"""
Modelos: Alertas, Configuración y otros auxiliares
"""
from sqlalchemy import (
    Column, Integer, String, Date, DateTime, Text, Boolean,
    ForeignKey, CheckConstraint
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import enum
from app.core.database import Base


class TipoAlertaEnum(str, enum.Enum):
    """Tipos de alerta"""
    VENCIMIENTO = "VENCIMIENTO"
    GRACIA = "GRACIA"
    BLOQUEO_PENDIENTE = "BLOQUEO_PENDIENTE"


class AlertaSistema(Base):
    """
    Alertas operativas internas
    
    Para dashboard diario
    No son notificaciones por correo
    """
    __tablename__ = "alertas_sistema"
    
    id = Column(Integer, primary_key=True, index=True)
    tipo = Column(String(30), nullable=False, index=True)
    acceso_vpn_id = Column(
        Integer,
        ForeignKey("accesos_vpn.id"),
        index=True
    )
    mensaje = Column(Text, nullable=False)
    fecha_generacion = Column(Date, nullable=False, index=True)
    leida = Column(Boolean, nullable=False, default=False, index=True)
    fecha_lectura = Column(DateTime(timezone=True))
    
    # Constraints
    __table_args__ = (
        CheckConstraint(
            "tipo IN ('VENCIMIENTO', 'GRACIA', 'BLOQUEO_PENDIENTE')",
            name="check_tipo_alerta_valido"
        ),
    )
    
    # Relaciones
    acceso = relationship(
        "AccesoVPN",
        back_populates="alertas"
    )
    
    def __repr__(self):
        return f"<AlertaSistema(id={self.id}, tipo='{self.tipo}', leida={self.leida})>"


class ImportacionExcel(Base):
    """
    Trazabilidad de importaciones desde Excel
    
    Auditoría de migración de datos
    """
    __tablename__ = "importaciones_excel"
    
    id = Column(Integer, primary_key=True, index=True)
    archivo_origen = Column(String(255))
    fecha_importacion = Column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now()
    )
    usuario_id = Column(
        Integer,
        ForeignKey("usuarios_sistema.id"),
        nullable=False
    )
    registros_procesados = Column(Integer, default=0)
    registros_exitosos = Column(Integer, default=0)
    registros_fallidos = Column(Integer, default=0)
    resultado = Column(Text)
    log_errores = Column(Text)
    
    def __repr__(self):
        return (
            f"<ImportacionExcel(id={self.id}, "
            f"archivo='{self.archivo_origen}', "
            f"exitosos={self.registros_exitosos})>"
        )


class ConfiguracionSistema(Base):
    """
    Configuraciones operativas del sistema
    
    Parámetros modificables sin cambiar código
    """
    __tablename__ = "configuracion_sistema"
    
    id = Column(Integer, primary_key=True, index=True)
    clave = Column(String(100), unique=True, nullable=False, index=True)
    valor = Column(Text, nullable=False)
    descripcion = Column(Text)
    tipo_dato = Column(String(20))
    fecha_modificacion = Column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now()
    )
    modificado_por = Column(
        Integer,
        ForeignKey("usuarios_sistema.id")
    )
    
    # Constraints
    __table_args__ = (
        CheckConstraint(
            "tipo_dato IN ('STRING', 'INTEGER', 'BOOLEAN', 'JSON')",
            name="check_tipo_dato_valido"
        ),
    )
    
    def __repr__(self):
        return f"<ConfiguracionSistema(clave='{self.clave}', valor='{self.valor}')>"


class Catalogo(Base):
    """
    Valores normalizados para listas desplegables
    
    Motivos de bloqueo, tipos de documentos, etc.
    """
    __tablename__ = "catalogos"
    
    id = Column(Integer, primary_key=True, index=True)
    tipo = Column(String(50), nullable=False, index=True)
    codigo = Column(String(50), nullable=False, index=True)
    descripcion = Column(String(200), nullable=False)
    activo = Column(Boolean, nullable=False, default=True)
    
    __table_args__ = (
        CheckConstraint(
            "tipo IN ('MOTIVO_BLOQUEO', 'MOTIVO_DESBLOQUEO', 'TIPO_DOCUMENTO')",
            name="check_tipo_catalogo_valido"
        ),
    )
    
    def __repr__(self):
        return f"<Catalogo(tipo='{self.tipo}', codigo='{self.codigo}')>"


class SesionLogin(Base):
    """
    Control de sesiones activas
    
    Auditoría de accesos al sistema
    """
    __tablename__ = "sesiones_login"
    
    id = Column(Integer, primary_key=True, index=True)
    usuario_id = Column(
        Integer,
        ForeignKey("usuarios_sistema.id"),
        nullable=False,
        index=True
    )
    token_hash = Column(String(64))
    ip_origen = Column(String(50))
    user_agent = Column(Text)
    fecha_inicio = Column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now()
    )
    fecha_expiracion = Column(DateTime(timezone=True))
    activa = Column(Boolean, nullable=False, default=True, index=True)
    
    def __repr__(self):
        return (
            f"<SesionLogin(id={self.id}, "
            f"usuario_id={self.usuario_id}, "
            f"activa={self.activa})>"
        )
