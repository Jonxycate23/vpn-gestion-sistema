# Sistema de Gestión de Accesos VPN

> Sistema institucional para control, auditoría y trazabilidad de accesos VPN.

---

## 📋 Descripción

Solución centralizada para la gestión de accesos VPN que reemplaza el uso de hojas de cálculo con un sistema web multiusuario, auditado y con control de vigencia. Permite trabajo concurrente, búsquedas rápidas, alertas de vencimiento y generación de cartas de responsabilidad en PDF.

---

## 🏗️ Arquitectura

```
Usuario (Navegador)
        │  HTTPS
        ▼
┌──────────────────┐
│   Nginx + SSL    │  ← Sirve frontend y hace proxy al API
└────────┬─────────┘
         │ proxy /api/
         ▼
┌──────────────────┐
│  Backend FastAPI │  ← Puerto 8000 (interno)
│  (Python 3.11+)  │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│   PostgreSQL     │  ← Base de datos (servidor separado)
└──────────────────┘
```

---

## 🛠️ Stack Tecnológico

| Capa | Tecnología |
|------|-----------|
| Frontend | HTML5, CSS3, JavaScript (Vanilla) |
| Backend | FastAPI (Python 3.11+) |
| Base de Datos | PostgreSQL 12+ |
| ORM | SQLAlchemy 2.0 |
| Autenticación | JWT + bcrypt |
| Validación | Pydantic v2 |
| Servidor Web | Nginx (reverse proxy + SSL) |
| Generación PDF | ReportLab |

---

## 📁 Estructura del Proyecto

```
vpn-gestion-sistema/
├── backend/                    # Backend FastAPI
│   ├── app/
│   │   ├── api/endpoints/      # Endpoints REST (auth, dashboard, solicitudes, etc.)
│   │   ├── core/               # Config, base de datos, seguridad
│   │   ├── models/             # Modelos SQLAlchemy
│   │   ├── schemas/            # Esquemas Pydantic
│   │   ├── services/           # Lógica de negocio
│   │   └── utils/              # Utilidades
│   ├── .env.example            # Plantilla de variables de entorno
│   ├── main.py                 # Punto de entrada FastAPI
│   └── requirements.txt
│
├── frontend/                   # Frontend Web
│   ├── css/                    # Estilos
│   ├── js/                     # Módulos JavaScript
│   │   ├── config.js           # Configuración de URL del API
│   │   ├── api.js              # Cliente HTTP
│   │   ├── auth.js             # Autenticación
│   │   ├── dashboard.js        # Dashboard y estadísticas
│   │   ├── solicitudes.js      # Gestión de solicitudes VPN
│   │   ├── accesos.js          # Control de accesos
│   │   └── ...
│   └── index.html
│
├── database/                   # Scripts SQL de instalación
│   ├── 01_create_database.sql
│   ├── 02_create_tables.sql
│   ├── 03_create_indexes.sql
│   ├── 04_functions_triggers.sql
│   ├── 05_initial_data.sql
│   └── install.sh
│
└── docs/                       # Documentación adicional
```

---

## 🚀 Instalación

### Prerrequisitos

- Ubuntu 20.04+ / Debian 11+
- Python 3.11+
- PostgreSQL 12+
- Nginx
- pip, virtualenv

---

### 1. Clonar o desplegar el proyecto

```bash
# Descomprimir o clonar en el servidor
sudo mkdir -p /opt/vpn-gestion-sistema
# Copiar los archivos del proyecto a esa ruta
```

---

### 2. Base de Datos

```bash
# Instalar PostgreSQL (si no está instalado)
sudo apt update && sudo apt install -y postgresql postgresql-contrib
sudo systemctl enable postgresql && sudo systemctl start postgresql

# Ejecutar el script de instalación
cd /opt/vpn-gestion-sistema/database
chmod +x install.sh
./install.sh
```

---

### 3. Backend

```bash
cd /opt/vpn-gestion-sistema/backend

# Crear entorno virtual e instalar dependencias
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Instalar dependencias del sistema para PDF (Ubuntu 24.04)
pip3 install reportlab --break-system-packages

# Crear archivo de configuración
cp .env.example .env
nano .env   # Completar con los valores del entorno
```

