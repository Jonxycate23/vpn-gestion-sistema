-- ========================================
-- REVERTIR CAMBIOS - RESTAURAR ESTADO ORIGINAL
-- Ejecutar: psql -h localhost -U postgres -d vpn_gestion -f REVERTIR_CAMBIOS.sql
-- ========================================

-- PASO 1: Ver estado actual
SELECT 'ESTADO ACTUAL:' as mensaje;
SELECT estado, tipo_solicitud, COUNT(*) 
FROM solicitudes_vpn 
GROUP BY estado, tipo_solicitud
ORDER BY estado, tipo_solicitud;

-- PASO 2: Eliminar constraint nuevo
ALTER TABLE solicitudes_vpn 
DROP CONSTRAINT IF EXISTS check_estado_solicitud_valido CASCADE;

-- PASO 3: Restaurar constraint original con 5 estados
ALTER TABLE solicitudes_vpn 
DROP CONSTRAINT IF EXISTS solicitudes_vpn_estado_check CASCADE;

ALTER TABLE solicitudes_vpn 
ADD CONSTRAINT solicitudes_vpn_estado_check 
CHECK (estado IN ('PENDIENTE', 'APROBADA', 'RECHAZADA', 'DENEGADA', 'CANCELADA'));

-- PASO 4: Revertir estados - TERMINADA → APROBADA
UPDATE solicitudes_vpn 
SET estado = 'APROBADA',
    comentarios_admin = REPLACE(
        REPLACE(comentarios_admin, '[Migrado: APROBADA→TERMINADA]', ''),
        '[Migrado automáticamente de APROBADA a TERMINADA]',
        ''
    )
WHERE estado = 'TERMINADA';

-- PASO 5: Limpiar justificaciones que se modificaron
UPDATE solicitudes_vpn 
SET justificacion = REGEXP_REPLACE(justificacion, '\n\n\[CANCELADA:.*?\]', '', 'g')
WHERE justificacion LIKE '%[CANCELADA:%';

UPDATE solicitudes_vpn 
SET justificacion = REGEXP_REPLACE(justificacion, '\n\n\[REACTIVADA:.*?\]', '', 'g')
WHERE justificacion LIKE '%[REACTIVADA:%';

-- PASO 6: Restaurar constraint de tipo_solicitud al original
ALTER TABLE solicitudes_vpn 
DROP CONSTRAINT IF EXISTS solicitudes_vpn_tipo_solicitud_check CASCADE;

ALTER TABLE solicitudes_vpn 
ADD CONSTRAINT solicitudes_vpn_tipo_solicitud_check 
CHECK (tipo_solicitud IN ('NUEVA', 'RENOVACION', 'CREACION', 'ACTUALIZACION'));

-- NO revertir tipo_solicitud porque los valores nuevos funcionan igual
-- Los dejamos como CREACION y ACTUALIZACION que son equivalentes

-- PASO 7: Actualizar comentarios
COMMENT ON COLUMN solicitudes_vpn.estado IS 'PENDIENTE, APROBADA, RECHAZADA, DENEGADA, CANCELADA';
COMMENT ON COLUMN solicitudes_vpn.tipo_solicitud IS 'NUEVA, RENOVACION, CREACION, ACTUALIZACION';

-- PASO 8: Verificar resultado final
SELECT 'ESTADO DESPUÉS DE REVERTIR:' as mensaje;
SELECT estado, tipo_solicitud, COUNT(*) 
FROM solicitudes_vpn 
GROUP BY estado, tipo_solicitud
ORDER BY estado, tipo_solicitud;

-- PASO 9: Ver todas las solicitudes
SELECT id, persona_id, estado, tipo_solicitud, fecha_solicitud
FROM solicitudes_vpn
ORDER BY id;

-- ========================================
-- ✅ RESULTADO ESPERADO:
-- ========================================
-- estado   | tipo_solicitud | count
-- ---------+----------------+-------
-- APROBADA | ACTUALIZACION  |   X
-- APROBADA | CREACION       |   X
-- (otros estados si existen)
