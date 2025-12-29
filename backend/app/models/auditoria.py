"""
Modelos: Auditoría y Comentarios Administrativos
"""
from sqlalchemy import (
    Column, Integer, String, DateTime, Text,
    ForeignKey, CheckConstraint
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from sqlalchemy.dialects.postgresql import JSONB
from app.core.database import Base


class ComentarioAdmin(Base):
    """
    Bitácora operativa humana
    
    Contexto adicional que no está en auditoría automática
    Útil para explicar decisiones administrativas
    """
    __tablename__ = "comentarios_admin"
    
    id = Column(Integer, primary_key=True, index=True)
    entidad = Column(String(30), nullable=False, index=True)
    entidad_id = Column(Integer, nullable=False, index=True)
    comentario = Column(Text, nullable=False)
    usuario_id = Column(
        Integer,
        ForeignKey("usuarios_sistema.id"),
        nullable=False
    )
    fecha = Column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        index=True
    )
    
    # Constraints
    __table_args__ = (
        CheckConstraint(
            "entidad IN ('PERSONA', 'SOLICITUD', 'ACCESO', 'BLOQUEO')",
            name="check_entidad_comentario_valida"
        ),
    )
    
    # Relaciones
    usuario = relationship(
        "UsuarioSistema",
        back_populates="comentarios"
    )
    
    def __repr__(self):
        return (
            f"<ComentarioAdmin(id={self.id}, "
            f"entidad='{self.entidad}', "
            f"entidad_id={self.entidad_id})>"
        )


class AuditoriaEvento(Base):
    """
    Auditoría completa del sistema - INMUTABLE
    
    CRÍTICO: Esta tabla NUNCA se edita ni elimina
    Registro completo de todas las acciones
    Legalmente defendible ante contraloría
    """
    __tablename__ = "auditoria_eventos"
    
    id = Column(Integer, primary_key=True, index=True)
    usuario_id = Column(
        Integer,
        ForeignKey("usuarios_sistema.id"),
        index=True
    )
    accion = Column(String(50), nullable=False, index=True)
    entidad = Column(String(30), nullable=False, index=True)
    entidad_id = Column(Integer, index=True)
    detalle_json = Column(JSONB)
    ip_origen = Column(String(50))
    fecha = Column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        index=True
    )
    
    # Relaciones
    usuario = relationship(
        "UsuarioSistema",
        back_populates="eventos_auditoria"
    )
    
    def __repr__(self):
        return (
            f"<AuditoriaEvento(id={self.id}, "
            f"accion='{self.accion}', "
            f"entidad='{self.entidad}', "
            f"fecha={self.fecha})>"
        )