**Variables requeridas en `.env`:**

```ini
DATABASE_URL=postgresql+psycopg2://USUARIO:CONTRASEÑA@HOST:5432/vpn_gestion
SECRET_KEY=<generar con: openssl rand -hex 32>
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60
APP_NAME=Sistema de Gestión VPN
ENVIRONMENT=production
DEBUG=false
UPLOAD_DIR=/ruta/para/archivos/subidos
```

---

### 4. Servicio del Backend (systemd)

Crear el archivo `/etc/systemd/system/vpn-gestion.service`:

```ini
[Unit]
Description=Sistema de Gestión VPN - Backend FastAPI
After=network.target

[Service]
User=<usuario>
WorkingDirectory=/opt/vpn-gestion-sistema/backend
ExecStart=/opt/vpn-gestion-sistema/backend/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable vpn-gestion
sudo systemctl start vpn-gestion
sudo systemctl status vpn-gestion
```

---

### 5. Nginx

Editar `/etc/nginx/sites-available/default`:

```nginx
# Redirigir HTTP → HTTPS
server {
    listen 80 default_server;
    server_name tu-dominio.com;
    return 301 https://$host$request_uri;
}

# Servidor principal con SSL
server {
    listen 443 ssl;
    server_name tu-dominio.com;

    ssl_certificate     /ruta/al/certificado.crt;
    ssl_certificate_key /ruta/a/la/llave.key;

    # Servir el Frontend
    location / {
        root /opt/vpn-gestion-sistema/frontend;
        index index.html;
        try_files $uri $uri/ /index.html;
    }

    # Proxy al Backend API
    location /api/ {
        proxy_pass http://127.0.0.1:8000/api/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```bash
sudo nginx -t && sudo systemctl restart nginx
```

---

## 📊 Modelo de Datos

| Tabla | Propósito |
|-------|-----------|
| `usuarios_sistema` | Autenticación y roles internos |
| `personas` | Solicitantes VPN (cédula única) |
| `solicitudes_vpn` | Historial de solicitudes |
| `accesos_vpn` | Control de vigencia activa |
| `bloqueos_vpn` | Historial de bloqueos/desbloqueos |
| `cartas_responsabilidad` | Registro de cartas generadas |
| `archivos_adjuntos` | Referencias a documentos físicos |
| `auditoria_eventos` | Auditoría completa (inmutable) |

---

## 🔒 Seguridad

- **Autenticación**: JWT con expiración configurable
- **Contraseñas**: Hashing con bcrypt
- **Roles**: `SUPERADMIN` (configuración total) y `ADMIN` (operaciones diarias)
- **Auditoría**: Toda acción queda registrada con usuario, IP, fecha y detalle
- **HTTPS**: Todo el tráfico cifrado vía Nginx + SSL institucional

---

## 🔧 Mantenimiento

### Verificar el sistema

```bash
sudo systemctl status vpn-gestion
sudo systemctl status nginx
sudo journalctl -u vpn-gestion -n 50 --no-pager
```

### Reiniciar servicios

```bash
sudo systemctl restart vpn-gestion
sudo systemctl restart nginx
```

### Backup de base de datos

```bash
# Usar variables de entorno para no exponer credenciales en el historial
source /ruta/al/proyecto/backend/.env
pg_dump -h $DB_HOST -U $DB_USER $DB_NAME > backup_$(date +%Y%m%d).sql
gzip backup_$(date +%Y%m%d).sql
```

---

## 📖 Documentación del API

Con el backend corriendo, acceder a:

- Swagger UI: `http://localhost:8000/docs`
- Redoc: `http://localhost:8000/redoc`

---

## 📄 Licencia y Clasificación

> ⚠️ **CLASIFICACIÓN: DOCUMENTO TÉCNICO DE CIRCULACIÓN RESTRINGIDA**
>
> El acceso, uso o divulgación no autorizada de este sistema o su documentación está sujeto a sanciones administrativas y legales conforme a la legislación vigente.

Sistema de uso institucional interno. Acceso restringido a personal autorizado.

---

**Versión:** 1.0.0 | **Actualizado:** Febrero 2026
