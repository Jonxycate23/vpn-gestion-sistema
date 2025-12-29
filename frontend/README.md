# Frontend - Sistema de Gestión VPN

## 📋 Descripción

Frontend completo en HTML, CSS y JavaScript vanilla (sin frameworks) para el sistema de gestión de accesos VPN.

## 🚀 Cómo Ejecutar

### Opción 1: Servidor Python Simple

```bash
cd frontend
python3 -m http.server 3000
```

Abre: http://localhost:3000

### Opción 2: Live Server (VS Code)

1. Instala la extensión "Live Server" en VS Code
2. Click derecho en `index.html`
3. Selecciona "Open with Live Server"

### Opción 3: Nginx (Producción)

```nginx
server {
    listen 80;
    server_name vpn.institucion.gob.gt;
    root /var/www/vpn-frontend;
    index index.html;
    
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

## ⚙️ Configuración

El archivo `js/config.js` contiene la configuración principal:

```javascript
const CONFIG = {
    API_URL: 'http://localhost:8000/api',  // ← Cambiar según tu backend
    TOKEN_KEY: 'vpn_token',
    USER_KEY: 'vpn_user'
};
```

**IMPORTANTE:** Si tu backend está en otro servidor o puerto, actualiza `API_URL`.

## 📁 Estructura de Archivos

```
frontend/
├── index.html              # Página principal
├── css/
│   └── styles.css         # Estilos completos
└── js/
    ├── config.js          # Configuración
    ├── api.js             # Cliente API
    ├── auth.js            # Autenticación
    ├── app.js             # Aplicación principal
    ├── dashboard.js       # Dashboard
    ├── personas.js        # Gestión de personas
    ├── solicitudes.js     # Gestión de solicitudes
    └── accesos.js         # Gestión de accesos
```

## 🎨 Características

### ✅ Implementadas

- **Autenticación completa**
  - Login con JWT
  - Almacenamiento de token
  - Logout
  
- **Dashboard**
  - Cards con estadísticas
  - Tabla de accesos recientes
  - Auto-actualización

- **Gestión de Personas**
  - Crear nueva persona
  - Listar con búsqueda en tiempo real
  - Validación de DPI

- **Gestión de Solicitudes**
  - Ver listado de solicitudes
  - Filtros por estado y tipo

- **Gestión de Accesos**
  - Ver listado completo
  - Prorrogar accesos (días de gracia)
  - Bloquear/Desbloquear con motivo

### 🚧 Por Mejorar

- Edición de personas
- Creación de solicitudes desde el frontend
- Aprobación/Rechazo de solicitudes
- Vista de detalles completos
- Paginación real
- Gestión de documentos
- Reportes y exportación

## 🔒 CORS

Para que el frontend pueda comunicarse con el backend, asegúrate que el backend tenga CORS configurado correctamente:

```python
# backend/main.py
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

## 📝 Credenciales de Prueba

**Usuario:** admin  
**Contraseña:** Admin123!

⚠️ Cambiar inmediatamente en producción

## 🎯 Flujo de Uso

1. **Login** con usuario/contraseña
2. **Dashboard** muestra resumen ejecutivo
3. **Personas** permite crear solicitantes
4. **Solicitudes** gestiona peticiones
5. **Accesos** controla vigencia y bloqueos

## 🐛 Solución de Problemas

### Error: "Connection refused"

Backend no está corriendo. Ejecuta:
```bash
cd backend
uvicorn main:app --reload
```

### Error: "CORS policy"

Backend no tiene CORS configurado o la URL no está permitida.

### El token expira

Token JWT expira en 8 horas. Vuelve a hacer login.

### Datos no aparecen

1. Verifica que el backend esté corriendo
2. Abre la consola del navegador (F12)
3. Revisa errores en la pestaña "Console"
4. Verifica llamadas en "Network"

## 🎨 Personalización

### Cambiar Colores

Edita `css/styles.css` en las variables CSS:

```css
:root {
    --primary: #2563eb;      /* Color primario */
    --success: #10b981;      /* Verde */
    --warning: #f59e0b;      /* Amarillo */
    --danger: #ef4444;       /* Rojo */
}
```

### Agregar Nueva Vista

1. Agrega HTML en `index.html`:
```html
<div id="nuevaView" class="view">
    <h1>Nueva Vista</h1>
</div>
```

2. Agrega item al menú:
```html
<li><a href="#" data-view="nueva" class="menu-item">📌 Nueva</a></li>
```

3. Crea módulo JS:
```javascript
const Nueva = {
    async load() {
        // Tu lógica aquí
    }
};
```

4. Agrega caso en `app.js`:
```javascript
case 'nueva':
    Nueva.load();
    break;
```

## 📊 Tecnologías Usadas

- **HTML5** - Estructura
- **CSS3** - Estilos (Grid, Flexbox, Variables CSS)
- **JavaScript ES6+** - Lógica (Async/Await, Modules, Fetch API)
- **LocalStorage** - Almacenamiento de token

**Sin frameworks** - Vanilla JS puro para máximo rendimiento

## 🚀 Despliegue en Producción

1. **Configurar API URL:**
```javascript
// js/config.js
const CONFIG = {
    API_URL: 'https://api.vpn.institucion.gob.gt',  // ← URL real
    // ...
};
```

2. **Minificar archivos** (opcional):
```bash
# CSS
npx cssnano css/styles.css css/styles.min.css

# JS
npx terser js/*.js --output js/bundle.min.js
```

3. **Configurar servidor web:**
   - Nginx
   - Apache
   - IIS

## 📄 Licencia

Sistema interno de institución pública.

---

**Versión:** 1.0.0  
**Última actualización:** 2025-12-29
