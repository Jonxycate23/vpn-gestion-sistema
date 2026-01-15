"""
Endpoints de Dashboard MEJORADO - VERSIÓN CORREGIDA
📍 Ubicación: backend/app/api/endpoints/dashboard.py
✅ CORREGIDO: Ahora cuenta correctamente las cartas por año y cancelados
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text, func, and_
from app.core.database import get_db
from app.api.dependencies.auth import get_current_active_user
from app.models import (
    UsuarioSistema, Persona, AccesoVPN, CartaResponsabilidad, 
    SolicitudVPN, BloqueoVPN
)
from app.schemas import DashboardVencimientos
from datetime import date, timedelta

router = APIRouter()


@router.get("/vencimientos", response_model=DashboardVencimientos)
async def obtener_dashboard_vencimientos(
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Obtener dashboard de vencimientos"""
    query = text("SELECT * FROM vista_dashboard_vencimientos")
    result = db.execute(query).fetchone()
    
    return DashboardVencimientos(
        activos=result[0] or 0,
        por_vencer=result[1] or 0,
        vencidos=result[2] or 0,
        bloqueados=result[3] or 0,
        vencen_esta_semana=result[4] or 0,
        vencen_hoy=result[5] or 0
    )


@router.get("/accesos-actuales")
async def obtener_accesos_actuales(
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db),
    estado_vigencia: str = None,
    estado_bloqueo: str = None,
    limit: int = 50
):
    """Obtener lista de accesos actuales CON NIP"""
    query = "SELECT * FROM vista_accesos_actuales WHERE 1=1"
    params = {}
    
    if estado_vigencia:
        query += " AND estado_vigencia = :estado_vigencia"
        params["estado_vigencia"] = estado_vigencia
    
    if estado_bloqueo:
        query += " AND estado_bloqueo = :estado_bloqueo"
        params["estado_bloqueo"] = estado_bloqueo
    
    query += f" ORDER BY dias_restantes LIMIT {limit}"
    
    result = db.execute(text(query), params).fetchall()
    
    accesos_list = []
    for row in result:
        persona_id = row[0]
        persona = db.query(Persona).filter(Persona.id == persona_id).first()
        nip = persona.nip if persona else None
        
        accesos_list.append({
            "persona_id": row[0],
            "dpi": row[1],
            "nip": nip,
            "nombres": row[2],
            "apellidos": row[3],
            "institucion": row[4],
            "cargo": row[5],
            "solicitud_id": row[6],
            "fecha_solicitud": row[7],
            "tipo_solicitud": row[8],
            "acceso_id": row[9],
            "fecha_inicio": row[10],
            "fecha_fin": row[11],
            "dias_gracia": row[12],
            "fecha_fin_con_gracia": row[13],
            "estado_vigencia": row[14],
            "dias_restantes": row[15],
            "estado_bloqueo": row[16],
            "usuario_registro": row[17]
        })
    
    return {
        "total": len(accesos_list),
        "accesos": accesos_list
    }


# ========================================
# ✅ CORREGIDO: ALERTAS INTELIGENTES CON CONTEO DE CARTAS Y CANCELADOS
# ========================================

