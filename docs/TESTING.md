# 🧪 Guía de Pruebas del Sistema VPN

## ✅ Sistema Actualmente Funcional

Has recibido un sistema con las siguientes características **FUNCIONANDO**:

### 🟢 Base de Datos (100%)
- ✅ 14 tablas creadas
- ✅ Funciones automáticas
- ✅ Vistas consolidadas
- ✅ Índices de rendimiento
- ✅ Usuario admin inicial

### 🟢 Backend API (40%)
- ✅ Autenticación JWT completa
- ✅ Dashboard de vencimientos
- ✅ Schemas de validación
- ✅ Utilidades (auditoría, archivos)
- ✅ Dependencias de seguridad

## 🚀 Pruebas Rápidas

### 1. Verificar que el servidor esté corriendo

```bash
curl http://localhost:8000/health
```

**Respuesta esperada:**
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "environment": "development"
}
```

### 2. Login con usuario admin

```bash
curl -X POST "http://localhost:8000/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "Admin123!"
  }'
```

**Respuesta esperada:**
```json
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "token_type": "bearer",
  "usuario": {
    "id": 1,
    "username": "admin",
    "nombre_completo": "Administrador del Sistema",
    "email": "admin@institucion.gob.gt",
    "rol": "SUPERADMIN",
    "activo": true,
    "fecha_creacion": "2025-12-29T...",
    "fecha_ultimo_login": "2025-12-29T..."
  }
}
```

**⚠️ IMPORTANTE:** Guarda el `access_token` para las siguientes peticiones.

### 3. Obtener información del usuario actual

```bash
# Reemplaza YOUR_TOKEN con el token del paso anterior
TOKEN="eyJ0eXAiOiJKV1QiLCJhbGc..."

curl -X GET "http://localhost:8000/api/auth/me" \
  -H "Authorization: Bearer $TOKEN"
```

### 4. Ver dashboard de vencimientos

```bash
curl -X GET "http://localhost:8000/api/dashboard/vencimientos" \
  -H "Authorization: Bearer $TOKEN"
```

**Respuesta esperada (base de datos nueva):**
```json
{
  "activos": 0,
  "por_vencer": 0,
  "vencidos": 0,
  "bloqueados": 0,
  "vencen_esta_semana": 0,
  "vencen_hoy": 0
}
```

### 5. Ver accesos actuales

```bash
curl -X GET "http://localhost:8000/api/dashboard/accesos-actuales" \
  -H "Authorization: Bearer $TOKEN"
```

### 6. Cambiar contraseña del admin

```bash
curl -X POST "http://localhost:8000/api/auth/change-password" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "password_actual": "Admin123!",
    "password_nueva": "MiNuevaPassword123!",
    "password_confirmacion": "MiNuevaPassword123!"
  }'
```

**Respuesta esperada:**
```json
{
  "success": true,
  "message": "Contraseña actualizada exitosamente"
}
```

### 7. Actualizar estados de vigencia

```bash
curl -X POST "http://localhost:8000/api/dashboard/actualizar-estados" \
  -H "Authorization: Bearer $TOKEN"
```

Esta llamada ejecuta las funciones SQL automáticas.

## 📖 Documentación Interactiva

El mejor lugar para probar el API es la documentación interactiva de FastAPI:

**Swagger UI:**  
http://localhost:8000/docs

**ReDoc:**  
http://localhost:8000/redoc

### Cómo usar Swagger UI:

1. Abre http://localhost:8000/docs
2. Haz clic en **POST /api/auth/login**
3. Haz clic en **"Try it out"**
4. Ingresa:
   ```json
   {
     "username": "admin",
     "password": "Admin123!"
   }
   ```
5. Haz clic en **Execute**
6. Copia el `access_token` de la respuesta
7. Haz clic en el botón **Authorize** (candado) en la parte superior
8. Pega el token en el campo "Value"
9. Haz clic en **Authorize**
10. ¡Ahora puedes probar todos los endpoints protegidos!

## 🔍 Verificar Auditoría

Todas las acciones se registran en la tabla de auditoría:

```sql
-- Conectarse a PostgreSQL
psql -h localhost -U postgres -d vpn_gestion

-- Ver últimos eventos de auditoría
SELECT 
    ae.fecha,
    u.username,
    ae.accion,
    ae.entidad,
    ae.ip_origen
