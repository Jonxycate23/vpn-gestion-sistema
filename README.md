# Sistema de Gestión de Accesos VPN

## 📋 Descripción

Sistema institucional completo para la gestión y control de accesos VPN con auditoría total, control de vigencia y trazabilidad institucional. Reemplaza el uso de archivos Excel con una solución centralizada, concurrente y auditada.

## 🎯 Objetivos del Sistema

- ✅ Reemplazar completamente Excel como base de datos
- ✅ Centralizar información de accesos VPN
- ✅ Permitir trabajo concurrente de ~16 usuarios simultáneos
- ✅ Control estricto de auditoría (quién, qué, cuándo, por qué)
- ✅ Facilitar búsquedas rápidas en soporte
- ✅ Generar alertas internas por vencimientos
- ✅ Mantener historial completo (nunca sobrescribir)
- ✅ Gestionar prórrogas y días de gracia
- ✅ Adjuntar documentos firmados (PDFs, imágenes)
- ✅ Cumplir buenas prácticas de trazabilidad institucional

## 🏗️ Arquitectura

```
┌──────────────────────────┐
│      Frontend Web        │
│   (React/Vue/HTML)       │
└───────────▲──────────────┘
            │ REST API
┌───────────┴──────────────┐
│     Backend FastAPI      │
│  - Autenticación JWT     │
│  - Validaciones          │
│  - Auditoría central     │
│  - Reglas de negocio     │
└───────────▲──────────────┘
            │
┌───────────┴──────────────┐
│   PostgreSQL Database    │
│  - Esquema normalizado   │
│  - Auditoría histórica   │
│  - Funciones automáticas │
└───────────▲──────────────┘
            │
┌───────────┴──────────────┐
│  Almacenamiento Archivos │
│  (Filesystem interno)    │
└──────────────────────────┘
```

## 🛠️ Stack Tecnológico

### Backend
- **Framework**: FastAPI (Python 3.11+)
- **Base de datos**: PostgreSQL 12+
- **ORM**: SQLAlchemy 2.0
- **Autenticación**: JWT + bcrypt
- **Validación**: Pydantic v2

### Frontend (Por implementar)
- React / Vue.js / HTML
- Axios para API REST
- Bootstrap / Tailwind CSS

## 📁 Estructura del Proyecto

```
vpn-gestion-sistema/
├── database/               # Scripts SQL
│   ├── 01_create_database.sql
│   ├── 02_create_tables.sql
│   ├── 03_create_indexes.sql
│   ├── 04_functions_triggers.sql
│   ├── 05_initial_data.sql
│   ├── install.sh         # Script de instalación completa
│   └── README.md
│
├── backend/               # Backend FastAPI
│   ├── app/
│   │   ├── api/
│   │   │   ├── endpoints/    # Endpoints REST
│   │   │   └── dependencies/ # Dependencias FastAPI
│   │   ├── core/
│   │   │   ├── config.py     # Configuración
│   │   │   ├── database.py   # SQLAlchemy setup
│   │   │   └── security.py   # JWT y hashing
│   │   ├── models/           # Modelos SQLAlchemy
│   │   │   ├── usuario_sistema.py
│   │   │   ├── persona.py
│   │   │   ├── solicitud_vpn.py
│   │   │   ├── acceso_vpn.py
│   │   │   ├── bloqueo_vpn.py
│   │   │   ├── documentos.py
│   │   │   ├── auditoria.py
│   │   │   └── auxiliares.py
│   │   ├── schemas/          # Esquemas Pydantic
│   │   ├── services/         # Lógica de negocio
│   │   └── utils/            # Utilidades
│   ├── tests/            # Tests unitarios
│   ├── alembic/          # Migraciones de BD
│   ├── requirements.txt
│   ├── .env.example
│   └── main.py
│
├── frontend/             # Frontend (Por implementar)
│   └── ...
│
├── docs/                 # Documentación
│   └── ...
│
├── scripts/              # Scripts auxiliares
│   └── ...
│
└── README.md            # Este archivo
```

## 🚀 Instalación y Configuración

### 1. Prerrequisitos

```bash
# Sistema operativo
Ubuntu 20.04+ / Debian 11+

# Software requerido
- PostgreSQL 12+
- Python 3.11+
- pip
- virtualenv
```

### 2. Instalar PostgreSQL

```bash
sudo apt update
sudo apt install postgresql postgresql-contrib
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

### 3. Crear Base de Datos

```bash
cd database
chmod +x install.sh
./install.sh
```

El script te pedirá la contraseña del usuario `postgres` y ejecutará todos los scripts SQL en orden.

**Credenciales iniciales:**
- Usuario: `admin`
- Contraseña: `Admin123!`
- ⚠️ **CAMBIAR INMEDIATAMENTE EN PRODUCCIÓN**

### 4. Configurar Backend

```bash
cd backend

# Crear entorno virtual
python3 -m venv venv
source venv/bin/activate  # Linux/Mac
# venv\Scripts\activate   # Windows

# Instalar dependencias
pip install -r requirements.txt

