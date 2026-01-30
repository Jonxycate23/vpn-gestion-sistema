-- =====================================================
-- ÍNDICES DE RENDIMIENTO PARA SISTEMA VPN
-- =====================================================
-- 📍 Ubicación: database/migrations/add_performance_indexes.sql
-- 🎯 Objetivo: Mejorar performance de queries frecuentes
-- ⚡ Impacto esperado: Reducir tiempo de carga de ~10s a <2s

-- =====================================================
-- 1. ÍNDICES PARA ACCESO VPN
-- =====================================================

-- Índice para ordenar por fecha de vencimiento (usado en dashboard y accesos)
CREATE INDEX IF NOT EXISTS idx_acceso_vpn_fecha_fin 
ON acceso_vpn(fecha_fin_con_gracia DESC);

-- Índice para filtrar por estado de vigencia
CREATE INDEX IF NOT EXISTS idx_acceso_vpn_estado_vigencia 
ON acceso_vpn(estado_vigencia);

-- Índice compuesto para joins con solicitudes
CREATE INDEX IF NOT EXISTS idx_acceso_vpn_solicitud 
ON acceso_vpn(solicitud_id);

-- =====================================================
-- 2. ÍNDICES PARA BLOQUEO VPN
-- =====================================================

-- Índice compuesto para obtener último bloqueo por acceso
-- Este es CRÍTICO para evitar N+1 queries
CREATE INDEX IF NOT EXISTS idx_bloqueo_vpn_acceso_fecha 
ON bloqueo_vpn(acceso_vpn_id, fecha_cambio DESC);

-- Índice para filtrar por estado
CREATE INDEX IF NOT EXISTS idx_bloqueo_vpn_estado 
ON bloqueo_vpn(estado);

-- =====================================================
-- 3. ÍNDICES PARA SOLICITUDES VPN
-- =====================================================

-- Índice para filtrar por estado (PENDIENTE, APROBADA, etc.)
CREATE INDEX IF NOT EXISTS idx_solicitud_vpn_estado 
ON solicitud_vpn(estado);

-- Índice para ordenar por ID (usado en ordenamiento)
CREATE INDEX IF NOT EXISTS idx_solicitud_vpn_id_desc 
ON solicitud_vpn(id DESC);

-- Índice compuesto para joins con personas
CREATE INDEX IF NOT EXISTS idx_solicitud_vpn_persona 
ON solicitud_vpn(persona_id);

-- Índice para búsqueda por fecha
CREATE INDEX IF NOT EXISTS idx_solicitud_vpn_fecha 
ON solicitud_vpn(fecha_solicitud DESC);

-- =====================================================
-- 4. ÍNDICES PARA CARTAS DE RESPONSABILIDAD
-- =====================================================

-- Índice para contar cartas por año (usado en dashboard)
CREATE INDEX IF NOT EXISTS idx_carta_anio 
ON carta_responsabilidad(anio_carta);

-- Índice compuesto para joins con solicitudes
CREATE INDEX IF NOT EXISTS idx_carta_solicitud 
ON carta_responsabilidad(solicitud_id);

-- Índice para ordenar por fecha de generación
CREATE INDEX IF NOT EXISTS idx_carta_fecha_generacion 
ON carta_responsabilidad(fecha_generacion DESC);

-- =====================================================
-- 5. ÍNDICES PARA PERSONAS
-- =====================================================

-- Índice para búsqueda por NIP
CREATE INDEX IF NOT EXISTS idx_persona_nip 
ON persona(nip);

-- Índice para búsqueda por DPI
CREATE INDEX IF NOT EXISTS idx_persona_dpi 
ON persona(dpi);

-- Índice para búsqueda por nombre
CREATE INDEX IF NOT EXISTS idx_persona_nombres 
ON persona(nombres);

-- =====================================================
-- 6. ÍNDICES PARA USUARIOS SISTEMA
-- =====================================================

-- Índice para login por username
CREATE INDEX IF NOT EXISTS idx_usuario_username 
ON usuario_sistema(username);

-- =====================================================
-- VERIFICACIÓN DE ÍNDICES CREADOS
-- =====================================================

-- Query para verificar los índices creados
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
    AND tablename IN ('acceso_vpn', 'bloqueo_vpn', 'solicitud_vpn', 'carta_responsabilidad', 'persona', 'usuario_sistema')
ORDER BY tablename, indexname;

-- =====================================================
-- ESTADÍSTICAS DE TABLAS (para verificar impacto)
-- =====================================================

-- Actualizar estadísticas después de crear índices
ANALYZE acceso_vpn;
ANALYZE bloqueo_vpn;
ANALYZE solicitud_vpn;
ANALYZE carta_responsabilidad;
ANALYZE persona;
ANALYZE usuario_sistema;

-- =====================================================
-- NOTAS DE MANTENIMIENTO
-- =====================================================

-- Los índices se actualizan automáticamente con INSERT/UPDATE/DELETE
-- Para verificar uso de índices, usar EXPLAIN ANALYZE en queries
-- Ejemplo:
-- EXPLAIN ANALYZE SELECT * FROM acceso_vpn ORDER BY fecha_fin_con_gracia DESC LIMIT 100;
