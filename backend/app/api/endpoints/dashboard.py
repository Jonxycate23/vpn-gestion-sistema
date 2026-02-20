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
from app.utils.fecha_local import hoy_gt  # ✅ Fecha en zona horaria local Guatemala UTC-6

router = APIRouter()


@router.get("/vencimientos", response_model=DashboardVencimientos)
async def obtener_dashboard_vencimientos(
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Obtener dashboard de vencimientos con eager loading de bloqueos"""
    from sqlalchemy.orm import selectinload
    
    hoy = hoy_gt()
    
    # Obtener accesos con bloqueos pre-cargados
    accesos = db.query(AccesoVPN)\
        .options(selectinload(AccesoVPN.bloqueos))\
        .all()
    
    activos = 0
    por_vencer = 0
    vencidos = 0
    bloqueados = 0
    vencen_esta_semana = 0
    vencen_hoy = 0
    
    for acceso in accesos:
        # Obtener último bloqueo de la lista pre-cargada
        bloqueos_ordenados = sorted(acceso.bloqueos, key=lambda b: b.fecha_cambio, reverse=True)
        estado_bloqueo = bloqueos_ordenados[0].estado if bloqueos_ordenados else "DESBLOQUEADO"
        
        dias_restantes = (acceso.fecha_fin_con_gracia - hoy).days
        
        # Lógica corregida:
        # VENCIDOS: Solo si ya pasó la fecha (dias < 0)
        # POR VENCER: Si vence hoy o en los próximos 30 días (0 <= dias <= 30)
        # ACTIVOS: Si faltan más de 30 días
        
        es_vencido = dias_restantes < 0
        es_por_vencer = 0 <= dias_restantes <= 30
        es_activo = dias_restantes > 30

        # Contadores principales (exclusivos para la gráfica usualmente, pero aquí permitimos superposición si está bloqueado)
        # Prioridad de estado para contadores visuales: BLOQUEADO > VENCIDO > POR VENCER > ACTIVO
        
        if estado_bloqueo == "BLOQUEADO":
            bloqueados += 1
            # Si está bloqueado, ¿lo contamos en vencidos? 
            # El usuario quiere ver datos reales. 
            # Mantendremos la lógica de que si está bloqueado, suma a bloqueados.
            # Pero internamente sabemos su estado de vigencia.
        elif es_vencido:
            vencidos += 1
        elif es_por_vencer:
            por_vencer += 1
            if dias_restantes <= 7:
                vencen_esta_semana += 1
                if dias_restantes == 0:
                    vencen_hoy += 1
        else:
            activos += 1
            
        # Contadores auxiliares (independientes del bloqueo para estadísticas globales)
        # Si queremos que "vecen_hoy" incluya bloqueados, lo movemos fuera del if/else principal
        if dias_restantes == 0:
            # vencen_hoy se usaba arriba solo para no bloqueados, ajustamos si es necesario
            # Por ahora mantenemos la consistencia con el bloque if/else anterior
            pass
    
    return DashboardVencimientos(
        activos=activos,
        por_vencer=por_vencer,
        vencidos=vencidos,
        bloqueados=bloqueados,
        vencen_esta_semana=vencen_esta_semana,
        vencen_hoy=vencen_hoy
    )


@router.get("/accesos-actuales")
async def obtener_accesos_actuales(
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db),
    estado_vigencia: str = None,
    estado_bloqueo: str = None,
    limit: int = 5000
):
    """Obtener lista de accesos actuales con eager loading de relaciones"""
    from sqlalchemy.orm import joinedload, selectinload
    
    # Eager loading de relaciones necesarias
    query = db.query(AccesoVPN)\
        .options(
            joinedload(AccesoVPN.solicitud).joinedload(SolicitudVPN.persona),
            joinedload(AccesoVPN.solicitud).joinedload(SolicitudVPN.usuario_registro),
            selectinload(AccesoVPN.bloqueos)
        )\
        .join(SolicitudVPN)\
        .join(Persona)
    
    # NOTA: Filtramos por estado_vigencia en memoria porque el de la DB puede estar desactualizado
    # Si estado_bloqueo viene, filtramos en memoria también para ser consistentes con la carga eager
    
    accesos = query.order_by(AccesoVPN.fecha_fin_con_gracia).limit(limit).all()
    
    accesos_list = []
    hoy = hoy_gt()
    
    for acceso in accesos:
        persona = acceso.solicitud.persona
        
        # Obtener último bloqueo de la lista pre-cargada
        bloqueos_ordenados = sorted(acceso.bloqueos, key=lambda b: b.fecha_cambio, reverse=True)
        estado_bloqueo_actual = bloqueos_ordenados[0].estado if bloqueos_ordenados else "DESBLOQUEADO"
        
        if estado_bloqueo and estado_bloqueo_actual != estado_bloqueo:
            continue
            
        # Calcular estado vigencia REAL
        dias_restantes = (acceso.fecha_fin_con_gracia - hoy).days
        estado_vigencia_real = "ACTIVO"
        if dias_restantes < 0:
            estado_vigencia_real = "VENCIDO"
        elif dias_restantes <= 30:
            estado_vigencia_real = "POR_VENCER"
            
        if estado_vigencia and estado_vigencia != estado_vigencia_real:
            continue
        
        accesos_list.append({
            "persona_id": persona.id,
            "dpi": persona.dpi,
            "nip": persona.nip,
            "nombres": persona.nombres,
            "apellidos": persona.apellidos,
            "institucion": persona.institucion,
            "cargo": persona.cargo,
            "solicitud_id": acceso.solicitud_id,
            "fecha_solicitud": acceso.solicitud.fecha_solicitud,
            "tipo_solicitud": acceso.solicitud.tipo_solicitud,
            "acceso_id": acceso.id,
            "fecha_inicio": acceso.fecha_inicio,
            "fecha_fin": acceso.fecha_fin,
            "dias_gracia": acceso.dias_gracia,
            "fecha_fin_con_gracia": acceso.fecha_fin_con_gracia,
            "estado_vigencia": estado_vigencia_real, # Usamos el calculado
            "dias_restantes": dias_restantes,
            "estado_bloqueo": estado_bloqueo_actual,
            "usuario_registro": acceso.solicitud.usuario_registro.nombre_completo if acceso.solicitud.usuario_registro else "N/A"
        })
    
    return {
        "total": len(accesos_list),
        "accesos": accesos_list
    }


# ========================================
# ALERTAS INTELIGENTES
# ========================================

@router.get("/alertas-vencimientos-inteligentes")
async def obtener_alertas_inteligentes(
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Obtener alertas de vencimientos con eager loading para evitar N+1 queries"""
    from sqlalchemy.orm import joinedload, selectinload
    
    hoy = hoy_gt()
    
    # Contar cartas por año en una sola query
    cartas_por_anio = db.query(
        CartaResponsabilidad.anio_carta,
        func.count(CartaResponsabilidad.id)
    ).filter(
        CartaResponsabilidad.anio_carta.in_([2023, 2024, 2025, 2026])
    ).group_by(CartaResponsabilidad.anio_carta).all()
    
    cartas_dict = {str(anio): count for anio, count in cartas_por_anio}
    cartas_2026 = cartas_dict.get('2026', 0)
    cartas_2025 = cartas_dict.get('2025', 0)
    cartas_2024 = cartas_dict.get('2024', 0)
    cartas_2023 = cartas_dict.get('2023', 0)
    
    print(f"Cartas por año: 2026={cartas_2026}, 2025={cartas_2025}, 2024={cartas_2024}, 2023={cartas_2023}")
    
    # Contar solicitudes canceladas y pendientes
    estados_count = db.query(
        SolicitudVPN.estado,
        func.count(SolicitudVPN.id)
    ).filter(
        SolicitudVPN.estado.in_(['CANCELADA', 'PENDIENTE'])
    ).group_by(SolicitudVPN.estado).all()
    
    estados_dict = {estado: count for estado, count in estados_count}
    cancelados = estados_dict.get('CANCELADA', 0)
    pendientes = estados_dict.get('PENDIENTE', 0)
    
    print(f"Cancelados: {cancelados}, Pendientes: {pendientes}")
    
    # Obtener accesos con eager loading de relaciones
    accesos_criticos = db.query(AccesoVPN)\
        .options(
            joinedload(AccesoVPN.solicitud).joinedload(SolicitudVPN.persona),
            selectinload(AccesoVPN.bloqueos)
        )\
        .join(SolicitudVPN)\
        .join(Persona)\
        .all()
    
    # ========================================
    # ⚡ PRE-CARGAR TODAS LAS CARTAS Y BLOQUEOS - Una sola query cada uno
    # ========================================
    # Obtener IDs de personas únicas
    persona_ids = list(set(acceso.solicitud.persona_id for acceso in accesos_criticos))
    
    # Pre-cargar todas las cartas de todas las personas en UNA query
    todas_cartas_query = db.query(CartaResponsabilidad)\
        .options(joinedload(CartaResponsabilidad.solicitud))\
        .join(SolicitudVPN)\
        .filter(SolicitudVPN.persona_id.in_(persona_ids))\
        .order_by(CartaResponsabilidad.fecha_generacion.desc())\
        .all()
    
    # Organizar cartas por persona_id
    cartas_por_persona = {}
    for carta in todas_cartas_query:
        persona_id = carta.solicitud.persona_id
        if persona_id not in cartas_por_persona:
            cartas_por_persona[persona_id] = []
        cartas_por_persona[persona_id].append(carta)
    
    # Pre-cargar todos los accesos relacionados con cartas en UNA query
    solicitud_ids = [carta.solicitud_id for carta in todas_cartas_query]
    accesos_cartas = {}
    if solicitud_ids:
        accesos_por_solicitud = db.query(AccesoVPN)\
            .filter(AccesoVPN.solicitud_id.in_(solicitud_ids))\
            .all()
        accesos_cartas = {acc.solicitud_id: acc for acc in accesos_por_solicitud}
    
    # Procesar accesos individualmente (sin agrupar por persona)
    alertas = []
    
    for acceso in accesos_criticos:
        persona = acceso.solicitud.persona
        persona_id = persona.id
        
        # Obtener cartas pre-cargadas de esta persona
        cartas_persona = cartas_por_persona.get(persona_id, [])
        
        # Analizar las cartas
        cartas_info = []
        tiene_carta_vigente = False
        carta_mas_reciente = None
        anio_carta_actual = None
        
        for carta in cartas_persona:
            acceso_carta = accesos_cartas.get(carta.solicitud_id)
            
            if acceso_carta:
                dias_rest = (acceso_carta.fecha_fin_con_gracia - hoy).days
                
                estado_carta = "VENCIDA"
                if dias_rest > 30:
                    estado_carta = "ACTIVA"
                    tiene_carta_vigente = True
                    if carta_mas_reciente is None or carta.fecha_generacion > carta_mas_reciente:
                        carta_mas_reciente = carta.fecha_generacion
                        anio_carta_actual = carta.anio_carta
                elif dias_rest >= 0: # Incluye 0
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
        
        # Obtener estado de bloqueo de la lista pre-cargada
        bloqueos_ordenados = sorted(acceso.bloqueos, key=lambda b: b.fecha_cambio, reverse=True)
        estado_bloqueo = bloqueos_ordenados[0].estado if bloqueos_ordenados else "DESBLOQUEADO"
        
        # Determinar tipo de alerta
        dias_restantes = (acceso.fecha_fin_con_gracia - hoy).days
        
        if tiene_carta_vigente:
            tipo_alerta = "CON_RENOVACION"
            prioridad = 1
        elif dias_restantes < 0:
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
        
        alertas.append({
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
        })
    
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
        "total_cancelados": cancelados,
        "resumen": {
            "activos": sum(1 for a in alertas if a["estado_bloqueo"] != "BLOQUEADO" and a["dias_restantes_acceso_actual"] >= 0), # Incluye 0 (Vence hoy)
            "vencidos_hoy": sum(1 for a in alertas if a["dias_restantes_acceso_actual"] == 0 and a["estado_bloqueo"] != "BLOQUEADO"),
            "bloqueados": sum(1 for a in alertas if a["estado_bloqueo"] == "BLOQUEADO"),
            "cancelados": cancelados,
            "vencidos_sin_renovacion": sum(1 for a in alertas if a["tipo_alerta"] == "VENCIDO_SIN_RENOVACION"), # < 0
            "por_vencer_urgente": sum(1 for a in alertas if a["tipo_alerta"] == "POR_VENCER_URGENTE"), # 0-7
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
    """Obtener historial completo de cartas de una persona con eager loading"""
    from sqlalchemy.orm import joinedload, selectinload
    
    persona = db.query(Persona).filter(Persona.id == persona_id).first()
    if not persona:
        raise HTTPException(status_code=404, detail="Persona no encontrada")
    
    # Pre-cargar cartas con sus solicitudes
    cartas = db.query(CartaResponsabilidad)\
        .options(joinedload(CartaResponsabilidad.solicitud))\
        .join(SolicitudVPN)\
        .filter(SolicitudVPN.persona_id == persona_id)\
        .order_by(CartaResponsabilidad.fecha_generacion.desc())\
        .all()
    
    hoy = hoy_gt()
    
    # Pre-cargar todos los accesos relacionados en una query
    solicitud_ids = [carta.solicitud_id for carta in cartas]
    accesos_dict = {}
    if solicitud_ids:
        accesos = db.query(AccesoVPN)\
            .options(selectinload(AccesoVPN.bloqueos))\
            .filter(AccesoVPN.solicitud_id.in_(solicitud_ids))\
            .all()
        accesos_dict = {acc.solicitud_id: acc for acc in accesos}
    
    historial = []
    
    for carta in cartas:
        acceso = accesos_dict.get(carta.solicitud_id)
        
        if acceso:
            dias_restantes = (acceso.fecha_fin_con_gracia - hoy).days
            
            estado = "VENCIDA"
            if dias_restantes > 30:
                estado = "ACTIVA"
            elif dias_restantes >= 0: # Incluye 0
                estado = "POR_VENCER"
            
            # Obtener último bloqueo de la lista pre-cargada
            bloqueos_ordenados = sorted(acceso.bloqueos, key=lambda b: b.fecha_cambio, reverse=True)
            estado_bloqueo = bloqueos_ordenados[0].estado if bloqueos_ordenados else "DESBLOQUEADO"
            
            historial.append({
                "carta_id": carta.id,
                "numero_carta": f"{carta.numero_carta}-{carta.anio_carta}",
                "solicitud_id": carta.solicitud_id,
                "fecha_generacion": carta.fecha_generacion,
                "fecha_vencimiento": acceso.fecha_fin_con_gracia,
                "dias_restantes": dias_restantes,
                "estado": estado,
                "acceso_id": acceso.id,
                "estado_bloqueo": estado_bloqueo
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


# ========================================
# NOTIFICACIONES DE VENCIMIENTO (CAMPANA)
# ========================================

@router.get("/notificaciones")
async def obtener_notificaciones_vencimiento(
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Retorna accesos que vencen hoy (no bloqueados) con indicador de carta vigente.
    Usado por la campana de notificaciones en tiempo real.
    """
    from sqlalchemy.orm import joinedload, selectinload

    hoy = hoy_gt()

    # Cargar TODOS los accesos (necesitamos verificar cartas vigentes de cada persona)
    accesos = db.query(AccesoVPN)\
        .options(
            joinedload(AccesoVPN.solicitud).joinedload(SolicitudVPN.persona),
            selectinload(AccesoVPN.bloqueos)
        )\
        .join(SolicitudVPN)\
        .join(Persona)\
        .all()

    solicitud_ids = [a.solicitud_id for a in accesos]
    cartas_map = {}
    if solicitud_ids:
        cartas_q = db.query(CartaResponsabilidad)\
            .filter(CartaResponsabilidad.solicitud_id.in_(solicitud_ids),
                    CartaResponsabilidad.eliminada == False)\
            .all()
        for c in cartas_q:
            cartas_map[c.solicitud_id] = c

    # Construir mapa persona_id → lista de (acceso, estado_bloqueo, dias)
    # para detectar cartas vigentes de cada persona
    persona_accesos: dict = {}
    for a in accesos:
        pid = a.solicitud.persona.id
        blq = sorted(a.bloqueos, key=lambda b: b.fecha_cambio, reverse=True)
        eb  = blq[0].estado if blq else "DESBLOQUEADO"
        d   = (a.fecha_fin_con_gracia - hoy).days
        if pid not in persona_accesos:
            persona_accesos[pid] = []
        persona_accesos[pid].append({"acceso": a, "estado_bloqueo": eb, "dias": d})

    notifs_pendientes = []   # aún no bloqueados → cuentan en el badge
    notifs_bloqueados  = []  # ya bloqueados hoy → sección informativa

    for acceso in accesos:
        persona = acceso.solicitud.persona
        dias = (acceso.fecha_fin_con_gracia - hoy).days

        if dias != 0:
            continue  # solo los que vencen HOY exactamente

        bloqueos_ord = sorted(acceso.bloqueos, key=lambda b: b.fecha_cambio, reverse=True)
        estado_bloqueo = bloqueos_ord[0].estado if bloqueos_ord else "DESBLOQUEADO"

        carta = cartas_map.get(acceso.solicitud_id)
        numero_carta = f"{carta.numero_carta}-{carta.anio_carta}" if carta else "SIN CARTA"

        # ✅ Detectar carta vigente de otra solicitud de esta persona
        tiene_carta_vigente = False
        carta_vigente_numero = ""
        for otro in persona_accesos.get(persona.id, []):
            if otro["acceso"].id != acceso.id \
               and otro["dias"] > 0 \
               and otro["estado_bloqueo"] != "BLOQUEADO":
                otra_carta = cartas_map.get(otro["acceso"].solicitud_id)
                if otra_carta:
                    tiene_carta_vigente = True
                    carta_vigente_numero = f"{otra_carta.numero_carta}-{otra_carta.anio_carta}"
                    break

        entrada = {
            "acceso_id": acceso.id,
            "solicitud_id": acceso.solicitud_id,
            "nip": persona.nip or "—",
            "nombre": f"{persona.nombres} {persona.apellidos}",
            "numero_carta": numero_carta,
            "fecha_fin_original": str(acceso.fecha_fin),
            "fecha_fin_con_gracia": str(acceso.fecha_fin_con_gracia),
            "dias_gracia": acceso.dias_gracia,
            "dias": dias,
            "justificacion": acceso.solicitud.justificacion or "",
            "tiene_carta_vigente": tiene_carta_vigente,
            "carta_vigente_numero": carta_vigente_numero,
        }

        if estado_bloqueo == "BLOQUEADO" and bloqueos_ord:
            # Obtener nombre del usuario que bloqueó
            ub = bloqueos_ord[0]
            usuario_bloqueo = db.query(UsuarioSistema).filter(
                UsuarioSistema.id == ub.usuario_id
            ).first()
            entrada["bloqueado_por"] = usuario_bloqueo.username if usuario_bloqueo else "—"
            entrada["fecha_bloqueo"] = str(ub.fecha_cambio)[:16]  # "YYYY-MM-DD HH:MM"
            entrada["motivo_bloqueo"] = ub.motivo or ""
            notifs_bloqueados.append(entrada)
        else:
            notifs_pendientes.append(entrada)

    return {
        "total": len(notifs_pendientes),   # badge = solo pendientes
        "vencen_hoy": len(notifs_pendientes),
        "notificaciones": notifs_pendientes,
        "bloqueados_hoy": notifs_bloqueados,
    }
