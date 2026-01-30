-- ====================================================================
-- VISTA OPTIMIZADA: Accesos Actuales con NIP
-- ✅ Incluye NIP en la vista para evitar queries adicionales
-- ====================================================================

CREATE OR REPLACE VIEW vista_accesos_actuales AS
SELECT 
    p.id AS persona_id,
    p.dpi,
    p.nip,  -- ✅ AGREGADO: NIP incluido en la vista
    p.nombres,
    p.apellidos,
    p.institucion,
    p.cargo,
    s.id AS solicitud_id,
    s.fecha_solicitud,
    s.tipo_solicitud,
    a.id AS acceso_id,
    a.fecha_inicio,
    a.fecha_fin,
    a.dias_gracia,
    a.fecha_fin_con_gracia,
    a.estado_vigencia,
    (a.fecha_fin_con_gracia - CURRENT_DATE) AS dias_restantes,
    COALESCE(
        (SELECT b.estado 
         FROM bloqueos_vpn b 
         WHERE b.acceso_vpn_id = a.id 
         ORDER BY b.fecha_cambio DESC 
         LIMIT 1),
        'DESBLOQUEADO'
    ) AS estado_bloqueo,
    u.nombre_completo AS usuario_registro
FROM accesos_vpn a
JOIN solicitudes_vpn s ON s.id = a.solicitud_id
JOIN personas p ON p.id = s.persona_id
LEFT JOIN usuarios_sistema u ON u.id = s.usuario_registro_id
ORDER BY a.fecha_fin_con_gracia;

-- ====================================================================
-- ÍNDICES ADICIONALES PARA MEJORAR RENDIMIENTO
-- ====================================================================

-- Índice compuesto para búsquedas complejas
CREATE INDEX IF NOT EXISTS idx_accesos_vigencia_fecha 
ON accesos_vpn(estado_vigencia, fecha_fin_con_gracia);

-- Índice para joins frecuentes
CREATE INDEX IF NOT EXISTS idx_solicitudes_persona 
ON solicitudes_vpn(persona_id, estado);

-- Índice para bloqueos (último estado)
CREATE INDEX IF NOT EXISTS idx_bloqueos_fecha_desc 
ON bloqueos_vpn(acceso_vpn_id, fecha_cambio DESC);

-- Índice para cartas por año
CREATE INDEX IF NOT EXISTS idx_cartas_anio 
ON cartas_responsabilidad(anio_carta, numero_carta);

-- Índice para personas por NIP
CREATE INDEX IF NOT EXISTS idx_personas_nip 
ON personas(nip) WHERE nip IS NOT NULL;

-- ====================================================================
-- ANÁLISIS DE LA TABLA (actualizar estadísticas para el optimizador)
-- ====================================================================

ANALYZE personas;
ANALYZE solicitudes_vpn;
ANALYZE accesos_vpn;
ANALYZE bloqueos_vpn;
ANALYZE cartas_responsabilidad;

-- ====================================================================
-- VERIFICAR ÍNDICES CREADOS
-- ====================================================================

SELECT 
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('personas', 'solicitudes_vpn', 'accesos_vpn', 'bloqueos_vpn', 'cartas_responsabilidad')
ORDER BY tablename, indexname;
