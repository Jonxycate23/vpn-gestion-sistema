"""
Dependencias de autenticación y autorización
"""
from fastapi import Depends, HTTPException, status, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from typing import Optional
from app.core.database import get_db
from app.core.security import verify_token
from app.models import UsuarioSistema, RolEnum

# Bearer token scheme
security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
) -> UsuarioSistema:
    """
    Obtener usuario actual desde el token JWT
    
    Raises:
        HTTPException: Si el token es inválido o el usuario no existe
    """
    token = credentials.credentials
    username = verify_token(token)
    
    if username is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido o expirado",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    usuario = db.query(UsuarioSistema).filter(
        UsuarioSistema.username == username,
        UsuarioSistema.activo == True
    ).first()
    
    if usuario is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario no encontrado o inactivo",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    return usuario


async def get_current_active_user(
    current_user: UsuarioSistema = Depends(get_current_user)
) -> UsuarioSistema:
    """
    Verificar que el usuario esté activo
    """
    if not current_user.activo:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Usuario inactivo"
        )
    return current_user


async def require_superadmin(
    current_user: UsuarioSistema = Depends(get_current_active_user)
) -> UsuarioSistema:
    """
    Requiere rol SUPERADMIN
    
    Raises:
        HTTPException: Si el usuario no es SUPERADMIN
    """
    if current_user.rol != RolEnum.SUPERADMIN.value:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Se requiere rol SUPERADMIN"
        )
    return current_user


async def require_admin_or_superadmin(
    current_user: UsuarioSistema = Depends(get_current_active_user)
) -> UsuarioSistema:
    """
    Requiere rol ADMIN o SUPERADMIN
    
    Raises:
        HTTPException: Si el usuario no tiene permisos
    """
    if current_user.rol not in [RolEnum.ADMIN.value, RolEnum.SUPERADMIN.value]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Se requiere rol ADMIN o SUPERADMIN"
        )
    return current_user


def get_client_ip(request: Request) -> str:
    """
    Obtener IP del cliente
    
    Intenta obtener la IP real considerando proxies
    """
    if "x-forwarded-for" in request.headers:
        return request.headers["x-forwarded-for"].split(",")[0].strip()
    elif "x-real-ip" in request.headers:
        return request.headers["x-real-ip"]
    return request.client.host if request.client else "unknown"
