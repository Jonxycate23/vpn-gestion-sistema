"""
Clase base para todos los modelos
"""
from sqlalchemy import Column, Integer, DateTime, func
from sqlalchemy.ext.declarative import declared_attr
from app.core.database import Base


class BaseModel(Base):
    """Modelo base abstracto con campos comunes"""
    
    __abstract__ = True
    
    id = Column(Integer, primary_key=True, index=True)
    
    @declared_attr
    def __tablename__(cls):
        """Nombre de tabla automático basado en nombre de clase"""
        return cls.__name__.lower()
