"""
Modelo: Acceso VPN (control de vigencia)
"""
from sqlalchemy import (
    Column, Integer, Date, DateTime, String, 
    ForeignKey, CheckConstraint
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import enum
from app.core.database import Base


class EstadoVigenciaEnum(str, enum.Enum):
    """Estados de vigencia"""
    ACTIVO = "ACTIVO"
    POR_VENCER = "POR_VENCER"
    VENCIDO = "VENCIDO"


class AccesoVPN(Base):
    """
    Control real de vigencia técnica
    
    Separado de la solicitud para mantener historial
    La vigencia estándar es de 12 meses
    Puede tener días de gracia adicionales
    """
    __tablename__ = "accesos_vpn"
    
    id = Column(Integer, primary_key=True, index=True)
    solicitud_id = Column(
        Integer, 
        ForeignKey("solicitudes_vpn.id"), 
        nullable=False,
        index=True
    )
    fecha_inicio = Column(Date, nullable=False, index=True)
    fecha_fin = Column(Date, nullable=False, index=True)
    dias_gracia = Column(Integer, default=0)
    fecha_fin_con_gracia = Column(Date, index=True)
    estado_vigencia = Column(String(20), nullable=False, index=True)
    usuario_creacion_id = Column(
        Integer,
        ForeignKey("usuarios_sistema.id"),
        nullable=False
    )
    fecha_creacion = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    
    # Constraints
    __table_args__ = (
        CheckConstraint(
            "estado_vigencia IN ('ACTIVO', 'POR_VENCER', 'VENCIDO')",
            name="check_estado_vigencia_valido"
        ),
    )
    
    # Relaciones
    solicitud = relationship(
        "SolicitudVPN",
        back_populates="acceso"
    )
    
    usuario_creacion = relationship(
        "UsuarioSistema",
        foreign_keys=[usuario_creacion_id],
        back_populates="accesos_creados"
    )
    
    bloqueos = relationship(
        "BloqueoVPN",
        back_populates="acceso",
        cascade="all, delete-orphan",
        order_by="BloqueoVPN.fecha_cambio.desc()"
    )
    
    alertas = relationship(
        "AlertaSistema",
        back_populates="acceso",
        cascade="all, delete-orphan"
    )
    
    @property
    def estado_bloqueo_actual(self) -> str:
        """Obtener estado actual de bloqueo"""
        if self.bloqueos:
            return self.bloqueos[0].estado
        return "DESBLOQUEADO"
    
    def __repr__(self):
        return (
            f"<AccesoVPN(id={self.id}, "
            f"vigencia='{self.estado_vigencia}', "
            f"fin={self.fecha_fin})>"
        )