FROM auditoria_eventos ae
LEFT JOIN usuarios_sistema u ON u.id = ae.usuario_id
ORDER BY ae.fecha DESC
LIMIT 10;
```

Deberías ver eventos de:
- LOGIN_EXITOSO
- CAMBIO_PASSWORD (si cambiaste la contraseña)

## 🎯 Próximos Pasos de Desarrollo

Para completar el sistema necesitas implementar:

### Prioridad Alta (Endpoints CRUD básicos):

1. **Personas** (`/api/personas`)
   - GET /api/personas (listar con paginación)
   - GET /api/personas/{id} (obtener una)
   - POST /api/personas (crear)
   - PUT /api/personas/{id} (actualizar)
   - GET /api/personas/buscar/{dpi} (buscar por DPI)

2. **Solicitudes** (`/api/solicitudes`)
   - POST /api/solicitudes (crear nueva solicitud)
   - GET /api/solicitudes (listar)
   - GET /api/solicitudes/{id} (detalles)
   - POST /api/solicitudes/{id}/aprobar (aprobar)
   - POST /api/solicitudes/{id}/rechazar (rechazar)

3. **Accesos** (`/api/accesos`)
   - GET /api/accesos (listar)
   - GET /api/accesos/{id} (detalles)
   - POST /api/accesos/{id}/prorrogar (extender días de gracia)

4. **Bloqueos** (`/api/bloqueos`)
   - POST /api/bloqueos (bloquear/desbloquear acceso)
   - GET /api/bloqueos/historial/{acceso_id}

### Prioridad Media:

5. **Documentos** (`/api/documentos`)
   - POST /api/documentos/cartas (crear carta)
   - POST /api/documentos/archivos (subir archivo)
   - GET /api/documentos/archivos/{id} (descargar)

6. **Comentarios** (`/api/comentarios`)
   - POST /api/comentarios (agregar comentario)
   - GET /api/comentarios/{entidad}/{id}

7. **Usuarios** (`/api/usuarios`)
   - POST /api/usuarios (crear usuario - solo SUPERADMIN)
   - GET /api/usuarios (listar)
   - PUT /api/usuarios/{id} (actualizar)

### Prioridad Baja:

8. **Importación Excel**
9. **Reportes y exportación**
10. **Alertas**

## 📝 Estructura de un Service Típico

Si quieres seguir desarrollando, aquí hay un ejemplo de cómo crear un service:

```python
# app/services/personas.py
from sqlalchemy.orm import Session
from app.models import Persona
from app.schemas import PersonaCreate, PersonaUpdate
from typing import List, Optional

class PersonaService:
    
    @staticmethod
    def crear(db: Session, data: PersonaCreate) -> Persona:
        persona = Persona(**data.model_dump())
        db.add(persona)
        db.commit()
        db.refresh(persona)
        return persona
    
    @staticmethod
    def obtener_por_id(db: Session, persona_id: int) -> Optional[Persona]:
        return db.query(Persona).filter(Persona.id == persona_id).first()
    
    @staticmethod
    def obtener_por_dpi(db: Session, dpi: str) -> Optional[Persona]:
        return db.query(Persona).filter(Persona.dpi == dpi).first()
    
    @staticmethod
    def listar(db: Session, skip: int = 0, limit: int = 50) -> List[Persona]:
        return db.query(Persona).offset(skip).limit(limit).all()
```

## 🐛 Troubleshooting

### Error: "401 Unauthorized"
- Verifica que el token esté presente y válido
- El token expira en 8 horas por defecto
- Haz login nuevamente para obtener un nuevo token

### Error: "403 Forbidden"
- Tu usuario no tiene permisos suficientes
- Verifica tu rol (ADMIN vs SUPERADMIN)

### Error: "Connection refused"
- Verifica que el servidor esté corriendo
- Ejecuta: `uvicorn main:app --reload`

### Error: "500 Internal Server Error"
- Verifica los logs del servidor
- Revisa la conexión a PostgreSQL
- Verifica que la BD esté creada correctamente

## 📊 Estado del Proyecto

| Componente | Estado | %  |
|------------|--------|-----|
| Base de Datos | ✅ Completo | 100% |
| Modelos SQLAlchemy | ✅ Completo | 100% |
| Schemas Pydantic | ✅ Completo | 100% |
| Autenticación | ✅ Funcional | 100% |
| Dashboard | ✅ Funcional | 100% |
| Utilidades | ✅ Completo | 100% |
| CRUD Personas | 🚧 Pendiente | 0% |
| CRUD Solicitudes | 🚧 Pendiente | 0% |
| CRUD Accesos | 🚧 Pendiente | 0% |
| Gestión Documentos | 🚧 Pendiente | 0% |
| Frontend | 🚧 Pendiente | 0% |

**Progreso total: ~40%**

---

¡El sistema está corriendo y funcional! Puedes hacer login y ver el dashboard. Los endpoints restantes siguen el mismo patrón.
