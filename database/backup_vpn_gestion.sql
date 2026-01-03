--
-- PostgreSQL database dump
--

\restrict znvvUuM4xaU1cLAgeSRvqlqO7FnbQvGgYad1TV6JOHebrnTPovrCsNSSncuv5wV

-- Dumped from database version 16.11
-- Dumped by pg_dump version 16.11

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: actualizar_estado_vigencia(); Type: FUNCTION; Schema: public; Owner: vpn_user
--

CREATE FUNCTION public.actualizar_estado_vigencia() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Marcar como VENCIDO los accesos que ya pasaron su fecha
    UPDATE accesos_vpn
    SET estado_vigencia = 'VENCIDO'
    WHERE estado_vigencia != 'VENCIDO'
    AND (
        (dias_gracia > 0 AND fecha_fin_con_gracia < CURRENT_DATE)
        OR (dias_gracia = 0 AND fecha_fin < CURRENT_DATE)
    );

    -- Marcar como POR_VENCER los que estÃ¡n a 30 dÃ­as o menos
    UPDATE accesos_vpn
    SET estado_vigencia = 'POR_VENCER'
    WHERE estado_vigencia = 'ACTIVO'
    AND (
        (dias_gracia > 0 AND fecha_fin_con_gracia - CURRENT_DATE <= 30)
        OR (dias_gracia = 0 AND fecha_fin - CURRENT_DATE <= 30)
    );
END;
$$;


ALTER FUNCTION public.actualizar_estado_vigencia() OWNER TO vpn_user;

--
-- Name: FUNCTION actualizar_estado_vigencia(); Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON FUNCTION public.actualizar_estado_vigencia() IS 'Actualiza estados de vigencia segÃºn fechas - ejecutar diariamente';


--
-- Name: calcular_fecha_gracia(); Type: FUNCTION; Schema: public; Owner: vpn_user
--

CREATE FUNCTION public.calcular_fecha_gracia() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.dias_gracia > 0 THEN
        NEW.fecha_fin_con_gracia := NEW.fecha_fin + (NEW.dias_gracia || ' days')::INTERVAL;
    ELSE
        NEW.fecha_fin_con_gracia := NEW.fecha_fin;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.calcular_fecha_gracia() OWNER TO vpn_user;

--
-- Name: generar_alertas_vencimiento(); Type: FUNCTION; Schema: public; Owner: vpn_user
--

CREATE FUNCTION public.generar_alertas_vencimiento() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    dias_alerta INTEGER;
BEGIN
    -- Obtener configuraciÃ³n
    SELECT valor::INTEGER INTO dias_alerta
    FROM configuracion_sistema
    WHERE clave = 'DIAS_ALERTA_VENCIMIENTO';

    -- Generar alertas para accesos prÃ³ximos a vencer
    INSERT INTO alertas_sistema (tipo, acceso_vpn_id, mensaje, fecha_generacion)
    SELECT 
        'VENCIMIENTO',
        av.id,
        'Acceso VPN prÃ³ximo a vencer en ' || 
        CASE 
            WHEN av.dias_gracia > 0 THEN (av.fecha_fin_con_gracia - CURRENT_DATE)
            ELSE (av.fecha_fin - CURRENT_DATE)
        END || ' dÃ­as',
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
$$;


ALTER FUNCTION public.generar_alertas_vencimiento() OWNER TO vpn_user;

--
-- Name: FUNCTION generar_alertas_vencimiento(); Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON FUNCTION public.generar_alertas_vencimiento() IS 'Genera alertas diarias de vencimientos prÃ³ximos';


--
-- Name: obtener_historial_persona(character varying); Type: FUNCTION; Schema: public; Owner: vpn_user
--

CREATE FUNCTION public.obtener_historial_persona(dpi_persona character varying) RETURNS TABLE(solicitud_id integer, fecha_solicitud date, tipo_solicitud character varying, estado_solicitud character varying, acceso_id integer, fecha_inicio date, fecha_fin date, estado_vigencia character varying, bloqueado boolean)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.obtener_historial_persona(dpi_persona character varying) OWNER TO vpn_user;

--
-- Name: FUNCTION obtener_historial_persona(dpi_persona character varying); Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON FUNCTION public.obtener_historial_persona(dpi_persona character varying) IS 'Obtiene todo el historial de solicitudes y accesos de una persona';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: accesos_vpn; Type: TABLE; Schema: public; Owner: vpn_user
--

CREATE TABLE public.accesos_vpn (
    id integer NOT NULL,
    solicitud_id integer NOT NULL,
    fecha_inicio date NOT NULL,
    fecha_fin date NOT NULL,
    dias_gracia integer DEFAULT 0,
    fecha_fin_con_gracia date,
    estado_vigencia character varying(20) NOT NULL,
    usuario_creacion_id integer NOT NULL,
    fecha_creacion timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT accesos_vpn_estado_vigencia_check CHECK (((estado_vigencia)::text = ANY ((ARRAY['ACTIVO'::character varying, 'POR_VENCER'::character varying, 'VENCIDO'::character varying])::text[]))),
    CONSTRAINT vigencia_12_meses CHECK ((fecha_fin = (fecha_inicio + '1 year'::interval)))
);


ALTER TABLE public.accesos_vpn OWNER TO vpn_user;

--
-- Name: TABLE accesos_vpn; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON TABLE public.accesos_vpn IS 'Control real de vigencia - separado de la solicitud';


--
-- Name: COLUMN accesos_vpn.dias_gracia; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.accesos_vpn.dias_gracia IS 'DÃ­as adicionales otorgados administrativamente';


--
-- Name: COLUMN accesos_vpn.estado_vigencia; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.accesos_vpn.estado_vigencia IS 'ACTIVO: vigente, POR_VENCER: 30 dÃ­as antes, VENCIDO: despuÃ©s de fecha_fin';


--
-- Name: accesos_vpn_id_seq; Type: SEQUENCE; Schema: public; Owner: vpn_user
--

CREATE SEQUENCE public.accesos_vpn_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.accesos_vpn_id_seq OWNER TO vpn_user;

--
-- Name: accesos_vpn_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vpn_user
--

ALTER SEQUENCE public.accesos_vpn_id_seq OWNED BY public.accesos_vpn.id;


--
-- Name: alertas_sistema; Type: TABLE; Schema: public; Owner: vpn_user
--

CREATE TABLE public.alertas_sistema (
    id integer NOT NULL,
    tipo character varying(30) NOT NULL,
    acceso_vpn_id integer,
    mensaje text NOT NULL,
    fecha_generacion date NOT NULL,
    leida boolean DEFAULT false NOT NULL,
    fecha_lectura timestamp without time zone,
    CONSTRAINT alertas_sistema_tipo_check CHECK (((tipo)::text = ANY ((ARRAY['VENCIMIENTO'::character varying, 'GRACIA'::character varying, 'BLOQUEO_PENDIENTE'::character varying])::text[])))
);


ALTER TABLE public.alertas_sistema OWNER TO vpn_user;

--
-- Name: TABLE alertas_sistema; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON TABLE public.alertas_sistema IS 'Alertas operativas internas - dashboard diario';


--
-- Name: alertas_sistema_id_seq; Type: SEQUENCE; Schema: public; Owner: vpn_user
--

CREATE SEQUENCE public.alertas_sistema_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.alertas_sistema_id_seq OWNER TO vpn_user;

--
-- Name: alertas_sistema_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vpn_user
--

ALTER SEQUENCE public.alertas_sistema_id_seq OWNED BY public.alertas_sistema.id;


--
-- Name: archivos_adjuntos; Type: TABLE; Schema: public; Owner: vpn_user
--

CREATE TABLE public.archivos_adjuntos (
    id integer NOT NULL,
    carta_id integer NOT NULL,
    nombre_archivo character varying(255) NOT NULL,
    ruta_archivo text NOT NULL,
    tipo_mime character varying(100),
    hash_integridad character varying(64),
    tamano_bytes bigint,
    fecha_subida timestamp without time zone DEFAULT now() NOT NULL,
    usuario_subida_id integer NOT NULL
);


ALTER TABLE public.archivos_adjuntos OWNER TO vpn_user;

--
-- Name: TABLE archivos_adjuntos; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON TABLE public.archivos_adjuntos IS 'Almacenamiento de archivos firmados - NUNCA en BD';


--
-- Name: COLUMN archivos_adjuntos.ruta_archivo; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.archivos_adjuntos.ruta_archivo IS 'Path relativo en filesystem interno';


--
-- Name: COLUMN archivos_adjuntos.hash_integridad; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.archivos_adjuntos.hash_integridad IS 'SHA-256 para verificar integridad';


--
-- Name: archivos_adjuntos_id_seq; Type: SEQUENCE; Schema: public; Owner: vpn_user
--

CREATE SEQUENCE public.archivos_adjuntos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.archivos_adjuntos_id_seq OWNER TO vpn_user;

--
-- Name: archivos_adjuntos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vpn_user
--

ALTER SEQUENCE public.archivos_adjuntos_id_seq OWNED BY public.archivos_adjuntos.id;


--
-- Name: auditoria_eventos; Type: TABLE; Schema: public; Owner: vpn_user
--

