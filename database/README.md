# Base de Datos - Sistema de Gestión de Accesos VPN

## Descripción General

Base de datos PostgreSQL diseñada para gestión institucional de accesos VPN con auditoría completa, control de vigencia y trazabilidad.

## Requisitos

- PostgreSQL 12 o superior
- Extensiones: uuid-ossp, pgcrypto

## Instalación Rápida

```bash
cd database
./install.sh
```

El script solicitará la contraseña del usuario `postgres` y ejecutará todos los scripts en orden.

## Scripts SQL (orden de ejecución)

1. **01_create_database.sql** - Crea la base de datos y extensiones
2. **02_create_tables.sql** - Crea todas las tablas del sistema
3. **03_create_indexes.sql** - Crea índices para rendimiento
4. **04_functions_triggers.sql** - Funciones y triggers automáticos
5. **05_initial_data.sql** - Usuario admin y configuración inicial

## Estructura de Tablas

### Tablas Principales

| Tabla | Descripción | Crítica |
|-------|-------------|---------|
| `usuarios_sistema` | Usuarios internos del sistema | ✓ |
| `personas` | Solicitantes de VPN (DPI único) | ✓ |
| `solicitudes_vpn` | Historial completo de solicitudes | ✓ |
| `accesos_vpn` | Control de vigencia técnica | ✓ |
| `bloqueos_vpn` | Historial de bloqueos/desbloqueos | ✓ |
| `cartas_responsabilidad` | Metadatos de documentos legales | ✓ |
| `archivos_adjuntos` | Referencias a archivos firmados | ✓ |
| `auditoria_eventos` | Auditoría completa (INMUTABLE) | ✓✓✓ |

### Tablas de Soporte

| Tabla | Descripción |
|-------|-------------|
| `comentarios_admin` | Bitácora operativa humana |
| `alertas_sistema` | Alertas internas de vencimiento |
| `importaciones_excel` | Trazabilidad de migraciones |
| `configuracion_sistema` | Parámetros del sistema |
| `catalogos` | Valores normalizados |
| `sesiones_login` | Control de sesiones activas |

## Modelo de Datos - Relaciones Clave

```
personas (1) ──→ (N) solicitudes_vpn
solicitudes_vpn (1) ──→ (1) accesos_vpn
accesos_vpn (1) ──→ (N) bloqueos_vpn
solicitudes_vpn (1) ──→ (N) cartas_responsabilidad
cartas_responsabilidad (1) ──→ (N) archivos_adjuntos
```

## Principios de Diseño

### ✅ Separación de Conceptos

- **Persona** ≠ **Solicitud** ≠ **Acceso** ≠ **Bloqueo**
- Cada entidad tiene su tabla independiente
- Permite historial completo sin sobrescribir

### ✅ Auditoría Total

- Toda acción genera registro en `auditoria_eventos`
- Tabla INMUTABLE (nunca se edita ni elimina)
- Incluye: usuario, acción, timestamp, IP, detalle JSON

### ✅ Vigencia vs Bloqueo

- **Vigencia**: estado temporal (activo/vencido)
- **Bloqueo**: acción administrativa
- Un acceso vigente puede estar bloqueado
- Un acceso vencido puede no estar bloqueado (auditoría)

### ✅ Historial Completo

- Una persona puede tener múltiples solicitudes
- Cada renovación es una nueva solicitud
- Nunca se sobrescriben datos históricos

## Funciones Automáticas

### `actualizar_estado_vigencia()`

Actualiza estados de vigencia según fechas actuales:
- `ACTIVO` → `POR_VENCER` (30 días antes)
- `POR_VENCER` → `VENCIDO` (después de fecha_fin)

**Ejecutar diariamente:**
```sql
SELECT actualizar_estado_vigencia();
```

### `generar_alertas_vencimiento()`

Genera alertas automáticas para accesos próximos a vencer.

**Ejecutar diariamente:**
```sql
SELECT generar_alertas_vencimiento();
```

### `obtener_historial_persona(dpi)`

