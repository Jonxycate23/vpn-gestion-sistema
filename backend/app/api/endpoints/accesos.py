"""
Endpoints de gestión de Accesos VPN y Bloqueos
"""
from http.client import HTTPException
from fastapi import APIRouter, Depends, status, Request
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.schemas import (
    AccesoProrrogar,
    BloqueoCreate,
    BloqueoResponse,
    ResponseBase
)
from app.services.accesos import AccesoService, BloqueoService
from app.api.dependencies.auth import get_current_active_user, get_client_ip
from app.models import UsuarioSistema

router = APIRouter()


@router.get("/{acceso_id}", response_model=dict)
async def obtener_acceso(
    acceso_id: int,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Obtener detalles de un acceso VPN
    """
    from datetime import date
    
    acceso = AccesoService.obtener_por_id(db=db, acceso_id=acceso_id)
    if not acceso:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Acceso no encontrado")
    
    # Obtener estado de bloqueo
    estado_bloqueo = AccesoService.obtener_estado_bloqueo(db, acceso_id)
    
    return {
        "id": acceso.id,
        "solicitud_id": acceso.solicitud_id,
        "fecha_inicio": acceso.fecha_inicio,
        "fecha_fin": acceso.fecha_fin,
        "dias_gracia": acceso.dias_gracia,
        "fecha_fin_con_gracia": acceso.fecha_fin_con_gracia,
        "estado_vigencia": acceso.estado_vigencia,
        "dias_restantes": (acceso.fecha_fin_con_gracia - date.today()).days,
        "estado_bloqueo": estado_bloqueo,
        "persona": {
            "id": acceso.solicitud.persona.id,
            "dpi": acceso.solicitud.persona.dpi,
            "nombres": acceso.solicitud.persona.nombres,
            "apellidos": acceso.solicitud.persona.apellidos
        }
    }


@router.post("/{acceso_id}/prorrogar", response_model=ResponseBase)
async def prorrogar_acceso(
    acceso_id: int,
    data: AccesoProrrogar,
    request: Request,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Prorrogar acceso VPN (agregar días de gracia)
    
    - **dias_adicionales**: Días adicionales a agregar
    - **motivo**: Justificación de la prórroga
    """
    ip_origen = get_client_ip(request)
    acceso = AccesoService.prorrogar(
        db=db,
        acceso_id=acceso_id,
        data=data,
        usuario_id=current_user.id,
        ip_origen=ip_origen
    )
    
    return ResponseBase(
        success=True,
        message=f"Prórroga de {data.dias_adicionales} días agregada. Nueva fecha fin: {acceso.fecha_fin_con_gracia}"
    )


@router.post("/bloquear", response_model=ResponseBase, status_code=status.HTTP_201_CREATED)
async def cambiar_estado_bloqueo(
    data: BloqueoCreate,
    request: Request,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Bloquear o desbloquear acceso VPN
    
    - **acceso_vpn_id**: ID del acceso a modificar
    - **estado**: BLOQUEADO o DESBLOQUEADO
    - **motivo**: Justificación del cambio (OBLIGATORIO)
    """
    ip_origen = get_client_ip(request)
    bloqueo = BloqueoService.cambiar_estado(
        db=db,
        data=data,
        usuario_id=current_user.id,
        ip_origen=ip_origen
    )
    
    accion = "bloqueado" if data.estado == "BLOQUEADO" else "desbloqueado"
    
    return ResponseBase(
        success=True,
        message=f"Acceso {accion} exitosamente"
    )

"""
Endpoint para obtener bloqueos de un acceso VPN
📍 Agregar a: backend/app/api/endpoints/accesos.py

AGREGAR ESTE ENDPOINT AL ARCHIVO EXISTENTE
"""

# ========================================
# OBTENER BLOQUEOS DE UN ACCESO
# ========================================

@router.get("/{acceso_id}/bloqueos", response_model=dict)
async def obtener_bloqueos_acceso(
    acceso_id: int,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Obtener historial de bloqueos de un acceso VPN
    """
    from app.models import BloqueoVPN, AccesoVPN, UsuarioSistema as Usuario
    
    # Verificar que el acceso existe
    acceso = db.query(AccesoVPN).filter(AccesoVPN.id == acceso_id).first()
    if not acceso:
        raise HTTPException(status_code=404, detail="Acceso VPN no encontrado")
    
    # Obtener bloqueos ordenados por fecha (más reciente primero)
    bloqueos = db.query(BloqueoVPN).filter(
        BloqueoVPN.acceso_vpn_id == acceso_id
    ).order_by(BloqueoVPN.fecha_bloqueo.desc()).all()
    
    # Formatear respuesta
    resultado = []
    for bloqueo in bloqueos:
        # Obtener nombre del usuario que realizó el bloqueo
        usuario_nombre = None
        if bloqueo.usuario_bloqueo_id:
            usuario = db.query(Usuario).filter(Usuario.id == bloqueo.usuario_bloqueo_id).first()
            if usuario:
                usuario_nombre = usuario.nombre_completo
        
        resultado.append({
            "id": bloqueo.id,
            "fecha_bloqueo": bloqueo.fecha_bloqueo,
            "estado": bloqueo.estado,
            "motivo": bloqueo.motivo,
            "usuario_bloqueo": usuario_nombre,
            "usuario_bloqueo_id": bloqueo.usuario_bloqueo_id
        })
    
    return {
        "success": True,
        "acceso_id": acceso_id,
        "total_bloqueos": len(resultado),
        "bloqueos": resultado
    }



@router.get("/{acceso_id}/historial-bloqueos", response_model=list[BloqueoResponse])
async def obtener_historial_bloqueos(
    acceso_id: int,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Obtener historial completo de bloqueos de un acceso
    """
    bloqueos = BloqueoService.obtener_historial(db=db, acceso_id=acceso_id)
    
    result = []
    for bloqueo in bloqueos:
        result.append({
            "id": bloqueo.id,
            "acceso_vpn_id": bloqueo.acceso_vpn_id,
            "estado": bloqueo.estado,
            "motivo": bloqueo.motivo,
            "fecha_cambio": bloqueo.fecha_cambio,
            "usuario_nombre": bloqueo.usuario.nombre_completo,
            "persona_nombres": bloqueo.acceso.solicitud.persona.nombres,
            "persona_apellidos": bloqueo.acceso.solicitud.persona.apellidos,
            "persona_dpi": bloqueo.acceso.solicitud.persona.dpi
        })
    
    return result

