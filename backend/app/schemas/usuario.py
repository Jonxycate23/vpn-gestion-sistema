"""
autenticación y usuarios del sistema
"""
from pydantic import BaseModel, Field, EmailStr, field_validator
from typing import Optional
from datetime import datetime
from enum import Enum


class RolEnum(str, Enum):
    """Roles del sistema"""
    SUPERADMIN = "SUPERADMIN"
    ADMIN = "ADMIN"


# ========================================
# AUTENTICACIÓN
# ========================================

class LoginRequest(BaseModel):
    """Request de login"""
    username: str = Field(..., min_length=3, max_length=50, description="Nombre de usuario")
    password: str = Field(..., min_length=6, description="Contraseña")


class LoginResponse(BaseModel):
    """Response de login"""
    access_token: str = Field(..., description="Token JWT")
    token_type: str = Field(default="bearer", description="Tipo de token")
    usuario: dict = Field(..., description="Datos del usuario")


class ChangePasswordRequest(BaseModel):
    """Request para cambiar contraseña"""
    password_actual: str = Field(..., description="Contraseña actual")
    password_nueva: str = Field(..., min_length=8, description="Nueva contraseña")
    password_confirmacion: str = Field(..., description="Confirmación de nueva contraseña")

    @field_validator('password_confirmacion')
    def passwords_match(cls, v, info):
        if 'password_nueva' in info.data and v != info.data['password_nueva']:
            raise ValueError('Las contraseñas no coinciden')
        return v


# ========================================
# USUARIOS DEL SISTEMA
# ========================================

class UsuarioBase(BaseModel):
    """Base de usuario"""
    username: str = Field(..., min_length=3, max_length=50, description="Nombre de usuario")
    nombre_completo: str = Field(..., min_length=3, max_length=150, description="Nombre completo")
    email: Optional[EmailStr] = Field(None, description="Email")
    rol: RolEnum = Field(..., description="Rol del usuario")
    
    @field_validator('username')
    def username_lowercase(cls, v):
        return v.lower()


class UsuarioCreate(UsuarioBase):
    """Crear usuario"""
    password: str = Field(..., min_length=8, description="Contraseña")


class UsuarioUpdate(BaseModel):
    """Actualizar usuario"""
    nombre_completo: Optional[str] = Field(None, min_length=3, max_length=150)
    email: Optional[EmailStr] = None
    rol: Optional[RolEnum] = None
    activo: Optional[bool] = None


class UsuarioResponse(UsuarioBase):
    """Response de usuario"""
    id: int
    activo: bool
    fecha_creacion: datetime
    fecha_ultimo_login: Optional[datetime] = None

    class Config:
        from_attributes = True


class UsuarioListResponse(BaseModel):
    """Lista de usuarios"""
    usuarios: list[UsuarioResponse]
    total: int