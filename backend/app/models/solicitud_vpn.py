"""
Modelo: Solicitud VPN (historial administrativo)
ACTUALIZADO: Incluye oficio, providencia y fecha de recepción
"""
from sqlalchemy import (
    Column, Integer, String, Date, DateTime, Text, 
    ForeignKey, CheckConstraint
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import enum
from app.core.database import Base


class TipoSolicitudEnum(str, enum.Enum):
    """Tipos de solicitud"""
    NUEVA = "NUEVA"
    RENOVACION = "RENOVACION"


class EstadoSolicitudEnum(str, enum.Enum):
    """Estados de solicitud"""
    APROBADA = "APROBADA"
    RECHAZADA = "RECHAZADA"
    CANCELADA = "CANCELADA"


class SolicitudVPN(Base):
    """
    Expediente administrativo de solicitudes VPN
    
    NUNCA se sobreescribe, se mantiene historial completo
    Una persona puede tener múltiples solicitudes
    """
    __tablename__ = "solicitudes_vpn"
    
    id = Column(Integer, primary_key=True, index=True)
    persona_id = Column(Integer, ForeignKey("personas.id"), nullable=False, index=True)
    
    # Datos administrativos de la solicitud
    numero_oficio = Column(String(50), index=True)  # Ej: "07-2025"
    numero_providencia = Column(String(50), index=True)  # Ej: "S/N", "3372-2024"
    fecha_recepcion = Column(Date, index=True)  # Fecha real de recepción del oficio
    fecha_solicitud = Column(Date, nullable=False, index=True)  # Fecha del sistema
    
    tipo_solicitud = Column(String(20), nullable=False, index=True)
    justificacion = Column(Text, nullable=False)
    estado = Column(String(20), nullable=False, index=True)
    usuario_registro_id = Column(
        Integer, 
        ForeignKey("usuarios_sistema.id"), 
        nullable=False
    )
    comentarios_admin = Column(Text)
    fecha_registro = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    
    # Constraints
    __table_args__ = (
        CheckConstraint(
            "tipo_solicitud IN ('NUEVA', 'RENOVACION')",
            name="check_tipo_solicitud_valido"
        ),
        CheckConstraint(
            "estado IN ('APROBADA', 'RECHAZADA', 'CANCELADA')",
            name="check_estado_solicitud_valido"
        ),
    )
    
    # Relaciones
    persona = relationship(
        "Persona",
        back_populates="solicitudes"
    )
    
    usuario_registro = relationship(
        "UsuarioSistema",
        foreign_keys=[usuario_registro_id],
        back_populates="solicitudes_registradas"
    )
    
    acceso = relationship(
        "AccesoVPN",
        back_populates="solicitud",
        uselist=False,
        cascade="all, delete-orphan"
    )
    
    cartas = relationship(
        "CartaResponsabilidad",
        back_populates="solicitud",
        cascade="all, delete-orphan"
    )
    
    def __repr__(self):
        return (
            f"<SolicitudVPN(id={self.id}, "
            f"oficio='{self.numero_oficio}', "
            f"tipo='{self.tipo_solicitud}', "
            f"estado='{self.estado}')>"
        )