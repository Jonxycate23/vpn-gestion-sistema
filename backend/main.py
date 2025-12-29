"""
Aplicación principal FastAPI
Sistema de Gestión de Accesos VPN
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.core.database import engine, Base

# Importar routers
from app.api.endpoints import auth, dashboard, personas, solicitudes, accesos

# Crear todas las tablas (solo en desarrollo, usar Alembic en producción)
# Base.metadata.create_all(bind=engine)

# Crear aplicación
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="Sistema institucional de gestión de accesos VPN con auditoría completa",
    docs_url="/docs",
    redoc_url="/redoc",
)

# Configurar CORS - PERMISIVO PARA DESARROLLO
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Permitir todos los orígenes en desarrollo
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"]
)


@app.get("/")
async def root():
    """Endpoint raíz"""
    return {
        "mensaje": "Sistema de Gestión de Accesos VPN",
        "version": settings.APP_VERSION,
        "docs": "/docs",
        "redoc": "/redoc",
        "estado": "Sistema funcional con autenticación activa"
    }


@app.get("/health")
async def health_check():
    """Health check para monitoreo"""
    return {
        "status": "healthy",
        "version": settings.APP_VERSION,
        "environment": settings.ENVIRONMENT
    }


# Registrar routers
app.include_router(auth.router, prefix="/api/auth", tags=["🔐 Autenticación"])
app.include_router(dashboard.router, prefix="/api/dashboard", tags=["📊 Dashboard"])
app.include_router(personas.router, prefix="/api/personas", tags=["👥 Personas"])
app.include_router(solicitudes.router, prefix="/api/solicitudes", tags=["📄 Solicitudes VPN"])
app.include_router(accesos.router, prefix="/api/accesos", tags=["🔑 Accesos VPN"])

# TODO: Agregar más routers cuando estén implementados
# from app.api.endpoints import personas, solicitudes, accesos, documentos, dashboard
# app.include_router(personas.router, prefix="/api/personas", tags=["👥 Personas"])
# app.include_router(solicitudes.router, prefix="/api/solicitudes", tags=["📄 Solicitudes"])
# app.include_router(accesos.router, prefix="/api/accesos", tags=["🔑 Accesos VPN"])
# app.include_router(documentos.router, prefix="/api/documentos", tags=["📎 Documentos"])
# app.include_router(dashboard.router, prefix="/api/dashboard", tags=["📊 Dashboard"])


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.DEBUG
    )