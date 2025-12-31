"""
Modelo: Persona (solicitante de acceso VPN)
ACTUALIZADO: Incluye NIP para personal policial
"""
from sqlalchemy import Column, Integer, String, Boolean, DateTime, Text
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base


class Persona(Base):
    """
    Entidad real que solicita acceso VPN
    
    Una persona puede tener múltiples solicitudes históricas
    El DPI es único e inmutable
    """
    __tablename__ = "personas"
    
    id = Column(Integer, primary_key=True, index=True)
    dpi = Column(String(20), unique=True, nullable=False, index=True)
    nip = Column(String(20), index=True)  # Número de Identificación Policial
    nombres = Column(String(150), nullable=False, index=True)
    apellidos = Column(String(150), nullable=False, index=True)
    institucion = Column(String(200))
    cargo = Column(String(150))
    telefono = Column(String(50))
    email = Column(String(150))
    observaciones = Column(Text)
    activo = Column(Boolean, nullable=False, default=True, index=True)
    fecha_creacion = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    
    # Relaciones
    solicitudes = relationship(
        "SolicitudVPN",
        back_populates="persona",
        cascade="all, delete-orphan"
    )
    
    @property
    def nombre_completo(self) -> str:
        """Propiedad computada: nombre completo"""
        return f"{self.nombres} {self.apellidos}"
    
    def __repr__(self):
        return f"<Persona(dpi='{self.dpi}', nombre='{self.nombre_completo}')>"