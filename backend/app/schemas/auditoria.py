"""
Auditoría
"""
from pydantic import BaseModel, Field
from typing import Optional, Any
from datetime import datetime, date


class AuditoriaEventoResponse(BaseModel):
    """Response de evento de auditoría"""
    id: int
    usuario_id: Optional[int] = None
    usuario_nombre: Optional[str] = None
    accion: str
    entidad: str
    entidad_id: Optional[int] = None
    detalle_json: Optional[dict[str, Any]] = None
    ip_origen: Optional[str] = None
    fecha: datetime

    class Config:
        from_attributes = True


class AuditoriaFiltros(BaseModel):
    """Filtros para búsqueda de auditoría"""
    fecha_inicio: Optional[date] = Field(None, description="Fecha inicio")
    fecha_fin: Optional[date] = Field(None, description="Fecha fin")
    usuario_id: Optional[int] = Field(None, description="ID del usuario")
    accion: Optional[str] = Field(None, description="Acción específica")
    entidad: Optional[str] = Field(None, description="Tipo de entidad")


class AlertaResponse(BaseModel):
    """Response de alerta"""
    id: int
    tipo: str
    acceso_vpn_id: Optional[int] = None
    mensaje: str
    fecha_generacion: date
    leida: bool
    fecha_lectura: Optional[datetime] = None
    
    # Información del acceso
    persona_nombres: Optional[str] = None
    persona_apellidos: Optional[str] = None
    persona_dpi: Optional[str] = None
    dias_restantes: Optional[int] = None

    class Config:
        from_attributes = True


class AlertaMarcarLeida(BaseModel):
    """Marcar alerta como leída"""
    alert_ids: list[int] = Field(..., description="IDs de alertas a marcar como leídas")
