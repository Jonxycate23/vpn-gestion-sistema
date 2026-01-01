"""
Schemas de Persona (solicitantes VPN) - CON NIP
📍 Ubicación: backend/app/schemas/persona.py
REEMPLAZA COMPLETAMENTE EL ARCHIVO ACTUAL
"""
from pydantic import BaseModel, Field, EmailStr, field_validator
from typing import Optional
from datetime import datetime
import re


class PersonaBase(BaseModel):
    """Base de persona"""
    dpi: str = Field(..., min_length=13, max_length=13, description="DPI de 13 dígitos")
    nip: Optional[str] = Field(None, max_length=20, description="Número de Identificación Policial")
    nombres: str = Field(..., min_length=2, max_length=150, description="Nombres")
    apellidos: str = Field(..., min_length=2, max_length=150, description="Apellidos")
    institucion: Optional[str] = Field(None, max_length=200, description="Institución")
    cargo: Optional[str] = Field(None, max_length=150, description="Cargo")
    telefono: Optional[str] = Field(None, max_length=50, description="Teléfono")
    email: Optional[EmailStr] = Field(None, description="Email")
    observaciones: Optional[str] = Field(None, description="Observaciones")
    
    @field_validator('dpi')
    def validar_dpi(cls, v):
        # Validar que solo contenga números
        if not re.match(r'^\d{13}$', v):
            raise ValueError('DPI debe contener exactamente 13 dígitos numéricos')
        return v
    
    @field_validator('nombres', 'apellidos')
    def validar_nombres(cls, v):
        # Eliminar espacios extra y capitalizar
        return ' '.join(v.split()).title()


class PersonaCreate(PersonaBase):
    """Crear persona"""
    pass


class PersonaUpdate(BaseModel):
    """Actualizar persona"""
    nip: Optional[str] = Field(None, max_length=20)
    nombres: Optional[str] = Field(None, min_length=2, max_length=150)
    apellidos: Optional[str] = Field(None, min_length=2, max_length=150)
    institucion: Optional[str] = Field(None, max_length=200)
    cargo: Optional[str] = Field(None, max_length=150)
    telefono: Optional[str] = Field(None, max_length=50)
    email: Optional[EmailStr] = None
    observaciones: Optional[str] = None
    activo: Optional[bool] = None


class PersonaResponse(PersonaBase):
    """Response de persona"""
    id: int
    activo: bool
    fecha_creacion: datetime
    nombre_completo: str = Field(..., description="Nombre completo concatenado")
    
    # Estadísticas
    total_solicitudes: Optional[int] = Field(None, description="Total de solicitudes")
    solicitudes_activas: Optional[int] = Field(None, description="Solicitudes activas")

    class Config:
        from_attributes = True


class PersonaBusqueda(BaseModel):
    """Búsqueda de persona"""
    query: str = Field(..., min_length=3, description="Búsqueda por DPI, nombres o apellidos")


class PersonaListResponse(BaseModel):
    """Lista de personas"""
    personas: list[PersonaResponse]
    total: int