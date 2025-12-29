"""
Schemas de Documentos y Archivos
"""
from pydantic import BaseModel, Field
from typing import Optional
from datetime import date, datetime
from enum import Enum


class TipoCartaEnum(str, Enum):
    """Tipos de carta"""
    RESPONSABILIDAD = "RESPONSABILIDAD"
    PRORROGA = "PRORROGA"
    OTRO = "OTRO"


# ========================================
# CARTA DE RESPONSABILIDAD
# ========================================

class CartaBase(BaseModel):
    """Base de carta"""
    solicitud_id: int = Field(..., description="ID de la solicitud")
    tipo: TipoCartaEnum = Field(..., description="Tipo de carta")
    fecha_generacion: date = Field(..., description="Fecha de generación")


class CartaCreate(CartaBase):
    """Crear carta"""
    pass


class CartaResponse(CartaBase):
    """Response de carta"""
    id: int
    generada_por_usuario_nombre: str
    cantidad_archivos: int = Field(default=0, description="Cantidad de archivos adjuntos")

    class Config:
        from_attributes = True


# ========================================
# ARCHIVO ADJUNTO
# ========================================

class ArchivoResponse(BaseModel):
    """Response de archivo"""
    id: int
    carta_id: int
    nombre_archivo: str
    tipo_mime: Optional[str] = None
    tamano_bytes: Optional[int] = None
    hash_integridad: Optional[str] = None
    fecha_subida: datetime
    usuario_subida_nombre: str

    class Config:
        from_attributes = True


class ArchivoUploadResponse(BaseModel):
    """Response después de subir archivo"""
    archivo_id: int
    nombre_archivo: str
    tamano_bytes: int
    hash_integridad: str
    mensaje: str = "Archivo subido exitosamente"


# ========================================
# COMENTARIO ADMINISTRATIVO
# ========================================

class ComentarioCreate(BaseModel):
    """Crear comentario"""
    entidad: str = Field(..., description="PERSONA, SOLICITUD, ACCESO, BLOQUEO")
    entidad_id: int = Field(..., description="ID de la entidad")
    comentario: str = Field(..., min_length=5, description="Comentario")


class ComentarioResponse(BaseModel):
    """Response de comentario"""
    id: int
    entidad: str
    entidad_id: int
    comentario: str
    usuario_nombre: str
    fecha: datetime

    class Config:
        from_attributes = True
