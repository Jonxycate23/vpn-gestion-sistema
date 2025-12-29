"""
Configuración de base de datos SQLAlchemy
"""
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from typing import Generator
from app.core.config import settings

# Motor de base de datos
engine = create_engine(
    settings.DATABASE_URL,
    echo=settings.DATABASE_ECHO,
    pool_pre_ping=True,  # Verifica conexión antes de usar
    pool_size=10,        # Tamaño del pool
    max_overflow=20      # Conexiones adicionales permitidas
)

# Sesión
SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)

# Base para modelos
Base = declarative_base()


def get_db() -> Generator[Session, None, None]:
    """
    Dependencia para obtener sesión de base de datos
    Se usa en endpoints FastAPI
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db() -> None:
    """
    Inicializar base de datos
    Crear todas las tablas si no existen
    """
    Base.metadata.create_all(bind=engine)