Obtiene todo el historial de una persona por DPI.

**Ejemplo:**
```sql
SELECT * FROM obtener_historial_persona('1234567890101');
```

## Vistas Útiles

### `vista_accesos_actuales`

Vista consolidada de todos los accesos con información completa:
- Datos de la persona
- Información de la solicitud
- Estado de vigencia
- Días restantes
- Estado de bloqueo

```sql
SELECT * FROM vista_accesos_actuales
WHERE estado_vigencia = 'POR_VENCER'
ORDER BY dias_restantes;
```

### `vista_dashboard_vencimientos`

Resumen ejecutivo para el dashboard:
- Accesos activos
- Por vencer
- Vencidos
- Bloqueados
- Vencen esta semana
- Vencen hoy

```sql
SELECT * FROM vista_dashboard_vencimientos;
```

## Configuración Inicial

El sistema incluye configuración por defecto en `configuracion_sistema`:

| Clave | Valor | Descripción |
|-------|-------|-------------|
| `DIAS_ALERTA_VENCIMIENTO` | 30 | Días antes para alertar |
| `DIAS_GRACIA_DEFAULT` | 15 | Días de gracia por defecto |
| `VIGENCIA_MESES` | 12 | Meses de vigencia VPN |
| `RUTA_ARCHIVOS` | `/var/vpn_archivos` | Ruta de archivos |

**Modificar configuración:**
```sql
UPDATE configuracion_sistema
SET valor = '20'
WHERE clave = 'DIAS_ALERTA_VENCIMIENTO';
```

## Usuario Inicial

**Credenciales por defecto:**
- Usuario: `admin`
- Contraseña: `Admin123!`
- Rol: `SUPERADMIN`

⚠️ **IMPORTANTE:** Cambiar esta contraseña inmediatamente después del primer login.

## Mantenimiento

### Backup Diario

```bash
pg_dump -h localhost -U postgres vpn_gestion > backup_$(date +%Y%m%d).sql
```

### Vacuuming (recomendado semanal)

```sql
VACUUM ANALYZE;
```

### Verificar tamaño de tablas

```sql
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

## Consultas Útiles

### Personas con accesos activos

```sql
SELECT p.dpi, p.nombres, p.apellidos, av.fecha_fin
FROM personas p
JOIN solicitudes_vpn s ON s.persona_id = p.id
JOIN accesos_vpn av ON av.solicitud_id = s.id
WHERE av.estado_vigencia = 'ACTIVO'
AND s.estado = 'APROBADA';
```

### Accesos que vencen en los próximos 7 días

```sql
SELECT *
FROM vista_accesos_actuales
WHERE dias_restantes BETWEEN 0 AND 7
ORDER BY dias_restantes;
```

### Historial de bloqueos de un acceso

```sql
SELECT 
    bv.id,
    bv.estado,
    bv.motivo,
    bv.fecha_cambio,
    u.nombre_completo as usuario
FROM bloqueos_vpn bv
JOIN usuarios_sistema u ON u.id = bv.usuario_id
WHERE bv.acceso_vpn_id = 123
ORDER BY bv.fecha_cambio DESC;
```

### Auditoría de acciones de un usuario

```sql
SELECT 
    ae.accion,
    ae.entidad,
    ae.fecha,
    ae.detalle_json
FROM auditoria_eventos ae
WHERE ae.usuario_id = 1
ORDER BY ae.fecha DESC
LIMIT 50;
```

## Seguridad

1. **Contraseñas**: Nunca almacenar en texto plano, siempre hash bcrypt
2. **Auditoría**: Tabla `auditoria_eventos` es inmutable
3. **Permisos**: Restringir acceso directo a BD, usar API
4. **Backups**: Automatizar backups diarios cifrados
5. **Logs**: Mantener logs de PostgreSQL separados

## Soporte y Contacto

Para modificaciones o consultas sobre la estructura de la base de datos, contactar al equipo de desarrollo.

---

**Versión:** 1.0.0  
**Última actualización:** 2025-01-01  
**PostgreSQL:** 12+
