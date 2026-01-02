"""
Schemas de Solicitud VPN
"""
from pydantic import BaseModel, Field
from typing import Optional
from datetime import date, datetime
from enum import Enum


class TipoSolicitudEnum(str, Enum):
    """Tipos de solicitud"""
    NUEVA = "CREACION"
    RENOVACION = "ACTUALIZACION"


class EstadoSolicitudEnum(str, Enum):
    """Estados de solicitud con workflow"""
    PENDIENTE = "PENDIENTE"      # ⏳ Recién creada, esperando revisión
    APROBADA = "APROBADA"        # ✅ Aprobada, esperando crear carta
    TERMINADA = "TERMINADA"      # ✅ Carta creada y acceso VPN activado
    DENEGADA = "DENEGADA"        # ❌ Rechazada por algún motivo
    CANCELADA = "CANCELADA"      # 🚫 No se presentó o cancelada



# ========================================
# SOLICITUD VPN
# ========================================

class SolicitudBase(BaseModel):
    """Base de solicitud"""
    persona_id: int = Field(..., description="ID de la persona solicitante")
    fecha_solicitud: date = Field(..., description="Fecha de la solicitud")
    tipo_solicitud: TipoSolicitudEnum = Field(..., description="Tipo de solicitud")
    justificacion: str = Field(..., min_length=10, description="Justificación de la solicitud")


class SolicitudCreate(SolicitudBase):
    """Crear solicitud"""
    pass


class SolicitudAprobar(BaseModel):
    """Aprobar solicitud"""
    comentarios_admin: Optional[str] = Field(None, description="Comentarios administrativos")
    dias_gracia: int = Field(default=0, ge=0, le=90, description="Días de gracia adicionales")


class SolicitudRechazar(BaseModel):
    """Rechazar solicitud"""
    motivo: str = Field(..., min_length=10, description="Motivo del rechazo")


class SolicitudResponse(SolicitudBase):
    """Response de solicitud"""
    id: int
    estado: EstadoSolicitudEnum
    comentarios_admin: Optional[str] = None
    fecha_registro: datetime
    usuario_registro_nombre: str = Field(..., description="Nombre del usuario que registró")
    
    # Datos de la persona
    persona_nombres: str
    persona_apellidos: str
    persona_dpi: str
    persona_institucion: Optional[str] = None
    
    # Datos del acceso (si existe)
    acceso_id: Optional[int] = None
    fecha_inicio: Optional[date] = None
    fecha_fin: Optional[date] = None
    estado_vigencia: Optional[str] = None
    dias_restantes: Optional[int] = None

    class Config:
        from_attributes = True


class SolicitudListResponse(BaseModel):
    """Lista de solicitudes"""
    solicitudes: list[SolicitudResponse]
    total: int


class SolicitudConHistorial(SolicitudResponse):
    """Solicitud con historial de accesos"""
    accesos: list = Field(default=[], description="Historial de accesos")
    cartas: list = Field(default=[], description="Cartas de responsabilidad")
    comentarios: list = Field(default=[], description="Comentarios administrativos")
