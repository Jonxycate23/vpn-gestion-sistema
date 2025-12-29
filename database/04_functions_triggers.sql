-- =====================================================
-- FUNCIONES Y TRIGGERS PARA AUDITORÍA AUTOMÁTICA
-- =====================================================

-- =====================================================
-- Función para actualizar estado de vigencia
-- =====================================================
CREATE OR REPLACE FUNCTION actualizar_estado_vigencia()
RETURNS void AS $$
BEGIN
    -- Marcar como VENCIDO los accesos que ya pasaron su fecha
    UPDATE accesos_vpn
    SET estado_vigencia = 'VENCIDO'
    WHERE estado_vigencia != 'VENCIDO'
    AND (
        (dias_gracia > 0 AND fecha_fin_con_gracia < CURRENT_DATE)
        OR (dias_gracia = 0 AND fecha_fin < CURRENT_DATE)
    );

    -- Marcar como POR_VENCER los que están a 30 días o menos
    UPDATE accesos_vpn
    SET estado_vigencia = 'POR_VENCER'
    WHERE estado_vigencia = 'ACTIVO'
    AND (
        (dias_gracia > 0 AND fecha_fin_con_gracia - CURRENT_DATE <= 30)
        OR (dias_gracia = 0 AND fecha_fin - CURRENT_DATE <= 30)
    );
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION actualizar_estado_vigencia IS 'Actualiza estados de vigencia según fechas - ejecutar diariamente';

-- =====================================================
-- Función para generar alertas automáticas
-- =====================================================
CREATE OR REPLACE FUNCTION generar_alertas_vencimiento()
RETURNS void AS $$
DECLARE
    dias_alerta INTEGER;
BEGIN
    -- Obtener configuración
    SELECT valor::INTEGER INTO dias_alerta
    FROM configuracion_sistema
    WHERE clave = 'DIAS_ALERTA_VENCIMIENTO';

    -- Generar alertas para accesos próximos a vencer
    INSERT INTO alertas_sistema (tipo, acceso_vpn_id, mensaje, fecha_generacion)
    SELECT 
        'VENCIMIENTO',
        av.id,
        'Acceso VPN próximo a vencer en ' || 
        CASE 
            WHEN av.dias_gracia > 0 THEN (av.fecha_fin_con_gracia - CURRENT_DATE)
            ELSE (av.fecha_fin - CURRENT_DATE)
        END || ' días',
        CURRENT_DATE
    FROM accesos_vpn av
    WHERE av.estado_vigencia IN ('ACTIVO', 'POR_VENCER')
    AND (
        (av.dias_gracia > 0 AND av.fecha_fin_con_gracia - CURRENT_DATE <= dias_alerta)
        OR (av.dias_gracia = 0 AND av.fecha_fin - CURRENT_DATE <= dias_alerta)
    )
    AND NOT EXISTS (
        SELECT 1 FROM alertas_sistema a
        WHERE a.acceso_vpn_id = av.id
        AND a.tipo = 'VENCIMIENTO'
        AND a.fecha_generacion = CURRENT_DATE
    );
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION generar_alertas_vencimiento IS 'Genera alertas diarias de vencimientos próximos';

-- =====================================================
-- Función para calcular fecha con gracia
-- =====================================================
CREATE OR REPLACE FUNCTION calcular_fecha_gracia()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.dias_gracia > 0 THEN
        NEW.fecha_fin_con_gracia := NEW.fecha_fin + (NEW.dias_gracia || ' days')::INTERVAL;
    ELSE
        NEW.fecha_fin_con_gracia := NEW.fecha_fin;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para calcular fecha de gracia automáticamente
CREATE TRIGGER trigger_calcular_fecha_gracia
BEFORE INSERT OR UPDATE ON accesos_vpn
FOR EACH ROW
EXECUTE FUNCTION calcular_fecha_gracia();

-- =====================================================
-- Vista para estado actual de accesos (útil para dashboard)
-- =====================================================
CREATE OR REPLACE VIEW vista_accesos_actuales AS
SELECT 
    p.id as persona_id,
    p.dpi,
    p.nombres,
    p.apellidos,
    p.institucion,
    p.cargo,
    s.id as solicitud_id,
    s.fecha_solicitud,
    s.tipo_solicitud,
    av.id as acceso_id,
    av.fecha_inicio,
    av.fecha_fin,
    av.dias_gracia,
    av.fecha_fin_con_gracia,
    av.estado_vigencia,
    CASE 
        WHEN av.dias_gracia > 0 THEN av.fecha_fin_con_gracia - CURRENT_DATE
        ELSE av.fecha_fin - CURRENT_DATE
    END as dias_restantes,
    (SELECT estado 
     FROM bloqueos_vpn bv 
     WHERE bv.acceso_vpn_id = av.id 
     ORDER BY bv.fecha_cambio DESC 
     LIMIT 1) as estado_bloqueo,
    u.nombre_completo as usuario_registro
FROM personas p
JOIN solicitudes_vpn s ON s.persona_id = p.id
JOIN accesos_vpn av ON av.solicitud_id = s.id
JOIN usuarios_sistema u ON u.id = av.usuario_creacion_id
WHERE s.estado = 'APROBADA'
ORDER BY av.fecha_fin;

COMMENT ON VIEW vista_accesos_actuales IS 'Vista consolidada de todos los accesos con información completa';

-- =====================================================
-- Vista para dashboard de vencimientos
-- =====================================================
CREATE OR REPLACE VIEW vista_dashboard_vencimientos AS
SELECT 
    COUNT(*) FILTER (WHERE estado_vigencia = 'ACTIVO' AND dias_restantes > 30) as activos,
    COUNT(*) FILTER (WHERE estado_vigencia = 'POR_VENCER') as por_vencer,
    COUNT(*) FILTER (WHERE estado_vigencia = 'VENCIDO') as vencidos,
    COUNT(*) FILTER (WHERE estado_bloqueo = 'BLOQUEADO') as bloqueados,
    COUNT(*) FILTER (WHERE dias_restantes <= 7 AND dias_restantes > 0) as vencen_esta_semana,
    COUNT(*) FILTER (WHERE dias_restantes = 0) as vencen_hoy
FROM vista_accesos_actuales;

COMMENT ON VIEW vista_dashboard_vencimientos IS 'Resumen ejecutivo para dashboard principal';

-- =====================================================
-- Función para obtener historial completo de una persona
-- =====================================================
CREATE OR REPLACE FUNCTION obtener_historial_persona(dpi_persona VARCHAR)
RETURNS TABLE (
    solicitud_id INTEGER,
    fecha_solicitud DATE,
    tipo_solicitud VARCHAR,
    estado_solicitud VARCHAR,
    acceso_id INTEGER,
    fecha_inicio DATE,
    fecha_fin DATE,
    estado_vigencia VARCHAR,
    bloqueado BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id,
        s.fecha_solicitud,
        s.tipo_solicitud,
        s.estado,
        av.id,
        av.fecha_inicio,
        av.fecha_fin,
        av.estado_vigencia,
        EXISTS(
            SELECT 1 FROM bloqueos_vpn bv
            WHERE bv.acceso_vpn_id = av.id
            AND bv.estado = 'BLOQUEADO'
            ORDER BY bv.fecha_cambio DESC
            LIMIT 1
        )
    FROM personas p
    JOIN solicitudes_vpn s ON s.persona_id = p.id
    LEFT JOIN accesos_vpn av ON av.solicitud_id = s.id
    WHERE p.dpi = dpi_persona
    ORDER BY s.fecha_solicitud DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION obtener_historial_persona IS 'Obtiene todo el historial de solicitudes y accesos de una persona';
