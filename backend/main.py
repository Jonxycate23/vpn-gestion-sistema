"""
Aplicación principal FastAPI
Sistema de Gestión de Accesos VPN
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings

# Importar todos los routers necesarios
from app.api.endpoints import auth, dashboard, solicitudes, accesos, usuarios

# Crear aplicación
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="Sistema institucional de gestión de accesos VPN con auditoría completa",
    docs_url="/docs",
    redoc_url="/redoc",
)

# ========================================
# CONFIGURAR CORS - MÁS EXPLÍCITO
# ========================================
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:5500",
        "http://127.0.0.1:5500",
        "http://localhost:3000",
        "http://127.0.0.1:3000",
        "*"  # Permitir todos durante desarrollo
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"],
    allow_headers=["*"],
    expose_headers=["*"],
    max_age=3600,
)


@app.get("/")
async def root():
    """Endpoint raíz"""
    return {
        "mensaje": "Sistema de Gestión de Accesos VPN - PNC",
        "version": settings.APP_VERSION,
        "docs": "/docs",
        "redoc": "/redoc",
        "estado": "✅ Sistema funcional",
        "nota": "⚠️ IMPORTANTE: Usuarios del SISTEMA (ADMIN/SUPERADMIN) son diferentes a usuarios de acceso VPN"
    }


@app.get("/health")
async def health_check():
    """Health check para monitoreo"""
    return {
        "status": "healthy",
        "version": settings.APP_VERSION,
        "environment": settings.ENVIRONMENT
    }


# ========================================
# REGISTRAR TODOS LOS ROUTERS
# ========================================
# ⚠️ NOTA: Los endpoints de /api/usuarios son para gestionar usuarios del SISTEMA
#          Los usuarios de ACCESO VPN están en las tablas Persona y AccesoVPN
app.include_router(auth.router, prefix="/api/auth", tags=["🔐 Autenticación"])
app.include_router(dashboard.router, prefix="/api/dashboard", tags=["📊 Dashboard"])
app.include_router(solicitudes.router, prefix="/api/solicitudes", tags=["📄 Solicitudes VPN"])
app.include_router(accesos.router, prefix="/api/accesos", tags=["🔑 Accesos VPN"])
app.include_router(usuarios.router, prefix="/api/usuarios", tags=["👥 Usuarios del Sistema (ADMIN/SUPERADMIN)"])


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.DEBUG
    )