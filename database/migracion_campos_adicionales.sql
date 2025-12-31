-- =====================================================
-- MIGRACIÓN: Agregar campos faltantes a personas y solicitudes
-- =====================================================

-- 1. Agregar NIP a tabla personas
ALTER TABLE personas
ADD COLUMN IF NOT EXISTS nip VARCHAR(20);

COMMENT ON COLUMN personas.nip IS 'Número de Identificación Policial';

-- 2. Agregar campos a solicitudes_vpn
ALTER TABLE solicitudes_vpn
ADD COLUMN IF NOT EXISTS numero_oficio VARCHAR(50),
ADD COLUMN IF NOT EXISTS numero_providencia VARCHAR(50),
ADD COLUMN IF NOT EXISTS fecha_recepcion DATE;

COMMENT ON COLUMN solicitudes_vpn.numero_oficio IS 'Número de oficio recibido';
COMMENT ON COLUMN solicitudes_vpn.numero_providencia IS 'Número de providencia';
COMMENT ON COLUMN solicitudes_vpn.fecha_recepcion IS 'Fecha en que se recibió la solicitud física';

-- 3. Actualizar índices para búsquedas
CREATE INDEX IF NOT EXISTS idx_personas_nip ON personas(nip);
CREATE INDEX IF NOT EXISTS idx_solicitudes_oficio ON solicitudes_vpn(numero_oficio);
CREATE INDEX IF NOT EXISTS idx_solicitudes_providencia ON solicitudes_vpn(numero_providencia);

-- 4. Actualizar datos existentes con valores por defecto
UPDATE solicitudes_vpn 
SET fecha_recepcion = fecha_solicitud 
WHERE fecha_recepcion IS NULL;

-- 5. Verificar cambios
SELECT 
    column_name, 
    data_type, 
    character_maximum_length,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'personas' 
  AND column_name IN ('dpi', 'nip', 'nombres', 'apellidos', 'institucion', 'cargo', 'telefono', 'email')
ORDER BY ordinal_position;

SELECT 
    column_name, 
    data_type, 
    character_maximum_length,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'solicitudes_vpn' 
  AND column_name IN ('numero_oficio', 'numero_providencia', 'fecha_recepcion', 'fecha_solicitud', 'tipo_solicitud', 'justificacion')
ORDER BY ordinal_position;

-- =====================================================
-- RESULTADO ESPERADO:
-- =====================================================
-- personas ahora tiene: dpi, nip, nombres, apellidos, institucion, cargo, telefono, email
-- solicitudes_vpn ahora tiene: numero_oficio, numero_providencia, fecha_recepcion, fecha_solicitud, tipo_solicitud, justificacion
