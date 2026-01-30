"""
Acceso VPN y Bloqueo
"""
from pydantic import BaseModel, Field
from typing import Optional
from datetime import date, datetime
from enum import Enum


class EstadoVigenciaEnum(str, Enum):
    """Estados de vigencia"""
    ACTIVO = "ACTIVO"
    POR_VENCER = "POR_VENCER"
    VENCIDO = "VENCIDO"


class EstadoBloqueoEnum(str, Enum):
    """Estados de bloqueo"""
    BLOQUEADO = "BLOQUEADO"
    DESBLOQUEADO = "DESBLOQUEADO"


# ========================================
# ACCESO VPN
# ========================================

class AccesoBase(BaseModel):
    """Base de acceso"""
    fecha_inicio: date = Field(..., description="Fecha de inicio del acceso")
    dias_gracia: int = Field(default=0, ge=0, le=90, description="Días de gracia")


class AccesoCreate(AccesoBase):
    """Crear acceso (usado internamente al aprobar solicitud)"""
    solicitud_id: int


class AccesoProrrogar(BaseModel):
    """Prorrogar acceso"""
    dias_adicionales: int = Field(..., ge=1, le=90, description="Días adicionales de prórroga")
    motivo: str = Field(..., min_length=10, description="Motivo de la prórroga")


class AccesoResponse(AccesoBase):
    """Response de acceso"""
    id: int
    solicitud_id: int
    fecha_fin: date
    fecha_fin_con_gracia: date
    estado_vigencia: EstadoVigenciaEnum
    fecha_creacion: datetime
    usuario_creacion_nombre: str
    
    # Información adicional
    dias_restantes: int = Field(..., description="Días restantes (puede ser negativo si vencido)")
    estado_bloqueo: str = Field(..., description="Estado actual de bloqueo")
    
    # Datos de la persona
    persona_id: int
    persona_nombres: str
    persona_apellidos: str
    persona_dpi: str

    class Config:
        from_attributes = True


class AccesoConDetalles(AccesoResponse):
    """Acceso con detalles completos"""
    historial_bloqueos: list = Field(default=[], description="Historial de bloqueos")
    alertas: list = Field(default=[], description="Alertas relacionadas")


# ========================================
# BLOQUEO VPN
# ========================================

class BloqueoCreate(BaseModel):
    """Crear bloqueo"""
    acceso_vpn_id: int = Field(..., description="ID del acceso VPN")
    estado: EstadoBloqueoEnum = Field(..., description="BLOQUEADO o DESBLOQUEADO")
    motivo: str = Field(..., min_length=10, description="Motivo del cambio (OBLIGATORIO)")


class BloqueoResponse(BaseModel):
    """Response de bloqueo"""
    id: int
    acceso_vpn_id: int
    estado: EstadoBloqueoEnum
    motivo: str
    fecha_cambio: datetime
    usuario_nombre: str
    
    # Información del acceso
    persona_nombres: str
    persona_apellidos: str
    persona_dpi: str

    class Config:
        from_attributes = True


# ========================================
# DASHBOARD Y REPORTES
# ========================================

class DashboardVencimientos(BaseModel):
    """Dashboard de vencimientos"""
    activos: int = Field(..., description="Accesos activos")
    por_vencer: int = Field(..., description="Accesos por vencer (30 días)")
    vencidos: int = Field(..., description="Accesos vencidos")
    bloqueados: int = Field(..., description="Accesos bloqueados")
    vencen_esta_semana: int = Field(..., description="Vencen en 7 días")
    vencen_hoy: int = Field(..., description="Vencen hoy")


class AccesoActual(BaseModel):
    """Acceso actual consolidado"""
    acceso_id: int
    persona_id: int
    persona_dpi: str
    persona_nombres: str
    persona_apellidos: str
    persona_institucion: Optional[str]
    solicitud_id: int
    fecha_solicitud: date
    tipo_solicitud: str
    fecha_inicio: date
    fecha_fin: date
    fecha_fin_con_gracia: date
    dias_gracia: int
    estado_vigencia: str
    dias_restantes: int
    estado_bloqueo: Optional[str]
    usuario_registro: str

    class Config:
        from_attributes = True
