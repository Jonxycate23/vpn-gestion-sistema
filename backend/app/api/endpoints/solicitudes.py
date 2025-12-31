"""
Endpoints de gestión de Solicitudes VPN
VERSIÓN COMPLETA: Incluye crear carta, no presentado, eliminar
📍 Ubicación: backend/app/api/endpoints/solicitudes.py
"""
from fastapi import APIRouter, Depends, status, Request, Query, HTTPException
from sqlalchemy.orm import Session
from typing import Optional
from datetime import date
from app.core.database import get_db
from app.schemas import (
    SolicitudCreate,
    SolicitudAprobar,
    SolicitudRechazar,
    PersonaCreate,
    ResponseBase
)
from app.services.solicitudes import SolicitudService
from app.services.personas import PersonaService
from app.api.dependencies.auth import get_current_active_user, get_client_ip
from app.models import (
    UsuarioSistema, 
    SolicitudVPN, 
    CartaResponsabilidad,
    Persona
)
from app.utils.auditoria import AuditoriaService

router = APIRouter()


# ========================================
# BÚSQUEDA POR DPI
# ========================================

@router.get("/buscar-dpi/{dpi}", response_model=dict)
async def buscar_persona_por_dpi(
    dpi: str,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Buscar persona por DPI - retorna datos completos si existe"""
    persona = PersonaService.obtener_por_dpi(db=db, dpi=dpi)
    
    if persona is None:
        return {"existe": False}
    
    # Contar solicitudes
    total_solicitudes = db.query(SolicitudVPN).filter(
        SolicitudVPN.persona_id == persona.id
    ).count()
    
    return {
        "existe": True,
        "id": persona.id,
        "dpi": persona.dpi,
        "nip": getattr(persona, 'nip', None),
        "nombres": persona.nombres,
        "apellidos": persona.apellidos,
        "institucion": persona.institucion,
        "cargo": persona.cargo,
        "telefono": persona.telefono,
        "email": persona.email,
        "observaciones": persona.observaciones,
        "activo": persona.activo,
        "fecha_creacion": persona.fecha_creacion,
        "total_solicitudes": total_solicitudes
    }


# ========================================
# CREAR/ACTUALIZAR PERSONA
# ========================================

@router.post("/persona", response_model=dict, status_code=status.HTTP_200_OK)
async def crear_o_actualizar_persona(
    data: PersonaCreate,
    request: Request,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Crear nueva persona o actualizar si ya existe"""
    ip_origen = get_client_ip(request)
    
    # Buscar si existe
    persona_existente = PersonaService.obtener_por_dpi(db=db, dpi=data.dpi)
    
    if persona_existente:
        # Actualizar solo campos editables DIRECTAMENTE
        if hasattr(persona_existente, 'nip') and hasattr(data, 'nip'):
            persona_existente.nip = data.nip
        persona_existente.email = data.email
        persona_existente.cargo = data.cargo
        persona_existente.telefono = data.telefono
        persona_existente.institucion = data.institucion
        if hasattr(data, 'observaciones') and data.observaciones:
            persona_existente.observaciones = data.observaciones
        
        db.commit()
        db.refresh(persona_existente)
        
        # Auditoría
        AuditoriaService.registrar_actualizar(
            db=db,
            usuario=current_user,
            entidad="PERSONA",
            entidad_id=persona_existente.id,
            cambios={"accion": "actualizar_datos"},
            ip_origen=ip_origen
        )
        
        return {
            "success": True,
            "message": "Datos actualizados exitosamente",
            "persona_id": persona_existente.id,
            "accion": "actualizar"
        }
    else:
        # Crear nueva persona
        persona = PersonaService.crear(
            db=db,
            data=data,
            usuario_id=current_user.id,
            ip_origen=ip_origen
        )
        
        return {
            "success": True,
            "message": "Persona creada exitosamente",
            "persona_id": persona.id,
            "accion": "crear"
        }


# ========================================
# SOLICITUDES VPN
# ========================================

@router.post("/", response_model=dict, status_code=status.HTTP_201_CREATED)
async def crear_solicitud(
    data: SolicitudCreate,
    request: Request,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Crear nueva solicitud VPN"""
    ip_origen = get_client_ip(request)
    solicitud = SolicitudService.crear(
        db=db,
        data=data,
        usuario_id=current_user.id,
        ip_origen=ip_origen
    )
    
    # Obtener datos completos para respuesta
    persona = db.query(Persona).filter(Persona.id == solicitud.persona_id).first()
    
    return {
        "success": True,
        "message": "Solicitud creada exitosamente",
        "solicitud": {
            "id": solicitud.id,
            "persona_id": solicitud.persona_id,
            "persona_nombre": f"{persona.nombres} {persona.apellidos}",
            "persona_dpi": persona.dpi,
            "tipo_solicitud": solicitud.tipo_solicitud,
            "fecha_solicitud": solicitud.fecha_solicitud,
            "estado": solicitud.estado
        }
    }


@router.get("/", response_model=dict)
async def listar_solicitudes(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=200),
    estado: Optional[str] = Query(None),
    tipo: Optional[str] = Query(None),
    persona_id: Optional[int] = Query(None),
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Listar solicitudes con filtros
    INCLUYE: campo carta_generada (true/false)
    """
    solicitudes, total = SolicitudService.listar(
        db=db,
        skip=skip,
        limit=limit,
        estado=estado,
        tipo=tipo,
        persona_id=persona_id
    )
    
    # Enriquecer con datos
    result = []
    for sol in solicitudes:
        # Verificar si tiene carta creada
        carta = db.query(CartaResponsabilidad).filter(
            CartaResponsabilidad.solicitud_id == sol.id
        ).first()
        
        sol_dict = {
            "id": sol.id,
            "persona_id": sol.persona_id,
            "numero_oficio": sol.numero_oficio,
            "numero_providencia": sol.numero_providencia,
            "fecha_recepcion": sol.fecha_recepcion,
            "fecha_solicitud": sol.fecha_solicitud,
            "tipo_solicitud": sol.tipo_solicitud,
            "justificacion": sol.justificacion,
            "estado": sol.estado,
            "comentarios_admin": sol.comentarios_admin,
            "fecha_registro": sol.fecha_registro,
            "persona_nombres": sol.persona.nombres,
            "persona_apellidos": sol.persona.apellidos,
            "persona_dpi": sol.persona.dpi,
            "usuario_registro_nombre": sol.usuario_registro.nombre_completo,
            "carta_generada": carta is not None,
        }
        
        # Agregar datos del acceso si existe
        if sol.acceso:
            sol_dict.update({
                "acceso_id": sol.acceso.id,
                "fecha_inicio": sol.acceso.fecha_inicio,
                "fecha_fin": sol.acceso.fecha_fin,
                "estado_vigencia": sol.acceso.estado_vigencia,
                "dias_restantes": (sol.acceso.fecha_fin_con_gracia - date.today()).days
            })
        
        result.append(sol_dict)
    
    return {
        "total": total,
        "page": (skip // limit) + 1 if limit > 0 else 1,
        "page_size": limit,
        "solicitudes": result
    }


@router.get("/{solicitud_id}", response_model=dict)
async def obtener_solicitud(
    solicitud_id: int,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Obtener solicitud por ID con todos los detalles"""
    solicitud = SolicitudService.obtener_por_id(db=db, solicitud_id=solicitud_id)
    if not solicitud:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
    
    result = {
        "id": solicitud.id,
        "persona_id": solicitud.persona_id,
        "numero_oficio": solicitud.numero_oficio,
        "numero_providencia": solicitud.numero_providencia,
        "fecha_recepcion": solicitud.fecha_recepcion,
        "fecha_solicitud": solicitud.fecha_solicitud,
        "tipo_solicitud": solicitud.tipo_solicitud,
        "justificacion": solicitud.justificacion,
        "estado": solicitud.estado,
        "comentarios_admin": solicitud.comentarios_admin,
        "fecha_registro": solicitud.fecha_registro,
        "persona": {
            "id": solicitud.persona.id,
            "dpi": solicitud.persona.dpi,
            "nip": getattr(solicitud.persona, 'nip', None),
            "nombres": solicitud.persona.nombres,
            "apellidos": solicitud.persona.apellidos,
            "institucion": solicitud.persona.institucion,
            "cargo": solicitud.persona.cargo
        },
        "usuario_registro": {
            "id": solicitud.usuario_registro.id,
            "nombre_completo": solicitud.usuario_registro.nombre_completo
        }
    }
    
    # Agregar datos del acceso si existe
    if solicitud.acceso:
        result["acceso"] = {
            "id": solicitud.acceso.id,
            "fecha_inicio": solicitud.acceso.fecha_inicio,
            "fecha_fin": solicitud.acceso.fecha_fin,
            "dias_gracia": solicitud.acceso.dias_gracia,
            "fecha_fin_con_gracia": solicitud.acceso.fecha_fin_con_gracia,
            "estado_vigencia": solicitud.acceso.estado_vigencia,
            "dias_restantes": (solicitud.acceso.fecha_fin_con_gracia - date.today()).days
        }
    
    return result


# ========================================
# CREAR CARTA DE RESPONSABILIDAD
# ========================================

@router.post("/{solicitud_id}/crear-carta", response_model=dict)
async def crear_carta_responsabilidad(
    solicitud_id: int,
    request: Request,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Crear carta de responsabilidad para una solicitud"""
    ip_origen = get_client_ip(request)
    
    # Verificar que la solicitud existe
    solicitud = db.query(SolicitudVPN).filter(SolicitudVPN.id == solicitud_id).first()
    if not solicitud:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
    
    # Verificar que esté aprobada
    if solicitud.estado != 'APROBADA':
        raise HTTPException(
            status_code=400, 
            detail="Solo se pueden crear cartas para solicitudes APROBADAS"
        )
    
    # Verificar que no exista ya una carta
    carta_existente = db.query(CartaResponsabilidad).filter(
        CartaResponsabilidad.solicitud_id == solicitud_id
    ).first()
    
    if carta_existente:
        raise HTTPException(
            status_code=400, 
            detail="Ya existe una carta para esta solicitud"
        )
    
    # Crear carta
    carta = CartaResponsabilidad(
        solicitud_id=solicitud_id,
        tipo='RESPONSABILIDAD',
        fecha_generacion=date.today(),
        generada_por_usuario_id=current_user.id
    )
    
    db.add(carta)
    db.commit()
    db.refresh(carta)
    
    # Auditoría
    AuditoriaService.registrar_crear(
        db=db,
        usuario=current_user,
        entidad="CARTA",
        entidad_id=carta.id,
        detalle={
            "solicitud_id": solicitud_id,
            "tipo": "RESPONSABILIDAD"
        },
        ip_origen=ip_origen
    )
    
    return {
        "success": True,
        "message": "Carta creada exitosamente",
        "carta_id": carta.id,
        "fecha_generacion": carta.fecha_generacion
    }


# ========================================
# MARCAR COMO "NO SE PRESENTÓ"
# ========================================

@router.post("/{solicitud_id}/no-presentado", response_model=dict)
async def marcar_no_presentado(
    solicitud_id: int,
    request: Request,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Marcar solicitud como 'No se presentó'"""
    ip_origen = get_client_ip(request)
    
    # Obtener body (si existe)
    try:
        body = await request.json()
        motivo = body.get('motivo', 'No se presentó a firmar la carta')
    except:
        motivo = 'No se presentó a firmar la carta'
    
    solicitud = db.query(SolicitudVPN).filter(SolicitudVPN.id == solicitud_id).first()
    if not solicitud:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
    
    # Guardar estado anterior
    estado_anterior = solicitud.estado
    
    # Cambiar estado a CANCELADA
    solicitud.estado = 'CANCELADA'
    solicitud.comentarios_admin = f"NO_PRESENTADO: {motivo}"
    
    db.commit()
    db.refresh(solicitud)
    
    # Auditoría
    AuditoriaService.registrar_actualizar(
        db=db,
        usuario=current_user,
        entidad="SOLICITUD",
        entidad_id=solicitud_id,
        cambios={
            "estado": {"anterior": estado_anterior, "nuevo": "NO_PRESENTADO"},
            "motivo": motivo
        },
        ip_origen=ip_origen
    )
    
    return {
        "success": True,
        "message": "Solicitud marcada como 'No se presentó'",
        "solicitud_id": solicitud_id
    }


# ========================================
# ELIMINAR SOLICITUD
# ========================================

@router.delete("/{solicitud_id}", response_model=dict)
async def eliminar_solicitud(
    solicitud_id: int,
    request: Request,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Eliminar una solicitud"""
    ip_origen = get_client_ip(request)
    
    solicitud = db.query(SolicitudVPN).filter(SolicitudVPN.id == solicitud_id).first()
    if not solicitud:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
    
    # Verificar que no tenga carta
    carta = db.query(CartaResponsabilidad).filter(
        CartaResponsabilidad.solicitud_id == solicitud_id
    ).first()
    
    if carta:
        raise HTTPException(
            status_code=400, 
            detail="No se puede eliminar: Ya tiene carta de responsabilidad creada"
        )
    
    # Verificar que no tenga acceso VPN
    if solicitud.acceso:
        raise HTTPException(
            status_code=400,
            detail="No se puede eliminar: Ya tiene acceso VPN asociado"
        )
    
    # Auditoría ANTES de eliminar
    AuditoriaService.registrar_eliminar(
        db=db,
        usuario=current_user,
        entidad="SOLICITUD",
        entidad_id=solicitud_id,
        motivo="Eliminación solicitada por usuario",
        ip_origen=ip_origen
    )
    
    # Eliminar
    db.delete(solicitud)
    db.commit()
    
    return {
        "success": True,
        "message": "Solicitud eliminada exitosamente"
    }


# ========================================
# APROBAR / RECHAZAR
# ========================================

@router.post("/{solicitud_id}/aprobar", response_model=dict)
async def aprobar_solicitud(
    solicitud_id: int,
    data: SolicitudAprobar,
    request: Request,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Aprobar solicitud VPN"""
    ip_origen = get_client_ip(request)
    solicitud, acceso = SolicitudService.aprobar(
        db=db,
        solicitud_id=solicitud_id,
        data=data,
        usuario_id=current_user.id,
        ip_origen=ip_origen
    )
    
    return {
        "success": True,
        "message": "Solicitud aprobada exitosamente",
        "solicitud_id": solicitud.id,
        "acceso_id": acceso.id,
        "fecha_inicio": acceso.fecha_inicio,
        "fecha_fin": acceso.fecha_fin
    }


@router.post("/{solicitud_id}/rechazar", response_model=ResponseBase)
async def rechazar_solicitud(
    solicitud_id: int,
    data: SolicitudRechazar,
    request: Request,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Rechazar solicitud VPN"""
    ip_origen = get_client_ip(request)
    SolicitudService.rechazar(
        db=db,
        solicitud_id=solicitud_id,
        data=data,
        usuario_id=current_user.id,
        ip_origen=ip_origen
    )
    
    return ResponseBase(
        success=True,
        message="Solicitud rechazada"
    )
# ========================================
# REACTIVAR SOLICITUD
# ========================================

@router.post("/{solicitud_id}/reactivar", response_model=dict)
async def reactivar_solicitud(
    solicitud_id: int,
    request: Request,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Reactivar una solicitud que fue marcada como 'No se presentó'"""
    ip_origen = get_client_ip(request)
    
    solicitud = db.query(SolicitudVPN).filter(SolicitudVPN.id == solicitud_id).first()
    if not solicitud:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
    
    # Verificar que esté en estado CANCELADA por NO_PRESENTADO
    if solicitud.estado != 'CANCELADA':
        raise HTTPException(
            status_code=400, 
            detail="Solo se pueden reactivar solicitudes canceladas"
        )
    
    if not solicitud.comentarios_admin or 'NO_PRESENTADO' not in solicitud.comentarios_admin:
        raise HTTPException(
            status_code=400,
            detail="Esta solicitud no fue marcada como 'No se presentó'"
        )
    
    # Guardar estado anterior
    estado_anterior = solicitud.estado
    comentarios_anteriores = solicitud.comentarios_admin
    
    # Reactivar a APROBADA
    solicitud.estado = 'APROBADA'
    solicitud.comentarios_admin = f"REACTIVADA: {comentarios_anteriores}"
    
    db.commit()
    db.refresh(solicitud)
    
    # Auditoría
    AuditoriaService.registrar_actualizar(
        db=db,
        usuario=current_user,
        entidad="SOLICITUD",
        entidad_id=solicitud_id,
        cambios={
            "estado": {"anterior": estado_anterior, "nuevo": "APROBADA"},
            "accion": "reactivacion"
        },
        ip_origen=ip_origen
    )
    
    return {
        "success": True,
        "message": "Solicitud reactivada exitosamente",
        "solicitud_id": solicitud_id,
        "nuevo_estado": solicitud.estado
    }