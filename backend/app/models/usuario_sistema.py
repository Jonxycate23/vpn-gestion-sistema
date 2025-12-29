"""
Modelo: Usuario del Sistema (autenticación interna)
"""
from sqlalchemy import Column, Integer, String, Boolean, DateTime, Enum, CheckConstraint
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import enum
from app.core.database import Base


class RolEnum(str, enum.Enum):
    """Roles de usuario"""
    SUPERADMIN = "SUPERADMIN"
    ADMIN = "ADMIN"


class UsuarioSistema(Base):
    """
    Usuarios internos que operan el sistema
    
    SUPERADMIN: configuración, auditoría, gestión de usuarios
    ADMIN: operaciones diarias, gestión de solicitudes
    """
    __tablename__ = "usuarios_sistema"
    
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, nullable=False, index=True)
    password_hash = Column(String, nullable=False)
    nombre_completo = Column(String(150), nullable=False)
    email = Column(String(150))
    rol = Column(String(20), nullable=False)
    activo = Column(Boolean, nullable=False, default=True, index=True)
    fecha_creacion = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    fecha_ultimo_login = Column(DateTime(timezone=True))
    
    # Constraint para validar rol
    __table_args__ = (
        CheckConstraint("rol IN ('SUPERADMIN', 'ADMIN')", name="check_rol_valido"),
        CheckConstraint("username = LOWER(username)", name="check_username_lowercase"),
    )
    
    # Relaciones
    solicitudes_registradas = relationship(
        "SolicitudVPN",
        foreign_keys="SolicitudVPN.usuario_registro_id",
        back_populates="usuario_registro"
    )
    
    accesos_creados = relationship(
        "AccesoVPN",
        foreign_keys="AccesoVPN.usuario_creacion_id",
        back_populates="usuario_creacion"
    )
    
    bloqueos_realizados = relationship(
        "BloqueoVPN",
        back_populates="usuario"
    )
    
    comentarios = relationship(
        "ComentarioAdmin",
        back_populates="usuario"
    )
    
    eventos_auditoria = relationship(
        "AuditoriaEvento",
        back_populates="usuario"
    )
    
    def __repr__(self):
        return f"<UsuarioSistema(username='{self.username}', rol='{self.rol}')>"
