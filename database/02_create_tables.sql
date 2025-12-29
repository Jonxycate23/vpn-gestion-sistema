-- =====================================================
-- TABLAS PRINCIPALES DEL SISTEMA
-- =====================================================

-- =====================================================
-- 1. USUARIOS DEL SISTEMA (Autenticación interna)
-- =====================================================
CREATE TABLE usuarios_sistema (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    nombre_completo VARCHAR(150) NOT NULL,
    email VARCHAR(150),
    rol VARCHAR(20) NOT NULL CHECK (rol IN ('SUPERADMIN', 'ADMIN')),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT NOW(),
    fecha_ultimo_login TIMESTAMP,
    CONSTRAINT username_lowercase CHECK (username = LOWER(username))
);

COMMENT ON TABLE usuarios_sistema IS 'Usuarios internos que operan el sistema';
COMMENT ON COLUMN usuarios_sistema.rol IS 'SUPERADMIN: configuración y auditoría, ADMIN: operación';
COMMENT ON COLUMN usuarios_sistema.password_hash IS 'Hash bcrypt de la contraseña';

-- =====================================================
-- 2. PERSONAS (Identidad real - solicitantes VPN)
-- =====================================================
CREATE TABLE personas (
    id SERIAL PRIMARY KEY,
    dpi VARCHAR(20) UNIQUE NOT NULL,
    nombres VARCHAR(150) NOT NULL,
    apellidos VARCHAR(150) NOT NULL,
    institucion VARCHAR(200),
    cargo VARCHAR(150),
    telefono VARCHAR(50),
    email VARCHAR(150),
    observaciones TEXT,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE personas IS 'Entidad real que solicita acceso VPN (puede tener múltiples solicitudes)';
COMMENT ON COLUMN personas.dpi IS 'Documento Personal de Identificación - único e inmutable';

-- =====================================================
-- 3. SOLICITUDES VPN (Historial completo)
-- =====================================================
CREATE TABLE solicitudes_vpn (
    id SERIAL PRIMARY KEY,
    persona_id INTEGER NOT NULL REFERENCES personas(id),
    fecha_solicitud DATE NOT NULL,
    tipo_solicitud VARCHAR(20) NOT NULL CHECK (tipo_solicitud IN ('NUEVA', 'RENOVACION')),
    justificacion TEXT NOT NULL,
    estado VARCHAR(20) NOT NULL CHECK (estado IN ('APROBADA', 'RECHAZADA', 'CANCELADA')),
    usuario_registro_id INTEGER NOT NULL REFERENCES usuarios_sistema(id),
    comentarios_admin TEXT,
    fecha_registro TIMESTAMP NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE solicitudes_vpn IS 'Expediente administrativo - NUNCA se sobreescribe';
COMMENT ON COLUMN solicitudes_vpn.tipo_solicitud IS 'NUEVA: primer acceso, RENOVACION: después de 12 meses';
COMMENT ON COLUMN solicitudes_vpn.estado IS 'Estado administrativo final de la solicitud';

-- =====================================================
-- 4. ACCESOS VPN (Vigencia técnica)
-- =====================================================
CREATE TABLE accesos_vpn (
    id SERIAL PRIMARY KEY,
    solicitud_id INTEGER NOT NULL REFERENCES solicitudes_vpn(id),
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    dias_gracia INTEGER DEFAULT 0,
    fecha_fin_con_gracia DATE,
    estado_vigencia VARCHAR(20) NOT NULL CHECK (
        estado_vigencia IN ('ACTIVO', 'POR_VENCER', 'VENCIDO')
    ),
    usuario_creacion_id INTEGER NOT NULL REFERENCES usuarios_sistema(id),
    fecha_creacion TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT vigencia_12_meses CHECK (fecha_fin = fecha_inicio + INTERVAL '12 months')
);

COMMENT ON TABLE accesos_vpn IS 'Control real de vigencia - separado de la solicitud';
COMMENT ON COLUMN accesos_vpn.dias_gracia IS 'Días adicionales otorgados administrativamente';
COMMENT ON COLUMN accesos_vpn.estado_vigencia IS 'ACTIVO: vigente, POR_VENCER: 30 días antes, VENCIDO: después de fecha_fin';

-- =====================================================
-- 5. BLOQUEOS VPN (Separado de vigencia)
-- =====================================================
CREATE TABLE bloqueos_vpn (
    id SERIAL PRIMARY KEY,
    acceso_vpn_id INTEGER NOT NULL REFERENCES accesos_vpn(id),
    estado VARCHAR(20) NOT NULL CHECK (estado IN ('BLOQUEADO', 'DESBLOQUEADO')),
    motivo TEXT NOT NULL,
    usuario_id INTEGER NOT NULL REFERENCES usuarios_sistema(id),
    fecha_cambio TIMESTAMP NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE bloqueos_vpn IS 'Histórico de bloqueos/desbloqueos - crítico para auditoría';
COMMENT ON COLUMN bloqueos_vpn.motivo IS 'OBLIGATORIO: justificación administrativa del cambio';

-- =====================================================
-- 6. CARTAS DE RESPONSABILIDAD
-- =====================================================
CREATE TABLE cartas_responsabilidad (
    id SERIAL PRIMARY KEY,
    solicitud_id INTEGER NOT NULL REFERENCES solicitudes_vpn(id),
    tipo VARCHAR(30) NOT NULL CHECK (
        tipo IN ('RESPONSABILIDAD', 'PRORROGA', 'OTRO')
    ),
    fecha_generacion DATE NOT NULL,
    generada_por_usuario_id INTEGER NOT NULL REFERENCES usuarios_sistema(id)
);

COMMENT ON TABLE cartas_responsabilidad IS 'Metadatos de documentos legales';
COMMENT ON COLUMN cartas_responsabilidad.tipo IS 'RESPONSABILIDAD: carta inicial, PRORROGA: extensión';

-- =====================================================
-- 7. ARCHIVOS ADJUNTOS (PDFs, imágenes firmadas)
-- =====================================================
CREATE TABLE archivos_adjuntos (
    id SERIAL PRIMARY KEY,
    carta_id INTEGER NOT NULL REFERENCES cartas_responsabilidad(id),
    nombre_archivo VARCHAR(255) NOT NULL,
    ruta_archivo TEXT NOT NULL,
    tipo_mime VARCHAR(100),
    hash_integridad VARCHAR(64),
    tamano_bytes BIGINT,
    fecha_subida TIMESTAMP NOT NULL DEFAULT NOW(),
    usuario_subida_id INTEGER NOT NULL REFERENCES usuarios_sistema(id)
);

COMMENT ON TABLE archivos_adjuntos IS 'Almacenamiento de archivos firmados - NUNCA en BD';
COMMENT ON COLUMN archivos_adjuntos.hash_integridad IS 'SHA-256 para verificar integridad';
COMMENT ON COLUMN archivos_adjuntos.ruta_archivo IS 'Path relativo en filesystem interno';

-- =====================================================
-- 8. COMENTARIOS ADMINISTRATIVOS
-- =====================================================
CREATE TABLE comentarios_admin (
    id SERIAL PRIMARY KEY,
    entidad VARCHAR(30) NOT NULL CHECK (
        entidad IN ('PERSONA', 'SOLICITUD', 'ACCESO', 'BLOQUEO')
    ),
    entidad_id INTEGER NOT NULL,
    comentario TEXT NOT NULL,
    usuario_id INTEGER NOT NULL REFERENCES usuarios_sistema(id),
    fecha TIMESTAMP NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE comentarios_admin IS 'Bitácora operativa humana - contexto institucional';

-- =====================================================
-- 9. AUDITORÍA DE EVENTOS (INMUTABLE)
-- =====================================================
CREATE TABLE auditoria_eventos (
    id SERIAL PRIMARY KEY,
    usuario_id INTEGER REFERENCES usuarios_sistema(id),
    accion VARCHAR(50) NOT NULL,
    entidad VARCHAR(30) NOT NULL,
    entidad_id INTEGER,
    detalle_json JSONB,
    ip_origen VARCHAR(50),
    fecha TIMESTAMP NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE auditoria_eventos IS 'CRÍTICO: registro completo de acciones - NUNCA se edita ni elimina';
COMMENT ON COLUMN auditoria_eventos.detalle_json IS 'Snapshot completo del cambio en formato JSON';
COMMENT ON COLUMN auditoria_eventos.accion IS 'Ejemplos: CREAR, EDITAR, BLOQUEAR, DESBLOQUEAR, LOGIN, IMPORTAR';

-- =====================================================
-- 10. ALERTAS INTERNAS
-- =====================================================
CREATE TABLE alertas_sistema (
    id SERIAL PRIMARY KEY,
    tipo VARCHAR(30) NOT NULL CHECK (
        tipo IN ('VENCIMIENTO', 'GRACIA', 'BLOQUEO_PENDIENTE')
    ),
    acceso_vpn_id INTEGER REFERENCES accesos_vpn(id),
    mensaje TEXT NOT NULL,
    fecha_generacion DATE NOT NULL,
    leida BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_lectura TIMESTAMP
);

COMMENT ON TABLE alertas_sistema IS 'Alertas operativas internas - dashboard diario';

-- =====================================================
-- 11. IMPORTACIONES DESDE EXCEL
-- =====================================================
CREATE TABLE importaciones_excel (
    id SERIAL PRIMARY KEY,
    archivo_origen VARCHAR(255),
    fecha_importacion TIMESTAMP NOT NULL DEFAULT NOW(),
    usuario_id INTEGER NOT NULL REFERENCES usuarios_sistema(id),
    registros_procesados INTEGER DEFAULT 0,
    registros_exitosos INTEGER DEFAULT 0,
    registros_fallidos INTEGER DEFAULT 0,
    resultado TEXT,
    log_errores TEXT
);

COMMENT ON TABLE importaciones_excel IS 'Trazabilidad de migración desde Excel';

-- =====================================================
-- 12. CONFIGURACIÓN DEL SISTEMA
-- =====================================================
CREATE TABLE configuracion_sistema (
    id SERIAL PRIMARY KEY,
    clave VARCHAR(100) UNIQUE NOT NULL,
    valor TEXT NOT NULL,
    descripcion TEXT,
    tipo_dato VARCHAR(20) CHECK (tipo_dato IN ('STRING', 'INTEGER', 'BOOLEAN', 'JSON')),
    fecha_modificacion TIMESTAMP NOT NULL DEFAULT NOW(),
    modificado_por INTEGER REFERENCES usuarios_sistema(id)
);

COMMENT ON TABLE configuracion_sistema IS 'Configuraciones operativas del sistema';

-- Configuraciones iniciales
INSERT INTO configuracion_sistema (clave, valor, descripcion, tipo_dato) VALUES
('DIAS_ALERTA_VENCIMIENTO', '30', 'Días antes del vencimiento para generar alerta', 'INTEGER'),
('DIAS_GRACIA_DEFAULT', '15', 'Días de gracia por defecto', 'INTEGER'),
('VIGENCIA_MESES', '12', 'Meses de vigencia de acceso VPN', 'INTEGER'),
('RUTA_ARCHIVOS', '/var/vpn_archivos', 'Ruta base para almacenamiento de archivos', 'STRING');

-- =====================================================
-- 13. CATÁLOGOS (Normalización)
-- =====================================================
CREATE TABLE catalogos (
    id SERIAL PRIMARY KEY,
    tipo VARCHAR(50) NOT NULL,
    codigo VARCHAR(50) NOT NULL,
    descripcion VARCHAR(200) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE(tipo, codigo)
);

COMMENT ON TABLE catalogos IS 'Valores normalizados para listas desplegables';

-- Catálogos iniciales
INSERT INTO catalogos (tipo, codigo, descripcion) VALUES
('MOTIVO_BLOQUEO', 'VENCIMIENTO', 'Vencimiento de vigencia'),
('MOTIVO_BLOQUEO', 'ADMINISTRATIVO', 'Decisión administrativa'),
('MOTIVO_BLOQUEO', 'SEGURIDAD', 'Incidente de seguridad'),
('MOTIVO_BLOQUEO', 'FINALIZACION_LABORAL', 'Terminación de relación laboral'),
('MOTIVO_DESBLOQUEO', 'RENOVACION', 'Renovación aprobada'),
('MOTIVO_DESBLOQUEO', 'PRORROGA', 'Prórroga administrativa'),
('MOTIVO_DESBLOQUEO', 'ERROR', 'Corrección de error administrativo');

-- =====================================================
-- 14. SESIONES DE LOGIN (Auditoría de acceso)
-- =====================================================
CREATE TABLE sesiones_login (
    id SERIAL PRIMARY KEY,
    usuario_id INTEGER NOT NULL REFERENCES usuarios_sistema(id),
    token_hash VARCHAR(64),
    ip_origen VARCHAR(50),
    user_agent TEXT,
    fecha_inicio TIMESTAMP NOT NULL DEFAULT NOW(),
    fecha_expiracion TIMESTAMP,
    activa BOOLEAN NOT NULL DEFAULT TRUE
);

COMMENT ON TABLE sesiones_login IS 'Control de sesiones activas y auditoría de accesos';
