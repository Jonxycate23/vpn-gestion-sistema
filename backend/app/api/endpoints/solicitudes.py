"""
Endpoints de gestión de Solicitudes VPN
INCLUYE: Búsqueda por DPI para autocompletado
"""
from fastapi import APIRouter, Depends, status, Request, Query
from sqlalchemy.orm import Session
from typing import Optional
from datetime import date
from app.core.database import get_db
from app.schemas import (
    SolicitudCreate,
    SolicitudAprobar,
    SolicitudRechazar,
    SolicitudResponse,
    PersonaCreate,
    PersonaUpdate,
    ResponseBase
)
from app.services.solicitudes import SolicitudService
from app.services.personas import PersonaService
from app.api.dependencies.auth import get_current_active_user, get_client_ip
from app.models import UsuarioSistema

router = APIRouter()


# ========================================
# BÚSQUEDA POR DPI (para nueva solicitud)
# ========================================

@router.get("/buscar-dpi/{dpi}", response_model=dict)
async def buscar_persona_por_dpi(
    dpi: str,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Buscar persona por DPI - retorna datos completos si existe
    
    Usado en el flujo de nueva solicitud para autocompletar datos
    """
    persona = PersonaService.obtener_por_dpi(db=db, dpi=dpi)
    
    if persona is None:
        return {"existe": False}
    
    # Contar solicitudes
    from app.models import SolicitudVPN
    total_solicitudes = db.query(SolicitudVPN).filter(
        SolicitudVPN.persona_id == persona.id
    ).count()
    
    return {
        "existe": True,
        "id": persona.id,
        "dpi": persona.dpi,
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
# CREAR/ACTUALIZAR PERSONA (desde solicitud)
# ========================================

@router.post("/persona", response_model=dict, status_code=status.HTTP_200_OK)
async def crear_o_actualizar_persona(
    data: PersonaCreate,
    request: Request,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Crear nueva persona o actualizar si ya existe
    
    Solo actualiza campos editables:
    - email
    - cargo
    - telefono
    - institucion
    """
    ip_origen = get_client_ip(request)
    
    # Buscar si existe
    persona_existente = PersonaService.obtener_por_dpi(db=db, dpi=data.dpi)
    
    if persona_existente:
        # Actualizar solo campos editables
        update_data = PersonaUpdate(
            email=data.email,
            cargo=data.cargo,
            telefono=data.telefono,
            institucion=data.institucion,
            observaciones=data.observaciones
        )
        
        persona = PersonaService.actualizar(
            db=db,
            persona_id=persona_existente.id,
            data=update_data,
            usuario_id=current_user.id,
            ip_origen=ip_origen
        )
        
        return {
            "success": True,
            "message": "Datos actualizados exitosamente",
            "persona_id": persona.id,
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
    """
    Crear nueva solicitud VPN
    
    - **persona_id**: ID de la persona solicitante
    - **tipo_solicitud**: NUEVA o RENOVACION
    - **justificacion**: Justificación de la solicitud
    """
    ip_origen = get_client_ip(request)
    solicitud = SolicitudService.crear(
        db=db,
        data=data,
        usuario_id=current_user.id,
        ip_origen=ip_origen
    )
    
    # Obtener datos completos para respuesta
    from app.models import Persona
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
    estado: Optional[str] = Query(None, description="APROBADA, RECHAZADA, CANCELADA"),
    tipo: Optional[str] = Query(None, description="NUEVA, RENOVACION"),
    persona_id: Optional[int] = Query(None, description="Filtrar por persona"),
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Listar solicitudes con filtros
    """
    solicitudes, total = SolicitudService.listar(
        db=db,
        skip=skip,
        limit=limit,
        estado=estado,
        tipo=tipo,
        persona_id=persona_id
    )
    
    # Enriquecer con datos de persona y usuario
    result = []
    for sol in solicitudes:
        sol_dict = {
            "id": sol.id,
            "persona_id": sol.persona_id,
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
    """
    Obtener solicitud por ID con todos los detalles
    """
    solicitud = SolicitudService.obtener_por_id(db=db, solicitud_id=solicitud_id)
    if not solicitud:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
    
    result = {
        "id": solicitud.id,
        "persona_id": solicitud.persona_id,
        "fecha_solicitud": solicitud.fecha_solicitud,
        "tipo_solicitud": solicitud.tipo_solicitud,
        "justificacion": solicitud.justificacion,
        "estado": solicitud.estado,
        "comentarios_admin": solicitud.comentarios_admin,
        "fecha_registro": solicitud.fecha_registro,
        "persona": {
            "id": solicitud.persona.id,
            "dpi": solicitud.persona.dpi,
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


@router.post("/{solicitud_id}/aprobar", response_model=dict)
async def aprobar_solicitud(
    solicitud_id: int,
    data: SolicitudAprobar,
    request: Request,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Aprobar solicitud VPN
    
    Crea automáticamente el acceso VPN con vigencia de 12 meses
    """
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
    """
    Rechazar solicitud VPN
    """
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