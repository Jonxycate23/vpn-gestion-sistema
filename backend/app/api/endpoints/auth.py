"""
Endpoints de autenticación
"""
from fastapi import APIRouter, Depends, status, Request
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.schemas import (
    LoginRequest,
    LoginResponse,
    ChangePasswordRequest,
    ResponseBase
)
from app.services.auth import AuthService
from app.api.dependencies.auth import get_current_active_user, get_client_ip
from app.models import UsuarioSistema

router = APIRouter()


@router.post("/login", response_model=LoginResponse, status_code=status.HTTP_200_OK)
async def login(
    credentials: LoginRequest,
    request: Request,
    db: Session = Depends(get_db)
):
    """
    Login de usuario
    
    Retorna token JWT para autenticación
    """
    ip_origen = get_client_ip(request)
    return AuthService.login(db=db, credentials=credentials, ip_origen=ip_origen)


@router.post("/change-password", response_model=ResponseBase)
async def cambiar_password(
    request_data: ChangePasswordRequest,
    request: Request,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Cambiar contraseña del usuario actual
    """
    ip_origen = get_client_ip(request)
    
    AuthService.cambiar_password(
        db=db,
        usuario=current_user,
        password_actual=request_data.password_actual,
        password_nueva=request_data.password_nueva,
        ip_origen=ip_origen
    )
    
    return ResponseBase(
        success=True,
        message="Contraseña actualizada exitosamente"
    )


@router.get("/me", response_model=dict)
async def obtener_usuario_actual(
    current_user: UsuarioSistema = Depends(get_current_active_user)
):
    """
    Obtener información del usuario actual
    """
    return {
        "id": current_user.id,
        "username": current_user.username,
        "nombre_completo": current_user.nombre_completo,
        "email": current_user.email,
        "rol": current_user.rol,
        "activo": current_user.activo,
        "fecha_creacion": current_user.fecha_creacion,
        "fecha_ultimo_login": current_user.fecha_ultimo_login
    }


@router.post("/logout", response_model=ResponseBase)
async def logout(
    request: Request,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Logout del usuario (registra en auditoría)
    """
    from app.utils.auditoria import AuditoriaService
    
    ip_origen = get_client_ip(request)
    AuditoriaService.registrar_logout(
        db=db,
        usuario=current_user,
        ip_origen=ip_origen
    )
    
    return ResponseBase(
        success=True,
        message="Sesión cerrada exitosamente"
    )
