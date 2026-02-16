import secrets
import string
from fastapi import APIRouter, Depends, status, Request, HTTPException
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
    password: Optional[str] = None
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
        "success": True,
        "usuarios": [
            {
                "id": u.id,
                "username": u.username,
                "nombre_completo": u.nombre_completo,
                "email": u.email,
                "rol": u.rol,
                "activo": u.activo,
                "fecha_creacion": u.fecha_creacion.isoformat() if u.fecha_creacion else None,
                "fecha_ultimo_login": u.fecha_ultimo_login.isoformat() if u.fecha_ultimo_login else None
            }
            for u in usuarios
        ],
        "total": total
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
    Crear un nuevo usuario del sistema
    
    **Requiere rol SUPERADMIN**
    """
    # Validar rol
    if data.rol not in ['ADMIN', 'SUPERADMIN']:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Rol inválido. Debe ser ADMIN o SUPERADMIN"
        )
    
    # Generar contraseña si no se provee
    password_final = data.password
    if not password_final:
        alphabet = string.ascii_letters + string.digits + "!@#$%^&*"
        password_final = ''.join(secrets.choice(alphabet) for i in range(12))
    
    # Validar contraseña solo si fue provista manualmente
    if data.password and len(data.password) < 6:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La contraseña debe tener al menos 6 caracteres"
        )
    
    ip_origen = get_client_ip(request)
    
    try:
        usuario, username = UsuarioService.crear_usuario(
            db=db,
            nombres=data.nombres,
            apellidos=data.apellidos,
            email=data.email,
            password=password_final,
            rol=data.rol,
            usuario_creador_id=current_user.id,
            ip_origen=ip_origen
        )
        
        return {
            "success": True,
            "message": "Usuario creado exitosamente",
            "password_inicial": password_final, # Retornamos la password para mostrarla 1 vez
            "usuario": {
                "id": usuario.id,
                "username": usuario.username,
                "nombre_completo": usuario.nombre_completo,
                "email": usuario.email,
                "rol": usuario.rol,
                "activo": usuario.activo
            }
        }
        
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


# ========================================
# OBTENER USUARIO ACTUAL
# ========================================

@router.get("/me", response_model=dict)
async def obtener_usuario_actual(
    current_user: UsuarioSistema = Depends(get_current_active_user)
):
    """
    Obtener información del usuario autenticado
    """
    return {
        "success": True,
        "usuario": {
            "id": current_user.id,
            "username": current_user.username,
            "nombre_completo": current_user.nombre_completo,
            "email": current_user.email,
            "rol": current_user.rol,
            "activo": current_user.activo,
            "fecha_creacion": current_user.fecha_creacion.isoformat() if current_user.fecha_creacion else None,
            "fecha_ultimo_login": current_user.fecha_ultimo_login.isoformat() if current_user.fecha_ultimo_login else None
        }
    }


# ========================================
# CAMBIAR CONTRASEÑA PROPIA
# ========================================

@router.put("/me/cambiar-password", response_model=ResponseBase)
async def cambiar_password_propia(
    password_actual: str,
    password_nueva: str,
    request: Request,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Cambiar la contraseña del usuario autenticado
    """
    ip_origen = get_client_ip(request)
    
    try:
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
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


# ========================================
# ACTIVAR/DESACTIVAR USUARIO
# ========================================

@router.put("/{usuario_id}/toggle-activo", response_model=ResponseBase)
async def toggle_activo_usuario(
    usuario_id: int,
    activo: bool,
    current_user: UsuarioSistema = Depends(require_superadmin),
    db: Session = Depends(get_db)
):
    """
    Activar o desactivar un usuario
    
    **Requiere rol SUPERADMIN**
    """
    try:
        UsuarioService.toggle_activo(db, usuario_id, activo)
        
        return ResponseBase(
            success=True,
            message=f"Usuario {'activado' if activo else 'desactivado'} exitosamente"
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
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


# ========================================
# ELIMINAR USUARIO
# ========================================

@router.delete("/{usuario_id}", response_model=ResponseBase)
async def eliminar_usuario(
    usuario_id: int,
    current_user: UsuarioSistema = Depends(require_superadmin),
    db: Session = Depends(get_db)
):
    """
    Eliminar un usuario del sistema
    
    **Requiere rol SUPERADMIN**
    
    - No se puede eliminar a sí mismo
    - Elimina permanentemente el usuario y sus datos asociados
    """
    # Verificar que no intente eliminarse a sí mismo
    if current_user.id == usuario_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No puedes eliminarte a ti mismo"
        )
    
    try:
        UsuarioService.eliminar_usuario(db, usuario_id)
        return ResponseBase(
            success=True,
            message="Usuario eliminado exitosamente"
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )