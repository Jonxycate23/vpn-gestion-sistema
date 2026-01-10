"""
Endpoints de Gestión de Usuarios del Sistema - VERSIÓN FINAL
📍 Ubicación: backend/app/api/endpoints/usuarios.py
✅ Compatible con el servicio
"""
from fastapi import APIRouter, Depends, status, Request
from sqlalchemy.orm import Session
from typing import Optional
from pydantic import BaseModel, EmailStr
from app.core.database import get_db
from app.schemas import ResponseBase
from app.services.usuarios import UsuarioService
from app.api.dependencies.auth import (
    get_current_active_user, 
    require_superadmin,
    get_client_ip
)
from app.models import UsuarioSistema

router = APIRouter()


# ========================================
# SCHEMAS
# ========================================

class UsuarioCreateRequest(BaseModel):
    """Request para crear usuario"""
    nombres: str
    apellidos: str
    email: Optional[EmailStr] = None
    password: str
    rol: str


# ========================================
# LISTAR USUARIOS
# ========================================

@router.get("/", response_model=dict)
async def listar_usuarios(
    skip: int = 0,
    limit: int = 50,
    activo: Optional[bool] = None,
    current_user: UsuarioSistema = Depends(require_superadmin),
    db: Session = Depends(get_db)
):
    """
    Listar usuarios del sistema
    
    **Requiere rol SUPERADMIN**
    """
    usuarios, total = UsuarioService.listar_usuarios(
        db=db,
        skip=skip,
        limit=limit,
        activo=activo
    )
    
    return {
        "total": total,
        "usuarios": [
            {
                "id": u.id,
                "username": u.username,
                "nombre_completo": u.nombre_completo,
                "email": u.email,
                "rol": u.rol,
                "activo": u.activo,
                "fecha_creacion": u.fecha_creacion,
                "fecha_ultimo_login": u.fecha_ultimo_login
            }
            for u in usuarios
        ]
    }


# ========================================
# CREAR USUARIO
# ========================================

@router.post("/", response_model=dict, status_code=status.HTTP_201_CREATED)
async def crear_usuario(
    data: UsuarioCreateRequest,
    request: Request,
    current_user: UsuarioSistema = Depends(require_superadmin),
    db: Session = Depends(get_db)
):
    """
    Crear nuevo usuario del sistema
    
    - **nombres**: Nombres del usuario
    - **apellidos**: Apellidos del usuario
    - **email**: Email del usuario (opcional)
    - **password**: Contraseña inicial
    - **rol**: ADMIN o SUPERADMIN
    
    El username se genera automáticamente:
    - Primera letra del nombre + primer apellido
    - Ejemplo: "Juan García" → jgarcia
    
    **Requiere rol SUPERADMIN**
    """
    ip_origen = get_client_ip(request)
    
    # Validar rol
    if data.rol not in ['ADMIN', 'SUPERADMIN']:
        from fastapi import HTTPException
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Rol inválido. Debe ser ADMIN o SUPERADMIN"
        )
    
    # Validar contraseña
    if len(data.password) < 6:
        from fastapi import HTTPException
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La contraseña debe tener al menos 6 caracteres"
        )
    
    try:
        usuario, username = UsuarioService.crear_usuario(
            db=db,
            nombres=data.nombres,
            apellidos=data.apellidos,
            email=data.email,
            password=data.password,
            rol=data.rol,
            usuario_creador_id=current_user.id,
            ip_origen=ip_origen
        )
        
        return {
            "success": True,
            "message": "Usuario creado exitosamente",
            "usuario": {
                "id": usuario.id,
                "username": username,
                "nombre_completo": usuario.nombre_completo,
                "email": usuario.email,
                "rol": usuario.rol
            }
        }
    except Exception as e:
        from fastapi import HTTPException
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al crear usuario: {str(e)}"
        )


# ========================================
# ACTIVAR/DESACTIVAR USUARIO
# ========================================

@router.put("/{usuario_id}/toggle-activo", response_model=ResponseBase)
async def toggle_usuario_activo(
    usuario_id: int,
    activo: bool,
    request: Request,
    current_user: UsuarioSistema = Depends(require_superadmin),
    db: Session = Depends(get_db)
):
    """
    Activar o desactivar usuario
    
    **Requiere rol SUPERADMIN**
    """
    ip_origen = get_client_ip(request)
    
    usuario = UsuarioService.activar_desactivar(
        db=db,
        usuario_id=usuario_id,
        activo=activo,
        usuario_modificador_id=current_user.id,
        ip_origen=ip_origen
    )
    
    estado = "activado" if activo else "desactivado"
    
    return ResponseBase(
        success=True,
        message=f"Usuario {estado} exitosamente"
    )


# ========================================
# OBTENER USUARIO POR ID
# ========================================

@router.get("/{usuario_id}", response_model=dict)
async def obtener_usuario(
    usuario_id: int,
    current_user: UsuarioSistema = Depends(require_superadmin),
    db: Session = Depends(get_db)
):
    """
    Obtener detalles de un usuario
    
    **Requiere rol SUPERADMIN**
    """
    usuario = db.query(UsuarioSistema).filter(
        UsuarioSistema.id == usuario_id
    ).first()
    
    if not usuario:
        from fastapi import HTTPException
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado"
        )
    
    return {
        "id": usuario.id,
        "username": usuario.username,
        "nombre_completo": usuario.nombre_completo,
        "email": usuario.email,
        "rol": usuario.rol,
        "activo": usuario.activo,
        "fecha_creacion": usuario.fecha_creacion,
        "fecha_ultimo_login": usuario.fecha_ultimo_login
    }


# ========================================
# CAMBIAR CONTRASEÑA (Usuario mismo)
# ========================================

@router.put("/me/cambiar-password", response_model=ResponseBase)
async def cambiar_mi_password(
    password_actual: str,
    password_nueva: str,
    request: Request,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Cambiar mi propia contraseña
    """
    ip_origen = get_client_ip(request)
    
    UsuarioService.cambiar_password(
        db=db,
        usuario_id=current_user.id,
        password_actual=password_actual,
        password_nueva=password_nueva,
        ip_origen=ip_origen
    )
    
    return ResponseBase(
        success=True,
        message="Contraseña cambiada exitosamente"
    )


# ========================================
# RESETEAR CONTRASEÑA (SUPERADMIN)
# ========================================

@router.put("/{usuario_id}/resetear-password", response_model=ResponseBase)
async def resetear_password_usuario(
    usuario_id: int,
    password_nueva: str,
    request: Request,
    current_user: UsuarioSistema = Depends(require_superadmin),
    db: Session = Depends(get_db)
):
    """
    Resetear contraseña de un usuario
    
    **Requiere rol SUPERADMIN**
    """
    ip_origen = get_client_ip(request)
    
    UsuarioService.resetear_password(
        db=db,
        usuario_id=usuario_id,
        password_nueva=password_nueva,
        usuario_admin_id=current_user.id,
        ip_origen=ip_origen
    )
    
    return ResponseBase(
        success=True,
        message="Contraseña reseteada exitosamente"
    )