-- =====================================================
-- DATOS INICIALES DEL SISTEMA
-- =====================================================

-- =====================================================
-- Usuario SUPERADMIN por defecto
-- Password: Admin123! (CAMBIAR EN PRODUCCIÓN)
-- =====================================================
-- El hash corresponde a bcrypt de "Admin123!"
-- IMPORTANTE: Cambiar esta contraseña inmediatamente después del primer login
INSERT INTO usuarios_sistema (
    username, 
    password_hash, 
    nombre_completo, 
    email, 
    rol, 
    activo
) VALUES (
    'admin',
    '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYqNqQqvqhi',
    'Administrador del Sistema',
    'admin@institucion.gob.gt',
    'SUPERADMIN',
    TRUE
);

-- =====================================================
-- Registro de auditoría del setup inicial
-- =====================================================
INSERT INTO auditoria_eventos (
    usuario_id,
    accion,
    entidad,
    entidad_id,
    detalle_json,
    ip_origen,
    fecha
) VALUES (
    1,
    'SETUP_INICIAL',
    'SISTEMA',
    NULL,
    '{"mensaje": "Configuración inicial del sistema completada", "version": "1.0.0"}',
    'localhost',
    NOW()
);

-- =====================================================
-- Comentario informativo
-- =====================================================
COMMENT ON DATABASE vpn_gestion IS 'Sistema de Gestión de Accesos VPN - Institución Pública';

-- =====================================================
-- Mensaje de finalización
-- =====================================================
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'BASE DE DATOS CREADA EXITOSAMENTE';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Usuario por defecto: admin';
    RAISE NOTICE 'Contraseña: Admin123!';
    RAISE NOTICE '¡CAMBIAR CONTRASEÑA INMEDIATAMENTE!';
    RAISE NOTICE '========================================';
END $$;
