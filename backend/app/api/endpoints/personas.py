"""
Endpoints de gestión de Personas
"""
from fastapi import APIRouter, Depends, status, Request, Query
from sqlalchemy.orm import Session
from typing import Optional
from app.core.database import get_db
from app.schemas import (
    PersonaCreate,
    PersonaUpdate,
    PersonaResponse,
    ResponseBase
)
from app.services.personas import PersonaService
from app.api.dependencies.auth import get_current_active_user, get_client_ip
from app.models import UsuarioSistema

router = APIRouter()


@router.post("/", response_model=PersonaResponse, status_code=status.HTTP_201_CREATED)
async def crear_persona(
    data: PersonaCreate,
    request: Request,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Crear nueva persona (solicitante VPN)
    
    - **dpi**: DPI de 13 dígitos (único)
    - **nombres**: Nombres de la persona
    - **apellidos**: Apellidos de la persona
    """
    ip_origen = get_client_ip(request)
    persona = PersonaService.crear(
        db=db,
        data=data,
        usuario_id=current_user.id,
        ip_origen=ip_origen
    )
    return persona


@router.get("/", response_model=dict)
async def listar_personas(
    skip: int = Query(0, ge=0, description="Número de registros a saltar"),
    limit: int = Query(50, ge=1, le=100, description="Número de registros a retornar"),
    activo: Optional[bool] = Query(None, description="Filtrar por estado activo"),
    busqueda: Optional[str] = Query(None, description="Buscar por DPI, nombres o apellidos"),
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Listar personas con filtros y paginación
    """
    personas, total = PersonaService.listar(
        db=db,
        skip=skip,
        limit=limit,
        activo=activo,
        busqueda=busqueda
    )
    
    return {
        "total": total,
        "page": (skip // limit) + 1,
        "page_size": limit,
        "personas": personas
    }


@router.get("/buscar", response_model=list[PersonaResponse])
async def buscar_personas(
    q: str = Query(..., min_length=3, description="Texto a buscar"),
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Búsqueda rápida de personas
    
    Busca en DPI, nombres y apellidos
    """
    return PersonaService.buscar_por_texto(db=db, query_text=q)


@router.get("/{persona_id}", response_model=PersonaResponse)
async def obtener_persona(
    persona_id: int,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Obtener persona por ID
    """
    persona = PersonaService.obtener_por_id(db=db, persona_id=persona_id)
    if not persona:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Persona no encontrada")
    return persona


@router.get("/dpi/{dpi}", response_model=PersonaResponse)
async def obtener_persona_por_dpi(
    dpi: str,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Obtener persona por DPI
    """
    persona = PersonaService.obtener_por_dpi(db=db, dpi=dpi)
    if not persona:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Persona no encontrada")
    return persona


@router.put("/{persona_id}", response_model=PersonaResponse)
async def actualizar_persona(
    persona_id: int,
    data: PersonaUpdate,
    request: Request,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Actualizar datos de persona
    """
    ip_origen = get_client_ip(request)
    persona = PersonaService.actualizar(
        db=db,
        persona_id=persona_id,
        data=data,
        usuario_id=current_user.id,
        ip_origen=ip_origen
    )
    return persona
