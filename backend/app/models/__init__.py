"""
Exportación de todos los modelos SQLAlchemy
"""
from app.models.usuario_sistema import UsuarioSistema, RolEnum
from app.models.persona import Persona
from app.models.solicitud_vpn import (
    SolicitudVPN, 
    TipoSolicitudEnum, 
    EstadoSolicitudEnum
)
from app.models.acceso_vpn import AccesoVPN, EstadoVigenciaEnum
from app.models.bloqueo_vpn import BloqueoVPN, EstadoBloqueoEnum
from app.models.documentos import (
    CartaResponsabilidad,
    ArchivoAdjunto,
    TipoCartaEnum
)
from app.models.auditoria import ComentarioAdmin, AuditoriaEvento
from app.models.auxiliares import (
    AlertaSistema,
    ImportacionExcel,
    ConfiguracionSistema,
    Catalogo,
    SesionLogin,
    TipoAlertaEnum
)

__all__ = [
    # Modelos principales
    "UsuarioSistema",
    "Persona",
    "SolicitudVPN",
    "AccesoVPN",
    "BloqueoVPN",
    "CartaResponsabilidad",
    "ArchivoAdjunto",
    
    # Auditoría y comentarios
    "ComentarioAdmin",
    "AuditoriaEvento",
    
    # Auxiliares
    "AlertaSistema",
    "ImportacionExcel",
    "ConfiguracionSistema",
    "Catalogo",
    "SesionLogin",
    
    # Enums
    "RolEnum",
    "TipoSolicitudEnum",
    "EstadoSolicitudEnum",
    "EstadoVigenciaEnum",
    "EstadoBloqueoEnum",
    "TipoCartaEnum",
    "TipoAlertaEnum",
]