# Configurar variables de entorno
cp .env.example .env
nano .env  # Editar con tus valores reales
```

**Variables importantes en `.env`:**
```ini
DATABASE_URL=postgresql://postgres:tu_password@localhost:5432/vpn_gestion
SECRET_KEY=genera_con_openssl_rand_hex_32
UPLOAD_DIR=/var/vpn_archivos
```

### 5. Ejecutar Backend

```bash
# Desarrollo
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Producción
uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4
```

Acceder a:
- API: http://localhost:8000
- Documentación: http://localhost:8000/docs
- Redoc: http://localhost:8000/redoc

## 📊 Modelo de Datos

### Tablas Principales

| Tabla | Propósito | Crítica |
|-------|-----------|---------|
| `usuarios_sistema` | Autenticación interna | ✓ |
| `personas` | Solicitantes VPN (DPI único) | ✓ |
| `solicitudes_vpn` | Historial de solicitudes | ✓ |
| `accesos_vpn` | Control de vigencia | ✓ |
| `bloqueos_vpn` | Historial bloqueos/desbloqueos | ✓ |
| `cartas_responsabilidad` | Metadatos documentos | ✓ |
| `archivos_adjuntos` | Referencias a archivos | ✓ |
| `auditoria_eventos` | Auditoría completa (INMUTABLE) | ✓✓✓ |

### Principios de Diseño

1. **Separación de Conceptos**
   - Persona ≠ Solicitud ≠ Acceso ≠ Bloqueo
   - Cada entidad en su tabla

2. **Historial Completo**
   - Una persona puede tener múltiples solicitudes
   - Nunca se sobrescriben datos

3. **Vigencia vs Bloqueo**
   - Vigencia: estado temporal (activo/vencido)
   - Bloqueo: acción administrativa
   - Son independientes

4. **Auditoría Total**
   - Toda acción genera evento
   - Tabla inmutable
   - Legalmente defendible

## 🔒 Seguridad

### Autenticación
- JWT con expiración configurable (default: 8 horas)
- Contraseñas hasheadas con bcrypt
- Validación de tokens en cada request

### Roles
- **SUPERADMIN**: Configuración, usuarios, auditoría completa
- **ADMIN**: Operaciones diarias, gestión de solicitudes

### Auditoría
- Toda acción se registra en `auditoria_eventos`
- Incluye: usuario, acción, timestamp, IP, detalle JSON
- Tabla NUNCA se edita ni elimina

## 📝 Funcionalidades Clave

### ✅ Implementadas (Base de Datos)

- [x] Modelo de datos completo
- [x] Separación persona/solicitud/acceso/bloqueo
- [x] Auditoría automática
- [x] Control de vigencia con días de gracia
- [x] Historial de bloqueos
- [x] Gestión de documentos
- [x] Comentarios administrativos
- [x] Alertas de vencimiento
- [x] Funciones automáticas (actualizar estados)
- [x] Vistas consolidadas (dashboard)
- [x] Índices de rendimiento
- [x] Usuario admin inicial

### 🚧 En Desarrollo (Backend)

- [x] Configuración FastAPI
- [x] Modelos SQLAlchemy
- [x] Autenticación JWT
- [ ] Schemas Pydantic
- [ ] Servicios de negocio
- [ ] Endpoints REST
- [ ] Importación de Excel
- [ ] Generación de reportes
- [ ] Subida de archivos
- [ ] Tests unitarios

### 📅 Por Implementar (Frontend)

- [ ] Interfaz de autenticación
- [ ] Dashboard de vencimientos
- [ ] Gestión de personas
- [ ] Gestión de solicitudes
- [ ] Control de accesos
- [ ] Historial y auditoría
- [ ] Reportes y exportación
- [ ] Gestión de usuarios

## 🔧 Tareas de Mantenimiento

### Diarias (Automatizar con cron)

```sql
-- Actualizar estados de vigencia
SELECT actualizar_estado_vigencia();

-- Generar alertas de vencimiento
SELECT generar_alertas_vencimiento();
```

### Semanales

```sql
-- Vacuuming y análisis
VACUUM ANALYZE;
```

### Backups (Automatizar)

```bash
# Backup diario
pg_dump -h localhost -U postgres vpn_gestion > backup_$(date +%Y%m%d).sql

# Comprimir
gzip backup_$(date +%Y%m%d).sql

# Mantener últimos 30 días
find /ruta/backups -name "backup_*.sql.gz" -mtime +30 -delete
```

## 📖 Documentación Adicional

- [Base de Datos](database/README.md) - Documentación completa de la BD
- API Docs - http://localhost:8000/docs (cuando backend esté corriendo)
- Redoc - http://localhost:8000/redoc

## 🤝 Soporte

Para consultas o problemas:
- Revisar documentación en `/docs`
- Revisar logs del sistema
- Contactar al equipo de desarrollo

## 📄 Licencia

Sistema interno de institución pública.
Uso restringido a personal autorizado.

---

**Versión:** 1.0.0  
**Última actualización:** 2025-01-01  
**Estado:** En desarrollo activo
