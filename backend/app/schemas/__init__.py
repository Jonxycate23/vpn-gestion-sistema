"""
Exportación de todos los schemas Pydantic
"""
from app.schemas.common import (
    ResponseBase,
    PaginationParams,
    PaginatedResponse,
    AuditoriaBase
)
from app.schemas.usuario import (
    RolEnum,
    LoginRequest,
    LoginResponse,
    ChangePasswordRequest,
    UsuarioCreate,
    UsuarioUpdate,
    UsuarioResponse,
    UsuarioListResponse
)
from app.schemas.persona import (
    PersonaCreate,
    PersonaUpdate,
    PersonaResponse,
    PersonaBusqueda,
    PersonaListResponse
)
from app.schemas.solicitud import (
    TipoSolicitudEnum,
    EstadoSolicitudEnum,
    SolicitudCreate,
    SolicitudAprobar,
    SolicitudRechazar,
    SolicitudResponse,
    SolicitudListResponse,
    SolicitudConHistorial
)
from app.schemas.acceso import (
    EstadoVigenciaEnum,
    EstadoBloqueoEnum,
    AccesoCreate,
    AccesoProrrogar,
    AccesoResponse,
    AccesoConDetalles,
    BloqueoCreate,
    BloqueoResponse,
    DashboardVencimientos,
    AccesoActual
)
from app.schemas.documento import (
    TipoCartaEnum,
    CartaCreate,
    CartaResponse,
    ArchivoResponse,
    ArchivoUploadResponse,
    ComentarioCreate,
    ComentarioResponse
)
from app.schemas.auditoria import (
    AuditoriaEventoResponse,
    AuditoriaFiltros,
    AlertaResponse,
    AlertaMarcarLeida
)

__all__ = [
    # Common
    "ResponseBase",
    "PaginationParams",
    "PaginatedResponse",
    "AuditoriaBase",
    
    # Usuario
    "RolEnum",
    "LoginRequest",
    "LoginResponse",
    "ChangePasswordRequest",
    "UsuarioCreate",
    "UsuarioUpdate",
    "UsuarioResponse",
    "UsuarioListResponse",
    
    # Persona
    "PersonaCreate",
    "PersonaUpdate",
    "PersonaResponse",
    "PersonaBusqueda",
    "PersonaListResponse",
    
    # Solicitud
    "TipoSolicitudEnum",
    "EstadoSolicitudEnum",
    "SolicitudCreate",
    "SolicitudAprobar",
    "SolicitudRechazar",
    "SolicitudResponse",
    "SolicitudListResponse",
    "SolicitudConHistorial",
    
    # Acceso
    "EstadoVigenciaEnum",
    "EstadoBloqueoEnum",
    "AccesoCreate",
    "AccesoProrrogar",
    "AccesoResponse",
    "AccesoConDetalles",
    "BloqueoCreate",
    "BloqueoResponse",
    "DashboardVencimientos",
    "AccesoActual",
    
    # Documento
    "TipoCartaEnum",
    "CartaCreate",
    "CartaResponse",
    "ArchivoResponse",
    "ArchivoUploadResponse",
    "ComentarioCreate",
    "ComentarioResponse",
    
    # Auditoría
    "AuditoriaEventoResponse",
    "AuditoriaFiltros",
    "AlertaResponse",
    "AlertaMarcarLeida",
]
