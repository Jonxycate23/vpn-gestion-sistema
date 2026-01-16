"""
Modelos: Cartas de Responsabilidad y Archivos Adjuntos
📍 ACTUALIZADO: Incluye numero_carta, anio_carta y eliminada
✅ Campo 'eliminada' permite mantener numeración al eliminar/regenerar
"""
from sqlalchemy import (
    Column, Integer, String, Date, DateTime, Text, Boolean,
    ForeignKey, BigInteger, CheckConstraint
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import enum
from app.core.database import Base


class TipoCartaEnum(str, enum.Enum):
    """Tipos de carta"""
    RESPONSABILIDAD = "RESPONSABILIDAD"
    PRORROGA = "PRORROGA"
    OTRO = "OTRO"


class CartaResponsabilidad(Base):
    """
    Metadatos de documentos legales
    
    ACTUALIZADO: Incluye campo 'eliminada' para mantener numeración
    al eliminar y regenerar cartas con datos corregidos
    """
    __tablename__ = "cartas_responsabilidad"
    
    id = Column(Integer, primary_key=True, index=True)
    solicitud_id = Column(
        Integer,
        ForeignKey("solicitudes_vpn.id"),
        nullable=False,
        index=True
    )
    tipo = Column(String(30), nullable=False, index=True)
    fecha_generacion = Column(Date, nullable=False)
    generada_por_usuario_id = Column(
        Integer,
        ForeignKey("usuarios_sistema.id"),
        nullable=False
    )
    numero_carta = Column(Integer, index=True)
    anio_carta = Column(Integer, index=True)
    
    # ✅ NUEVO CAMPO: permite eliminar sin perder el número
    eliminada = Column(Boolean, nullable=False, default=False, index=True)
    
    # Constraints
    __table_args__ = (
        CheckConstraint(
            "tipo IN ('RESPONSABILIDAD', 'PRORROGA', 'OTRO')",
            name="check_tipo_carta_valido"
        ),
    )
    
    # Relaciones
    solicitud = relationship(
        "SolicitudVPN",
        back_populates="cartas"
    )
    
    archivos = relationship(
        "ArchivoAdjunto",
        back_populates="carta",
        cascade="all, delete-orphan"
    )
    
    def __repr__(self):
        estado = " (ELIMINADA)" if self.eliminada else ""
        return f"<CartaResponsabilidad(id={self.id}, numero={self.numero_carta}-{self.anio_carta}{estado})>"


class ArchivoAdjunto(Base):
    """
    Referencias a archivos físicos firmados
    
    NUNCA almacenar archivos binarios en BD
    Guardar hash para verificar integridad
    """
    __tablename__ = "archivos_adjuntos"
    
    id = Column(Integer, primary_key=True, index=True)
    carta_id = Column(
        Integer,
        ForeignKey("cartas_responsabilidad.id"),
        nullable=False,
        index=True
    )
    nombre_archivo = Column(String(255), nullable=False)
    ruta_archivo = Column(Text, nullable=False)
    tipo_mime = Column(String(100))
    hash_integridad = Column(String(64), index=True)
    tamano_bytes = Column(BigInteger)
    fecha_subida = Column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now()
    )
    usuario_subida_id = Column(
        Integer,
        ForeignKey("usuarios_sistema.id"),
        nullable=False
    )
    
    # Relaciones
    carta = relationship(
        "CartaResponsabilidad",
        back_populates="archivos"
    )
    
    def __repr__(self):
        return f"<ArchivoAdjunto(id={self.id}, nombre='{self.nombre_archivo}')>"