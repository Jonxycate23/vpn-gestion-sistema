"""
comunes y base
"""
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


class ResponseBase(BaseModel):
    """Respuesta base para todos los endpoints"""
    success: bool = Field(default=True, description="Indica si la operación fue exitosa")
    message: Optional[str] = Field(default=None, description="Mensaje descriptivo")


class PaginationParams(BaseModel):
    """Parámetros de paginación"""
    page: int = Field(default=1, ge=1, description="Número de página")
    page_size: int = Field(default=50, ge=1, le=100, description="Elementos por página")


class PaginatedResponse(BaseModel):
    """Respuesta paginada"""
    total: int = Field(description="Total de registros")
    page: int = Field(description="Página actual")
    page_size: int = Field(description="Elementos por página")
    total_pages: int = Field(description="Total de páginas")
    items: list = Field(description="Lista de elementos")


class AuditoriaBase(BaseModel):
    """Información de auditoría en respuestas"""
    fecha_creacion: Optional[datetime] = None
    usuario_creacion: Optional[str] = None
    fecha_modificacion: Optional[datetime] = None
    usuario_modificacion: Optional[str] = None

    class Config:
        from_attributes = True
