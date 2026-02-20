"""
Endpoints para gestión de Cartas de Responsabilidad - CON ELIMINACIÓN
📍 Ubicación: backend/app/api/endpoints/cartas.py
✅ Solo SUPERADMIN puede eliminar cartas
"""
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status, Request, Query
from sqlalchemy.orm import Session
from sqlalchemy import asc
from app.core.database import get_db
from app.schemas import ResponseBase
from app.models import CartaResponsabilidad, SolicitudVPN, AccesoVPN, UsuarioSistema, Persona
from app.api.dependencies.auth import get_current_active_user, require_superadmin, get_client_ip
from app.utils.auditoria import AuditoriaService

router = APIRouter()


# ========================================
# LISTAR TODAS LAS CARTAS (CONTROL)
# ========================================

@router.get("/control", response_model=dict)
async def listar_cartas_control(
    anio: Optional[int] = Query(None, description="Filtrar por año"),
    numero: Optional[int] = Query(None, description="Filtrar por número de carta"),
    nombre: Optional[str] = Query(None, description="Filtrar por nombre/apellido"),
    nip: Optional[str] = Query(None, description="Filtrar por NIP"),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Listar todas las cartas ordenadas por año y número para el módulo de control.
    """
    query = db.query(CartaResponsabilidad).join(
        SolicitudVPN, CartaResponsabilidad.solicitud_id == SolicitudVPN.id
    ).join(
        Persona, SolicitudVPN.persona_id == Persona.id
    ).filter(
        CartaResponsabilidad.eliminada == False
    )

    if anio:
        query = query.filter(CartaResponsabilidad.anio_carta == anio)
    if numero:
        query = query.filter(CartaResponsabilidad.numero_carta == numero)
    if nombre:
        term = f"%{nombre.upper()}%"
        query = query.filter(
            (Persona.nombres.ilike(term)) | (Persona.apellidos.ilike(term))
        )
    if nip:
        query = query.filter(Persona.nip.ilike(f"%{nip}%"))

    total = query.count()

    cartas = query.order_by(
        asc(CartaResponsabilidad.anio_carta),
        asc(CartaResponsabilidad.numero_carta)
    ).offset(skip).limit(limit).all()

    # Obtener años disponibles para el filtro
    from sqlalchemy import distinct
    anios_disponibles = [
        row[0] for row in db.query(distinct(CartaResponsabilidad.anio_carta))
        .filter(CartaResponsabilidad.eliminada == False)
        .order_by(asc(CartaResponsabilidad.anio_carta))
        .all()
    ]

    resultado = []
    for carta in cartas:
        sol = carta.solicitud
        persona = sol.persona

        # Obtener acceso y calcular estado dinámicamente (el campo almacenado puede estar desactualizado)
        acceso = db.query(AccesoVPN).filter(
            AccesoVPN.solicitud_id == sol.id
        ).first()

        from app.utils.fecha_local import hoy_gt as _hoy_gt
        if not acceso:
            estado_acceso = 'SIN_ACCESO'
        else:
            dias = (acceso.fecha_fin_con_gracia - _hoy_gt()).days
            if dias <= 0:           # <-- vencido hoy O ya expiró
                estado_acceso = 'VENCIDO'
            elif dias <= 30:
                estado_acceso = 'POR_VENCER'
            else:
                estado_acceso = 'VIGENTE'

        resultado.append({
            "carta_id": carta.id,
            "solicitud_id": sol.id,
            "numero_carta": carta.numero_carta,
            "anio_carta": carta.anio_carta,
            "numero_display": f"{carta.numero_carta}-{carta.anio_carta}",
            "fecha_generacion": carta.fecha_generacion.isoformat() if carta.fecha_generacion else None,
            "nip": persona.nip or "—",
            "nombre": f"{persona.nombres} {persona.apellidos}",
            "institucion": persona.institucion or "—",
            "estado_acceso": estado_acceso,
            "justificacion": sol.justificacion or "",
            "fecha_fin_con_gracia": acceso.fecha_fin_con_gracia.isoformat() if acceso else None,
            "dias_gracia": acceso.dias_gracia if acceso else 0,
            "dias_restantes": (acceso.fecha_fin_con_gracia - _hoy_gt()).days if acceso else None,
        })

    return {
        "success": True,
        "total": total,
        "skip": skip,
        "limit": limit,
        "anios_disponibles": anios_disponibles,
        "cartas": resultado
    }



# ========================================
# ELIMINAR CARTA (SOLO SUPERADMIN)
# ========================================

@router.delete("/{carta_id}", response_model=ResponseBase)
async def eliminar_carta(
    carta_id: int,
    request: Request,
    current_user: UsuarioSistema = Depends(require_superadmin),
    db: Session = Depends(get_db)
):
    """
    Eliminar una carta de responsabilidad
    
    ⚠️ SOLO SUPERADMIN
    
    Esta acción:
    1. Elimina el acceso VPN asociado
    2. Cambia el estado de la solicitud a PENDIENTE
    3. MANTIENE el número de carta para poder reutilizarlo
    4. Registra en auditoría
    """
    
    # Obtener carta
    carta = db.query(CartaResponsabilidad).filter(
        CartaResponsabilidad.id == carta_id
    ).first()
    
    if not carta:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Carta no encontrada"
        )
    
    # Obtener solicitud asociada
    solicitud = db.query(SolicitudVPN).filter(
        SolicitudVPN.id == carta.solicitud_id
    ).first()
    
    if not solicitud:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Solicitud asociada no encontrada"
        )
    
    # Guardar información para auditoría
    info_carta = {
        "carta_id": carta.id,
        "numero_carta": carta.numero_carta,
        "anio_carta": carta.anio_carta,
        "solicitud_id": solicitud.id,
        "persona_dpi": solicitud.persona.dpi,
        "persona_nombres": solicitud.persona.nombres,
        "persona_apellidos": solicitud.persona.apellidos
    }
    
    # Eliminar acceso VPN si existe
    acceso = db.query(AccesoVPN).filter(
        AccesoVPN.solicitud_id == solicitud.id
    ).first()
    
    if acceso:
        info_carta["acceso_id"] = acceso.id
        db.delete(acceso)
    
    # Cambiar estado de solicitud a PENDIENTE
    solicitud.estado = 'PENDIENTE'
    
    # ✅ CRÍTICO: NO eliminamos la carta, solo marcamos como eliminada
    # Esto permite mantener el número de carta
    carta.eliminada = True  # Agregar este campo en el modelo
    
    # Commit cambios
    db.commit()
    
    # Registrar en auditoría
    ip_origen = get_client_ip(request)
    AuditoriaService.registrar_evento(
        db=db,
        usuario=current_user,
        accion="ELIMINAR_CARTA",
        entidad="CARTA",
        entidad_id=carta_id,
        detalle=info_carta,
        ip_origen=ip_origen
    )
    
    return ResponseBase(
        success=True,
        message=f"Carta {carta.numero_carta}-{carta.anio_carta} eliminada. Puedes corregir los datos y regenerarla."
    )


# ========================================
# REGENERAR CARTA (MANTIENE EL NÚMERO)
# ========================================

@router.post("/regenerar/{solicitud_id}", response_model=dict)
async def regenerar_carta(
    solicitud_id: int,
    request: Request,
    current_user: UsuarioSistema = Depends(require_superadmin),
    db: Session = Depends(get_db)
):
    """
    Regenerar una carta eliminada manteniendo el número original
    
    ⚠️ SOLO SUPERADMIN
    """
    from datetime import date, timedelta
    from sqlalchemy import func
    
    # Obtener solicitud
    solicitud = db.query(SolicitudVPN).filter(
        SolicitudVPN.id == solicitud_id
    ).first()
    
    if not solicitud:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Solicitud no encontrada"
        )
    
    # Verificar si tiene carta eliminada
    carta_eliminada = db.query(CartaResponsabilidad).filter(
        CartaResponsabilidad.solicitud_id == solicitud_id,
        CartaResponsabilidad.eliminada == True
    ).first()
    
    if not carta_eliminada:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Esta solicitud no tiene carta eliminada para regenerar"
        )
    
    # Guardar número y año de la carta eliminada
    numero_original = carta_eliminada.numero_carta
    anio_original = carta_eliminada.anio_carta
    
    # Eliminar definitivamente la carta antigua
    db.delete(carta_eliminada)
    db.flush()
    
    # Crear nueva carta CON EL MISMO NÚMERO
    nueva_carta = CartaResponsabilidad(
        solicitud_id=solicitud_id,
        tipo='RESPONSABILIDAD',
        fecha_generacion=date.today(),
        generada_por_usuario_id=current_user.id,
        numero_carta=numero_original,  # ✅ MANTENER NÚMERO ORIGINAL
        anio_carta=anio_original,      # ✅ MANTENER AÑO ORIGINAL
        eliminada=False
    )
    db.add(nueva_carta)
    db.flush()
    
    # Crear nuevo acceso VPN
    fecha_inicio = date.today()
    fecha_fin = fecha_inicio + timedelta(days=365)
    
    acceso = AccesoVPN(
        solicitud_id=solicitud_id,
        fecha_inicio=fecha_inicio,
        fecha_fin=fecha_fin,
        dias_gracia=0,
        fecha_fin_con_gracia=fecha_fin,
        estado_vigencia='ACTIVO',
        usuario_creacion_id=current_user.id
    )
    db.add(acceso)
    
    # Cambiar estado de solicitud
    solicitud.estado = 'APROBADA'
    
    db.commit()
    db.refresh(nueva_carta)
    db.refresh(acceso)
    
    # Auditoría
    ip_origen = get_client_ip(request)
    AuditoriaService.registrar_evento(
        db=db,
        usuario=current_user,
        accion="REGENERAR_CARTA",
        entidad="CARTA",
        entidad_id=nueva_carta.id,
        detalle={
            "numero_carta": numero_original,
            "anio_carta": anio_original,
            "solicitud_id": solicitud_id,
            "acceso_id": acceso.id,
            "carta_anterior_id": carta_eliminada.id
        },
        ip_origen=ip_origen
    )
    
    return {
        "success": True,
        "message": f"Carta {numero_original}-{anio_original} regenerada exitosamente",
        "carta_id": nueva_carta.id,
        "numero_carta": numero_original,
        "anio_carta": anio_original,
        "acceso_id": acceso.id
    }


# ========================================
# OBTENER INFORMACIÓN DE CARTA
# ========================================

@router.get("/{carta_id}", response_model=dict)
async def obtener_carta(
    carta_id: int,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Obtener detalles de una carta"""
    
    carta = db.query(CartaResponsabilidad).filter(
        CartaResponsabilidad.id == carta_id
    ).first()
    
    if not carta:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Carta no encontrada"
        )
    
    return {
        "id": carta.id,
        "solicitud_id": carta.solicitud_id,
        "tipo": carta.tipo,
        "numero_carta": carta.numero_carta,
        "anio_carta": carta.anio_carta,
        "fecha_generacion": carta.fecha_generacion,
        "eliminada": getattr(carta, 'eliminada', False),
        "persona": {
            "id": carta.solicitud.persona.id,
            "dpi": carta.solicitud.persona.dpi,
            "nip": carta.solicitud.persona.nip,
            "nombres": carta.solicitud.persona.nombres,
            "apellidos": carta.solicitud.persona.apellidos,
            "institucion": carta.solicitud.persona.institucion
        }
    }