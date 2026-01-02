"""
Endpoints de Dashboard y reportes
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text
from app.core.database import get_db
from app.api.dependencies.auth import get_current_active_user
from app.models import UsuarioSistema, Persona
from app.schemas import DashboardVencimientos

router = APIRouter()


@router.get("/vencimientos", response_model=DashboardVencimientos)
async def obtener_dashboard_vencimientos(
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Obtener dashboard de vencimientos
    
    Retorna resumen ejecutivo de estados de accesos VPN
    """
    # Usar la vista creada en la BD
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
    """
    Obtener lista de accesos actuales CON NIP
    
    Usa la vista consolidada de la BD y trae el NIP desde la tabla personas
    """
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
    
    # Traer el NIP desde la tabla personas
    accesos_list = []
    for row in result:
        persona_id = row[0]
        
        # Obtener el NIP de la tabla personas
        persona = db.query(Persona).filter(Persona.id == persona_id).first()
        nip = persona.nip if persona else None
        
        accesos_list.append({
            "persona_id": row[0],
            "dpi": row[1],
            "nip": nip,              # ← NIP traído desde la tabla personas
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


@router.post("/actualizar-estados")
async def actualizar_estados_vigencia(
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Ejecutar funciones automáticas de actualización
    
    - Actualiza estados de vigencia
    - Genera alertas de vencimiento
    
    **Requiere rol ADMIN o SUPERADMIN**
    """
    try:
        # Actualizar estados de vigencia
        db.execute(text("SELECT actualizar_estado_vigencia()"))
        
        # Generar alertas
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