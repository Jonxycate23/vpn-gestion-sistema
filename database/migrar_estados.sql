-- ========================================
-- MIGRACIÃ"N DEFINITIVA: 3 ESTADOS
-- Ejecutar: psql -h localhost -U postgres -d vpn_gestion -f MIGRAR_ESTADOS_DEFINITIVO.sql
-- ========================================

-- PASO 1: Ver los constraints actuales
SELECT conname, pg_get_constraintdef(oid) 
FROM pg_constraint 
WHERE conrelid = 'solicitudes_vpn'::regclass 
  AND contype = 'c';

-- PASO 2: Ver los datos ANTES de cambiar
SELECT estado, COUNT(*) 
FROM solicitudes_vpn 
GROUP BY estado;

-- PASO 3: ELIMINAR TODOS LOS CONSTRAINTS DE ESTADO
-- (Tanto el anónimo como cualquier otro)
ALTER TABLE solicitudes_vpn 
DROP CONSTRAINT IF EXISTS solicitudes_vpn_estado_check CASCADE;

ALTER TABLE solicitudes_vpn 
DROP CONSTRAINT IF EXISTS check_estado_solicitud_valido CASCADE;

-- PASO 4: ACTUALIZAR DATOS (ahora sin constraints que molesten)

-- Cambiar APROBADA → PENDIENTE (las que NO tienen carta)
UPDATE solicitudes_vpn 
SET estado = 'PENDIENTE' 
WHERE estado = 'APROBADA' 
  AND id NOT IN (
      SELECT DISTINCT solicitud_id 
      FROM cartas_responsabilidad
  );

-- Cambiar APROBADA → TERMINADA (las que SÃ tienen carta)
UPDATE solicitudes_vpn 
SET estado = 'TERMINADA',
    comentarios_admin = COALESCE(comentarios_admin || ' | ', '') || '[Migrado: APROBADA→TERMINADA]'
WHERE estado = 'APROBADA' 
  AND id IN (
      SELECT DISTINCT solicitud_id 
      FROM cartas_responsabilidad
  );

-- Cambiar RECHAZADA → CANCELADA
UPDATE solicitudes_vpn 
SET estado = 'CANCELADA',
    comentarios_admin = COALESCE(comentarios_admin || ' | ', '') || '[Migrado: RECHAZADA→CANCELADA]'
WHERE estado = 'RECHAZADA';

-- Cambiar DENEGADA → CANCELADA (por si existe)
UPDATE solicitudes_vpn 
SET estado = 'CANCELADA',
    comentarios_admin = COALESCE(comentarios_admin || ' | ', '') || '[Migrado: DENEGADA→CANCELADA]'
WHERE estado = 'DENEGADA';

-- PASO 5: Verificar que TODO estÃ© en los 3 estados permitidos
SELECT estado, COUNT(*) 
FROM solicitudes_vpn 
GROUP BY estado;

-- PASO 6: AHORA SÃ crear el constraint nuevo
ALTER TABLE solicitudes_vpn 
ADD CONSTRAINT check_estado_solicitud_valido 
CHECK (estado IN ('PENDIENTE', 'TERMINADA', 'CANCELADA'));

-- PASO 7: Actualizar constraint de tipo_solicitud
ALTER TABLE solicitudes_vpn 
DROP CONSTRAINT IF EXISTS solicitudes_vpn_tipo_solicitud_check CASCADE;

ALTER TABLE solicitudes_vpn 
ADD CONSTRAINT solicitudes_vpn_tipo_solicitud_check 
CHECK (tipo_solicitud IN ('CREACION', 'ACTUALIZACION'));

-- PASO 8: Actualizar los valores de tipo_solicitud
UPDATE solicitudes_vpn 
SET tipo_solicitud = 'CREACION' 
WHERE tipo_solicitud = 'NUEVA';

UPDATE solicitudes_vpn 
SET tipo_solicitud = 'ACTUALIZACION' 
WHERE tipo_solicitud = 'RENOVACION';

-- PASO 9: Actualizar comentarios
COMMENT ON COLUMN solicitudes_vpn.estado IS 'PENDIENTE: esperando crear carta, TERMINADA: carta creada y acceso activo, CANCELADA: no se presentó';
COMMENT ON COLUMN solicitudes_vpn.tipo_solicitud IS 'CREACION: nueva solicitud, ACTUALIZACION: renovación';

-- PASO 10: Verificación FINAL
SELECT 
    estado,
    COUNT(*) as total,
    COUNT(CASE WHEN id IN (SELECT solicitud_id FROM cartas_responsabilidad) THEN 1 END) as con_carta
FROM solicitudes_vpn
GROUP BY estado
ORDER BY estado;

SELECT tipo_solicitud, COUNT(*) 
FROM solicitudes_vpn 
GROUP BY tipo_solicitud;

-- ========================================
-- âœ… RESULTADO ESPERADO:
-- ========================================
-- estado    | total | con_carta
-- ----------+-------+-----------
-- CANCELADA |   X   |    X
-- PENDIENTE |   X   |    0
-- TERMINADA |   X   |    X
--
-- tipo_solicitud | count
-- ---------------+-------
-- ACTUALIZACION  |   X
-- CREACION       |   X