@router.get("/alertas-vencimientos-inteligentes")
async def obtener_alertas_inteligentes(
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    ✅ CORREGIDO: Contadores separados y precisos
    """
    hoy = date.today()
    
    # ========================================
    # ✅ CONTAR CARTAS POR AÑO
    # ========================================
    cartas_2026 = db.query(CartaResponsabilidad).filter(
        CartaResponsabilidad.anio_carta == 2026
    ).count()
    
    cartas_2025 = db.query(CartaResponsabilidad).filter(
        CartaResponsabilidad.anio_carta == 2025
    ).count()
    
    cartas_2024 = db.query(CartaResponsabilidad).filter(
        CartaResponsabilidad.anio_carta == 2024
    ).count()
    
    cartas_2023 = db.query(CartaResponsabilidad).filter(
        CartaResponsabilidad.anio_carta == 2023
    ).count()
    
    print(f"📊 Cartas por año:")
    print(f"   2026: {cartas_2026} cartas")
    print(f"   2025: {cartas_2025} cartas")
    print(f"   2024: {cartas_2024} cartas")
    print(f"   2023: {cartas_2023} cartas")
    
    # ========================================
    # ✅ CONTAR CANCELADOS (SOLICITUDES)
    # ========================================
    cancelados = db.query(SolicitudVPN).filter(
        SolicitudVPN.estado == 'CANCELADA'
    ).count()
    
    print(f"📊 Solicitudes Canceladas: {cancelados}")
    
    # ========================================
    # ✅ CONTAR PENDIENTES (Solicitudes sin carta)
    # ========================================
    pendientes = db.query(SolicitudVPN).filter(
        SolicitudVPN.estado == 'PENDIENTE'
    ).count()
    
    print(f"📊 Solicitudes Pendientes: {pendientes}")
    
    # ========================================
    # OBTENER TODOS LOS ACCESOS PARA ANÁLISIS
    # ========================================
    accesos_criticos = db.query(AccesoVPN).join(
        SolicitudVPN
    ).join(
        Persona
    ).all()
    
    # Agrupar por persona para evitar duplicados
    personas_procesadas = {}
    
    for acceso in accesos_criticos:
        persona = acceso.solicitud.persona
        persona_id = persona.id
        
        # Si ya procesamos esta persona, solo actualizar si este acceso es más crítico
        if persona_id in personas_procesadas:
            dias_actual = (acceso.fecha_fin_con_gracia - hoy).days
            dias_guardado = personas_procesadas[persona_id]['dias_restantes_acceso_actual']
            
            if dias_actual < dias_guardado:
                personas_procesadas[persona_id]['acceso_id'] = acceso.id
                personas_procesadas[persona_id]['fecha_vencimiento_acceso_actual'] = acceso.fecha_fin_con_gracia
                personas_procesadas[persona_id]['dias_restantes_acceso_actual'] = dias_actual
                
                ultimo_bloqueo = db.query(BloqueoVPN).filter(
                    BloqueoVPN.acceso_vpn_id == acceso.id
                ).order_by(BloqueoVPN.fecha_cambio.desc()).first()
                personas_procesadas[persona_id]['estado_bloqueo'] = ultimo_bloqueo.estado if ultimo_bloqueo else "DESBLOQUEADO"
            
            continue
        
        # Obtener TODAS las cartas de esta persona
        todas_las_cartas = db.query(CartaResponsabilidad).join(
            SolicitudVPN
        ).filter(
            SolicitudVPN.persona_id == persona.id
        ).order_by(CartaResponsabilidad.fecha_generacion.desc()).all()
        
        # Analizar las cartas
        cartas_info = []
        tiene_carta_vigente = False
        carta_mas_reciente = None
        anio_carta_actual = None
        
        for carta in todas_las_cartas:
            acceso_carta = db.query(AccesoVPN).filter(
                AccesoVPN.solicitud_id == carta.solicitud_id
            ).first()
            
            if acceso_carta:
                dias_rest = (acceso_carta.fecha_fin_con_gracia - hoy).days
                
                estado_carta = "VENCIDA"
                if dias_rest > 30:
                    estado_carta = "ACTIVA"
                    tiene_carta_vigente = True
                    if carta_mas_reciente is None or carta.fecha_generacion > carta_mas_reciente:
                        carta_mas_reciente = carta.fecha_generacion
                        anio_carta_actual = carta.anio_carta
                elif dias_rest > 0:
                    estado_carta = "POR_VENCER"
                
                cartas_info.append({
                    "carta_id": carta.id,
                    "numero_carta": f"{carta.numero_carta}-{carta.anio_carta}",
                    "fecha_generacion": carta.fecha_generacion,
                    "fecha_vencimiento": acceso_carta.fecha_fin_con_gracia,
                    "dias_restantes": dias_rest,
                    "estado": estado_carta,
                    "acceso_id": acceso_carta.id,
                    "anio_carta": carta.anio_carta
                })
        
        # Obtener estado de bloqueo
        ultimo_bloqueo = db.query(BloqueoVPN).filter(
            BloqueoVPN.acceso_vpn_id == acceso.id
        ).order_by(BloqueoVPN.fecha_cambio.desc()).first()
        
        estado_bloqueo = ultimo_bloqueo.estado if ultimo_bloqueo else "DESBLOQUEADO"
        
        # Determinar tipo de alerta
        dias_restantes = (acceso.fecha_fin_con_gracia - hoy).days
        
        if tiene_carta_vigente:
            tipo_alerta = "CON_RENOVACION"
            prioridad = 1
        elif dias_restantes <= 0:
            tipo_alerta = "VENCIDO_SIN_RENOVACION"
            prioridad = 5
        elif dias_restantes <= 7:
            tipo_alerta = "POR_VENCER_URGENTE"
            prioridad = 4
        elif dias_restantes <= 30:
            tipo_alerta = "POR_VENCER"
            prioridad = 3
        else:
            tipo_alerta = "INFORMATIVA"
            prioridad = 2
        
        personas_procesadas[persona_id] = {
            "persona_id": persona.id,
            "nip": persona.nip,
            "dpi": persona.dpi,
            "nombres": persona.nombres,
            "apellidos": persona.apellidos,
            "institucion": persona.institucion,
            "acceso_id": acceso.id,
            "fecha_vencimiento_acceso_actual": acceso.fecha_fin_con_gracia,
            "dias_restantes_acceso_actual": dias_restantes,
            "estado_bloqueo": estado_bloqueo,
            "tiene_carta_vigente": tiene_carta_vigente,
            "total_cartas": len(cartas_info),
            "historial_cartas": cartas_info,
            "tipo_alerta": tipo_alerta,
            "prioridad": prioridad,
            "requiere_bloqueo": not tiene_carta_vigente and dias_restantes <= 0,
            "anio_carta": anio_carta_actual
        }
    
    alertas = list(personas_procesadas.values())
    alertas.sort(key=lambda x: x["dias_restantes_acceso_actual"])
    
    return {
        "total_alertas": len(alertas),
        "alertas": alertas,
        "cartas_por_anio": {
            "2026": cartas_2026,
            "2025": cartas_2025,
            "2024": cartas_2024,
            "2023": cartas_2023
        },
        "pendientes_sin_carta": pendientes,
        "total_cancelados": cancelados,  # ✅ ENVIAR CANCELADOS
        "resumen": {
            "activos": sum(1 for a in alertas if a["estado_bloqueo"] != "BLOQUEADO" and a["dias_restantes_acceso_actual"] > 0),
            "vencidos_hoy": sum(1 for a in alertas if a["fecha_vencimiento_acceso_actual"] == hoy and a["estado_bloqueo"] != "BLOQUEADO"),
            "bloqueados": sum(1 for a in alertas if a["estado_bloqueo"] == "BLOQUEADO"),
            "cancelados": cancelados,
            "vencidos_sin_renovacion": sum(1 for a in alertas if a["tipo_alerta"] == "VENCIDO_SIN_RENOVACION"),
            "por_vencer_urgente": sum(1 for a in alertas if a["tipo_alerta"] == "POR_VENCER_URGENTE"),
            "por_vencer": sum(1 for a in alertas if a["tipo_alerta"] == "POR_VENCER"),
            "con_renovacion": sum(1 for a in alertas if a["tipo_alerta"] == "CON_RENOVACION"),
            "informativa": sum(1 for a in alertas if a["tipo_alerta"] == "INFORMATIVA")
        }
    }


@router.get("/historial-cartas/{persona_id}")
async def obtener_historial_cartas_persona(
    persona_id: int,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Obtener historial completo de cartas de una persona
    """
    persona = db.query(Persona).filter(Persona.id == persona_id).first()
    if not persona:
        raise HTTPException(status_code=404, detail="Persona no encontrada")
    
    cartas = db.query(CartaResponsabilidad).join(
        SolicitudVPN
    ).filter(
        SolicitudVPN.persona_id == persona_id
    ).order_by(CartaResponsabilidad.fecha_generacion.desc()).all()
    
    hoy = date.today()
    historial = []
    
    for carta in cartas:
        acceso = db.query(AccesoVPN).filter(
            AccesoVPN.solicitud_id == carta.solicitud_id
        ).first()
        
        if acceso:
            dias_restantes = (acceso.fecha_fin_con_gracia - hoy).days
            
            estado = "VENCIDA"
            if dias_restantes > 30:
                estado = "ACTIVA"
            elif dias_restantes > 0:
                estado = "POR_VENCER"
            
            historial.append({
                "carta_id": carta.id,
                "numero_carta": f"{carta.numero_carta}-{carta.anio_carta}",
                "solicitud_id": carta.solicitud_id,
                "fecha_generacion": carta.fecha_generacion,
                "fecha_vencimiento": acceso.fecha_fin_con_gracia,
                "dias_restantes": dias_restantes,
                "estado": estado,
                "acceso_id": acceso.id,
                "estado_bloqueo": acceso.estado_bloqueo_actual
            })
    
    return {
        "persona": {
            "id": persona.id,
            "nip": persona.nip,
            "dpi": persona.dpi,
            "nombres": persona.nombres,
            "apellidos": persona.apellidos,
            "institucion": persona.institucion
        },
        "total_cartas": len(historial),
        "historial": historial,
        "tiene_carta_vigente": any(c["estado"] == "ACTIVA" for c in historial)
    }


@router.post("/actualizar-estados")
async def actualizar_estados_vigencia(
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Ejecutar funciones automáticas de actualización"""
    try:
        db.execute(text("SELECT actualizar_estado_vigencia()"))
        db.execute(text("SELECT generar_alertas_vencimiento()"))
        db.commit()
        
        return {
            "success": True,
            "message": "Estados actualizados y alertas generadas exitosamente"
        }
    except Exception as e:
        db.rollback()
        return {
            "success": False,
            "message": f"Error al actualizar estados: {str(e)}"
        }