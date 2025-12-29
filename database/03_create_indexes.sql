-- =====================================================
-- ÍNDICES PARA RENDIMIENTO Y BÚSQUEDAS
-- =====================================================

-- Usuarios del sistema
CREATE INDEX idx_usuarios_username ON usuarios_sistema(username);
CREATE INDEX idx_usuarios_activo ON usuarios_sistema(activo);

-- Personas
CREATE INDEX idx_personas_dpi ON personas(dpi);
CREATE INDEX idx_personas_nombres ON personas(nombres);
CREATE INDEX idx_personas_apellidos ON personas(apellidos);
CREATE INDEX idx_personas_activo ON personas(activo);

-- Solicitudes VPN
CREATE INDEX idx_solicitudes_persona ON solicitudes_vpn(persona_id);
CREATE INDEX idx_solicitudes_estado ON solicitudes_vpn(estado);
CREATE INDEX idx_solicitudes_fecha ON solicitudes_vpn(fecha_solicitud);
CREATE INDEX idx_solicitudes_tipo ON solicitudes_vpn(tipo_solicitud);

-- Accesos VPN
CREATE INDEX idx_accesos_solicitud ON accesos_vpn(solicitud_id);
CREATE INDEX idx_accesos_estado ON accesos_vpn(estado_vigencia);
CREATE INDEX idx_accesos_fecha_fin ON accesos_vpn(fecha_fin);
CREATE INDEX idx_accesos_fecha_inicio ON accesos_vpn(fecha_inicio);
CREATE INDEX idx_accesos_gracia ON accesos_vpn(fecha_fin_con_gracia);

-- Bloqueos VPN
CREATE INDEX idx_bloqueos_acceso ON bloqueos_vpn(acceso_vpn_id);
CREATE INDEX idx_bloqueos_estado ON bloqueos_vpn(estado);
CREATE INDEX idx_bloqueos_fecha ON bloqueos_vpn(fecha_cambio);

-- Cartas de responsabilidad
CREATE INDEX idx_cartas_solicitud ON cartas_responsabilidad(solicitud_id);
CREATE INDEX idx_cartas_tipo ON cartas_responsabilidad(tipo);

-- Archivos adjuntos
CREATE INDEX idx_archivos_carta ON archivos_adjuntos(carta_id);
CREATE INDEX idx_archivos_hash ON archivos_adjuntos(hash_integridad);

-- Comentarios
CREATE INDEX idx_comentarios_entidad ON comentarios_admin(entidad, entidad_id);
CREATE INDEX idx_comentarios_fecha ON comentarios_admin(fecha);

-- Auditoría (CRÍTICO para reportes)
CREATE INDEX idx_auditoria_usuario ON auditoria_eventos(usuario_id);
CREATE INDEX idx_auditoria_fecha ON auditoria_eventos(fecha);
CREATE INDEX idx_auditoria_accion ON auditoria_eventos(accion);
CREATE INDEX idx_auditoria_entidad ON auditoria_eventos(entidad, entidad_id);
CREATE INDEX idx_auditoria_detalle ON auditoria_eventos USING GIN (detalle_json);

-- Alertas
CREATE INDEX idx_alertas_tipo ON alertas_sistema(tipo);
CREATE INDEX idx_alertas_leida ON alertas_sistema(leida);
CREATE INDEX idx_alertas_fecha ON alertas_sistema(fecha_generacion);
CREATE INDEX idx_alertas_acceso ON alertas_sistema(acceso_vpn_id);

-- Sesiones
CREATE INDEX idx_sesiones_usuario ON sesiones_login(usuario_id);
CREATE INDEX idx_sesiones_activa ON sesiones_login(activa);
CREATE INDEX idx_sesiones_fecha ON sesiones_login(fecha_inicio);
