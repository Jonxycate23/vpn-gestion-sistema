"""
Modelo: Bloqueo VPN (separado de vigencia)
"""
from sqlalchemy import (
    Column, Integer, String, DateTime, Text,
    ForeignKey, CheckConstraint
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import enum
from app.core.database import Base


class EstadoBloqueoEnum(str, enum.Enum):
    """Estados de bloqueo"""
    BLOQUEADO = "BLOQUEADO"
    DESBLOQUEADO = "DESBLOQUEADO"


class BloqueoVPN(Base):
    """
    Histórico de bloqueos/desbloqueos
    
    Crítico para auditoría institucional
    Un acceso puede tener múltiples cambios de estado
    El motivo es OBLIGATORIO
    """
    __tablename__ = "bloqueos_vpn"
    
    id = Column(Integer, primary_key=True, index=True)
    acceso_vpn_id = Column(
        Integer,
        ForeignKey("accesos_vpn.id"),
        nullable=False,
        index=True
    )
    estado = Column(String(20), nullable=False, index=True)
    motivo = Column(Text, nullable=False)
    usuario_id = Column(
        Integer,
        ForeignKey("usuarios_sistema.id"),
        nullable=False
    )
    fecha_cambio = Column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        index=True
    )
    
    # Constraints
    __table_args__ = (
        CheckConstraint(
            "estado IN ('BLOQUEADO', 'DESBLOQUEADO')",
            name="check_estado_bloqueo_valido"
        ),
    )
    
    # Relaciones
    acceso = relationship(
        "AccesoVPN",
        back_populates="bloqueos"
    )
    
    usuario = relationship(
        "UsuarioSistema",
        back_populates="bloqueos_realizados"
    )
    
    def __repr__(self):
        return (
            f"<BloqueoVPN(id={self.id}, "
            f"estado='{self.estado}', "
            f"fecha={self.fecha_cambio})>"
        )
