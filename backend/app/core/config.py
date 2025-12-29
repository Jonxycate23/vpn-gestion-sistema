"""
Configuración central del sistema
"""
from pydantic_settings import BaseSettings
from pydantic import Field
from typing import List
import os


class Settings(BaseSettings):
    """Configuración de la aplicación"""
    
    # Base de datos
    DATABASE_URL: str = Field(
        default="postgresql://postgres:postgres@localhost:5432/vpn_gestion",
        description="URL de conexión a PostgreSQL"
    )
    DATABASE_ECHO: bool = Field(
        default=False,
        description="Mostrar queries SQL en consola"
    )
    
    # JWT y seguridad
    SECRET_KEY: str = Field(
        default="CAMBIAR_EN_PRODUCCION",
        description="Clave secreta para JWT - usar openssl rand -hex 32"
    )
    ALGORITHM: str = Field(
        default="HS256",
        description="Algoritmo de encriptación JWT"
    )
    ACCESS_TOKEN_EXPIRE_MINUTES: int = Field(
        default=480,
        description="Tiempo de expiración del token en minutos (8 horas)"
    )
    
    # Aplicación
    APP_NAME: str = Field(
        default="Sistema de Gestión de Accesos VPN",
        description="Nombre de la aplicación"
    )
    APP_VERSION: str = Field(
        default="1.0.0",
        description="Versión del sistema"
    )
    DEBUG: bool = Field(
        default=False,
        description="Modo debug"
    )
    ENVIRONMENT: str = Field(
        default="production",
        description="Entorno: development, staging, production"
    )
    
    # CORS
    CORS_ORIGINS: List[str] = Field(
        default=["http://localhost:3000"],
        description="Orígenes permitidos para CORS"
    )
    
    # Archivos
    UPLOAD_DIR: str = Field(
        default="/var/vpn_archivos",
        description="Directorio para archivos subidos"
    )
    MAX_UPLOAD_SIZE: int = Field(
        default=10485760,  # 10MB
        description="Tamaño máximo de archivo en bytes"
    )
    ALLOWED_EXTENSIONS: List[str] = Field(
        default=[".pdf", ".jpg", ".jpeg", ".png"],
        description="Extensiones de archivo permitidas"
    )
    
    # Alertas y vigencia
    DIAS_ALERTA_VENCIMIENTO: int = Field(
        default=30,
        description="Días antes del vencimiento para generar alerta"
    )
    DIAS_GRACIA_DEFAULT: int = Field(
        default=15,
        description="Días de gracia por defecto"
    )
    
    # Logging
    LOG_LEVEL: str = Field(
        default="INFO",
        description="Nivel de logging: DEBUG, INFO, WARNING, ERROR"
    )
    LOG_FILE: str = Field(
        default="/var/log/vpn_gestion.log",
        description="Archivo de logs"
    )
    
    # Paginación
    DEFAULT_PAGE_SIZE: int = Field(
        default=50,
        description="Tamaño de página por defecto"
    )
    MAX_PAGE_SIZE: int = Field(
        default=100,
        description="Tamaño máximo de página"
    )
    
    class Config:
        env_file = ".env"
        case_sensitive = False


# Instancia global de configuración
settings = Settings()


def get_settings() -> Settings:
    """Obtener configuración del sistema"""
    return settings


# Crear directorio de uploads si no existe
if not os.path.exists(settings.UPLOAD_DIR):
    try:
        os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
    except Exception as e:
        print(f"Advertencia: No se pudo crear directorio de uploads: {e}")