CREATE TABLE public.auditoria_eventos (
    id integer NOT NULL,
    usuario_id integer,
    accion character varying(50) NOT NULL,
    entidad character varying(30) NOT NULL,
    entidad_id integer,
    detalle_json jsonb,
    ip_origen character varying(50),
    fecha timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.auditoria_eventos OWNER TO vpn_user;

--
-- Name: COLUMN auditoria_eventos.accion; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.auditoria_eventos.accion IS 'Ejemplos: CREAR, EDITAR, BLOQUEAR, DESBLOQUEAR, LOGIN, IMPORTAR';


--
-- Name: COLUMN auditoria_eventos.detalle_json; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.auditoria_eventos.detalle_json IS 'Snapshot completo del cambio en formato JSON';


--
-- Name: auditoria_eventos_id_seq; Type: SEQUENCE; Schema: public; Owner: vpn_user
--

CREATE SEQUENCE public.auditoria_eventos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.auditoria_eventos_id_seq OWNER TO vpn_user;

--
-- Name: auditoria_eventos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vpn_user
--

ALTER SEQUENCE public.auditoria_eventos_id_seq OWNED BY public.auditoria_eventos.id;


--
-- Name: bloqueos_vpn; Type: TABLE; Schema: public; Owner: vpn_user
--

CREATE TABLE public.bloqueos_vpn (
    id integer NOT NULL,
    acceso_vpn_id integer NOT NULL,
    estado character varying(20) NOT NULL,
    motivo text NOT NULL,
    usuario_id integer NOT NULL,
    fecha_cambio timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT bloqueos_vpn_estado_check CHECK (((estado)::text = ANY ((ARRAY['BLOQUEADO'::character varying, 'DESBLOQUEADO'::character varying])::text[])))
);


ALTER TABLE public.bloqueos_vpn OWNER TO vpn_user;

--
-- Name: TABLE bloqueos_vpn; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON TABLE public.bloqueos_vpn IS 'HistÃ³rico de bloqueos/desbloqueos - crÃ­tico para auditorÃ­a';


--
-- Name: COLUMN bloqueos_vpn.motivo; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.bloqueos_vpn.motivo IS 'OBLIGATORIO: justificaciÃ³n administrativa del cambio';


--
-- Name: bloqueos_vpn_id_seq; Type: SEQUENCE; Schema: public; Owner: vpn_user
--

CREATE SEQUENCE public.bloqueos_vpn_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.bloqueos_vpn_id_seq OWNER TO vpn_user;

--
-- Name: bloqueos_vpn_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vpn_user
--

ALTER SEQUENCE public.bloqueos_vpn_id_seq OWNED BY public.bloqueos_vpn.id;


--
-- Name: cartas_responsabilidad; Type: TABLE; Schema: public; Owner: vpn_user
--

CREATE TABLE public.cartas_responsabilidad (
    id integer NOT NULL,
    solicitud_id integer NOT NULL,
    tipo character varying(30) NOT NULL,
    fecha_generacion date NOT NULL,
    generada_por_usuario_id integer NOT NULL,
    CONSTRAINT cartas_responsabilidad_tipo_check CHECK (((tipo)::text = ANY ((ARRAY['RESPONSABILIDAD'::character varying, 'PRORROGA'::character varying, 'OTRO'::character varying])::text[])))
);


ALTER TABLE public.cartas_responsabilidad OWNER TO vpn_user;

--
-- Name: TABLE cartas_responsabilidad; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON TABLE public.cartas_responsabilidad IS 'Metadatos de documentos legales';


--
-- Name: COLUMN cartas_responsabilidad.tipo; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.cartas_responsabilidad.tipo IS 'RESPONSABILIDAD: carta inicial, PRORROGA: extensiÃ³n';


--
-- Name: cartas_responsabilidad_id_seq; Type: SEQUENCE; Schema: public; Owner: vpn_user
--

CREATE SEQUENCE public.cartas_responsabilidad_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cartas_responsabilidad_id_seq OWNER TO vpn_user;

--
-- Name: cartas_responsabilidad_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vpn_user
--

ALTER SEQUENCE public.cartas_responsabilidad_id_seq OWNED BY public.cartas_responsabilidad.id;


--
-- Name: catalogos; Type: TABLE; Schema: public; Owner: vpn_user
--

CREATE TABLE public.catalogos (
    id integer NOT NULL,
    tipo character varying(50) NOT NULL,
    codigo character varying(50) NOT NULL,
    descripcion character varying(200) NOT NULL,
    activo boolean DEFAULT true NOT NULL
);


ALTER TABLE public.catalogos OWNER TO vpn_user;

--
-- Name: TABLE catalogos; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON TABLE public.catalogos IS 'Valores normalizados para listas desplegables';


--
-- Name: catalogos_id_seq; Type: SEQUENCE; Schema: public; Owner: vpn_user
--

CREATE SEQUENCE public.catalogos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.catalogos_id_seq OWNER TO vpn_user;

--
-- Name: catalogos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vpn_user
--

ALTER SEQUENCE public.catalogos_id_seq OWNED BY public.catalogos.id;


--
-- Name: comentarios_admin; Type: TABLE; Schema: public; Owner: vpn_user
--

CREATE TABLE public.comentarios_admin (
    id integer NOT NULL,
    entidad character varying(30) NOT NULL,
    entidad_id integer NOT NULL,
    comentario text NOT NULL,
    usuario_id integer NOT NULL,
    fecha timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT comentarios_admin_entidad_check CHECK (((entidad)::text = ANY ((ARRAY['PERSONA'::character varying, 'SOLICITUD'::character varying, 'ACCESO'::character varying, 'BLOQUEO'::character varying])::text[])))
);


ALTER TABLE public.comentarios_admin OWNER TO vpn_user;

--
-- Name: TABLE comentarios_admin; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON TABLE public.comentarios_admin IS 'BitÃ¡cora operativa humana - contexto institucional';


--
-- Name: comentarios_admin_id_seq; Type: SEQUENCE; Schema: public; Owner: vpn_user
--

CREATE SEQUENCE public.comentarios_admin_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.comentarios_admin_id_seq OWNER TO vpn_user;

--
-- Name: comentarios_admin_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vpn_user
--

ALTER SEQUENCE public.comentarios_admin_id_seq OWNED BY public.comentarios_admin.id;


--
-- Name: configuracion_sistema; Type: TABLE; Schema: public; Owner: vpn_user
--

CREATE TABLE public.configuracion_sistema (
    id integer NOT NULL,
    clave character varying(100) NOT NULL,
    valor text NOT NULL,
    descripcion text,
    tipo_dato character varying(20),
    fecha_modificacion timestamp without time zone DEFAULT now() NOT NULL,
    modificado_por integer,
    CONSTRAINT configuracion_sistema_tipo_dato_check CHECK (((tipo_dato)::text = ANY ((ARRAY['STRING'::character varying, 'INTEGER'::character varying, 'BOOLEAN'::character varying, 'JSON'::character varying])::text[])))
);


ALTER TABLE public.configuracion_sistema OWNER TO vpn_user;

--
-- Name: TABLE configuracion_sistema; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON TABLE public.configuracion_sistema IS 'Configuraciones operativas del sistema';


--
-- Name: configuracion_sistema_id_seq; Type: SEQUENCE; Schema: public; Owner: vpn_user
--

CREATE SEQUENCE public.configuracion_sistema_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.configuracion_sistema_id_seq OWNER TO vpn_user;

--
-- Name: configuracion_sistema_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vpn_user
--

ALTER SEQUENCE public.configuracion_sistema_id_seq OWNED BY public.configuracion_sistema.id;


--
-- Name: importaciones_excel; Type: TABLE; Schema: public; Owner: vpn_user
--

CREATE TABLE public.importaciones_excel (
    id integer NOT NULL,
    archivo_origen character varying(255),
    fecha_importacion timestamp without time zone DEFAULT now() NOT NULL,
    usuario_id integer NOT NULL,
    registros_procesados integer DEFAULT 0,
    registros_exitosos integer DEFAULT 0,
    registros_fallidos integer DEFAULT 0,
    resultado text,
    log_errores text
);


ALTER TABLE public.importaciones_excel OWNER TO vpn_user;

--
-- Name: TABLE importaciones_excel; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON TABLE public.importaciones_excel IS 'Trazabilidad de migraciÃ³n desde Excel';


--
-- Name: importaciones_excel_id_seq; Type: SEQUENCE; Schema: public; Owner: vpn_user
--

CREATE SEQUENCE public.importaciones_excel_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.importaciones_excel_id_seq OWNER TO vpn_user;

--
-- Name: importaciones_excel_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vpn_user
--

ALTER SEQUENCE public.importaciones_excel_id_seq OWNED BY public.importaciones_excel.id;


--
-- Name: personas; Type: TABLE; Schema: public; Owner: vpn_user
--

CREATE TABLE public.personas (
    id integer NOT NULL,
    dpi character varying(20) NOT NULL,
    nombres character varying(150) NOT NULL,
    apellidos character varying(150) NOT NULL,
    institucion character varying(200),
    cargo character varying(150),
    telefono character varying(50),
    email character varying(150),
    observaciones text,
    activo boolean DEFAULT true NOT NULL,
    fecha_creacion timestamp without time zone DEFAULT now() NOT NULL,
    nip character varying(20)
);


ALTER TABLE public.personas OWNER TO vpn_user;

--
-- Name: TABLE personas; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON TABLE public.personas IS 'Entidad real que solicita acceso VPN (puede tener mÃºltiples solicitudes)';


--
-- Name: COLUMN personas.dpi; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.personas.dpi IS 'Documento Personal de IdentificaciÃ³n - Ãºnico e inmutable';


--
-- Name: COLUMN personas.nip; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.personas.nip IS 'NÃºmero de IdentificaciÃ³n Policial';


--
-- Name: personas_id_seq; Type: SEQUENCE; Schema: public; Owner: vpn_user
--

CREATE SEQUENCE public.personas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.personas_id_seq OWNER TO vpn_user;

--
-- Name: personas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vpn_user
--

ALTER SEQUENCE public.personas_id_seq OWNED BY public.personas.id;


--
-- Name: sesiones_login; Type: TABLE; Schema: public; Owner: vpn_user
--

CREATE TABLE public.sesiones_login (
    id integer NOT NULL,
    usuario_id integer NOT NULL,
    token_hash character varying(64),
    ip_origen character varying(50),
    user_agent text,
    fecha_inicio timestamp without time zone DEFAULT now() NOT NULL,
    fecha_expiracion timestamp without time zone,
    activa boolean DEFAULT true NOT NULL
);


ALTER TABLE public.sesiones_login OWNER TO vpn_user;

--
-- Name: TABLE sesiones_login; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON TABLE public.sesiones_login IS 'Control de sesiones activas y auditorÃ­a de accesos';


--
-- Name: sesiones_login_id_seq; Type: SEQUENCE; Schema: public; Owner: vpn_user
--

CREATE SEQUENCE public.sesiones_login_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.sesiones_login_id_seq OWNER TO vpn_user;

--
-- Name: sesiones_login_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vpn_user
--

ALTER SEQUENCE public.sesiones_login_id_seq OWNED BY public.sesiones_login.id;


--
-- Name: solicitudes_vpn; Type: TABLE; Schema: public; Owner: vpn_user
--

CREATE TABLE public.solicitudes_vpn (
    id integer NOT NULL,
    persona_id integer NOT NULL,
    fecha_solicitud date NOT NULL,
    tipo_solicitud character varying(20) NOT NULL,
    justificacion text NOT NULL,
    estado character varying(20) NOT NULL,
    usuario_registro_id integer NOT NULL,
    comentarios_admin text,
    fecha_registro timestamp without time zone DEFAULT now() NOT NULL,
    numero_oficio character varying(50),
    numero_providencia character varying(50),
    fecha_recepcion date,
    CONSTRAINT solicitudes_vpn_tipo_solicitud_check CHECK (((tipo_solicitud)::text = ANY ((ARRAY['NUEVA'::character varying, 'RENOVACION'::character varying, 'CREACION'::character varying, 'ACTUALIZACION'::character varying])::text[])))
);


ALTER TABLE public.solicitudes_vpn OWNER TO vpn_user;

--
-- Name: TABLE solicitudes_vpn; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON TABLE public.solicitudes_vpn IS 'Expediente administrativo - NUNCA se sobreescribe';


--
-- Name: COLUMN solicitudes_vpn.tipo_solicitud; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.solicitudes_vpn.tipo_solicitud IS 'NUEVA, RENOVACION, CREACION, ACTUALIZACION';


--
-- Name: COLUMN solicitudes_vpn.estado; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.solicitudes_vpn.estado IS 'PENDIENTE, APROBADA, RECHAZADA, DENEGADA, CANCELADA';


--
-- Name: COLUMN solicitudes_vpn.numero_oficio; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.solicitudes_vpn.numero_oficio IS 'NÃºmero de oficio recibido';


--
-- Name: COLUMN solicitudes_vpn.numero_providencia; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.solicitudes_vpn.numero_providencia IS 'NÃºmero de providencia';


--
-- Name: COLUMN solicitudes_vpn.fecha_recepcion; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.solicitudes_vpn.fecha_recepcion IS 'Fecha en que se recibiÃ³ la solicitud fÃ­sica';


--
-- Name: solicitudes_vpn_id_seq; Type: SEQUENCE; Schema: public; Owner: vpn_user
--

CREATE SEQUENCE public.solicitudes_vpn_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.solicitudes_vpn_id_seq OWNER TO vpn_user;

--
-- Name: solicitudes_vpn_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vpn_user
--

ALTER SEQUENCE public.solicitudes_vpn_id_seq OWNED BY public.solicitudes_vpn.id;


--
-- Name: usuarios_sistema; Type: TABLE; Schema: public; Owner: vpn_user
--

CREATE TABLE public.usuarios_sistema (
    id integer NOT NULL,
    username character varying(50) NOT NULL,
    password_hash text NOT NULL,
    nombre_completo character varying(150) NOT NULL,
    email character varying(150),
    rol character varying(20) NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    fecha_creacion timestamp without time zone DEFAULT now() NOT NULL,
    fecha_ultimo_login timestamp without time zone,
    CONSTRAINT username_lowercase CHECK (((username)::text = lower((username)::text))),
    CONSTRAINT usuarios_sistema_rol_check CHECK (((rol)::text = ANY ((ARRAY['SUPERADMIN'::character varying, 'ADMIN'::character varying])::text[])))
);


ALTER TABLE public.usuarios_sistema OWNER TO vpn_user;

--
-- Name: TABLE usuarios_sistema; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON TABLE public.usuarios_sistema IS 'Usuarios internos que operan el sistema';


--
-- Name: COLUMN usuarios_sistema.password_hash; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.usuarios_sistema.password_hash IS 'Hash bcrypt de la contraseÃ±a';


--
-- Name: COLUMN usuarios_sistema.rol; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.usuarios_sistema.rol IS 'SUPERADMIN: configuraciÃ³n y auditorÃ­a, ADMIN: operaciÃ³n';


--
-- Name: usuarios_sistema_id_seq; Type: SEQUENCE; Schema: public; Owner: vpn_user
--

CREATE SEQUENCE public.usuarios_sistema_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.usuarios_sistema_id_seq OWNER TO vpn_user;

--
-- Name: usuarios_sistema_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vpn_user
--

ALTER SEQUENCE public.usuarios_sistema_id_seq OWNED BY public.usuarios_sistema.id;


--
-- Name: vista_accesos_actuales; Type: VIEW; Schema: public; Owner: vpn_user
--

CREATE VIEW public.vista_accesos_actuales AS
 SELECT p.id AS persona_id,
    p.dpi,
    p.nombres,
    p.apellidos,
    p.institucion,
    p.cargo,
    s.id AS solicitud_id,
    s.fecha_solicitud,
    s.tipo_solicitud,
    av.id AS acceso_id,
    av.fecha_inicio,
    av.fecha_fin,
    av.dias_gracia,
    av.fecha_fin_con_gracia,
    av.estado_vigencia,
        CASE
            WHEN (av.dias_gracia > 0) THEN (av.fecha_fin_con_gracia - CURRENT_DATE)
            ELSE (av.fecha_fin - CURRENT_DATE)
        END AS dias_restantes,
    ( SELECT bv.estado
           FROM public.bloqueos_vpn bv
          WHERE (bv.acceso_vpn_id = av.id)
          ORDER BY bv.fecha_cambio DESC
         LIMIT 1) AS estado_bloqueo,
    u.nombre_completo AS usuario_registro
   FROM (((public.personas p
     JOIN public.solicitudes_vpn s ON ((s.persona_id = p.id)))
     JOIN public.accesos_vpn av ON ((av.solicitud_id = s.id)))
     JOIN public.usuarios_sistema u ON ((u.id = av.usuario_creacion_id)))
  WHERE ((s.estado)::text = 'APROBADA'::text)
  ORDER BY av.fecha_fin;


ALTER VIEW public.vista_accesos_actuales OWNER TO vpn_user;

--
-- Name: VIEW vista_accesos_actuales; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON VIEW public.vista_accesos_actuales IS 'Vista consolidada de todos los accesos con informaciÃ³n completa';


--
-- Name: vista_dashboard_vencimientos; Type: VIEW; Schema: public; Owner: vpn_user
--

CREATE VIEW public.vista_dashboard_vencimientos AS
 SELECT count(*) FILTER (WHERE (((estado_vigencia)::text = 'ACTIVO'::text) AND (dias_restantes > 30))) AS activos,
    count(*) FILTER (WHERE ((estado_vigencia)::text = 'POR_VENCER'::text)) AS por_vencer,
    count(*) FILTER (WHERE ((estado_vigencia)::text = 'VENCIDO'::text)) AS vencidos,
    count(*) FILTER (WHERE ((estado_bloqueo)::text = 'BLOQUEADO'::text)) AS bloqueados,
    count(*) FILTER (WHERE ((dias_restantes <= 7) AND (dias_restantes > 0))) AS vencen_esta_semana,
    count(*) FILTER (WHERE (dias_restantes = 0)) AS vencen_hoy
   FROM public.vista_accesos_actuales;


ALTER VIEW public.vista_dashboard_vencimientos OWNER TO vpn_user;

--
-- Name: VIEW vista_dashboard_vencimientos; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON VIEW public.vista_dashboard_vencimientos IS 'Resumen ejecutivo para dashboard principal';


--
-- Name: accesos_vpn id; Type: DEFAULT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.accesos_vpn ALTER COLUMN id SET DEFAULT nextval('public.accesos_vpn_id_seq'::regclass);


--
-- Name: alertas_sistema id; Type: DEFAULT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.alertas_sistema ALTER COLUMN id SET DEFAULT nextval('public.alertas_sistema_id_seq'::regclass);


--
-- Name: archivos_adjuntos id; Type: DEFAULT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.archivos_adjuntos ALTER COLUMN id SET DEFAULT nextval('public.archivos_adjuntos_id_seq'::regclass);


--
-- Name: auditoria_eventos id; Type: DEFAULT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.auditoria_eventos ALTER COLUMN id SET DEFAULT nextval('public.auditoria_eventos_id_seq'::regclass);


--
-- Name: bloqueos_vpn id; Type: DEFAULT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.bloqueos_vpn ALTER COLUMN id SET DEFAULT nextval('public.bloqueos_vpn_id_seq'::regclass);


--
-- Name: cartas_responsabilidad id; Type: DEFAULT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.cartas_responsabilidad ALTER COLUMN id SET DEFAULT nextval('public.cartas_responsabilidad_id_seq'::regclass);


--
-- Name: catalogos id; Type: DEFAULT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.catalogos ALTER COLUMN id SET DEFAULT nextval('public.catalogos_id_seq'::regclass);


--
-- Name: comentarios_admin id; Type: DEFAULT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.comentarios_admin ALTER COLUMN id SET DEFAULT nextval('public.comentarios_admin_id_seq'::regclass);


--
-- Name: configuracion_sistema id; Type: DEFAULT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.configuracion_sistema ALTER COLUMN id SET DEFAULT nextval('public.configuracion_sistema_id_seq'::regclass);


--
-- Name: importaciones_excel id; Type: DEFAULT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.importaciones_excel ALTER COLUMN id SET DEFAULT nextval('public.importaciones_excel_id_seq'::regclass);


--
-- Name: personas id; Type: DEFAULT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.personas ALTER COLUMN id SET DEFAULT nextval('public.personas_id_seq'::regclass);


--
-- Name: sesiones_login id; Type: DEFAULT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.sesiones_login ALTER COLUMN id SET DEFAULT nextval('public.sesiones_login_id_seq'::regclass);


--
-- Name: solicitudes_vpn id; Type: DEFAULT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.solicitudes_vpn ALTER COLUMN id SET DEFAULT nextval('public.solicitudes_vpn_id_seq'::regclass);


--
-- Name: usuarios_sistema id; Type: DEFAULT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.usuarios_sistema ALTER COLUMN id SET DEFAULT nextval('public.usuarios_sistema_id_seq'::regclass);


--
-- Data for Name: accesos_vpn; Type: TABLE DATA; Schema: public; Owner: vpn_user
--

COPY public.accesos_vpn (id, solicitud_id, fecha_inicio, fecha_fin, dias_gracia, fecha_fin_con_gracia, estado_vigencia, usuario_creacion_id, fecha_creacion) FROM stdin;
1	4	2025-12-31	2026-12-31	0	2026-12-31	ACTIVO	1	2025-12-31 19:32:37.743618
2	6	2025-12-31	2026-12-31	0	2026-12-31	ACTIVO	1	2025-12-31 19:50:28.402322
3	7	2025-12-31	2026-12-31	0	2026-12-31	ACTIVO	1	2025-12-31 19:54:14.209846
4	8	2025-12-31	2026-12-31	0	2026-12-31	ACTIVO	1	2025-12-31 19:55:50.798223
5	5	2025-12-31	2026-12-31	0	2026-12-31	ACTIVO	1	2025-12-31 20:51:08.041792
6	9	2025-12-31	2026-12-31	0	2026-12-31	ACTIVO	1	2025-12-31 20:55:05.950607
7	10	2026-01-01	2027-01-01	0	2027-01-01	ACTIVO	1	2026-01-01 11:27:55.736537
8	11	2026-01-01	2027-01-01	0	2027-01-01	ACTIVO	1	2026-01-01 12:15:30.072993
9	18	2026-01-01	2027-01-01	0	2027-01-01	ACTIVO	1	2026-01-01 20:11:48.427451
10	19	2026-01-02	2027-01-02	0	2027-01-02	ACTIVO	1	2026-01-02 09:42:53.338901
11	25	2026-01-02	2027-01-02	0	2027-01-02	ACTIVO	1	2026-01-02 10:12:35.196654
12	26	2026-01-02	2027-01-02	0	2027-01-02	ACTIVO	1	2026-01-02 10:27:33.410017
13	28	2026-01-02	2027-01-02	0	2027-01-02	ACTIVO	1	2026-01-02 18:03:53.820883
14	30	2026-01-02	2027-01-02	0	2027-01-02	ACTIVO	1	2026-01-02 18:04:45.975874
15	29	2026-01-02	2027-01-02	0	2027-01-02	ACTIVO	1	2026-01-02 19:08:43.172767
16	31	2026-01-02	2027-01-02	0	2027-01-02	ACTIVO	1	2026-01-02 19:10:27.376477
17	32	2026-01-02	2027-01-02	0	2027-01-02	ACTIVO	1	2026-01-02 19:22:28.209284
18	33	2026-01-02	2027-01-02	0	2027-01-02	ACTIVO	1	2026-01-02 20:13:51.942786
19	34	2026-01-02	2027-01-02	0	2027-01-02	ACTIVO	1	2026-01-02 20:32:16.675889
20	35	2026-01-02	2027-01-02	0	2027-01-02	ACTIVO	1	2026-01-02 20:33:28.945965
21	36	2026-01-02	2027-01-02	0	2027-01-02	ACTIVO	1	2026-01-02 20:34:29.305673
22	38	2026-01-03	2027-01-03	0	2027-01-03	ACTIVO	1	2026-01-03 10:15:05.320798
\.


--
-- Data for Name: alertas_sistema; Type: TABLE DATA; Schema: public; Owner: vpn_user
--

COPY public.alertas_sistema (id, tipo, acceso_vpn_id, mensaje, fecha_generacion, leida, fecha_lectura) FROM stdin;
\.


--
-- Data for Name: archivos_adjuntos; Type: TABLE DATA; Schema: public; Owner: vpn_user
--

COPY public.archivos_adjuntos (id, carta_id, nombre_archivo, ruta_archivo, tipo_mime, hash_integridad, tamano_bytes, fecha_subida, usuario_subida_id) FROM stdin;
\.


--
-- Data for Name: auditoria_eventos; Type: TABLE DATA; Schema: public; Owner: vpn_user
--

COPY public.auditoria_eventos (id, usuario_id, accion, entidad, entidad_id, detalle_json, ip_origen, fecha) FROM stdin;
1	1	SETUP_INICIAL	SISTEMA	\N	{"mensaje": "ConfiguraciÃ³n inicial del sistema completada", "version": "1.0.0"}	localhost	2025-12-29 12:08:57.851715
2	\N	LOGIN_FALLIDO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 09:19:53.747553
3	\N	LOGIN_FALLIDO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 09:20:00.440328
4	\N	LOGIN_FALLIDO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 09:20:40.169532
5	\N	LOGIN_FALLIDO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 09:22:10.024583
6	\N	LOGIN_FALLIDO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 09:22:27.706887
7	\N	LOGIN_FALLIDO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 09:29:12.424514
8	\N	LOGIN_FALLIDO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 09:29:16.651366
9	\N	LOGIN_FALLIDO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 10:09:57.974373
10	\N	LOGIN_FALLIDO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 10:10:05.789254
11	\N	LOGIN_FALLIDO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 10:10:42.71899
12	\N	LOGIN_FALLIDO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 10:10:57.675276
13	\N	LOGIN_FALLIDO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 11:12:15.422171
14	\N	LOGIN_FALLIDO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 11:12:16.85544
15	\N	LOGIN_FALLIDO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 11:12:22.892176
16	\N	LOGIN_FALLIDO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 11:54:49.950834
17	\N	LOGIN_FALLIDO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 11:56:59.20152
18	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 11:58:06.572429
19	\N	LOGIN_FALLIDO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 12:03:43.623483
20	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 12:07:20.63611
21	\N	LOGIN_FALLIDO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 12:16:10.778491
22	\N	LOGIN_FALLIDO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 12:16:17.662438
23	\N	LOGIN_FALLIDO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 12:17:45.629975
24	\N	LOGIN_FALLIDO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 12:18:13.595585
25	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 12:26:39.942246
26	1	CREAR	PERSONA	1	{"dpi": "1234567891000", "nombre_completo": "Primera Prueba Del Sistema"}	127.0.0.1	2025-12-30 12:31:48.869785
27	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 12:32:06.542767
28	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 12:41:58.180439
29	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 14:41:24.010027
30	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 15:44:14.735162
31	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 16:58:19.600593
32	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 17:36:49.431597
33	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 18:54:22.168837
34	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 20:00:48.70123
35	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-30 21:10:20.229988
36	1	CREAR	PERSONA	2	{"dpi": "1111122222333", "nombre_completo": "Segunda Prueba Del Sistema"}	127.0.0.1	2025-12-30 21:12:38.949192
37	1	CREAR	SOLICITUD	1	{"tipo": "NUEVA", "estado": "APROBADA", "persona_dpi": "1111122222333"}	127.0.0.1	2025-12-30 21:13:13.059934
38	1	CREAR	SOLICITUD	2	{"tipo": "RENOVACION", "estado": "APROBADA", "persona_dpi": "1111122222333"}	127.0.0.1	2025-12-30 21:16:01.703711
39	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-31 08:47:40.132675
40	1	CREAR	CARTA	1	{"tipo": "RESPONSABILIDAD", "solicitud_id": 1}	127.0.0.1	2025-12-31 09:07:55.506608
41	1	ACTUALIZAR	SOLICITUD	1	{"cambios": {"estado": {"nuevo": "NO_PRESENTADO", "anterior": "APROBADA"}, "motivo": "no se presento"}}	127.0.0.1	2025-12-31 09:08:18.530953
42	1	ACTUALIZAR	SOLICITUD	2	{"cambios": {"estado": {"nuevo": "NO_PRESENTADO", "anterior": "APROBADA"}, "motivo": null}}	127.0.0.1	2025-12-31 09:08:27.553035
43	1	ELIMINAR	SOLICITUD	2	{"motivo": "Eliminación solicitada por usuario"}	127.0.0.1	2025-12-31 09:11:52.927945
44	1	ACTUALIZAR	PERSONA	2	{"cambios": {"accion": "actualizar_datos"}}	127.0.0.1	2025-12-31 09:33:08.460489
45	1	CREAR	PERSONA	3	{"dpi": "1234567891234", "nombre_completo": "Aaaa Ooo"}	127.0.0.1	2025-12-31 09:43:21.099693
46	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-31 09:49:25.569138
47	1	ACTUALIZAR	SOLICITUD	1	{"cambios": {"estado": {"nuevo": "NO_PRESENTADO", "anterior": "CANCELADA"}, "motivo": ""}}	127.0.0.1	2025-12-31 09:58:09.065162
48	1	ACTUALIZAR	PERSONA	2	{"cambios": {"accion": "actualizar_datos"}}	127.0.0.1	2025-12-31 09:58:20.419572
49	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-31 11:15:31.301056
50	1	ACTUALIZAR	PERSONA	2	{"cambios": {"accion": "actualizar_datos"}}	127.0.0.1	2025-12-31 11:15:51.614054
51	1	ACTUALIZAR	SOLICITUD	1	{"cambios": {"estado": {"nuevo": "NO_PRESENTADO", "anterior": "CANCELADA"}, "motivo": ""}}	127.0.0.1	2025-12-31 11:17:44.819957
52	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-31 13:18:16.849622
53	1	ACTUALIZAR	PERSONA	1	{"cambios": {"accion": "actualizar_datos"}}	127.0.0.1	2025-12-31 13:19:07.632206
54	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-31 14:20:00.926033
55	1	ACTUALIZAR	SOLICITUD	1	{"cambios": {"accion": "reactivacion", "estado": {"nuevo": "APROBADA", "anterior": "CANCELADA"}}}	127.0.0.1	2025-12-31 14:20:09.873416
56	1	ACTUALIZAR	PERSONA	2	{"cambios": {"accion": "actualizar_datos"}}	127.0.0.1	2025-12-31 14:54:33.684342
57	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-31 15:34:17.175952
58	1	ACTUALIZAR	PERSONA	2	{"cambios": {"accion": "actualizar_datos"}}	127.0.0.1	2025-12-31 15:36:25.158833
59	1	ACTUALIZAR	PERSONA	2	{"cambios": {"accion": "actualizar_datos"}}	127.0.0.1	2025-12-31 15:38:51.039791
60	1	CREAR	SOLICITUD	3	{"tipo": "RENOVACION", "estado": "APROBADA", "persona_dpi": "1111122222333"}	127.0.0.1	2025-12-31 15:39:17.964022
61	1	CREAR	CARTA	2	{"tipo": "RESPONSABILIDAD", "solicitud_id": 3}	127.0.0.1	2025-12-31 15:39:25.561836
62	1	ACTUALIZAR	PERSONA	3	{"cambios": {"accion": "actualizar_datos"}}	127.0.0.1	2025-12-31 15:43:59.576362
63	1	CREAR	SOLICITUD	4	{"tipo": "NUEVA", "estado": "APROBADA", "persona_dpi": "1234567891234"}	127.0.0.1	2025-12-31 15:44:20.500088
64	1	ACTUALIZAR	SOLICITUD	4	{"cambios": {"estado": {"nuevo": "NO_PRESENTADO", "anterior": "APROBADA"}, "motivo": "No se presentó a firmar"}}	127.0.0.1	2025-12-31 15:44:43.988631
65	1	ACTUALIZAR	SOLICITUD	4	{"cambios": {"accion": "reactivacion", "estado": {"nuevo": "APROBADA", "anterior": "CANCELADA"}}}	127.0.0.1	2025-12-31 15:44:57.767731
66	1	ACTUALIZAR	SOLICITUD	4	{"cambios": {"estado": {"nuevo": "NO_PRESENTADO", "anterior": "APROBADA"}, "motivo": "No se presentó a firmar"}}	127.0.0.1	2025-12-31 15:45:01.108731
67	1	CREAR	PERSONA	4	{"dpi": "1234567891001", "nombre_completo": "Ddf Faf"}	127.0.0.1	2025-12-31 15:45:42.484811
68	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-31 18:52:13.885584
69	1	ACTUALIZAR	SOLICITUD	4	{"cambios": {"justificacion": "Solicitud de creacion de usuario vpn", "tipo_solicitud": "NUEVA"}}	127.0.0.1	2025-12-31 18:54:01.556379
70	1	CREAR	CARTA	3	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_3_1234567891234.pdf", "acceso_id": 1, "pdf_generado": true, "solicitud_id": 4}	127.0.0.1	2025-12-31 19:32:37.872217
71	1	CREAR	PERSONA	5	{"dpi": "1234567891230", "nombre_completo": "Gdgf Gfdfdg"}	127.0.0.1	2025-12-31 19:34:50.132495
72	1	CREAR	SOLICITUD	5	{"tipo": "NUEVA", "estado": "APROBADA", "persona_dpi": "1234567891230", "numero_oficio": "38-2025", "numero_providencia": "112-2025"}	127.0.0.1	2025-12-31 19:35:10.285574
73	1	CREAR	SOLICITUD	6	{"tipo": "RENOVACION", "estado": "APROBADA", "persona_dpi": "1234567891230", "numero_oficio": "72-2025", "numero_providencia": "S/N"}	127.0.0.1	2025-12-31 19:50:10.3897
74	1	CREAR	CARTA	4	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_4_1234567891230.pdf", "acceso_id": 2, "pdf_generado": true, "solicitud_id": 6}	127.0.0.1	2025-12-31 19:50:28.480677
75	1	BLOQUEAR	ACCESO	1	{"motivo": "traslado a comisaria"}	127.0.0.1	2025-12-31 19:51:02.521672
76	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-31 19:52:29.417601
77	1	CREAR	SOLICITUD	7	{"tipo": "RENOVACION", "estado": "APROBADA", "persona_dpi": "1234567891230", "numero_oficio": "38-2025", "numero_providencia": "S/N"}	127.0.0.1	2025-12-31 19:53:09.393226
78	1	CREAR	CARTA	5	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_5_1234567891230.pdf", "acceso_id": 3, "pdf_generado": true, "solicitud_id": 7}	127.0.0.1	2025-12-31 19:54:14.292046
79	1	CREAR	SOLICITUD	8	{"tipo": "NUEVA", "estado": "APROBADA", "persona_dpi": "1111122222333", "numero_oficio": "72-2025", "numero_providencia": "S/N"}	127.0.0.1	2025-12-31 19:55:25.458894
80	1	CREAR	CARTA	6	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_6_1111122222333.pdf", "acceso_id": 4, "pdf_generado": true, "solicitud_id": 8}	127.0.0.1	2025-12-31 19:55:50.841817
81	1	BLOQUEAR	ACCESO	4	{"motivo": "jdkldfjkjfdlkfdfd "}	127.0.0.1	2025-12-31 19:56:16.616694
82	1	DESBLOQUEAR	ACCESO	1	{"motivo": "Por equivocacion se bloqueo el usuario"}	127.0.0.1	2025-12-31 20:12:55.603181
83	1	CREAR	CARTA	7	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_7_1234567891230.pdf", "acceso_id": 5, "pdf_generado": true, "solicitud_id": 5}	127.0.0.1	2025-12-31 20:51:08.283133
84	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2025-12-31 20:53:44.857285
85	1	CREAR	SOLICITUD	9	{"tipo": "RENOVACION", "estado": "APROBADA", "persona_dpi": "1234567891234"}	127.0.0.1	2025-12-31 20:55:00.193438
86	1	CREAR	CARTA	8	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_8_1234567891234.pdf", "acceso_id": 6, "pdf_generado": true, "solicitud_id": 9}	127.0.0.1	2025-12-31 20:55:06.077915
87	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-01 10:02:02.325795
88	1	CREAR	PERSONA	6	{"dpi": "9999888877776", "nombre_completo": "Esteban Osorio Lopez Guzman"}	127.0.0.1	2026-01-01 10:54:19.968186
89	1	CREAR	SOLICITUD	10	{"tipo": "NUEVA", "estado": "APROBADA", "persona_dpi": "9999888877776", "persona_nip": "22345-P"}	127.0.0.1	2026-01-01 10:54:39.105505
90	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-01 11:05:20.012463
91	1	CREAR	CARTA	9	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_9_9999888877776.pdf", "acceso_id": 7, "pdf_generado": true, "solicitud_id": 10}	127.0.0.1	2026-01-01 11:27:56.360963
92	1	BLOQUEAR	ACCESO	3	{"motivo": "realizando prueba"}	127.0.0.1	2026-01-01 11:30:52.426182
93	1	BLOQUEAR	ACCESO	7	{"motivo": "tercera prueba "}	127.0.0.1	2026-01-01 11:35:45.187544
94	1	DESBLOQUEAR	ACCESO	7	{"motivo": "era una prueba"}	127.0.0.1	2026-01-01 11:49:04.726857
95	1	CREAR	PERSONA	7	{"dpi": "9876543212345", "nombre_completo": "Abner Joel Bb Dd"}	127.0.0.1	2026-01-01 11:59:58.890061
96	1	CREAR	SOLICITUD	11	{"tipo": "NUEVA", "estado": "APROBADA", "persona_dpi": "9876543212345", "persona_nip": "11111-P"}	127.0.0.1	2026-01-01 12:00:20.952866
97	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-01 12:05:39.740792
98	1	CREAR	CARTA	10	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_10_9876543212345.pdf", "acceso_id": 8, "pdf_generado": true, "solicitud_id": 11}	127.0.0.1	2026-01-01 12:15:30.281008
99	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-01 13:13:56.800139
100	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-01 14:32:56.319266
101	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-01 15:36:46.344292
102	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-01 15:58:07.908654
103	1	CREAR	PERSONA	8	{"dpi": "4567891237894", "nombre_completo": "Hola S Dd Ll"}	127.0.0.1	2026-01-01 16:03:24.301622
104	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-01 17:00:36.644519
105	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-01 18:02:20.087695
106	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-01 19:26:44.05462
107	1	CREAR	SOLICITUD	18	{"tipo": "RENOVACION", "estado": "APROBADA", "persona_dpi": "9999888877776", "persona_nip": "22345-P"}	127.0.0.1	2026-01-01 20:11:20.87618
108	1	CREAR	CARTA	11	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_11_9999888877776.pdf", "acceso_id": 9, "pdf_generado": true, "solicitud_id": 18}	127.0.0.1	2026-01-01 20:11:48.902987
109	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-02 09:28:19.374004
110	1	CREAR	PERSONA	9	{"dpi": "9638527412589", "nombre_completo": "Probando Sistema Prueba Cartas"}	127.0.0.1	2026-01-02 09:41:19.648764
111	1	CREAR	SOLICITUD	19	{"tipo": "NUEVA", "estado": "APROBADA", "persona_dpi": "9638527412589", "persona_nip": "78878-P"}	127.0.0.1	2026-01-02 09:42:06.722848
112	1	CREAR	CARTA	12	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_12_9638527412589.pdf", "acceso_id": 10, "pdf_generado": true, "solicitud_id": 19}	127.0.0.1	2026-01-02 09:42:53.614166
113	1	CREAR	SOLICITUD	25	{"tipo": "RENOVACION", "estado": "APROBADA", "persona_dpi": "4567891237894", "persona_nip": "47586-P"}	127.0.0.1	2026-01-02 10:12:24.32901
114	1	CREAR	CARTA	13	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_13_4567891237894.pdf", "acceso_id": 11, "pdf_generado": true, "solicitud_id": 25}	127.0.0.1	2026-01-02 10:12:35.370067
115	1	CREAR	SOLICITUD	26	{"tipo": "RENOVACION", "estado": "APROBADA", "persona_dpi": "9638527412589", "persona_nip": "78878-P"}	127.0.0.1	2026-01-02 10:27:21.790112
116	1	CREAR	CARTA	14	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_14_9638527412589.pdf", "acceso_id": 12, "pdf_generado": true, "solicitud_id": 26}	127.0.0.1	2026-01-02 10:27:33.606295
117	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-02 10:28:26.070109
118	1	BLOQUEAR	ACCESO	2	{"motivo": "causo alta"}	127.0.0.1	2026-01-02 10:29:44.783189
119	1	DESBLOQUEAR	ACCESO	2	{"motivo": "habilitarlo"}	127.0.0.1	2026-01-02 10:30:00.888377
120	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-02 10:30:21.309343
121	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-02 11:32:53.566017
122	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-02 12:59:03.51928
123	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-02 14:09:15.080216
124	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-02 15:53:09.345325
125	1	CREAR	SOLICITUD	27	{"tipo": "RENOVACION", "estado": "APROBADA", "persona_dpi": "4567891237894", "persona_nip": "47586-P"}	127.0.0.1	2026-01-02 16:03:21.353545
126	1	CREAR	SOLICITUD_EDICION	27	{"accion": "EDITAR", "campos_modificados": ["numero_oficio", "numero_providencia", "fecha_recepcion", "tipo_solicitud", "justificacion"]}	127.0.0.1	2026-01-02 16:41:48.805884
127	1	CREAR	SOLICITUD_EDICION	27	{"accion": "EDITAR", "campos_modificados": ["numero_oficio", "numero_providencia", "fecha_recepcion", "tipo_solicitud", "justificacion"]}	127.0.0.1	2026-01-02 16:47:13.457742
128	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-02 17:03:38.045552
129	1	CREAR	SOLICITUD	28	{"tipo": "NUEVA", "estado": "APROBADA", "persona_dpi": "4567891237894", "persona_nip": "47586-P"}	127.0.0.1	2026-01-02 17:06:13.763263
130	1	CREAR	SOLICITUD	29	{"tipo": "NUEVA", "estado": "APROBADA", "oficio": "2-2025", "persona_dpi": "4567891237894", "persona_nip": "47586-P", "providencia": "S/N"}	127.0.0.1	2026-01-02 17:16:20.48256
131	1	CREAR	SOLICITUD_EDICION	28	{"accion": "EDITAR", "campos_modificados": ["numero_oficio", "numero_providencia", "fecha_recepcion", "tipo_solicitud", "justificacion"]}	127.0.0.1	2026-01-02 17:17:34.526491
132	1	CREAR	SOLICITUD	30	{"tipo": "NUEVA", "estado": "APROBADA", "oficio": null, "persona_dpi": "9999888877776", "persona_nip": "22345-P", "providencia": null}	127.0.0.1	2026-01-02 17:46:33.133225
133	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-02 18:03:44.57836
134	1	CREAR	CARTA	15	{"pdf_path": "C:\\\\Users\\\\HP\\\\Desktop\\\\VPN-PROJECT\\\\vpn-gestion-sistema\\\\cartas\\\\CARTA_15_4567891237894.pdf", "acceso_id": 13, "pdf_generado": true, "solicitud_id": 28}	127.0.0.1	2026-01-02 18:03:54.117379
135	1	CREAR	CARTA	16	{"pdf_path": "C:\\\\Users\\\\HP\\\\Desktop\\\\VPN-PROJECT\\\\vpn-gestion-sistema\\\\cartas\\\\CARTA_16_9999888877776.pdf", "acceso_id": 14, "pdf_generado": true, "solicitud_id": 30}	127.0.0.1	2026-01-02 18:04:46.03532
136	1	CREAR	SOLICITUD_EDICION	29	{"accion": "EDITAR", "campos_modificados": ["numero_oficio", "numero_providencia", "fecha_recepcion", "tipo_solicitud", "justificacion"]}	127.0.0.1	2026-01-02 18:09:46.979979
137	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-02 19:07:49.245944
138	1	CREAR	CARTA	17	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_17_4567891237894.pdf", "acceso_id": 15, "pdf_generado": true, "solicitud_id": 29}	127.0.0.1	2026-01-02 19:08:43.320608
139	1	CREAR	SOLICITUD	31	{"tipo": "RENOVACION", "estado": "APROBADA", "persona_dpi": "9638527412589", "persona_nip": "78878-P"}	127.0.0.1	2026-01-02 19:10:19.192627
140	1	CREAR	CARTA	18	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_18_9638527412589.pdf", "acceso_id": 16, "pdf_generado": true, "solicitud_id": 31}	127.0.0.1	2026-01-02 19:10:27.466344
141	1	CREAR	SOLICITUD	32	{"tipo": "NUEVA", "estado": "APROBADA", "persona_dpi": "4567891237894", "persona_nip": "47586-P"}	127.0.0.1	2026-01-02 19:22:06.971581
142	1	CREAR	SOLICITUD_EDICION	32	{"accion": "EDITAR", "campos_modificados": ["numero_oficio", "numero_providencia", "tipo_solicitud", "justificacion"]}	127.0.0.1	2026-01-02 19:22:18.467402
143	1	CREAR	CARTA	19	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_19_4567891237894.pdf", "acceso_id": 17, "pdf_generado": true, "solicitud_id": 32}	127.0.0.1	2026-01-02 19:22:28.337645
144	1	CREAR	SOLICITUD	33	{"tipo": "NUEVA", "estado": "APROBADA", "persona_dpi": "9638527412589", "persona_nip": "78878-P"}	127.0.0.1	2026-01-02 19:28:22.194765
145	1	CREAR	SOLICITUD_EDICION	33	{"accion": "EDITAR", "campos_modificados": ["numero_oficio", "numero_providencia", "fecha_recepcion", "tipo_solicitud", "justificacion"]}	127.0.0.1	2026-01-02 19:29:40.185504
146	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-02 20:13:18.193087
147	1	CREAR	SOLICITUD_EDICION	33	{"accion": "EDITAR", "campos_modificados": ["numero_oficio", "numero_providencia", "fecha_recepcion", "tipo_solicitud", "justificacion"]}	127.0.0.1	2026-01-02 20:13:47.976066
148	1	CREAR	CARTA	20	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_20_9638527412589.pdf", "acceso_id": 18, "pdf_generado": true, "solicitud_id": 33}	127.0.0.1	2026-01-02 20:13:52.072021
149	1	CREAR	SOLICITUD	34	{"tipo": "NUEVA", "estado": "APROBADA", "persona_dpi": "9638527412589", "persona_nip": "78878-P"}	127.0.0.1	2026-01-02 20:32:12.411814
150	1	CREAR	CARTA	21	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_21_9638527412589.pdf", "acceso_id": 19, "pdf_generado": true, "solicitud_id": 34}	127.0.0.1	2026-01-02 20:32:16.79259
151	1	CREAR	SOLICITUD	35	{"tipo": "NUEVA", "estado": "APROBADA", "persona_dpi": "4567891237894", "persona_nip": "47586-P"}	127.0.0.1	2026-01-02 20:33:26.056609
152	1	CREAR	CARTA	22	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_22_4567891237894.pdf", "acceso_id": 20, "pdf_generado": true, "solicitud_id": 35}	127.0.0.1	2026-01-02 20:33:29.067896
153	1	CREAR	SOLICITUD	36	{"tipo": "NUEVA", "estado": "APROBADA", "persona_dpi": "9999888877776", "persona_nip": "22345-P"}	127.0.0.1	2026-01-02 20:34:25.112819
154	1	CREAR	CARTA	23	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_23_9999888877776.pdf", "acceso_id": 21, "pdf_generado": true, "solicitud_id": 36}	127.0.0.1	2026-01-02 20:34:29.428073
155	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-03 08:02:11.810195
156	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-03 09:25:09.698382
157	1	CREAR	PERSONA	10	{"dpi": "1234567891239", "nombre_completo": "Jonathan Cate"}	127.0.0.1	2026-01-03 10:03:39.738007
158	1	CREAR	SOLICITUD	37	{"tipo": "NUEVA", "estado": "APROBADA", "persona_dpi": "1234567891239", "persona_nip": "25345-P"}	127.0.0.1	2026-01-03 10:03:58.907019
159	1	CREAR	SOLICITUD	38	{"tipo": "RENOVACION", "estado": "APROBADA", "persona_dpi": "4567891237894", "persona_nip": "47586-P"}	127.0.0.1	2026-01-03 10:14:41.243784
160	1	CREAR	CARTA	24	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_24_4567891237894.pdf", "acceso_id": 22, "pdf_generado": true, "solicitud_id": 38}	127.0.0.1	2026-01-03 10:15:05.619192
161	1	BLOQUEAR	ACCESO	22	{"motivo": "CAUSO ALTA"}	127.0.0.1	2026-01-03 10:16:12.446841
\.


--
-- Data for Name: bloqueos_vpn; Type: TABLE DATA; Schema: public; Owner: vpn_user
--

COPY public.bloqueos_vpn (id, acceso_vpn_id, estado, motivo, usuario_id, fecha_cambio) FROM stdin;
1	1	BLOQUEADO	traslado a comisaria	1	2025-12-31 19:51:02.457087
2	4	BLOQUEADO	jdkldfjkjfdlkfdfd 	1	2025-12-31 19:56:16.557572
3	1	DESBLOQUEADO	Por equivocacion se bloqueo el usuario	1	2025-12-31 20:12:55.578637
4	3	BLOQUEADO	realizando prueba	1	2026-01-01 11:30:52.395767
5	7	BLOQUEADO	tercera prueba 	1	2026-01-01 11:35:45.170373
6	7	DESBLOQUEADO	era una prueba	1	2026-01-01 11:49:04.715681
7	2	BLOQUEADO	causo alta	1	2026-01-02 10:29:44.714175
8	2	DESBLOQUEADO	habilitarlo	1	2026-01-02 10:30:00.83085
9	22	BLOQUEADO	CAUSO ALTA	1	2026-01-03 10:16:12.381334
\.


--
-- Data for Name: cartas_responsabilidad; Type: TABLE DATA; Schema: public; Owner: vpn_user
--

COPY public.cartas_responsabilidad (id, solicitud_id, tipo, fecha_generacion, generada_por_usuario_id) FROM stdin;
1	1	RESPONSABILIDAD	2025-12-31	1
2	3	RESPONSABILIDAD	2025-12-31	1
3	4	RESPONSABILIDAD	2025-12-31	1
4	6	RESPONSABILIDAD	2025-12-31	1
5	7	RESPONSABILIDAD	2025-12-31	1
6	8	RESPONSABILIDAD	2025-12-31	1
7	5	RESPONSABILIDAD	2025-12-31	1
8	9	RESPONSABILIDAD	2025-12-31	1
9	10	RESPONSABILIDAD	2026-01-01	1
10	11	RESPONSABILIDAD	2026-01-01	1
11	18	RESPONSABILIDAD	2026-01-01	1
12	19	RESPONSABILIDAD	2026-01-02	1
13	25	RESPONSABILIDAD	2026-01-02	1
14	26	RESPONSABILIDAD	2026-01-02	1
15	28	RESPONSABILIDAD	2026-01-02	1
16	30	RESPONSABILIDAD	2026-01-02	1
17	29	RESPONSABILIDAD	2026-01-02	1
18	31	RESPONSABILIDAD	2026-01-02	1
19	32	RESPONSABILIDAD	2026-01-02	1
20	33	RESPONSABILIDAD	2026-01-02	1
21	34	RESPONSABILIDAD	2026-01-02	1
22	35	RESPONSABILIDAD	2026-01-02	1
23	36	RESPONSABILIDAD	2026-01-02	1
24	38	RESPONSABILIDAD	2026-01-03	1
\.


--
-- Data for Name: catalogos; Type: TABLE DATA; Schema: public; Owner: vpn_user
--

COPY public.catalogos (id, tipo, codigo, descripcion, activo) FROM stdin;
1	MOTIVO_BLOQUEO	VENCIMIENTO	Vencimiento de vigencia	t
2	MOTIVO_BLOQUEO	ADMINISTRATIVO	DecisiÃ³n administrativa	t
3	MOTIVO_BLOQUEO	SEGURIDAD	Incidente de seguridad	t
4	MOTIVO_BLOQUEO	FINALIZACION_LABORAL	TerminaciÃ³n de relaciÃ³n laboral	t
5	MOTIVO_DESBLOQUEO	RENOVACION	RenovaciÃ³n aprobada	t
6	MOTIVO_DESBLOQUEO	PRORROGA	PrÃ³rroga administrativa	t
7	MOTIVO_DESBLOQUEO	ERROR	CorrecciÃ³n de error administrativo	t
\.


--
-- Data for Name: comentarios_admin; Type: TABLE DATA; Schema: public; Owner: vpn_user
--

COPY public.comentarios_admin (id, entidad, entidad_id, comentario, usuario_id, fecha) FROM stdin;
\.


--
-- Data for Name: configuracion_sistema; Type: TABLE DATA; Schema: public; Owner: vpn_user
--

COPY public.configuracion_sistema (id, clave, valor, descripcion, tipo_dato, fecha_modificacion, modificado_por) FROM stdin;
1	DIAS_ALERTA_VENCIMIENTO	30	DÃ­as antes del vencimiento para generar alerta	INTEGER	2025-12-29 12:07:33.730041	\N
2	DIAS_GRACIA_DEFAULT	15	DÃ­as de gracia por defecto	INTEGER	2025-12-29 12:07:33.730041	\N
3	VIGENCIA_MESES	12	Meses de vigencia de acceso VPN	INTEGER	2025-12-29 12:07:33.730041	\N
4	RUTA_ARCHIVOS	/var/vpn_archivos	Ruta base para almacenamiento de archivos	STRING	2025-12-29 12:07:33.730041	\N
\.


--
-- Data for Name: importaciones_excel; Type: TABLE DATA; Schema: public; Owner: vpn_user
--

COPY public.importaciones_excel (id, archivo_origen, fecha_importacion, usuario_id, registros_procesados, registros_exitosos, registros_fallidos, resultado, log_errores) FROM stdin;
\.


--
-- Data for Name: personas; Type: TABLE DATA; Schema: public; Owner: vpn_user
--

COPY public.personas (id, dpi, nombres, apellidos, institucion, cargo, telefono, email, observaciones, activo, fecha_creacion, nip) FROM stdin;
1	1234567891000	Primera Prueba	Del Sistema	SGAIA	AGENTE	11111111	prueba1@gmail.com	\N	t	2025-12-30 12:31:48.791709	\N
3	1234567891234	Aaaa	Ooo	DIPANDA	Oficial III	88880000	a@gmail.com	\N	t	2025-12-31 09:43:21.077342	\N
4	1234567891001	Ddf	Faf	DEIC	agente	11111111	fd@gmail.com	\N	t	2025-12-31 15:45:42.42642	\N
5	1234567891230	Gdgf	Gfdfdg	SGAIA	INSPECTOR	12345678	DD@gmail.com	\N	t	2025-12-31 19:34:50.081437	44444-P
2	1111122222333	Segunda	Prueba Del Sistema	DIPANDA	agente	00001111	segunda@gmail.com	\N	t	2025-12-30 21:12:38.842033	44444-P
6	9999888877776	Esteban Osorio	Lopez Guzman	SGAIA	INSPECTOR	22225555	esteban21@gmail.com	\N	t	2026-01-01 10:54:19.92226	22345-P
7	9876543212345	Abner Joel	Bb Dd	DEIC	agente	14785236	11@gmail.com	\N	t	2026-01-01 11:59:58.843689	11111-P
8	4567891237894	Hola S	Dd Ll	UEI	oficial I	78945612	h@gmail.com	\N	t	2026-01-01 16:03:24.223546	47586-P
9	9638527412589	Probando Sistema	Prueba Cartas	Deic	Oficial II	89562374	cartas@gmail.com	\N	t	2026-01-02 09:41:19.574161	78878-P
10	1234567891239	Jonathan	Cate	DIPANDA	agente	41436701	jonxyc@gmail.com	\N	t	2026-01-03 10:03:39.695031	25345-P
\.


--
-- Data for Name: sesiones_login; Type: TABLE DATA; Schema: public; Owner: vpn_user
--

COPY public.sesiones_login (id, usuario_id, token_hash, ip_origen, user_agent, fecha_inicio, fecha_expiracion, activa) FROM stdin;
\.


--
-- Data for Name: solicitudes_vpn; Type: TABLE DATA; Schema: public; Owner: vpn_user
--

COPY public.solicitudes_vpn (id, persona_id, fecha_solicitud, tipo_solicitud, justificacion, estado, usuario_registro_id, comentarios_admin, fecha_registro, numero_oficio, numero_providencia, fecha_recepcion) FROM stdin;
11	7	2026-01-01	CREACION	creacion de vpn	APROBADA	1		2026-01-01 12:00:20.907455	5-2025	S/N	2026-01-01
29	8	2026-01-02	NUEVA	ACTUALIZACION	APROBADA	1	\N	2026-01-02 17:16:20.416405	2-2025	S/N	2026-01-02
28	8	2026-01-02	NUEVA	ACTUALIZACION	APROBADA	1	\N	2026-01-02 17:06:13.725707	22-2025	S/N	2026-01-02
30	6	2026-01-02	NUEVA	ACTUALIZACION\n	APROBADA	1	\N	2026-01-02 17:46:33.067044	\N	\N	2026-01-02
31	9	2026-01-03	RENOVACION	actualizacion	APROBADA	1	\N	2026-01-02 19:10:19.182063	72-2025	S/N	2026-01-03
32	8	2026-01-03	NUEVA	actualizacion	APROBADA	1	\N	2026-01-02 19:22:06.949033	12-2025	S/N	2026-01-03
33	9	2026-01-03	NUEVA	actualizacion	APROBADA	1	\N	2026-01-02 19:28:22.184662	260-2025	S/N	2026-01-03
34	9	2026-01-03	NUEVA	creacion	APROBADA	1	\N	2026-01-02 20:32:12.357983	5-2025	S/N	2026-01-03
35	8	2026-01-03	NUEVA	creacion	APROBADA	1	\N	2026-01-02 20:33:26.034986	5-2025	457-2026	2026-01-03
36	6	2026-01-03	NUEVA	creacion	APROBADA	1	\N	2026-01-02 20:34:25.095203	2-2025	264-2026	2025-12-30
38	8	2026-01-03	RENOVACION	GGFHHF	APROBADA	1	\N	2026-01-03 10:14:41.185724	51-2025	S/N	2026-01-03
19	9	2026-01-02	CREACION	CREACION	APROBADA	1		2026-01-02 09:42:06.67322	38-2025	S/N	2026-01-02
5	5	2026-01-01	CREACION	CREACION DE USUARIO VPN	APROBADA	1		2025-12-31 19:35:10.268308	38-2025	112-2025	2026-01-01
4	3	2025-12-31	CREACION	Solicitud de creacion de usuario vpn	APROBADA	1	REACTIVADA: NO_PRESENTADO: No se presentó a firmar | 	2025-12-31 15:44:20.469895	\N	\N	\N
10	6	2026-01-01	CREACION	creacion de usuario vpn	APROBADA	1		2026-01-01 10:54:39.07374	25-2025	112-2025	2025-12-31
1	2	2025-12-31	CREACION	CREACION DE USUARIO	APROBADA	1	REACTIVADA: NO_PRESENTADO:  | 	2025-12-30 21:13:12.984462	\N	\N	\N
8	2	2026-01-01	CREACION	idhfdhkjfdhjkdffd 	APROBADA	1	REACTIVADA: NO_PRESENTADO: No se presentó a firmar | 	2025-12-31 19:55:25.404511	72-2025	S/N	2025-12-31
9	3	2026-01-01	ACTUALIZACION	renovacion de usuario vpn	APROBADA	1		2025-12-31 20:55:00.166794	72-2025	112-2025	2025-01-03
26	9	2026-01-02	ACTUALIZACION	actualizacion	APROBADA	1		2026-01-02 10:27:21.724424	72-2025	457-2026	2025-12-30
3	2	2025-12-31	ACTUALIZACION	Actualizacion de usuario vpn	APROBADA	1		2025-12-31 15:39:17.919925	\N	\N	\N
6	5	2026-01-01	ACTUALIZACION	renovacion de usuario vpn	APROBADA	1		2025-12-31 19:50:10.302341	72-2025	S/N	2025-12-30
7	5	2026-01-01	ACTUALIZACION	usuario de vpn 	APROBADA	1	REACTIVADA: NO_PRESENTADO: No se presentó a firmar | 	2025-12-31 19:53:09.338083	38-2025	S/N	2025-12-31
25	8	2026-01-02	ACTUALIZACION	actualizacion	APROBADA	1		2026-01-02 10:12:24.28077	72-2025	S/N	2026-01-02
18	6	2026-01-02	ACTUALIZACION	ACTUALIZACION	APROBADA	1		2026-01-01 20:11:20.820044	25-2025	S/N	2025-12-30
\.


--
-- Data for Name: usuarios_sistema; Type: TABLE DATA; Schema: public; Owner: vpn_user
--

COPY public.usuarios_sistema (id, username, password_hash, nombre_completo, email, rol, activo, fecha_creacion, fecha_ultimo_login) FROM stdin;
1	admin	$2b$12$iq7h5i.pBClxAHHxYscC4uIm6HWVutjnDiMMk1n9.5y5Y6PfAbWmG	Administrador del Sistema	admin@institucion.gob.gt	SUPERADMIN	t	2025-12-29 12:08:57.844089	2026-01-03 15:25:09.622301
\.


--
-- Name: accesos_vpn_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vpn_user
--

SELECT pg_catalog.setval('public.accesos_vpn_id_seq', 22, true);


--
-- Name: alertas_sistema_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vpn_user
--

SELECT pg_catalog.setval('public.alertas_sistema_id_seq', 1, false);


--
-- Name: archivos_adjuntos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vpn_user
--

SELECT pg_catalog.setval('public.archivos_adjuntos_id_seq', 1, false);


--
-- Name: auditoria_eventos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vpn_user
--

SELECT pg_catalog.setval('public.auditoria_eventos_id_seq', 161, true);


--
-- Name: bloqueos_vpn_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vpn_user
--

SELECT pg_catalog.setval('public.bloqueos_vpn_id_seq', 9, true);


--
-- Name: cartas_responsabilidad_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vpn_user
--

SELECT pg_catalog.setval('public.cartas_responsabilidad_id_seq', 24, true);


--
-- Name: catalogos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vpn_user
--

SELECT pg_catalog.setval('public.catalogos_id_seq', 7, true);


--
-- Name: comentarios_admin_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vpn_user
--

SELECT pg_catalog.setval('public.comentarios_admin_id_seq', 1, false);


--
-- Name: configuracion_sistema_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vpn_user
--

SELECT pg_catalog.setval('public.configuracion_sistema_id_seq', 4, true);


--
-- Name: importaciones_excel_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vpn_user
--

SELECT pg_catalog.setval('public.importaciones_excel_id_seq', 1, false);


--
-- Name: personas_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vpn_user
--

SELECT pg_catalog.setval('public.personas_id_seq', 10, true);


--
-- Name: sesiones_login_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vpn_user
--

SELECT pg_catalog.setval('public.sesiones_login_id_seq', 1, false);


--
-- Name: solicitudes_vpn_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vpn_user
--

SELECT pg_catalog.setval('public.solicitudes_vpn_id_seq', 38, true);


--
-- Name: usuarios_sistema_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vpn_user
--

SELECT pg_catalog.setval('public.usuarios_sistema_id_seq', 1, true);


--
-- Name: accesos_vpn accesos_vpn_pkey; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.accesos_vpn
    ADD CONSTRAINT accesos_vpn_pkey PRIMARY KEY (id);


--
-- Name: alertas_sistema alertas_sistema_pkey; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.alertas_sistema
    ADD CONSTRAINT alertas_sistema_pkey PRIMARY KEY (id);


--
-- Name: archivos_adjuntos archivos_adjuntos_pkey; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.archivos_adjuntos
    ADD CONSTRAINT archivos_adjuntos_pkey PRIMARY KEY (id);


--
-- Name: auditoria_eventos auditoria_eventos_pkey; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.auditoria_eventos
    ADD CONSTRAINT auditoria_eventos_pkey PRIMARY KEY (id);


--
-- Name: bloqueos_vpn bloqueos_vpn_pkey; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.bloqueos_vpn
    ADD CONSTRAINT bloqueos_vpn_pkey PRIMARY KEY (id);


--
-- Name: cartas_responsabilidad cartas_responsabilidad_pkey; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.cartas_responsabilidad
    ADD CONSTRAINT cartas_responsabilidad_pkey PRIMARY KEY (id);


--
-- Name: catalogos catalogos_pkey; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.catalogos
    ADD CONSTRAINT catalogos_pkey PRIMARY KEY (id);


--
-- Name: catalogos catalogos_tipo_codigo_key; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.catalogos
    ADD CONSTRAINT catalogos_tipo_codigo_key UNIQUE (tipo, codigo);


--
-- Name: comentarios_admin comentarios_admin_pkey; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.comentarios_admin
    ADD CONSTRAINT comentarios_admin_pkey PRIMARY KEY (id);


--
-- Name: configuracion_sistema configuracion_sistema_clave_key; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.configuracion_sistema
    ADD CONSTRAINT configuracion_sistema_clave_key UNIQUE (clave);


--
-- Name: configuracion_sistema configuracion_sistema_pkey; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.configuracion_sistema
    ADD CONSTRAINT configuracion_sistema_pkey PRIMARY KEY (id);


--
-- Name: importaciones_excel importaciones_excel_pkey; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.importaciones_excel
    ADD CONSTRAINT importaciones_excel_pkey PRIMARY KEY (id);


--
-- Name: personas personas_dpi_key; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.personas
    ADD CONSTRAINT personas_dpi_key UNIQUE (dpi);


--
-- Name: personas personas_pkey; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.personas
    ADD CONSTRAINT personas_pkey PRIMARY KEY (id);


--
-- Name: sesiones_login sesiones_login_pkey; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.sesiones_login
    ADD CONSTRAINT sesiones_login_pkey PRIMARY KEY (id);


--
-- Name: solicitudes_vpn solicitudes_vpn_pkey; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.solicitudes_vpn
    ADD CONSTRAINT solicitudes_vpn_pkey PRIMARY KEY (id);


--
-- Name: usuarios_sistema usuarios_sistema_pkey; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.usuarios_sistema
    ADD CONSTRAINT usuarios_sistema_pkey PRIMARY KEY (id);


--
-- Name: usuarios_sistema usuarios_sistema_username_key; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.usuarios_sistema
    ADD CONSTRAINT usuarios_sistema_username_key UNIQUE (username);


--
-- Name: idx_accesos_estado; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_accesos_estado ON public.accesos_vpn USING btree (estado_vigencia);


--
-- Name: idx_accesos_fecha_fin; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_accesos_fecha_fin ON public.accesos_vpn USING btree (fecha_fin);


--
-- Name: idx_accesos_fecha_inicio; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_accesos_fecha_inicio ON public.accesos_vpn USING btree (fecha_inicio);


--
-- Name: idx_accesos_gracia; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_accesos_gracia ON public.accesos_vpn USING btree (fecha_fin_con_gracia);


--
-- Name: idx_accesos_solicitud; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_accesos_solicitud ON public.accesos_vpn USING btree (solicitud_id);


--
-- Name: idx_alertas_acceso; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_alertas_acceso ON public.alertas_sistema USING btree (acceso_vpn_id);


--
-- Name: idx_alertas_fecha; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_alertas_fecha ON public.alertas_sistema USING btree (fecha_generacion);


--
-- Name: idx_alertas_leida; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_alertas_leida ON public.alertas_sistema USING btree (leida);


--
-- Name: idx_alertas_tipo; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_alertas_tipo ON public.alertas_sistema USING btree (tipo);


--
-- Name: idx_archivos_carta; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_archivos_carta ON public.archivos_adjuntos USING btree (carta_id);


--
-- Name: idx_archivos_hash; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_archivos_hash ON public.archivos_adjuntos USING btree (hash_integridad);


--
-- Name: idx_auditoria_accion; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_auditoria_accion ON public.auditoria_eventos USING btree (accion);


--
-- Name: idx_auditoria_detalle; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_auditoria_detalle ON public.auditoria_eventos USING gin (detalle_json);


--
-- Name: idx_auditoria_entidad; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_auditoria_entidad ON public.auditoria_eventos USING btree (entidad, entidad_id);


--
-- Name: idx_auditoria_fecha; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_auditoria_fecha ON public.auditoria_eventos USING btree (fecha);


--
-- Name: idx_auditoria_usuario; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_auditoria_usuario ON public.auditoria_eventos USING btree (usuario_id);


--
-- Name: idx_bloqueos_acceso; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_bloqueos_acceso ON public.bloqueos_vpn USING btree (acceso_vpn_id);


--
-- Name: idx_bloqueos_estado; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_bloqueos_estado ON public.bloqueos_vpn USING btree (estado);


--
-- Name: idx_bloqueos_fecha; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_bloqueos_fecha ON public.bloqueos_vpn USING btree (fecha_cambio);


--
-- Name: idx_cartas_solicitud; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_cartas_solicitud ON public.cartas_responsabilidad USING btree (solicitud_id);


--
-- Name: idx_cartas_tipo; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_cartas_tipo ON public.cartas_responsabilidad USING btree (tipo);


--
-- Name: idx_comentarios_entidad; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_comentarios_entidad ON public.comentarios_admin USING btree (entidad, entidad_id);


--
-- Name: idx_comentarios_fecha; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_comentarios_fecha ON public.comentarios_admin USING btree (fecha);


--
-- Name: idx_personas_activo; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_personas_activo ON public.personas USING btree (activo);


--
-- Name: idx_personas_apellidos; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_personas_apellidos ON public.personas USING btree (apellidos);


--
-- Name: idx_personas_dpi; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_personas_dpi ON public.personas USING btree (dpi);


--
-- Name: idx_personas_nip; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_personas_nip ON public.personas USING btree (nip);


--
-- Name: idx_personas_nombres; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_personas_nombres ON public.personas USING btree (nombres);


--
-- Name: idx_sesiones_activa; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_sesiones_activa ON public.sesiones_login USING btree (activa);


--
-- Name: idx_sesiones_fecha; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_sesiones_fecha ON public.sesiones_login USING btree (fecha_inicio);


--
-- Name: idx_sesiones_usuario; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_sesiones_usuario ON public.sesiones_login USING btree (usuario_id);


--
-- Name: idx_solicitudes_estado; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_solicitudes_estado ON public.solicitudes_vpn USING btree (estado);


--
-- Name: idx_solicitudes_fecha; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_solicitudes_fecha ON public.solicitudes_vpn USING btree (fecha_solicitud);


--
-- Name: idx_solicitudes_oficio; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_solicitudes_oficio ON public.solicitudes_vpn USING btree (numero_oficio);


--
-- Name: idx_solicitudes_persona; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_solicitudes_persona ON public.solicitudes_vpn USING btree (persona_id);


--
-- Name: idx_solicitudes_providencia; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_solicitudes_providencia ON public.solicitudes_vpn USING btree (numero_providencia);


--
-- Name: idx_solicitudes_tipo; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_solicitudes_tipo ON public.solicitudes_vpn USING btree (tipo_solicitud);


--
-- Name: idx_usuarios_activo; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_usuarios_activo ON public.usuarios_sistema USING btree (activo);


--
-- Name: idx_usuarios_username; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_usuarios_username ON public.usuarios_sistema USING btree (username);


--
-- Name: accesos_vpn trigger_calcular_fecha_gracia; Type: TRIGGER; Schema: public; Owner: vpn_user
--

CREATE TRIGGER trigger_calcular_fecha_gracia BEFORE INSERT OR UPDATE ON public.accesos_vpn FOR EACH ROW EXECUTE FUNCTION public.calcular_fecha_gracia();


--
-- Name: accesos_vpn accesos_vpn_solicitud_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.accesos_vpn
    ADD CONSTRAINT accesos_vpn_solicitud_id_fkey FOREIGN KEY (solicitud_id) REFERENCES public.solicitudes_vpn(id);


--
-- Name: accesos_vpn accesos_vpn_usuario_creacion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.accesos_vpn
    ADD CONSTRAINT accesos_vpn_usuario_creacion_id_fkey FOREIGN KEY (usuario_creacion_id) REFERENCES public.usuarios_sistema(id);


--
-- Name: alertas_sistema alertas_sistema_acceso_vpn_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.alertas_sistema
    ADD CONSTRAINT alertas_sistema_acceso_vpn_id_fkey FOREIGN KEY (acceso_vpn_id) REFERENCES public.accesos_vpn(id);


--
-- Name: archivos_adjuntos archivos_adjuntos_carta_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.archivos_adjuntos
    ADD CONSTRAINT archivos_adjuntos_carta_id_fkey FOREIGN KEY (carta_id) REFERENCES public.cartas_responsabilidad(id);


--
-- Name: archivos_adjuntos archivos_adjuntos_usuario_subida_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.archivos_adjuntos
    ADD CONSTRAINT archivos_adjuntos_usuario_subida_id_fkey FOREIGN KEY (usuario_subida_id) REFERENCES public.usuarios_sistema(id);


--
-- Name: auditoria_eventos auditoria_eventos_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.auditoria_eventos
    ADD CONSTRAINT auditoria_eventos_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios_sistema(id);


--
-- Name: bloqueos_vpn bloqueos_vpn_acceso_vpn_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.bloqueos_vpn
    ADD CONSTRAINT bloqueos_vpn_acceso_vpn_id_fkey FOREIGN KEY (acceso_vpn_id) REFERENCES public.accesos_vpn(id);


--
-- Name: bloqueos_vpn bloqueos_vpn_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.bloqueos_vpn
    ADD CONSTRAINT bloqueos_vpn_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios_sistema(id);


--
-- Name: cartas_responsabilidad cartas_responsabilidad_generada_por_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.cartas_responsabilidad
    ADD CONSTRAINT cartas_responsabilidad_generada_por_usuario_id_fkey FOREIGN KEY (generada_por_usuario_id) REFERENCES public.usuarios_sistema(id);


--
-- Name: cartas_responsabilidad cartas_responsabilidad_solicitud_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.cartas_responsabilidad
    ADD CONSTRAINT cartas_responsabilidad_solicitud_id_fkey FOREIGN KEY (solicitud_id) REFERENCES public.solicitudes_vpn(id);


--
-- Name: comentarios_admin comentarios_admin_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.comentarios_admin
    ADD CONSTRAINT comentarios_admin_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios_sistema(id);


--
-- Name: configuracion_sistema configuracion_sistema_modificado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.configuracion_sistema
    ADD CONSTRAINT configuracion_sistema_modificado_por_fkey FOREIGN KEY (modificado_por) REFERENCES public.usuarios_sistema(id);


--
-- Name: importaciones_excel importaciones_excel_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.importaciones_excel
    ADD CONSTRAINT importaciones_excel_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios_sistema(id);


--
-- Name: sesiones_login sesiones_login_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.sesiones_login
    ADD CONSTRAINT sesiones_login_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios_sistema(id);


--
-- Name: solicitudes_vpn solicitudes_vpn_persona_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.solicitudes_vpn
    ADD CONSTRAINT solicitudes_vpn_persona_id_fkey FOREIGN KEY (persona_id) REFERENCES public.personas(id);


--
-- Name: solicitudes_vpn solicitudes_vpn_usuario_registro_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.solicitudes_vpn
    ADD CONSTRAINT solicitudes_vpn_usuario_registro_id_fkey FOREIGN KEY (usuario_registro_id) REFERENCES public.usuarios_sistema(id);


--
-- PostgreSQL database dump complete
--

\unrestrict znvvUuM4xaU1cLAgeSRvqlqO7FnbQvGgYad1TV6JOHebrnTPovrCsNSSncuv5wV

