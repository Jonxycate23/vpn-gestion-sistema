--
-- PostgreSQL database dump
--

\restrict 8czH3YlB07WofLHRaJzdcm2NuKMKqemn3Y7uQ4kSgE1RabFxZRKIYfp607WbDTw

-- Dumped from database version 16.11
-- Dumped by pg_dump version 16.11

-- Started on 2026-02-03 20:00:17

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
-- TOC entry 245 (class 1255 OID 16676)
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
-- TOC entry 5135 (class 0 OID 0)
-- Dependencies: 245
-- Name: FUNCTION actualizar_estado_vigencia(); Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON FUNCTION public.actualizar_estado_vigencia() IS 'Actualiza estados de vigencia segÃºn fechas - ejecutar diariamente';


--
-- TOC entry 247 (class 1255 OID 16678)
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
-- TOC entry 246 (class 1255 OID 16677)
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
-- TOC entry 5136 (class 0 OID 0)
-- Dependencies: 246
-- Name: FUNCTION generar_alertas_vencimiento(); Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON FUNCTION public.generar_alertas_vencimiento() IS 'Genera alertas diarias de vencimientos prÃ³ximos';


--
-- TOC entry 248 (class 1255 OID 16690)
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
-- TOC entry 5137 (class 0 OID 0)
-- Dependencies: 248
-- Name: FUNCTION obtener_historial_persona(dpi_persona character varying); Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON FUNCTION public.obtener_historial_persona(dpi_persona character varying) IS 'Obtiene todo el historial de solicitudes y accesos de una persona';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 222 (class 1259 OID 16451)
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
    CONSTRAINT vigencia_12_meses CHECK (((fecha_fin - fecha_inicio) = 365))
);


ALTER TABLE public.accesos_vpn OWNER TO vpn_user;

--
-- TOC entry 5138 (class 0 OID 0)
-- Dependencies: 222
-- Name: TABLE accesos_vpn; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON TABLE public.accesos_vpn IS 'Control real de vigencia - separado de la solicitud';


--
-- TOC entry 5139 (class 0 OID 0)
-- Dependencies: 222
-- Name: COLUMN accesos_vpn.dias_gracia; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.accesos_vpn.dias_gracia IS 'DÃ­as adicionales otorgados administrativamente';


--
-- TOC entry 5140 (class 0 OID 0)
-- Dependencies: 222
-- Name: COLUMN accesos_vpn.estado_vigencia; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.accesos_vpn.estado_vigencia IS 'ACTIVO: vigente, POR_VENCER: 30 dÃ­as antes, VENCIDO: despuÃ©s de fecha_fin';


--
-- TOC entry 221 (class 1259 OID 16450)
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
-- TOC entry 5142 (class 0 OID 0)
-- Dependencies: 221
-- Name: accesos_vpn_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vpn_user
--

ALTER SEQUENCE public.accesos_vpn_id_seq OWNED BY public.accesos_vpn.id;


--
-- TOC entry 234 (class 1259 OID 16562)
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
-- TOC entry 5144 (class 0 OID 0)
-- Dependencies: 234
-- Name: TABLE alertas_sistema; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON TABLE public.alertas_sistema IS 'Alertas operativas internas - dashboard diario';


--
-- TOC entry 233 (class 1259 OID 16561)
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
-- TOC entry 5146 (class 0 OID 0)
-- Dependencies: 233
-- Name: alertas_sistema_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vpn_user
--

ALTER SEQUENCE public.alertas_sistema_id_seq OWNED BY public.alertas_sistema.id;


--
-- TOC entry 228 (class 1259 OID 16511)
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
-- TOC entry 5148 (class 0 OID 0)
-- Dependencies: 228
-- Name: TABLE archivos_adjuntos; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON TABLE public.archivos_adjuntos IS 'Almacenamiento de archivos firmados - NUNCA en BD';


--
-- TOC entry 5149 (class 0 OID 0)
-- Dependencies: 228
-- Name: COLUMN archivos_adjuntos.ruta_archivo; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.archivos_adjuntos.ruta_archivo IS 'Path relativo en filesystem interno';


--
-- TOC entry 5150 (class 0 OID 0)
-- Dependencies: 228
-- Name: COLUMN archivos_adjuntos.hash_integridad; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.archivos_adjuntos.hash_integridad IS 'SHA-256 para verificar integridad';


--
-- TOC entry 227 (class 1259 OID 16510)
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
-- TOC entry 5152 (class 0 OID 0)
-- Dependencies: 227
-- Name: archivos_adjuntos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vpn_user
--

ALTER SEQUENCE public.archivos_adjuntos_id_seq OWNED BY public.archivos_adjuntos.id;


--
-- TOC entry 232 (class 1259 OID 16547)
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
-- TOC entry 5154 (class 0 OID 0)
-- Dependencies: 232
-- Name: COLUMN auditoria_eventos.accion; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.auditoria_eventos.accion IS 'Ejemplos: CREAR, EDITAR, BLOQUEAR, DESBLOQUEAR, LOGIN, IMPORTAR';


--
-- TOC entry 5155 (class 0 OID 0)
-- Dependencies: 232
-- Name: COLUMN auditoria_eventos.detalle_json; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.auditoria_eventos.detalle_json IS 'Snapshot completo del cambio en formato JSON';


--
-- TOC entry 231 (class 1259 OID 16546)
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
-- TOC entry 5157 (class 0 OID 0)
-- Dependencies: 231
-- Name: auditoria_eventos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vpn_user
--

ALTER SEQUENCE public.auditoria_eventos_id_seq OWNED BY public.auditoria_eventos.id;


--
-- TOC entry 224 (class 1259 OID 16472)
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
-- TOC entry 5159 (class 0 OID 0)
-- Dependencies: 224
-- Name: TABLE bloqueos_vpn; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON TABLE public.bloqueos_vpn IS 'HistÃ³rico de bloqueos/desbloqueos - crÃ­tico para auditorÃ­a';


--
-- TOC entry 5160 (class 0 OID 0)
-- Dependencies: 224
-- Name: COLUMN bloqueos_vpn.motivo; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.bloqueos_vpn.motivo IS 'OBLIGATORIO: justificaciÃ³n administrativa del cambio';


--
-- TOC entry 223 (class 1259 OID 16471)
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
-- TOC entry 5162 (class 0 OID 0)
-- Dependencies: 223
-- Name: bloqueos_vpn_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vpn_user
--

ALTER SEQUENCE public.bloqueos_vpn_id_seq OWNED BY public.bloqueos_vpn.id;


--
-- TOC entry 226 (class 1259 OID 16493)
-- Name: cartas_responsabilidad; Type: TABLE; Schema: public; Owner: vpn_user
--

CREATE TABLE public.cartas_responsabilidad (
    id integer NOT NULL,
    solicitud_id integer NOT NULL,
    tipo character varying(30) NOT NULL,
    fecha_generacion date NOT NULL,
    generada_por_usuario_id integer NOT NULL,
    numero_carta integer,
    anio_carta integer,
    eliminada boolean DEFAULT false NOT NULL,
    CONSTRAINT cartas_responsabilidad_tipo_check CHECK (((tipo)::text = ANY ((ARRAY['RESPONSABILIDAD'::character varying, 'PRORROGA'::character varying, 'OTRO'::character varying])::text[])))
);


ALTER TABLE public.cartas_responsabilidad OWNER TO vpn_user;

--
-- TOC entry 5164 (class 0 OID 0)
-- Dependencies: 226
-- Name: TABLE cartas_responsabilidad; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON TABLE public.cartas_responsabilidad IS 'Metadatos de documentos legales';


--
-- TOC entry 5165 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN cartas_responsabilidad.tipo; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.cartas_responsabilidad.tipo IS 'RESPONSABILIDAD: carta inicial, PRORROGA: extensiÃ³n';


--
-- TOC entry 5166 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN cartas_responsabilidad.eliminada; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.cartas_responsabilidad.eliminada IS 'Indica si la carta fue eliminada (para mantener numeración)';


--
-- TOC entry 225 (class 1259 OID 16492)
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
-- TOC entry 5168 (class 0 OID 0)
-- Dependencies: 225
-- Name: cartas_responsabilidad_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vpn_user
--

ALTER SEQUENCE public.cartas_responsabilidad_id_seq OWNED BY public.cartas_responsabilidad.id;


--
-- TOC entry 240 (class 1259 OID 16614)
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
-- TOC entry 5170 (class 0 OID 0)
-- Dependencies: 240
-- Name: TABLE catalogos; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON TABLE public.catalogos IS 'Valores normalizados para listas desplegables';


--
-- TOC entry 239 (class 1259 OID 16613)
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
-- TOC entry 5172 (class 0 OID 0)
-- Dependencies: 239
-- Name: catalogos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vpn_user
--

ALTER SEQUENCE public.catalogos_id_seq OWNED BY public.catalogos.id;


--
-- TOC entry 230 (class 1259 OID 16531)
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
-- TOC entry 5174 (class 0 OID 0)
-- Dependencies: 230
-- Name: TABLE comentarios_admin; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON TABLE public.comentarios_admin IS 'BitÃ¡cora operativa humana - contexto institucional';


--
-- TOC entry 229 (class 1259 OID 16530)
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
-- TOC entry 5176 (class 0 OID 0)
-- Dependencies: 229
-- Name: comentarios_admin_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vpn_user
--

ALTER SEQUENCE public.comentarios_admin_id_seq OWNED BY public.comentarios_admin.id;


--
-- TOC entry 238 (class 1259 OID 16596)
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
-- TOC entry 5178 (class 0 OID 0)
-- Dependencies: 238
-- Name: TABLE configuracion_sistema; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON TABLE public.configuracion_sistema IS 'Configuraciones operativas del sistema';


--
-- TOC entry 237 (class 1259 OID 16595)
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
-- TOC entry 5180 (class 0 OID 0)
-- Dependencies: 237
-- Name: configuracion_sistema_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vpn_user
--

ALTER SEQUENCE public.configuracion_sistema_id_seq OWNED BY public.configuracion_sistema.id;


--
-- TOC entry 236 (class 1259 OID 16578)
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
-- TOC entry 5182 (class 0 OID 0)
-- Dependencies: 236
-- Name: TABLE importaciones_excel; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON TABLE public.importaciones_excel IS 'Trazabilidad de migraciÃ³n desde Excel';


--
-- TOC entry 235 (class 1259 OID 16577)
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
-- TOC entry 5184 (class 0 OID 0)
-- Dependencies: 235
-- Name: importaciones_excel_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vpn_user
--

ALTER SEQUENCE public.importaciones_excel_id_seq OWNED BY public.importaciones_excel.id;


--
-- TOC entry 218 (class 1259 OID 16416)
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
-- TOC entry 5186 (class 0 OID 0)
-- Dependencies: 218
-- Name: TABLE personas; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON TABLE public.personas IS 'Entidad real que solicita acceso VPN (puede tener mÃºltiples solicitudes)';


--
-- TOC entry 5187 (class 0 OID 0)
-- Dependencies: 218
-- Name: COLUMN personas.dpi; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.personas.dpi IS 'Documento Personal de IdentificaciÃ³n - Ãºnico e inmutable';


--
-- TOC entry 5188 (class 0 OID 0)
-- Dependencies: 218
-- Name: COLUMN personas.nip; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.personas.nip IS 'NÃºmero de IdentificaciÃ³n Policial';


--
-- TOC entry 217 (class 1259 OID 16415)
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
-- TOC entry 5190 (class 0 OID 0)
-- Dependencies: 217
-- Name: personas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vpn_user
--

ALTER SEQUENCE public.personas_id_seq OWNED BY public.personas.id;


--
-- TOC entry 242 (class 1259 OID 16624)
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
-- TOC entry 5192 (class 0 OID 0)
-- Dependencies: 242
-- Name: TABLE sesiones_login; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON TABLE public.sesiones_login IS 'Control de sesiones activas y auditorÃ­a de accesos';


--
-- TOC entry 241 (class 1259 OID 16623)
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
-- TOC entry 5194 (class 0 OID 0)
-- Dependencies: 241
-- Name: sesiones_login_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vpn_user
--

ALTER SEQUENCE public.sesiones_login_id_seq OWNED BY public.sesiones_login.id;


--
-- TOC entry 220 (class 1259 OID 16429)
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
    CONSTRAINT solicitudes_vpn_estado_check CHECK (((estado)::text = ANY ((ARRAY['APROBADA'::character varying, 'PENDIENTE'::character varying, 'CANCELADA'::character varying])::text[]))),
    CONSTRAINT solicitudes_vpn_tipo_solicitud_check CHECK (((tipo_solicitud)::text = ANY ((ARRAY['CREACION'::character varying, 'ACTUALIZACION'::character varying, 'NUEVA'::character varying, 'RENOVACION'::character varying])::text[])))
);


ALTER TABLE public.solicitudes_vpn OWNER TO vpn_user;

--
-- TOC entry 5196 (class 0 OID 0)
-- Dependencies: 220
-- Name: TABLE solicitudes_vpn; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON TABLE public.solicitudes_vpn IS 'Expediente administrativo - NUNCA se sobreescribe';


--
-- TOC entry 5197 (class 0 OID 0)
-- Dependencies: 220
-- Name: COLUMN solicitudes_vpn.tipo_solicitud; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.solicitudes_vpn.tipo_solicitud IS 'NUEVA, RENOVACION, CREACION, ACTUALIZACION';


--
-- TOC entry 5198 (class 0 OID 0)
-- Dependencies: 220
-- Name: COLUMN solicitudes_vpn.estado; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.solicitudes_vpn.estado IS 'PENDIENTE, APROBADA, RECHAZADA, DENEGADA, CANCELADA';


--
-- TOC entry 5199 (class 0 OID 0)
-- Dependencies: 220
-- Name: COLUMN solicitudes_vpn.numero_oficio; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.solicitudes_vpn.numero_oficio IS 'NÃºmero de oficio recibido';


--
-- TOC entry 5200 (class 0 OID 0)
-- Dependencies: 220
-- Name: COLUMN solicitudes_vpn.numero_providencia; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.solicitudes_vpn.numero_providencia IS 'NÃºmero de providencia';


--
-- TOC entry 5201 (class 0 OID 0)
-- Dependencies: 220
-- Name: COLUMN solicitudes_vpn.fecha_recepcion; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.solicitudes_vpn.fecha_recepcion IS 'Fecha en que se recibiÃ³ la solicitud fÃ­sica';


--
-- TOC entry 219 (class 1259 OID 16428)
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
-- TOC entry 5203 (class 0 OID 0)
-- Dependencies: 219
-- Name: solicitudes_vpn_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vpn_user
--

ALTER SEQUENCE public.solicitudes_vpn_id_seq OWNED BY public.solicitudes_vpn.id;


--
-- TOC entry 216 (class 1259 OID 16401)
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
-- TOC entry 5205 (class 0 OID 0)
-- Dependencies: 216
-- Name: TABLE usuarios_sistema; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON TABLE public.usuarios_sistema IS 'Usuarios internos que operan el sistema';


--
-- TOC entry 5206 (class 0 OID 0)
-- Dependencies: 216
-- Name: COLUMN usuarios_sistema.password_hash; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.usuarios_sistema.password_hash IS 'Hash bcrypt de la contraseÃ±a';


--
-- TOC entry 5207 (class 0 OID 0)
-- Dependencies: 216
-- Name: COLUMN usuarios_sistema.rol; Type: COMMENT; Schema: public; Owner: vpn_user
--

COMMENT ON COLUMN public.usuarios_sistema.rol IS 'SUPERADMIN: configuraciÃ³n y auditorÃ­a, ADMIN: operaciÃ³n';


--
-- TOC entry 215 (class 1259 OID 16400)
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
-- TOC entry 5209 (class 0 OID 0)
-- Dependencies: 215
-- Name: usuarios_sistema_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vpn_user
--

ALTER SEQUENCE public.usuarios_sistema_id_seq OWNED BY public.usuarios_sistema.id;


--
-- TOC entry 244 (class 1259 OID 24820)
-- Name: vista_accesos_actuales; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vista_accesos_actuales AS
 SELECT p.id AS persona_id,
    p.dpi,
    p.nip,
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
    COALESCE(( SELECT b.estado
           FROM public.bloqueos_vpn b
          WHERE (b.acceso_vpn_id = a.id)
          ORDER BY b.fecha_cambio DESC
         LIMIT 1), 'DESBLOQUEADO'::character varying) AS estado_bloqueo,
    u.nombre_completo AS usuario_registro
   FROM (((public.accesos_vpn a
     JOIN public.solicitudes_vpn s ON ((s.id = a.solicitud_id)))
     JOIN public.personas p ON ((p.id = s.persona_id)))
     LEFT JOIN public.usuarios_sistema u ON ((u.id = s.usuario_registro_id)))
  ORDER BY a.fecha_fin_con_gracia;


ALTER VIEW public.vista_accesos_actuales OWNER TO postgres;

--
-- TOC entry 243 (class 1259 OID 24815)
-- Name: vista_dashboard_vencimientos; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vista_dashboard_vencimientos AS
 SELECT count(*) FILTER (WHERE (((estado_vigencia)::text = 'ACTIVO'::text) AND ((COALESCE(( SELECT b.estado
           FROM public.bloqueos_vpn b
          WHERE (b.acceso_vpn_id = a.id)
          ORDER BY b.fecha_cambio DESC
         LIMIT 1), 'DESBLOQUEADO'::character varying))::text = 'DESBLOQUEADO'::text))) AS activos,
    count(*) FILTER (WHERE ((((fecha_fin_con_gracia - CURRENT_DATE) >= 1) AND ((fecha_fin_con_gracia - CURRENT_DATE) <= 30)) AND ((COALESCE(( SELECT b.estado
           FROM public.bloqueos_vpn b
          WHERE (b.acceso_vpn_id = a.id)
          ORDER BY b.fecha_cambio DESC
         LIMIT 1), 'DESBLOQUEADO'::character varying))::text = 'DESBLOQUEADO'::text))) AS por_vencer,
    count(*) FILTER (WHERE (((fecha_fin_con_gracia - CURRENT_DATE) <= 0) AND ((COALESCE(( SELECT b.estado
           FROM public.bloqueos_vpn b
          WHERE (b.acceso_vpn_id = a.id)
          ORDER BY b.fecha_cambio DESC
         LIMIT 1), 'DESBLOQUEADO'::character varying))::text = 'DESBLOQUEADO'::text))) AS vencidos,
    count(*) FILTER (WHERE ((COALESCE(( SELECT b.estado
           FROM public.bloqueos_vpn b
          WHERE (b.acceso_vpn_id = a.id)
          ORDER BY b.fecha_cambio DESC
         LIMIT 1), 'DESBLOQUEADO'::character varying))::text = 'BLOQUEADO'::text)) AS bloqueados,
    count(*) FILTER (WHERE ((((fecha_fin_con_gracia - CURRENT_DATE) >= 1) AND ((fecha_fin_con_gracia - CURRENT_DATE) <= 7)) AND ((COALESCE(( SELECT b.estado
           FROM public.bloqueos_vpn b
          WHERE (b.acceso_vpn_id = a.id)
          ORDER BY b.fecha_cambio DESC
         LIMIT 1), 'DESBLOQUEADO'::character varying))::text = 'DESBLOQUEADO'::text))) AS vencen_esta_semana,
    count(*) FILTER (WHERE ((fecha_fin_con_gracia = CURRENT_DATE) AND ((COALESCE(( SELECT b.estado
           FROM public.bloqueos_vpn b
          WHERE (b.acceso_vpn_id = a.id)
          ORDER BY b.fecha_cambio DESC
         LIMIT 1), 'DESBLOQUEADO'::character varying))::text = 'DESBLOQUEADO'::text))) AS vencen_hoy
   FROM public.accesos_vpn a;


ALTER VIEW public.vista_dashboard_vencimientos OWNER TO postgres;

--
-- TOC entry 4822 (class 2604 OID 16454)
-- Name: accesos_vpn id; Type: DEFAULT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.accesos_vpn ALTER COLUMN id SET DEFAULT nextval('public.accesos_vpn_id_seq'::regclass);


--
-- TOC entry 4835 (class 2604 OID 16565)
-- Name: alertas_sistema id; Type: DEFAULT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.alertas_sistema ALTER COLUMN id SET DEFAULT nextval('public.alertas_sistema_id_seq'::regclass);


--
-- TOC entry 4829 (class 2604 OID 16514)
-- Name: archivos_adjuntos id; Type: DEFAULT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.archivos_adjuntos ALTER COLUMN id SET DEFAULT nextval('public.archivos_adjuntos_id_seq'::regclass);


--
-- TOC entry 4833 (class 2604 OID 16550)
-- Name: auditoria_eventos id; Type: DEFAULT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.auditoria_eventos ALTER COLUMN id SET DEFAULT nextval('public.auditoria_eventos_id_seq'::regclass);


--
-- TOC entry 4825 (class 2604 OID 16475)
-- Name: bloqueos_vpn id; Type: DEFAULT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.bloqueos_vpn ALTER COLUMN id SET DEFAULT nextval('public.bloqueos_vpn_id_seq'::regclass);


--
-- TOC entry 4827 (class 2604 OID 16496)
-- Name: cartas_responsabilidad id; Type: DEFAULT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.cartas_responsabilidad ALTER COLUMN id SET DEFAULT nextval('public.cartas_responsabilidad_id_seq'::regclass);


--
-- TOC entry 4844 (class 2604 OID 16617)
-- Name: catalogos id; Type: DEFAULT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.catalogos ALTER COLUMN id SET DEFAULT nextval('public.catalogos_id_seq'::regclass);


--
-- TOC entry 4831 (class 2604 OID 16534)
-- Name: comentarios_admin id; Type: DEFAULT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.comentarios_admin ALTER COLUMN id SET DEFAULT nextval('public.comentarios_admin_id_seq'::regclass);


--
-- TOC entry 4842 (class 2604 OID 16599)
-- Name: configuracion_sistema id; Type: DEFAULT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.configuracion_sistema ALTER COLUMN id SET DEFAULT nextval('public.configuracion_sistema_id_seq'::regclass);


--
-- TOC entry 4837 (class 2604 OID 16581)
-- Name: importaciones_excel id; Type: DEFAULT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.importaciones_excel ALTER COLUMN id SET DEFAULT nextval('public.importaciones_excel_id_seq'::regclass);


--
-- TOC entry 4817 (class 2604 OID 16419)
-- Name: personas id; Type: DEFAULT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.personas ALTER COLUMN id SET DEFAULT nextval('public.personas_id_seq'::regclass);


--
-- TOC entry 4846 (class 2604 OID 16627)
-- Name: sesiones_login id; Type: DEFAULT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.sesiones_login ALTER COLUMN id SET DEFAULT nextval('public.sesiones_login_id_seq'::regclass);


--
-- TOC entry 4820 (class 2604 OID 16432)
-- Name: solicitudes_vpn id; Type: DEFAULT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.solicitudes_vpn ALTER COLUMN id SET DEFAULT nextval('public.solicitudes_vpn_id_seq'::regclass);


--
-- TOC entry 4814 (class 2604 OID 16404)
-- Name: usuarios_sistema id; Type: DEFAULT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.usuarios_sistema ALTER COLUMN id SET DEFAULT nextval('public.usuarios_sistema_id_seq'::regclass);


--
-- TOC entry 5109 (class 0 OID 16451)
-- Dependencies: 222
-- Data for Name: accesos_vpn; Type: TABLE DATA; Schema: public; Owner: vpn_user
--

COPY public.accesos_vpn (id, solicitud_id, fecha_inicio, fecha_fin, dias_gracia, fecha_fin_con_gracia, estado_vigencia, usuario_creacion_id, fecha_creacion) FROM stdin;
816	888	2026-01-02	2027-01-02	0	2027-01-02	ACTIVO	1	2026-02-03 19:59:33.209583
817	889	2025-10-02	2026-10-02	0	2026-10-02	ACTIVO	1	2026-02-03 19:59:33.209583
818	890	2025-09-21	2026-09-21	0	2026-09-21	ACTIVO	1	2026-02-03 19:59:33.209583
819	891	2025-09-18	2026-09-18	0	2026-09-18	ACTIVO	1	2026-02-03 19:59:33.209583
820	892	2025-09-20	2026-09-20	0	2026-09-20	ACTIVO	1	2026-02-03 19:59:33.209583
821	893	2025-09-23	2026-09-23	0	2026-09-23	ACTIVO	1	2026-02-03 19:59:33.209583
822	894	2025-09-24	2026-09-24	0	2026-09-24	ACTIVO	1	2026-02-03 19:59:33.209583
823	895	2025-10-09	2026-10-09	0	2026-10-09	ACTIVO	1	2026-02-03 19:59:33.209583
824	896	2025-09-23	2026-09-23	0	2026-09-23	ACTIVO	1	2026-02-03 19:59:33.209583
825	897	2025-09-23	2026-09-23	0	2026-09-23	ACTIVO	1	2026-02-03 19:59:33.209583
826	898	2025-09-22	2026-09-22	0	2026-09-22	ACTIVO	1	2026-02-03 19:59:33.209583
827	899	2025-09-25	2026-09-25	0	2026-09-25	ACTIVO	1	2026-02-03 19:59:33.209583
828	900	2025-09-28	2026-09-28	0	2026-09-28	ACTIVO	1	2026-02-03 19:59:33.209583
829	903	2025-10-21	2026-10-21	0	2026-10-21	ACTIVO	1	2026-02-03 19:59:33.209583
830	905	2025-10-06	2026-10-06	0	2026-10-06	ACTIVO	1	2026-02-03 19:59:33.209583
831	907	2025-10-25	2026-10-25	0	2026-10-25	ACTIVO	1	2026-02-03 19:59:33.209583
832	908	2025-08-01	2026-08-01	0	2026-08-01	ACTIVO	1	2026-02-03 19:59:33.209583
833	909	2025-09-17	2026-09-17	0	2026-09-17	ACTIVO	1	2026-02-03 19:59:33.209583
834	910	2025-10-14	2026-10-14	0	2026-10-14	ACTIVO	1	2026-02-03 19:59:33.209583
835	911	2025-09-16	2026-09-16	0	2026-09-16	ACTIVO	1	2026-02-03 19:59:33.209583
836	912	2025-09-19	2026-09-19	0	2026-09-19	ACTIVO	1	2026-02-03 19:59:33.209583
837	913	2025-09-28	2026-09-28	0	2026-09-28	ACTIVO	1	2026-02-03 19:59:33.209583
838	914	2025-10-10	2026-10-10	0	2026-10-10	ACTIVO	1	2026-02-03 19:59:33.209583
839	915	2025-10-16	2026-10-16	0	2026-10-16	ACTIVO	1	2026-02-03 19:59:33.209583
840	916	2025-10-09	2026-10-09	0	2026-10-09	ACTIVO	1	2026-02-03 19:59:33.209583
841	917	2025-10-15	2026-10-15	0	2026-10-15	ACTIVO	1	2026-02-03 19:59:33.209583
842	918	2025-10-13	2026-10-13	0	2026-10-13	ACTIVO	1	2026-02-03 19:59:33.209583
843	919	2025-10-15	2026-10-15	0	2026-10-15	ACTIVO	1	2026-02-03 19:59:33.209583
844	921	2025-09-18	2026-09-18	0	2026-09-18	ACTIVO	1	2026-02-03 19:59:33.209583
845	922	2025-09-18	2026-09-18	0	2026-09-18	ACTIVO	1	2026-02-03 19:59:33.209583
846	923	2025-09-24	2026-09-24	0	2026-09-24	ACTIVO	1	2026-02-03 19:59:33.209583
847	924	2025-10-21	2026-10-21	0	2026-10-21	ACTIVO	1	2026-02-03 19:59:33.209583
848	925	2025-09-24	2026-09-24	0	2026-09-24	ACTIVO	1	2026-02-03 19:59:33.209583
849	926	2025-09-23	2026-09-23	0	2026-09-23	ACTIVO	1	2026-02-03 19:59:33.209583
850	927	2025-09-23	2026-09-23	0	2026-09-23	ACTIVO	1	2026-02-03 19:59:33.209583
851	928	2025-09-23	2026-09-23	0	2026-09-23	ACTIVO	1	2026-02-03 19:59:33.209583
852	929	2025-09-23	2026-09-23	0	2026-09-23	ACTIVO	1	2026-02-03 19:59:33.209583
853	930	2025-10-21	2026-10-21	0	2026-10-21	ACTIVO	1	2026-02-03 19:59:33.209583
854	931	2025-09-18	2026-09-18	0	2026-09-18	ACTIVO	1	2026-02-03 19:59:33.209583
855	932	2025-09-18	2026-09-18	0	2026-09-18	ACTIVO	1	2026-02-03 19:59:33.209583
856	934	2025-10-20	2026-10-20	0	2026-10-20	ACTIVO	1	2026-02-03 19:59:33.209583
857	935	2025-09-18	2026-09-18	0	2026-09-18	ACTIVO	1	2026-02-03 19:59:33.209583
858	936	2025-09-18	2026-09-18	0	2026-09-18	ACTIVO	1	2026-02-03 19:59:33.209583
859	937	2025-09-11	2026-09-11	0	2026-09-11	ACTIVO	1	2026-02-03 19:59:33.209583
860	938	2025-09-09	2026-09-09	0	2026-09-09	ACTIVO	1	2026-02-03 19:59:33.209583
861	939	2025-10-04	2026-10-04	0	2026-10-04	ACTIVO	1	2026-02-03 19:59:33.209583
862	940	2025-10-17	2026-10-17	0	2026-10-17	ACTIVO	1	2026-02-03 19:59:33.209583
863	941	2025-12-07	2026-12-07	0	2026-12-07	ACTIVO	1	2026-02-03 19:59:33.209583
864	942	2025-10-17	2026-10-17	0	2026-10-17	ACTIVO	1	2026-02-03 19:59:33.209583
865	943	2025-10-17	2026-10-17	0	2026-10-17	ACTIVO	1	2026-02-03 19:59:33.209583
866	944	2025-10-30	2026-10-30	0	2026-10-30	ACTIVO	1	2026-02-03 19:59:33.209583
867	946	2025-10-29	2026-10-29	0	2026-10-29	ACTIVO	1	2026-02-03 19:59:33.209583
868	947	2025-11-02	2026-11-02	0	2026-11-02	ACTIVO	1	2026-02-03 19:59:33.209583
869	948	2025-10-20	2026-10-20	0	2026-10-20	ACTIVO	1	2026-02-03 19:59:33.209583
870	949	2025-10-30	2026-10-30	0	2026-10-30	ACTIVO	1	2026-02-03 19:59:33.209583
871	951	2025-10-29	2026-10-29	0	2026-10-29	ACTIVO	1	2026-02-03 19:59:33.209583
872	952	2025-10-30	2026-10-30	0	2026-10-30	ACTIVO	1	2026-02-03 19:59:33.209583
873	953	2025-11-05	2026-11-05	0	2026-11-05	ACTIVO	1	2026-02-03 19:59:33.209583
874	954	2025-12-08	2026-12-08	0	2026-12-08	ACTIVO	1	2026-02-03 19:59:33.209583
875	955	2025-10-28	2026-10-28	0	2026-10-28	ACTIVO	1	2026-02-03 19:59:33.209583
876	956	2025-10-28	2026-10-28	0	2026-10-28	ACTIVO	1	2026-02-03 19:59:33.209583
877	957	2025-10-31	2026-10-31	0	2026-10-31	ACTIVO	1	2026-02-03 19:59:33.209583
878	958	2025-10-26	2026-10-26	0	2026-10-26	ACTIVO	1	2026-02-03 19:59:33.209583
879	959	2025-10-26	2026-10-26	0	2026-10-26	ACTIVO	1	2026-02-03 19:59:33.209583
880	960	2025-10-20	2026-10-20	0	2026-10-20	ACTIVO	1	2026-02-03 19:59:33.209583
881	961	2025-12-30	2026-12-30	0	2026-12-30	ACTIVO	1	2026-02-03 19:59:33.209583
882	963	2025-12-10	2026-12-10	0	2026-12-10	ACTIVO	1	2026-02-03 19:59:33.209583
883	964	2025-11-18	2026-11-18	0	2026-11-18	ACTIVO	1	2026-02-03 19:59:33.209583
884	965	2025-12-06	2026-12-06	0	2026-12-06	ACTIVO	1	2026-02-03 19:59:33.209583
885	967	2025-12-06	2026-12-06	0	2026-12-06	ACTIVO	1	2026-02-03 19:59:33.209583
886	969	2026-01-09	2027-01-09	0	2027-01-09	ACTIVO	1	2026-02-03 19:59:33.209583
887	970	2025-11-05	2026-11-05	0	2026-11-05	ACTIVO	1	2026-02-03 19:59:33.209583
888	971	2025-11-19	2026-11-19	0	2026-11-19	ACTIVO	1	2026-02-03 19:59:33.209583
889	972	2025-11-12	2026-11-12	0	2026-11-12	ACTIVO	1	2026-02-03 19:59:33.209583
890	973	2025-11-14	2026-11-14	0	2026-11-14	ACTIVO	1	2026-02-03 19:59:33.209583
891	974	2025-11-12	2026-11-12	0	2026-11-12	ACTIVO	1	2026-02-03 19:59:33.209583
892	975	2025-11-12	2026-11-12	0	2026-11-12	ACTIVO	1	2026-02-03 19:59:33.209583
893	976	2025-11-12	2026-11-12	0	2026-11-12	ACTIVO	1	2026-02-03 19:59:33.209583
894	977	2025-11-19	2026-11-19	0	2026-11-19	ACTIVO	1	2026-02-03 19:59:33.209583
895	978	2025-11-12	2026-11-12	0	2026-11-12	ACTIVO	1	2026-02-03 19:59:33.209583
896	979	2025-06-08	2026-06-08	0	2026-06-08	ACTIVO	1	2026-02-03 19:59:33.209583
897	980	2026-12-05	2027-12-05	0	2027-12-05	ACTIVO	1	2026-02-03 19:59:33.209583
898	981	2025-12-06	2026-12-06	0	2026-12-06	ACTIVO	1	2026-02-03 19:59:33.209583
899	982	2025-11-24	2026-11-24	0	2026-11-24	ACTIVO	1	2026-02-03 19:59:33.209583
900	983	2025-11-06	2026-11-06	0	2026-11-06	ACTIVO	1	2026-02-03 19:59:33.209583
901	984	2025-11-12	2026-11-12	0	2026-11-12	ACTIVO	1	2026-02-03 19:59:33.209583
902	985	2025-11-14	2026-11-14	0	2026-11-14	ACTIVO	1	2026-02-03 19:59:33.209583
903	986	2025-11-05	2026-11-05	0	2026-11-05	ACTIVO	1	2026-02-03 19:59:33.209583
904	987	2025-11-06	2026-11-06	0	2026-11-06	ACTIVO	1	2026-02-03 19:59:33.209583
905	988	2025-11-22	2026-11-22	0	2026-11-22	ACTIVO	1	2026-02-03 19:59:33.209583
906	989	2025-11-11	2026-11-11	0	2026-11-11	ACTIVO	1	2026-02-03 19:59:33.209583
907	990	2025-11-05	2026-11-05	0	2026-11-05	ACTIVO	1	2026-02-03 19:59:33.209583
908	991	2025-12-05	2026-12-05	0	2026-12-05	ACTIVO	1	2026-02-03 19:59:33.209583
909	992	2025-11-14	2026-11-14	0	2026-11-14	ACTIVO	1	2026-02-03 19:59:33.209583
910	993	2025-11-14	2026-11-14	0	2026-11-14	ACTIVO	1	2026-02-03 19:59:33.209583
911	994	2025-11-14	2026-11-14	0	2026-11-14	ACTIVO	1	2026-02-03 19:59:33.209583
912	995	2025-11-19	2026-11-19	0	2026-11-19	ACTIVO	1	2026-02-03 19:59:33.209583
913	996	2025-11-12	2026-11-12	0	2026-11-12	ACTIVO	1	2026-02-03 19:59:33.209583
914	997	2025-11-06	2026-11-06	0	2026-11-06	ACTIVO	1	2026-02-03 19:59:33.209583
915	998	2025-10-26	2026-10-26	0	2026-10-26	ACTIVO	1	2026-02-03 19:59:33.209583
916	999	2025-11-26	2026-11-26	0	2026-11-26	ACTIVO	1	2026-02-03 19:59:33.209583
917	1000	2025-10-26	2026-10-26	0	2026-10-26	ACTIVO	1	2026-02-03 19:59:33.209583
918	1001	2025-10-26	2026-10-26	0	2026-10-26	ACTIVO	1	2026-02-03 19:59:33.209583
919	1002	2025-10-26	2026-10-26	0	2026-10-26	ACTIVO	1	2026-02-03 19:59:33.209583
920	1003	2025-10-26	2026-10-26	0	2026-10-26	ACTIVO	1	2026-02-03 19:59:33.209583
921	1004	2025-10-26	2026-10-26	0	2026-10-26	ACTIVO	1	2026-02-03 19:59:33.209583
922	1005	2025-10-26	2026-10-26	0	2026-10-26	ACTIVO	1	2026-02-03 19:59:33.209583
923	1006	2025-11-08	2026-11-08	0	2026-11-08	ACTIVO	1	2026-02-03 19:59:33.209583
924	1007	2025-11-06	2026-11-06	0	2026-11-06	ACTIVO	1	2026-02-03 19:59:33.209583
925	1008	2025-11-11	2026-11-11	0	2026-11-11	ACTIVO	1	2026-02-03 19:59:33.209583
926	1009	2025-11-11	2026-11-11	0	2026-11-11	ACTIVO	1	2026-02-03 19:59:33.209583
927	1010	2025-11-11	2026-11-11	0	2026-11-11	ACTIVO	1	2026-02-03 19:59:33.209583
928	1013	2025-11-05	2026-11-05	0	2026-11-05	ACTIVO	1	2026-02-03 19:59:33.209583
929	1014	2025-11-09	2026-11-09	0	2026-11-09	ACTIVO	1	2026-02-03 19:59:33.209583
930	1015	2025-11-10	2026-11-10	0	2026-11-10	ACTIVO	1	2026-02-03 19:59:33.209583
931	1016	2025-12-12	2026-12-12	0	2026-12-12	ACTIVO	1	2026-02-03 19:59:33.209583
932	1017	2025-12-10	2026-12-10	0	2026-12-10	ACTIVO	1	2026-02-03 19:59:33.209583
933	1018	2025-12-10	2026-12-10	0	2026-12-10	ACTIVO	1	2026-02-03 19:59:33.209583
934	1019	2025-11-09	2026-11-09	0	2026-11-09	ACTIVO	1	2026-02-03 19:59:33.209583
935	1020	2025-12-12	2026-12-12	0	2026-12-12	ACTIVO	1	2026-02-03 19:59:33.209583
936	1022	2025-11-22	2026-11-22	0	2026-11-22	ACTIVO	1	2026-02-03 19:59:33.209583
937	1023	2025-12-05	2026-12-05	0	2026-12-05	ACTIVO	1	2026-02-03 19:59:33.209583
938	1024	2025-11-11	2026-11-11	0	2026-11-11	ACTIVO	1	2026-02-03 19:59:33.209583
939	1025	2025-12-12	2026-12-12	0	2026-12-12	ACTIVO	1	2026-02-03 19:59:33.209583
940	1026	2025-10-29	2026-10-29	0	2026-10-29	ACTIVO	1	2026-02-03 19:59:33.209583
941	1027	2025-10-29	2026-10-29	0	2026-10-29	ACTIVO	1	2026-02-03 19:59:33.209583
942	1028	2025-11-05	2026-11-05	0	2026-11-05	ACTIVO	1	2026-02-03 19:59:33.209583
943	1029	2025-11-14	2026-11-14	0	2026-11-14	ACTIVO	1	2026-02-03 19:59:33.209583
944	1030	2025-11-12	2026-11-12	0	2026-11-12	ACTIVO	1	2026-02-03 19:59:33.209583
945	1031	2025-11-26	2026-11-26	0	2026-11-26	ACTIVO	1	2026-02-03 19:59:33.209583
946	1032	2025-11-26	2026-11-26	0	2026-11-26	ACTIVO	1	2026-02-03 19:59:33.209583
947	1033	2025-11-20	2026-11-20	0	2026-11-20	ACTIVO	1	2026-02-03 19:59:33.209583
948	1034	2025-11-12	2026-11-12	0	2026-11-12	ACTIVO	1	2026-02-03 19:59:33.209583
949	1035	2025-11-14	2026-11-14	0	2026-11-14	ACTIVO	1	2026-02-03 19:59:33.209583
950	1036	2025-12-01	2026-12-01	0	2026-12-01	ACTIVO	1	2026-02-03 19:59:33.209583
951	1037	2025-12-26	2026-12-26	0	2026-12-26	ACTIVO	1	2026-02-03 19:59:33.209583
952	1038	2025-12-26	2026-12-26	0	2026-12-26	ACTIVO	1	2026-02-03 19:59:33.209583
953	1039	2025-12-27	2026-12-27	0	2026-12-27	ACTIVO	1	2026-02-03 19:59:33.209583
954	1040	2025-12-12	2026-12-12	0	2026-12-12	ACTIVO	1	2026-02-03 19:59:33.209583
955	1041	2025-12-28	2026-12-28	0	2026-12-28	ACTIVO	1	2026-02-03 19:59:33.209583
956	1042	2025-12-27	2026-12-27	0	2026-12-27	ACTIVO	1	2026-02-03 19:59:33.209583
957	1043	2025-12-26	2026-12-26	0	2026-12-26	ACTIVO	1	2026-02-03 19:59:33.209583
958	1044	2025-12-26	2026-12-26	0	2026-12-26	ACTIVO	1	2026-02-03 19:59:33.209583
959	1045	2025-12-27	2026-12-27	0	2026-12-27	ACTIVO	1	2026-02-03 19:59:33.209583
960	1046	2025-12-27	2026-12-27	0	2026-12-27	ACTIVO	1	2026-02-03 19:59:33.209583
961	1047	2025-12-11	2026-12-11	0	2026-12-11	ACTIVO	1	2026-02-03 19:59:33.209583
962	1048	2025-12-30	2026-12-30	0	2026-12-30	ACTIVO	1	2026-02-03 19:59:33.209583
963	1049	2025-12-12	2026-12-12	0	2026-12-12	ACTIVO	1	2026-02-03 19:59:33.209583
964	1050	2026-01-02	2027-01-02	0	2027-01-02	ACTIVO	1	2026-02-03 19:59:33.209583
965	1051	2025-12-16	2026-12-16	0	2026-12-16	ACTIVO	1	2026-02-03 19:59:33.209583
966	1052	2026-01-02	2027-01-02	0	2027-01-02	ACTIVO	1	2026-02-03 19:59:33.209583
967	1053	2025-12-27	2026-12-27	0	2026-12-27	ACTIVO	1	2026-02-03 19:59:33.209583
968	1054	2025-12-16	2026-12-16	0	2026-12-16	ACTIVO	1	2026-02-03 19:59:33.209583
969	1055	2025-12-16	2026-12-16	0	2026-12-16	ACTIVO	1	2026-02-03 19:59:33.209583
970	1056	2025-12-30	2026-12-30	0	2026-12-30	ACTIVO	1	2026-02-03 19:59:33.209583
971	1059	2025-12-26	2026-12-26	0	2026-12-26	ACTIVO	1	2026-02-03 19:59:33.209583
972	1061	2025-12-11	2026-12-11	0	2026-12-11	ACTIVO	1	2026-02-03 19:59:33.209583
973	1062	2026-01-05	2027-01-05	0	2027-01-05	ACTIVO	1	2026-02-03 19:59:33.209583
974	1063	2025-12-18	2026-12-18	0	2026-12-18	ACTIVO	1	2026-02-03 19:59:33.209583
975	1064	2025-12-12	2026-12-12	0	2026-12-12	ACTIVO	1	2026-02-03 19:59:33.209583
976	1065	2026-01-05	2027-01-05	0	2027-01-05	ACTIVO	1	2026-02-03 19:59:33.209583
977	1066	2025-12-27	2026-12-27	0	2026-12-27	ACTIVO	1	2026-02-03 19:59:33.209583
978	1067	2025-12-26	2026-12-26	0	2026-12-26	ACTIVO	1	2026-02-03 19:59:33.209583
979	1068	2025-12-27	2026-12-27	0	2026-12-27	ACTIVO	1	2026-02-03 19:59:33.209583
980	1069	2026-01-03	2027-01-03	0	2027-01-03	ACTIVO	1	2026-02-03 19:59:33.209583
981	1070	2025-12-30	2026-12-30	0	2026-12-30	ACTIVO	1	2026-02-03 19:59:33.209583
982	1071	2026-01-03	2027-01-03	0	2027-01-03	ACTIVO	1	2026-02-03 19:59:33.209583
983	1072	2025-12-29	2026-12-29	0	2026-12-29	ACTIVO	1	2026-02-03 19:59:33.209583
984	1073	2025-12-30	2026-12-30	0	2026-12-30	ACTIVO	1	2026-02-03 19:59:33.209583
985	1074	2025-12-29	2026-12-29	0	2026-12-29	ACTIVO	1	2026-02-03 19:59:33.209583
986	1077	2026-01-13	2027-01-13	0	2027-01-13	ACTIVO	1	2026-02-03 19:59:33.209583
987	1082	2025-12-30	2026-12-30	0	2026-12-30	ACTIVO	1	2026-02-03 19:59:33.209583
988	1084	2026-01-01	2027-01-01	0	2027-01-01	ACTIVO	1	2026-02-03 19:59:33.209583
989	1085	2026-01-03	2027-01-03	0	2027-01-03	ACTIVO	1	2026-02-03 19:59:33.209583
990	1089	2026-01-03	2027-01-03	0	2027-01-03	ACTIVO	1	2026-02-03 19:59:33.209583
991	1096	2025-12-30	2026-12-30	0	2026-12-30	ACTIVO	1	2026-02-03 19:59:33.209583
992	1097	2025-12-29	2026-12-29	0	2026-12-29	ACTIVO	1	2026-02-03 19:59:33.209583
993	1098	2026-01-08	2027-01-08	0	2027-01-08	ACTIVO	1	2026-02-03 19:59:33.209583
994	1099	2026-01-10	2027-01-10	0	2027-01-10	ACTIVO	1	2026-02-03 19:59:33.209583
995	1100	2026-01-08	2027-01-08	0	2027-01-08	ACTIVO	1	2026-02-03 19:59:33.209583
996	1102	2026-01-10	2027-01-10	0	2027-01-10	ACTIVO	1	2026-02-03 19:59:33.209583
997	1103	2026-01-08	2027-01-08	0	2027-01-08	ACTIVO	1	2026-02-03 19:59:33.209583
998	1104	2025-12-29	2026-12-29	0	2026-12-29	ACTIVO	1	2026-02-03 19:59:33.209583
999	1105	2026-01-14	2027-01-14	0	2027-01-14	ACTIVO	1	2026-02-03 19:59:33.209583
1000	1106	2026-01-14	2027-01-14	0	2027-01-14	ACTIVO	1	2026-02-03 19:59:33.209583
1001	1107	2026-01-14	2027-01-14	0	2027-01-14	ACTIVO	1	2026-02-03 19:59:33.209583
1002	1108	2026-01-14	2027-01-14	0	2027-01-14	ACTIVO	1	2026-02-03 19:59:33.209583
1003	1109	2026-01-14	2027-01-14	0	2027-01-14	ACTIVO	1	2026-02-03 19:59:33.209583
1004	1110	2026-01-14	2027-01-14	0	2027-01-14	ACTIVO	1	2026-02-03 19:59:33.209583
1	1	2025-02-12	2026-02-12	0	2026-02-12	POR_VENCER	1	2026-02-03 19:59:33.209583
2	2	2023-10-17	2024-10-16	0	2024-10-16	VENCIDO	1	2026-02-03 19:59:33.209583
3	3	2024-01-30	2025-01-29	0	2025-01-29	VENCIDO	1	2026-02-03 19:59:33.209583
4	4	2024-02-01	2025-01-31	0	2025-01-31	VENCIDO	1	2026-02-03 19:59:33.209583
5	5	2024-08-03	2025-08-03	0	2025-08-03	VENCIDO	1	2026-02-03 19:59:33.209583
6	6	2023-07-26	2024-07-25	0	2024-07-25	VENCIDO	1	2026-02-03 19:59:33.209583
7	7	2024-01-26	2025-01-25	0	2025-01-25	VENCIDO	1	2026-02-03 19:59:33.209583
8	8	2023-12-06	2024-12-05	0	2024-12-05	VENCIDO	1	2026-02-03 19:59:33.209583
9	9	2023-11-20	2024-11-19	0	2024-11-19	VENCIDO	1	2026-02-03 19:59:33.209583
10	10	2025-01-28	2026-01-28	0	2026-01-28	VENCIDO	1	2026-02-03 19:59:33.209583
11	11	2024-07-20	2025-07-20	0	2025-07-20	VENCIDO	1	2026-02-03 19:59:33.209583
12	12	2023-11-15	2024-11-14	0	2024-11-14	VENCIDO	1	2026-02-03 19:59:33.209583
13	13	2024-05-13	2025-05-13	0	2025-05-13	VENCIDO	1	2026-02-03 19:59:33.209583
14	14	2023-12-03	2024-12-02	0	2024-12-02	VENCIDO	1	2026-02-03 19:59:33.209583
15	15	2025-02-05	2026-02-05	0	2026-02-05	POR_VENCER	1	2026-02-03 19:59:33.209583
16	16	2023-12-11	2024-12-10	0	2024-12-10	VENCIDO	1	2026-02-03 19:59:33.209583
17	17	2023-12-11	2024-12-10	0	2024-12-10	VENCIDO	1	2026-02-03 19:59:33.209583
18	18	2024-01-20	2025-01-19	0	2025-01-19	VENCIDO	1	2026-02-03 19:59:33.209583
19	19	2023-10-23	2024-10-22	0	2024-10-22	VENCIDO	1	2026-02-03 19:59:33.209583
20	20	2023-10-21	2024-10-20	0	2024-10-20	VENCIDO	1	2026-02-03 19:59:33.209583
21	21	2023-11-30	2024-11-29	0	2024-11-29	VENCIDO	1	2026-02-03 19:59:33.209583
22	22	2025-01-02	2026-01-02	0	2026-01-02	VENCIDO	1	2026-02-03 19:59:33.209583
23	23	2023-10-13	2024-10-12	0	2024-10-12	VENCIDO	1	2026-02-03 19:59:33.209583
24	24	2023-11-22	2024-11-21	0	2024-11-21	VENCIDO	1	2026-02-03 19:59:33.209583
25	25	2024-01-19	2025-01-18	0	2025-01-18	VENCIDO	1	2026-02-03 19:59:33.209583
26	26	2025-02-10	2026-02-10	0	2026-02-10	POR_VENCER	1	2026-02-03 19:59:33.209583
27	27	2024-02-29	2025-02-28	0	2025-02-28	VENCIDO	1	2026-02-03 19:59:33.209583
28	28	2023-12-11	2024-12-10	0	2024-12-10	VENCIDO	1	2026-02-03 19:59:33.209583
29	29	2024-06-12	2025-06-12	0	2025-06-12	VENCIDO	1	2026-02-03 19:59:33.209583
30	30	2023-12-11	2024-12-10	0	2024-12-10	VENCIDO	1	2026-02-03 19:59:33.209583
31	31	2023-11-20	2024-11-19	0	2024-11-19	VENCIDO	1	2026-02-03 19:59:33.209583
32	32	2025-01-28	2026-01-28	0	2026-01-28	VENCIDO	1	2026-02-03 19:59:33.209583
33	33	2024-02-07	2025-02-06	0	2025-02-06	VENCIDO	1	2026-02-03 19:59:33.209583
34	34	2023-12-31	2024-12-30	0	2024-12-30	VENCIDO	1	2026-02-03 19:59:33.209583
35	35	2025-02-12	2026-02-12	0	2026-02-12	POR_VENCER	1	2026-02-03 19:59:33.209583
36	36	2024-06-07	2025-06-07	0	2025-06-07	VENCIDO	1	2026-02-03 19:59:33.209583
37	37	2024-05-13	2025-05-13	0	2025-05-13	VENCIDO	1	2026-02-03 19:59:33.209583
38	38	2023-10-18	2024-10-17	0	2024-10-17	VENCIDO	1	2026-02-03 19:59:33.209583
39	39	2025-01-03	2026-01-03	0	2026-01-03	VENCIDO	1	2026-02-03 19:59:33.209583
40	40	2024-04-18	2025-04-18	0	2025-04-18	VENCIDO	1	2026-02-03 19:59:33.209583
41	41	2023-10-25	2024-10-24	0	2024-10-24	VENCIDO	1	2026-02-03 19:59:33.209583
42	42	2024-07-01	2025-07-01	0	2025-07-01	VENCIDO	1	2026-02-03 19:59:33.209583
43	43	2023-08-20	2024-08-19	0	2024-08-19	VENCIDO	1	2026-02-03 19:59:33.209583
44	44	2023-10-18	2024-10-17	0	2024-10-17	VENCIDO	1	2026-02-03 19:59:33.209583
45	45	2024-03-05	2025-03-05	0	2025-03-05	VENCIDO	1	2026-02-03 19:59:33.209583
46	46	2023-08-22	2024-08-21	0	2024-08-21	VENCIDO	1	2026-02-03 19:59:33.209583
47	47	2023-10-18	2024-10-17	0	2024-10-17	VENCIDO	1	2026-02-03 19:59:33.209583
48	48	2023-11-25	2024-11-24	0	2024-11-24	VENCIDO	1	2026-02-03 19:59:33.209583
49	49	2024-04-30	2025-04-30	0	2025-04-30	VENCIDO	1	2026-02-03 19:59:33.209583
50	50	2023-10-31	2024-10-30	0	2024-10-30	VENCIDO	1	2026-02-03 19:59:33.209583
51	51	2024-05-13	2025-05-13	0	2025-05-13	VENCIDO	1	2026-02-03 19:59:33.209583
52	52	2025-01-20	2026-01-20	0	2026-01-20	VENCIDO	1	2026-02-03 19:59:33.209583
53	54	2025-02-01	2026-02-01	0	2026-02-01	VENCIDO	1	2026-02-03 19:59:33.209583
54	55	2023-08-20	2024-08-19	0	2024-08-19	VENCIDO	1	2026-02-03 19:59:33.209583
55	56	2024-06-09	2025-06-09	0	2025-06-09	VENCIDO	1	2026-02-03 19:59:33.209583
56	57	2025-02-10	2026-02-10	0	2026-02-10	POR_VENCER	1	2026-02-03 19:59:33.209583
57	58	2023-08-30	2024-08-29	0	2024-08-29	VENCIDO	1	2026-02-03 19:59:33.209583
58	59	2025-01-28	2026-01-28	0	2026-01-28	VENCIDO	1	2026-02-03 19:59:33.209583
59	60	2023-12-14	2024-12-13	0	2024-12-13	VENCIDO	1	2026-02-03 19:59:33.209583
60	61	2024-03-18	2025-03-18	0	2025-03-18	VENCIDO	1	2026-02-03 19:59:33.209583
61	62	2024-06-09	2025-06-09	0	2025-06-09	VENCIDO	1	2026-02-03 19:59:33.209583
62	63	2024-02-24	2025-02-23	0	2025-02-23	VENCIDO	1	2026-02-03 19:59:33.209583
63	64	2023-10-18	2024-10-17	0	2024-10-17	VENCIDO	1	2026-02-03 19:59:33.209583
64	65	2024-01-09	2025-01-08	0	2025-01-08	VENCIDO	1	2026-02-03 19:59:33.209583
65	66	2023-09-18	2024-09-17	0	2024-09-17	VENCIDO	1	2026-02-03 19:59:33.209583
66	67	2025-01-28	2026-01-28	0	2026-01-28	VENCIDO	1	2026-02-03 19:59:33.209583
67	68	2025-01-20	2026-01-20	0	2026-01-20	VENCIDO	1	2026-02-03 19:59:33.209583
68	69	2023-11-04	2024-11-03	0	2024-11-03	VENCIDO	1	2026-02-03 19:59:33.209583
69	70	2023-10-21	2024-10-20	0	2024-10-20	VENCIDO	1	2026-02-03 19:59:33.209583
70	71	2024-01-09	2025-01-08	0	2025-01-08	VENCIDO	1	2026-02-03 19:59:33.209583
71	72	2025-01-20	2026-01-20	0	2026-01-20	VENCIDO	1	2026-02-03 19:59:33.209583
72	73	2025-02-10	2026-02-10	0	2026-02-10	POR_VENCER	1	2026-02-03 19:59:33.209583
73	74	2023-11-30	2024-11-29	0	2024-11-29	VENCIDO	1	2026-02-03 19:59:33.209583
74	75	2023-10-23	2024-10-22	0	2024-10-22	VENCIDO	1	2026-02-03 19:59:33.209583
75	76	2024-01-09	2025-01-08	0	2025-01-08	VENCIDO	1	2026-02-03 19:59:33.209583
76	77	2023-08-08	2024-08-07	0	2024-08-07	VENCIDO	1	2026-02-03 19:59:33.209583
77	78	2023-12-12	2024-12-11	0	2024-12-11	VENCIDO	1	2026-02-03 19:59:33.209583
78	79	2024-02-28	2025-02-27	0	2025-02-27	VENCIDO	1	2026-02-03 19:59:33.209583
79	80	2023-12-07	2024-12-06	0	2024-12-06	VENCIDO	1	2026-02-03 19:59:33.209583
80	81	2025-02-04	2026-02-04	0	2026-02-04	POR_VENCER	1	2026-02-03 19:59:33.209583
81	82	2024-03-18	2025-03-18	0	2025-03-18	VENCIDO	1	2026-02-03 19:59:33.209583
82	83	2023-10-18	2024-10-17	0	2024-10-17	VENCIDO	1	2026-02-03 19:59:33.209583
83	84	2025-01-30	2026-01-30	0	2026-01-30	VENCIDO	1	2026-02-03 19:59:33.209583
84	85	2024-06-12	2025-06-12	0	2025-06-12	VENCIDO	1	2026-02-03 19:59:33.209583
85	86	2023-10-23	2024-10-22	0	2024-10-22	VENCIDO	1	2026-02-03 19:59:33.209583
86	87	2023-08-06	2024-08-05	0	2024-08-05	VENCIDO	1	2026-02-03 19:59:33.209583
87	88	2024-01-30	2025-01-29	0	2025-01-29	VENCIDO	1	2026-02-03 19:59:33.209583
88	89	2024-02-02	2025-02-01	0	2025-02-01	VENCIDO	1	2026-02-03 19:59:33.209583
89	90	2024-01-09	2025-01-08	0	2025-01-08	VENCIDO	1	2026-02-03 19:59:33.209583
90	91	2023-07-21	2024-07-20	0	2024-07-20	VENCIDO	1	2026-02-03 19:59:33.209583
91	92	2024-04-30	2025-04-30	0	2025-04-30	VENCIDO	1	2026-02-03 19:59:33.209583
92	93	2023-11-08	2024-11-07	0	2024-11-07	VENCIDO	1	2026-02-03 19:59:33.209583
93	94	2024-04-16	2025-04-16	0	2025-04-16	VENCIDO	1	2026-02-03 19:59:33.209583
94	95	2025-02-13	2026-02-13	0	2026-02-13	POR_VENCER	1	2026-02-03 19:59:33.209583
95	96	2023-11-11	2024-11-10	0	2024-11-10	VENCIDO	1	2026-02-03 19:59:33.209583
96	97	2023-10-18	2024-10-17	0	2024-10-17	VENCIDO	1	2026-02-03 19:59:33.209583
97	98	2024-01-16	2025-01-15	0	2025-01-15	VENCIDO	1	2026-02-03 19:59:33.209583
98	99	2024-01-20	2025-01-19	0	2025-01-19	VENCIDO	1	2026-02-03 19:59:33.209583
99	100	2024-02-24	2025-02-23	0	2025-02-23	VENCIDO	1	2026-02-03 19:59:33.209583
100	101	2024-06-12	2025-06-12	0	2025-06-12	VENCIDO	1	2026-02-03 19:59:33.209583
101	102	2023-07-04	2024-07-03	0	2024-07-03	VENCIDO	1	2026-02-03 19:59:33.209583
102	103	2023-11-29	2024-11-28	0	2024-11-28	VENCIDO	1	2026-02-03 19:59:33.209583
103	104	2025-02-05	2026-02-05	0	2026-02-05	POR_VENCER	1	2026-02-03 19:59:33.209583
104	105	2023-12-28	2024-12-27	0	2024-12-27	VENCIDO	1	2026-02-03 19:59:33.209583
105	106	2023-10-13	2024-10-12	0	2024-10-12	VENCIDO	1	2026-02-03 19:59:33.209583
106	107	2023-09-07	2024-09-06	0	2024-09-06	VENCIDO	1	2026-02-03 19:59:33.209583
107	108	2025-01-28	2026-01-28	0	2026-01-28	VENCIDO	1	2026-02-03 19:59:33.209583
108	109	2024-04-30	2025-04-30	0	2025-04-30	VENCIDO	1	2026-02-03 19:59:33.209583
109	110	2023-10-25	2024-10-24	0	2024-10-24	VENCIDO	1	2026-02-03 19:59:33.209583
110	111	2024-03-24	2025-03-24	0	2025-03-24	VENCIDO	1	2026-02-03 19:59:33.209583
111	112	2023-10-31	2024-10-30	0	2024-10-30	VENCIDO	1	2026-02-03 19:59:33.209583
112	113	2023-07-31	2024-07-30	0	2024-07-30	VENCIDO	1	2026-02-03 19:59:33.209583
113	114	2025-01-06	2026-01-06	0	2026-01-06	VENCIDO	1	2026-02-03 19:59:33.209583
114	115	2023-10-18	2024-10-17	0	2024-10-17	VENCIDO	1	2026-02-03 19:59:33.209583
115	116	2023-11-09	2024-11-08	0	2024-11-08	VENCIDO	1	2026-02-03 19:59:33.209583
116	117	2023-11-29	2024-11-28	0	2024-11-28	VENCIDO	1	2026-02-03 19:59:33.209583
117	118	2024-06-07	2025-06-07	0	2025-06-07	VENCIDO	1	2026-02-03 19:59:33.209583
118	119	2024-05-21	2025-05-21	0	2025-05-21	VENCIDO	1	2026-02-03 19:59:33.209583
119	120	2024-05-25	2025-05-25	0	2025-05-25	VENCIDO	1	2026-02-03 19:59:33.209583
120	121	2023-10-18	2024-10-17	0	2024-10-17	VENCIDO	1	2026-02-03 19:59:33.209583
121	122	2025-01-20	2026-01-20	0	2026-01-20	VENCIDO	1	2026-02-03 19:59:33.209583
122	123	2023-07-23	2024-07-22	0	2024-07-22	VENCIDO	1	2026-02-03 19:59:33.209583
123	124	2024-05-03	2025-05-03	0	2025-05-03	VENCIDO	1	2026-02-03 19:59:33.209583
124	125	2024-01-09	2025-01-08	0	2025-01-08	VENCIDO	1	2026-02-03 19:59:33.209583
125	126	2024-02-01	2025-01-31	0	2025-01-31	VENCIDO	1	2026-02-03 19:59:33.209583
126	127	2023-10-23	2024-10-22	0	2024-10-22	VENCIDO	1	2026-02-03 19:59:33.209583
127	128	2024-01-09	2025-01-08	0	2025-01-08	VENCIDO	1	2026-02-03 19:59:33.209583
128	129	2024-01-30	2025-01-29	0	2025-01-29	VENCIDO	1	2026-02-03 19:59:33.209583
129	130	2023-08-06	2024-08-05	0	2024-08-05	VENCIDO	1	2026-02-03 19:59:33.209583
130	131	2024-04-30	2025-04-30	0	2025-04-30	VENCIDO	1	2026-02-03 19:59:33.209583
131	132	2023-10-20	2024-10-19	0	2024-10-19	VENCIDO	1	2026-02-03 19:59:33.209583
132	133	2023-07-27	2024-07-26	0	2024-07-26	VENCIDO	1	2026-02-03 19:59:33.209583
133	134	2025-01-09	2026-01-09	0	2026-01-09	VENCIDO	1	2026-02-03 19:59:33.209583
134	135	2023-09-21	2024-09-20	0	2024-09-20	VENCIDO	1	2026-02-03 19:59:33.209583
135	136	2023-12-11	2024-12-10	0	2024-12-10	VENCIDO	1	2026-02-03 19:59:33.209583
136	137	2024-01-19	2025-01-18	0	2025-01-18	VENCIDO	1	2026-02-03 19:59:33.209583
137	138	2024-06-04	2025-06-04	0	2025-06-04	VENCIDO	1	2026-02-03 19:59:33.209583
138	139	2023-12-12	2024-12-11	0	2024-12-11	VENCIDO	1	2026-02-03 19:59:33.209583
139	140	2023-10-21	2024-10-20	0	2024-10-20	VENCIDO	1	2026-02-03 19:59:33.209583
140	141	2025-01-30	2026-01-30	0	2026-01-30	VENCIDO	1	2026-02-03 19:59:33.209583
141	142	2023-10-31	2024-10-30	0	2024-10-30	VENCIDO	1	2026-02-03 19:59:33.209583
142	143	2023-11-15	2024-11-14	0	2024-11-14	VENCIDO	1	2026-02-03 19:59:33.209583
143	144	2024-05-13	2025-05-13	0	2025-05-13	VENCIDO	1	2026-02-03 19:59:33.209583
144	145	2023-07-04	2024-07-03	0	2024-07-03	VENCIDO	1	2026-02-03 19:59:33.209583
145	147	2025-01-19	2026-01-19	0	2026-01-19	VENCIDO	1	2026-02-03 19:59:33.209583
146	148	2024-01-01	2024-12-31	0	2024-12-31	VENCIDO	1	2026-02-03 19:59:33.209583
147	149	2024-02-25	2025-02-24	0	2025-02-24	VENCIDO	1	2026-02-03 19:59:33.209583
148	150	2023-10-23	2024-10-22	0	2024-10-22	VENCIDO	1	2026-02-03 19:59:33.209583
149	151	2023-11-22	2024-11-21	0	2024-11-21	VENCIDO	1	2026-02-03 19:59:33.209583
150	152	2024-05-25	2025-05-25	0	2025-05-25	VENCIDO	1	2026-02-03 19:59:33.209583
151	153	2023-09-11	2024-09-10	0	2024-09-10	VENCIDO	1	2026-02-03 19:59:33.209583
152	154	2024-03-30	2025-03-30	0	2025-03-30	VENCIDO	1	2026-02-03 19:59:33.209583
153	155	2023-12-18	2024-12-17	0	2024-12-17	VENCIDO	1	2026-02-03 19:59:33.209583
154	156	2023-11-22	2024-11-21	0	2024-11-21	VENCIDO	1	2026-02-03 19:59:33.209583
155	157	2023-10-20	2024-10-19	0	2024-10-19	VENCIDO	1	2026-02-03 19:59:33.209583
156	158	2024-06-12	2025-06-12	0	2025-06-12	VENCIDO	1	2026-02-03 19:59:33.209583
157	159	2023-11-22	2024-11-21	0	2024-11-21	VENCIDO	1	2026-02-03 19:59:33.209583
158	160	2025-02-11	2026-02-11	0	2026-02-11	POR_VENCER	1	2026-02-03 19:59:33.209583
159	161	2023-08-30	2024-08-29	0	2024-08-29	VENCIDO	1	2026-02-03 19:59:33.209583
160	162	2025-01-28	2026-01-28	0	2026-01-28	VENCIDO	1	2026-02-03 19:59:33.209583
161	163	2024-02-28	2025-02-27	0	2025-02-27	VENCIDO	1	2026-02-03 19:59:33.209583
162	164	2024-06-09	2025-06-09	0	2025-06-09	VENCIDO	1	2026-02-03 19:59:33.209583
163	165	2023-12-05	2024-12-04	0	2024-12-04	VENCIDO	1	2026-02-03 19:59:33.209583
164	166	2023-10-21	2024-10-20	0	2024-10-20	VENCIDO	1	2026-02-03 19:59:33.209583
165	167	2024-02-27	2025-02-26	0	2025-02-26	VENCIDO	1	2026-02-03 19:59:33.209583
166	168	2023-11-22	2024-11-21	0	2024-11-21	VENCIDO	1	2026-02-03 19:59:33.209583
167	170	2023-10-27	2024-10-26	0	2024-10-26	VENCIDO	1	2026-02-03 19:59:33.209583
168	171	2023-10-18	2024-10-17	0	2024-10-17	VENCIDO	1	2026-02-03 19:59:33.209583
169	172	2024-02-08	2025-02-07	0	2025-02-07	VENCIDO	1	2026-02-03 19:59:33.209583
170	173	2024-05-24	2025-05-24	0	2025-05-24	VENCIDO	1	2026-02-03 19:59:33.209583
171	175	2025-02-02	2026-02-02	0	2026-02-02	VENCIDO	1	2026-02-03 19:59:33.209583
172	176	2024-02-07	2025-02-06	0	2025-02-06	VENCIDO	1	2026-02-03 19:59:33.209583
173	177	2024-06-17	2025-06-17	0	2025-06-17	VENCIDO	1	2026-02-03 19:59:33.209583
174	178	2023-09-07	2024-09-06	0	2024-09-06	VENCIDO	1	2026-02-03 19:59:33.209583
175	179	2025-01-28	2026-01-28	0	2026-01-28	VENCIDO	1	2026-02-03 19:59:33.209583
176	180	2023-07-26	2024-07-25	0	2024-07-25	VENCIDO	1	2026-02-03 19:59:33.209583
177	181	2023-09-28	2024-09-27	0	2024-09-27	VENCIDO	1	2026-02-03 19:59:33.209583
178	182	2023-07-09	2024-07-08	0	2024-07-08	VENCIDO	1	2026-02-03 19:59:33.209583
179	183	2025-02-20	2026-02-20	0	2026-02-20	POR_VENCER	1	2026-02-03 19:59:33.209583
180	184	2024-02-27	2025-02-26	0	2025-02-26	VENCIDO	1	2026-02-03 19:59:33.209583
181	185	2024-08-04	2025-08-04	0	2025-08-04	VENCIDO	1	2026-02-03 19:59:33.209583
182	186	2023-08-12	2024-08-11	0	2024-08-11	VENCIDO	1	2026-02-03 19:59:33.209583
183	187	2024-01-20	2025-01-19	0	2025-01-19	VENCIDO	1	2026-02-03 19:59:33.209583
184	188	2024-03-18	2025-03-18	0	2025-03-18	VENCIDO	1	2026-02-03 19:59:33.209583
185	189	2023-11-25	2024-11-24	0	2024-11-24	VENCIDO	1	2026-02-03 19:59:33.209583
186	190	2025-01-02	2026-01-02	0	2026-01-02	VENCIDO	1	2026-02-03 19:59:33.209583
187	191	2024-01-31	2025-01-30	0	2025-01-30	VENCIDO	1	2026-02-03 19:59:33.209583
188	192	2024-02-24	2025-02-23	0	2025-02-23	VENCIDO	1	2026-02-03 19:59:33.209583
189	193	2024-01-19	2025-01-18	0	2025-01-18	VENCIDO	1	2026-02-03 19:59:33.209583
190	194	2025-01-08	2026-01-08	0	2026-01-08	VENCIDO	1	2026-02-03 19:59:33.209583
191	195	2023-11-11	2024-11-10	0	2024-11-10	VENCIDO	1	2026-02-03 19:59:33.209583
192	196	2023-10-21	2024-10-20	0	2024-10-20	VENCIDO	1	2026-02-03 19:59:33.209583
193	197	2023-10-31	2024-10-30	0	2024-10-30	VENCIDO	1	2026-02-03 19:59:33.209583
194	198	2023-07-26	2024-07-25	0	2024-07-25	VENCIDO	1	2026-02-03 19:59:33.209583
195	199	2023-12-05	2024-12-04	0	2024-12-04	VENCIDO	1	2026-02-03 19:59:33.209583
196	200	2024-02-08	2025-02-07	0	2025-02-07	VENCIDO	1	2026-02-03 19:59:33.209583
197	201	2025-01-31	2026-01-31	0	2026-01-31	VENCIDO	1	2026-02-03 19:59:33.209583
198	202	2023-10-29	2024-10-28	0	2024-10-28	VENCIDO	1	2026-02-03 19:59:33.209583
199	203	2023-08-28	2024-08-27	0	2024-08-27	VENCIDO	1	2026-02-03 19:59:33.209583
200	204	2025-02-03	2026-02-03	0	2026-02-03	VENCIDO	1	2026-02-03 19:59:33.209583
201	205	2025-01-09	2026-01-09	0	2026-01-09	VENCIDO	1	2026-02-03 19:59:33.209583
202	206	2024-05-03	2025-05-03	0	2025-05-03	VENCIDO	1	2026-02-03 19:59:33.209583
203	208	2024-06-09	2025-06-09	0	2025-06-09	VENCIDO	1	2026-02-03 19:59:33.209583
204	209	2023-08-21	2024-08-20	0	2024-08-20	VENCIDO	1	2026-02-03 19:59:33.209583
205	211	2025-02-04	2026-02-04	0	2026-02-04	POR_VENCER	1	2026-02-03 19:59:33.209583
206	212	2025-01-20	2026-01-20	0	2026-01-20	VENCIDO	1	2026-02-03 19:59:33.209583
207	213	2024-02-29	2025-02-28	0	2025-02-28	VENCIDO	1	2026-02-03 19:59:33.209583
208	214	2023-11-02	2024-11-01	0	2024-11-01	VENCIDO	1	2026-02-03 19:59:33.209583
209	215	2024-06-03	2025-06-03	0	2025-06-03	VENCIDO	1	2026-02-03 19:59:33.209583
210	216	2024-02-09	2025-02-08	0	2025-02-08	VENCIDO	1	2026-02-03 19:59:33.209583
211	217	2024-01-23	2025-01-22	0	2025-01-22	VENCIDO	1	2026-02-03 19:59:33.209583
212	218	2024-03-06	2025-03-06	0	2025-03-06	VENCIDO	1	2026-02-03 19:59:33.209583
213	219	2023-08-08	2024-08-07	0	2024-08-07	VENCIDO	1	2026-02-03 19:59:33.209583
214	220	2024-02-02	2025-02-01	0	2025-02-01	VENCIDO	1	2026-02-03 19:59:33.209583
215	221	2024-04-30	2025-04-30	0	2025-04-30	VENCIDO	1	2026-02-03 19:59:33.209583
216	222	2023-12-31	2024-12-30	0	2024-12-30	VENCIDO	1	2026-02-03 19:59:33.209583
217	224	2025-02-03	2026-02-03	0	2026-02-03	VENCIDO	1	2026-02-03 19:59:33.209583
218	225	2025-02-13	2026-02-13	0	2026-02-13	POR_VENCER	1	2026-02-03 19:59:33.209583
219	226	2024-02-27	2025-02-26	0	2025-02-26	VENCIDO	1	2026-02-03 19:59:33.209583
220	227	2025-01-20	2026-01-20	0	2026-01-20	VENCIDO	1	2026-02-03 19:59:33.209583
221	228	2023-11-11	2024-11-10	0	2024-11-10	VENCIDO	1	2026-02-03 19:59:33.209583
222	229	2024-03-06	2025-03-06	0	2025-03-06	VENCIDO	1	2026-02-03 19:59:33.209583
223	230	2023-11-26	2024-11-25	0	2024-11-25	VENCIDO	1	2026-02-03 19:59:33.209583
224	231	2025-02-05	2026-02-05	0	2026-02-05	POR_VENCER	1	2026-02-03 19:59:33.209583
225	232	2024-05-27	2025-05-27	0	2025-05-27	VENCIDO	1	2026-02-03 19:59:33.209583
226	233	2025-01-28	2026-01-28	0	2026-01-28	VENCIDO	1	2026-02-03 19:59:33.209583
227	234	2023-11-29	2024-11-28	0	2024-11-28	VENCIDO	1	2026-02-03 19:59:33.209583
228	235	2025-01-27	2026-01-27	0	2026-01-27	VENCIDO	1	2026-02-03 19:59:33.209583
229	236	2023-10-18	2024-10-17	0	2024-10-17	VENCIDO	1	2026-02-03 19:59:33.209583
230	237	2025-01-03	2026-01-03	0	2026-01-03	VENCIDO	1	2026-02-03 19:59:33.209583
231	238	2024-03-27	2025-03-27	0	2025-03-27	VENCIDO	1	2026-02-03 19:59:33.209583
232	239	2025-01-03	2026-01-03	0	2026-01-03	VENCIDO	1	2026-02-03 19:59:33.209583
233	240	2023-12-05	2024-12-04	0	2024-12-04	VENCIDO	1	2026-02-03 19:59:33.209583
234	241	2024-02-01	2025-01-31	0	2025-01-31	VENCIDO	1	2026-02-03 19:59:33.209583
235	242	2024-02-21	2025-02-20	0	2025-02-20	VENCIDO	1	2026-02-03 19:59:33.209583
236	243	2024-04-19	2025-04-19	0	2025-04-19	VENCIDO	1	2026-02-03 19:59:33.209583
237	244	2024-04-16	2025-04-16	0	2025-04-16	VENCIDO	1	2026-02-03 19:59:33.209583
238	245	2024-03-30	2025-03-30	0	2025-03-30	VENCIDO	1	2026-02-03 19:59:33.209583
239	246	2023-08-30	2024-08-29	0	2024-08-29	VENCIDO	1	2026-02-03 19:59:33.209583
240	247	2025-01-28	2026-01-28	0	2026-01-28	VENCIDO	1	2026-02-03 19:59:33.209583
241	249	2023-10-23	2024-10-22	0	2024-10-22	VENCIDO	1	2026-02-03 19:59:33.209583
242	250	2023-12-14	2024-12-13	0	2024-12-13	VENCIDO	1	2026-02-03 19:59:33.209583
243	251	2024-02-02	2025-02-01	0	2025-02-01	VENCIDO	1	2026-02-03 19:59:33.209583
244	252	2025-01-28	2026-01-28	0	2026-01-28	VENCIDO	1	2026-02-03 19:59:33.209583
245	254	2024-03-17	2025-03-17	0	2025-03-17	VENCIDO	1	2026-02-03 19:59:33.209583
246	255	2023-12-31	2024-12-30	0	2024-12-30	VENCIDO	1	2026-02-03 19:59:33.209583
247	256	2023-08-06	2024-08-05	0	2024-08-05	VENCIDO	1	2026-02-03 19:59:33.209583
248	257	2023-09-18	2024-09-17	0	2024-09-17	VENCIDO	1	2026-02-03 19:59:33.209583
249	258	2025-01-28	2026-01-28	0	2026-01-28	VENCIDO	1	2026-02-03 19:59:33.209583
250	259	2025-02-11	2026-02-11	0	2026-02-11	POR_VENCER	1	2026-02-03 19:59:33.209583
251	260	2023-09-21	2024-09-20	0	2024-09-20	VENCIDO	1	2026-02-03 19:59:33.209583
252	261	2023-09-18	2024-09-17	0	2024-09-17	VENCIDO	1	2026-02-03 19:59:33.209583
253	262	2025-01-28	2026-01-28	0	2026-01-28	VENCIDO	1	2026-02-03 19:59:33.209583
254	263	2025-02-10	2026-02-10	0	2026-02-10	POR_VENCER	1	2026-02-03 19:59:33.209583
255	264	2023-11-25	2024-11-24	0	2024-11-24	VENCIDO	1	2026-02-03 19:59:33.209583
256	265	2025-02-02	2026-02-02	0	2026-02-02	VENCIDO	1	2026-02-03 19:59:33.209583
257	266	2023-12-05	2024-12-04	0	2024-12-04	VENCIDO	1	2026-02-03 19:59:33.209583
258	267	2023-11-25	2024-11-24	0	2024-11-24	VENCIDO	1	2026-02-03 19:59:33.209583
259	268	2024-06-27	2025-06-27	0	2025-06-27	VENCIDO	1	2026-02-03 19:59:33.209583
260	269	2025-02-18	2026-02-18	0	2026-02-18	POR_VENCER	1	2026-02-03 19:59:33.209583
261	270	2024-02-08	2025-02-07	0	2025-02-07	VENCIDO	1	2026-02-03 19:59:33.209583
262	271	2023-10-31	2024-10-30	0	2024-10-30	VENCIDO	1	2026-02-03 19:59:33.209583
263	272	2025-02-12	2026-02-12	0	2026-02-12	POR_VENCER	1	2026-02-03 19:59:33.209583
264	273	2025-01-31	2026-01-31	0	2026-01-31	VENCIDO	1	2026-02-03 19:59:33.209583
265	274	2024-03-19	2025-03-19	0	2025-03-19	VENCIDO	1	2026-02-03 19:59:33.209583
266	275	2023-11-22	2024-11-21	0	2024-11-21	VENCIDO	1	2026-02-03 19:59:33.209583
267	276	2024-05-27	2025-05-27	0	2025-05-27	VENCIDO	1	2026-02-03 19:59:33.209583
268	277	2024-02-23	2025-02-22	0	2025-02-22	VENCIDO	1	2026-02-03 19:59:33.209583
269	278	2023-11-30	2024-11-29	0	2024-11-29	VENCIDO	1	2026-02-03 19:59:33.209583
270	279	2023-07-31	2024-07-30	0	2024-07-30	VENCIDO	1	2026-02-03 19:59:33.209583
271	280	2023-11-25	2024-11-24	0	2024-11-24	VENCIDO	1	2026-02-03 19:59:33.209583
272	281	2025-01-31	2026-01-31	0	2026-01-31	VENCIDO	1	2026-02-03 19:59:33.209583
273	282	2024-06-10	2025-06-10	0	2025-06-10	VENCIDO	1	2026-02-03 19:59:33.209583
274	283	2024-02-05	2025-02-04	0	2025-02-04	VENCIDO	1	2026-02-03 19:59:33.209583
275	284	2023-11-22	2024-11-21	0	2024-11-21	VENCIDO	1	2026-02-03 19:59:33.209583
276	285	2025-01-06	2026-01-06	0	2026-01-06	VENCIDO	1	2026-02-03 19:59:33.209583
277	286	2024-05-13	2025-05-13	0	2025-05-13	VENCIDO	1	2026-02-03 19:59:33.209583
278	287	2023-11-15	2024-11-14	0	2024-11-14	VENCIDO	1	2026-02-03 19:59:33.209583
279	288	2024-05-13	2025-05-13	0	2025-05-13	VENCIDO	1	2026-02-03 19:59:33.209583
280	290	2024-02-28	2025-02-27	0	2025-02-27	VENCIDO	1	2026-02-03 19:59:33.209583
281	291	2024-06-12	2025-06-12	0	2025-06-12	VENCIDO	1	2026-02-03 19:59:33.209583
282	294	2023-10-18	2024-10-17	0	2024-10-17	VENCIDO	1	2026-02-03 19:59:33.209583
283	295	2025-01-03	2026-01-03	0	2026-01-03	VENCIDO	1	2026-02-03 19:59:33.209583
284	296	2024-05-24	2025-05-24	0	2025-05-24	VENCIDO	1	2026-02-03 19:59:33.209583
285	297	2023-07-27	2024-07-26	0	2024-07-26	VENCIDO	1	2026-02-03 19:59:33.209583
286	298	2023-07-22	2024-07-21	0	2024-07-21	VENCIDO	1	2026-02-03 19:59:33.209583
287	300	2023-12-10	2024-12-09	0	2024-12-09	VENCIDO	1	2026-02-03 19:59:33.209583
288	301	2024-01-16	2025-01-15	0	2025-01-15	VENCIDO	1	2026-02-03 19:59:33.209583
289	302	2023-09-18	2024-09-17	0	2024-09-17	VENCIDO	1	2026-02-03 19:59:33.209583
290	303	2025-01-28	2026-01-28	0	2026-01-28	VENCIDO	1	2026-02-03 19:59:33.209583
291	304	2023-08-12	2024-08-11	0	2024-08-11	VENCIDO	1	2026-02-03 19:59:33.209583
292	305	2023-11-22	2024-11-21	0	2024-11-21	VENCIDO	1	2026-02-03 19:59:33.209583
293	306	2024-04-17	2025-04-17	0	2025-04-17	VENCIDO	1	2026-02-03 19:59:33.209583
294	307	2024-02-24	2025-02-23	0	2025-02-23	VENCIDO	1	2026-02-03 19:59:33.209583
295	308	2023-12-03	2024-12-02	0	2024-12-02	VENCIDO	1	2026-02-03 19:59:33.209583
296	309	2025-01-02	2026-01-02	0	2026-01-02	VENCIDO	1	2026-02-03 19:59:33.209583
297	310	2023-09-17	2024-09-16	0	2024-09-16	VENCIDO	1	2026-02-03 19:59:33.209583
298	311	2025-02-19	2026-02-19	0	2026-02-19	POR_VENCER	1	2026-02-03 19:59:33.209583
299	312	2025-01-21	2026-01-21	0	2026-01-21	VENCIDO	1	2026-02-03 19:59:33.209583
300	313	2025-02-01	2026-02-01	0	2026-02-01	VENCIDO	1	2026-02-03 19:59:33.209583
301	314	2023-11-22	2024-11-21	0	2024-11-21	VENCIDO	1	2026-02-03 19:59:33.209583
302	315	2024-04-16	2025-04-16	0	2025-04-16	VENCIDO	1	2026-02-03 19:59:33.209583
303	316	2024-06-12	2025-06-12	0	2025-06-12	VENCIDO	1	2026-02-03 19:59:33.209583
304	317	2023-11-22	2024-11-21	0	2024-11-21	VENCIDO	1	2026-02-03 19:59:33.209583
305	318	2023-10-21	2024-10-20	0	2024-10-20	VENCIDO	1	2026-02-03 19:59:33.209583
306	319	2023-10-17	2024-10-16	0	2024-10-16	VENCIDO	1	2026-02-03 19:59:33.209583
307	320	2023-11-04	2024-11-03	0	2024-11-03	VENCIDO	1	2026-02-03 19:59:33.209583
308	321	2024-05-27	2025-05-27	0	2025-05-27	VENCIDO	1	2026-02-03 19:59:33.209583
309	322	2023-09-07	2024-09-06	0	2024-09-06	VENCIDO	1	2026-02-03 19:59:33.209583
310	323	2025-01-28	2026-01-28	0	2026-01-28	VENCIDO	1	2026-02-03 19:59:33.209583
311	324	2024-05-28	2025-05-28	0	2025-05-28	VENCIDO	1	2026-02-03 19:59:33.209583
312	325	2023-08-22	2024-08-21	0	2024-08-21	VENCIDO	1	2026-02-03 19:59:33.209583
313	326	2024-03-26	2025-03-26	0	2025-03-26	VENCIDO	1	2026-02-03 19:59:33.209583
314	327	2023-10-17	2024-10-16	0	2024-10-16	VENCIDO	1	2026-02-03 19:59:33.209583
315	328	2024-02-29	2025-02-28	0	2025-02-28	VENCIDO	1	2026-02-03 19:59:33.209583
316	329	2024-02-02	2025-02-01	0	2025-02-01	VENCIDO	1	2026-02-03 19:59:33.209583
317	331	2023-10-18	2024-10-17	0	2024-10-17	VENCIDO	1	2026-02-03 19:59:33.209583
318	332	2024-02-08	2025-02-07	0	2025-02-07	VENCIDO	1	2026-02-03 19:59:33.209583
319	333	2023-10-21	2024-10-20	0	2024-10-20	VENCIDO	1	2026-02-03 19:59:33.209583
320	334	2024-02-26	2025-02-25	0	2025-02-25	VENCIDO	1	2026-02-03 19:59:33.209583
321	335	2023-07-21	2024-07-20	0	2024-07-20	VENCIDO	1	2026-02-03 19:59:33.209583
322	336	2024-06-09	2025-06-09	0	2025-06-09	VENCIDO	1	2026-02-03 19:59:33.209583
323	337	2024-02-29	2025-02-28	0	2025-02-28	VENCIDO	1	2026-02-03 19:59:33.209583
324	338	2025-02-10	2026-02-10	0	2026-02-10	POR_VENCER	1	2026-02-03 19:59:33.209583
325	339	2023-12-11	2024-12-10	0	2024-12-10	VENCIDO	1	2026-02-03 19:59:33.209583
326	340	2023-10-18	2024-10-17	0	2024-10-17	VENCIDO	1	2026-02-03 19:59:33.209583
327	341	2025-01-30	2026-01-30	0	2026-01-30	VENCIDO	1	2026-02-03 19:59:33.209583
328	342	2023-10-18	2024-10-17	0	2024-10-17	VENCIDO	1	2026-02-03 19:59:33.209583
329	343	2023-11-20	2024-11-19	0	2024-11-19	VENCIDO	1	2026-02-03 19:59:33.209583
330	344	2025-01-28	2026-01-28	0	2026-01-28	VENCIDO	1	2026-02-03 19:59:33.209583
331	345	2023-08-25	2024-08-24	0	2024-08-24	VENCIDO	1	2026-02-03 19:59:33.209583
332	346	2023-08-25	2024-08-24	0	2024-08-24	VENCIDO	1	2026-02-03 19:59:33.209583
333	347	2024-04-22	2025-04-22	0	2025-04-22	VENCIDO	1	2026-02-03 19:59:33.209583
334	348	2024-03-26	2025-03-26	0	2025-03-26	VENCIDO	1	2026-02-03 19:59:33.209583
335	349	2025-01-28	2026-01-28	0	2026-01-28	VENCIDO	1	2026-02-03 19:59:33.209583
336	350	2023-11-26	2024-11-25	0	2024-11-25	VENCIDO	1	2026-02-03 19:59:33.209583
337	351	2024-08-28	2025-08-28	0	2025-08-28	VENCIDO	1	2026-02-03 19:59:33.209583
338	352	2024-05-27	2025-05-27	0	2025-05-27	VENCIDO	1	2026-02-03 19:59:33.209583
339	353	2025-02-01	2026-02-01	0	2026-02-01	VENCIDO	1	2026-02-03 19:59:33.209583
340	354	2023-10-16	2024-10-15	0	2024-10-15	VENCIDO	1	2026-02-03 19:59:33.209583
341	355	2024-01-31	2025-01-30	0	2025-01-30	VENCIDO	1	2026-02-03 19:59:33.209583
342	356	2024-05-24	2025-05-24	0	2025-05-24	VENCIDO	1	2026-02-03 19:59:33.209583
343	357	2023-09-17	2024-09-16	0	2024-09-16	VENCIDO	1	2026-02-03 19:59:33.209583
344	358	2024-05-26	2025-05-26	0	2025-05-26	VENCIDO	1	2026-02-03 19:59:33.209583
345	359	2024-05-26	2025-05-26	0	2025-05-26	VENCIDO	1	2026-02-03 19:59:33.209583
346	360	2024-01-26	2025-01-25	0	2025-01-25	VENCIDO	1	2026-02-03 19:59:33.209583
347	361	2024-05-17	2025-05-17	0	2025-05-17	VENCIDO	1	2026-02-03 19:59:33.209583
348	362	2025-01-31	2026-01-31	0	2026-01-31	VENCIDO	1	2026-02-03 19:59:33.209583
349	363	2023-08-21	2024-08-20	0	2024-08-20	VENCIDO	1	2026-02-03 19:59:33.209583
350	364	2023-10-23	2024-10-22	0	2024-10-22	VENCIDO	1	2026-02-03 19:59:33.209583
351	365	2024-02-07	2025-02-06	0	2025-02-06	VENCIDO	1	2026-02-03 19:59:33.209583
352	366	2024-02-27	2025-02-26	0	2025-02-26	VENCIDO	1	2026-02-03 19:59:33.209583
353	367	2023-09-15	2024-09-14	0	2024-09-14	VENCIDO	1	2026-02-03 19:59:33.209583
354	368	2024-03-25	2025-03-25	0	2025-03-25	VENCIDO	1	2026-02-03 19:59:33.209583
355	369	2024-01-25	2025-01-24	0	2025-01-24	VENCIDO	1	2026-02-03 19:59:33.209583
356	370	2024-01-09	2025-01-08	0	2025-01-08	VENCIDO	1	2026-02-03 19:59:33.209583
357	371	2023-10-31	2024-10-30	0	2024-10-30	VENCIDO	1	2026-02-03 19:59:33.209583
358	372	2023-10-23	2024-10-22	0	2024-10-22	VENCIDO	1	2026-02-03 19:59:33.209583
359	373	2024-02-29	2025-02-28	0	2025-02-28	VENCIDO	1	2026-02-03 19:59:33.209583
360	374	2024-05-25	2025-05-25	0	2025-05-25	VENCIDO	1	2026-02-03 19:59:33.209583
361	375	2023-07-04	2024-07-03	0	2024-07-03	VENCIDO	1	2026-02-03 19:59:33.209583
362	376	2023-10-23	2024-10-22	0	2024-10-22	VENCIDO	1	2026-02-03 19:59:33.209583
363	377	2023-08-06	2024-08-05	0	2024-08-05	VENCIDO	1	2026-02-03 19:59:33.209583
364	378	2023-10-20	2024-10-19	0	2024-10-19	VENCIDO	1	2026-02-03 19:59:33.209583
365	379	2024-06-07	2025-06-07	0	2025-06-07	VENCIDO	1	2026-02-03 19:59:33.209583
366	380	2023-11-04	2024-11-03	0	2024-11-03	VENCIDO	1	2026-02-03 19:59:33.209583
367	381	2023-10-27	2024-10-26	0	2024-10-26	VENCIDO	1	2026-02-03 19:59:33.209583
368	382	2023-10-23	2024-10-22	0	2024-10-22	VENCIDO	1	2026-02-03 19:59:33.209583
369	383	2023-10-31	2024-10-30	0	2024-10-30	VENCIDO	1	2026-02-03 19:59:33.209583
370	384	2024-05-13	2025-05-13	0	2025-05-13	VENCIDO	1	2026-02-03 19:59:33.209583
371	385	2023-11-26	2024-11-25	0	2024-11-25	VENCIDO	1	2026-02-03 19:59:33.209583
372	386	2025-02-01	2026-02-01	0	2026-02-01	VENCIDO	1	2026-02-03 19:59:33.209583
373	387	2024-05-25	2025-05-25	0	2025-05-25	VENCIDO	1	2026-02-03 19:59:33.209583
374	388	2023-10-18	2024-10-17	0	2024-10-17	VENCIDO	1	2026-02-03 19:59:33.209583
375	389	2023-07-13	2024-07-12	0	2024-07-12	VENCIDO	1	2026-02-03 19:59:33.209583
376	390	2023-09-18	2024-09-17	0	2024-09-17	VENCIDO	1	2026-02-03 19:59:33.209583
377	391	2023-10-20	2024-10-19	0	2024-10-19	VENCIDO	1	2026-02-03 19:59:33.209583
378	392	2023-09-07	2024-09-06	0	2024-09-06	VENCIDO	1	2026-02-03 19:59:33.209583
379	393	2025-01-28	2026-01-28	0	2026-01-28	VENCIDO	1	2026-02-03 19:59:33.209583
380	394	2024-02-29	2025-02-28	0	2025-02-28	VENCIDO	1	2026-02-03 19:59:33.209583
381	395	2025-02-10	2026-02-10	0	2026-02-10	POR_VENCER	1	2026-02-03 19:59:33.209583
382	396	2025-01-06	2026-01-06	0	2026-01-06	VENCIDO	1	2026-02-03 19:59:33.209583
383	397	2024-04-09	2025-04-09	0	2025-04-09	VENCIDO	1	2026-02-03 19:59:33.209583
384	398	2025-02-10	2026-02-10	0	2026-02-10	POR_VENCER	1	2026-02-03 19:59:33.209583
385	399	2024-06-09	2025-06-09	0	2025-06-09	VENCIDO	1	2026-02-03 19:59:33.209583
386	400	2024-03-05	2025-03-05	0	2025-03-05	VENCIDO	1	2026-02-03 19:59:33.209583
387	401	2025-02-03	2026-02-03	0	2026-02-03	VENCIDO	1	2026-02-03 19:59:33.209583
388	402	2024-01-27	2025-01-26	0	2025-01-26	VENCIDO	1	2026-02-03 19:59:33.209583
389	403	2024-04-16	2025-04-16	0	2025-04-16	VENCIDO	1	2026-02-03 19:59:33.209583
390	404	2023-11-22	2024-11-21	0	2024-11-21	VENCIDO	1	2026-02-03 19:59:33.209583
391	406	2023-12-11	2024-12-10	0	2024-12-10	VENCIDO	1	2026-02-03 19:59:33.209583
392	407	2023-08-21	2024-08-20	0	2024-08-20	VENCIDO	1	2026-02-03 19:59:33.209583
393	408	2023-08-08	2024-08-07	0	2024-08-07	VENCIDO	1	2026-02-03 19:59:33.209583
394	409	2023-10-23	2024-10-22	0	2024-10-22	VENCIDO	1	2026-02-03 19:59:33.209583
395	410	2024-02-24	2025-02-23	0	2025-02-23	VENCIDO	1	2026-02-03 19:59:33.209583
396	411	2023-11-20	2024-11-19	0	2024-11-19	VENCIDO	1	2026-02-03 19:59:33.209583
397	412	2024-05-27	2025-05-27	0	2025-05-27	VENCIDO	1	2026-02-03 19:59:33.209583
398	413	2024-02-24	2025-02-23	0	2025-02-23	VENCIDO	1	2026-02-03 19:59:33.209583
399	414	2024-01-19	2025-01-18	0	2025-01-18	VENCIDO	1	2026-02-03 19:59:33.209583
400	415	2023-10-21	2024-10-20	0	2024-10-20	VENCIDO	1	2026-02-03 19:59:33.209583
401	416	2023-08-22	2024-08-21	0	2024-08-21	VENCIDO	1	2026-02-03 19:59:33.209583
402	417	2023-10-25	2024-10-24	0	2024-10-24	VENCIDO	1	2026-02-03 19:59:33.209583
403	418	2024-05-21	2025-05-21	0	2025-05-21	VENCIDO	1	2026-02-03 19:59:33.209583
404	419	2023-08-06	2024-08-05	0	2024-08-05	VENCIDO	1	2026-02-03 19:59:33.209583
405	420	2023-08-21	2024-08-20	0	2024-08-20	VENCIDO	1	2026-02-03 19:59:33.209583
406	421	2024-01-30	2025-01-29	0	2025-01-29	VENCIDO	1	2026-02-03 19:59:33.209583
407	422	2024-01-09	2025-01-08	0	2025-01-08	VENCIDO	1	2026-02-03 19:59:33.209583
408	423	2023-08-07	2024-08-06	0	2024-08-06	VENCIDO	1	2026-02-03 19:59:33.209583
409	424	2025-02-10	2026-02-10	0	2026-02-10	POR_VENCER	1	2026-02-03 19:59:33.209583
410	425	2023-12-31	2024-12-30	0	2024-12-30	VENCIDO	1	2026-02-03 19:59:33.209583
411	426	2023-08-11	2024-08-10	0	2024-08-10	VENCIDO	1	2026-02-03 19:59:33.209583
412	427	2024-05-21	2025-05-21	0	2025-05-21	VENCIDO	1	2026-02-03 19:59:33.209583
413	428	2023-10-16	2024-10-15	0	2024-10-15	VENCIDO	1	2026-02-03 19:59:33.209583
414	429	2023-11-25	2024-11-24	0	2024-11-24	VENCIDO	1	2026-02-03 19:59:33.209583
415	430	2025-01-06	2026-01-06	0	2026-01-06	VENCIDO	1	2026-02-03 19:59:33.209583
416	431	2023-10-21	2024-10-20	0	2024-10-20	VENCIDO	1	2026-02-03 19:59:33.209583
417	432	2024-02-05	2025-02-04	0	2025-02-04	VENCIDO	1	2026-02-03 19:59:33.209583
418	433	2024-01-30	2025-01-29	0	2025-01-29	VENCIDO	1	2026-02-03 19:59:33.209583
419	434	2023-11-14	2024-11-13	0	2024-11-13	VENCIDO	1	2026-02-03 19:59:33.209583
420	435	2024-03-26	2025-03-26	0	2025-03-26	VENCIDO	1	2026-02-03 19:59:33.209583
421	436	2023-10-31	2024-10-30	0	2024-10-30	VENCIDO	1	2026-02-03 19:59:33.209583
422	437	2023-09-17	2024-09-16	0	2024-09-16	VENCIDO	1	2026-02-03 19:59:33.209583
423	438	2023-08-08	2024-08-07	0	2024-08-07	VENCIDO	1	2026-02-03 19:59:33.209583
424	439	2024-01-26	2025-01-25	0	2025-01-25	VENCIDO	1	2026-02-03 19:59:33.209583
425	440	2023-10-18	2024-10-17	0	2024-10-17	VENCIDO	1	2026-02-03 19:59:33.209583
426	441	2025-01-31	2026-01-31	0	2026-01-31	VENCIDO	1	2026-02-03 19:59:33.209583
427	442	2023-12-18	2024-12-17	0	2024-12-17	VENCIDO	1	2026-02-03 19:59:33.209583
428	443	2025-01-19	2026-01-19	0	2026-01-19	VENCIDO	1	2026-02-03 19:59:33.209583
429	445	2025-01-20	2026-01-20	0	2026-01-20	VENCIDO	1	2026-02-03 19:59:33.209583
430	446	2024-05-13	2025-05-13	0	2025-05-13	VENCIDO	1	2026-02-03 19:59:33.209583
431	447	2024-02-29	2025-02-28	0	2025-02-28	VENCIDO	1	2026-02-03 19:59:33.209583
432	449	2024-04-16	2025-04-16	0	2025-04-16	VENCIDO	1	2026-02-03 19:59:33.209583
433	450	2024-06-12	2025-06-12	0	2025-06-12	VENCIDO	1	2026-02-03 19:59:33.209583
434	451	2024-03-26	2025-03-26	0	2025-03-26	VENCIDO	1	2026-02-03 19:59:33.209583
435	452	2023-11-26	2024-11-25	0	2024-11-25	VENCIDO	1	2026-02-03 19:59:33.209583
436	453	2025-02-01	2026-02-01	0	2026-02-01	VENCIDO	1	2026-02-03 19:59:33.209583
437	455	2024-04-30	2025-04-30	0	2025-04-30	VENCIDO	1	2026-02-03 19:59:33.209583
438	456	2024-02-01	2025-01-31	0	2025-01-31	VENCIDO	1	2026-02-03 19:59:33.209583
439	457	2023-10-18	2024-10-17	0	2024-10-17	VENCIDO	1	2026-02-03 19:59:33.209583
440	458	2023-08-03	2024-08-02	0	2024-08-02	VENCIDO	1	2026-02-03 19:59:33.209583
441	459	2025-01-28	2026-01-28	0	2026-01-28	VENCIDO	1	2026-02-03 19:59:33.209583
442	460	2023-12-12	2024-12-11	0	2024-12-11	VENCIDO	1	2026-02-03 19:59:33.209583
443	461	2023-10-21	2024-10-20	0	2024-10-20	VENCIDO	1	2026-02-03 19:59:33.209583
444	462	2023-10-17	2024-10-16	0	2024-10-16	VENCIDO	1	2026-02-03 19:59:33.209583
445	463	2023-10-18	2024-10-17	0	2024-10-17	VENCIDO	1	2026-02-03 19:59:33.209583
446	464	2023-09-18	2024-09-17	0	2024-09-17	VENCIDO	1	2026-02-03 19:59:33.209583
447	465	2025-01-28	2026-01-28	0	2026-01-28	VENCIDO	1	2026-02-03 19:59:33.209583
448	466	2023-09-21	2024-09-20	0	2024-09-20	VENCIDO	1	2026-02-03 19:59:33.209583
449	467	2023-11-22	2024-11-21	0	2024-11-21	VENCIDO	1	2026-02-03 19:59:33.209583
450	468	2024-02-27	2025-02-26	0	2025-02-26	VENCIDO	1	2026-02-03 19:59:33.209583
451	469	2024-02-23	2025-02-22	0	2025-02-22	VENCIDO	1	2026-02-03 19:59:33.209583
452	470	2024-02-08	2025-02-07	0	2025-02-07	VENCIDO	1	2026-02-03 19:59:33.209583
453	471	2024-07-05	2025-07-05	0	2025-07-05	VENCIDO	1	2026-02-03 19:59:33.209583
454	472	2024-02-29	2025-02-28	0	2025-02-28	VENCIDO	1	2026-02-03 19:59:33.209583
455	473	2023-12-13	2024-12-12	0	2024-12-12	VENCIDO	1	2026-02-03 19:59:33.209583
456	474	2023-10-23	2024-10-22	0	2024-10-22	VENCIDO	1	2026-02-03 19:59:33.209583
457	475	2024-02-28	2025-02-27	0	2025-02-27	VENCIDO	1	2026-02-03 19:59:33.209583
458	476	2024-02-01	2025-01-31	0	2025-01-31	VENCIDO	1	2026-02-03 19:59:33.209583
459	477	2023-10-16	2024-10-15	0	2024-10-15	VENCIDO	1	2026-02-03 19:59:33.209583
460	478	2023-08-21	2024-08-20	0	2024-08-20	VENCIDO	1	2026-02-03 19:59:33.209583
461	479	2023-11-30	2024-11-29	0	2024-11-29	VENCIDO	1	2026-02-03 19:59:33.209583
462	480	2024-02-26	2025-02-25	0	2025-02-25	VENCIDO	1	2026-02-03 19:59:33.209583
463	481	2023-11-25	2024-11-24	0	2024-11-24	VENCIDO	1	2026-02-03 19:59:33.209583
464	482	2025-01-27	2026-01-27	0	2026-01-27	VENCIDO	1	2026-02-03 19:59:33.209583
465	483	2023-12-31	2024-12-30	0	2024-12-30	VENCIDO	1	2026-02-03 19:59:33.209583
466	484	2025-02-12	2026-02-12	0	2026-02-12	POR_VENCER	1	2026-02-03 19:59:33.209583
467	485	2023-10-17	2024-10-16	0	2024-10-16	VENCIDO	1	2026-02-03 19:59:33.209583
468	486	2024-01-09	2025-01-08	0	2025-01-08	VENCIDO	1	2026-02-03 19:59:33.209583
469	487	2023-07-13	2024-07-12	0	2024-07-12	VENCIDO	1	2026-02-03 19:59:33.209583
470	488	2025-02-18	2026-02-18	0	2026-02-18	POR_VENCER	1	2026-02-03 19:59:33.209583
471	489	2023-08-06	2024-08-05	0	2024-08-05	VENCIDO	1	2026-02-03 19:59:33.209583
472	490	2024-02-19	2025-02-18	0	2025-02-18	VENCIDO	1	2026-02-03 19:59:33.209583
473	491	2023-10-27	2024-10-26	0	2024-10-26	VENCIDO	1	2026-02-03 19:59:33.209583
474	492	2023-12-12	2024-12-11	0	2024-12-11	VENCIDO	1	2026-02-03 19:59:33.209583
475	493	2023-12-12	2024-12-11	0	2024-12-11	VENCIDO	1	2026-02-03 19:59:33.209583
476	494	2024-02-26	2025-02-25	0	2025-02-25	VENCIDO	1	2026-02-03 19:59:33.209583
477	495	2023-11-15	2024-11-14	0	2024-11-14	VENCIDO	1	2026-02-03 19:59:33.209583
478	496	2024-05-13	2025-05-13	0	2025-05-13	VENCIDO	1	2026-02-03 19:59:33.209583
479	497	2023-07-24	2024-07-23	0	2024-07-23	VENCIDO	1	2026-02-03 19:59:33.209583
480	498	2023-10-31	2024-10-30	0	2024-10-30	VENCIDO	1	2026-02-03 19:59:33.209583
481	499	2024-06-03	2025-06-03	0	2025-06-03	VENCIDO	1	2026-02-03 19:59:33.209583
482	500	2025-02-10	2026-02-10	0	2026-02-10	POR_VENCER	1	2026-02-03 19:59:33.209583
483	501	2024-04-30	2025-04-30	0	2025-04-30	VENCIDO	1	2026-02-03 19:59:33.209583
484	503	2023-08-21	2024-08-20	0	2024-08-20	VENCIDO	1	2026-02-03 19:59:33.209583
485	504	2023-12-12	2024-12-11	0	2024-12-11	VENCIDO	1	2026-02-03 19:59:33.209583
486	506	2024-04-15	2025-04-15	0	2025-04-15	VENCIDO	1	2026-02-03 19:59:33.209583
487	507	2023-12-03	2024-12-02	0	2024-12-02	VENCIDO	1	2026-02-03 19:59:33.209583
488	508	2023-12-18	2024-12-17	0	2024-12-17	VENCIDO	1	2026-02-03 19:59:33.209583
489	510	2023-07-24	2024-07-23	0	2024-07-23	VENCIDO	1	2026-02-03 19:59:33.209583
490	511	2025-02-13	2026-02-13	0	2026-02-13	POR_VENCER	1	2026-02-03 19:59:33.209583
491	512	2023-10-31	2024-10-30	0	2024-10-30	VENCIDO	1	2026-02-03 19:59:33.209583
492	513	2024-02-29	2025-02-28	0	2025-02-28	VENCIDO	1	2026-02-03 19:59:33.209583
493	514	2023-11-07	2024-11-06	0	2024-11-06	VENCIDO	1	2026-02-03 19:59:33.209583
494	515	2024-06-30	2025-06-30	0	2025-06-30	VENCIDO	1	2026-02-03 19:59:33.209583
495	516	2024-02-27	2025-02-26	0	2025-02-26	VENCIDO	1	2026-02-03 19:59:33.209583
496	517	2023-08-15	2024-08-14	0	2024-08-14	VENCIDO	1	2026-02-03 19:59:33.209583
497	518	2023-10-31	2024-10-30	0	2024-10-30	VENCIDO	1	2026-02-03 19:59:33.209583
498	519	2024-05-13	2025-05-13	0	2025-05-13	VENCIDO	1	2026-02-03 19:59:33.209583
499	520	2025-01-06	2026-01-06	0	2026-01-06	VENCIDO	1	2026-02-03 19:59:33.209583
500	521	2024-01-09	2025-01-08	0	2025-01-08	VENCIDO	1	2026-02-03 19:59:33.209583
501	522	2023-12-01	2024-11-30	0	2024-11-30	VENCIDO	1	2026-02-03 19:59:33.209583
502	523	2024-06-07	2025-06-07	0	2025-06-07	VENCIDO	1	2026-02-03 19:59:33.209583
503	524	2024-03-25	2025-03-25	0	2025-03-25	VENCIDO	1	2026-02-03 19:59:33.209583
504	525	2025-01-04	2026-01-04	0	2026-01-04	VENCIDO	1	2026-02-03 19:59:33.209583
505	526	2023-08-22	2024-08-21	0	2024-08-21	VENCIDO	1	2026-02-03 19:59:33.209583
506	527	2024-01-30	2025-01-29	0	2025-01-29	VENCIDO	1	2026-02-03 19:59:33.209583
507	528	2023-12-18	2024-12-17	0	2024-12-17	VENCIDO	1	2026-02-03 19:59:33.209583
508	529	2024-03-19	2025-03-19	0	2025-03-19	VENCIDO	1	2026-02-03 19:59:33.209583
509	530	2024-03-27	2025-03-27	0	2025-03-27	VENCIDO	1	2026-02-03 19:59:33.209583
510	531	2023-12-12	2024-12-11	0	2024-12-11	VENCIDO	1	2026-02-03 19:59:33.209583
511	532	2024-03-17	2025-03-17	0	2025-03-17	VENCIDO	1	2026-02-03 19:59:33.209583
512	533	2023-12-12	2024-12-11	0	2024-12-11	VENCIDO	1	2026-02-03 19:59:33.209583
513	534	2023-08-22	2024-08-21	0	2024-08-21	VENCIDO	1	2026-02-03 19:59:33.209583
514	535	2025-02-10	2026-02-10	0	2026-02-10	POR_VENCER	1	2026-02-03 19:59:33.209583
515	536	2024-04-14	2025-04-14	0	2025-04-14	VENCIDO	1	2026-02-03 19:59:33.209583
516	537	2023-10-27	2024-10-26	0	2024-10-26	VENCIDO	1	2026-02-03 19:59:33.209583
517	538	2023-10-17	2024-10-16	0	2024-10-16	VENCIDO	1	2026-02-03 19:59:33.209583
518	540	2025-02-17	2026-02-17	0	2026-02-17	POR_VENCER	1	2026-02-03 19:59:33.209583
519	541	2025-06-03	2026-06-03	0	2026-06-03	ACTIVO	1	2026-02-03 19:59:33.209583
520	542	2025-06-04	2026-06-04	0	2026-06-04	ACTIVO	1	2026-02-03 19:59:33.209583
521	543	2025-02-17	2026-02-17	0	2026-02-17	POR_VENCER	1	2026-02-03 19:59:33.209583
522	544	2025-06-08	2026-06-08	0	2026-06-08	ACTIVO	1	2026-02-03 19:59:33.209583
523	545	2025-02-17	2026-02-17	0	2026-02-17	POR_VENCER	1	2026-02-03 19:59:33.209583
524	546	2025-02-23	2026-02-23	0	2026-02-23	POR_VENCER	1	2026-02-03 19:59:33.209583
525	547	2025-06-08	2026-06-08	0	2026-06-08	ACTIVO	1	2026-02-03 19:59:33.209583
526	548	2025-06-10	2026-06-10	0	2026-06-10	ACTIVO	1	2026-02-03 19:59:33.209583
527	549	2025-03-02	2026-03-02	0	2026-03-02	POR_VENCER	1	2026-02-03 19:59:33.209583
528	550	2025-06-08	2026-06-08	0	2026-06-08	ACTIVO	1	2026-02-03 19:59:33.209583
529	551	2024-01-01	2024-12-31	0	2024-12-31	VENCIDO	1	2026-02-03 19:59:33.209583
530	552	2025-06-09	2026-06-09	0	2026-06-09	ACTIVO	1	2026-02-03 19:59:33.209583
531	553	2025-02-28	2026-02-28	0	2026-02-28	POR_VENCER	1	2026-02-03 19:59:33.209583
532	554	2025-03-02	2026-03-02	0	2026-03-02	POR_VENCER	1	2026-02-03 19:59:33.209583
533	555	2025-06-09	2026-06-09	0	2026-06-09	ACTIVO	1	2026-02-03 19:59:33.209583
534	556	2025-03-02	2026-03-02	0	2026-03-02	POR_VENCER	1	2026-02-03 19:59:33.209583
535	557	2025-06-08	2026-06-08	0	2026-06-08	ACTIVO	1	2026-02-03 19:59:33.209583
536	558	2025-02-23	2026-02-23	0	2026-02-23	POR_VENCER	1	2026-02-03 19:59:33.209583
537	559	2025-06-09	2026-06-09	0	2026-06-09	ACTIVO	1	2026-02-03 19:59:33.209583
538	560	2025-06-09	2026-06-09	0	2026-06-09	ACTIVO	1	2026-02-03 19:59:33.209583
539	561	2025-02-23	2026-02-23	0	2026-02-23	POR_VENCER	1	2026-02-03 19:59:33.209583
540	562	2025-02-26	2026-02-26	0	2026-02-26	POR_VENCER	1	2026-02-03 19:59:33.209583
541	563	2025-06-08	2026-06-08	0	2026-06-08	ACTIVO	1	2026-02-03 19:59:33.209583
542	564	2025-02-26	2026-02-26	0	2026-02-26	POR_VENCER	1	2026-02-03 19:59:33.209583
543	565	2025-06-09	2026-06-09	0	2026-06-09	ACTIVO	1	2026-02-03 19:59:33.209583
544	566	2025-02-26	2026-02-26	0	2026-02-26	POR_VENCER	1	2026-02-03 19:59:33.209583
545	567	2025-06-08	2026-06-08	0	2026-06-08	ACTIVO	1	2026-02-03 19:59:33.209583
546	568	2025-06-08	2026-06-08	0	2026-06-08	ACTIVO	1	2026-02-03 19:59:33.209583
547	569	2025-02-24	2026-02-24	0	2026-02-24	POR_VENCER	1	2026-02-03 19:59:33.209583
548	570	2025-02-26	2026-02-26	0	2026-02-26	POR_VENCER	1	2026-02-03 19:59:33.209583
549	571	2025-06-08	2026-06-08	0	2026-06-08	ACTIVO	1	2026-02-03 19:59:33.209583
550	572	2025-06-08	2026-06-08	0	2026-06-08	ACTIVO	1	2026-02-03 19:59:33.209583
551	573	2025-02-26	2026-02-26	0	2026-02-26	POR_VENCER	1	2026-02-03 19:59:33.209583
552	574	2025-02-26	2026-02-26	0	2026-02-26	POR_VENCER	1	2026-02-03 19:59:33.209583
553	575	2025-06-08	2026-06-08	0	2026-06-08	ACTIVO	1	2026-02-03 19:59:33.209583
554	576	2025-02-26	2026-02-26	0	2026-02-26	POR_VENCER	1	2026-02-03 19:59:33.209583
555	577	2025-06-08	2026-06-08	0	2026-06-08	ACTIVO	1	2026-02-03 19:59:33.209583
556	578	2025-02-26	2026-02-26	0	2026-02-26	POR_VENCER	1	2026-02-03 19:59:33.209583
557	579	2025-06-09	2026-06-09	0	2026-06-09	ACTIVO	1	2026-02-03 19:59:33.209583
558	580	2025-02-26	2026-02-26	0	2026-02-26	POR_VENCER	1	2026-02-03 19:59:33.209583
559	581	2025-06-23	2026-06-23	0	2026-06-23	ACTIVO	1	2026-02-03 19:59:33.209583
560	582	2025-03-05	2026-03-05	0	2026-03-05	POR_VENCER	1	2026-02-03 19:59:33.209583
561	583	2025-06-10	2026-06-10	0	2026-06-10	ACTIVO	1	2026-02-03 19:59:33.209583
562	584	2025-04-06	2026-04-06	0	2026-04-06	ACTIVO	1	2026-02-03 19:59:33.209583
563	585	2025-06-10	2026-06-10	0	2026-06-10	ACTIVO	1	2026-02-03 19:59:33.209583
564	586	2025-06-10	2026-06-10	0	2026-06-10	ACTIVO	1	2026-02-03 19:59:33.209583
565	587	2025-04-04	2026-04-04	0	2026-04-04	ACTIVO	1	2026-02-03 19:59:33.209583
566	588	2025-04-17	2026-04-17	0	2026-04-17	ACTIVO	1	2026-02-03 19:59:33.209583
567	589	2025-06-10	2026-06-10	0	2026-06-10	ACTIVO	1	2026-02-03 19:59:33.209583
568	590	2025-06-10	2026-06-10	0	2026-06-10	ACTIVO	1	2026-02-03 19:59:33.209583
569	591	2025-04-17	2026-04-17	0	2026-04-17	ACTIVO	1	2026-02-03 19:59:33.209583
570	592	2025-03-10	2026-03-10	0	2026-03-10	ACTIVO	1	2026-02-03 19:59:33.209583
571	593	2025-06-10	2026-06-10	0	2026-06-10	ACTIVO	1	2026-02-03 19:59:33.209583
572	594	2025-03-21	2026-03-21	0	2026-03-21	ACTIVO	1	2026-02-03 19:59:33.209583
573	595	2025-06-17	2026-06-17	0	2026-06-17	ACTIVO	1	2026-02-03 19:59:33.209583
574	596	2025-03-24	2026-03-24	0	2026-03-24	ACTIVO	1	2026-02-03 19:59:33.209583
575	597	2025-06-08	2026-06-08	0	2026-06-08	ACTIVO	1	2026-02-03 19:59:33.209583
576	598	2025-04-09	2026-04-09	0	2026-04-09	ACTIVO	1	2026-02-03 19:59:33.209583
577	599	2025-06-27	2026-06-27	0	2026-06-27	ACTIVO	1	2026-02-03 19:59:33.209583
578	600	2025-06-10	2026-06-10	0	2026-06-10	ACTIVO	1	2026-02-03 19:59:33.209583
579	601	2025-04-03	2026-04-03	0	2026-04-03	ACTIVO	1	2026-02-03 19:59:33.209583
580	602	2025-04-12	2026-04-12	0	2026-04-12	ACTIVO	1	2026-02-03 19:59:33.209583
581	603	2025-06-10	2026-06-10	0	2026-06-10	ACTIVO	1	2026-02-03 19:59:33.209583
582	604	2025-06-10	2026-06-10	0	2026-06-10	ACTIVO	1	2026-02-03 19:59:33.209583
583	605	2025-04-04	2026-04-04	0	2026-04-04	ACTIVO	1	2026-02-03 19:59:33.209583
584	606	2025-06-23	2026-06-23	0	2026-06-23	ACTIVO	1	2026-02-03 19:59:33.209583
585	607	2025-04-03	2026-04-03	0	2026-04-03	ACTIVO	1	2026-02-03 19:59:33.209583
586	608	2025-06-10	2026-06-10	0	2026-06-10	ACTIVO	1	2026-02-03 19:59:33.209583
587	609	2025-04-19	2026-04-19	0	2026-04-19	ACTIVO	1	2026-02-03 19:59:33.209583
588	610	2025-05-05	2026-05-05	0	2026-05-05	ACTIVO	1	2026-02-03 19:59:33.209583
589	611	2025-06-10	2026-06-10	0	2026-06-10	ACTIVO	1	2026-02-03 19:59:33.209583
590	612	2025-06-23	2026-06-23	0	2026-06-23	ACTIVO	1	2026-02-03 19:59:33.209583
591	613	2025-05-05	2026-05-05	0	2026-05-05	ACTIVO	1	2026-02-03 19:59:33.209583
592	614	2025-06-16	2026-06-16	0	2026-06-16	ACTIVO	1	2026-02-03 19:59:33.209583
593	615	2025-05-30	2026-05-30	0	2026-05-30	ACTIVO	1	2026-02-03 19:59:33.209583
594	616	2025-05-30	2026-05-30	0	2026-05-30	ACTIVO	1	2026-02-03 19:59:33.209583
595	617	2025-06-16	2026-06-16	0	2026-06-16	ACTIVO	1	2026-02-03 19:59:33.209583
596	618	2025-07-16	2026-07-16	0	2026-07-16	ACTIVO	1	2026-02-03 19:59:33.209583
597	619	2025-05-30	2026-05-30	0	2026-05-30	ACTIVO	1	2026-02-03 19:59:33.209583
598	620	2025-06-27	2026-06-27	0	2026-06-27	ACTIVO	1	2026-02-03 19:59:33.209583
599	621	2025-05-28	2026-05-28	0	2026-05-28	ACTIVO	1	2026-02-03 19:59:33.209583
600	622	2025-05-28	2026-05-28	0	2026-05-28	ACTIVO	1	2026-02-03 19:59:33.209583
601	623	2025-06-30	2026-06-30	0	2026-06-30	ACTIVO	1	2026-02-03 19:59:33.209583
602	624	2025-05-28	2026-05-28	0	2026-05-28	ACTIVO	1	2026-02-03 19:59:33.209583
603	625	2025-06-10	2026-06-10	0	2026-06-10	ACTIVO	1	2026-02-03 19:59:33.209583
604	626	2025-06-23	2026-06-23	0	2026-06-23	ACTIVO	1	2026-02-03 19:59:33.209583
605	627	2025-06-09	2026-06-09	0	2026-06-09	ACTIVO	1	2026-02-03 19:59:33.209583
606	628	2025-06-09	2026-06-09	0	2026-06-09	ACTIVO	1	2026-02-03 19:59:33.209583
607	629	2025-06-10	2026-06-10	0	2026-06-10	ACTIVO	1	2026-02-03 19:59:33.209583
608	630	2025-06-09	2026-06-09	0	2026-06-09	ACTIVO	1	2026-02-03 19:59:33.209583
609	632	2025-06-30	2026-06-30	0	2026-06-30	ACTIVO	1	2026-02-03 19:59:33.209583
610	633	2025-06-11	2026-06-11	0	2026-06-11	ACTIVO	1	2026-02-03 19:59:33.209583
611	634	2025-06-25	2026-06-25	0	2026-06-25	ACTIVO	1	2026-02-03 19:59:33.209583
612	635	2025-06-16	2026-06-16	0	2026-06-16	ACTIVO	1	2026-02-03 19:59:33.209583
613	636	2025-07-01	2026-07-01	0	2026-07-01	ACTIVO	1	2026-02-03 19:59:33.209583
614	638	2025-06-13	2026-06-13	0	2026-06-13	ACTIVO	1	2026-02-03 19:59:33.209583
615	639	2025-06-13	2026-06-13	0	2026-06-13	ACTIVO	1	2026-02-03 19:59:33.209583
616	641	2025-06-13	2026-06-13	0	2026-06-13	ACTIVO	1	2026-02-03 19:59:33.209583
617	642	2025-06-14	2026-06-14	0	2026-06-14	ACTIVO	1	2026-02-03 19:59:33.209583
618	643	2025-09-22	2026-09-22	0	2026-09-22	ACTIVO	1	2026-02-03 19:59:33.209583
619	644	2025-06-13	2026-06-13	0	2026-06-13	ACTIVO	1	2026-02-03 19:59:33.209583
620	645	2025-06-13	2026-06-13	0	2026-06-13	ACTIVO	1	2026-02-03 19:59:33.209583
621	646	2025-06-13	2026-06-13	0	2026-06-13	ACTIVO	1	2026-02-03 19:59:33.209583
622	647	2025-06-13	2026-06-13	0	2026-06-13	ACTIVO	1	2026-02-03 19:59:33.209583
623	648	2025-06-13	2026-06-13	0	2026-06-13	ACTIVO	1	2026-02-03 19:59:33.209583
624	649	2025-06-21	2026-06-21	0	2026-06-21	ACTIVO	1	2026-02-03 19:59:33.209583
625	650	2025-06-14	2026-06-14	0	2026-06-14	ACTIVO	1	2026-02-03 19:59:33.209583
626	651	2025-06-30	2026-06-30	0	2026-06-30	ACTIVO	1	2026-02-03 19:59:33.209583
627	652	2025-06-14	2026-06-14	0	2026-06-14	ACTIVO	1	2026-02-03 19:59:33.209583
628	653	2025-06-30	2026-06-30	0	2026-06-30	ACTIVO	1	2026-02-03 19:59:33.209583
629	655	2025-06-22	2026-06-22	0	2026-06-22	ACTIVO	1	2026-02-03 19:59:33.209583
630	657	2025-06-14	2026-06-14	0	2026-06-14	ACTIVO	1	2026-02-03 19:59:33.209583
631	658	2025-06-25	2026-06-25	0	2026-06-25	ACTIVO	1	2026-02-03 19:59:33.209583
632	659	2025-06-14	2026-06-14	0	2026-06-14	ACTIVO	1	2026-02-03 19:59:33.209583
633	660	2025-07-28	2026-07-28	0	2026-07-28	ACTIVO	1	2026-02-03 19:59:33.209583
634	661	2025-06-19	2026-06-19	0	2026-06-19	ACTIVO	1	2026-02-03 19:59:33.209583
635	662	2025-07-03	2026-07-03	0	2026-07-03	ACTIVO	1	2026-02-03 19:59:33.209583
636	663	2025-06-16	2026-06-16	0	2026-06-16	ACTIVO	1	2026-02-03 19:59:33.209583
637	664	2025-06-14	2026-06-14	0	2026-06-14	ACTIVO	1	2026-02-03 19:59:33.209583
638	665	2025-06-14	2026-06-14	0	2026-06-14	ACTIVO	1	2026-02-03 19:59:33.209583
639	666	2025-06-16	2026-06-16	0	2026-06-16	ACTIVO	1	2026-02-03 19:59:33.209583
640	667	2025-06-17	2026-06-17	0	2026-06-17	ACTIVO	1	2026-02-03 19:59:33.209583
641	669	2025-07-22	2026-07-22	0	2026-07-22	ACTIVO	1	2026-02-03 19:59:33.209583
642	670	2025-07-25	2026-07-25	0	2026-07-25	ACTIVO	1	2026-02-03 19:59:33.209583
643	672	2025-06-17	2026-06-17	0	2026-06-17	ACTIVO	1	2026-02-03 19:59:33.209583
644	673	2025-07-24	2026-07-24	0	2026-07-24	ACTIVO	1	2026-02-03 19:59:33.209583
645	674	2025-06-23	2026-06-23	0	2026-06-23	ACTIVO	1	2026-02-03 19:59:33.209583
646	675	2025-06-21	2026-06-21	0	2026-06-21	ACTIVO	1	2026-02-03 19:59:33.209583
647	676	2025-06-21	2026-06-21	0	2026-06-21	ACTIVO	1	2026-02-03 19:59:33.209583
648	678	2025-06-17	2026-06-17	0	2026-06-17	ACTIVO	1	2026-02-03 19:59:33.209583
649	679	2025-12-10	2026-12-10	0	2026-12-10	ACTIVO	1	2026-02-03 19:59:33.209583
650	680	2025-06-21	2026-06-21	0	2026-06-21	ACTIVO	1	2026-02-03 19:59:33.209583
651	682	2025-06-22	2026-06-22	0	2026-06-22	ACTIVO	1	2026-02-03 19:59:33.209583
652	684	2025-07-21	2026-07-21	0	2026-07-21	ACTIVO	1	2026-02-03 19:59:33.209583
653	685	2025-07-21	2026-07-21	0	2026-07-21	ACTIVO	1	2026-02-03 19:59:33.209583
654	686	2025-07-21	2026-07-21	0	2026-07-21	ACTIVO	1	2026-02-03 19:59:33.209583
655	688	2025-07-21	2026-07-21	0	2026-07-21	ACTIVO	1	2026-02-03 19:59:33.209583
656	689	2025-07-21	2026-07-21	0	2026-07-21	ACTIVO	1	2026-02-03 19:59:33.209583
657	690	2025-06-21	2026-06-21	0	2026-06-21	ACTIVO	1	2026-02-03 19:59:33.209583
658	691	2025-07-08	2026-07-08	0	2026-07-08	ACTIVO	1	2026-02-03 19:59:33.209583
659	692	2025-06-22	2026-06-22	0	2026-06-22	ACTIVO	1	2026-02-03 19:59:33.209583
660	693	2025-06-22	2026-06-22	0	2026-06-22	ACTIVO	1	2026-02-03 19:59:33.209583
661	694	2025-06-22	2026-06-22	0	2026-06-22	ACTIVO	1	2026-02-03 19:59:33.209583
662	695	2025-06-22	2026-06-22	0	2026-06-22	ACTIVO	1	2026-02-03 19:59:33.209583
663	696	2025-06-22	2026-06-22	0	2026-06-22	ACTIVO	1	2026-02-03 19:59:33.209583
664	698	2025-06-22	2026-06-22	0	2026-06-22	ACTIVO	1	2026-02-03 19:59:33.209583
665	700	2025-06-22	2026-06-22	0	2026-06-22	ACTIVO	1	2026-02-03 19:59:33.209583
666	701	2025-06-22	2026-06-22	0	2026-06-22	ACTIVO	1	2026-02-03 19:59:33.209583
667	703	2025-07-06	2026-07-06	0	2026-07-06	ACTIVO	1	2026-02-03 19:59:33.209583
668	704	2025-07-06	2026-07-06	0	2026-07-06	ACTIVO	1	2026-02-03 19:59:33.209583
669	707	2025-07-06	2026-07-06	0	2026-07-06	ACTIVO	1	2026-02-03 19:59:33.209583
670	709	2025-07-06	2026-07-06	0	2026-07-06	ACTIVO	1	2026-02-03 19:59:33.209583
671	710	2025-09-13	2026-09-13	0	2026-09-13	ACTIVO	1	2026-02-03 19:59:33.209583
672	711	2025-07-06	2026-07-06	0	2026-07-06	ACTIVO	1	2026-02-03 19:59:33.209583
673	712	2025-07-06	2026-07-06	0	2026-07-06	ACTIVO	1	2026-02-03 19:59:33.209583
674	713	2025-10-08	2026-10-08	0	2026-10-08	ACTIVO	1	2026-02-03 19:59:33.209583
675	714	2025-09-22	2026-09-22	0	2026-09-22	ACTIVO	1	2026-02-03 19:59:33.209583
676	715	2025-09-22	2026-09-22	0	2026-09-22	ACTIVO	1	2026-02-03 19:59:33.209583
677	716	2025-09-13	2026-09-13	0	2026-09-13	ACTIVO	1	2026-02-03 19:59:33.209583
678	717	2025-09-13	2026-09-13	0	2026-09-13	ACTIVO	1	2026-02-03 19:59:33.209583
679	718	2025-09-15	2026-09-15	0	2026-09-15	ACTIVO	1	2026-02-03 19:59:33.209583
680	720	2025-09-15	2026-09-15	0	2026-09-15	ACTIVO	1	2026-02-03 19:59:33.209583
681	722	2025-09-15	2026-09-15	0	2026-09-15	ACTIVO	1	2026-02-03 19:59:33.209583
682	723	2025-09-17	2026-09-17	0	2026-09-17	ACTIVO	1	2026-02-03 19:59:33.209583
683	726	2025-09-13	2026-09-13	0	2026-09-13	ACTIVO	1	2026-02-03 19:59:33.209583
684	728	2026-01-12	2027-01-12	0	2027-01-12	ACTIVO	1	2026-02-03 19:59:33.209583
685	729	2026-01-13	2027-01-13	0	2027-01-13	ACTIVO	1	2026-02-03 19:59:33.209583
686	734	2025-07-09	2026-07-09	0	2026-07-09	ACTIVO	1	2026-02-03 19:59:33.209583
687	735	2025-07-16	2026-07-16	0	2026-07-16	ACTIVO	1	2026-02-03 19:59:33.209583
688	736	2025-07-06	2026-07-06	0	2026-07-06	ACTIVO	1	2026-02-03 19:59:33.209583
689	738	2025-07-06	2026-07-06	0	2026-07-06	ACTIVO	1	2026-02-03 19:59:33.209583
690	739	2025-07-08	2026-07-08	0	2026-07-08	ACTIVO	1	2026-02-03 19:59:33.209583
691	740	2025-07-22	2026-07-22	0	2026-07-22	ACTIVO	1	2026-02-03 19:59:33.209583
692	741	2025-07-08	2026-07-08	0	2026-07-08	ACTIVO	1	2026-02-03 19:59:33.209583
693	742	2025-07-08	2026-07-08	0	2026-07-08	ACTIVO	1	2026-02-03 19:59:33.209583
694	746	2025-07-07	2026-07-07	0	2026-07-07	ACTIVO	1	2026-02-03 19:59:33.209583
695	747	2025-07-07	2026-07-07	0	2026-07-07	ACTIVO	1	2026-02-03 19:59:33.209583
696	748	2025-07-07	2026-07-07	0	2026-07-07	ACTIVO	1	2026-02-03 19:59:33.209583
697	750	2025-09-14	2026-09-14	0	2026-09-14	ACTIVO	1	2026-02-03 19:59:33.209583
698	751	2025-07-09	2026-07-09	0	2026-07-09	ACTIVO	1	2026-02-03 19:59:33.209583
699	752	2025-08-07	2026-08-07	0	2026-08-07	ACTIVO	1	2026-02-03 19:59:33.209583
700	753	2025-07-31	2026-07-31	0	2026-07-31	ACTIVO	1	2026-02-03 19:59:33.209583
701	754	2025-07-19	2026-07-19	0	2026-07-19	ACTIVO	1	2026-02-03 19:59:33.209583
702	755	2025-07-13	2026-07-13	0	2026-07-13	ACTIVO	1	2026-02-03 19:59:33.209583
703	756	2025-08-08	2026-08-08	0	2026-08-08	ACTIVO	1	2026-02-03 19:59:33.209583
704	758	2025-07-08	2026-07-08	0	2026-07-08	ACTIVO	1	2026-02-03 19:59:33.209583
705	759	2025-07-18	2026-07-18	0	2026-07-18	ACTIVO	1	2026-02-03 19:59:33.209583
706	761	2025-07-23	2026-07-23	0	2026-07-23	ACTIVO	1	2026-02-03 19:59:33.209583
707	762	2025-07-23	2026-07-23	0	2026-07-23	ACTIVO	1	2026-02-03 19:59:33.209583
708	767	2025-07-15	2026-07-15	0	2026-07-15	ACTIVO	1	2026-02-03 19:59:33.209583
709	768	2025-07-15	2026-07-15	0	2026-07-15	ACTIVO	1	2026-02-03 19:59:33.209583
710	769	2025-06-23	2026-06-23	0	2026-06-23	ACTIVO	1	2026-02-03 19:59:33.209583
711	770	2025-06-25	2026-06-25	0	2026-06-25	ACTIVO	1	2026-02-03 19:59:33.209583
712	771	2025-06-25	2026-06-25	0	2026-06-25	ACTIVO	1	2026-02-03 19:59:33.209583
713	772	2025-06-18	2026-06-18	0	2026-06-18	ACTIVO	1	2026-02-03 19:59:33.209583
714	773	2025-08-31	2026-08-31	0	2026-08-31	ACTIVO	1	2026-02-03 19:59:33.209583
715	776	2025-08-01	2026-08-01	0	2026-08-01	ACTIVO	1	2026-02-03 19:59:33.209583
716	777	2025-07-02	2026-07-02	0	2026-07-02	ACTIVO	1	2026-02-03 19:59:33.209583
717	778	2025-07-29	2026-07-29	0	2026-07-29	ACTIVO	1	2026-02-03 19:59:33.209583
718	779	2025-07-29	2026-07-29	0	2026-07-29	ACTIVO	1	2026-02-03 19:59:33.209583
719	780	2025-07-02	2026-07-02	0	2026-07-02	ACTIVO	1	2026-02-03 19:59:33.209583
720	781	2025-06-29	2026-06-29	0	2026-06-29	ACTIVO	1	2026-02-03 19:59:33.209583
721	782	2025-07-28	2026-07-28	0	2026-07-28	ACTIVO	1	2026-02-03 19:59:33.209583
722	783	2025-06-30	2026-06-30	0	2026-06-30	ACTIVO	1	2026-02-03 19:59:33.209583
723	784	2025-10-10	2026-10-10	0	2026-10-10	ACTIVO	1	2026-02-03 19:59:33.209583
724	785	2025-08-20	2026-08-20	0	2026-08-20	ACTIVO	1	2026-02-03 19:59:33.209583
725	786	2025-06-23	2026-06-23	0	2026-06-23	ACTIVO	1	2026-02-03 19:59:33.209583
726	787	2025-01-28	2026-01-28	0	2026-01-28	VENCIDO	1	2026-02-03 19:59:33.209583
727	788	2025-07-23	2026-07-23	0	2026-07-23	ACTIVO	1	2026-02-03 19:59:33.209583
728	789	2025-07-22	2026-07-22	0	2026-07-22	ACTIVO	1	2026-02-03 19:59:33.209583
729	790	2025-07-19	2026-07-19	0	2026-07-19	ACTIVO	1	2026-02-03 19:59:33.209583
730	791	2025-07-23	2026-07-23	0	2026-07-23	ACTIVO	1	2026-02-03 19:59:33.209583
731	792	2025-07-28	2026-07-28	0	2026-07-28	ACTIVO	1	2026-02-03 19:59:33.209583
732	793	2025-08-06	2026-08-06	0	2026-08-06	ACTIVO	1	2026-02-03 19:59:33.209583
733	794	2025-08-20	2026-08-20	0	2026-08-20	ACTIVO	1	2026-02-03 19:59:33.209583
734	796	2025-08-20	2026-08-20	0	2026-08-20	ACTIVO	1	2026-02-03 19:59:33.209583
735	797	2025-09-03	2026-09-03	0	2026-09-03	ACTIVO	1	2026-02-03 19:59:33.209583
736	798	2025-08-22	2026-08-22	0	2026-08-22	ACTIVO	1	2026-02-03 19:59:33.209583
737	799	2025-07-21	2026-07-21	0	2026-07-21	ACTIVO	1	2026-02-03 19:59:33.209583
738	801	2025-07-30	2026-07-30	0	2026-07-30	ACTIVO	1	2026-02-03 19:59:33.209583
739	802	2025-07-28	2026-07-28	0	2026-07-28	ACTIVO	1	2026-02-03 19:59:33.209583
740	803	2025-07-29	2026-07-29	0	2026-07-29	ACTIVO	1	2026-02-03 19:59:33.209583
741	804	2025-07-28	2026-07-28	0	2026-07-28	ACTIVO	1	2026-02-03 19:59:33.209583
742	805	2025-07-28	2026-07-28	0	2026-07-28	ACTIVO	1	2026-02-03 19:59:33.209583
743	806	2025-07-22	2026-07-22	0	2026-07-22	ACTIVO	1	2026-02-03 19:59:33.209583
744	807	2025-07-26	2026-07-26	0	2026-07-26	ACTIVO	1	2026-02-03 19:59:33.209583
745	808	2025-08-07	2026-08-07	0	2026-08-07	ACTIVO	1	2026-02-03 19:59:33.209583
746	809	2025-07-26	2026-07-26	0	2026-07-26	ACTIVO	1	2026-02-03 19:59:33.209583
747	811	2025-07-23	2026-07-23	0	2026-07-23	ACTIVO	1	2026-02-03 19:59:33.209583
748	812	2025-07-24	2026-07-24	0	2026-07-24	ACTIVO	1	2026-02-03 19:59:33.209583
749	814	2025-08-20	2026-08-20	0	2026-08-20	ACTIVO	1	2026-02-03 19:59:33.209583
750	815	2025-07-18	2026-07-18	0	2026-07-18	ACTIVO	1	2026-02-03 19:59:33.209583
751	816	2025-07-18	2026-07-18	0	2026-07-18	ACTIVO	1	2026-02-03 19:59:33.209583
752	817	2025-07-23	2026-07-23	0	2026-07-23	ACTIVO	1	2026-02-03 19:59:33.209583
753	818	2025-07-21	2026-07-21	0	2026-07-21	ACTIVO	1	2026-02-03 19:59:33.209583
754	819	2025-07-28	2026-07-28	0	2026-07-28	ACTIVO	1	2026-02-03 19:59:33.209583
755	820	2025-07-22	2026-07-22	0	2026-07-22	ACTIVO	1	2026-02-03 19:59:33.209583
756	821	2025-08-01	2026-08-01	0	2026-08-01	ACTIVO	1	2026-02-03 19:59:33.209583
757	822	2025-07-24	2026-07-24	0	2026-07-24	ACTIVO	1	2026-02-03 19:59:33.209583
758	823	2025-07-24	2026-07-24	0	2026-07-24	ACTIVO	1	2026-02-03 19:59:33.209583
759	824	2025-08-05	2026-08-05	0	2026-08-05	ACTIVO	1	2026-02-03 19:59:33.209583
760	825	2025-08-05	2026-08-05	0	2026-08-05	ACTIVO	1	2026-02-03 19:59:33.209583
761	826	2025-08-20	2026-08-20	0	2026-08-20	ACTIVO	1	2026-02-03 19:59:33.209583
762	827	2025-08-07	2026-08-07	0	2026-08-07	ACTIVO	1	2026-02-03 19:59:33.209583
763	828	2025-08-07	2026-08-07	0	2026-08-07	ACTIVO	1	2026-02-03 19:59:33.209583
764	829	2025-08-05	2026-08-05	0	2026-08-05	ACTIVO	1	2026-02-03 19:59:33.209583
765	830	2025-08-05	2026-08-05	0	2026-08-05	ACTIVO	1	2026-02-03 19:59:33.209583
766	831	2025-08-05	2026-08-05	0	2026-08-05	ACTIVO	1	2026-02-03 19:59:33.209583
767	832	2025-08-05	2026-08-05	0	2026-08-05	ACTIVO	1	2026-02-03 19:59:33.209583
768	833	2025-08-21	2026-08-21	0	2026-08-21	ACTIVO	1	2026-02-03 19:59:33.209583
769	834	2025-08-27	2026-08-27	0	2026-08-27	ACTIVO	1	2026-02-03 19:59:33.209583
770	835	2025-08-20	2026-08-20	0	2026-08-20	ACTIVO	1	2026-02-03 19:59:33.209583
771	836	2025-08-22	2026-08-22	0	2026-08-22	ACTIVO	1	2026-02-03 19:59:33.209583
772	837	2025-08-05	2026-08-05	0	2026-08-05	ACTIVO	1	2026-02-03 19:59:33.209583
773	838	2025-08-07	2026-08-07	0	2026-08-07	ACTIVO	1	2026-02-03 19:59:33.209583
774	839	2025-08-04	2026-08-04	0	2026-08-04	ACTIVO	1	2026-02-03 19:59:33.209583
775	840	2025-08-18	2026-08-18	0	2026-08-18	ACTIVO	1	2026-02-03 19:59:33.209583
776	841	2025-09-01	2026-09-01	0	2026-09-01	ACTIVO	1	2026-02-03 19:59:33.209583
777	843	2025-09-09	2026-09-09	0	2026-09-09	ACTIVO	1	2026-02-03 19:59:33.209583
778	844	2025-09-09	2026-09-09	0	2026-09-09	ACTIVO	1	2026-02-03 19:59:33.209583
779	845	2025-08-04	2026-08-04	0	2026-08-04	ACTIVO	1	2026-02-03 19:59:33.209583
780	846	2025-08-29	2026-08-29	0	2026-08-29	ACTIVO	1	2026-02-03 19:59:33.209583
781	847	2025-08-29	2026-08-29	0	2026-08-29	ACTIVO	1	2026-02-03 19:59:33.209583
782	848	2025-09-09	2026-09-09	0	2026-09-09	ACTIVO	1	2026-02-03 19:59:33.209583
783	849	2025-10-09	2026-10-09	0	2026-10-09	ACTIVO	1	2026-02-03 19:59:33.209583
784	851	2025-10-22	2026-10-22	0	2026-10-22	ACTIVO	1	2026-02-03 19:59:33.209583
785	852	2025-09-12	2026-09-12	0	2026-09-12	ACTIVO	1	2026-02-03 19:59:33.209583
786	853	2025-09-08	2026-09-08	0	2026-09-08	ACTIVO	1	2026-02-03 19:59:33.209583
787	854	2025-09-12	2026-09-12	0	2026-09-12	ACTIVO	1	2026-02-03 19:59:33.209583
788	855	2025-09-17	2026-09-17	0	2026-09-17	ACTIVO	1	2026-02-03 19:59:33.209583
789	856	2025-09-12	2026-09-12	0	2026-09-12	ACTIVO	1	2026-02-03 19:59:33.209583
790	857	2025-09-08	2026-09-08	0	2026-09-08	ACTIVO	1	2026-02-03 19:59:33.209583
791	858	2025-09-30	2026-09-30	0	2026-09-30	ACTIVO	1	2026-02-03 19:59:33.209583
792	859	2025-09-22	2026-09-22	0	2026-09-22	ACTIVO	1	2026-02-03 19:59:33.209583
793	861	2025-09-22	2026-09-22	0	2026-09-22	ACTIVO	1	2026-02-03 19:59:33.209583
794	863	2025-09-25	2026-09-25	0	2026-09-25	ACTIVO	1	2026-02-03 19:59:33.209583
795	864	2025-12-07	2026-12-07	0	2026-12-07	ACTIVO	1	2026-02-03 19:59:33.209583
796	865	2025-09-24	2026-09-24	0	2026-09-24	ACTIVO	1	2026-02-03 19:59:33.209583
797	866	2025-09-23	2026-09-23	0	2026-09-23	ACTIVO	1	2026-02-03 19:59:33.209583
798	867	2025-10-17	2026-10-17	0	2026-10-17	ACTIVO	1	2026-02-03 19:59:33.209583
799	868	2025-09-24	2026-09-24	0	2026-09-24	ACTIVO	1	2026-02-03 19:59:33.209583
800	869	2025-03-22	2026-03-22	0	2026-03-22	ACTIVO	1	2026-02-03 19:59:33.209583
801	870	2025-09-21	2026-09-21	0	2026-09-21	ACTIVO	1	2026-02-03 19:59:33.209583
802	871	2025-09-22	2026-09-22	0	2026-09-22	ACTIVO	1	2026-02-03 19:59:33.209583
803	872	2025-09-21	2026-09-21	0	2026-09-21	ACTIVO	1	2026-02-03 19:59:33.209583
804	874	2025-09-22	2026-09-22	0	2026-09-22	ACTIVO	1	2026-02-03 19:59:33.209583
805	876	2025-09-22	2026-09-22	0	2026-09-22	ACTIVO	1	2026-02-03 19:59:33.209583
806	878	2025-09-30	2026-09-30	0	2026-09-30	ACTIVO	1	2026-02-03 19:59:33.209583
807	879	2025-10-15	2026-10-15	0	2026-10-15	ACTIVO	1	2026-02-03 19:59:33.209583
808	880	2025-10-20	2026-10-20	0	2026-10-20	ACTIVO	1	2026-02-03 19:59:33.209583
809	881	2025-09-19	2026-09-19	0	2026-09-19	ACTIVO	1	2026-02-03 19:59:33.209583
810	882	2025-09-19	2026-09-19	0	2026-09-19	ACTIVO	1	2026-02-03 19:59:33.209583
811	883	2025-09-19	2026-09-19	0	2026-09-19	ACTIVO	1	2026-02-03 19:59:33.209583
812	884	2025-09-19	2026-09-19	0	2026-09-19	ACTIVO	1	2026-02-03 19:59:33.209583
813	885	2025-09-24	2026-09-24	0	2026-09-24	ACTIVO	1	2026-02-03 19:59:33.209583
814	886	2025-09-30	2026-09-30	0	2026-09-30	ACTIVO	1	2026-02-03 19:59:33.209583
815	887	2025-10-22	2026-10-22	0	2026-10-22	ACTIVO	1	2026-02-03 19:59:33.209583
\.


--
-- TOC entry 5121 (class 0 OID 16562)
-- Dependencies: 234
-- Data for Name: alertas_sistema; Type: TABLE DATA; Schema: public; Owner: vpn_user
--

COPY public.alertas_sistema (id, tipo, acceso_vpn_id, mensaje, fecha_generacion, leida, fecha_lectura) FROM stdin;
\.


--
-- TOC entry 5115 (class 0 OID 16511)
-- Dependencies: 228
-- Data for Name: archivos_adjuntos; Type: TABLE DATA; Schema: public; Owner: vpn_user
--

COPY public.archivos_adjuntos (id, carta_id, nombre_archivo, ruta_archivo, tipo_mime, hash_integridad, tamano_bytes, fecha_subida, usuario_subida_id) FROM stdin;
\.


--
-- TOC entry 5119 (class 0 OID 16547)
-- Dependencies: 232
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
266	1	DESACTIVAR_USUARIO	USUARIO	2	{"username": "jcate", "nuevo_estado": false}	127.0.0.1	2026-01-10 15:15:42.74331
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
267	\N	LOGIN_FALLIDO	SISTEMA	\N	{"username": "jcate"}	127.0.0.1	2026-01-10 15:16:19.609118
160	1	CREAR	CARTA	24	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_24_4567891237894.pdf", "acceso_id": 22, "pdf_generado": true, "solicitud_id": 38}	127.0.0.1	2026-01-03 10:15:05.619192
161	1	BLOQUEAR	ACCESO	22	{"motivo": "CAUSO ALTA"}	127.0.0.1	2026-01-03 10:16:12.446841
162	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-03 10:39:16.866102
163	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-03 12:30:03.014718
164	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-03 13:57:41.358522
165	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-03 14:09:01.887334
166	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-03 14:18:53.316877
167	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-03 14:22:13.279418
168	1	CREAR	PERSONA	1	{"dpi": "1234567891023", "nombre_completo": "Primera Prueba Del Sistema"}	127.0.0.1	2026-01-03 14:39:04.339923
169	1	CREAR	SOLICITUD	6	{"tipo": "ACTUALIZACION", "estado": "APROBADA", "persona_dpi": "1234567891023", "persona_nip": "11111-P"}	127.0.0.1	2026-01-03 14:57:18.324619
170	1	CREAR	SOLICITUD_EDICION	6	{"accion": "EDITAR", "campos_modificados": ["numero_oficio", "numero_providencia", "fecha_recepcion", "tipo_solicitud", "justificacion"]}	127.0.0.1	2026-01-03 14:59:03.033797
171	1	CREAR	SOLICITUD_EDICION	6	{"accion": "EDITAR", "campos_modificados": ["numero_oficio", "numero_providencia", "fecha_recepcion", "tipo_solicitud", "justificacion"]}	127.0.0.1	2026-01-03 15:00:57.63453
172	1	CREAR	PERSONA	2	{"dpi": "1425367894152", "nombre_completo": "Segunda Prueba Del Sistema"}	127.0.0.1	2026-01-03 15:02:46.251859
173	1	CREAR	SOLICITUD	7	{"tipo": "NUEVA", "estado": "APROBADA", "persona_dpi": "1425367894152", "persona_nip": "22345-P"}	127.0.0.1	2026-01-03 15:02:58.783241
174	1	CREAR	SOLICITUD_EDICION	7	{"accion": "EDITAR", "campos_modificados": ["numero_oficio", "numero_providencia", "fecha_recepcion", "tipo_solicitud", "justificacion"]}	127.0.0.1	2026-01-03 15:03:18.914117
175	1	CREAR	SOLICITUD_EDICION	7	{"accion": "EDITAR", "campos_modificados": ["numero_oficio", "numero_providencia", "fecha_recepcion", "tipo_solicitud", "justificacion"]}	127.0.0.1	2026-01-03 15:03:33.893182
176	1	CREAR	CARTA	1	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_1_1234567891023.pdf", "acceso_id": 1, "pdf_generado": true, "solicitud_id": 6}	127.0.0.1	2026-01-03 15:03:44.071182
177	1	CREAR	CARTA	2	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_2_1425367894152.pdf", "acceso_id": 2, "pdf_generado": true, "solicitud_id": 7}	127.0.0.1	2026-01-03 15:03:54.958002
178	1	CREAR	PERSONA	1	{"dpi": "1234567891234", "nombre_completo": "Primera Prueba Del Sistema"}	127.0.0.1	2026-01-03 15:14:07.724781
179	1	CREAR	SOLICITUD	1	{"tipo": "NUEVA", "estado": "APROBADA", "persona_dpi": "1234567891234", "persona_nip": "78878-P"}	127.0.0.1	2026-01-03 15:14:24.019904
180	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-03 15:26:29.316912
181	1	CREAR	SOLICITUD_EDICION	1	{"accion": "EDITAR", "campos_modificados": ["numero_oficio", "numero_providencia", "fecha_recepcion", "tipo_solicitud", "justificacion"]}	127.0.0.1	2026-01-03 15:29:18.179845
182	1	CREAR	PERSONA	2	{"dpi": "1111122222333", "nombre_completo": "Primera Prueba Prueba Cartas"}	127.0.0.1	2026-01-03 15:30:27.785431
183	1	CREAR	SOLICITUD	2	{"tipo": "NUEVA", "estado": "PENDIENTE", "persona_dpi": "1111122222333", "persona_nip": "11111-P"}	127.0.0.1	2026-01-03 15:30:39.237623
184	1	CREAR	CARTA	1	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_1_1111122222333.pdf", "acceso_id": 1, "pdf_generado": true, "solicitud_id": 2}	127.0.0.1	2026-01-03 15:35:41.663764
185	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-03 18:15:54.067818
186	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-03 18:31:03.569835
187	1	BLOQUEAR	ACCESO	22	{"motivo": "finalizo la vigencia de la carta"}	127.0.0.1	2026-01-03 18:42:16.550731
188	1	BLOQUEAR	ACCESO	229	{"motivo": "finalizo la vigencia del usuario"}	127.0.0.1	2026-01-03 18:42:49.132008
189	1	BLOQUEAR	ACCESO	39	{"motivo": "finalizo vigencia del usuario"}	127.0.0.1	2026-01-03 18:43:56.964844
190	1	BLOQUEAR	ACCESO	231	{"motivo": "vencio la vigencia"}	127.0.0.1	2026-01-03 18:44:28.352313
191	1	BLOQUEAR	ACCESO	280	{"motivo": "vencio vigencia del usuario\\n"}	127.0.0.1	2026-01-03 18:45:17.562027
192	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-03 19:42:38.414778
193	1	BLOQUEAR	ACCESO	292	{"motivo": "vencimiento"}	127.0.0.1	2026-01-03 19:43:11.847503
194	1	BLOQUEAR	ACCESO	236	{"motivo": "vencimiento"}	127.0.0.1	2026-01-03 19:43:20.092497
195	1	BLOQUEAR	ACCESO	234	{"motivo": "vencimiento"}	127.0.0.1	2026-01-03 19:43:28.31352
196	1	BLOQUEAR	ACCESO	39	{"motivo": "vencimiento"}	127.0.0.1	2026-01-03 19:43:35.665675
197	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-03 21:10:25.805292
198	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-04 08:13:56.881795
199	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-04 08:21:16.820405
200	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-04 09:26:12.657508
201	1	BLOQUEAR	ACCESO	550	{"motivo": "finalizo el tiempo"}	127.0.0.1	2026-01-04 10:22:22.415105
202	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-04 10:27:15.152568
203	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-04 17:02:45.980577
204	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-04 18:08:30.680673
205	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-04 19:09:19.756043
206	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-04 21:20:09.304796
207	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-08 16:58:39.833532
208	1	BLOQUEAR	ACCESO	513	{"motivo": "vencimiento\\n"}	127.0.0.1	2026-01-08 17:05:34.109487
209	1	CREAR	PERSONA	820	{"dpi": "3084855560404", "nombre_completo": "Jonathan Miguel Cate Catu"}	127.0.0.1	2026-01-08 17:09:57.454688
210	1	CREAR	SOLICITUD	1105	{"tipo": "NUEVA", "estado": "PENDIENTE", "persona_dpi": "3084855560404", "persona_nip": "63975-P"}	127.0.0.1	2026-01-08 17:10:34.562198
211	1	CREAR	CARTA	971	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_971_3084855560404.pdf", "acceso_id": 1000, "pdf_generado": true, "solicitud_id": 1105}	127.0.0.1	2026-01-08 17:10:50.556631
212	1	CREAR	PERSONA	821	{"dpi": "1234567891023", "nombre_completo": "Prueba Del Sistema Cartas"}	127.0.0.1	2026-01-08 17:26:32.211409
213	1	CREAR	SOLICITUD	1106	{"tipo": "NUEVA", "estado": "PENDIENTE", "persona_dpi": "1234567891023", "persona_nip": "12345-P"}	127.0.0.1	2026-01-08 17:26:45.399342
214	1	CREAR	CARTA	972	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_972_1234567891023.pdf", "acceso_id": 1001, "anio_carta": 2026, "numero_carta": 2025, "pdf_generado": true, "solicitud_id": 1106}	127.0.0.1	2026-01-08 17:26:59.455442
215	1	CREAR	PERSONA	822	{"dpi": "7894561237894", "nombre_completo": "Segunda Prueba Del Sistema"}	127.0.0.1	2026-01-08 17:35:22.193933
216	1	CREAR	SOLICITUD	1107	{"tipo": "NUEVA", "estado": "PENDIENTE", "persona_dpi": "7894561237894", "persona_nip": "11111-P"}	127.0.0.1	2026-01-08 17:35:43.605687
217	1	CREAR	CARTA	973	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_973_7894561237894.pdf", "acceso_id": 1002, "anio_carta": 2026, "numero_carta": 2026, "pdf_generado": true, "solicitud_id": 1107}	127.0.0.1	2026-01-08 17:36:16.674789
218	1	CREAR	PERSONA	820	{"dpi": "1234567897894", "nombre_completo": "Primera Prueba Del Sistema"}	127.0.0.1	2026-01-08 17:39:37.290854
219	1	CREAR	SOLICITUD	1105	{"tipo": "NUEVA", "estado": "PENDIENTE", "persona_dpi": "1234567897894", "persona_nip": "11111-P"}	127.0.0.1	2026-01-08 17:39:47.70258
220	1	CREAR	CARTA	971	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_971_1234567897894.pdf", "acceso_id": 998, "anio_carta": 2026, "numero_carta": 2025, "pdf_generado": true, "solicitud_id": 1105}	127.0.0.1	2026-01-08 17:40:02.15993
221	1	CREAR	PERSONA	820	{"dpi": "1111122222333", "nombre_completo": "Jonathan Cate"}	127.0.0.1	2026-01-08 17:51:16.46387
222	1	CREAR	SOLICITUD	1105	{"tipo": "NUEVA", "estado": "PENDIENTE", "persona_dpi": "1111122222333", "persona_nip": "63975-P"}	127.0.0.1	2026-01-08 17:51:27.215451
223	1	CREAR	CARTA	971	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_971_1111122222333.pdf", "acceso_id": 998, "anio_carta": 2026, "numero_carta": 2025, "pdf_generado": true, "solicitud_id": 1105}	127.0.0.1	2026-01-08 17:52:22.287784
224	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-08 18:10:13.392388
225	1	CREAR	PERSONA	820	{"dpi": "1234567891234", "nombre_completo": "Primera Prueba Del Sistema"}	127.0.0.1	2026-01-08 18:11:26.531251
226	1	CREAR	SOLICITUD	1105	{"tipo": "NUEVA", "estado": "PENDIENTE", "persona_dpi": "1234567891234", "persona_nip": "11111-P"}	127.0.0.1	2026-01-08 18:11:51.752705
227	1	CREAR	CARTA	971	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_971_1234567891234.pdf", "acceso_id": 998, "anio_carta": 2026, "numero_carta": 2025, "pdf_generado": true, "solicitud_id": 1105}	127.0.0.1	2026-01-08 18:14:14.391621
228	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-08 20:42:00.349005
229	1	CREAR	PERSONA	821	{"dpi": "1234567891234", "nombre_completo": "Primera Prueba Del Sistema"}	127.0.0.1	2026-01-08 20:55:47.933053
230	1	CREAR	SOLICITUD	1106	{"tipo": "NUEVA", "estado": "PENDIENTE", "persona_dpi": "1234567891234", "persona_nip": "11111-P"}	127.0.0.1	2026-01-08 20:56:01.599264
231	1	CREAR	CARTA	977	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_977_1234567891234.pdf", "acceso_id": 1022, "anio_carta": 2026, "numero_carta": 14, "pdf_generado": true, "solicitud_id": 1106}	127.0.0.1	2026-01-08 20:56:18.560578
232	1	CREAR	CARTA	978	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_978_1707212481610.pdf", "acceso_id": 1023, "anio_carta": 2026, "numero_carta": 15, "pdf_generado": true, "solicitud_id": 1103}	127.0.0.1	2026-01-08 20:59:08.077978
233	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-10 08:32:14.018965
234	1	BLOQUEAR	ACCESO	347	{"motivo": "finalizo fecha de vencimiento\\n"}	127.0.0.1	2026-01-10 08:33:32.555426
235	1	BLOQUEAR	ACCESO	282	{"motivo": "finalizo fecha de vencimiento\\n"}	127.0.0.1	2026-01-10 08:33:53.230949
236	1	BLOQUEAR	ACCESO	330	{"motivo": "finalizo fecha de vencimiento\\n"}	127.0.0.1	2026-01-10 08:34:06.749497
237	1	BLOQUEAR	ACCESO	1004	{"motivo": "finalizo fecha de vencimiento"}	127.0.0.1	2026-01-10 08:34:39.585747
238	1	BLOQUEAR	ACCESO	984	{"motivo": "finalizo fecha de vencimiento"}	127.0.0.1	2026-01-10 08:34:56.64865
239	1	BLOQUEAR	ACCESO	1021	{"motivo": "finalizo fecha de vencimiento\\n"}	127.0.0.1	2026-01-10 08:35:13.273409
240	1	BLOQUEAR	ACCESO	471	{"motivo": "finalizo fecha de vencimiento\\n"}	127.0.0.1	2026-01-10 08:35:19.557017
241	1	BLOQUEAR	ACCESO	292	{"motivo": "finalizo fecha de vencimiento\\n"}	127.0.0.1	2026-01-10 08:35:26.132372
242	1	BLOQUEAR	ACCESO	293	{"motivo": "finalizo fecha de vencimiento\\n"}	127.0.0.1	2026-01-10 08:35:34.148162
243	1	BLOQUEAR	ACCESO	351	{"motivo": "finalizo fecha de vencimiento\\n"}	127.0.0.1	2026-01-10 08:35:44.981718
244	1	BLOQUEAR	ACCESO	190	{"motivo": "finalizo fecha de vencimiento"}	127.0.0.1	2026-01-10 08:37:11.810517
245	1	BLOQUEAR	ACCESO	309	{"motivo": "finalizo fecha de vencimiento"}	127.0.0.1	2026-01-10 08:37:47.4035
246	1	BLOQUEAR	ACCESO	22	{"motivo": "FINALIZO FECHA DE VENCIMIENTO"}	127.0.0.1	2026-01-10 08:39:14.572645
247	1	BLOQUEAR	ACCESO	239	{"motivo": "FINALIZO FECHA DE VENCIMIENTO"}	127.0.0.1	2026-01-10 08:40:12.175608
248	1	BLOQUEAR	ACCESO	237	{"motivo": "FINALIZO FECHA DE VENCIMIENTO"}	127.0.0.1	2026-01-10 08:40:55.195124
249	1	BLOQUEAR	ACCESO	295	{"motivo": "FINALIZO FECHA DE VENCIMIENTO"}	127.0.0.1	2026-01-10 08:41:43.260139
250	1	BLOQUEAR	ACCESO	39	{"motivo": "finalizo vigencia"}	127.0.0.1	2026-01-10 08:42:41.246208
251	1	BLOQUEAR	ACCESO	285	{"motivo": "finalizo vigencia"}	127.0.0.1	2026-01-10 08:46:00.20246
252	1	BLOQUEAR	ACCESO	194	{"motivo": "finalizo vigencia"}	127.0.0.1	2026-01-10 08:51:25.155524
253	1	BLOQUEAR	ACCESO	205	{"motivo": "finalizo vigencia"}	127.0.0.1	2026-01-10 08:52:14.722998
254	1	CREAR	CARTA	979	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_979_3389318561001.pdf", "acceso_id": 1024, "anio_carta": 2026, "numero_carta": 16, "pdf_generado": true, "solicitud_id": 1102}	127.0.0.1	2026-01-10 08:57:15.425132
255	1	CREAR	CARTA	980	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_980_2426118180101.pdf", "acceso_id": 1025, "anio_carta": 2026, "numero_carta": 17, "pdf_generado": true, "solicitud_id": 1076}	127.0.0.1	2026-01-10 08:57:41.466761
256	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-10 11:20:21.066059
257	1	BLOQUEAR	ACCESO	134	{"motivo": "FECHA DE VENCIMIENTO"}	127.0.0.1	2026-01-10 11:21:20.24139
258	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-10 11:54:24.871032
259	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-10 12:54:42.924925
260	1	CREAR_USUARIO_SISTEMA	USUARIO	2	{"rol": "ADMIN", "username": "jcate", "nombre_completo": "JONATHAN MIGUEL CATE CATU"}	127.0.0.1	2026-01-10 12:55:40.02208
261	2	LOGIN_EXITOSO	SISTEMA	\N	{"username": "jcate"}	127.0.0.1	2026-01-10 12:56:53.665305
262	2	CREAR	SOLICITUD	1107	{"tipo": "ACTUALIZACION", "estado": "PENDIENTE", "persona_dpi": "2352449960610", "persona_nip": "49010-P"}	127.0.0.1	2026-01-10 12:59:10.293348
263	2	CREAR	CARTA	981	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_981_2352449960610.pdf", "acceso_id": 1026, "anio_carta": 2026, "numero_carta": 18, "pdf_generado": true, "solicitud_id": 1107}	127.0.0.1	2026-01-10 12:59:50.560815
264	2	LOGIN_EXITOSO	SISTEMA	\N	{"username": "jcate"}	127.0.0.1	2026-01-10 14:14:24.179964
265	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-10 15:15:27.672556
268	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-10 15:16:44.339443
269	1	ACTIVAR_USUARIO	USUARIO	2	{"username": "jcate", "nuevo_estado": true}	127.0.0.1	2026-01-10 15:16:50.969211
270	2	LOGIN_EXITOSO	SISTEMA	\N	{"username": "jcate"}	127.0.0.1	2026-01-10 15:17:11.274908
271	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-10 15:17:30.508059
272	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-10 16:17:47.708071
273	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-10 17:31:06.0992
274	1	DESBLOQUEAR	ACCESO	398	{"motivo": "aun activo"}	127.0.0.1	2026-01-10 17:53:44.431681
275	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-10 18:32:33.522204
276	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-10 19:33:29.03891
277	\N	LOGIN_FALLIDO	SISTEMA	\N	{"username": "jcate"}	127.0.0.1	2026-01-10 20:37:33.917997
278	2	LOGIN_EXITOSO	SISTEMA	\N	{"username": "jcate"}	127.0.0.1	2026-01-10 20:37:56.222187
279	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-14 08:27:48.747115
280	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-14 09:33:05.098343
281	1	CREAR	CARTA	982	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_982_2600358900410.pdf", "acceso_id": 1027, "anio_carta": 2026, "numero_carta": 19, "pdf_generado": true, "solicitud_id": 1084}	127.0.0.1	2026-01-14 09:42:43.146686
282	1	RESETEAR_PASSWORD	USUARIO	2	{"mensaje": "Contraseña reseteada para usuario jcate"}	127.0.0.1	2026-01-14 09:56:21.844923
283	2	LOGIN_EXITOSO	SISTEMA	\N	{"username": "jcate"}	127.0.0.1	2026-01-14 09:56:33.418615
284	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-14 10:03:50.11038
285	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-14 10:36:14.552771
286	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-14 10:36:32.783791
287	2	LOGIN_EXITOSO	SISTEMA	\N	{"username": "jcate"}	127.0.0.1	2026-01-14 10:38:23.215359
288	2	CAMBIAR_PASSWORD	USUARIO	2	{"mensaje": "Contraseña cambiada por el usuario"}	127.0.0.1	2026-01-14 10:45:49.952931
289	2	LOGIN_EXITOSO	SISTEMA	\N	{"username": "jcate"}	127.0.0.1	2026-01-14 10:46:05.038268
290	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-14 12:02:34.295825
291	1	CREAR	CARTA	983	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_983_1732490000404.pdf", "acceso_id": 1028, "anio_carta": 2026, "numero_carta": 20, "pdf_generado": true, "solicitud_id": 677}	127.0.0.1	2026-01-14 12:30:34.074635
292	2	LOGIN_EXITOSO	SISTEMA	\N	{"username": "jcate"}	127.0.0.1	2026-01-14 12:35:10.672137
293	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-14 12:36:19.024643
294	2	LOGIN_EXITOSO	SISTEMA	\N	{"username": "jcate"}	127.0.0.1	2026-01-14 12:46:17.257046
295	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-14 12:46:51.030069
296	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-14 14:18:33.156001
297	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-14 14:18:49.237011
298	2	LOGIN_EXITOSO	SISTEMA	\N	{"username": "jcate"}	127.0.0.1	2026-01-14 14:19:09.157943
299	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-14 14:20:03.171994
300	2	LOGIN_EXITOSO	SISTEMA	\N	{"username": "jcate"}	127.0.0.1	2026-01-14 14:23:30.343567
301	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-14 14:23:43.5069
302	2	LOGIN_EXITOSO	SISTEMA	\N	{"username": "jcate"}	127.0.0.1	2026-01-14 14:24:13.334268
303	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-14 14:29:42.831483
304	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-14 14:32:54.320488
305	2	LOGIN_EXITOSO	SISTEMA	\N	{"username": "jcate"}	127.0.0.1	2026-01-14 14:34:30.64048
306	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-14 14:34:36.00882
307	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-14 14:36:19.159563
308	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-14 15:37:40.429317
309	1	DESACTIVAR_USUARIO	USUARIO	2	{"username": "jcate", "nuevo_estado": false}	127.0.0.1	2026-01-14 15:47:59.918537
310	1	ACTIVAR_USUARIO	USUARIO	2	{"username": "jcate", "nuevo_estado": true}	127.0.0.1	2026-01-14 15:48:07.71929
311	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-14 17:02:11.125436
312	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-14 17:47:35.246683
313	2	LOGIN_EXITOSO	SISTEMA	\N	{"username": "jcate"}	127.0.0.1	2026-01-14 17:49:45.097493
314	2	CREAR	CARTA	988	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_988_3389318561001.pdf", "acceso_id": 998, "anio_carta": 2026, "numero_carta": 20, "pdf_generado": true, "solicitud_id": 1101}	127.0.0.1	2026-01-14 17:52:36.232755
315	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-14 17:53:53.443727
316	1	DESACTIVAR_USUARIO	USUARIO	2	{"username": "jcate", "nuevo_estado": false}	127.0.0.1	2026-01-14 17:54:21.458678
317	\N	LOGIN_FALLIDO	SISTEMA	\N	{"username": "jcate"}	127.0.0.1	2026-01-14 17:54:33.196577
318	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-14 17:54:40.015528
319	1	ACTIVAR_USUARIO	USUARIO	2	{"username": "jcate", "nuevo_estado": true}	127.0.0.1	2026-01-14 17:54:47.170693
320	2	LOGIN_EXITOSO	SISTEMA	\N	{"username": "jcate"}	127.0.0.1	2026-01-14 17:56:02.940802
321	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-14 18:01:25.751845
322	1	CREAR	CARTA	994	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_994_3428509382206.pdf", "acceso_id": 1004, "anio_carta": 2026, "numero_carta": 26, "pdf_generado": true, "solicitud_id": 1113}	127.0.0.1	2026-01-14 18:25:24.691164
323	2	LOGIN_EXITOSO	SISTEMA	\N	{"username": "jcate"}	127.0.0.1	2026-01-14 18:26:09.387503
324	2	CREAR	CARTA	995	{"pdf_path": "/var/vpn_archivos/cartas\\\\CARTA_995_2753095731603.pdf", "acceso_id": 1005, "anio_carta": 2026, "numero_carta": 27, "pdf_generado": true, "solicitud_id": 1112}	127.0.0.1	2026-01-14 18:26:23.444678
325	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-14 18:29:09.739184
326	1	BLOQUEAR	ACCESO	22	{"motivo": "finalizo fecha de vencimiento"}	127.0.0.1	2026-01-14 18:37:24.588547
327	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-14 19:08:21.187808
328	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-14 19:08:35.966438
329	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-14 19:09:37.552564
330	1	BLOQUEAR	ACCESO	232	{"motivo": "Carta vencida sin renovación"}	127.0.0.1	2026-01-14 19:36:52.264296
331	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-14 20:27:26.795965
332	1	DESACTIVAR_USUARIO	USUARIO	2	{"username": "jcate", "nuevo_estado": false}	127.0.0.1	2026-01-14 20:32:10.040719
333	1	ACTIVAR_USUARIO	USUARIO	2	{"username": "jcate", "nuevo_estado": true}	127.0.0.1	2026-01-14 20:32:15.676329
334	1	DESACTIVAR_USUARIO	USUARIO	2	{"username": "jcate", "nuevo_estado": false}	127.0.0.1	2026-01-14 20:32:21.873034
335	1	ACTIVAR_USUARIO	USUARIO	2	{"username": "jcate", "nuevo_estado": true}	127.0.0.1	2026-01-14 20:32:45.840068
336	1	DESACTIVAR_USUARIO	USUARIO	2	{"username": "jcate", "nuevo_estado": false}	127.0.0.1	2026-01-14 20:32:52.760734
337	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-15 08:35:16.573655
338	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-16 15:32:34.717445
339	1	ACTIVAR_USUARIO	USUARIO	2	{"username": "jcate", "nuevo_estado": true}	127.0.0.1	2026-01-16 15:33:18.188431
340	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-16 16:35:24.630787
341	1	CREAR	PERSONA	830	{"dpi": "1111122222333", "nombre_completo": "Jonathan Cate"}	127.0.0.1	2026-01-16 16:47:48.791516
342	1	CREAR	SOLICITUD	1114	{"tipo": "NUEVA", "estado": "PENDIENTE", "persona_dpi": "1111122222333", "persona_nip": "11111-P"}	127.0.0.1	2026-01-16 16:48:07.925484
343	1	EDITAR_PERSONA_COMPLETA	PERSONA	830	{"cambios": {"nombres": {"nuevo": "Jonathan Miguel", "anterior": "Jonathan"}, "apellidos": {"nuevo": "Cate Catu", "anterior": "Cate"}}, "carta_id": null, "advertencia": null, "tiene_carta_activa": false}	127.0.0.1	2026-01-16 16:48:32.47169
344	1	CREAR	CARTA	996	{"acceso_id": 1006, "anio_carta": 2026, "numero_carta": 28, "solicitud_id": 1114, "pdf_generado_dinamicamente": true}	127.0.0.1	2026-01-16 16:48:42.24808
345	1	EDITAR_PERSONA_COMPLETA	PERSONA	830	{"cambios": {"nip": {"nuevo": "11112-P", "anterior": "11111-P"}, "nombres": {"nuevo": "JONATHAN", "anterior": "Jonathan Miguel"}, "apellidos": {"nuevo": "CATE CATU", "anterior": "Cate Catu"}}, "carta_id": 996, "advertencia": "Editados datos críticos de persona con carta generada", "tiene_carta_activa": true}	127.0.0.1	2026-01-16 16:49:31.325004
346	1	DESACTIVAR_USUARIO	USUARIO	2	{"username": "jcate", "nuevo_estado": false}	127.0.0.1	2026-01-16 16:56:10.583312
347	1	ACTIVAR_USUARIO	USUARIO	2	{"username": "jcate", "nuevo_estado": true}	127.0.0.1	2026-01-16 17:03:54.757073
348	1	DESACTIVAR_USUARIO	USUARIO	2	{"username": "jcate", "nuevo_estado": false}	127.0.0.1	2026-01-16 17:03:58.025171
349	1	ACTIVAR_USUARIO	USUARIO	2	{"username": "jcate", "nuevo_estado": true}	127.0.0.1	2026-01-16 17:07:26.617865
350	1	DESACTIVAR_USUARIO	USUARIO	2	{"username": "jcate", "nuevo_estado": false}	127.0.0.1	2026-01-16 17:07:33.886035
351	1	ACTIVAR_USUARIO	USUARIO	2	{"username": "jcate", "nuevo_estado": true}	127.0.0.1	2026-01-16 17:07:48.002294
352	1	DESACTIVAR_USUARIO	USUARIO	2	{"username": "jcate", "nuevo_estado": false}	127.0.0.1	2026-01-16 17:07:50.311036
353	1	ACTIVAR_USUARIO	USUARIO	2	{"username": "jcate", "nuevo_estado": true}	127.0.0.1	2026-01-16 17:08:00.160451
354	1	DESACTIVAR_USUARIO	USUARIO	2	{"username": "jcate", "nuevo_estado": false}	127.0.0.1	2026-01-16 17:25:51.256171
355	1	ACTIVAR_USUARIO	USUARIO	2	{"username": "jcate", "nuevo_estado": true}	127.0.0.1	2026-01-16 17:26:09.9761
356	\N	LOGIN_FALLIDO	SISTEMA	\N	{"username": "jcate"}	127.0.0.1	2026-01-16 17:26:23.061453
357	2	LOGIN_EXITOSO	SISTEMA	\N	{"username": "jcate"}	127.0.0.1	2026-01-16 17:26:38.849089
358	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-16 17:40:36.975657
359	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-16 17:47:49.193522
360	1	CREAR	CARTA	997	{"acceso_id": 1007, "anio_carta": 2026, "numero_carta": 29, "solicitud_id": 1094, "pdf_generado_dinamicamente": true}	127.0.0.1	2026-01-16 18:01:07.966759
361	2	LOGIN_EXITOSO	SISTEMA	\N	{"username": "jcate"}	127.0.0.1	2026-01-16 18:09:19.717147
362	2	CREAR	CARTA	998	{"acceso_id": 1008, "anio_carta": 2026, "numero_carta": 30, "solicitud_id": 1111, "pdf_generado_dinamicamente": true}	127.0.0.1	2026-01-16 18:13:20.931628
363	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-16 18:14:15.720515
364	1	EDITAR_PERSONA_COMPLETA	PERSONA	827	{"cambios": {"nombres": {"nuevo": "ROBIN GUSTAVO", "anterior": "ROBIN GUSTABO"}}, "carta_id": 998, "advertencia": "Editados datos de persona con carta generada", "tiene_carta_activa": true}	127.0.0.1	2026-01-16 18:14:37.396326
365	1	CREAR	SOLICITUD	1115	{"tipo": "ACTUALIZACION", "estado": "PENDIENTE", "persona_dpi": "2753095731603", "persona_nip": "68132-P"}	127.0.0.1	2026-01-16 18:20:18.243431
366	1	DESACTIVAR_USUARIO	USUARIO	2	{"username": "jcate", "nuevo_estado": false}	127.0.0.1	2026-01-16 18:24:35.971465
367	\N	LOGIN_FALLIDO	SISTEMA	\N	{"username": "jcate"}	127.0.0.1	2026-01-16 18:24:51.677126
368	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-16 18:24:58.52553
369	1	ACTIVAR_USUARIO	USUARIO	2	{"username": "jcate", "nuevo_estado": true}	127.0.0.1	2026-01-16 18:25:20.184108
370	2	LOGIN_EXITOSO	SISTEMA	\N	{"username": "jcate"}	127.0.0.1	2026-01-16 18:25:34.082017
371	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-16 19:25:31.949303
372	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-17 11:01:30.074828
373	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-17 11:07:10.068202
374	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-17 16:58:34.658268
375	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-17 17:04:41.744539
376	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-29 17:57:16.749837
377	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-29 18:13:03.153577
378	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-29 20:38:31.570796
379	1	RESETEAR_PASSWORD	USUARIO	2	{"mensaje": "Contraseña reseteada para usuario jcate"}	127.0.0.1	2026-01-29 20:39:25.787689
380	2	LOGIN_EXITOSO	SISTEMA	\N	{"username": "jcate"}	127.0.0.1	2026-01-29 20:40:05.018314
381	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-29 21:18:35.381956
382	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-29 21:31:13.034223
383	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-30 12:09:05.869767
384	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-30 12:15:23.776984
385	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-30 15:43:37.573261
386	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-30 16:32:22.908183
387	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-30 17:01:53.436401
388	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-30 17:05:47.70254
389	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-30 17:34:09.11191
390	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-30 17:41:36.283153
391	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-30 17:43:22.898496
392	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-30 17:47:22.167421
393	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-30 17:52:05.725718
394	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-30 17:52:55.2488
395	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-30 17:57:30.007235
396	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-01-30 18:05:15.435157
397	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-02-02 11:26:10.461157
398	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-02-02 14:30:23.021227
399	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-02-03 10:51:22.95815
400	\N	LOGIN_FALLIDO	SISTEMA	\N	{"username": "jcate"}	127.0.0.1	2026-02-03 10:58:07.225862
401	\N	LOGIN_FALLIDO	SISTEMA	\N	{"username": "jcate"}	127.0.0.1	2026-02-03 10:58:17.244846
402	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-02-03 10:58:21.734776
403	1	RESETEAR_PASSWORD	USUARIO	2	{"mensaje": "Contraseña reseteada para usuario jcate"}	127.0.0.1	2026-02-03 10:58:39.018636
404	2	LOGIN_EXITOSO	SISTEMA	\N	{"username": "jcate"}	127.0.0.1	2026-02-03 10:58:57.25756
405	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-02-03 12:04:04.579084
406	1	CREAR	CARTA	994	{"acceso_id": 1005, "anio_carta": 2026, "numero_carta": 26, "solicitud_id": 1095, "pdf_generado_dinamicamente": true}	127.0.0.1	2026-02-03 12:07:16.257815
407	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-02-03 12:12:27.186788
408	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-02-03 12:38:11.173284
409	1	CREAR	CARTA	995	{"acceso_id": 1006, "anio_carta": 2026, "numero_carta": 27, "solicitud_id": 1111, "pdf_generado_dinamicamente": true}	127.0.0.1	2026-02-03 12:38:58.845569
410	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-02-03 13:43:12.642932
411	1	BLOQUEAR	ACCESO	428	{"motivo": "Carta vencida sin renovación"}	127.0.0.1	2026-02-03 13:59:21.234778
412	1	BLOQUEAR	ACCESO	71	{"motivo": "Carta vencida sin renovación"}	127.0.0.1	2026-02-03 14:00:53.853979
413	1	BLOQUEAR	ACCESO	121	{"motivo": "Carta vencida sin renovación"}	127.0.0.1	2026-02-03 14:02:09.840323
414	1	BLOQUEAR	ACCESO	206	{"motivo": "Carta vencida sin renovación"}	127.0.0.1	2026-02-03 14:05:01.133441
415	1	BLOQUEAR	ACCESO	299	{"motivo": "Carta vencida sin renovación"}	127.0.0.1	2026-02-03 14:07:18.285144
416	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-02-03 14:45:27.112737
417	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-02-03 16:09:49.571522
418	1	LOGIN_EXITOSO	SISTEMA	\N	{"username": "admin"}	127.0.0.1	2026-02-03 19:59:21.938892
\.


--
-- TOC entry 5111 (class 0 OID 16472)
-- Dependencies: 224
-- Data for Name: bloqueos_vpn; Type: TABLE DATA; Schema: public; Owner: vpn_user
--

COPY public.bloqueos_vpn (id, acceso_vpn_id, estado, motivo, usuario_id, fecha_cambio) FROM stdin;
1	2	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
2	3	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
3	4	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
4	5	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
5	6	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
6	7	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
7	8	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
8	9	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
9	11	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
10	12	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
11	13	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
12	14	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
13	16	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
14	17	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
15	18	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
16	19	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
17	20	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
18	21	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
19	23	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
20	24	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
21	25	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
22	27	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
23	28	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
24	29	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
25	30	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
26	31	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
27	33	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
28	34	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
29	36	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
30	37	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
31	38	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
32	40	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
33	41	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
34	42	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
35	43	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
36	44	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
37	45	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
38	46	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
39	47	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
40	48	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
41	49	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
42	50	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
43	51	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
44	54	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
45	55	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
46	57	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
47	59	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
48	60	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
49	61	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
50	62	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
51	63	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
52	64	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
53	65	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
54	68	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
55	69	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
56	70	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
57	71	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
58	73	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
59	74	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
60	75	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
61	76	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
62	77	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
63	78	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
64	79	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
65	81	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
66	82	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
67	84	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
68	85	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
69	86	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
70	87	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
71	88	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
72	89	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
73	90	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
74	91	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
75	92	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
76	93	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
77	95	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
78	96	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
79	97	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
80	98	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
81	99	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
82	100	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
83	101	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
84	102	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
85	104	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
86	105	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
87	106	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
88	108	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
89	109	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
90	110	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
91	111	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
92	112	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
93	113	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
94	114	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
95	115	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
96	116	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
97	117	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
98	118	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
99	119	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
100	120	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
101	121	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
102	122	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
103	123	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
104	124	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
105	125	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
106	126	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
107	127	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
108	128	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
109	129	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
110	130	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
111	131	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
112	132	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
113	134	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
114	135	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
115	136	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
116	137	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
117	138	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
118	139	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
119	141	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
120	142	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
121	143	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
122	144	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
123	146	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
124	147	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
125	148	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
126	149	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
127	150	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
128	151	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
129	152	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
130	153	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
131	154	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
132	155	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
133	156	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
134	157	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
135	158	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
136	159	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
137	161	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
138	162	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
139	163	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
140	164	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
141	165	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
142	166	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
143	167	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
144	168	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
145	169	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
146	170	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
147	172	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
148	173	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
149	174	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
150	176	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
151	177	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
152	178	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
153	180	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
154	181	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
155	182	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
156	183	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
157	184	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
158	185	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
159	187	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
160	188	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
161	189	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
162	191	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
163	192	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
164	193	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
165	194	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
166	195	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
167	196	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
168	198	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
169	199	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
170	202	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
171	203	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
172	204	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
173	207	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
174	208	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
175	209	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
176	210	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
177	211	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
178	212	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
179	213	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
180	214	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
181	215	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
182	216	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
183	219	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
184	221	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
185	222	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
186	223	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
187	225	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
188	227	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
189	229	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
190	231	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
191	233	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
192	234	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
193	235	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
194	236	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
195	237	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
196	238	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
197	239	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
198	241	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
199	242	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
200	243	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
201	245	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
202	246	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
203	247	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
204	248	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
205	251	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
206	252	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
207	255	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
208	257	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
209	258	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
210	259	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
211	261	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
212	262	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
213	265	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
214	266	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
215	267	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
216	268	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
217	269	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
218	270	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
219	271	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
220	273	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
221	274	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
222	275	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
223	277	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
224	278	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
225	279	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
226	280	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
227	281	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
228	282	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
229	284	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
230	285	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
231	286	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
232	287	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
233	288	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
234	289	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
235	291	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
236	292	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
237	293	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
238	294	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
239	295	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
240	297	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
241	301	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
242	302	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
243	303	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
244	304	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
245	305	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
246	306	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
247	307	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
248	308	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
249	309	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
250	311	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
251	312	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
252	313	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
253	314	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
254	315	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
255	316	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
256	317	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
257	318	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
258	319	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
259	320	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
260	321	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
261	322	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
262	323	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
263	325	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
264	326	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
265	328	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
266	329	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
267	331	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
268	332	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
269	333	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
270	334	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
271	336	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
272	337	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
273	338	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
274	340	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
275	341	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
276	342	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
277	343	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
278	344	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
279	345	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
280	346	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
281	347	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
282	349	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
283	350	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
284	351	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
285	352	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
286	353	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
287	354	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
288	355	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
289	356	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
290	357	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
291	358	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
292	359	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
293	360	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
294	361	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
295	362	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
296	363	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
297	364	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
298	365	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
299	366	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
300	367	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
301	368	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
302	369	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
303	370	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
304	371	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
305	373	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
306	374	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
307	375	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
308	376	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
309	377	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
310	378	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
311	380	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
312	381	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
313	382	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
314	383	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
315	384	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
316	385	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
317	386	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
318	388	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
319	389	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
320	390	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
321	391	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
322	392	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
323	393	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
324	394	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
325	395	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
326	396	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
327	397	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
328	398	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
329	399	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
330	400	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
331	401	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
332	402	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
333	403	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
334	404	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
335	405	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
336	406	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
337	407	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
338	408	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
339	410	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
340	411	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
341	412	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
342	413	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
343	414	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
344	415	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
345	416	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
346	417	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
347	418	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
348	419	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
349	420	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
350	421	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
351	422	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
352	423	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
353	424	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
354	425	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
355	427	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
356	428	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
357	430	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
358	431	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
359	432	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
360	433	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
361	434	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
362	435	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
363	437	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
364	438	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
365	439	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
366	440	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
367	442	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
368	443	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
369	444	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
370	445	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
371	446	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
372	448	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
373	449	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
374	450	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
375	451	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
376	452	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
377	453	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
378	454	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
379	455	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
380	456	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
381	457	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
382	458	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
383	459	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
384	460	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
385	461	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
386	462	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
387	463	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
388	465	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
389	467	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
390	468	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
391	469	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
392	471	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
393	472	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
394	473	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
395	474	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
396	475	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
397	476	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
398	477	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
399	478	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
400	479	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
401	480	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
402	481	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
403	483	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
404	484	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
405	485	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
406	486	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
407	487	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
408	488	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
409	489	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
410	491	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
411	492	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
412	493	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
413	494	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
414	495	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
415	496	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
416	497	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
417	498	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
418	499	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
419	500	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
420	501	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
421	502	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
422	503	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
423	504	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
424	505	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
425	506	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
426	507	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
427	508	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
428	509	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
429	510	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
430	511	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
431	512	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
432	513	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
433	515	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
434	516	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
435	517	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
436	546	BLOQUEADO	Importado con estado: Bloqueado	1	2026-02-03 19:59:33.209583
\.


--
-- TOC entry 5113 (class 0 OID 16493)
-- Dependencies: 226
-- Data for Name: cartas_responsabilidad; Type: TABLE DATA; Schema: public; Owner: vpn_user
--

COPY public.cartas_responsabilidad (id, solicitud_id, tipo, fecha_generacion, generada_por_usuario_id, numero_carta, anio_carta, eliminada) FROM stdin;
750	822	RESPONSABILIDAD	2025-07-24	1	317	2025	f
751	823	RESPONSABILIDAD	2025-07-24	1	318	2025	f
752	824	RESPONSABILIDAD	2025-08-05	1	341	2025	f
753	825	RESPONSABILIDAD	2025-08-05	1	342	2025	f
754	826	RESPONSABILIDAD	2025-08-20	1	361	2025	f
755	827	RESPONSABILIDAD	2025-08-07	1	351	2025	f
756	828	RESPONSABILIDAD	2025-08-07	1	350	2025	f
757	829	RESPONSABILIDAD	2025-08-05	1	340	2025	f
758	830	RESPONSABILIDAD	2025-08-05	1	339	2025	f
759	831	RESPONSABILIDAD	2025-08-05	1	345	2025	f
760	832	RESPONSABILIDAD	2025-08-05	1	343	2025	f
761	833	RESPONSABILIDAD	2025-08-21	1	362	2025	f
762	834	RESPONSABILIDAD	2025-08-27	1	366	2025	f
763	835	RESPONSABILIDAD	2025-08-20	1	360	2025	f
764	836	RESPONSABILIDAD	2025-08-22	1	364	2025	f
765	837	RESPONSABILIDAD	2025-08-05	1	344	2025	f
766	838	RESPONSABILIDAD	2025-08-07	1	348	2025	f
767	840	RESPONSABILIDAD	2025-08-18	1	354	2025	f
768	841	RESPONSABILIDAD	2025-09-01	1	363	2025	f
769	843	RESPONSABILIDAD	2025-09-09	1	376	2025	f
770	845	RESPONSABILIDAD	2025-08-04	1	371	2025	f
771	846	RESPONSABILIDAD	2025-08-29	1	367	2025	f
772	847	RESPONSABILIDAD	2025-08-29	1	368	2025	f
773	848	RESPONSABILIDAD	2025-09-09	1	374	2025	f
774	849	RESPONSABILIDAD	2025-10-09	1	451	2025	f
775	851	RESPONSABILIDAD	2025-10-22	1	472	2025	f
776	852	RESPONSABILIDAD	2025-09-12	1	379	2025	f
777	853	RESPONSABILIDAD	2025-09-08	1	373	2025	f
778	854	RESPONSABILIDAD	2025-09-12	1	381	2025	f
779	855	RESPONSABILIDAD	2025-09-17	1	394	2025	f
780	856	RESPONSABILIDAD	2025-09-12	1	380	2025	f
781	857	RESPONSABILIDAD	2025-09-08	1	372	2025	f
782	858	RESPONSABILIDAD	2025-09-30	1	444	2025	f
783	859	RESPONSABILIDAD	2025-09-22	1	413	2025	f
784	863	RESPONSABILIDAD	2025-09-25	1	438	2025	f
785	864	RESPONSABILIDAD	2025-12-07	1	554	2025	f
786	865	RESPONSABILIDAD	2025-09-24	1	432	2025	f
787	866	RESPONSABILIDAD	2025-09-23	1	427	2025	f
788	867	RESPONSABILIDAD	2025-10-17	1	460	2025	f
789	868	RESPONSABILIDAD	2025-09-24	1	434	2025	f
790	869	RESPONSABILIDAD	2025-09-22	1	412	2025	f
791	870	RESPONSABILIDAD	2025-09-21	1	411	2025	f
792	871	RESPONSABILIDAD	2025-09-22	1	421	2025	f
793	872	RESPONSABILIDAD	2025-09-21	1	410	2025	f
794	874	RESPONSABILIDAD	2025-09-22	1	415	2025	f
795	876	RESPONSABILIDAD	2025-09-22	1	419	2025	f
796	878	RESPONSABILIDAD	2025-09-30	1	442	2025	f
797	879	RESPONSABILIDAD	2025-10-15	1	458	2025	f
798	880	RESPONSABILIDAD	2025-10-20	1	464	2025	f
799	881	RESPONSABILIDAD	2025-09-19	1	405	2025	f
800	882	RESPONSABILIDAD	2025-09-19	1	406	2025	f
801	883	RESPONSABILIDAD	2025-09-19	1	403	2025	f
802	884	RESPONSABILIDAD	2025-09-19	1	404	2025	f
803	885	RESPONSABILIDAD	2025-09-24	1	436	2025	f
804	886	RESPONSABILIDAD	2025-09-30	1	443	2025	f
805	887	RESPONSABILIDAD	2025-10-22	1	473	2025	f
806	888	RESPONSABILIDAD	2026-01-02	1	3	2026	f
807	889	RESPONSABILIDAD	2025-10-02	1	446	2025	f
808	890	RESPONSABILIDAD	2025-09-21	1	408	2025	f
809	891	RESPONSABILIDAD	2025-09-18	1	402	2025	f
810	892	RESPONSABILIDAD	2025-09-20	1	409	2025	f
811	893	RESPONSABILIDAD	2025-09-23	1	423	2025	f
812	894	RESPONSABILIDAD	2025-09-24	1	435	2025	f
813	895	RESPONSABILIDAD	2025-10-09	1	450	2025	f
814	896	RESPONSABILIDAD	2025-09-23	1	426	2025	f
815	897	RESPONSABILIDAD	2025-09-23	1	430	2025	f
816	898	RESPONSABILIDAD	2025-09-22	1	420	2025	f
817	899	RESPONSABILIDAD	2025-09-25	1	422	2025	f
818	900	RESPONSABILIDAD	2025-09-28	1	441	2025	f
819	903	RESPONSABILIDAD	2025-10-21	1	469	2025	f
820	905	RESPONSABILIDAD	2025-10-06	1	448	2025	f
821	907	RESPONSABILIDAD	2025-10-25	1	474	2025	f
822	908	RESPONSABILIDAD	2025-08-01	1	336	2025	f
823	909	RESPONSABILIDAD	2025-09-17	1	395	2025	f
824	910	RESPONSABILIDAD	2025-10-14	1	455	2025	f
825	911	RESPONSABILIDAD	2025-09-16	1	392	2025	f
826	912	RESPONSABILIDAD	2025-09-19	1	407	2025	f
827	913	RESPONSABILIDAD	2025-09-28	1	440	2025	f
828	914	RESPONSABILIDAD	2025-10-10	1	453	2025	f
829	915	RESPONSABILIDAD	2025-10-16	1	459	2025	f
830	916	RESPONSABILIDAD	2025-10-09	1	452	2025	f
831	917	RESPONSABILIDAD	2025-10-15	1	457	2025	f
832	918	RESPONSABILIDAD	2025-10-13	1	454	2025	f
833	919	RESPONSABILIDAD	2025-10-15	1	456	2025	f
834	921	RESPONSABILIDAD	2025-09-18	1	400	2025	f
835	922	RESPONSABILIDAD	2025-09-18	1	396	2025	f
836	923	RESPONSABILIDAD	2025-09-24	1	431	2025	f
837	924	RESPONSABILIDAD	2025-10-21	1	470	2025	f
838	925	RESPONSABILIDAD	2025-09-24	1	433	2025	f
839	926	RESPONSABILIDAD	2025-09-23	1	429	2025	f
840	927	RESPONSABILIDAD	2025-09-23	1	424	2025	f
841	928	RESPONSABILIDAD	2025-09-23	1	425	2025	f
842	929	RESPONSABILIDAD	2025-09-23	1	428	2025	f
843	930	RESPONSABILIDAD	2025-10-21	1	471	2025	f
844	931	RESPONSABILIDAD	2025-09-18	1	397	2025	f
845	932	RESPONSABILIDAD	2025-09-18	1	401	2025	f
846	934	RESPONSABILIDAD	2025-10-20	1	466	2025	f
847	935	RESPONSABILIDAD	2025-09-18	1	399	2025	f
848	936	RESPONSABILIDAD	2025-09-18	1	398	2025	f
849	937	RESPONSABILIDAD	2025-09-11	1	378	2025	f
850	938	RESPONSABILIDAD	2025-09-09	1	375	2025	f
851	939	RESPONSABILIDAD	2025-10-04	1	447	2025	f
852	940	RESPONSABILIDAD	2025-10-17	1	463	2025	f
853	941	RESPONSABILIDAD	2025-12-07	1	553	2025	f
854	942	RESPONSABILIDAD	2025-10-17	1	462	2025	f
855	943	RESPONSABILIDAD	2025-10-17	1	461	2025	f
856	944	RESPONSABILIDAD	2025-10-30	1	495	2025	f
857	946	RESPONSABILIDAD	2025-10-29	1	491	2025	f
858	947	RESPONSABILIDAD	2025-11-02	1	498	2025	f
859	948	RESPONSABILIDAD	2025-10-20	1	468	2025	f
860	949	RESPONSABILIDAD	2025-10-30	1	494	2025	f
861	951	RESPONSABILIDAD	2025-10-29	1	493	2025	f
862	952	RESPONSABILIDAD	2025-10-30	1	496	2025	f
863	953	RESPONSABILIDAD	2025-11-05	1	504	2025	f
864	954	RESPONSABILIDAD	2025-12-08	1	555	2025	f
865	955	RESPONSABILIDAD	2025-10-28	1	487	2025	f
866	956	RESPONSABILIDAD	2025-10-28	1	485	2025	f
867	957	RESPONSABILIDAD	2025-10-31	1	497	2025	f
868	958	RESPONSABILIDAD	2025-10-26	1	475	2025	f
869	959	RESPONSABILIDAD	2025-10-26	1	476	2025	f
870	960	RESPONSABILIDAD	2025-10-20	1	465	2025	f
871	961	RESPONSABILIDAD	2025-12-30	1	600	2025	f
872	963	RESPONSABILIDAD	2025-12-10	1	558	2025	f
873	964	RESPONSABILIDAD	2025-11-18	1	535	2025	f
874	965	RESPONSABILIDAD	2025-12-06	1	551	2025	f
875	967	RESPONSABILIDAD	2025-12-06	1	550	2025	f
876	969	RESPONSABILIDAD	2026-01-09	1	14	2026	f
877	970	RESPONSABILIDAD	2025-11-05	1	499	2025	f
878	971	RESPONSABILIDAD	2025-11-19	1	537	2025	f
879	972	RESPONSABILIDAD	2025-11-12	1	522	2025	f
880	973	RESPONSABILIDAD	2025-11-14	1	532	2025	f
881	974	RESPONSABILIDAD	2025-11-12	1	519	2025	f
882	975	RESPONSABILIDAD	2025-11-12	1	523	2025	f
883	976	RESPONSABILIDAD	2025-11-12	1	520	2025	f
884	977	RESPONSABILIDAD	2025-11-19	1	538	2025	f
885	978	RESPONSABILIDAD	2025-11-12	1	521	2025	f
886	980	RESPONSABILIDAD	2026-12-05	1	548	2025	f
887	981	RESPONSABILIDAD	2025-12-06	1	552	2025	f
888	982	RESPONSABILIDAD	2025-11-24	1	543	2025	f
889	983	RESPONSABILIDAD	2025-11-06	1	507	2025	f
890	984	RESPONSABILIDAD	2025-11-12	1	524	2025	f
891	985	RESPONSABILIDAD	2025-11-14	1	529	2025	f
892	986	RESPONSABILIDAD	2025-11-05	1	503	2025	f
893	987	RESPONSABILIDAD	2025-11-06	1	506	2025	f
894	988	RESPONSABILIDAD	2025-11-22	1	542	2025	f
895	989	RESPONSABILIDAD	2025-11-11	1	518	2025	f
896	990	RESPONSABILIDAD	2025-11-05	1	501	2025	f
897	991	RESPONSABILIDAD	2025-12-05	1	549	2025	f
898	992	RESPONSABILIDAD	2025-11-14	1	530	2025	f
899	993	RESPONSABILIDAD	2025-11-14	1	534	2025	f
900	994	RESPONSABILIDAD	2025-11-14	1	528	2025	f
901	995	RESPONSABILIDAD	2025-11-19	1	539	2025	f
902	996	RESPONSABILIDAD	2025-11-12	1	527	2025	f
903	997	RESPONSABILIDAD	2025-11-06	1	505	2025	f
904	998	RESPONSABILIDAD	2025-10-26	1	480	2025	f
905	999	RESPONSABILIDAD	2025-11-26	1	481	2025	f
906	1000	RESPONSABILIDAD	2025-10-26	1	478	2025	f
907	1001	RESPONSABILIDAD	2025-10-26	1	483	2025	f
908	1002	RESPONSABILIDAD	2025-10-26	1	479	2025	f
909	1003	RESPONSABILIDAD	2025-10-26	1	477	2025	f
910	1004	RESPONSABILIDAD	2025-10-26	1	482	2025	f
911	1005	RESPONSABILIDAD	2025-10-26	1	484	2025	f
912	1006	RESPONSABILIDAD	2025-11-08	1	509	2025	f
913	1007	RESPONSABILIDAD	2025-11-06	1	508	2025	f
914	1008	RESPONSABILIDAD	2025-11-11	1	516	2025	f
915	1009	RESPONSABILIDAD	2025-11-11	1	514	2025	f
916	1010	RESPONSABILIDAD	2025-11-11	1	515	2025	f
917	1013	RESPONSABILIDAD	2025-11-05	1	500	2025	f
918	1014	RESPONSABILIDAD	2025-11-09	1	512	2025	f
919	1015	RESPONSABILIDAD	2025-11-10	1	513	2025	f
920	1016	RESPONSABILIDAD	2025-12-12	1	563	2025	f
921	1017	RESPONSABILIDAD	2025-12-10	1	557	2025	f
922	1018	RESPONSABILIDAD	2025-12-10	1	559	2025	f
923	1019	RESPONSABILIDAD	2025-11-09	1	511	2025	f
924	1020	RESPONSABILIDAD	2025-12-12	1	565	2025	f
925	1022	RESPONSABILIDAD	2025-11-22	1	541	2025	f
926	1023	RESPONSABILIDAD	2025-12-05	1	547	2025	f
927	1024	RESPONSABILIDAD	2025-11-11	1	517	2025	f
1	1	RESPONSABILIDAD	2025-02-12	1	89	2025	f
2	2	RESPONSABILIDAD	2024-04-16	1	86	2024	f
3	3	RESPONSABILIDAD	2024-07-29	1	275	2024	f
4	4	RESPONSABILIDAD	2024-07-31	1	281	2024	f
5	5	RESPONSABILIDAD	2025-02-03	1	67	2025	f
6	6	RESPONSABILIDAD	2024-01-25	1	15	2024	f
7	7	RESPONSABILIDAD	2024-07-25	1	269	2024	f
8	8	RESPONSABILIDAD	2024-06-05	1	212	2024	f
9	9	RESPONSABILIDAD	2024-05-19	1	172	2024	f
10	10	RESPONSABILIDAD	2025-01-28	1	47	2025	f
11	11	RESPONSABILIDAD	2025-01-20	1	27	2025	f
12	12	RESPONSABILIDAD	2024-05-14	1	167	2024	f
13	13	RESPONSABILIDAD	2024-11-13	1	386	2024	f
14	14	RESPONSABILIDAD	2024-06-02	1	206	2024	f
15	15	RESPONSABILIDAD	2025-02-05	1	74	2025	f
16	16	RESPONSABILIDAD	2024-06-10	1	219	2024	f
17	17	RESPONSABILIDAD	2024-06-10	1	216	2024	f
18	18	RESPONSABILIDAD	2024-07-19	1	246	2024	f
19	19	RESPONSABILIDAD	2024-04-22	1	120	2024	f
20	20	RESPONSABILIDAD	2024-04-20	1	128	2024	f
21	21	RESPONSABILIDAD	2024-05-29	1	202	2024	f
22	22	RESPONSABILIDAD	2025-01-02	1	4	2025	f
23	23	RESPONSABILIDAD	2024-04-12	1	78	2024	f
24	24	RESPONSABILIDAD	2024-05-21	1	179	2024	f
25	25	RESPONSABILIDAD	2024-07-18	1	262	2024	f
26	26	RESPONSABILIDAD	2025-02-10	1	83	2025	f
27	27	RESPONSABILIDAD	2024-08-28	1	326	2024	f
28	28	RESPONSABILIDAD	2024-06-10	1	215	2024	f
29	29	RESPONSABILIDAD	2024-12-12	1	421	2024	f
30	30	RESPONSABILIDAD	2024-06-10	1	217	2024	f
31	31	RESPONSABILIDAD	2024-05-19	1	173	2024	f
32	32	RESPONSABILIDAD	2025-01-28	1	33	2025	f
33	33	RESPONSABILIDAD	2024-08-06	1	293	2024	f
34	34	RESPONSABILIDAD	2024-06-30	1	241	2024	f
35	35	RESPONSABILIDAD	2025-02-12	1	90	2025	f
36	36	RESPONSABILIDAD	2024-12-07	1	410	2024	f
37	37	RESPONSABILIDAD	2024-11-13	1	378	2024	f
38	38	RESPONSABILIDAD	2024-04-17	1	104	2024	f
39	39	RESPONSABILIDAD	2025-01-03	1	9	2025	f
40	40	RESPONSABILIDAD	2024-10-18	1	366	2024	f
41	41	RESPONSABILIDAD	2024-04-24	1	113	2024	f
42	42	RESPONSABILIDAD	2025-01-01	1	1	2025	f
43	43	RESPONSABILIDAD	2024-02-19	1	38	2024	f
44	44	RESPONSABILIDAD	2024-04-17	1	95	2024	f
45	45	RESPONSABILIDAD	2024-09-05	1	336	2024	f
46	46	RESPONSABILIDAD	2024-02-21	1	48	2024	f
47	47	RESPONSABILIDAD	2024-04-17	1	94	2024	f
48	48	RESPONSABILIDAD	2024-05-24	1	187	2024	f
49	49	RESPONSABILIDAD	2024-10-30	1	372	2024	f
50	50	RESPONSABILIDAD	2024-04-30	1	141	2024	f
51	51	RESPONSABILIDAD	2024-11-13	1	385	2024	f
52	52	RESPONSABILIDAD	2025-01-20	1	20	2025	f
53	54	RESPONSABILIDAD	2025-02-01	1	61	2025	f
54	55	RESPONSABILIDAD	2024-02-19	1	39	2024	f
55	56	RESPONSABILIDAD	2024-12-09	1	411	2024	f
56	57	RESPONSABILIDAD	2025-02-10	1	80	2025	f
57	58	RESPONSABILIDAD	2024-02-29	1	55	2024	f
58	59	RESPONSABILIDAD	2025-01-28	1	39	2025	f
59	60	RESPONSABILIDAD	2024-06-13	1	234	2024	f
60	61	RESPONSABILIDAD	2024-09-18	1	342	2024	f
61	62	RESPONSABILIDAD	2024-12-09	1	416	2024	f
62	63	RESPONSABILIDAD	2024-08-23	1	311	2024	f
63	64	RESPONSABILIDAD	2024-04-17	1	105	2024	f
64	65	RESPONSABILIDAD	2024-07-08	1	247	2024	f
65	66	RESPONSABILIDAD	2024-03-17	1	67	2024	f
66	67	RESPONSABILIDAD	2025-01-28	1	31	2025	f
67	68	RESPONSABILIDAD	2025-01-20	1	26	2025	f
68	69	RESPONSABILIDAD	2024-05-03	1	154	2024	f
69	70	RESPONSABILIDAD	2024-04-20	1	132	2024	f
70	71	RESPONSABILIDAD	2024-07-08	1	256	2024	f
71	72	RESPONSABILIDAD	2025-01-20	1	21	2025	f
72	73	RESPONSABILIDAD	2025-02-10	1	82	2025	f
73	74	RESPONSABILIDAD	2024-05-29	1	201	2024	f
74	75	RESPONSABILIDAD	2024-04-22	1	114	2024	f
75	76	RESPONSABILIDAD	2024-07-08	1	249	2024	f
76	77	RESPONSABILIDAD	2024-02-07	1	33	2024	f
77	78	RESPONSABILIDAD	2024-06-11	1	230	2024	f
78	79	RESPONSABILIDAD	2024-08-27	1	321	2024	f
79	80	RESPONSABILIDAD	2024-06-06	1	213	2024	f
80	81	RESPONSABILIDAD	2025-02-04	1	71	2025	f
81	82	RESPONSABILIDAD	2024-09-18	1	341	2024	f
82	83	RESPONSABILIDAD	2024-04-17	1	99	2024	f
83	84	RESPONSABILIDAD	2025-01-30	1	50	2025	f
84	85	RESPONSABILIDAD	2024-12-12	1	422	2024	f
85	86	RESPONSABILIDAD	2024-04-22	1	116	2024	f
86	87	RESPONSABILIDAD	2024-02-05	1	26	2024	f
87	88	RESPONSABILIDAD	2024-07-29	1	274	2024	f
88	89	RESPONSABILIDAD	2024-08-01	1	286	2024	f
89	90	RESPONSABILIDAD	2024-07-08	1	255	2024	f
90	91	RESPONSABILIDAD	2024-01-20	1	8	2024	f
91	92	RESPONSABILIDAD	2024-10-30	1	369	2024	f
92	93	RESPONSABILIDAD	2024-05-07	1	158	2024	f
93	94	RESPONSABILIDAD	2024-10-16	1	362	2024	f
94	95	RESPONSABILIDAD	2025-02-13	1	94	2025	f
95	96	RESPONSABILIDAD	2024-05-10	1	162	2024	f
96	97	RESPONSABILIDAD	2024-04-17	1	93	2024	f
97	98	RESPONSABILIDAD	2024-07-15	1	258	2024	f
98	99	RESPONSABILIDAD	2024-07-19	1	264	2024	f
99	100	RESPONSABILIDAD	2024-08-23	1	307	2024	f
100	101	RESPONSABILIDAD	2024-12-12	1	424	2024	f
101	102	RESPONSABILIDAD	2024-01-03	1	2	2024	f
102	103	RESPONSABILIDAD	2024-05-28	1	199	2024	f
103	104	RESPONSABILIDAD	2025-02-05	1	73	2025	f
104	105	RESPONSABILIDAD	2024-06-27	1	239	2024	f
105	106	RESPONSABILIDAD	2024-04-12	1	77	2024	f
106	107	RESPONSABILIDAD	2024-03-06	1	59	2024	f
107	108	RESPONSABILIDAD	2025-01-28	1	36	2025	f
108	109	RESPONSABILIDAD	2024-10-31	1	373	2024	f
109	110	RESPONSABILIDAD	2024-04-24	1	111	2024	f
110	111	RESPONSABILIDAD	2024-09-24	1	346	2024	f
111	112	RESPONSABILIDAD	2024-04-30	1	143	2024	f
112	113	RESPONSABILIDAD	2024-01-30	1	21	2024	f
113	114	RESPONSABILIDAD	2025-01-06	1	10	2024	f
114	115	RESPONSABILIDAD	2024-04-17	1	101	2024	f
115	116	RESPONSABILIDAD	2024-05-08	1	159	2024	f
116	117	RESPONSABILIDAD	2024-05-28	1	200	2024	f
117	118	RESPONSABILIDAD	2024-12-07	1	407	2024	f
118	119	RESPONSABILIDAD	2024-11-21	1	387	2024	f
119	120	RESPONSABILIDAD	2024-11-25	1	392	2024	f
120	121	RESPONSABILIDAD	2024-04-17	1	89	2024	f
121	122	RESPONSABILIDAD	2025-01-20	1	23	2025	f
122	123	RESPONSABILIDAD	2024-01-22	1	11	2024	f
123	124	RESPONSABILIDAD	2024-11-03	1	376	2024	f
124	125	RESPONSABILIDAD	2024-07-08	1	248	2024	f
125	126	RESPONSABILIDAD	2024-07-31	1	282	2024	f
126	127	RESPONSABILIDAD	2024-04-22	1	121	2024	f
127	128	RESPONSABILIDAD	2024-07-08	1	250	2024	f
128	129	RESPONSABILIDAD	2024-07-29	1	272	2024	f
129	130	RESPONSABILIDAD	2024-02-05	1	24	2024	f
130	131	RESPONSABILIDAD	2024-10-30	1	368	2024	f
131	132	RESPONSABILIDAD	2024-04-19	1	125	2024	f
132	133	RESPONSABILIDAD	2024-01-26	1	19	2024	f
133	134	RESPONSABILIDAD	2025-01-09	1	16	2025	f
134	135	RESPONSABILIDAD	2024-03-20	1	74	2024	f
135	136	RESPONSABILIDAD	2024-06-10	1	220	2024	f
136	137	RESPONSABILIDAD	2024-07-18	1	260	2024	f
137	138	RESPONSABILIDAD	2024-12-04	1	406	2024	f
138	139	RESPONSABILIDAD	2024-06-11	1	231	2024	f
139	140	RESPONSABILIDAD	2024-04-20	1	126	2024	f
140	141	RESPONSABILIDAD	2025-01-30	1	51	2025	f
141	142	RESPONSABILIDAD	2024-04-30	1	145	2024	f
142	143	RESPONSABILIDAD	2024-05-14	1	165	2024	f
143	144	RESPONSABILIDAD	2024-11-13	1	381	2024	f
144	145	RESPONSABILIDAD	2024-01-03	1	1	2024	f
145	147	RESPONSABILIDAD	2025-01-19	1	18	2025	f
146	149	RESPONSABILIDAD	2024-08-24	1	312	2024	f
147	150	RESPONSABILIDAD	2024-04-22	1	108	2024	f
148	151	RESPONSABILIDAD	2024-05-21	1	177	2024	f
149	152	RESPONSABILIDAD	2024-11-25	1	394	2024	f
150	153	RESPONSABILIDAD	2024-03-10	1	62	2024	f
151	154	RESPONSABILIDAD	2024-09-30	1	355	2024	f
152	155	RESPONSABILIDAD	2024-06-17	1	238	2024	f
153	156	RESPONSABILIDAD	2024-05-21	1	174	2024	f
154	157	RESPONSABILIDAD	2024-04-19	1	124	2024	f
155	158	RESPONSABILIDAD	2024-12-12	1	420	2024	f
156	159	RESPONSABILIDAD	2024-05-21	1	184	2024	f
157	160	RESPONSABILIDAD	2025-02-11	1	87	2025	f
158	161	RESPONSABILIDAD	2024-02-29	1	57	2024	f
159	162	RESPONSABILIDAD	2025-01-28	1	37	2025	f
160	163	RESPONSABILIDAD	2024-08-27	1	323	2024	f
161	164	RESPONSABILIDAD	2024-12-09	1	415	2024	f
162	165	RESPONSABILIDAD	2024-06-04	1	211	2024	f
163	166	RESPONSABILIDAD	2024-04-20	1	134	2024	f
164	167	RESPONSABILIDAD	2024-08-26	1	319	2024	f
165	168	RESPONSABILIDAD	2024-05-21	1	181	2024	f
166	170	RESPONSABILIDAD	2024-04-26	1	139	2024	f
167	171	RESPONSABILIDAD	2024-04-17	1	96	2024	f
168	172	RESPONSABILIDAD	2024-08-07	1	297	2024	f
169	173	RESPONSABILIDAD	2024-11-24	1	393	2024	f
170	175	RESPONSABILIDAD	2025-02-02	1	64	2025	f
171	176	RESPONSABILIDAD	2024-08-06	1	294	2024	f
172	177	RESPONSABILIDAD	2024-12-17	1	426	2024	f
173	178	RESPONSABILIDAD	2024-03-06	1	61	2024	f
174	179	RESPONSABILIDAD	2025-01-28	1	35	2025	f
175	180	RESPONSABILIDAD	2024-01-25	1	16	2024	f
176	181	RESPONSABILIDAD	2024-03-27	1	76	2024	f
177	182	RESPONSABILIDAD	2024-01-08	1	4	2024	f
178	183	RESPONSABILIDAD	2025-02-20	1	101	2025	f
179	184	RESPONSABILIDAD	2024-08-26	1	320	2024	f
180	185	RESPONSABILIDAD	2025-02-04	1	70	2025	f
181	186	RESPONSABILIDAD	2024-02-11	1	35	2024	f
182	187	RESPONSABILIDAD	2024-07-19	1	265	2024	f
183	188	RESPONSABILIDAD	2024-09-18	1	343	2024	f
184	189	RESPONSABILIDAD	2024-05-24	1	186	2024	f
185	190	RESPONSABILIDAD	2025-01-02	1	3	2025	f
186	191	RESPONSABILIDAD	2024-07-30	1	278	2024	f
187	192	RESPONSABILIDAD	2024-08-23	1	308	2024	f
188	193	RESPONSABILIDAD	2024-07-18	1	263	2024	f
189	194	RESPONSABILIDAD	2025-01-08	1	15	2025	f
190	195	RESPONSABILIDAD	2024-05-10	1	160	2024	f
191	196	RESPONSABILIDAD	2024-04-20	1	133	2024	f
192	197	RESPONSABILIDAD	2024-04-30	1	149	2024	f
193	198	RESPONSABILIDAD	2024-01-25	1	17	2024	f
194	199	RESPONSABILIDAD	2024-06-04	1	210	2024	f
195	200	RESPONSABILIDAD	2024-08-07	1	299	2024	f
196	201	RESPONSABILIDAD	2025-01-31	1	55	2025	f
197	202	RESPONSABILIDAD	2024-04-28	1	140	2024	f
198	203	RESPONSABILIDAD	2024-02-27	1	54	2024	f
199	204	RESPONSABILIDAD	2025-02-03	1	68	2025	f
200	205	RESPONSABILIDAD	2025-01-09	1	17	2025	f
201	206	RESPONSABILIDAD	2024-11-03	1	375	2024	f
202	208	RESPONSABILIDAD	2024-12-09	1	412	2024	f
203	209	RESPONSABILIDAD	2024-02-20	1	44	2024	f
204	211	RESPONSABILIDAD	2025-02-04	1	69	2025	f
205	212	RESPONSABILIDAD	2025-01-20	1	22	2025	f
206	213	RESPONSABILIDAD	2024-08-28	1	329	2024	f
207	214	RESPONSABILIDAD	2024-05-01	1	152	2024	f
208	215	RESPONSABILIDAD	2024-12-03	1	404	2024	f
209	216	RESPONSABILIDAD	2024-08-08	1	300	2024	f
210	217	RESPONSABILIDAD	2024-07-22	1	266	2024	f
211	218	RESPONSABILIDAD	2024-09-06	1	338	2024	f
212	219	RESPONSABILIDAD	2024-02-07	1	32	2024	f
213	220	RESPONSABILIDAD	2024-08-01	1	289	2024	f
214	221	RESPONSABILIDAD	2024-10-31	1	374	2024	f
215	222	RESPONSABILIDAD	2024-06-30	1	242	2024	f
216	224	RESPONSABILIDAD	2025-02-03	1	65	2025	f
217	225	RESPONSABILIDAD	2025-02-13	1	92	2025	f
218	226	RESPONSABILIDAD	2024-08-26	1	304	2024	f
219	227	RESPONSABILIDAD	2025-01-20	1	24	2025	f
220	228	RESPONSABILIDAD	2024-05-10	1	161	2024	f
221	229	RESPONSABILIDAD	2024-09-06	1	337	2024	f
222	230	RESPONSABILIDAD	2024-05-25	1	196	2024	f
223	231	RESPONSABILIDAD	2025-02-05	1	72	2025	f
224	232	RESPONSABILIDAD	2024-11-27	1	399	2024	f
225	233	RESPONSABILIDAD	2025-01-28	1	32	2025	f
226	234	RESPONSABILIDAD	2024-05-28	1	198	2024	f
227	235	RESPONSABILIDAD	2025-01-27	1	29	2025	f
228	236	RESPONSABILIDAD	2024-04-17	1	98	2024	f
229	237	RESPONSABILIDAD	2025-01-03	1	7	2025	f
230	238	RESPONSABILIDAD	2024-09-27	1	354	2024	f
231	239	RESPONSABILIDAD	2025-01-03	1	6	2025	f
232	240	RESPONSABILIDAD	2024-06-04	1	209	2024	f
233	241	RESPONSABILIDAD	2024-07-31	1	285	2024	f
234	242	RESPONSABILIDAD	2024-08-20	1	303	2024	f
235	243	RESPONSABILIDAD	2024-10-19	1	367	2024	f
236	244	RESPONSABILIDAD	2024-10-16	1	360	2024	f
237	245	RESPONSABILIDAD	2024-09-30	1	356	2024	f
238	246	RESPONSABILIDAD	2024-02-29	1	56	2024	f
239	247	RESPONSABILIDAD	2025-01-28	1	45	2025	f
240	249	RESPONSABILIDAD	2024-04-22	1	122	2024	f
241	250	RESPONSABILIDAD	2024-06-13	1	233	2024	f
242	251	RESPONSABILIDAD	2024-08-01	1	287	2024	f
243	252	RESPONSABILIDAD	2025-01-28	1	49	2025	f
244	254	RESPONSABILIDAD	2024-09-17	1	340	2024	f
245	255	RESPONSABILIDAD	2024-06-30	1	244	2024	f
246	256	RESPONSABILIDAD	2024-02-05	1	28	2024	f
247	257	RESPONSABILIDAD	2024-03-17	1	70	2024	f
248	258	RESPONSABILIDAD	2025-01-28	1	44	2025	f
249	259	RESPONSABILIDAD	2025-02-11	1	88	2025	f
250	260	RESPONSABILIDAD	2024-03-20	1	73	2024	f
251	261	RESPONSABILIDAD	2024-03-17	1	72	2024	f
252	262	RESPONSABILIDAD	2025-01-28	1	40	2025	f
253	263	RESPONSABILIDAD	2025-02-12	1	84	2025	f
254	264	RESPONSABILIDAD	2024-05-24	1	189	2024	f
255	265	RESPONSABILIDAD	2025-02-02	1	63	2025	f
256	266	RESPONSABILIDAD	2024-06-04	1	208	2024	f
257	267	RESPONSABILIDAD	2024-05-24	1	190	2024	f
258	268	RESPONSABILIDAD	2024-12-27	1	428	2024	f
259	269	RESPONSABILIDAD	2025-02-18	1	99	2025	f
260	270	RESPONSABILIDAD	2024-08-07	1	298	2024	f
261	271	RESPONSABILIDAD	2024-04-30	1	142	2024	f
262	272	RESPONSABILIDAD	2025-02-12	1	77	2025	f
263	273	RESPONSABILIDAD	2025-01-31	1	54	2025	f
264	274	RESPONSABILIDAD	2024-09-19	1	344	2024	f
265	275	RESPONSABILIDAD	2024-05-21	1	183	2024	f
266	276	RESPONSABILIDAD	2024-11-27	1	401	2024	f
267	277	RESPONSABILIDAD	2024-08-22	1	305	2024	f
268	278	RESPONSABILIDAD	2024-05-29	1	203	2024	f
269	279	RESPONSABILIDAD	2024-01-30	1	20	2024	f
270	280	RESPONSABILIDAD	2024-05-24	1	191	2024	f
271	281	RESPONSABILIDAD	2025-01-31	1	56	2025	f
272	282	RESPONSABILIDAD	2024-06-10	1	221	2024	f
273	283	RESPONSABILIDAD	2024-08-04	1	290	2024	f
274	284	RESPONSABILIDAD	2024-05-21	1	178	2024	f
275	285	RESPONSABILIDAD	2025-01-06	1	13	2025	f
276	286	RESPONSABILIDAD	2024-11-13	1	380	2024	f
277	287	RESPONSABILIDAD	2024-05-14	1	166	2024	f
278	288	RESPONSABILIDAD	2024-11-13	1	382	2024	f
279	290	RESPONSABILIDAD	2024-08-27	1	322	2024	f
280	291	RESPONSABILIDAD	2024-12-12	1	419	2024	f
281	294	RESPONSABILIDAD	2024-04-17	1	103	2024	f
282	295	RESPONSABILIDAD	2025-01-03	1	8	2025	f
283	296	RESPONSABILIDAD	2024-11-24	1	391	2024	f
284	297	RESPONSABILIDAD	2024-01-26	1	18	2024	f
285	298	RESPONSABILIDAD	2024-01-21	1	9	2024	f
286	300	RESPONSABILIDAD	2024-06-09	1	214	2024	f
287	301	RESPONSABILIDAD	2024-07-15	1	257	2024	f
288	302	RESPONSABILIDAD	2024-03-17	1	68	2024	f
289	303	RESPONSABILIDAD	2025-01-28	1	42	2025	f
290	304	RESPONSABILIDAD	2024-02-11	1	36	2024	f
291	305	RESPONSABILIDAD	2024-05-21	1	185	2024	f
292	306	RESPONSABILIDAD	2024-10-17	1	365	2024	f
293	307	RESPONSABILIDAD	2024-08-23	1	310	2024	f
294	308	RESPONSABILIDAD	2024-06-02	1	205	2024	f
295	309	RESPONSABILIDAD	2025-01-02	1	5	2025	f
296	310	RESPONSABILIDAD	2024-03-16	1	64	2024	f
297	311	RESPONSABILIDAD	2025-02-19	1	100	2025	f
298	312	RESPONSABILIDAD	2025-01-21	1	28	2025	f
299	313	RESPONSABILIDAD	2025-02-01	1	62	2025	f
300	314	RESPONSABILIDAD	2024-05-21	1	176	2024	f
301	315	RESPONSABILIDAD	2024-10-16	1	364	2024	f
302	316	RESPONSABILIDAD	2024-12-12	1	418	2024	f
303	317	RESPONSABILIDAD	2024-05-21	1	180	2024	f
304	318	RESPONSABILIDAD	2024-04-20	1	129	2024	f
305	319	RESPONSABILIDAD	2024-04-16	1	87	2024	f
306	320	RESPONSABILIDAD	2024-05-03	1	153	2024	f
307	321	RESPONSABILIDAD	2024-11-27	1	400	2024	f
308	322	RESPONSABILIDAD	2024-03-06	1	58	2024	f
309	323	RESPONSABILIDAD	2025-01-28	1	38	2025	f
310	324	RESPONSABILIDAD	2024-11-28	1	403	2024	f
311	325	RESPONSABILIDAD	2024-02-21	1	51	2024	f
312	326	RESPONSABILIDAD	2024-09-26	1	350	2024	f
313	327	RESPONSABILIDAD	2024-04-16	1	84	2024	f
314	328	RESPONSABILIDAD	2024-08-29	1	330	2024	f
315	329	RESPONSABILIDAD	2024-08-01	1	288	2024	f
316	331	RESPONSABILIDAD	2024-04-17	1	88	2024	f
317	332	RESPONSABILIDAD	2024-08-07	1	295	2024	f
318	333	RESPONSABILIDAD	2024-04-20	1	135	2024	f
319	334	RESPONSABILIDAD	2024-08-25	1	313	2024	f
320	335	RESPONSABILIDAD	2024-01-20	1	7	2024	f
321	336	RESPONSABILIDAD	2024-12-09	1	413	2024	f
322	337	RESPONSABILIDAD	2024-08-29	1	331	2024	f
323	338	RESPONSABILIDAD	2025-02-10	1	78	2025	f
324	339	RESPONSABILIDAD	2024-06-10	1	218	2024	f
325	340	RESPONSABILIDAD	2024-04-17	1	100	2024	f
326	341	RESPONSABILIDAD	2025-01-30	1	52	2025	f
327	342	RESPONSABILIDAD	2024-04-17	1	91	2024	f
328	343	RESPONSABILIDAD	2024-05-19	1	171	2024	f
329	344	RESPONSABILIDAD	2025-01-28	1	34	2025	f
330	345	RESPONSABILIDAD	2024-02-24	1	52	2024	f
331	346	RESPONSABILIDAD	2024-02-24	1	53	2024	f
332	347	RESPONSABILIDAD	2024-04-22	1	109	2024	f
333	348	RESPONSABILIDAD	2024-09-26	1	349	2024	f
334	349	RESPONSABILIDAD	2025-01-28	1	48	2025	f
335	350	RESPONSABILIDAD	2024-05-25	1	193	2024	f
336	351	RESPONSABILIDAD	2024-08-28	1	325	2024	f
337	352	RESPONSABILIDAD	2024-05-27	1	197	2024	f
338	353	RESPONSABILIDAD	2025-02-01	1	60	2025	f
339	354	RESPONSABILIDAD	2024-04-15	1	80	2024	f
340	355	RESPONSABILIDAD	2024-07-30	1	279	2024	f
341	356	RESPONSABILIDAD	2024-11-24	1	390	2024	f
342	357	RESPONSABILIDAD	2024-03-16	1	66	2024	f
343	358	RESPONSABILIDAD	2024-11-26	1	397	2024	f
344	359	RESPONSABILIDAD	2024-11-26	1	398	2024	f
345	360	RESPONSABILIDAD	2024-07-25	1	268	2024	f
346	361	RESPONSABILIDAD	2024-05-17	1	169	2024	f
347	362	RESPONSABILIDAD	2025-01-31	1	57	2025	f
348	363	RESPONSABILIDAD	2024-02-20	1	43	2024	f
349	364	RESPONSABILIDAD	2024-04-22	1	123	2024	f
350	365	RESPONSABILIDAD	2024-08-06	1	292	2024	f
351	366	RESPONSABILIDAD	2024-08-26	1	316	2024	f
352	367	RESPONSABILIDAD	2024-03-14	1	63	2024	f
353	368	RESPONSABILIDAD	2024-09-25	1	347	2024	f
354	369	RESPONSABILIDAD	2024-07-24	1	267	2024	f
355	370	RESPONSABILIDAD	2024-07-08	1	251	2024	f
356	371	RESPONSABILIDAD	2024-04-30	1	144	2024	f
357	372	RESPONSABILIDAD	2024-04-22	1	115	2024	f
358	373	RESPONSABILIDAD	2024-08-28	1	327	2024	f
359	374	RESPONSABILIDAD	2024-11-25	1	395	2024	f
360	375	RESPONSABILIDAD	2024-01-03	1	3	2024	f
361	376	RESPONSABILIDAD	2024-04-22	1	112	2024	f
362	377	RESPONSABILIDAD	2024-02-05	1	25	2024	f
363	378	RESPONSABILIDAD	2024-04-19	1	106	2024	f
364	379	RESPONSABILIDAD	2024-12-07	1	408	2024	f
365	380	RESPONSABILIDAD	2024-05-03	1	155	2024	f
366	381	RESPONSABILIDAD	2024-04-26	1	136	2024	f
367	382	RESPONSABILIDAD	2024-04-22	1	117	2024	f
368	383	RESPONSABILIDAD	2024-04-30	1	151	2024	f
369	384	RESPONSABILIDAD	2024-11-13	1	383	2024	f
370	385	RESPONSABILIDAD	2024-05-25	1	194	2024	f
371	386	RESPONSABILIDAD	2025-02-01	1	58	2025	f
372	387	RESPONSABILIDAD	2024-11-25	1	396	2024	f
373	388	RESPONSABILIDAD	2024-04-17	1	92	2024	f
374	389	RESPONSABILIDAD	2024-01-12	1	5	2024	f
375	390	RESPONSABILIDAD	2024-03-17	1	69	2024	f
376	391	RESPONSABILIDAD	2024-04-19	1	107	2024	f
377	392	RESPONSABILIDAD	2024-03-06	1	60	2024	f
378	393	RESPONSABILIDAD	2025-01-28	1	43	2025	f
379	394	RESPONSABILIDAD	2024-08-30	1	334	2025	f
380	395	RESPONSABILIDAD	2025-02-10	1	75	2025	f
381	396	RESPONSABILIDAD	2025-01-06	1	11	2025	f
382	397	RESPONSABILIDAD	2024-10-09	1	357	2024	f
383	398	RESPONSABILIDAD	2025-02-10	1	81	2025	f
384	399	RESPONSABILIDAD	2024-12-09	1	417	2024	f
385	400	RESPONSABILIDAD	2024-09-05	1	335	2024	f
386	401	RESPONSABILIDAD	2025-02-03	1	66	2025	f
387	402	RESPONSABILIDAD	2024-07-26	1	271	2024	f
388	403	RESPONSABILIDAD	2024-10-16	1	363	2024	f
389	404	RESPONSABILIDAD	2024-05-21	1	175	2024	f
390	406	RESPONSABILIDAD	2024-06-10	1	222	2024	f
391	407	RESPONSABILIDAD	2024-02-20	1	42	2024	f
392	408	RESPONSABILIDAD	2024-02-07	1	31	2024	f
393	409	RESPONSABILIDAD	2024-04-22	1	118	2024	f
394	410	RESPONSABILIDAD	2024-08-23	1	309	2024	f
395	411	RESPONSABILIDAD	2024-05-19	1	170	2024	f
396	412	RESPONSABILIDAD	2024-11-27	1	402	2024	f
397	413	RESPONSABILIDAD	2024-08-23	1	306	2024	f
398	414	RESPONSABILIDAD	2024-07-18	1	259	2024	f
399	415	RESPONSABILIDAD	2024-04-20	1	131	2024	f
400	416	RESPONSABILIDAD	2024-02-21	1	50	2024	f
401	417	RESPONSABILIDAD	2024-04-24	1	110	2024	f
402	418	RESPONSABILIDAD	2024-11-21	1	388	2024	f
403	419	RESPONSABILIDAD	2024-02-05	1	23	2024	f
404	420	RESPONSABILIDAD	2024-02-20	1	46	2024	f
405	421	RESPONSABILIDAD	2024-07-29	1	277	2024	f
406	422	RESPONSABILIDAD	2024-07-08	1	254	2024	f
407	423	RESPONSABILIDAD	2024-02-06	1	29	2024	f
408	424	RESPONSABILIDAD	2025-02-10	1	86	2025	f
409	425	RESPONSABILIDAD	2024-06-30	1	240	2024	f
410	426	RESPONSABILIDAD	2024-02-10	1	34	2024	f
411	427	RESPONSABILIDAD	2024-11-21	1	389	2024	f
412	428	RESPONSABILIDAD	2024-04-15	1	79	2024	f
413	429	RESPONSABILIDAD	2024-05-24	1	192	2024	f
414	430	RESPONSABILIDAD	2025-01-06	1	12	2025	f
415	431	RESPONSABILIDAD	2024-04-20	1	130	2024	f
416	432	RESPONSABILIDAD	2024-08-04	1	291	2024	f
417	433	RESPONSABILIDAD	2024-07-29	1	276	2024	f
418	434	RESPONSABILIDAD	2024-05-13	1	164	2024	f
419	435	RESPONSABILIDAD	2024-09-26	1	352	2024	f
420	436	RESPONSABILIDAD	2024-04-30	1	147	2024	f
421	437	RESPONSABILIDAD	2024-03-16	1	65	2024	f
422	438	RESPONSABILIDAD	2024-02-07	1	30	2024	f
423	439	RESPONSABILIDAD	2024-07-25	1	270	2024	f
424	440	RESPONSABILIDAD	2024-04-17	1	97	2024	f
425	441	RESPONSABILIDAD	2025-01-31	1	53	2025	f
426	442	RESPONSABILIDAD	2024-06-17	1	236	2024	f
427	443	RESPONSABILIDAD	2025-01-19	1	19	2025	f
428	445	RESPONSABILIDAD	2025-01-20	1	25	2025	f
429	446	RESPONSABILIDAD	2024-11-13	1	377	2024	f
430	447	RESPONSABILIDAD	2024-08-29	1	332	2024	f
431	449	RESPONSABILIDAD	2024-10-16	1	361	2024	f
432	450	RESPONSABILIDAD	2024-12-12	1	423	2024	f
433	451	RESPONSABILIDAD	2024-09-26	1	351	2024	f
434	452	RESPONSABILIDAD	2024-05-25	1	195	2024	f
435	453	RESPONSABILIDAD	2025-02-01	1	59	2025	f
436	455	RESPONSABILIDAD	2024-10-30	1	371	2024	f
437	456	RESPONSABILIDAD	2024-07-31	1	280	2024	f
438	457	RESPONSABILIDAD	2024-04-17	1	90	2024	f
439	458	RESPONSABILIDAD	2024-02-02	1	22	2024	f
440	459	RESPONSABILIDAD	2025-01-28	1	46	2025	f
441	460	RESPONSABILIDAD	2024-06-11	1	228	2024	f
442	461	RESPONSABILIDAD	2024-04-20	1	127	2024	f
443	462	RESPONSABILIDAD	2024-04-16	1	82	2024	f
444	463	RESPONSABILIDAD	2024-04-17	1	102	2024	f
445	464	RESPONSABILIDAD	2024-03-17	1	71	2024	f
446	465	RESPONSABILIDAD	2025-01-28	1	41	2025	f
447	466	RESPONSABILIDAD	2024-03-20	1	75	2024	f
448	467	RESPONSABILIDAD	2024-05-21	1	182	2024	f
449	468	RESPONSABILIDAD	2024-08-26	1	318	2024	f
450	469	RESPONSABILIDAD	2024-08-22	1	302	2024	f
451	470	RESPONSABILIDAD	2024-08-07	1	296	2024	f
452	471	RESPONSABILIDAD	2024-07-05	1	245	2024	f
453	472	RESPONSABILIDAD	2024-08-29	1	333	2024	f
454	473	RESPONSABILIDAD	2024-06-12	1	232	2024	f
455	474	RESPONSABILIDAD	2024-04-22	1	119	2024	f
456	475	RESPONSABILIDAD	2024-08-27	1	324	2024	f
457	476	RESPONSABILIDAD	2024-07-31	1	283	2024	f
458	477	RESPONSABILIDAD	2024-04-15	1	81	2024	f
459	478	RESPONSABILIDAD	2024-02-20	1	45	2024	f
460	479	RESPONSABILIDAD	2024-05-29	1	204	2024	f
461	480	RESPONSABILIDAD	2024-08-25	1	314	2024	f
462	481	RESPONSABILIDAD	2024-05-24	1	188	2024	f
463	482	RESPONSABILIDAD	2025-01-27	1	30	2025	f
464	483	RESPONSABILIDAD	2024-06-30	1	243	2024	f
465	484	RESPONSABILIDAD	2025-02-12	1	91	2025	f
466	485	RESPONSABILIDAD	2024-04-16	1	85	2024	f
467	486	RESPONSABILIDAD	2024-07-08	1	253	2024	f
468	487	RESPONSABILIDAD	2024-01-12	1	6	2024	f
469	488	RESPONSABILIDAD	2025-02-18	1	98	2025	f
470	489	RESPONSABILIDAD	2024-02-05	1	27	2024	f
471	490	RESPONSABILIDAD	2024-08-18	1	301	2024	f
472	491	RESPONSABILIDAD	2024-04-26	1	137	2024	f
473	492	RESPONSABILIDAD	2024-06-11	1	225	2024	f
474	493	RESPONSABILIDAD	2024-06-11	1	226	2024	f
475	494	RESPONSABILIDAD	2024-08-25	1	315	2024	f
476	495	RESPONSABILIDAD	2024-05-14	1	168	2024	f
477	496	RESPONSABILIDAD	2024-11-13	1	377	2025	f
478	497	RESPONSABILIDAD	2024-01-23	1	14	2024	f
479	498	RESPONSABILIDAD	2024-04-30	1	146	2024	f
480	499	RESPONSABILIDAD	2024-12-03	1	405	2024	f
481	500	RESPONSABILIDAD	2025-02-10	1	79	2025	f
482	501	RESPONSABILIDAD	2024-10-30	1	370	2024	f
483	503	RESPONSABILIDAD	2024-02-20	1	40	2024	f
484	504	RESPONSABILIDAD	2024-06-11	1	223	2024	f
485	506	RESPONSABILIDAD	2024-10-15	1	359	2024	f
486	507	RESPONSABILIDAD	2024-06-02	1	207	2024	f
487	508	RESPONSABILIDAD	2024-06-17	1	235	2024	f
488	510	RESPONSABILIDAD	2024-01-23	1	12	2024	f
489	511	RESPONSABILIDAD	2025-02-13	1	93	2025	f
490	512	RESPONSABILIDAD	2024-04-30	1	150	2024	f
491	513	RESPONSABILIDAD	2024-08-28	1	328	2024	f
492	514	RESPONSABILIDAD	2024-05-06	1	157	2024	f
493	515	RESPONSABILIDAD	2024-12-30	1	429	2024	f
494	516	RESPONSABILIDAD	2024-08-26	1	317	2024	f
495	517	RESPONSABILIDAD	2024-02-14	1	37	2024	f
496	518	RESPONSABILIDAD	2024-04-30	1	148	2024	f
497	519	RESPONSABILIDAD	2024-11-13	1	379	2024	f
498	520	RESPONSABILIDAD	2025-01-06	1	14	2025	f
499	521	RESPONSABILIDAD	2024-07-08	1	252	2024	f
500	522	RESPONSABILIDAD	2024-05-30	1	156	2024	f
501	523	RESPONSABILIDAD	2024-12-07	1	409	2024	f
502	524	RESPONSABILIDAD	2024-09-25	1	348	2024	f
503	525	RESPONSABILIDAD	2025-01-04	1	2	2025	f
504	526	RESPONSABILIDAD	2024-02-21	1	47	2024	f
505	527	RESPONSABILIDAD	2024-07-29	1	273	2024	f
506	528	RESPONSABILIDAD	2024-06-17	1	237	2024	f
507	529	RESPONSABILIDAD	2024-09-19	1	345	2024	f
508	530	RESPONSABILIDAD	2024-09-27	1	353	2024	f
509	531	RESPONSABILIDAD	2024-06-11	1	229	2024	f
510	532	RESPONSABILIDAD	2024-09-17	1	339	2024	f
511	533	RESPONSABILIDAD	2024-06-11	1	224	2024	f
512	534	RESPONSABILIDAD	2024-02-21	1	49	2024	f
513	535	RESPONSABILIDAD	2025-02-10	1	76	2025	f
514	536	RESPONSABILIDAD	2024-10-14	1	358	2024	f
515	537	RESPONSABILIDAD	2024-04-26	1	138	2024	f
516	538	RESPONSABILIDAD	2024-04-16	1	83	2024	f
517	540	RESPONSABILIDAD	2025-02-17	1	95	2025	f
518	541	RESPONSABILIDAD	2025-06-03	1	142	2025	f
519	542	RESPONSABILIDAD	2025-06-04	1	143	2025	f
520	543	RESPONSABILIDAD	2025-02-17	1	96	2025	f
521	544	RESPONSABILIDAD	2025-06-08	1	156	2025	f
522	545	RESPONSABILIDAD	2025-02-17	1	97	2025	f
523	546	RESPONSABILIDAD	2025-02-23	1	102	2025	f
524	547	RESPONSABILIDAD	2025-06-08	1	150	2025	f
525	548	RESPONSABILIDAD	2025-06-10	1	169	2025	f
526	549	RESPONSABILIDAD	2025-03-02	1	117	2025	f
527	550	RESPONSABILIDAD	2025-06-08	1	146	2025	f
528	552	RESPONSABILIDAD	2025-06-09	1	158	2025	f
529	553	RESPONSABILIDAD	2025-02-28	1	115	2025	f
530	554	RESPONSABILIDAD	2025-03-02	1	118	2025	f
531	555	RESPONSABILIDAD	2025-06-09	1	159	2025	f
532	556	RESPONSABILIDAD	2025-03-02	1	116	2025	f
533	557	RESPONSABILIDAD	2025-06-08	1	145	2025	f
534	558	RESPONSABILIDAD	2025-02-23	1	103	2025	f
535	559	RESPONSABILIDAD	2025-06-09	1	161	2025	f
536	560	RESPONSABILIDAD	2025-06-09	1	162	2025	f
537	561	RESPONSABILIDAD	2025-02-23	1	104	2025	f
538	562	RESPONSABILIDAD	2025-02-26	1	112	2025	f
539	563	RESPONSABILIDAD	2025-06-08	1	149	2025	f
540	564	RESPONSABILIDAD	2025-02-26	1	113	2025	f
541	565	RESPONSABILIDAD	2025-06-09	1	163	2025	f
542	566	RESPONSABILIDAD	2025-02-26	1	114	2025	f
543	567	RESPONSABILIDAD	2025-06-08	1	147	2025	f
544	568	RESPONSABILIDAD	2025-06-08	1	154	2025	f
545	569	RESPONSABILIDAD	2025-02-24	1	105	2025	f
546	570	RESPONSABILIDAD	2025-02-26	1	111	2025	f
547	571	RESPONSABILIDAD	2025-06-08	1	153	2025	f
548	572	RESPONSABILIDAD	2025-06-08	1	155	2025	f
549	573	RESPONSABILIDAD	2025-02-26	1	106	2025	f
550	574	RESPONSABILIDAD	2025-02-26	1	110	2025	f
551	575	RESPONSABILIDAD	2025-06-08	1	151	2025	f
552	576	RESPONSABILIDAD	2025-02-26	1	108	2025	f
553	577	RESPONSABILIDAD	2025-06-08	1	152	2025	f
554	578	RESPONSABILIDAD	2025-02-26	1	109	2025	f
555	579	RESPONSABILIDAD	2025-06-09	1	160	2025	f
556	580	RESPONSABILIDAD	2025-02-26	1	107	2025	f
557	581	RESPONSABILIDAD	2025-06-23	1	230	2025	f
558	582	RESPONSABILIDAD	2025-03-05	1	119	2025	f
559	583	RESPONSABILIDAD	2025-06-10	1	172	2025	f
560	584	RESPONSABILIDAD	2025-04-06	1	127	2025	f
561	585	RESPONSABILIDAD	2025-06-10	1	173	2025	f
562	586	RESPONSABILIDAD	2025-06-10	1	177	2025	f
563	587	RESPONSABILIDAD	2025-04-04	1	128	2025	f
564	588	RESPONSABILIDAD	2025-04-17	1	131	2025	f
565	589	RESPONSABILIDAD	2025-06-10	1	182	2025	f
566	590	RESPONSABILIDAD	2025-06-10	1	174	2025	f
567	591	RESPONSABILIDAD	2025-04-17	1	132	2025	f
568	592	RESPONSABILIDAD	2025-03-10	1	121	2025	f
569	593	RESPONSABILIDAD	2025-06-10	1	175	2025	f
570	594	RESPONSABILIDAD	2025-03-21	1	122	2025	f
571	595	RESPONSABILIDAD	2025-06-17	1	209	2025	f
572	596	RESPONSABILIDAD	2025-03-24	1	123	2025	f
573	597	RESPONSABILIDAD	2025-06-08	1	157	2025	f
574	598	RESPONSABILIDAD	2025-04-09	1	129	2025	f
575	599	RESPONSABILIDAD	2025-06-27	1	256	2025	f
576	600	RESPONSABILIDAD	2025-06-10	1	179	2025	f
577	601	RESPONSABILIDAD	2025-04-03	1	124	2025	f
578	602	RESPONSABILIDAD	2025-04-12	1	130	2025	f
579	603	RESPONSABILIDAD	2025-06-10	1	180	2025	f
580	604	RESPONSABILIDAD	2025-06-10	1	181	2025	f
581	605	RESPONSABILIDAD	2025-04-04	1	126	2025	f
582	606	RESPONSABILIDAD	2025-06-23	1	231	2025	f
583	607	RESPONSABILIDAD	2025-04-03	1	125	2025	f
584	608	RESPONSABILIDAD	2025-06-10	1	170	2025	f
585	609	RESPONSABILIDAD	2025-04-19	1	133	2025	f
586	610	RESPONSABILIDAD	2025-05-06	1	134	2025	f
587	611	RESPONSABILIDAD	2025-06-10	1	171	2025	f
588	612	RESPONSABILIDAD	2025-06-23	1	233	2025	f
589	613	RESPONSABILIDAD	2025-05-06	1	135	2025	f
590	614	RESPONSABILIDAD	2025-06-16	1	207	2025	f
591	615	RESPONSABILIDAD	2025-05-30	1	139	2025	f
592	616	RESPONSABILIDAD	2025-05-30	1	140	2025	f
593	617	RESPONSABILIDAD	2025-06-16	1	201	2025	f
594	618	RESPONSABILIDAD	2025-07-16	1	290	2025	f
595	619	RESPONSABILIDAD	2025-05-30	1	141	2025	f
596	620	RESPONSABILIDAD	2025-06-27	1	255	2025	f
597	621	RESPONSABILIDAD	2025-05-28	1	136	2025	f
598	622	RESPONSABILIDAD	2025-05-28	1	137	2025	f
599	623	RESPONSABILIDAD	2025-06-30	1	259	2025	f
600	624	RESPONSABILIDAD	2025-05-28	1	138	2025	f
601	625	RESPONSABILIDAD	2025-06-10	1	176	2025	f
602	626	RESPONSABILIDAD	2025-06-23	1	232	2025	f
603	627	RESPONSABILIDAD	2025-06-09	1	165	2025	f
604	628	RESPONSABILIDAD	2025-06-09	1	166	2025	f
605	629	RESPONSABILIDAD	2025-06-10	1	167	2025	f
606	630	RESPONSABILIDAD	2025-06-09	1	168	2025	f
607	632	RESPONSABILIDAD	2025-06-30	1	261	2025	f
608	633	RESPONSABILIDAD	2025-06-11	1	183	2025	f
609	634	RESPONSABILIDAD	2025-06-25	1	236	2025	f
610	635	RESPONSABILIDAD	2025-06-16	1	200	2025	f
611	636	RESPONSABILIDAD	2025-07-01	1	263	2025	f
612	638	RESPONSABILIDAD	2025-06-13	1	188	2025	f
613	639	RESPONSABILIDAD	2025-06-13	1	185	2025	f
614	641	RESPONSABILIDAD	2025-06-13	1	186	2025	f
615	642	RESPONSABILIDAD	2025-06-14	1	198	2025	f
616	643	RESPONSABILIDAD	2025-09-22	1	416	2025	f
617	644	RESPONSABILIDAD	2025-06-13	1	187	2025	f
618	645	RESPONSABILIDAD	2025-06-13	1	189	2025	f
619	646	RESPONSABILIDAD	2025-06-13	1	191	2025	f
620	647	RESPONSABILIDAD	2025-06-13	1	190	2025	f
621	648	RESPONSABILIDAD	2025-06-13	1	184	2025	f
622	649	RESPONSABILIDAD	2025-06-21	1	216	2025	f
623	650	RESPONSABILIDAD	2025-06-14	1	193	2025	f
624	651	RESPONSABILIDAD	2025-06-30	1	260	2025	f
625	652	RESPONSABILIDAD	2025-06-14	1	195	2025	f
626	653	RESPONSABILIDAD	2025-06-30	1	262	2025	f
627	655	RESPONSABILIDAD	2025-06-22	1	228	2025	f
628	658	RESPONSABILIDAD	2025-06-25	1	237	2025	f
629	659	RESPONSABILIDAD	2025-06-14	1	192	2025	f
630	660	RESPONSABILIDAD	2025-07-28	1	326	2025	f
631	661	RESPONSABILIDAD	2025-06-19	1	213	2025	f
632	662	RESPONSABILIDAD	2025-07-03	1	266	2025	f
633	663	RESPONSABILIDAD	2025-06-16	1	199	2025	f
634	664	RESPONSABILIDAD	2025-06-14	1	197	2025	f
635	665	RESPONSABILIDAD	2025-06-14	1	196	2025	f
636	666	RESPONSABILIDAD	2025-06-16	1	206	2025	f
637	667	RESPONSABILIDAD	2025-06-17	1	208	2025	f
638	669	RESPONSABILIDAD	2025-07-22	1	305	2025	f
639	670	RESPONSABILIDAD	2025-07-25	1	319	2025	f
640	672	RESPONSABILIDAD	2025-06-17	1	202	2025	f
641	673	RESPONSABILIDAD	2025-07-24	1	316	2025	f
642	674	RESPONSABILIDAD	2025-06-23	1	229	2025	f
643	675	RESPONSABILIDAD	2025-06-21	1	217	2025	f
644	676	RESPONSABILIDAD	2025-06-21	1	214	2025	f
645	678	RESPONSABILIDAD	2025-06-17	1	203	2025	f
646	679	RESPONSABILIDAD	2025-12-10	1	560	2025	f
647	680	RESPONSABILIDAD	2025-06-21	1	218	2025	f
648	682	RESPONSABILIDAD	2025-06-22	1	223	2025	f
649	684	RESPONSABILIDAD	2025-07-21	1	298	2025	f
650	685	RESPONSABILIDAD	2025-07-21	1	299	2025	f
651	686	RESPONSABILIDAD	2025-07-21	1	300	2025	f
652	688	RESPONSABILIDAD	2025-07-21	1	297	2025	f
653	689	RESPONSABILIDAD	2025-07-21	1	296	2025	f
654	690	RESPONSABILIDAD	2025-06-21	1	215	2025	f
655	691	RESPONSABILIDAD	2025-07-08	1	281	2025	f
656	692	RESPONSABILIDAD	2025-06-22	1	224	2025	f
657	693	RESPONSABILIDAD	2025-06-22	1	219	2025	f
658	694	RESPONSABILIDAD	2025-06-22	1	225	2025	f
659	695	RESPONSABILIDAD	2025-06-22	1	227	2025	f
660	696	RESPONSABILIDAD	2025-06-22	1	220	2025	f
661	698	RESPONSABILIDAD	2025-06-22	1	226	2025	f
662	700	RESPONSABILIDAD	2025-06-22	1	221	2025	f
663	701	RESPONSABILIDAD	2025-06-22	1	222	2025	f
664	703	RESPONSABILIDAD	2025-07-06	1	268	2025	f
665	704	RESPONSABILIDAD	2025-07-06	1	267	2025	f
666	707	RESPONSABILIDAD	2025-07-06	1	274	2025	f
667	709	RESPONSABILIDAD	2025-07-06	1	272	2025	f
668	710	RESPONSABILIDAD	2025-09-13	1	383	2025	f
669	711	RESPONSABILIDAD	2025-07-06	1	273	2025	f
670	712	RESPONSABILIDAD	2025-07-06	1	271	2025	f
671	713	RESPONSABILIDAD	2025-10-08	1	449	2025	f
672	714	RESPONSABILIDAD	2025-09-22	1	417	2025	f
673	715	RESPONSABILIDAD	2025-09-22	1	418	2025	f
674	716	RESPONSABILIDAD	2025-09-13	1	385	2025	f
675	717	RESPONSABILIDAD	2025-09-13	1	382	2025	f
676	718	RESPONSABILIDAD	2025-09-15	1	389	2025	f
677	720	RESPONSABILIDAD	2025-09-15	1	390	2025	f
678	722	RESPONSABILIDAD	2025-09-15	1	391	2025	f
679	723	RESPONSABILIDAD	2025-09-17	1	393	2025	f
680	726	RESPONSABILIDAD	2025-09-13	1	384	2025	f
681	728	RESPONSABILIDAD	2026-01-12	1	17	2026	f
682	729	RESPONSABILIDAD	2026-01-13	1	18	2026	f
683	734	RESPONSABILIDAD	2025-07-09	1	284	2025	f
684	735	RESPONSABILIDAD	2025-07-16	1	289	2025	f
685	736	RESPONSABILIDAD	2025-07-06	1	270	2025	f
686	738	RESPONSABILIDAD	2025-07-06	1	269	2025	f
687	739	RESPONSABILIDAD	2025-07-08	1	279	2025	f
688	740	RESPONSABILIDAD	2025-07-22	1	304	2025	f
689	741	RESPONSABILIDAD	2025-07-08	1	282	2025	f
690	742	RESPONSABILIDAD	2025-07-08	1	283	2025	f
691	746	RESPONSABILIDAD	2025-07-07	1	276	2025	f
692	747	RESPONSABILIDAD	2025-07-07	1	277	2025	f
693	748	RESPONSABILIDAD	2025-07-07	1	275	2025	f
694	750	RESPONSABILIDAD	2025-09-14	1	388	2025	f
695	751	RESPONSABILIDAD	2025-07-09	1	285	2025	f
696	752	RESPONSABILIDAD	2025-08-07	1	347	2025	f
697	754	RESPONSABILIDAD	2025-07-19	1	294	2025	f
698	755	RESPONSABILIDAD	2025-07-13	1	286	2025	f
699	756	RESPONSABILIDAD	2025-08-08	1	352	2025	f
700	758	RESPONSABILIDAD	2025-07-08	1	278	2025	f
701	759	RESPONSABILIDAD	2025-07-18	1	293	2025	f
702	761	RESPONSABILIDAD	2025-07-23	1	308	2025	f
703	762	RESPONSABILIDAD	2025-07-23	1	309	2025	f
704	767	RESPONSABILIDAD	2025-07-15	1	287	2025	f
705	768	RESPONSABILIDAD	2025-07-15	1	288	2025	f
706	770	RESPONSABILIDAD	2025-06-25	1	235	2025	f
707	771	RESPONSABILIDAD	2025-06-25	1	238	2025	f
708	772	RESPONSABILIDAD	2025-06-18	1	210	2025	f
709	773	RESPONSABILIDAD	2025-08-31	1	369	2025	f
710	776	RESPONSABILIDAD	2025-08-01	1	337	2025	f
711	777	RESPONSABILIDAD	2025-07-02	1	265	2025	f
712	778	RESPONSABILIDAD	2025-07-29	1	330	2025	f
713	779	RESPONSABILIDAD	2025-07-29	1	329	2025	f
714	780	RESPONSABILIDAD	2025-07-02	1	264	2025	f
715	781	RESPONSABILIDAD	2025-06-29	1	257	2025	f
716	782	RESPONSABILIDAD	2025-07-28	1	328	2025	f
717	783	RESPONSABILIDAD	2025-06-30	1	258	2025	f
718	784	RESPONSABILIDAD	2025-10-10	1	414	2025	f
719	785	RESPONSABILIDAD	2025-08-20	1	355	2025	f
720	787	RESPONSABILIDAD	2025-01-28	1	148	2025	f
721	788	RESPONSABILIDAD	2025-07-23	1	313	2025	f
722	789	RESPONSABILIDAD	2025-07-22	1	306	2025	f
723	790	RESPONSABILIDAD	2025-07-19	1	295	2025	f
724	791	RESPONSABILIDAD	2025-07-23	1	312	2025	f
725	792	RESPONSABILIDAD	2025-07-28	1	323	2025	f
726	793	RESPONSABILIDAD	2025-08-06	1	346	2025	f
727	794	RESPONSABILIDAD	2025-08-20	1	358	2025	f
728	796	RESPONSABILIDAD	2025-08-20	1	357	2025	f
729	797	RESPONSABILIDAD	2025-09-03	1	370	2025	f
730	798	RESPONSABILIDAD	2025-08-22	1	365	2025	f
731	799	RESPONSABILIDAD	2025-07-21	1	302	2025	f
732	801	RESPONSABILIDAD	2025-07-31	1	335	2025	f
733	802	RESPONSABILIDAD	2025-07-28	1	322	2025	f
734	803	RESPONSABILIDAD	2025-07-29	1	331	2025	f
735	804	RESPONSABILIDAD	2025-07-28	1	325	2025	f
736	805	RESPONSABILIDAD	2025-07-28	1	324	2025	f
737	806	RESPONSABILIDAD	2025-07-22	1	307	2025	f
738	807	RESPONSABILIDAD	2025-07-26	1	321	2025	f
739	808	RESPONSABILIDAD	2025-08-07	1	349	2025	f
740	809	RESPONSABILIDAD	2025-07-26	1	320	2025	f
741	811	RESPONSABILIDAD	2025-07-23	1	311	2025	f
742	812	RESPONSABILIDAD	2025-07-24	1	315	2025	f
743	814	RESPONSABILIDAD	2025-08-20	1	356	2025	f
744	815	RESPONSABILIDAD	2025-07-18	1	291	2025	f
745	816	RESPONSABILIDAD	2025-07-18	1	292	2025	f
746	817	RESPONSABILIDAD	2025-07-23	1	310	2025	f
747	818	RESPONSABILIDAD	2025-07-21	1	301	2025	f
748	819	RESPONSABILIDAD	2025-07-28	1	327	2025	f
749	821	RESPONSABILIDAD	2025-08-01	1	338	2025	f
928	1025	RESPONSABILIDAD	2025-12-12	1	564	2025	f
929	1026	RESPONSABILIDAD	2025-10-29	1	489	2025	f
930	1027	RESPONSABILIDAD	2025-10-29	1	490	2025	f
931	1028	RESPONSABILIDAD	2025-11-05	1	502	2025	f
932	1029	RESPONSABILIDAD	2025-11-14	1	533	2025	f
933	1030	RESPONSABILIDAD	2025-11-12	1	525	2025	f
934	1031	RESPONSABILIDAD	2025-11-26	1	544	2025	f
935	1032	RESPONSABILIDAD	2025-11-26	1	545	2025	f
936	1033	RESPONSABILIDAD	2025-11-20	1	540	2025	f
937	1034	RESPONSABILIDAD	2025-11-12	1	526	2025	f
938	1035	RESPONSABILIDAD	2025-11-14	1	531	2025	f
939	1036	RESPONSABILIDAD	2025-12-01	1	546	2025	f
940	1037	RESPONSABILIDAD	2025-12-26	1	575	2025	f
941	1038	RESPONSABILIDAD	2025-12-26	1	579	2025	f
942	1039	RESPONSABILIDAD	2025-12-27	1	583	2025	f
943	1040	RESPONSABILIDAD	2025-12-12	1	568	2025	f
944	1041	RESPONSABILIDAD	2025-12-28	1	588	2025	f
945	1042	RESPONSABILIDAD	2025-12-27	1	582	2025	f
946	1043	RESPONSABILIDAD	2025-12-26	1	580	2025	f
947	1044	RESPONSABILIDAD	2025-12-26	1	578	2025	f
948	1045	RESPONSABILIDAD	2025-12-27	1	587	2025	f
949	1046	RESPONSABILIDAD	2025-12-27	1	586	2025	f
950	1047	RESPONSABILIDAD	2025-12-11	1	561	2025	f
951	1048	RESPONSABILIDAD	2025-12-30	1	594	2025	f
952	1049	RESPONSABILIDAD	2025-12-12	1	567	2025	f
953	1050	RESPONSABILIDAD	2026-01-02	1	4	2026	f
954	1051	RESPONSABILIDAD	2025-12-16	1	570	2025	f
955	1052	RESPONSABILIDAD	2026-01-02	1	2	2026	f
956	1053	RESPONSABILIDAD	2025-12-27	1	585	2025	f
957	1054	RESPONSABILIDAD	2025-12-16	1	569	2025	f
958	1055	RESPONSABILIDAD	2025-12-16	1	571	2025	f
959	1056	RESPONSABILIDAD	2025-12-30	1	597	2025	f
960	1059	RESPONSABILIDAD	2025-12-26	1	577	2025	f
961	1061	RESPONSABILIDAD	2025-12-11	1	562	2025	f
962	1062	RESPONSABILIDAD	2026-01-05	1	9	2026	f
963	1063	RESPONSABILIDAD	2025-12-18	1	574	2025	f
964	1064	RESPONSABILIDAD	2025-12-12	1	556	2025	f
965	1065	RESPONSABILIDAD	2026-01-05	1	10	2026	f
966	1066	RESPONSABILIDAD	2025-12-27	1	584	2025	f
967	1067	RESPONSABILIDAD	2025-12-26	1	576	2025	f
968	1068	RESPONSABILIDAD	2025-12-27	1	581	2025	f
969	1069	RESPONSABILIDAD	2026-01-03	1	8	2026	f
970	1070	RESPONSABILIDAD	2025-12-30	1	596	2025	f
971	1071	RESPONSABILIDAD	2026-01-03	1	7	2026	f
972	1072	RESPONSABILIDAD	2025-12-29	1	591	2025	f
973	1073	RESPONSABILIDAD	2025-12-30	1	595	2025	f
974	1074	RESPONSABILIDAD	2025-12-29	1	590	2025	f
975	1077	RESPONSABILIDAD	2026-01-13	1	19	2026	f
976	1082	RESPONSABILIDAD	2025-12-30	1	598	2025	f
977	1084	RESPONSABILIDAD	2026-01-01	1	1	2026	f
978	1085	RESPONSABILIDAD	2026-01-03	1	6	2026	f
979	1089	RESPONSABILIDAD	2026-01-03	1	5	2026	f
980	1096	RESPONSABILIDAD	2025-12-30	1	599	2025	f
981	1097	RESPONSABILIDAD	2025-12-29	1	589	2025	f
982	1098	RESPONSABILIDAD	2026-01-08	1	12	2026	f
983	1099	RESPONSABILIDAD	2026-01-10	1	15	2026	f
984	1100	RESPONSABILIDAD	2026-01-08	1	13	2026	f
985	1102	RESPONSABILIDAD	2026-01-10	1	16	2026	f
986	1103	RESPONSABILIDAD	2026-01-08	1	11	2026	f
987	1104	RESPONSABILIDAD	2025-12-29	1	592	2025	f
988	1105	RESPONSABILIDAD	2026-01-14	1	20	2026	f
989	1106	RESPONSABILIDAD	2026-01-14	1	21	2026	f
990	1107	RESPONSABILIDAD	2026-01-14	1	25	2026	f
991	1108	RESPONSABILIDAD	2026-01-14	1	22	2026	f
992	1109	RESPONSABILIDAD	2026-01-14	1	23	2026	f
993	1110	RESPONSABILIDAD	2026-01-14	1	24	2026	f
\.


--
-- TOC entry 5127 (class 0 OID 16614)
-- Dependencies: 240
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
-- TOC entry 5117 (class 0 OID 16531)
-- Dependencies: 230
-- Data for Name: comentarios_admin; Type: TABLE DATA; Schema: public; Owner: vpn_user
--

COPY public.comentarios_admin (id, entidad, entidad_id, comentario, usuario_id, fecha) FROM stdin;
\.


--
-- TOC entry 5125 (class 0 OID 16596)
-- Dependencies: 238
-- Data for Name: configuracion_sistema; Type: TABLE DATA; Schema: public; Owner: vpn_user
--

COPY public.configuracion_sistema (id, clave, valor, descripcion, tipo_dato, fecha_modificacion, modificado_por) FROM stdin;
1	DIAS_ALERTA_VENCIMIENTO	30	DÃ­as antes del vencimiento para generar alerta	INTEGER	2025-12-29 12:07:33.730041	\N
2	DIAS_GRACIA_DEFAULT	15	DÃ­as de gracia por defecto	INTEGER	2025-12-29 12:07:33.730041	\N
3	VIGENCIA_MESES	12	Meses de vigencia de acceso VPN	INTEGER	2025-12-29 12:07:33.730041	\N
4	RUTA_ARCHIVOS	/var/vpn_archivos	Ruta base para almacenamiento de archivos	STRING	2025-12-29 12:07:33.730041	\N
\.


--
-- TOC entry 5123 (class 0 OID 16578)
-- Dependencies: 236
-- Data for Name: importaciones_excel; Type: TABLE DATA; Schema: public; Owner: vpn_user
--

COPY public.importaciones_excel (id, archivo_origen, fecha_importacion, usuario_id, registros_procesados, registros_exitosos, registros_fallidos, resultado, log_errores) FROM stdin;
\.


--
-- TOC entry 5105 (class 0 OID 16416)
-- Dependencies: 218
-- Data for Name: personas; Type: TABLE DATA; Schema: public; Owner: vpn_user
--

COPY public.personas (id, dpi, nombres, apellidos, institucion, cargo, telefono, email, observaciones, activo, fecha_creacion, nip) FROM stdin;
1	1813389630606	Abel Ovidio	Perez Garcia	SGAIA-PNC	Inspector	37587226	\N	\N	t	2026-02-03 19:59:33.209583	36250-P
2	2081442692217	Abiezer Azael	del Cid Aroche	Departamento de Investigación de Delitos - Delegación Santa Rosa - DEIC	Agente	30268220	\N	\N	t	2026-02-03 19:59:33.209583	42563-P
3	2596775311219	Abinai Jonathan	Barrios Miranda	Sección Contra la Trata de Personas -DEIC-	Agente	31415275	\N	\N	t	2026-02-03 19:59:33.209583	65379-P
5	2424881290101	Adriana Mishel Monzon	Valle de Matazin	SGAIA-PNC	Agente	30304983	\N	\N	t	2026-02-03 19:59:33.209583	61590-P
13	1644318961202	Alexander Manfredo	Velasquez Bravo	Departamento de Investigación de Delitos - Delegación Villa Nueva - DEIC	Agente	35688014	\N	\N	t	2026-02-03 19:59:33.209583	32939-P
16	1751024810101	Álvaro Antonio	Colindres Orozco	Jefatura Adjunta de Departamentos y Delegaciones Especiales de Investigación - DEIC -	Agente	59378415	\N	\N	t	2026-02-03 19:59:33.209583	28173-P
17	2461122632201	Alvaro Luis	Carrillo Barrera	Departamento de Investigación de Delitos - DEIC - División de Análisis Criminal	Agente	36144900	\N	\N	t	2026-02-03 19:59:33.209583	32039-P
18	1999385470407	Alvaro Upun	Aju	CAT - SGIC	Agente	31537325	\N	\N	t	2026-02-03 19:59:33.209583	38285-P
22	2855677131008	Ana Julia	López Hernández	División de Investigación y Desactivación de Armas y Expolivos - DIDAE	Agente	58593247	\N	\N	t	2026-02-03 19:59:33.209583	27352-P
23	2715893101902	Andrea Gabriela	Navas	Ministerio Público	MP	53806337	\N	\N	t	2026-02-03 19:59:33.209583	\N
26	2576376562207	Ángel Roberto	Vásquez Lemus	Departamento de Investigación de Delitos - Delegación Villa Nueva - DEIC	Agente	53533606	\N	\N	t	2026-02-03 19:59:33.209583	55649-P
27	2463009651327	Angélica Rodríguez	Rodríguez	DEIC - Huehuetenango	Agente	47482401	\N	\N	t	2026-02-03 19:59:33.209583	52800-P
28	3081926720607	Anhuner Gabriel	Cano García	Sección Contra la Trata de Personas -DEIC-	Agente	55322656	\N	\N	t	2026-02-03 19:59:33.209583	65449-P
29	2121183822101	Antonia Cruz	Sagui	Departamento de Investigación de Delitos - Delegación Jalapa - DEIC	Agente	54299231	\N	\N	t	2026-02-03 19:59:33.209583	54554-P
30	2298247491504	Antonio Florian	Fernandez Dubon	SGAIA-PNC	Agente	40070831	\N	\N	t	2026-02-03 19:59:33.209583	10615-P
32	2142692480609	Armando Daniel	Vasquez Archila	Departamento de Investigación de Delitos - Delegación Escuintla - DEIC	Agente	56232823	\N	\N	t	2026-02-03 19:59:33.209583	41950-P
33	2344417120603	Armenia de	Jesus Morales Castellanos	CAT - SGIC	Agente	47934216	\N	\N	t	2026-02-03 19:59:33.209583	46086-P
34	2844306760205	Arnoldo José	Alvarado Flores	Departamento de Investigación de Delitos - Delegación El Progreso - DEIC	Agente	37084448	\N	\N	t	2026-02-03 19:59:33.209583	65286-P
35	1741468410806	Augusto Francisco	Carrillo Lux	División Nacional Contra el Desarrollo Criminal de las Pandillas - DIPANDA - Escuintla	Agente	30365149	\N	\N	t	2026-02-03 19:59:33.209583	63232-P
36	1768487460111	Axel David	Benito Benito	Departamento de Investigación de Delitos - Delegación Escuintla - DEIC	Agente	56273178	\N	\N	t	2026-02-03 19:59:33.209583	28318-P
37	1996126412216	Axel Omar	Garcia Jimenez	Secretaría Técnica - SGIC	Agente	34037899	\N	\N	t	2026-02-03 19:59:33.209583	39169-P
39	1924859461204	Baudilio Mijail	Coronado y Coronado	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	41551514	\N	\N	t	2026-02-03 19:59:33.209583	37010-P
20	1677539671503	AMILCAR ISMALEJ	VALEY	UEI	Agente	47434115	\N	\N	t	2026-02-03 19:59:33.209583	28704-P
40	1958094320601	Bayron Guiancarlo	Castañeda Mendez	DEIC - Chiquimulilla	Agente	35754224	\N	\N	t	2026-02-03 19:59:33.209583	36889-P
41	3282738561101	Belbeth Roxana de	la Cruz Pu	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación de Delitos Financieros y Económicos	Agente	53015166	\N	\N	t	2026-02-03 19:59:33.209583	60990-P
42	2916624391206	Belizario Angelino	Macario Hernández	Centro Antipandillas Transnacional - CAT - DIPANDA - SGIC	Agente	58717953	\N	\N	t	2026-02-03 19:59:33.209583	57645-P
47	1944458011502	Braulio Fernando	Canahui Canahui	Secretaría Técnica - SGIC	Agente	33883371	\N	\N	t	2026-02-03 19:59:33.209583	38841-P
48	2246654860410	Bráyan Urías	Tocal Ruyán	ORP - Inspectoría General	Agente	44351800	\N	\N	t	2026-02-03 19:59:33.209583	41911-P
49	2201914921502	Briseida Quetzaly Vásquez	Ixmalej de Chuy	Divisicón de Investigación y Desactivación de Armas y Expolivos - DIDAE	Agente	54175043	\N	\N	t	2026-02-03 19:59:33.209583	58468-P
50	1812226121901	Briseyda Nataly	Rodriguez Perez	DEIC - Huehuetenango	Agente	42159925	\N	\N	t	2026-02-03 19:59:33.209583	39865-P
51	3308200361203	Bryan Cristofer	Cabrera Cardona	División Nacional Contra el Desarrollo Criminal de las Pandillas - DIPANDA - Escuintla	Agente	48648185	\N	\N	t	2026-02-03 19:59:33.209583	63210-P
56	1742983230101	Carlos David	Ixcot Lopez	División de Protección de Personas y Seguridad - DPPS	Subcomisario	40306120	\N	\N	t	2026-02-03 19:59:33.209583	27323-P
59	1584426600404	Carlos Humberto	López Patzán	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación de Delitos Financieros y Económicos	Agente	55274959	\N	\N	t	2026-02-03 19:59:33.209583	41347-P
60	1659842792213	Carlos Humberto	Martinez Santos	División Especializada de Investigación Huehuetenango - DEIC - SGIC	Agente	54289641	\N	\N	t	2026-02-03 19:59:33.209583	32498-P
61	9999888160552	Carlos Lem	Cal	\N	\N	\N	\N	\N	t	2026-02-03 19:59:33.209583	\N
62	1938007801603	Carlos Lem	Cal	DEIC-ALTA VERAPAZ	Agente	40010496	\N	\N	t	2026-02-03 19:59:33.209583	39380-P
63	1832363000920	Carlos Ovidio	Zabala Vásquez	Divisicón de Investigación y Desactivación de Armas y Expolivos - DIDAE	Agente	59536813	\N	\N	t	2026-02-03 19:59:33.209583	40145-P
64	2701741842215	Carlos Roberto	Beron Herrera	Centro Antipandillas Transnacional - CAT - DIPANDA - SGIC	Agente	36368249	\N	\N	t	2026-02-03 19:59:33.209583	56698-P
66	2079569441410	Catarina Magdalena	Lux Gonzalez	\N	\N	47214583	\N	\N	t	2026-02-03 19:59:33.209583	\N
67	2338665662201	Cesar Augusto	Peñate Argueta	Despacho Dirección General	Oficial Tercero	32170226	\N	\N	t	2026-02-03 19:59:33.209583	16924-P
68	1722909450508	Cesar Augusto	Teyes Gaitan	Departamento de Investigación de Delitos - Delegación Chimaltenango - DEIC	Subinspector	30460961	\N	\N	t	2026-02-03 19:59:33.209583	31030-P
69	1850959251610	Cesar Eduardo	Ponce Si	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	53186213	\N	\N	t	2026-02-03 19:59:33.209583	22252-P
73	2315715340513	Claudia Patricia	Garcia Mulul	Departamento de Investigación de Delitos - Delegación Pinula - DEIC	Agente	37552534	\N	\N	t	2026-02-03 19:59:33.209583	52691-P
76	2166574312201	Cynthia Gabriela	Carrillo y Carrillo	Sección Contra la Trata de Personas -DEIC-	Agente	35652092	\N	\N	t	2026-02-03 19:59:33.209583	38876-P
77	3151374011501	Cynthia Marisol	Doradea López	Jefatura Adjunta de Departamentos y Delegaciones Especiales de Investigación - DEIC -	Agente	40783450	\N	\N	t	2026-02-03 19:59:33.209583	64154-P
78	2749806810203	Dalia Fernanda	Montecinos Cruz	División de Protección de Personas y Seguridad - DPPS	Agente	33040868	\N	\N	t	2026-02-03 19:59:33.209583	61581-P
80	1835382771502	Daniel Pérez	González	Departamento de Investigación de Delitos - Delegación Baja Verapaz - DEIC	Agente	49157313	\N	\N	t	2026-02-03 19:59:33.209583	41595-P
81	1956483231001	Dany Josue	Carrillo Alonzo	Departamento de Investigación de Delitos Patrimoniales - DEIC - SGIC -	Agente	41201911	\N	\N	t	2026-02-03 19:59:33.209583	49678-P
82	2977819871018	David Iván	Gonón Alvarado	Interpol-DEIC-SGIC	Agente	42414486	\N	\N	t	2026-02-03 19:59:33.209583	64339-P
83	1860613742216	Dawuin Misael	Cabrera Castillo	SGAIA-PNC	Oficial Primero	30358968	\N	\N	t	2026-02-03 19:59:33.209583	35480-P
84	2280140501202	Degli America	Miranda Escobar	Departamento de Investigación de Delitos - Delegación Quetzaltenango - DEIC	Agente	39941081	\N	\N	t	2026-02-03 19:59:33.209583	31562-P
85	2201865531105	Delvin Estuardo	Rojas	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación de Delitos Financieros y Económicos	Agente	32901754	\N	\N	t	2026-02-03 19:59:33.209583	41110-P
92	2145826120301	Dilcia Marta	Liliana Sosa Monroy	CAT - SGIC	Agente	41592944	\N	\N	t	2026-02-03 19:59:33.209583	50778-P
93	9999255416904	Dina Rubi	Salvdor Herrera	S/N	S/N	\N	\N	\N	t	2026-02-03 19:59:33.209583	\N
95	2930602581204	Eberto Efrain	Ramirez y Ramirez	DEIC - Huehuetenango	Agente	47864883	\N	\N	t	2026-02-03 19:59:33.209583	66535-P
96	2151245290206	Edgar Amilcar	Jimenez Rodas	Interpol-DEIC-SGIC	Agente	55536636	\N	\N	t	2026-02-03 19:59:33.209583	66009-P
97	3251510081010	Edgar Daniel	Suhul Palacios	División Nacional Contra el Desarrollo Criminal de las Pandillas - DIPANDA - Escuintla	Agente	54434493	\N	\N	t	2026-02-03 19:59:33.209583	66703-P
98	2587973041609	Edgar Gabriel	Choc Sierra	Interpol-DEIC-SGIC	Agente	54686234	\N	\N	t	2026-02-03 19:59:33.209583	64020-P
99	0227263041615	Edgar Jose	Alexander Xol Mez	Departamento de Investigación de Delitos - DEIC - División de Análisis Criminal	Agente	54750653	\N	\N	t	2026-02-03 19:59:33.209583	42006-P
100	1844692600508	Edgar Randolfo	Cadenas Marroquin	SGAIA - SIA Departamento de Investigación	Agente	38195946	\N	\N	t	2026-02-03 19:59:33.209583	29399-P
101	2069780731008	Edgar Reynaldo	Mejia Quich	Departamento de Investigación de Delitos - Delegación Coatepeque - DEIC	Agente	47707002	\N	\N	t	2026-02-03 19:59:33.209583	43147-P
104	3411236331416	Edgar Sebastian	Izaguirre Felipe	Centro Antipandillas Transnacional - CAT - DIPANDA - SGIC	Agente	41672926	\N	\N	t	2026-02-03 19:59:33.209583	59227-P
105	2247341721017	Edvin Leonel	Felipe Ajqui	Departamento de Investigación de Delitos - Delegación Escuintla - DEIC	Agente	42861043	\N	\N	t	2026-02-03 19:59:33.209583	49919-P
106	2789175421501	Edvin Noe	Canahui Rodriguez	Subdirecion General Antinarcotica SGAIA	Agente	33788422	\N	\N	t	2026-02-03 19:59:33.209583	58769-P
107	2743885881008	Edwin Collin	Raymundo	Division Especializada en Investigacion, Criminal. DEIC	Oficial Primero	37561082	\N	\N	t	2026-02-03 19:59:33.209583	24074-P
108	2429549870611	Edwin Isai	Gómez Ramírez	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación Contra el Delito de Femicidio	Agente	31051302	\N	\N	t	2026-02-03 19:59:33.209583	41068-P
109	3164003511503	Edwin Jerdany	Alvarado González	Unidad Especial de Investigación - UEI - SGIC	Agente	39060492	\N	\N	t	2026-02-03 19:59:33.209583	56576-P
110	1860614392216	Edwin Osbely	Jimenez Garcia	SGAIA-DFIAAT	Agente	37560583	\N	\N	t	2026-02-03 19:59:33.209583	27324-P
111	2173842931503	Edwin Oswaldo	Tecu	Division especializada en invetigacion criminal-DEIC-SGIC	Agente	54183943	\N	\N	t	2026-02-03 19:59:33.209583	40001-P
112	1774428240404	Edwin Wilfredo	Velasquez Corona	División de Protección de Personas y Seguridad - DPPS	Oficial Segundo	57841604	\N	\N	t	2026-02-03 19:59:33.209583	31078-P
114	2858613011606	Edy Estuardo	Beb Ticoy	Jefatura Adjunta de Departamentos y Delegaciones Especiales de Investigación - DEIC -	Agente	37941041	\N	\N	t	2026-02-03 19:59:33.209583	67135-P
115	1942662731003	Edy Facundo	Godinez Gomez	Sección Contra la Trata de Personas -DEIC-	Oficial Tercero	32602222	\N	\N	t	2026-02-03 19:59:33.209583	26480-P
118	1638554201803	Elder Obdulio	Gonzales Pec	Departamento de Investigación de Delitos - Delegación Baja Verapaz - DEIC	Agente	53402226	\N	\N	t	2026-02-03 19:59:33.209583	46382-P
119	2362329831202	Elder Ottoniel	Barrios Fuentes	DEIC - San Marcos	Inspector	59670075	\N	\N	t	2026-02-03 19:59:33.209583	20353-P
120	2576383340607	Elias Interiano	Zepeda	SGAIA - Departamento de Investigación, Sección en seguimiento al narcomenudeo	Agente	\N	\N	\N	t	2026-02-03 19:59:33.209583	50129-P
122	1663007052211	Elver Ramirez	y Ramirez	Departamento de Investigación de Delitos Patrimoniales - DEIC - SGIC -	Agente	42058086	\N	\N	t	2026-02-03 19:59:33.209583	34774-P
123	1767290031108	Elvidia Marleny	Reyes Rodas	Departamento de Investigación de Delitos - Delegación Villa Nueva - DEIC	Agente	54405066	\N	\N	t	2026-02-03 19:59:33.209583	34826-P
125	3085069951208	Emilcer Raymundo	Berduo Arreaga	Departamento de Investigación de Delitos - Delegación Escuintla - DEIC	Agente	37716043	\N	\N	t	2026-02-03 19:59:33.209583	67142-P
127	1649132382210	Erardo Ramirez	Rivera	CAT - SGIC	Agente	37603802	\N	\N	t	2026-02-03 19:59:33.209583	34763-P
128	1590964130501	Erick Andres	Lopez Rosales	Departamento de Investigación de Delitos - DEIC - División de Análisis Criminal	Agente	38065386	\N	\N	t	2026-02-03 19:59:33.209583	27827-P
144	2754637612212	Faibel Ovil	Pineda y Pineda	Divisicón de Investigación y Desactivación de Armas y Expolivos - DIDAE	Agente	48297540	\N	\N	t	2026-02-03 19:59:33.209583	66463-P
129	1834958880404	Erick Estuardo	Curuchich Icú	Departamento de Investigación de Delitos - Delegación Quiche - DEIC	Oficial Tercero	39809956	\N	\N	t	2026-02-03 19:59:33.209583	57050-P
131	1909985042204	Erik Marcial	Sánchez Lemus	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Subinspector	58243820	\N	\N	t	2026-02-03 19:59:33.209583	38142-P
133	2135790221609	Erver Yovani	Caal Morales	DGA SUBDIRECCION GENERAL DE INVESTIGACION CRIMINAL (SGIC)	Agente	57860389	\N	\N	t	2026-02-03 19:59:33.209583	65413-P
134	1610016531604	Erwin Dario	Isém Isém	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	40280573	\N	\N	t	2026-02-03 19:59:33.209583	37397-P
136	2313889772217	Esdras Eliel	Salazar Aroche	Departamento de Investigación de Delitos - Delegación Villa Nueva - DEIC	Oficial Tercero	38418765	\N	\N	t	2026-02-03 19:59:33.209583	49254-P
137	2681996980501	Esdras Job	Chic Ordoñez	Division Especializada en Investigacion, Criminal. DEIC Suchitepequez	Oficial Primero	30327421	\N	\N	t	2026-02-03 19:59:33.209583	21570-P
45	1634655251703	Bilda Yasmin	Esteban Hoil	DEIC - Peten	Inspector	40224938	\N	\N	t	2026-02-03 19:59:33.209583	39099-P
141	3424424652201	Evelin Yulisa	Zepeda Barrientos	Jefatura Adjunta de Departamentos y Delegaciones Especiales de Investigación - DEIC -	Agente	46918211	\N	\N	t	2026-02-03 19:59:33.209583	66836-P
145	1768205070613	Felipe Genaro	Rodriguez Alvarado	DEIC - Huehuetenango	Agente	49797772	\N	\N	t	2026-02-03 19:59:33.209583	39852-P
146	1692862230101	Félix Eduardo	Tepáz Ruiz	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	32046548	\N	\N	t	2026-02-03 19:59:33.209583	40011-P
152	9999777544112	Frandi Veronica	Cifuentes Moran	Departamento de Investigación de Delitos Patrimoniales - DEIC - SGIC -	Agente	58225501	\N	\N	t	2026-02-03 19:59:33.209583	\N
155	3248469751007	Fredy Aron	Ayala Xicay	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación Contra el Delito de Femicidio	Agente	57357578	\N	\N	t	2026-02-03 19:59:33.209583	65350-P
157	2290709222201	Gabriel Manuel	Virula Mayén	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	47730702	\N	\N	t	2026-02-03 19:59:33.209583	41991-P
159	2127705780610	Geizon Sebastian	Lemus Granados	Departamento de Investigación de Delitos - Delegación Villa Nueva - DEIC	Agente	54409716	\N	\N	t	2026-02-03 19:59:33.209583	41267-P
161	3313588321204	Geovany Maguiver	Ramirez Jiguan	DEIC - Huehuetenango	Agente	57410737	\N	\N	t	2026-02-03 19:59:33.209583	66512-P
163	2281575601501	Gerson Doroteo	Adqui Garcia	DEIC - Salama	Agente	58097061	\N	\N	t	2026-02-03 19:59:33.209583	46540-P
164	2823164931501	Gerson Elias	Rodriguez Lopez	Diprona Salama	Agente	37076123	\N	\N	t	2026-02-03 19:59:33.209583	61951-P
165	3416558642105	Gerson Wilfredo	Hernández Nájera	Divisicón de Investigación y Desactivación de Armas y Expolivos - DIDAE	Agente	40101970	\N	\N	t	2026-02-03 19:59:33.209583	64406-P
166	2100401142201	Girian Rosibel	Diaz Cruz	Departamento de Investigación de Delitos - Delegación Santa Rosa - DEIC	Agente	36425471	\N	\N	t	2026-02-03 19:59:33.209583	40867-P
168	2524347492201	Glenda Jeaneth	Vasquez Ordoñez	División de Policía Internacional	Oficial Tercero	30477133	\N	\N	t	2026-02-03 19:59:33.209583	55130-P
170	2182882200301	Graciela Carolina	Romero Guachin	Departamento de Investigación de Delitos - Delegación Sacatepéquez - DEIC	Agente	43089802	\N	\N	t	2026-02-03 19:59:33.209583	14960-P
171	1737205281002	Guillermo Adalberto	Barrera Pérez	CAT - SGIC	Subinspector	31532422	\N	\N	t	2026-02-03 19:59:33.209583	29367-P
177	2183241030611	Hector David	Ramirez Hernandez	Departamento de Investigación de Delitos Patrimoniales - DEIC - SGIC -	Agente	36316379	\N	\N	t	2026-02-03 19:59:33.209583	43487-P
178	2485089382004	Hector Elixalen	Escalante Centé	Departamento de Investigación de Delitos - DEIC - División de Análisis Criminal	Agente	54822196	\N	\N	t	2026-02-03 19:59:33.209583	25792-P
179	1866924392107	Hector Felipe	Dominguez Donis	SGAIA - Departamento de Investigaciones	Agente	37586747	\N	\N	t	2026-02-03 19:59:33.209583	26938-P
183	2363253882216	Hener Hercilio	Garcia Castillo	Departamento de Investigación de Delitos - DEIC - División de Análisis Criminal	Agente	55447147	\N	\N	t	2026-02-03 19:59:33.209583	33779-P
181	2270041591109	Héctor Roel	Sánchez Juárez	DEPARTAMENTO DE OPERACIONES-DEIC-SGIC	Agente	33346871	\N	\N	t	2026-02-03 19:59:33.209583	63634-P
184	1597007520404	Henry Alexander	Gonzalez Chacach	Jefatura de Planificación Estratégica y Desarrollo Institucional - JEPEDI	Oficial Tercero	57028868	\N	\N	t	2026-02-03 19:59:33.209583	35814-P
188	2093553441202	Herbert Santiago	Xiloj Garcia	Dipanda - SGIC	Agente	58468280	\N	\N	t	2026-02-03 19:59:33.209583	41997-P
190	1874866700101	Herrman Ezequiel	Herrarte Morales	Unidad Especial de Investigación - UEI - SGIC	Oficial Tercero	48405039	\N	\N	t	2026-02-03 19:59:33.209583	31455-P
191	1666489142212	Hersón Mindael	García Sarceño	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	51635959	\N	\N	t	2026-02-03 19:59:33.209583	32273-P
192	2370362310404	Herver Isaias	Xocop Cux	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación de Delitos Financieros y Económicos	Inspector	30352924	\N	\N	t	2026-02-03 19:59:33.209583	15143-P
195	2172415491211	Hilton Dimas	Hernández Fuentes	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	59891756	\N	\N	t	2026-02-03 19:59:33.209583	57388-P
196	2194642000101	Hugo Leonel	Franco Gutierrez	División de Policía Internacional	Agente	42639322	\N	\N	t	2026-02-03 19:59:33.209583	42646-P
197	1626390900801	Ing. Saturnino	Pablo Toyóm Mazariegos	Fiscalía Contra la Trata de Personas, Sistema de Protección Infantil en Línez	Analista de Sistemas II SPI	55688848	\N	\N	t	2026-02-03 19:59:33.209583	20120-P
198	2334346232201	Ingrid Julissa	Valdéz Zuñiga	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	30080998	\N	\N	t	2026-02-03 19:59:33.209583	52829-P
199	2325613382210	Inmer Geovany	Quiñonez Perez	Departamento de Investigación de Delitos - Delegación Jalapa - DEIC	Agente	46027198	\N	\N	t	2026-02-03 19:59:33.209583	59639-P
202	1661223270601	Irma Yolanda	Ramirez Ramirez	SGAIA-PNC	Agente	30313378	\N	\N	t	2026-02-03 19:59:33.209583	22898-P
206	2085334860614	Jackeline Anahí	Urias Icute	Departamento de Investigación de Delitos - Delegación Santa Rosa - DEIC	Agente	56311180	\N	\N	t	2026-02-03 19:59:33.209583	46685-P
208	2286071160608	Jaime Geovany	Gomez Lucha	Departamento de Investigación de Delitos - Delegación Escuintla - DEIC	Agente	56936607	\N	\N	t	2026-02-03 19:59:33.209583	42768-P
211	2528632160101	Jairo Estuardo	Tejada Herrera	CAT - SGIC	Agente	47934212	\N	\N	t	2026-02-03 19:59:33.209583	40004-P
212	2501197651101	Jairo René	de León Ardón	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	42025434	\N	\N	t	2026-02-03 19:59:33.209583	65674-P
222	3081892130607	Jessica Yumila	Cano Vazquez	Jefatura Adjunta de Departamentos y Delegaciones Especiales de Investigación - DEIC -	Agente	46017927	\N	\N	t	2026-02-03 19:59:33.209583	67236-P
213	1687536340201	Jairo Rodolfo	Lima Coronado	DEIC - Peten	Agente	38389017	\N	\N	t	2026-02-03 19:59:33.209583	27315-P
215	2920131321616	Jaqueline Yadira	Yamileth Welman Morales	Sección Contra la Trata de Personas -DEIC-	Agente	50589206	\N	\N	t	2026-02-03 19:59:33.209583	66798-P
216	1838683800101	Jarinson Humberto	Rodriguez Capul	Departamento de Investigaciones SGAIA	Agente	35690435	\N	\N	t	2026-02-03 19:59:33.209583	34851-P
217	1917499821910	Jefrey Estuardo	Mateo Sagüil	DIP-SGIC	Agente	41996204	\N	\N	t	2026-02-03 19:59:33.209583	34304-P
218	3422742012201	Jefri Omar	Ruano Lima	Interpol-DEIC-SGIC	Agente	58755369	\N	\N	t	2026-02-03 19:59:33.209583	68998-P
224	3164771681503	Jhonatan Misael	Cuxúm Corazón	Jefatura Adjunta de Departamentos y Delegaciones Especiales de Investigación - DEIC -	Agente	51719463	\N	\N	t	2026-02-03 19:59:33.209583	70098-P
225	2777309101301	Jhony Alfredo	Gomez Rodriguez	SGIC DEIC-HUEHUETENANGO	Agente	30339648	\N	\N	t	2026-02-03 19:59:33.209583	53842-P
228	1649395122216	Jomar Deyni	Ruano Alvarez	Departamento de Investigación de Delitos - Delegación Jalapa - DEIC	Agente	32340763	\N	\N	t	2026-02-03 19:59:33.209583	32789-P
230	3307905281202	Jonifer Anselmo	Lopez Miranda	DEIC - Huehuetenango	Agente	32811043	\N	\N	t	2026-02-03 19:59:33.209583	64554-P
231	2765769182205	Jordi Armando	Di Paolantonio Navas	Divisicón de Investigación y Desactivación de Armas y Expolivos - DIDAE	Agente	32992284	\N	\N	t	2026-02-03 19:59:33.209583	64140-P
233	1581738801001	Jorge Amilcar	Ramos de Leon	DEIC - Huehuetenango	Agente	37673816	\N	\N	t	2026-02-03 19:59:33.209583	43520-P
234	2292191010101	Jorge Ernesto	Salazar Castro	Divisicón de Investigación y Desactivación de Armas y Expolivos - DIDAE	Agente	41367704	\N	\N	t	2026-02-03 19:59:33.209583	36425-P
236	1847311351610	Jorge Laurindo	Ic Tut	Unidad Especial de Investigación - UEI - SGIC	Agente	30674184	\N	\N	t	2026-02-03 19:59:33.209583	32371-P
237	2369245402106	Jorge Luis	López Jiménez	CAT - SGIC	Agente	31535748	\N	\N	t	2026-02-03 19:59:33.209583	45230-P
238	2940585750101	Jorge Luis	Trigueros Oliva	Divisicón de Investigación y Desactivación de Armas y Expolivos - DIDAE	Agente	30533818	\N	\N	t	2026-02-03 19:59:33.209583	69221-P
239	1960130891105	José Adolfo	Vásquez Juárez	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación Contra el Delito de Femicidio	Agente	55683015	\N	\N	t	2026-02-03 19:59:33.209583	36552-P
241	3166940021503	José Armando	Alvarez Manzo	División Nacional Contra el Desarrollo Criminal de las Pandillas - DIPANDA - Escuintla	Agente	48381596	\N	\N	t	2026-02-03 19:59:33.209583	58657-P
243	2880721702101	Jose Carlos	Zapata Arteaga	Interpol-DEIC-SGIC	Agente	59660652	\N	\N	t	2026-02-03 19:59:33.209583	69403-P
244	1776471750513	José Daniel	del Cid Quiñonez	Departamento de Investigación de Delitos - Delegación Villa Nueva - DEIC	Agente	45336550	\N	\N	t	2026-02-03 19:59:33.209583	25778-P
245	2169768041102	Jose Emanuel	Sanchez Solis	Departamento de Investigación de Delitos - Delegación Escuintla - DEIC	Agente	35860005	\N	\N	t	2026-02-03 19:59:33.209583	52475-P
246	3411816331416	José Enrique	Matías Lancerio	Departamento de Investigación de Delitos - Delegación Sacatepéquez - DEIC	Agente	53782418	\N	\N	t	2026-02-03 19:59:33.209583	60236-P
247	2130579131416	José Esteban	Ajiataz Chamorro	Unidad Especial de Investigación - UEI - SGIC	Agente	31286302	\N	\N	t	2026-02-03 19:59:33.209583	40454-P
248	2085295271503	Jose Fernando	Alvarado Toj	DEIC - El Progreso	Agente	36917318	\N	\N	t	2026-02-03 19:59:33.209583	46781-P
255	1972546911001	Josselyne Carolina	Cerin Pineda	Departamento de Investigación de Delitos - Delegación Quiche - DEIC	Agente	55932299	\N	\N	t	2026-02-03 19:59:33.209583	32057-P
249	1997655610412	Jose Humberto	Alvarado Matzir	CAT - SGIC	Agente	31531238	\N	\N	t	2026-02-03 19:59:33.209583	42209-P
250	1915862931501	José Macario	Cornel Santos	Departamento de Investigación de Delitos - DEIC - SGIC -	Comisario	55514478	\N	\N	t	2026-02-03 19:59:33.209583	15309-P
256	2564323410108	Josue David	Fuentes Boror	DEIC - Huehuetenango	Agente	43451449	\N	\N	t	2026-02-03 19:59:33.209583	49939-P
254	3248219561007	Jose Roberto	Chavez Tupul	Departamento de Investigación de Delitos - Delegación Escuintla - DEIC	Agente	58563239	\N	\N	t	2026-02-03 19:59:33.209583	60844-P
260	1782108030606	Juan Carlos	García Alfaro	Sección Contra la Trata de Personas -DEIC-	Agente	32698134	\N	\N	t	2026-02-03 19:59:33.209583	33767-P
261	1957518840713	Juan Estuardo	Tereta Campa	CAT - SGIC	Agente	54446023	\N	\N	t	2026-02-03 19:59:33.209583	26631-P
262	2873628170707	Juan Estuardo	To y To	Departamento de Investigación de Delitos - Delegación Escuintla - DEIC	Agente	41427784	\N	\N	t	2026-02-03 19:59:33.209583	56446-P
263	3429274342209	Juan Francisco	Godoy Albeño	SGAIA - Departamento de Investigaciones	Agente	47815216	\N	\N	t	2026-02-03 19:59:33.209583	62583-P
264	1606312382001	Juan Francisco	Larios Curcin	DEIC - El Progreso	Subinspector	30146461	\N	\N	t	2026-02-03 19:59:33.209583	34082-P
265	1996729031008	Juan Jose	Cacoj Ortis	Divisicón de Investigación y Desactivación de Armas y Expolivos - DIDAE	Oficial Tercero	30355078	\N	\N	t	2026-02-03 19:59:33.209583	19558-P
266	2602821621101	Juan José	Díaz Vásquez	Unidad Especial de Investigación - UEI - SGIC	Subcomisario	30364623	\N	\N	t	2026-02-03 19:59:33.209583	15358-P
268	1947350791306	Juana Raquel	Morales Morales	DEIC - Huehuetenango	Agente	30102803	\N	\N	t	2026-02-03 19:59:33.209583	39592-P
269	1731064551503	Julia Margarita	Juarez Alvarado	División de Policía Internacional	Agente	56951440	\N	\N	t	2026-02-03 19:59:33.209583	46853-P
271	1751317242214	Julio Cesar	Avila Samayoa	DIP-SGIC	Agente	30448350	\N	\N	t	2026-02-03 19:59:33.209583	35423-P
275	2557537050114	Karen Mishel	Arenas Solares	SGAIA-PNC	Agente	40072328	\N	\N	t	2026-02-03 19:59:33.209583	33190-P
276	2607197732214	Karla Marilú	Ceballos González	DEIC - Peten	Agente	46164462	\N	\N	t	2026-02-03 19:59:33.209583	21548-P
277	3102673820614	Karla Nineth	Paredes López	Unidad Especial de Investigación - UEI - SGIC	Agente	40282664	\N	\N	t	2026-02-03 19:59:33.209583	37937-P
278	2607823432207	Kelvin Misael	Herrera Lorenzana	Unidad Especial de Investigación - UEI - SGIC	Agente	40282016	\N	\N	t	2026-02-03 19:59:33.209583	22758-P
279	2809252711605	Kely Daniela	Guadalupe Tipol Cucul	Interpol-DEIC-SGIC	Agente	58775433	\N	\N	t	2026-02-03 19:59:33.209583	66714-P
280	2916265482206	Kendy Maloy	Godoy Cortez	Sección registro y control de Ordenes de Aprehensión - DEIC -SGIC	Agente	40323670	\N	\N	t	2026-02-03 19:59:33.209583	67826-P
282	3207070160501	Kevin Daniel	Revolorio Rivas	Departamento de Investigación de Delitos - DEIC - División de Análisis Criminal	Agente	42843043	\N	\N	t	2026-02-03 19:59:33.209583	68915-P
283	3112142821215	Kevin Eduardo	Perez Agueda	Departamento de Investigación de Delitos - DEIC - División de Análisis Criminal	Agente	37779985	\N	\N	t	2026-02-03 19:59:33.209583	59565-P
284	2822425701505	Kevin Eduardo	Reyes Garcia	Departamento de Investigación de Delitos Patrimoniales - DEIC - SGIC -	Agente	57276432	\N	\N	t	2026-02-03 19:59:33.209583	58160-P
285	3255711121013	Kevin Geovany	Urrutia Tzorin	Departamento de Investigación de Delitos - Delegación Escuintla - DEIC	Agente	32866250	\N	\N	t	2026-02-03 19:59:33.209583	66751-P
286	2115115441416	Kevin Gilberto	Azañon Garcia	DEIC - Huehuetenango	Agente	54184445	\N	\N	t	2026-02-03 19:59:33.209583	43944-P
287	3053633280205	Keyla Nayeli	Cáceres López	Departamento de Investigación Contra la Delincuencia Organizada, DEIC-SGIC	Agente	36020996	\N	\N	t	2026-02-03 19:59:33.209583	65422-P
288	2789472711202	Kleyder Alexander	Godinez Velasquez	Departamento de Investigación de Delitos Contra la Propiedad de Vehículos Automotores Terrestres - DEIC	Agente	32511977	\N	\N	t	2026-02-03 19:59:33.209583	54645-P
292	2540991810101	Lic. Aristeo	Sánchez Gutiérrez	Fiscalía Contra la Trata de Personas, Sistema de Protección Infantil en Línez	Coordinador de Sistemas y Comunicaciones	37565941	\N	\N	t	2026-02-03 19:59:33.209583	20060-P
293	2124348291202	Lirica Lesdy	García Miranda	Departamento de Investigación de Delitos - DEIC - SGIC -	Agente	38194424	\N	\N	t	2026-02-03 19:59:33.209583	57228-P
297	1871425561003	Luis Alberto	González Lopez	Departamento de Investigación de Delitos - Delegación Suchitepéquez - DEIC	Agente	36258974	\N	\N	t	2026-02-03 19:59:33.209583	33900-P
299	2108368301102	Luis Antonio	Chay Macario	Departamento de Investigación de Delitos - Delegación Suchitepéquez - DEIC	Agente	42284368	\N	\N	t	2026-02-03 19:59:33.209583	38926-P
300	1976437441605	Luis Arnulfo	Chá Sis	División Nacional Contra el Desarrollo Criminal de las Pandillas - DIPANDA - Escuintla	Agente	53595222	\N	\N	t	2026-02-03 19:59:33.209583	46952-P
301	2102388441213	Luis Arnulfo	Pérez López	Departamento de Investigación de Delitos - Delegación Villa Nueva - DEIC	Agente	54451679	\N	\N	t	2026-02-03 19:59:33.209583	56341-P
303	2091695590101	Luis Daniel	Sierra Urizar	Jefatura Adjunta de Departamentos y Delegaciones Especiales de Investigación - DEIC -	Agente	49291638	\N	\N	t	2026-02-03 19:59:33.209583	52493-P
304	2621407130101	Luis Enrique	Domingo López	DEIC - Huehuetenango	Agente	51126619	\N	\N	t	2026-02-03 19:59:33.209583	54584-P
306	1905825961901	Luis Estuardo Pacheco	de la Cruz	SGIC - DEIC - Unidad Especial de Investigación	Agente	50535387	\N	\N	t	2026-02-03 19:59:33.209583	37814-P
308	3387481721001	Luis Francisco	Velasco Reyes	Interpol-DEIC-SGIC	Agente	41603480	\N	\N	t	2026-02-03 19:59:33.209583	69317-P
309	2344894720805	Luis Mardoqueo	Elias Calel	SGIC DEIC-HUEHUETENANGO	Agente	59750023	\N	\N	t	2026-02-03 19:59:33.209583	67589-P
313	2596913211213	Manuel Estuardo	Ochoa	Departamento de Investigación de Delitos - Delegación Totonicapán - DEIC	Agente	30256821	\N	\N	t	2026-02-03 19:59:33.209583	23504-P
317	2438678401009	Maria Cristina	Chial Ortiz	Division Especializada en Investigacion, Criminal. DEIC Suchitepequez	Agente	54922818	\N	\N	t	2026-02-03 19:59:33.209583	49734-P
318	1847400960501	Maria De Los	Angeles Cac Semet	Division Especializada en Investigacion, Criminal. DEIC Suchitepequez	Agente	42200762	\N	\N	t	2026-02-03 19:59:33.209583	17383-P
321	2547112781002	Maria Teresa	Garcia Bautista	Dipanda - SGIC	Oficial Primero	37556790	\N	\N	t	2026-02-03 19:59:33.209583	28564-P
323	3080013700606	Mariela Esperanza	Blanco Anavisca	Sección Contra la Trata de Personas -DEIC-	Agente	51300908	\N	\N	t	2026-02-03 19:59:33.209583	65392-P
326	2734358922216	Marlon Alexis	Pineda Velasquez	Interpol-DEIC-SGIC	Agente	58880964	\N	\N	t	2026-02-03 19:59:33.209583	68781-P
327	2902673901216	Marlon Ali Barrios	De Los Reyes	DEPARTAMENTO DE OPERACIONES-DEIC-SGIC	Agente	55769762	\N	\N	t	2026-02-03 19:59:33.209583	63836-P
328	1680109761503	Marlon Estuardo	Ismalej Cuja	Departamento de Administración de Compensaciones, Incentivos y Remuneraciones - DACIR-SGP	Oficial Segundo	40180627	\N	\N	t	2026-02-03 19:59:33.209583	30499-P
329	1997614691011	Marlon Gilberto	Herrera de Leon	Departamento de Investigación de Delitos - DEIC - División de Análisis Criminal	Agente	37918993	\N	\N	t	2026-02-03 19:59:33.209583	30482-P
331	2130483100101	Marta Lucia	Cruz	Ministerio Público	MP	53806337	\N	\N	t	2026-02-03 19:59:33.209583	\N
333	1724141801008	Marvyn Geovany	Chuc Alvarado	SGIC DIVISION DE INVESTIGACION Y DESACTIVACION DE ARMAS Y EXPLOSIVOS (DIDAE)	Agente	41131114	\N	\N	t	2026-02-03 19:59:33.209583	30165-P
334	2066269081109	Maynor Joel	Juárez Hernández	División Nacional Contra el Desarrollo Criminal de las Pandillas - DIPANDA - Escuintla	Agente	41369905	\N	\N	t	2026-02-03 19:59:33.209583	47093-P
339	2277379460101	Melvin Guillermo	Vasquez Carrillo	División de Investigación y Desactivación de Armas y Explosivos - DIDAE -	Agente	57825161	\N	\N	t	2026-02-03 19:59:33.209583	43810-P
343	2072003191402	Micaela Cuin	Suy	Oficinista I Ministerio Publico	Oficinista I	51719563	\N	\N	t	2026-02-03 19:59:33.209583	20240-P
344	3423224782201	Michael Jean	Carlo Escobar Florian	Departamento de Investigación de Delitos - DEIC - División de Análisis Criminal	Oficial Tercero	56153458	\N	\N	t	2026-02-03 19:59:33.209583	55314-P
345	2805406471419	Miguel Agustin	Tum Lopez	SGIC-DEIC-COBAN	Agente	\N	\N	\N	t	2026-02-03 19:59:33.209583	56459-P
346	3399916151413	Miguel Angel	Chavez Cobo	DEIC - Huehuetenango	Agente	48891251	\N	\N	t	2026-02-03 19:59:33.209583	56074-P
347	2802230940901	Miguel Roberto	Puac Rodas	Departamento de Investigación de Delitos - Delegación Totonicapán - DEIC	Agente	42441495	\N	\N	t	2026-02-03 19:59:33.209583	15712-P
348	2073482001303	Mike Annthony	Hidalgo Rosario	DEIC - Huehuetenango	Agente	32811043	\N	\N	t	2026-02-03 19:59:33.209583	41204-P
350	1836569111211	Milton Gudiel	López López	División Nacional Contra el Desarrollo Criminal de las Pandillas - DIPANDA - Escuintla	Oficial Tercero	30373558	\N	\N	t	2026-02-03 19:59:33.209583	34188-P
351	3249724661008	Milton René	Tunay Guerra	Departamento de Investigación de Delitos - Delegación Coatepeque - DEIC	Agente	54636440	\N	\N	t	2026-02-03 19:59:33.209583	59820-P
353	2974843701216	Mireily Luciel	Reyna Fuentes	Divisicón de Investigación y Desactivación de Armas y Expolivos - DIDAE	Agente	56340635	\N	\N	t	2026-02-03 19:59:33.209583	66584-P
354	1836733360508	Mirna Elizabeth	Rodriguez Lima	ORP - Inspectoría General	Agente	53450024	\N	\N	t	2026-02-03 19:59:33.209583	34853-P
356	1630544792104	Mynor Antonio	Aguilar Ramirez	SGAIA-PNC	Agente	\N	\N	\N	t	2026-02-03 19:59:33.209583	33105-P
360	2712480332207	Nancy Carolina	Peñate	Departamento de Investigación de Delitos - Delegación Santa Rosa - DEIC	Agente	59806865	\N	\N	t	2026-02-03 19:59:33.209583	61725-P
361	2329576062213	Natividad de	Jesus Garcia Fabian	Departamento de Investigación de Delitos Contra la Propiedad de Vehículos Automotores Terrestres - DEIC	Agente	59804685	\N	\N	t	2026-02-03 19:59:33.209583	40989-P
363	2871054742101	Nelson Rolando	Mendez Perez	División de Policía Internacional	Agente	42050911	\N	\N	t	2026-02-03 19:59:33.209583	68428-P
365	3087388450404	Nestor Adolfo	López Colaj	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	36239236	\N	\N	t	2026-02-03 19:59:33.209583	64525-P
368	2984463242201	Oldin Ediel	Salguero Ramos	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	40123496	\N	\N	t	2026-02-03 19:59:33.209583	55025-P
369	2534841541505	Olinda Isabel	Reyes Garcia	DEPARTAMENTO DE OPERACIONES-DEIC-SGIC	Agente	58071736	\N	\N	t	2026-02-03 19:59:33.209583	47220-P
370	1800018922211	Omer Rivel	Ortiz Martínez	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación de Delitos Financieros y Económicos	Agente	41075235	\N	\N	t	2026-02-03 19:59:33.209583	28950-P
373	1962156681001	Oscar Hilario	Xipon Nolasco	Escuela de Formacion de Oficiales de Policia ESFOP	Oficial Tercero	42668170	\N	\N	t	2026-02-03 19:59:33.209583	19140-P
375	3394028572101	Osman Eli	Jimenez Gonzalez	Dipanda - SGIC	Agente	46413231	\N	\N	t	2026-02-03 19:59:33.209583	55416-P
376	2901268190607	Osman Sacarías	Gómez Gaitán	Sección Contra la Trata de Personas -DEIC-	Agente	45966495	\N	\N	t	2026-02-03 19:59:33.209583	65853-P
377	2180915830415	Otto Lizardo	Marroquin Perez	División de Protección de Personas y Seguridad - DPPS	Agente	47208630	\N	\N	t	2026-02-03 19:59:33.209583	29607-P
379	2420158402001	Pablo Daniel	Ceballos	SGAIA-PNC	Agente	30358072	\N	\N	t	2026-02-03 19:59:33.209583	44725-P
380	1681716942210	Paula Hermina	Godoy Lima	Departamento de Investigación de Delitos - Delegación Jalapa - DEIC	Agente	42101810	\N	\N	t	2026-02-03 19:59:33.209583	52694-P
381	2952908542207	Paula Ivania	Chinchilla Diaz	División de Policía Internacional	Agente	33893514	\N	\N	t	2026-02-03 19:59:33.209583	65559-P
382	1974433540707	Pedro Antonio	Tó Pérez	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	58265506	\N	\N	t	2026-02-03 19:59:33.209583	38252-P
383	2458506351002	Pedro de	Jesus Sanabria Niños	DEIC - Mixco	Agente	54943985	\N	\N	t	2026-02-03 19:59:33.209583	32816-P
385	2213748091001	Petronilo Solval	Vicente	Departamento de Investigación de Delitos - Delegación Coatepeque - DEIC	Agente	59297899	\N	\N	t	2026-02-03 19:59:33.209583	52507-P
386	1663967371801	Porfirio Isidro	Rafael Sicajan Lobos	Departamento de Investigación de Delitos - DEIC - División de Análisis Criminal	Agente	54587242	\N	\N	t	2026-02-03 19:59:33.209583	52490-P
387	2346504782207	Rene Antonio	Godoy Rivera	Departamento de Investigación de Delitos - Delegación Santa Rosa - DEIC	Oficial Segundo	58094802	\N	\N	t	2026-02-03 19:59:33.209583	20679-P
388	2232418301609	Rene Pop	Cuz	Sección Contra la Trata de Personas -DEIC-	Agente	55236310	\N	\N	t	2026-02-03 19:59:33.209583	61804-P
389	1833722121503	Rene Romeo	Rojas Corazon	Departamento de Investigación de Delitos Patrimoniales - DEIC - SGIC -	Agente	54408565	\N	\N	t	2026-02-03 19:59:33.209583	29108-P
391	5157545300513	Reyna Victoria	Muñoz	Departamento de Investigación de Delitos - DEIC - División de Análisis Criminal	Agente	41612640	\N	\N	t	2026-02-03 19:59:33.209583	57838-P
393	2428112992211	Rito Marrey	Marroquin Aguirre	División de Policía Internacional	Agente	57819271	\N	\N	t	2026-02-03 19:59:33.209583	53130-P
397	1966621410101	Rodolfo Isaías	Rabanales López	Departamento de Investigación de Delitos - Delegación Escuintla - DEIC	Agente	36518563	\N	\N	t	2026-02-03 19:59:33.209583	37963-P
398	2296972670605	Rodrigo Javier	Lemus Solares	SGIC - Interpol	Agente	48519528	\N	\N	t	2026-02-03 19:59:33.209583	48796-P
401	1928567821101	Rolando Neftali	Morales Morales	Departamento de Investigación de Delitos - Delegación Suchitepéquez - DEIC	Agente	41283264	\N	\N	t	2026-02-03 19:59:33.209583	39593-P
402	1940827091229	Ronal Eduardo	López Rabanales	DEIC - Huehuetenango	Agente	49880792	\N	\N	t	2026-02-03 19:59:33.209583	36019-P
403	1782913902101	Ronal Geovanni	Guzmán Salazar	Interpol-DEIC-SGIC	Agente	55258034	\N	\N	t	2026-02-03 19:59:33.209583	37343-P
404	2079493441213	Ronal Iván	López Osorio	Departamento de Investigación de Delitos - Delegación Pinula - DEIC	Agente	30089260	\N	\N	t	2026-02-03 19:59:33.209583	41346-P
406	2294879390403	Rony Ismael	Lancerio Cusanero	CAT - SGIC	Agente	43425001	\N	\N	t	2026-02-03 19:59:33.209583	61353-P
407	2694483062210	Rosa Amarilis	Quiñonez Arevalo	SGAIA-PNC	Agente	30304941	\N	\N	t	2026-02-03 19:59:33.209583	52781-P
408	1806819071503	Rosa Herlinda	Ixpancoc Xitumul	Departamento de Investigación de Delitos - Delegación Baja Verapaz - DEIC	Agente	41141989	\N	\N	t	2026-02-03 19:59:33.209583	27802-P
409	2510163580608	Rosario Jimenez	Contreras	Ministerio Público	MP	53806337	\N	\N	t	2026-02-03 19:59:33.209583	\N
410	3002414290101	Roselyn Betzayda	Peláez García	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación Contra el Delito de Femicidio	Agente	41981438	\N	\N	t	2026-02-03 19:59:33.209583	66374-P
411	1989787231502	Rosmery Patricia	De Paz Orellana	DEIC - El Progreso	Agente	51305800	\N	\N	t	2026-02-03 19:59:33.209583	30258-P
412	2075466062001	Rubi Amabilia	Diaz Agustin	DIPANDA ISABAL-SGIC	Oficial Primero	46807591	\N	\N	t	2026-02-03 19:59:33.209583	37093-P
415	2619500611901	Rudy Mauricio	Asencio Vásquez	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación Contra el Delito de Femicidio	Agente	30123043	\N	\N	t	2026-02-03 19:59:33.209583	60634-P
430	2457448431007	Sergio Daniel	Linares Linares	Dipanda - SGIC	Agente	30424057	\N	\N	t	2026-02-03 19:59:33.209583	66050-P
417	1736730661201	Ruperto Jesus	Maldonado Hernandez	DEIC - Huehuetenango	Agente	31063408	\N	\N	t	2026-02-03 19:59:33.209583	39480-P
418	1748463201503	Ruth Noemi	Milian Tovias	Departamento de Investigación de Delitos Patrimoniales - DEIC - SGIC -	Agente	38816056	\N	\N	t	2026-02-03 19:59:33.209583	37660-P
421	2261175880401	Sandro Jeremias	Ramírez García	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Oficial Tercero	50161860	\N	\N	t	2026-02-03 19:59:33.209583	14875-P
422	3420529772201	Sandy Hoeymi	Cardona Jiménez	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación Contra el Delito de Femicidio	Agente	39785278	\N	\N	t	2026-02-03 19:59:33.209583	60780-P
423	3428876382207	Santos Armando	Goy Peñate	S/N	N/T	55575624	\N	\N	t	2026-02-03 19:59:33.209583	\N
424	2711222421203	Sarbelio Adonaí	López Alvarado	Departamento de Investigación Contra Secuestros - SGIC	Agente	50182143	\N	\N	t	2026-02-03 19:59:33.209583	37459-P
427	2591331911501	Selvin Estuardo	Alonzo Rodriguez	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	36244552	\N	\N	t	2026-02-03 19:59:33.209583	65283-P
428	3163883001503	Selvin Haroldo	Milian Reyes	Sección Contra la Trata de Personas -DEIC-	Agente	30733348	\N	\N	t	2026-02-03 19:59:33.209583	66230-P
431	1781348210101	Sergio Danilo	Melendez Guerra	Departamento Administrativo de Apoyo y Logística, Policía Internacional, INTERPOL	\N	30092630	\N	\N	t	2026-02-03 19:59:33.209583	19958-P
434	3429406272210	Seydi Magali	Grijalva Arevalo	Departamento de Investigación de Delitos - Delegación Jalapa - DEIC	Agente	36794487	\N	\N	t	2026-02-03 19:59:33.209583	65897-P
437	2021589190607	Silvia Olinda	Gomez Mayen	División de Protección de Personas y Seguridad - DPPS	Agente	42964220	\N	\N	t	2026-02-03 19:59:33.209583	52701-P
439	2863665922211	Sindi Yanira	García y García	Divisicón de Investigación y Desactivación de Armas y Expolivos - DIDAE	Agente	48946660	\N	\N	t	2026-02-03 19:59:33.209583	65835-P
440	2787699422201	Sindy Areli	Alejandro Cordero	División de Policía Internacional	Agente	30476181	\N	\N	t	2026-02-03 19:59:33.209583	65274-P
441	2329735982216	Sindy Yanira	Pineda Castillo	Departamento de Investigación de Delitos - Delegación Santa Rosa - DEIC	Agente	48647367	\N	\N	t	2026-02-03 19:59:33.209583	58035-P
449	2301776460901	Vicente Castañeda	Lopez	Divisicón de Investigación y Desactivación de Armas y Expolivos - DIDAE	Oficial Segundo	30486227	\N	\N	t	2026-02-03 19:59:33.209583	14110-P
450	1986431871501	Victor Saul	Adquí Adquí	Departamento de Investigación de Delitos - Delegación Baja Verapaz - DEIC	Agente	55545704	\N	\N	t	2026-02-03 19:59:33.209583	36648-P
451	1836566520610	Waldis Oniel	Botello Alfaro	DEIC - Peten	Agente	42517661	\N	\N	t	2026-02-03 19:59:33.209583	30030-P
453	1950191050315	Walter Alfredo	Guaran Chávez	Departamento de Investigación de Delitos - Delegación Chimaltenango - DEIC	Agente	30244928	\N	\N	t	2026-02-03 19:59:33.209583	26495-P
458	1736613430607	Walther Obdulio	Gonzalez Cano	Departamento de Investigación de Delitos - Delegación Escuintla - DEIC	Agente	59603931	\N	\N	t	2026-02-03 19:59:33.209583	37281-P
460	2855504382216	Warner Oswaldo	Carias Castillo	SGAIA-PNC	Agente	46295714	\N	\N	t	2026-02-03 19:59:33.209583	62381-P
461	2407428500608	Wender Castillo	Herrera	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación de Delitos Financieros y Económicos	Agente	54970243	\N	\N	t	2026-02-03 19:59:33.209583	33389-P
466	3389902591001	Wilfredo Nazario	Hernandez Tupul	Departamento de Investigación de Delitos - DEIC - División de Análisis Criminal	Agente	58752642	\N	\N	t	2026-02-03 19:59:33.209583	64420-P
467	1709662751101	Wiliam Roderico	Reyes Gramajo	Departamento de Investigación de Delitos - Delegación Escuintla - DEIC	Agente	41568768	\N	\N	t	2026-02-03 19:59:33.209583	39825-P
469	1622355820415	William Enrique	Marroquin Hernandez	División de Protección de Personas y Seguridad - DPPS	Agente	47579399	\N	\N	t	2026-02-03 19:59:33.209583	48873-P
470	3394262412101	William Estuardo	Nájera López	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación de Delitos Financieros y Económicos	Agente	30344097	\N	\N	t	2026-02-03 19:59:33.209583	62869-P
472	1603452941503	Wilson Alberto	Chuy Alvarado	Interpol-DEIC-SGIC	Agente	55967158	\N	\N	t	2026-02-03 19:59:33.209583	51083-P
473	2246283050404	Wilson David	Sotz Curuchich	Departamento de Investigación de Delitos - Delegación Escuintla - DEIC	Agente	41198334	\N	\N	t	2026-02-03 19:59:33.209583	45791-P
474	2529082282201	Wulmaro Walverto	Coronado Mateo	DEIC - Chiquimulilla	Inspector	35872464	\N	\N	t	2026-02-03 19:59:33.209583	14190-P
475	2058195401610	Xeyder Gerardo	Xicol Macz	DEIC - Alta Verapaz	Agente	53100852	\N	\N	t	2026-02-03 19:59:33.209583	38364-P
476	2327130300301	Xiomara del	Milagro Chavez Ortiz	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	55230396	\N	\N	t	2026-02-03 19:59:33.209583	38920-P
477	2111814472201	Yarelyn Marisol	Marroquin Alejandro	Interpol-DEIC-SGIC	Agente	55366931	\N	\N	t	2026-02-03 19:59:33.209583	52743-P
480	3000419850101	Yoni Anderson	Ramírez Lemus	Departamento de Operaciones-ST-SGIC	Agente	39752524	\N	\N	t	2026-02-03 19:59:33.209583	68839-P
481	2123831910411	Yorin Aroldo	Pichiya García	Departamento de Investigación de Delitos - Delegación Villa Nueva - DEIC	Agente	54437280	\N	\N	t	2026-02-03 19:59:33.209583	41627-P
483	3389275731001	Ysmar Fernando	Acabal	División Nacional Contra el Desarrollo Criminal de las Pandillas - DIPANDA - Escuintla	Agente	59894498	\N	\N	t	2026-02-03 19:59:33.209583	63727-P
486	2201865022206	Zonia Suleima	Valenzuela Barrientos	Jefatura Adjunta de Departamentos y Delegaciones Especiales de Investigación - DEIC -	Profesional I	51241634	\N	\N	t	2026-02-03 19:59:33.209583	32915-P
487	1800959350301	Zuliana Judith	Archila	Departamento de Administración de Compensaciones, Incentivos y Remuneraciones - DACIR-SGP	Profesional I	41387688	\N	\N	t	2026-02-03 19:59:33.209583	51914-P
488	3017398700101	Kimberly Yanira	Chiapaz Hernandez	DEIC-BAJA VERAPAZ	Agente	37936851	\N	\N	t	2026-02-03 19:59:33.209583	64012-P
307	1772371390101	Luis Fermin	Perez Xamba	UEI-SGIC	Agente	59107534	\N	\N	t	2026-02-03 19:59:33.209583	37902-P
414	1938549532103	Rudy Arnoldo	Yaque Lopez	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Oficial Tercero	30319038	\N	\N	t	2026-02-03 19:59:33.209583	35217-P
490	3132609740901	Luis Fernando	Pererira Jocol	SGIC-DEIC PNC	Agente	58562496	\N	\N	t	2026-02-03 19:59:33.209583	64811-P
491	2457111041804	Gerardo Antonio	Lpez	DIVISION ESPECIALIZADA EN INVESTIGACION CRIMINAL-DEIC	Agente	56215929	\N	\N	t	2026-02-03 19:59:33.209583	41280-P
464	2557096841212	Wesby Walberto	Godinez Lopez	DEI-COATEPEQUE	Subinspector	40180829	\N	\N	t	2026-02-03 19:59:33.209583	28599-P
54	1781719802101	Byron Salvador	Castañeda Cruz	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	51226715	\N	\N	t	2026-02-03 19:59:33.209583	55258-P
150	3411821411416	Francisco Flores	Vásquez	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	55658192	\N	\N	t	2026-02-03 19:59:33.209583	63300-P
492	2083532401502	Clemente Garcia	Sis	DIVISION ESPECIALIZADA EN INVESTIGACION CRIMINAL-DEIC	Agente	41651897	\N	\N	t	2026-02-03 19:59:33.209583	42717-P
88	2554823880203	Deyvis Josué	Crúz	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	30165437	\N	\N	t	2026-02-03 19:59:33.209583	53469-P
493	2057678180606	Carlos Alfredo	Guevara Zepeda	DIVISION ESPECIALIZADA EN INVESTIGACION CRIMINAL-DEIC	Agente	42661135	\N	\N	t	2026-02-03 19:59:33.209583	48691-P
173	1703714681202	Hanaly Daniela	Velásquez Osorio	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	55514382	\N	\N	t	2026-02-03 19:59:33.209583	40094-P
494	2068396422102	Bayron Rene	Rosa Mateo	DIVISION ESPECIALIZADA EN INVESTIGACION CRIMINAL-DEIC	Agente	42554141	\N	\N	t	2026-02-03 19:59:33.209583	50680-P
495	3618332371607	Elfido Ogaldez	Que Bin	DIVISION ESPECIALIZADA EN INVESTIGACION CRIMINAL-DEIC	Agente	40062540	\N	\N	t	2026-02-03 19:59:33.209583	58065-P
38	3468890141202	Banny Armando	Ramírez Fuentes	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación Contra el Delito de Femicidio	Oficial Tercero	37128368	\N	\N	t	2026-02-03 19:59:33.209583	56382-P
496	2906837930206	Veronica Jamileth	Ramos Morales	DIVISION ESPECIALIZADA EN INVESTIGACION CRIMINAL-DEIC	Agente	44809036	\N	\N	t	2026-02-03 19:59:33.209583	66555-P
65	1936439951610	Carlos Roberto	Poou Cabnal	Sección Contra la Trata de Personas -DEIC-	Agente	56644399	\N	\N	t	2026-02-03 19:59:33.209583	30826-P
372	3226562491001	Oscar Armando	Zamudio Santos	DIPANDA-SGIC PNC	Agente	54887851	\N	\N	t	2026-02-03 19:59:33.209583	66834-P
338	1696603462201	Melvin Estuardo	Ramírez Salvador	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación de Delitos Financieros y Económicos	Agente	30322298	\N	\N	t	2026-02-03 19:59:33.209583	49158-P
296	2137531031014	Lucero Adriana	Chilin	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación de Delitos Financieros y Económicos	Agente	56952573	\N	\N	t	2026-02-03 19:59:33.209583	52652-P
135	2750021521108	Erwin José	Ignacio Cifuentes Cifuentes	DIPANDO-SGIC PNC	Agente	45218249	\N	\N	t	2026-02-03 19:59:33.209583	63249-P
448	2647819100101	Veronica Magaly	Ramos Lopez	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación de Delitos Financieros y Económicos	Agente	47513114	\N	\N	t	2026-02-03 19:59:33.209583	32729-P
324	3345481011805	Mario Antonio	Aguilar Lima	DEIC-COATEPEQUE	Agente	42295967	\N	\N	t	2026-02-03 19:59:33.209583	60557-P
497	1619347730501	Juan Clemente	Chávez Gonzalez	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación Contra el Delito de Femicidio	Agente	30194186	\N	\N	t	2026-02-03 19:59:33.209583	12903-P
311	2732641171010	Manolo Ixtos	Morales	DEIC-COATEPEQUE	Agente	39570186	\N	\N	t	2026-02-03 19:59:33.209583	18665-P
498	1795602981605	Erick Baldomero	Calel Sis	Departamento de Investigación de Delitos Contra la Propiedad de Vehículos Automotores Terrestres - DEIC	Agente	51541958	\N	\N	t	2026-02-03 19:59:33.209583	25663-P
90	2352449960610	Diego Fernando	Orozco Ramos	Departamento-DIDAE-SGIC	Agente	36047065	\N	\N	t	2026-02-03 19:59:33.209583	49010-P
53	2371294851106	Byron Ranferí	Macario Díaz	Departamento de Investigación de Delitos - Delegación Pinula - DEIC	Agente	54946232	\N	\N	t	2026-02-03 19:59:33.209583	26002-P
332	1736203021007	Marta Rosa	Albino Cap	Departamento de Investigación de Delitos - Delegación Pinula - DEIC	Agente	54941595	\N	\N	t	2026-02-03 19:59:33.209583	49520-P
147	3345694001805	Ferdi Vinicio	Martínez Morales	Departamento de Investigación de Delitos - Delegación Pinula - DEIC	Agente	46165203	\N	\N	t	2026-02-03 19:59:33.209583	59386-P
89	1979785922211	Didier Bonifacio	Martínez Ramírez	Departamento de Investigación de Delitos - Delegación Pinula - DEIC	Agente	44941899	\N	\N	t	2026-02-03 19:59:33.209583	41410-P
203	2490864840610	Irvin Estuardo	González Ramírez	Departamento de Investigación de Ciberdelitos e Informática Forense	Oficial Tercero	30190049	\N	\N	t	2026-02-03 19:59:33.209583	45050-P
240	2289658630501	José Alfaro	Medina	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación de Delitos Financieros y Económicos	Oficial Primero	30485112	\N	\N	t	2026-02-03 19:59:33.209583	27432-P
503	1939814671501	Dina Rubi	Salvdor Herrera	DEIC-BAJA VERAPAZ	Subinspector	30256054	\N	\N	t	2026-02-03 19:59:33.209583	38125-P
504	1957532081003	Luis Carlos	López Rodriguez	DIPANDA-Retalhuleu	Agente	30367038	\N	\N	t	2026-02-03 19:59:33.209583	21991-P
505	2961031601605	Edwin Geovany	Caal Cha	DEIC-BAJA VERAPAZ	Agente	30803905	\N	\N	t	2026-02-03 19:59:33.209583	52033-P
506	1834975381501	Lesdy Beraliz	Perez Muñiz	DEIC-BAJA VERAPAZ	Agente	30340836	\N	\N	t	2026-02-03 19:59:33.209583	37880-P
507	3250492111009	Edinson Ely	Gómez Farfán	DIPANDA-Retalhuleu	Agente	48490665	\N	\N	t	2026-02-03 19:59:33.209583	67862-P
508	2178112801202	Rony Yeison	Ardiano Velásquez	DIPANDA-Retalhuleu	Agente	54193134	\N	\N	t	2026-02-03 19:59:33.209583	63183-P
325	2425559182201	Mario Roberto	Mendez Hernandez	DEIC - Izabal	Inspector	30353131	\N	\N	t	2026-02-03 19:59:33.209583	13460-P
509	2623491592101	Joselyn Sujeyli	Bocanegra Téllez	DEIC - Jalapa	Subinspector	30503210	\N	\N	t	2026-02-03 19:59:33.209583	52627-P
510	2553595941108	Dilan Randy	López de León	DIPANDA-Retalhuleu	Agente	32971913	\N	\N	t	2026-02-03 19:59:33.209583	53412-P
511	2211714441203	Wilson Gustavo	Carreto Ramirez	DEIC-QUETZALTENANGO	Agente	47063126	\N	\N	t	2026-02-03 19:59:33.209583	38868-P
396	1675574241503	Robin Wagner	Sic Alvarado	DEIC - Jalapa	Agente	59887107	\N	\N	t	2026-02-03 19:59:33.209583	55956-P
226	2852439501202	Job Vitalino	López Juárez	DEIC-QUETZALTENANGO	Agente	30876767	\N	\N	t	2026-02-03 19:59:33.209583	64537-P
176	2600323521001	Hector David Puac	de la Cruz	DEIC-QUETZALTENANGO	Agente	36070798	\N	\N	t	2026-02-03 19:59:33.209583	50568-P
512	9999191388670	Sindy Magelda	Coutiño Cifuentes	Division de Metodos Especialzados de Investigacion-DIMEI-SGIC	Subcomisario	30205055	\N	\N	t	2026-02-03 19:59:33.209583	25730-P
223	3301352951201	Jeyson Estuardo	Perez Velasquez	DEIC-QUETZALTENANGO	Agente	58614889	\N	\N	t	2026-02-03 19:59:33.209583	66421-P
341	1856254600703	Melvin Ruben	Sosa Aju	Departamento de Investigación de Delitos - Delegación Quiché - DEIC	Agente	56350812	\N	\N	t	2026-02-03 19:59:33.209583	52511-P
513	9999153107088	Iris Adalila	Bravo Lopez	Division de Metodos Especialzados de Investigacion-DIMEI-SGIC	Oficial Primero	55529425	\N	\N	t	2026-02-03 19:59:33.209583	36804-P
514	1973979722210	Henry Leonel	Garza Lopez	Division de Metodos Especialzados de Investigacion-DIMEI-SGIC	Oficial Tercero	39995949	\N	\N	t	2026-02-03 19:59:33.209583	37230-P
11	2100828790805	Alex Nibardo	Tzun Sontay	Departamento de Investigación de Delitos - Delegación Quiche - DEIC	Agente	39956257	\N	\N	t	2026-02-03 19:59:33.209583	52563-P
44	1633140630709	Bibian Erica	Solis Mendoza	Departamento de Investigación de Delitos - Delegación Quiché - DEIC	Agente	58594123	\N	\N	t	2026-02-03 19:59:33.209583	21230-P
515	9999564321473	Alex Orlando	Gabriel Bar	Division de Metodos Especialzados de Investigacion-DIMEI-SGIC	Oficial Tercero	30107771	\N	\N	t	2026-02-03 19:59:33.209583	37175-P
446	1901141690718	Tomas Alfonso	Sajquiy Buch	Departamento de Investigación de Delitos - Delegación Quiche - DEIC	Agente	59331935	\N	\N	t	2026-02-03 19:59:33.209583	39889-P
516	9999781839309	Mavin Enriquez	Guzman Gonzalez	Division de Metodos Especialzados de Investigacion-DIMEI-SGIC	Subinspector	52043648	\N	\N	t	2026-02-03 19:59:33.209583	41155-P
274	1912936602207	Julio Rene	Cordon Rios	Departamento de Investigación de Delitos - Delegación Santa Rosa - DEIC	Oficial Primero	30128638	\N	\N	t	2026-02-03 19:59:33.209583	18423-P
517	3238947981002	Edwin Josue	Castañeda Albeño	DIGICI-MINGOB	Agente	42213022	\N	\N	t	2026-02-03 19:59:33.209583	67275-P
518	1971251580101	Luis Eduardo	Valdez Oliva	Sub direccion General de Salud Policial	Administrativo	59901098	\N	\N	t	2026-02-03 19:59:33.209583	38533-P
24	2427350530101	Angel Esteban	Muñoz Castañeda	División Especializada de Investigación Santa Rosa - DEIC - SGIC	Agente	30474623	\N	\N	t	2026-02-03 19:59:33.209583	34460-P
267	2394455030801	Juan Salome	Sapon Tax	DEIC-SOLOLA	Agente	59374698	\N	\N	t	2026-02-03 19:59:33.209583	52483-P
519	2551528331326	Cesar Jonathan	Calel Castañeda	Sub direccion General de Salud Policial	Administrativo	59901098	\N	\N	t	2026-02-03 19:59:33.209583	54181-P
478	1733965501211	Yener Osbely	Tomas Coronado	Departamento de Investigación de Delitos - Delegación Totonicapán - DEIC	Agente	36653504	\N	\N	t	2026-02-03 19:59:33.209583	54128-P
520	2510165800608	Rosario Jimenez	Contreras	MINISTERIO PUBLICO	Analista Profesional II	53806337	\N	\N	t	2026-02-03 19:59:33.209583	19950-P
205	2243037831213	Ivan Everardo	Lopez Hernandez	Departamento de Investigación de Delitos - Delegación Totonicapán - DEIC	Agente	55951577	\N	\N	t	2026-02-03 19:59:33.209583	30571-P
57	2428190281326	Carlos Eloin	Rivas Castillo	DEIC - Huehuetenango	Oficial Primero	30559339	\N	\N	t	2026-02-03 19:59:33.209583	22341-P
220	1877550861301	Jervin Suneri	Argueta Solis	DEIC - Huehuetenango	Agente	30961623	\N	\N	t	2026-02-03 19:59:33.209583	38741-P
521	1574073810101	Cecilia Yaquelin	Perez Roche	DAAP-SGP	Agente	42902459	\N	\N	t	2026-02-03 19:59:33.209583	32659-P
522	2419897870608	Fausto Ignacio	Chajon Hernandez	DAAP-SGP	Agente	42101872	\N	\N	t	2026-02-03 19:59:33.209583	25692-P
9	1663099310920	Alex Alfredo	Lucas Villatoro	SGIC DEIC-HUEHUETENANGO	Agente	58241347	\N	\N	t	2026-02-03 19:59:33.209583	41367-P
523	2956051702201	Wagner Josue	Godoy Olivares	SAFE-SGIC	Agente	37823280	\N	\N	t	2026-02-03 19:59:33.209583	70410-P
524	2652463181606	Abdi Natanael	Coc Xol	DEIC - Zacapa	Agente	33086799	\N	\N	t	2026-02-03 19:59:33.209583	30181-P
251	2145795810404	José Mario	Pichiyá Velásquez	Jefatura Adjunta de Departamentos y Delegaciones Especiales de Investigación - DEIC -	Agente	30994678	\N	\N	t	2026-02-03 19:59:33.209583	49096-P
479	2700580280203	Yesica Beatriz	Toledo Cruz	Jefatura Adjunta de Departamentos y Delegaciones Especiales de Investigación - DEIC -	Agente	46930455	\N	\N	t	2026-02-03 19:59:33.209583	58406-P
4	2194225592214	Ada Lisbeth	Corado Meda	Jefatura Adjunta de Departamentos y Delegaciones Especiales de Investigación - DEIC -	Agente	56943679	\N	\N	t	2026-02-03 19:59:33.209583	42496-P
444	2890742232206	Thania Fernanda	Quiñonez Martínez	Jefatura Adjunta de Departamentos y Delegaciones Especiales de Investigación - DEIC -	Agente	46996726	\N	\N	t	2026-02-03 19:59:33.209583	68807-P
193	3424519792201	Heydelyn Esmeralda	Hernández Vega	Jefatura Adjunta de Departamentos y Delegaciones Especiales de Investigación - DEIC -	Agente	39950261	\N	\N	t	2026-02-03 19:59:33.209583	70580-P
425	2920569900404	Selvin Arnulfo	Chex Cana	Jefatura Adjunta de Departamentos y Delegaciones Especiales de Investigación - DEIC -	Agente	45001998	\N	\N	t	2026-02-03 19:59:33.209583	54517-P
86	1955029142206	Dember David	Asencio Corado	DEIC - PETEN	Oficial Primero	30287630	\N	\N	t	2026-02-03 19:59:33.209583	33210-P
172	2153023890401	Gustavo Adolfo	Tuyuc Otzoy	Delegación Suchitepéquez - DEIC	Oficial Tercero	30581013	\N	\N	t	2026-02-03 19:59:33.209583	41931-P
525	2659866212214	Brayan Agustin	Jeronimo Quinteros	Delegación Suchitepéquez - DEIC	Agente	55161176	\N	\N	t	2026-02-03 19:59:33.209583	45147-P
10	3449950110101	Alex Leonel	Grijalva Gutierrez	DIGICI	Agente	35696975	\N	\N	t	2026-02-03 19:59:33.209583	59151-P
526	1717234141109	Felipe Salvador	Rivera Izara	en	Oficial Tercero	30125326	\N	\N	t	2026-02-03 19:59:33.209583	18987-P
527	1730124260108	Claudia Lorena	Mendez Hernández	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Inspector	30076167	\N	\N	t	2026-02-03 19:59:33.209583	43161-P
528	2171762080101	Pablo Alejandro	Ramirez García	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Inspector	53187022	\N	\N	t	2026-02-03 19:59:33.209583	39776-P
529	2279176420404	Edgar David	Tubín Estepán	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	41687307	\N	\N	t	2026-02-03 19:59:33.209583	52542-P
139	2305027411415	Estuardo Rigoberto	Rivera Natareno	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	58150006	\N	\N	t	2026-02-03 19:59:33.209583	52447-P
530	2436074150401	Edvin Vinicio	Tagual Suyuc	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	30566807	\N	\N	t	2026-02-03 19:59:33.209583	32880-P
531	2634606652201	Edgar Augusto	Martínez Vargas	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	30088852	\N	\N	t	2026-02-03 19:59:33.209583	48895-P
532	1665746350404	Gildey Roberto	Sen Cuxil	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	53865906	\N	\N	t	2026-02-03 19:59:33.209583	31719-P
533	2099222810201	Urier Josué	Santiz Ortiz	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	53186321	\N	\N	t	2026-02-03 19:59:33.209583	41830-P
534	2907848830610	Luis Enrique	Esteban Lemus	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	53191747	\N	\N	t	2026-02-03 19:59:33.209583	58988-P
535	2801860612201	Brailyn Yonjairo	Ramos Yanes	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	37902443	\N	\N	t	2026-02-03 19:59:33.209583	68889-P
536	1875497020607	Carolina Aguilar	Felipe	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	38740153	\N	\N	t	2026-02-03 19:59:33.209583	40428-P
537	1943394831009	Osman Rocael	Puac Castro	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	30556924	\N	\N	t	2026-02-03 19:59:33.209583	39748-P
538	1975040001009	Sergio Eliseo	Xiquín Chavajay	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	42692192	\N	\N	t	2026-02-03 19:59:33.209583	40119-P
539	1725740721106	Pablo Chávez	Pérez	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	46231771	\N	\N	t	2026-02-03 19:59:33.209583	19270-P
540	1864783560610	Edgar Roberto	Bailón Santos	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	50190040	\N	\N	t	2026-02-03 19:59:33.209583	28291-P
541	2124425621203	Rodelbí Abelino	Estrada Cardona	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	55757863	\N	\N	t	2026-02-03 19:59:33.209583	40919-P
542	1714387521207	Amilcar Soto	Pérez	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	30200237	\N	\N	t	2026-02-03 19:59:33.209583	41882-P
543	1706824470717	Luciano Yotz	Ujpán	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	50193974	\N	\N	t	2026-02-03 19:59:33.209583	27042-P
544	2313555561207	Lorenzo Rufino	Mejía Sánchez	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	48878005	\N	\N	t	2026-02-03 19:59:33.209583	59421-P
545	2346010001101	Hermer Josue	López Reynoso	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	55784834	\N	\N	t	2026-02-03 19:59:33.209583	44178-P
546	2485171202201	Nolmar Filadelfo	Ramos Yanes	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	37913153	\N	\N	t	2026-02-03 19:59:33.209583	34799-P
547	3431372242213	Edgar Ruben	Moran Lorenzo	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	59402302	\N	\N	t	2026-02-03 19:59:33.209583	59475-P
548	3164616871503	Byron Samuel	Alvarado Azumatán	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	30496496	\N	\N	t	2026-02-03 19:59:33.209583	58634-P
549	1932182401017	Yadira Maribel Chay	Ordoñez De Mendoza	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	42140452	\N	\N	t	2026-02-03 19:59:33.209583	56898-P
550	2175259381213	Ricardo Eugenio	Sandoval Agustin	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	45874982	\N	\N	t	2026-02-03 19:59:33.209583	29758-P
551	2403325551416	Erwin Feliciano	Gómez Mejia	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	58797241	\N	\N	t	2026-02-03 19:59:33.209583	36165-P
552	1918688092201	Pedro Jairo	Geovany Xi Grijalva	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	41497924	\N	\N	t	2026-02-03 19:59:33.209583	35192-P
553	2486002222210	Tony Bryan	Martínez Sandoval	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	58273568	\N	\N	t	2026-02-03 19:59:33.209583	59388-P
554	2205577641406	Samuel Tián	Mejía	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación Contra el Delito de Femicidio	Oficial Tercero	30836108	\N	\N	t	2026-02-03 19:59:33.209583	35046-P
555	2450519962001	Randall Humberto	García Sánchez	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación Contra el Delito de Femicidio	Inspector	30433584	\N	\N	t	2026-02-03 19:59:33.209583	35781-P
556	2705485801712	Hansell René	Virula Méndez	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación Contra el Delito de Femicidio	Agente	56254213	\N	\N	t	2026-02-03 19:59:33.209583	55663-P
557	2743916862213	Jilman Estuardo	Gutierrez Hernández	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación Contra el Delito de Femicidio	Agente	59779447	\N	\N	t	2026-02-03 19:59:33.209583	59163-P
558	3221740900801	Juan Olegario	Batz Tzul	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación Contra el Delito de Femicidio	Agente	59592447	\N	\N	t	2026-02-03 19:59:33.209583	63198-P
559	2076826230717	Juan Martín	Yotz Ramírez	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación Contra el Delito de Femicidio	Agente	30301812	\N	\N	t	2026-02-03 19:59:33.209583	38395-P
560	2861314711229	Herson Jesús	López Gramajo	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación Contra el Delito de Femicidio	Agente	48493723	\N	\N	t	2026-02-03 19:59:33.209583	64530-P
561	1752953282201	Oseas Antonio	Sarceño Ramos	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación Contra el Delito de Femicidio	Agente	32551370	\N	\N	t	2026-02-03 19:59:33.209583	41841-P
563	2814087261508	Angel Maurilio	Rax Juc	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación Contra el Delito de Femicidio	Agente	30166899	\N	\N	t	2026-02-03 19:59:33.209583	58145-P
564	2666889501504	Lidia Coz	González	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación Contra el Delito de Femicidio	Agente	59786156	\N	\N	t	2026-02-03 19:59:33.209583	55759-P
565	1732490000404	Ervin Venturo	Similox Ramón	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación Contra el Delito de Femicidio	Agente	58137047	\N	\N	t	2026-02-03 19:59:33.209583	32850-P
566	1939039460921	Nestor Gamadiel	Cardona Orosco	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación Contra el Delito de Femicidio	Agente	47441003	\N	\N	t	2026-02-03 19:59:33.209583	32031-P
567	1969637371504	Ancelmo Teletor	Taperia	SGIC-DEIC PNC	Oficial Tercero	32458509	\N	\N	t	2026-02-03 19:59:33.209583	29776-P
568	1995387860610	Edgar Marin	González y González	SGIC-DEIC PNC	Subinspector	42590391	\N	\N	t	2026-02-03 19:59:33.209583	48675-P
569	1966235021604	Luigi Angel	Rolando Tecum Matus	SGIC-DEIC PNC	Agente	42236264	\N	\N	t	2026-02-03 19:59:33.209583	38238-P
570	3432928902215	Jennifer Sulema	Barahona López	SGIC-DEIC PNC	Agente	35839999	\N	\N	t	2026-02-03 19:59:33.209583	67090-P
489	2223075441501	Amilcar Noe	Ramos Larios	SGIC-DEIC PNC	Agente	41474725	\N	\N	t	2026-02-03 19:59:33.209583	55936-P
571	1653283632212	Marco Antonio	Vargas Mencos	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación Contra el Delito de Femicidio	Agente	54115310	\N	\N	t	2026-02-03 19:59:33.209583	31765-P
572	2856077582201	Leidy Sucely	Monzón Sarceño	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación Contra el Delito de Femicidio	Agente	50189972	\N	\N	t	2026-02-03 19:59:33.209583	64706-P
573	1581642532206	Ebelin Siomara Escobar	Barillas De Rivera	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación Contra el Delito de Femicidio	Agente	31056637	\N	\N	t	2026-02-03 19:59:33.209583	52677-P
574	1840984400502	Imelda Galindo	Morales De López	Departamento de Investigación de Delitos - DEIC - SGIC -	Oficial Primero	30382096	\N	\N	t	2026-02-03 19:59:33.209583	16367-P
575	3330958201206	Denis Danilo	Aguilar Pérez	Departamento de Investigación de Delitos Contra la Niñez y la Adolescencia  adolescentes en conflicto con la ley penal	Agente	45198850	\N	\N	t	2026-02-03 19:59:33.209583	63736-P
576	1749806121101	Angel Alexander	Chanté Pérez	Departamento de Investigación de Delitos Contra la Niñez y la Adolescencia  adolescentes en conflicto con la ley penal	Agente	35863454	\N	\N	t	2026-02-03 19:59:33.209583	40712-P
577	1817794632211	Ivis Yesenia Cortéz	Martinez de López	Departamento de Investigación de Delitos Contra la Niñez y la Adolescencia  adolescentes en conflicto con la ley penal	Agente	58663980	\N	\N	t	2026-02-03 19:59:33.209583	42508-P
578	2286868062107	Deimy Victoria	Escobar Valdéz	Departamento de Investigación de Delitos Contra la Niñez y la Adolescencia  adolescentes en conflicto con la ley penal	Agente	37421624	\N	\N	t	2026-02-03 19:59:33.209583	42611-P
579	2941651341502	Edras Omar	Capriel Camó	SGIC-DEIC PNC	Agente	42977883	\N	\N	t	2026-02-03 19:59:33.209583	60775-P
580	1760633070513	Nancy Maribel	Ramirez Castellanos	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación de Delitos Financieros y Económicos	Oficial Tercero	30527606	\N	\N	t	2026-02-03 19:59:33.209583	32706-P
581	1676405260101	Luis Fernando	Núñez	SGIC-DEIC PNC	Subinspector	30345251	\N	\N	t	2026-02-03 19:59:33.209583	41507-P
582	1583483892211	Elmer Adalberto	Martínez Ramírez	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación de Delitos Financieros y Económicos	Agente	37607693	\N	\N	t	2026-02-03 19:59:33.209583	36079-P
583	1926019972107	Víctor Samuel	Jolón Fajardo	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación de Delitos Financieros y Económicos	Agente	51952431	\N	\N	t	2026-02-03 19:59:33.209583	21495-P
585	1598743510920	Yesenia Beatriz	Hernández Calderon	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación de Delitos Financieros y Económicos	Agente	56335533	\N	\N	t	2026-02-03 19:59:33.209583	33964-P
586	2197249702207	Gustavo Adolfo	Valladares Ríos	Departamento de Investigación de Delitos Patrimoniales - DEIC - SGIC -	Agente	42670708	\N	\N	t	2026-02-03 19:59:33.209583	31764-P
587	2311676522206	Isaí Alberto	Ordoñez Valdez	Departamento de Investigación de Delitos Patrimoniales - DEIC - SGIC -	Agente	44264703	\N	\N	t	2026-02-03 19:59:33.209583	49003-P
588	2452380772101	Flora Marleny	Jiménez López	Departamento de Investigación de Delitos Patrimoniales - DEIC - SGIC -	Agente	38126351	\N	\N	t	2026-02-03 19:59:33.209583	54719-P
589	2619476480611	Dora Elvira	Montufar Gómez	Departamento de Investigación de Delitos contra el ambiente	Oficial Segundo	55245361	\N	\N	t	2026-02-03 19:59:33.209583	03097-P
590	1782912932101	Wilson Alber	Chavez Alarcón	Departamento de Investigación de Delitos contra el ambiente	Agente	58436999	\N	\N	t	2026-02-03 19:59:33.209583	36931-P
591	3459306302102	Heidi Yanira	Gómez Galicia	Departamento de Investigación de Delitos contra el ambiente	Agente	41748483	\N	\N	t	2026-02-03 19:59:33.209583	57285-P
592	2615500472211	Katerin Alondra	Santiago Chávez	Departamento de Investigación de Delitos contra el ambiente	Agente	35951405	\N	\N	t	2026-02-03 19:59:33.209583	52814-P
593	2613951650101	Sandra Maribel Jolón	Mendez De Machá	Departamento de Investigación de Delitos Contra la Propiedad de Vehículos Automotores Terrestres - DEIC	Subinspector	40172600	\N	\N	t	2026-02-03 19:59:33.209583	28724-P
594	2375391010206	Rómulo Omar	Castañeda Ruano	Sección de Revisión Fisica	Subinspector	59584226	\N	\N	t	2026-02-03 19:59:33.209583	47315-P
595	2581134051008	Cristian Belisario	Quiché Sohón	Sección de Revisión Fisica	Subinspector	30382051	\N	\N	t	2026-02-03 19:59:33.209583	34709-P
596	1744475581211	Santiago Isidro	García López	Departamento de Investigación de Delitos Contra la Propiedad de Vehículos Automotores Terrestres - DEIC	Agente	36305667	\N	\N	t	2026-02-03 19:59:33.209583	47380-P
597	2157322190101	Karla Gabriela	Méndez Alay	Departamento de Investigación de Delitos Contra la Propiedad de Vehículos Automotores Terrestres - DEIC	Agente	42650434	\N	\N	t	2026-02-03 19:59:33.209583	43153-P
598	2526094840404	Jhonatan Alexander	Icú Quex	Departamento de Investigación de Delitos Contra la Propiedad de Vehículos Automotores Terrestres - DEIC	Agente	34047153	\N	\N	t	2026-02-03 19:59:33.209583	46723-P
599	2084543731019	Esdras Isai	Chay García	Departamento de Investigación de Delitos Contra la Propiedad de Vehículos Automotores Terrestres - DEIC	Agente	52923770	\N	\N	t	2026-02-03 19:59:33.209583	46455-P
600	3428473682206	Edwin David	Flores Ordoñez	Departamento de Investigación de Delitos Contra la Propiedad de Vehículos Automotores Terrestres - DEIC	Agente	48084124	\N	\N	t	2026-02-03 19:59:33.209583	57162-P
601	2642125330101	Durman Diamond	Mich Valiente	Sección de Revisión Fisica	Agente	37979041	\N	\N	t	2026-02-03 19:59:33.209583	46294-P
602	2977379960606	Yicsar Manuel	Domínguez Marroquín	Sección de Revisión Fisica	Agente	53389921	\N	\N	t	2026-02-03 19:59:33.209583	55307-P
603	2111812260101	Luis Enrique	Lima Morales	Sección de Revisión Fisica	Agente	56727014	\N	\N	t	2026-02-03 19:59:33.209583	41277-P
604	3053795420206	Honny Fernando	Esquivel Dávila	Sección de Revisión Fisica	Agente	48557204	\N	\N	t	2026-02-03 19:59:33.209583	64180-P
605	1767878600608	Erick Estuardo	Pérez García	Sección de Revisión Fisica	Agente	55545400	\N	\N	t	2026-02-03 19:59:33.209583	39693-P
606	3301271951201	Roberto Carlos	Molina Gómez	Sección de Revisión Fisica	Agente	50022117	\N	\N	t	2026-02-03 19:59:33.209583	63497-P
607	1944065551909	Odgar Pablo	García Castillo	Sección de Revisión Fisica	Agente	30658984	\N	\N	t	2026-02-03 19:59:33.209583	61151-P
608	1708632711501	José Amilcar	Hernández Bachan	Sección de Revisión Fisica	Agente	36480629	\N	\N	t	2026-02-03 19:59:33.209583	46763-P
609	2058180481609	Fredi Elizardo	Sacul Pop	Sección de Revisión Fisica	Agente	54655048	\N	\N	t	2026-02-03 19:59:33.209583	43614-P
610	1693146851503	Manuel De	Jesús Galeano	Sección de Revisión Fisica	Agente	58642024	\N	\N	t	2026-02-03 19:59:33.209583	30309-P
611	1733460061503	Henry Jerónimo	Abraham Coloch Lajuj	Sección de Revisión Fisica	Agente	50370206	\N	\N	t	2026-02-03 19:59:33.209583	60907-P
612	2297809621601	Walter Leonel	Chén Icó	Sección de Revisión Fisica	Agente	49569781	\N	\N	t	2026-02-03 19:59:33.209583	55719-P
613	1664416860101	Nelson Oswaldo	Morales Pineda	Sección de Revisión Fisica	Agente	36920504	\N	\N	t	2026-02-03 19:59:33.209583	47185-P
614	2553485332101	Mario René	Ruano Salazar	Sección de Revisión Fisica	Agente	55514376	\N	\N	t	2026-02-03 19:59:33.209583	32793-P
615	1838952310801	Miguel Oswaldo	Puac Lastor	Sección de Revisión Fisica	Agente	54146963	\N	\N	t	2026-02-03 19:59:33.209583	26155-P
616	1623988241106	César Adolfo	Agustin Hernández	Sección de Revisión Fisica	Agente	56250923	\N	\N	t	2026-02-03 19:59:33.209583	26906-P
617	1831146981202	Alex Santiago	Monzón Fuentes	Sección de Revisión Fisica	Agente	56976068	\N	\N	t	2026-02-03 19:59:33.209583	39577-P
618	1909024930703	Gaspar David	Chavajay Dionisio	Sección de Revisión Fisica	Agente	55583054	\N	\N	t	2026-02-03 19:59:33.209583	46523-P
619	1986169451211	Ovidio Baldemar	Ovalle Orozco	Sección de Revisión Fisica	Agente	36036348	\N	\N	t	2026-02-03 19:59:33.209583	54011-P
620	1612106512206	Victor Hugo	Quintanilla Hernández	Sección de Revisión Fisica	Agente	50425486	\N	\N	t	2026-02-03 19:59:33.209583	43460-P
621	2457266161413	Mario Sebastian	Rivera Cobo	Departamento de Investigación de Delitos - Delegación Pinula - DEIC	Oficial Tercero	46484146	\N	\N	t	2026-02-03 19:59:33.209583	54088-P
622	1983018041416	Domingo Gomez	Felipe	Departamento de Investigación de Delitos - Delegación Pinula - DEIC	Subinspector	42635863	\N	\N	t	2026-02-03 19:59:33.209583	30383-P
623	1873742282201	Elmer Ernesto	Ordoñez Ramirez	Departamento de Investigación de Delitos - Delegación Pinula - DEIC	Agente	37245115	\N	\N	t	2026-02-03 19:59:33.209583	37766-P
454	1748464602216	Walter Jeovany	Jimenez Barahona	Deic-Mixco	Oficial Primero	30336321	\N	\N	t	2026-02-03 19:59:33.209583	37420-P
624	2180860320414	Carlos Sinac	Padre	Deic-Mixco	Agente	42444066	\N	\N	t	2026-02-03 19:59:33.209583	32852-P
625	2456862660510	Juan Francisco	Garcia Gomez	Deic-Mixco	Agente	47370886	\N	\N	t	2026-02-03 19:59:33.209583	57246-P
626	2129468461503	Norberto Cuxum	Lajuj	Deic-Mixco	Agente	54940764	\N	\N	t	2026-02-03 19:59:33.209583	57768-P
627	2674921540608	Marlon Gabriel	Garcia Moreno	Deic-Mixco	Agente	57159258	\N	\N	t	2026-02-03 19:59:33.209583	49977-P
628	2201637820607	Gresy Abigail	Gomez Interiano	Deic-Mixco	Agente	54254118	\N	\N	t	2026-02-03 19:59:33.209583	50015-P
629	2909287101416	Oscar Leonel	Mejia Lopez	Deic-Mixco	Agente	50191363	\N	\N	t	2026-02-03 19:59:33.209583	63480-P
631	3422289942201	Marlon Eberardo	Hernandez Mendez	Deic-Mixco	Agente	42243922	\N	\N	t	2026-02-03 19:59:33.209583	59188-P
632	2074987761203	Ottoniel Nicolas	Cardona Carreto	Deic-Villa Nueva	Agente	30359695	\N	\N	t	2026-02-03 19:59:33.209583	36868-P
633	1686851080101	Mario Eriberto	Aguilar De Leon	Deic-Villa Nueva	Agente	54405163	\N	\N	t	2026-02-03 19:59:33.209583	31909-P
634	1943377582207	Milver Alexander	Rivas Marroquin	Deic-Villa Nueva	Agente	56348697	\N	\N	t	2026-02-03 19:59:33.209583	34836-P
635	2225232552202	Marvin Manuel	Lopez Olivares	Deic-Villa Nueva	Agente	37674108	\N	\N	t	2026-02-03 19:59:33.209583	39442-P
419	2069911180402	Samuel Cuxil	Tubac	Deic-Villa Nueva	Agente	30233864	\N	\N	t	2026-02-03 19:59:33.209583	39032-P
636	3429154362207	Alexander Anibal	Vasquez Escarate	Deic-Villa Nueva	Agente	40924373	\N	\N	t	2026-02-03 19:59:33.209583	65172-P
637	2184419751712	Juana Maria	Magdalena Xoj Caal	Deic-Alta Verapaz	Agente	46290868	\N	\N	t	2026-02-03 19:59:33.209583	50901-P
638	2615728061609	Jose Manuel	Pana Itz	Deic-Alta Verapaz	Agente	56699410	\N	\N	t	2026-02-03 19:59:33.209583	58919-P
639	1620487262207	Cesar Augusto	Corado	Deic-Chiquimula	Agente	54262821	\N	\N	t	2026-02-03 19:59:33.209583	44780-P
640	3423783172201	Wilson Omar	Cardona Salguero	Deic-Chiquimula	Agente	33216264	\N	\N	t	2026-02-03 19:59:33.209583	56814-P
641	1721089341705	William Estuardo	Arana Flores	Deic-Izabal	Agente	45202789	\N	\N	t	2026-02-03 19:59:33.209583	33186-P
642	2778557801603	Rudy Mateo	Cal Lem	Deic-Izabal	Agente	45970738	\N	\N	t	2026-02-03 19:59:33.209583	65432-P
643	2362587611607	Rolando Choc	Chun	Deic-Izabal	Agente	58700114	\N	\N	t	2026-02-03 19:59:33.209583	40731-P
644	1834968921202	Aurelio Eli	Gabriel Fuentes	Deic-Quetzaltenango	Agente	56283214	\N	\N	t	2026-02-03 19:59:33.209583	37177-P
645	3237760431002	Kevinson Donaldo	de Jesus	Deic-Quetzaltenango	Agente	58279900	\N	\N	t	2026-02-03 19:59:33.209583	59113-P
646	3137402161410	Oliver Lorenzo	Perez Rodriguez	Deic-Quetzaltenango	Agente	39790075	\N	\N	t	2026-02-03 19:59:33.209583	63573-P
647	2344773931202	Kenett Renan	De Leon Tul	Deic-Quetzaltenango	Agente	30568213	\N	\N	t	2026-02-03 19:59:33.209583	57065-P
648	2432590340919	Wilmar Gudiel	Alvarado Tumaca	Deic-Retalhuleu	Agente	52060524	\N	\N	t	2026-02-03 19:59:33.209583	58650-P
649	1834957440101	Elmer Javier	Brisuela Cifuentes	Deic-Retalhuleu	Agente	41927553	\N	\N	t	2026-02-03 19:59:33.209583	36806-P
650	2507162671108	Suria Sucely Ciefuentes	Calderon De Calderon	Deic-Retalhuleu	Agente	50164651	\N	\N	t	2026-02-03 19:59:33.209583	47443-P
651	16392708811107	Lester Enrique	Tumin Lopez	Deic-Retalhuleu	Agente	51714441	\N	\N	t	2026-02-03 19:59:33.209583	31043-P
652	1965932120610	Rito Esteban	Santos Cruz	Deic-Santa Rosa	Suibnspector	30207448	\N	\N	t	2026-02-03 19:59:33.209583	34947-P
653	3093913930610	Abener Geobany	Gonzalez Urias	Deic-Santa Rosa	Agente	34037501	\N	\N	t	2026-02-03 19:59:33.209583	64370-P
654	1610905320402	Juan Manuel	Telon sanic	Deic-Solola	Agente	50182361	\N	\N	t	2026-02-03 19:59:33.209583	26630-P
655	1994480001108	Wagner Francisco	Gomez Vasquez	Deic-Suchitepequez	Agente	49092971	\N	\N	t	2026-02-03 19:59:33.209583	41073-P
656	2066191701001	Telvi Nohelia	Castro Garcia	Deic-Suchitepequez	Agente	59403291	\N	\N	t	2026-02-03 19:59:33.209583	49698-P
657	2881422760919	Angela Alejandra	De Leon Sontay	Deic-Suchitepequez	Agente	42278751	\N	\N	t	2026-02-03 19:59:33.209583	67562-P
658	1960842371219	Jose Luis	Garcia Sandoval	Deic-Totonicapan	Agente	30034889	\N	\N	t	2026-02-03 19:59:33.209583	27377-P
209	2658455050917	Jaime Neftali	Macha Guzman	Deic-Huehuetenango	Suibnspector	57274825	\N	\N	t	2026-02-03 19:59:33.209583	41372-P
659	2111751881229	Edilsar Manuel	Perez Rabanales	Jefatura Adjunta Delegaciones DEIC	Suibnspector	30062984	\N	\N	t	2026-02-03 19:59:33.209583	43388-P
413	1707529331001	Rudy Alfredo	Sopon Nolasco	Jefatura Adjunta Delegaciones DEIC	Agente	41388732	\N	\N	t	2026-02-03 19:59:33.209583	32866-P
151	2194212851009	Francisco Javier	Ixquiatap García	Unidad Especial de Investigación - UEI - SGIC	Agente	31286300	\N	\N	t	2026-02-03 19:59:33.209583	44133-P
457	2043793770203	Walter Saúl	Gonzalez Archila	Unidad Especial de Investigación - UEI - SGIC	Agente	30363844	\N	\N	t	2026-02-03 19:59:33.209583	41084-P
660	2172860461102	Omar Acevedo	Ixcoy	Unidad Especial de Investigación - UEI - SGIC	Agente	37626226	\N	\N	t	2026-02-03 19:59:33.209583	40419-P
661	2356914882214	Elmer Leonel	Lopez Rodriguez	Unidad Especial de Investigación - UEI - SGIC	Oficial Tercero	51206506	\N	\N	t	2026-02-03 19:59:33.209583	28791-P
140	1785212641301	Esvin Rosanio	Hernández López	Unidad Especial de Investigación - UEI - SGIC	Agente	30364555	\N	\N	t	2026-02-03 19:59:33.209583	27285-P
662	0221295488153	Fredy Estuardo	Cahuec Mendoza	Unidad Especial de Investigación - UEI - SGIC	Agente	30739381	\N	\N	t	2026-02-03 19:59:33.209583	31259-P
257	2513080650501	Josue Elias	Reynoso Pecheco	Deic-Suchitepequez	Oficial Primero	30142365	\N	\N	t	2026-02-03 19:59:33.209583	26848-P
502	1999437371606	Juan Pablo	Xol Ichich	Deic-Alta Verapaz	Oficial Primero	30614251	\N	\N	t	2026-02-03 19:59:33.209583	27032-P
232	1914489902201	Jorge Alexander	Lopez Aldana	Departamento de Investigación de Delitos Patrimoniales - DEIC - SGIC -	Oficial Segundo	48137422	\N	\N	t	2026-02-03 19:59:33.209583	22778-P
272	1706601841603	Julio César	Yoj Catalán	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Oficial Tercero	53191055	\N	\N	t	2026-02-03 19:59:33.209583	52598-P
94	2063616101301	Dulce Luz de	María Analy Hernandez Villatoro	Deic-Totonicapan	Oficial Tercero	30156359	\N	\N	t	2026-02-03 19:59:33.209583	41191-P
452	1873456940608	Walter Alberto	Moto Morataya	Departamento de Investigación de Delitos Contra la Propiedad de Vehículos Automotores Terrestres - DEIC	Inspector	30302664	\N	\N	t	2026-02-03 19:59:33.209583	26075-P
663	2304200520101	Mario David	Martínez de Leon	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Inspector	30439009	\N	\N	t	2026-02-03 19:59:33.209583	28826-P
664	1887416660920	Suliana Maday	Lepe Orozco	DIVISION ESPECIALIZADA EN INVESTIGACION CRIMINAL-DEIC	Inspector	30207448	\N	\N	t	2026-02-03 19:59:33.209583	39387-P
116	2101120341613	Efrain Che	Xo	Deic-Alta Verapaz	Agente	44847278	\N	\N	t	2026-02-03 19:59:33.209583	46369-P
252	1740567961503	José Nicael	Alvarado Pérez	Jefatura Adjunta de Departamentos y Delegaciones Especiales de Investigación - DEIC -	Agente	54873080	\N	\N	t	2026-02-03 19:59:33.209583	35401-P
665	1657217580101	Luis Alberto	Canastuj Catun	Jefatura Adjunta de Departamentos y Delegaciones Especiales de Investigación - DEIC -	Agente	43437189	\N	\N	t	2026-02-03 19:59:33.209583	36859-P
463	2130856740101	Wendy Yanira	Molina Lima	Departamento de Investigación de Delitos Patrimoniales - DEIC - SGIC -	Agente	42582679	\N	\N	t	2026-02-03 19:59:33.209583	54822-P
371	2336670321109	Oralia Josefina	Ramirez Torres	Departamento de Investigación de Delitos Contra la Propiedad de Vehículos Automotores Terrestres - DEIC	Agente	55578112	\N	\N	t	2026-02-03 19:59:33.209583	29712-P
362	2122832780805	Nelson Eleodoro	Sontay Perez	Departamento de Investigación de Delitos Contra la Propiedad de Vehículos Automotores Terrestres - DEIC	Agente	47223443	\N	\N	t	2026-02-03 19:59:33.209583	41878-P
666	2072518192213	Silverio Cruz	Lázaro	Departamento de Investigación de Delitos Contra la Propiedad de Vehículos Automotores Terrestres - DEIC	Agente	41068744	\N	\N	t	2026-02-03 19:59:33.209583	44816-P
8	2050972431606	Alan Maximo Estuardo	de la Cruz Choc	DEIC - Jalapa	Agente	34709274	\N	\N	t	2026-02-03 19:59:33.209583	42542-P
667	2847715381501	Beverly Escarleth	Orrego Gonzalez	DIVISION ESPECIALIZADA EN INVESTIGACION CRIMINAL-DEIC	Agente	58383913	\N	\N	t	2026-02-03 19:59:33.209583	57891-P
668	2875215241101	Dany Ronald Perez	de la Cruz	DIVISION ESPECIALIZADA EN INVESTIGACION CRIMINAL-DEIC	Agente	56292275	\N	\N	t	2026-02-03 19:59:33.209583	64820-P
669	2488708820101	Lauro Alberto	Guacamaya Interiano	DIVISION ESPECIALIZADA EN INVESTIGACION CRIMINAL-DEIC	Agente	41513977	\N	\N	t	2026-02-03 19:59:33.209583	39262-P
670	1964698051008	Jorge Doroteo	Solval García	DIVISION ESPECIALIZADA EN INVESTIGACION CRIMINAL-DEIC	Agente	48326846	\N	\N	t	2026-02-03 19:59:33.209583	29768-P
671	2537231751020	Marta Izabel	Mas Zepeda	Deic-Solola	Oficial Tercero	30362003	\N	\N	t	2026-02-03 19:59:33.209583	20898-P
672	2735114082210	Jonathan Josue	Revolorio Linares	Deic-DIDFE	Oficial Tercero	42988631	\N	\N	t	2026-02-03 19:59:33.209583	50640-P
673	2228087802009	Juan Francisco	Perez Mejia	Deic-Alta Verapaz	Agente	35694881	\N	\N	t	2026-02-03 19:59:33.209583	43383-P
674	3260138731602	Alexander Wenceslao	Jalal Caal	Deic-Alta Verapaz	Agente	35704150	\N	\N	t	2026-02-03 19:59:33.209583	65992-P
675	1985437781211	Jose Manuel	Chavez Feliciano	Deic-Solola	Agente	40298125	\N	\N	t	2026-02-03 19:59:33.209583	38919-P
676	2568128021008	Claudia Janeth	Avila Xum	Deic-DIDFE	Agente	56989463	\N	\N	t	2026-02-03 19:59:33.209583	38755-P
584	2598028750803	Kimberly Yessenia	Magaly Oxlaj Pérez	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación de Delitos Financieros y Económicos	Agente	56329901	\N	\N	t	2026-02-03 19:59:33.209583	61699-P
677	1922440431101	Carlos Anibal	Ixcolin Escobar	Deic-Delitos Sexuales	Agente	37084282	\N	\N	t	2026-02-03 19:59:33.209583	48759-P
678	2994091200101	Jaqueline Rocio	Quinilla Boteo	Deic-Delitos Sexuales	Agente	51214248	\N	\N	t	2026-02-03 19:59:33.209583	66486-P
194	2373622521203	Hilda Nohemi	Estrada Orozco	DIP-SGIC	Agente	36219115	\N	\N	t	2026-02-03 19:59:33.209583	28535-P
679	3492290821203	Julio Cesar	Culajay Colaj	DIP-SGIC	Agente	51199315	\N	\N	t	2026-02-03 19:59:33.209583	57044-P
15	2653427590101	Alfredo Isai	Barrios de León	DIP-SGIC	Agente	51339315	\N	\N	t	2026-02-03 19:59:33.209583	46022-P
43	1857508501709	Benedicto Efraín	Chub Coc	DIP-SGIC	Agente	30433892	\N	\N	t	2026-02-03 19:59:33.209583	42460-P
680	1631730442201	Mario Guerrero	Ordoñez	SGAIA-PNC	Oficial Tercero	39922286	\N	\N	t	2026-02-03 19:59:33.209583	31438-P
681	3013249210101	Jeyson Antonio	Mayen Salazar	SGAIA-PNC	Agente	57386075	\N	\N	t	2026-02-03 19:59:33.209583	64637-P
682	2984793890203	Lorena Magali	Perez Contreras	SGAIA-PNC	Agente	32694503	\N	\N	t	2026-02-03 19:59:33.209583	61755-P
683	2782753621108	Edgar Arnoldo	Calderon De Leon	Seccion de Registro y Control de Ordenes de Aprehension-DEIC-SGIC	Agente	31442148	\N	\N	t	2026-02-03 19:59:33.209583	63898-P
143	3305140831202	Evilio Gregorio	Velasquez Castañon	Seccion de Registro y Control de Ordenes de Aprehension-DEIC-SGIC	Agente	48943665	\N	\N	t	2026-02-03 19:59:33.209583	65189-P
684	2852429381011	Miguel Francisco	Sunún Quiñonez	SAFE-SGIC	Agente	39498970	\N	\N	t	2026-02-03 19:59:33.209583	71664-P
358	1739976191909	Nancy Lourdes	Súchite Asmén	Interpol-DEIC-SGIC	Agente	37796127	\N	\N	t	2026-02-03 19:59:33.209583	47168-P
685	2399922962201	Douglas Rolando	Osorio Meda	Interpol-DEIC-SGIC	Agente	47247355	\N	\N	t	2026-02-03 19:59:33.209583	45486-P
686	2659871802201	Manuel de	Jesus Ortega Mencos	Interpol-DEIC-SGIC	Agente	44843981	\N	\N	t	2026-02-03 19:59:33.209583	45475-P
687	2091989580611	Geidy Nohemi	Peralta Salazar	Interpol-DEIC-SGIC	Agente	57172653	\N	\N	t	2026-02-03 19:59:33.209583	41571-P
378	2593378111229	Ovidio Estanislao	Perez Rabanales	División de Policía Internacional	Oficial Primero	39296021	\N	\N	t	2026-02-03 19:59:33.209583	15696-P
374	1902450421610	Osman Eduardo	Putul Hidalgo	División de Policía Internacional	Suibnspector	40827753	\N	\N	t	2026-02-03 19:59:33.209583	37946-P
75	2778414531503	Cristian Alfredo	Toj Lopez	División de Policía Internacional	Agente	30607052	\N	\N	t	2026-02-03 19:59:33.209583	65124-P
405	2248738650412	Roni Alexander	Alvarado Matzir	División de Policía Internacional	Agente	54876128	\N	\N	t	2026-02-03 19:59:33.209583	44525-P
335	2311274560101	Mayra Elizabeth	Gamez Recinos	División de Policía Internacional	Agente	56165618	\N	\N	t	2026-02-03 19:59:33.209583	19744-P
390	2108013601219	Renffery Americo	Lopez Ramirez	División de Policía Internacional	Agente	51879540	\N	\N	t	2026-02-03 19:59:33.209583	43032-P
117	1924222512010	Efrain Perez	Cruz	División de Policía Internacional	Agente	53700746	\N	\N	t	2026-02-03 19:59:33.209583	43358-P
465	2164959110608	Wilber Alfonso	Vasquez Gonzalez	División de Policía Internacional	Agente	58040733	\N	\N	t	2026-02-03 19:59:33.209583	45870-P
138	3420602522201	Estiwar Josue	Mendez Esquivel	División de Policía Internacional	Agente	51908512	\N	\N	t	2026-02-03 19:59:33.209583	62816-P
229	2911265102209	Jonathan Alexis	Arana Corado	División de Policía Internacional	Agente	40765487	\N	\N	t	2026-02-03 19:59:33.209583	63783-P
289	2997699091401	Kleysser Benedicto	Reyes Ruiz	División de Policía Internacional	Agente	40713139	\N	\N	t	2026-02-03 19:59:33.209583	63611-P
688	0230827055019	Camila Marie	Mus Figueroa	Digicri	Directora de Investigaciones Especializadas	41492991	\N	\N	t	2026-02-03 19:59:33.209583	\N
432	2162761601008	Sergio Geovany	Xum Tunay	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	54104734	\N	\N	t	2026-02-03 19:59:33.209583	42013-P
689	1848679750101	Carlos Alberto	Bocaletti Herrarte	Solicitado por el oficial Tercero Chelo-CRADIC	\N	39937989	\N	\N	t	2026-02-03 19:59:33.209583	\N
690	2396964922102	Oscar Rene	Ochoa Mateo	Seguridad Interna, Inspectoria General MINGOB	Oficial Primero	37302714	\N	\N	t	2026-02-03 19:59:33.209583	26093-P
459	2711934841207	Wander Humberto	Morales Perez	Division de Informacion Policial-DIP	Agente	48414037	\N	\N	t	2026-02-03 19:59:33.209583	61600-P
447	1836264780904	Veronica Danuvia	Vicente Vasquez	División de Información Policial	Agente	42119279	\N	\N	t	2026-02-03 19:59:33.209583	32960-P
187	2354592671901	Henry Otoniel	Ac Quiroa	SGAIA-PNC	Oficial Primero	35673868	\N	\N	t	2026-02-03 19:59:33.209583	27676-P
79	3423628282201	Daniel Adolfo	Rodriguez Florian	SGAIA-PNC	Agente	47145799	\N	\N	t	2026-02-03 19:59:33.209583	63025-P
298	2059343820606	Luis Alberto	Ruano Cardona	SGAIA-PNC	Agente	43182359	\N	\N	t	2026-02-03 19:59:33.209583	63038-P
691	1666824112210	Hugo Manuel	Godoy Corado	Dimei	Agente	40015946	\N	\N	t	2026-02-03 19:59:33.209583	25849-P
103	1653117890406	Edgar Rolando	Pac Jiatz	Didae	Inspector	45763268	\N	\N	t	2026-02-03 19:59:33.209583	32611-P
692	1891528500602	Jose Manuel	Betancourt Rodriguez	Didae	Subinspector	30389421	\N	\N	t	2026-02-03 19:59:33.209583	38791-P
485	2089866341227	Yurving Geymer	López de León	Didae	Agente	59558819	\N	\N	t	2026-02-03 19:59:33.209583	39410-P
130	2085753172216	Erick Orlando	Pineda Castillo	Didae	Agente	54318093	\N	\N	t	2026-02-03 19:59:33.209583	41631-P
442	1782912262103	Sonia Yanileth	Mateo Yaque	Didae	Agente	56265265	\N	\N	t	2026-02-03 19:59:33.209583	37611-P
693	1761380642201	Edwin Rafael	Polanco Castro	Didae	Agente	36940038	\N	\N	t	2026-02-03 19:59:33.209583	43432-P
153	1732450481108	Frandy Adbeel	Castañeda Lopez	Didae	Agente	50128158	\N	\N	t	2026-02-03 19:59:33.209583	43999-P
694	0268904450101	Pablo Steben	Corado Luis	Didae	Agente	56170923	\N	\N	t	2026-02-03 19:59:33.209583	48426-P
695	1692030180101	Juan Francisco	Sequen Figueroa	DEIC	Subcomisario	30372980	\N	\N	t	2026-02-03 19:59:33.209583	15022-P
696	1794157191901	Jonny Lester	Escalante Morales	DEIC	Inspector	50194065	\N	\N	t	2026-02-03 19:59:33.209583	19335-P
697	2541629400101	Enio Adonahi	Donis Bolaños	DEIC	Subinspector	36216570	\N	\N	t	2026-02-03 19:59:33.209583	32191-P
698	1891400101008	Eduardo Benjamin	Chay Panjoj	DEIC	Subinspector	36216570	\N	\N	t	2026-02-03 19:59:33.209583	38928-P
699	2429186970101	Carlos Ulises	Castro	DEIC	Subinspector	45033899	\N	\N	t	2026-02-03 19:59:33.209583	28394-P
700	2425412080101	Joseline Stefani	Carias Tuche	DEIC	Agente	54523343	\N	\N	t	2026-02-03 19:59:33.209583	63911-P
701	1630237352210	Marvin Arnoldo	Corado Arana	DEIC	Agente	55780589	\N	\N	t	2026-02-03 19:59:33.209583	40767-P
702	2672054141008	Juan Carlos	Solval Garcia	DEIC	Agente	59046624	\N	\N	t	2026-02-03 19:59:33.209583	32861-P
703	1613935780101	Iveth Beatriz	Alvarez Muralles	DEIC	Agente	42623955	\N	\N	t	2026-02-03 19:59:33.209583	38717-P
704	3286802731101	Estefany Sarai	Citalan Ixcoy	DEIC	Agente	55013578	\N	\N	t	2026-02-03 19:59:33.209583	65583-P
705	2888418751202	Lusvin Eliverio	Lopez Fuentes	DEIC	Agente	30228849	\N	\N	t	2026-02-03 19:59:33.209583	64523-P
706	2137148922206	Yunior Getzabel	Asencio Corado	DEIC	Agente	55177493	\N	\N	t	2026-02-03 19:59:33.209583	52875-P
707	1793334450613	Abdin Eleno	Choché Rosales	DEIC	Agente	53187050	\N	\N	t	2026-02-03 19:59:33.209583	32100-P
708	1767806290404	Wuiny Dinael	Sen Cuxil	DEIC	Agente	30471738	\N	\N	t	2026-02-03 19:59:33.209583	38191-P
709	2732148530610	Luis Anival	Gonzalez Reynosa	DEIC	Agente	42995913	\N	\N	t	2026-02-03 19:59:33.209583	59137-P
710	2188990682101	Florencio Agustin	Andres	DEIC	Agente	30088477	\N	\N	t	2026-02-03 19:59:33.209583	40448-P
711	2067715762214	Rosalba Amarilis	Arevalo Alvarez	DEIC	Agente	48064931	\N	\N	t	2026-02-03 19:59:33.209583	36714-P
712	3466662440203	Diego Alexander	Garcia Escobar	DEIC	Agente	48634156	\N	\N	t	2026-02-03 19:59:33.209583	59042-P
714	1999068661101	Alex Wilfredo	Mateo Esteban	DEIC	Agente	42278751	\N	\N	t	2026-02-03 19:59:33.209583	36083-P
715	3314364504802	Luis Fernando	Siquic Pop	DEIC	Agente	46858752	\N	\N	t	2026-02-03 19:59:33.209583	66689-P
716	2967042962201	Nelson Vidal	Florian Mendez	DEIC	Agente	58531383	\N	\N	t	2026-02-03 19:59:33.209583	57164-P
717	3053772990206	Sergio Antonio	Barrientos Castañeda	DEIC	Agente	47056771	\N	\N	t	2026-02-03 19:59:33.209583	58715-P
718	3389819421001	Blanca Damaris	Gomez Herrera	DEIC	Agente	59641366	\N	\N	t	2026-02-03 19:59:33.209583	57300-P
630	1591725860610	Luis Arturo	Lorenzana Santos	DEIC	Agente	54348846	\N	\N	t	2026-02-03 19:59:33.209583	43058-P
719	1784461501501	Lilian Marilis	Bolvito Galeano	DEIC	Agente	32208335	\N	\N	t	2026-02-03 19:59:33.209583	36796-P
720	2093736281601	Jaime Francisco	Clemente Ical Fernandez	DEIC	Agente	53709674	\N	\N	t	2026-02-03 19:59:33.209583	53490-P
721	2460557742201	Helen Nineth	Cordero y Cordero	DEIC	Agente	54101756	\N	\N	t	2026-02-03 19:59:33.209583	52656-P
722	1901274810101	Marlon Francisco	García Flores	DIGICRI	Subdirector	30320184	\N	\N	t	2026-02-03 19:59:33.209583	\N
316	2162448702214	Maria Angelica	Martir Ozuna	DEIC - Mixco	Oficial Tercero	30168552	\N	\N	t	2026-02-03 19:59:33.209583	50308-P
723	1761012091503	Leonel Coloch	Tecú	Baja Verapaz	Inspector	30147369	\N	\N	t	2026-02-03 19:59:33.209583	19632-P
294	1589071320404	Llym Gustavo	Lara Hernandez	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación Contra el Delito de Femicidio	Subinspector	30354272	\N	\N	t	2026-02-03 19:59:33.209583	41257-P
162	2316889701508	Gerardo Chocol	Ichich	DEIC - PETEN	Agente	49617289	\N	\N	t	2026-02-03 19:59:33.209583	55736-P
270	1675470031603	Julio Armando	Laj Moran	DEIC - PETEN	Agente	50485346	\N	\N	t	2026-02-03 19:59:33.209583	42934-P
290	2721743510101	Lucero Estefany	Verónica Matías Pérez	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación Contra el Delito de Femicidio	Agente	30324890	\N	\N	t	2026-02-03 19:59:33.209583	54795-P
258	2339135992214	Jova de	Jesús Gutierrez Alvarez	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación Contra el Delito de Femicidio	Agente	37043825	\N	\N	t	2026-02-03 19:59:33.209583	52712-P
154	1627733072101	Fredy Armando	Jiménez y Jiménez	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación Contra el Delito de Femicidio	Agente	30115723	\N	\N	t	2026-02-03 19:59:33.209583	29572-P
330	2825796050404	Marlon Yovani	Alexander Chipix Sotz	Sección Contra la Trata de Personas -DEIC-	Agente	58692862	\N	\N	t	2026-02-03 19:59:33.209583	65562-P
426	2806779871503	Selvin Engelbert	Depaz Cornelio	Sección Contra la Trata de Personas -DEIC-	Agente	47693102	\N	\N	t	2026-02-03 19:59:33.209583	64138-P
322	2776299931606	Mariano Chub	Pec	Sección Contra la Trata de Personas -DEIC-	Agente	35719917	\N	\N	t	2026-02-03 19:59:33.209583	65575-P
340	2833518531502	Melvin Morente	Sique	Sección Contra la Trata de Personas -DEIC-	Agente	35692259	\N	\N	t	2026-02-03 19:59:33.209583	61628-P
74	1803377420301	Crisol Esterli	Velasquez Albizurez	Sección Contra la Trata de Personas -DEIC-	Agente	51395117	\N	\N	t	2026-02-03 19:59:33.209583	40090-P
364	2977823201508	Nery Estuardo	Cao Co	Sección Contra la Trata de Personas -DEIC-	Agente	47827258	\N	\N	t	2026-02-03 19:59:33.209583	67238-P
366	1761327591210	Nesvi José	Ramírez	Departamento de Investigación de Delitos - Delegación Quetzaltenango - DEIC	Agente	31702546	\N	\N	t	2026-02-03 19:59:33.209583	52423-P
420	2347437350919	Samuel de	Jesus Itzep Ramirez	Deic-Suchitepequez	Agente	34027569	\N	\N	t	2026-02-03 19:59:33.209583	41213-P
305	1800179342201	Luis Enrique	Ortega Monzon	DEIC - Chiquimulilla	Agente	33620722	\N	\N	t	2026-02-03 19:59:33.209583	28946-P
355	1917156620101	Mychel Leonel	Catalan Vallejos	Deic-Solola	Agente	51239262	\N	\N	t	2026-02-03 19:59:33.209583	35545-P
314	2287199170411	Manuel Marroquín	Pérez	Departamento de Investigación de Delitos - Delegación Sacatepéquez - DEIC	Agente	55979616	\N	\N	t	2026-02-03 19:59:33.209583	52287-P
156	3272299501019	Fredy Jose	Ruiz Lopez	Departamento de Investigación de Delitos - Delegación Escuintla - DEIC	Agente	41195616	\N	\N	t	2026-02-03 19:59:33.209583	69010-P
25	1921133211012	Angel Gregorio	López Mis	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación Contra el Delito de Femicidio	Agente	59202487	\N	\N	t	2026-02-03 19:59:33.209583	56239-P
468	2623279960608	Wilian Osvaldo	Domínguez Vega	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación Contra el Delito de Femicidio	Agente	55832028	\N	\N	t	2026-02-03 19:59:33.209583	25784-P
253	2393693511504	José Oswaldo	Pérez Morente	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación Contra el Delito de Femicidio	Agente	57393056	\N	\N	t	2026-02-03 19:59:33.209583	59582-P
142	2134389761107	Ever Alexander	Barrientos Guzmán	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación Contra el Delito de Femicidio	Agente	30796422	\N	\N	t	2026-02-03 19:59:33.209583	58713-P
295	1828141732214	Lorinmer González	Menéndez	Departamento de Investigación de Delitos - DEIC - Departamento de Investigación Contra el Delito de Femicidio	Agente	30485539	\N	\N	t	2026-02-03 19:59:33.209583	33905-P
392	1733316372207	Richard Mike	Vasquez Escobar	DEIC - El Progreso	Agente	58461049	\N	\N	t	2026-02-03 19:59:33.209583	35128-P
724	2843304181502	Fredy Ottoniel	Reyes Xitumul	Seccion Tráfico de Personas	Agente	39794684	\N	\N	t	2026-02-03 19:59:33.209583	61933-P
725	2172445991804	Luis Armando	Paredes Vargas	Seccion Tráfico de Personas	Agente	42204311	\N	\N	t	2026-02-03 19:59:33.209583	57936-P
726	2749175641602	Edin José	Domingo Jor Max	Seccion Tráfico de Personas	Agente	47384169	\N	\N	t	2026-02-03 19:59:33.209583	61332-P
727	1649485541503	Noé Eduardo	Chen Siana	Seccion Tráfico de Personas	Agente	50520449	\N	\N	t	2026-02-03 19:59:33.209583	35566-P
728	1929640111214	Luis Guillermo	Aguilar Chilel	Departamento de Investigación de Delitos Contra la Vida - DEIC - SGIC	Agente	37925137	\N	\N	t	2026-02-03 19:59:33.209583	44474-P
124	1670396950101	Emerson Jorge	Ricardo Rosales Lopez	DEPARTAMENTO DE OPERACIONES-DEIC-SGIC	Oficial Primero	30284706	\N	\N	t	2026-02-03 19:59:33.209583	23988-P
14	1701611020405	Alexander Tubac	Sajbochol	Departamento de Operaciones-ST-SGIC	Oficial Tercero	33723095	\N	\N	t	2026-02-03 19:59:33.209583	35072-P
259	2682909380101	Juan Andeli	Ruiz Vasquez	DEPARTAMENTO DE OPERACIONES-DEIC-SGIC	Oficial Tercero	54758266	\N	\N	t	2026-02-03 19:59:33.209583	32798-P
729	2096801720314	Luis Alberto	Chavac Petcera	Departamento de Operaciones-ST-SGIC	Subinspector	48047934	\N	\N	t	2026-02-03 19:59:33.209583	54512-P
174	1729601181212	Hanea Raquel	Gonzalez Gomez	Departamento de Operaciones-ST-SGIC	Agente	57460256	\N	\N	t	2026-02-03 19:59:33.209583	39241-P
484	1979497700603	Yuri González	Barillas	Departamento de Operaciones-ST-SGIC	Agente	41382045	\N	\N	t	2026-02-03 19:59:33.209583	30403-P
169	2351799062211	Glendy Maricela	Ramirez Castillo	Departamento de Operaciones-ST-SGIC	Agente	38681396	\N	\N	t	2026-02-03 19:59:33.209583	50592-P
219	3051394950201	Jersson Gudiel	Orellana Aquino	Departamento de Operaciones-ST-SGIC	Agente	56342941	\N	\N	t	2026-02-03 19:59:33.209583	68585-P
87	3085541830404	Denzel Zidane	Roquel Chex	DEPARTAMENTO DE OPERACIONES-DEIC-SGIC	Agente	59204782	\N	\N	t	2026-02-03 19:59:33.209583	68986-P
227	2860195661202	Johnny Estuardo	Fuentes Pérez	DEPARTAMENTO DE OPERACIONES-DEIC-SGIC	Agente	48914009	\N	\N	t	2026-02-03 19:59:33.209583	67676-P
357	2986974830101	Mynor Eduardo	Valladares López	Departamento de Operaciones-ST-SGIC	Agente	58763799	\N	\N	t	2026-02-03 19:59:33.209583	69260-P
730	2720373542206	Gustavo Adolfo	Arana Bernal	DEPARTAMENTO DE OPERACIONES-DEIC-SGIC	Agente	38488259	\N	\N	t	2026-02-03 19:59:33.209583	52865-P
394	3315914721204	Roberto Carlos	Tomas Lopez	DEPARTAMENTO DE OPERACIONES-DEIC-SGIC	Agente	46588055	\N	\N	t	2026-02-03 19:59:33.209583	66729-P
7	3164055581503	Alan ciriaco	Perdomo Lajuj	Departamento de Operaciones-ST-SGIC	Agente	32885269	\N	\N	t	2026-02-03 19:59:33.209583	68669-P
731	3424910082201	Smaylin Nineth	López Godoy	Departamento de Operaciones-ST-SGIC	Agente	57026838	\N	\N	t	2026-02-03 19:59:33.209583	70817-P
319	3746515581211	Maria Fernanda	Sanchez Ramirez	Departamento de Operaciones-ST-SGIC	Agente	48893359	\N	\N	t	2026-02-03 19:59:33.209583	69068-P
732	3422576412201	Telma Lucrecia	Ramirez Vega	Departamento de Operaciones-ST-SGIC	Agente	31394596	\N	\N	t	2026-02-03 19:59:33.209583	71436-P
733	1945209350718	Juan Israél	Sequec Navichoc	Departamento de Operaciones-ST-SGIC	Agente	54580811	\N	\N	t	2026-02-03 19:59:33.209583	43680-P
734	2314407231008	David Salomon	Lopez Hernández	SGIC-DEPARTAMENTO DE TECNOLOGIA	Inspector	30498961	\N	\N	t	2026-02-03 19:59:33.209583	22789-P
126	1971674892207	Enrique Alberto	Tenas Portillo	DIDAE	Inspector	30498961	\N	\N	t	2026-02-03 19:59:33.209583	26288-P
113	3422465262201	Edy Adonay	Corado Ramos	DEIC CHIMALTENANGO	Oficial Tercero	35750876	\N	\N	t	2026-02-03 19:59:33.209583	55282-P
735	2375920961405	Gaspar Marcelino	Rivera Zuñiga	JEFATURA DEIC  COATEPEQUE	Oficial Segundo	30165525	\N	\N	t	2026-02-03 19:59:33.209583	12423-P
132	2376505331109	ERNESTO ORLANDO	IXCOT JUAREZ	JEFATURA DEIC	Oficial Tercero	42124223	\N	\N	t	2026-02-03 19:59:33.209583	29562-P
736	2976794300718	Luis Valeriano	Navichoc Gonzalez	DIPANDA - DEIC	Agente	59595674	\N	\N	t	2026-02-03 19:59:33.209583	63513-P
737	2577009431703	Elieser Lemuel	Ac Cordova	ORIP - DIP	Sub Inspector	30483165	\N	\N	t	2026-02-03 19:59:33.209583	13951-P
352	1861161441202	MIQUEAS JONATAN	JUAREZ SANTOS	DEPTO. CONTRA SECUESTROS	Sub Inspector	30387527	\N	\N	t	2026-02-03 19:59:33.209583	37440-P
349	2083500981502	MILTON ESTUARDO	HERNANDEZ REYES	DEPTO. CONTRA SECUESTROS	Sub Inspector	30428181	\N	\N	t	2026-02-03 19:59:33.209583	41182-P
482	2163622021006	Yorvi Otoniel	Cotij Bercian	seccion de vehiculos	Agente	30343888	\N	\N	t	2026-02-03 19:59:33.209583	40793-P
167	2374107021502	Glenda Daniela	González González	JEFATURA DEIC	Sub Inspector	41496333	\N	\N	t	2026-02-03 19:59:33.209583	41096-P
456	1673689231503	Armando Garcia	Ruiz	DEIC - ZACAPA	Agente	49595411	\N	\N	t	2026-02-03 19:59:33.209583	32629-P
429	3437758911201	Sergio Arnoldo	Gomez Godinez	DEIC - TOTONICAPAN	Agente	31249471	\N	\N	t	2026-02-03 19:59:33.209583	63333-P
6	1574633111503	AGUSTO SOLANO	TOJ IXPATA	DEIC	Agente	58406158	\N	\N	t	2026-02-03 19:59:33.209583	31749-P
500	2419094301101	Mario Domingo	Cux Puac	DEPTO CONTRA SECUESTROS	Agente	54308436	\N	\N	t	2026-02-03 19:59:33.209583	30235-P
200	2552592550920	INMER JOSE	CIFUENTES MUÑOZ	DEPTO CONTRA SECUESTROS	Agente	30412135	\N	\N	t	2026-02-03 19:59:33.209583	42471-P
71	1796268090614	CESAR OSBALDO	GODOY SANTOS	DEPTO CONTRA SECUESTROS	Agente	31006125	\N	\N	t	2026-02-03 19:59:33.209583	35795-P
501	1834977162201	LAURA MARIA	CORDERO RAMOS	DEPTO CONTRA SECUESTROS	Agente	55102513	\N	\N	t	2026-02-03 19:59:33.209583	35611-P
221	2075410511212	JESSICA GABRIELA	CIFUENTES CASTILLO	DEPTO CONTRA SECUESTROS	Agente	51941063	\N	\N	t	2026-02-03 19:59:33.209583	64028-P
462	2133929920610	WENDY ROXANA	SOLIS NAVARIJO	DEPTO CONTRA SECUESTROS	Agente	32057862	\N	\N	t	2026-02-03 19:59:33.209583	52815-P
52	1810509781108	Byron Leonel	Cifuentes Mazariegos	DEPTO CONTRA SECUESTROS	Agente	33407673	\N	\N	t	2026-02-03 19:59:33.209583	21595-P
738	2538096140610	VICTORIA EVANGELINA	SOLIS CHAVEZ	DEPTO CONTRA SECUESTROS	Agente	41898161	\N	\N	t	2026-02-03 19:59:33.209583	50770-P
455	2080516271410	WALTER JOSUE	MARTIN ORDOÑEZ	DEIC -MIXCO	Agente	56173600	\N	\N	t	2026-02-03 19:59:33.209583	63469-P
739	1719859742010	Eroes Jacinto	Perez	DEIC - ZACAPA	Oficial lll	40179493	\N	\N	t	2026-02-03 19:59:33.209583	30512-P
740	1767810641011	DIEGO ANTONIO	ATZALAM PEREZ	UEI	oficial lll	30434346	\N	\N	t	2026-02-03 19:59:33.209583	36737-P
741	1834970661229	SARAI BUGAMBILIA	REYNA MATIAS	UEI	oficial ll	31286312	\N	\N	t	2026-02-03 19:59:33.209583	36378-P
742	1837473211401	NANCY DONINEY	RUIZ	UEI	Agente	30363579	\N	\N	t	2026-02-03 19:59:33.209583	26236-P
743	2219193091503	ERICK CARLOS	CHICOJAY CHEN	UEI	Agente	48404717	\N	\N	t	2026-02-03 19:59:33.209583	46428-P
744	2056319750415	SAMUEL EDILZAR	MOREJON GUARCAX	UEI	Agente	48404787	\N	\N	t	2026-02-03 19:59:33.209583	39606-P
148	2359432580101	Fermin Alexander	Morejon Guzman	UEI	Agente	31286303	\N	\N	t	2026-02-03 19:59:33.209583	31578-P
745	1924308821229	JORGE LUIS	GOMEZ PEREZ	UEI	Agente	48404802	\N	\N	t	2026-02-03 19:59:33.209583	56167-P
746	2602120592201	PEDRO ROBERTO	CARRILLO GUDIEL	UEI	Agente	40281930	\N	\N	t	2026-02-03 19:59:33.209583	18344-P
747	3428363232206	CARLOS HUMBERTO	QUIÑONEZ ORDOÑEZ	UEI	Agente	30364984	\N	\N	t	2026-02-03 19:59:33.209583	59629-P
748	2153123762201	MIGUEL CRUZ	FLORES	UEI	Agente	40279021	\N	\N	t	2026-02-03 19:59:33.209583	44815-P
749	1995461261019	MANUEL DE	JESUS RODAS LOPEZ	UEI	Agente	48405061	\N	\N	t	2026-02-03 19:59:33.209583	41745-P
750	1973021061229	FRANJI AUDIAS	RABANALES SOTO	UEI	Agente	48404861	\N	\N	t	2026-02-03 19:59:33.209583	37964-P
751	2365924160203	EMILIO CRUZ	RAMIREZ	UEI	Agente	31286307	\N	\N	t	2026-02-03 19:59:33.209583	25747-P
752	2611739521502	ANEXON EDUARDO	ACETUN JERONIMO	UEI	Agente	31286307	\N	\N	t	2026-02-03 19:59:33.209583	22552-P
214	2315007181704	JAMILTON ABETHSAI	MENDEZ GARCIA	UEI	Agente	48405002	\N	\N	t	2026-02-03 19:59:33.209583	50337-P
753	2442841720917	FRANKLIN ADOLFO	GALINDO GONZALEZ	UEI	Agente	31286310	\N	\N	t	2026-02-03 19:59:33.209583	59023-P
754	2786202992207	FRANCISCO ELIZANDRO	MARROQUIN PEÑATE	UEI	Agente	30837074	\N	\N	t	2026-02-03 19:59:33.209583	59366-P
755	2449308131503	MARLON IVAN	CAJBON GONZALEZ	UEI	Agente	48404823	\N	\N	t	2026-02-03 19:59:33.209583	44671-P
499	2704456842213	Sindi Paola	Hernández Linares	Departamento de Investigación de Delitos - Delegación Pinula - DEIC	Agente	37593595	\N	\N	t	2026-02-03 19:59:33.209583	52717-P
756	1663211171002	LOPEZ GOMEZ,	JOSE MOISES	UEI	Agente	48404758	\N	\N	t	2026-02-03 19:59:33.209583	26523-P
281	1834934002210	KENNY OMAR	MELGAR ARANA	UEI	Agente	30364750	\N	\N	t	2026-02-03 19:59:33.209583	37636-P
180	2731530990611	Hector Gustavo	Monterroso Peralta	UEI	Agente	48404898	\N	\N	t	2026-02-03 19:59:33.209583	50371-P
359	2298842020101	Nanci Margarita	Carreto Pérez	UEI	Agente	31286313	\N	\N	t	2026-02-03 19:59:33.209583	47169-P
204	2230579400611	Israel Hernández	Esquite	UEI	Agente	48404928	\N	\N	t	2026-02-03 19:59:33.209583	25910-P
399	1930715921009	Rodrigo Salomon	Ixquiatap García	UEI	Agente	31286311	\N	\N	t	2026-02-03 19:59:33.209583	37411-P
58	2822162351019	Carlos Francisco	Mejía Rodas	UEI	Agente	40282191	\N	\N	t	2026-02-03 19:59:33.209583	68410-P
158	1848745051018	GASPAR GONZALEZ	COXIC	UEI	Agente	30439529	\N	\N	t	2026-02-03 19:59:33.209583	41091-P
201	2856848090404	IRMA NOEMI	SIMON CHIPIX	UEI	Agente	40284688	\N	\N	t	2026-02-03 19:59:33.209583	58332-P
242	3423744352201	JOSE ARMANDO	OSORIO MEDA	UEI	Agente	47050059	\N	\N	t	2026-02-03 19:59:33.209583	66358-P
160	2153123842201	Gelber Ottoniel	Monzón Alejandro	UEI	Agente	30439594	\N	\N	t	2026-02-03 19:59:33.209583	45389-P
185	2097050430101	HENRY LEONEL	HERNANDEZ SAMAYOA	UEI	Agente	55539179	\N	\N	t	2026-02-03 19:59:33.209583	50116-P
435	3182184611505	SHARON MARITZA	VELASCO HERNANDEZ	UEI	Agente	39060489	\N	\N	t	2026-02-03 19:59:33.209583	62186-P
175	2909217080415	Hector Antonio	Arana Girón	UEI	Agente	40282457	\N	\N	t	2026-02-03 19:59:33.209583	49553-P
121	2509917562201	ELVER ORLANDO	PAIZ ALAY	UEI	AGENTE	30726598	\N	\N	t	2026-02-03 19:59:33.209583	55534-P
336	1680920500801	MAYRA ELIZABETH	LACAN GUTIERREZ	UEI	AGENTE	40787061	\N	\N	t	2026-02-03 19:59:33.209583	41253-P
757	2277468211206	MEYER ESAU	NOLASCO AGUILAR	SAFE-SGIC	Agente	55441178	\N	\N	t	2026-02-03 19:59:33.209583	29649-P
471	2296055241419	Wuilmer Manfredo	Perez	SAFE-SGIC	Agente	47665148	\N	\N	t	2026-02-03 19:59:33.209583	54907-P
31	2291658180705	Antonio Timoteo	Tambriz Tzep	SAFE-SGIC	Agente	41428732	\N	\N	t	2026-02-03 19:59:33.209583	52524-P
758	2059941992103	Silvia Veronica	Damian Agustin	SAFE-SGIC	Agente	58151079	\N	\N	t	2026-02-03 19:59:33.209583	57056-P
759	1967852430712	Juan Binifacio	Xajil Cumez	SAFE-SGIC	Agente	36448007	\N	\N	t	2026-02-03 19:59:33.209583	52584-P
760	2693904131108	Luis Alfredo	Perez Martinez	SAFE-SGIC	Agente	36103986	\N	\N	t	2026-02-03 19:59:33.209583	52390-P
337	2048393782201	Meilin Siomara	Pio Zeceña	SAFE-SGIC	Agente	33484195	\N	\N	t	2026-02-03 19:59:33.209583	66470-P
761	1896215400601	Blanca Lidia	Contreras Revolorio	SAFE-SGIC	Agente	39059868	\N	\N	t	2026-02-03 19:59:33.209583	30189-P
395	2348888651102	Robilio Lopez	Galicia	CAT - SGIC	Inspector	47934213	\N	\N	t	2026-02-03 19:59:33.209583	29589-P
302	1748461771804	Luis Aroldo	Lopez Gomez	CAT - SGIC	Agente	47934226	\N	\N	t	2026-02-03 19:59:33.209583	37498-P
416	2750291902216	Rudy Misael	Orozco y Orozco	CAT - SGIC	Agente	47934218	\N	\N	t	2026-02-03 19:59:33.209583	62895-P
762	0190388293103	Julio Cesar	Sarat Godinez	UEI	Sub Comisario	30364623	\N	\N	t	2026-02-03 19:59:33.209583	15805-P
763	1916715762201	Reyes Estuardo	Cruz Fallas	UEI	Oficial Primero	47934116	\N	\N	t	2026-02-03 19:59:33.209583	33557-P
764	2171436601010	Francis Vidal	Funes Cabrera	UEI	Agente	51277001	\N	\N	t	2026-02-03 19:59:33.209583	48557-P
765	1755829041215	Sami Azucena	Felix Pérez	UEI	Agente	46812630	\N	\N	t	2026-02-03 19:59:33.209583	37145-P
766	1693247611503	Marcelino Bolaj	Lajuj	UEI	Agente	38166063	\N	\N	t	2026-02-03 19:59:33.209583	31989-P
767	2344095090610	Jorge Leonardo	González Lémus	UEI	Agente	39575233	\N	\N	t	2026-02-03 19:59:33.209583	53044-P
768	3460347441601	Reyna Audelina	Yaxcal Rax	UEI	Agente	53727675	\N	\N	t	2026-02-03 19:59:33.209583	62248-P
769	2879671581003	Hansy Alberto	Carrillo Carrilo	UEI	Agente	40285328	\N	\N	t	2026-02-03 19:59:33.209583	56831-P
770	1959901961601	Alfonzo	Yatz	UEI	Agente	47937541	\N	\N	t	2026-02-03 19:59:33.209583	27046-P
771	3663551980101	Cristian Anderson	Godoy López	UEI	Agente	30131647	\N	\N	t	2026-02-03 19:59:33.209583	67838-P
772	2505719781610	Jorge Eduardo	Xol Tot	UEI	Agente	47937512	\N	\N	t	2026-02-03 19:59:33.209583	36584-P
773	1945922270614	Mario David	Gomez Garcia	UEI	Agente	47937503	\N	\N	t	2026-02-03 19:59:33.209583	30386-P
774	1827849910404	Amilcar Horacio	Castro Icu	UEI	Agente	47258937	\N	\N	t	2026-02-03 19:59:33.209583	33399-P
775	3026279790103	Luz Esperanza	Barrios De León	UEI	Agente	30674184	\N	\N	t	2026-02-03 19:59:33.209583	63835-P
776	2269183781001	OSCAR ROBERTO	BOC IXCOL	UEI	Agente	30364374	\N	\N	t	2026-02-03 19:59:33.209583	28327-P
777	2864056281501	Roselyn Leticia	García Hernandez	SGAIA-PNC	Agente	53555234	\N	\N	t	2026-02-03 19:59:33.209583	61126-P
778	2147283660513	Hugo Rolando	Martinez Salazar	SGAIA-PNC	Agente	52036395	\N	\N	t	2026-02-03 19:59:33.209583	62787-P
779	2189570410101	Juan Carlos	Chun Tzaquitzal	UEI	Agente	40280454	\N	\N	t	2026-02-03 19:59:33.209583	44017-P
780	2376493810203	Cupertino Ortiz	Lopez	UEI	Agente	30713252	\N	\N	t	2026-02-03 19:59:33.209583	31611-P
781	2384430941101	Wilfido David	Rodriguez de León	UEI	Agente	47937505	\N	\N	t	2026-02-03 19:59:33.209583	63617-P
782	2123831911041	Yorin Aroldo	Pichiya García	DEIC - VILLANUEVA	Agente	54437280	\N	\N	t	2026-02-03 19:59:33.209583	43627-P
443	2094422981203	Secely Elizabeth	Garcia Ramirez	DEIC - VILLANUEVA	Agente	56952591	\N	\N	t	2026-02-03 19:59:33.209583	41024-P
783	2926875592201	Edgar Dionicio	Osorio Alejandro	DEPTO-VEHÍCULO	Agente	42242624	\N	\N	t	2026-02-03 19:59:33.209583	68631-P
149	2466578202101	Filiberto Perez	Sanchez	UEI	Agente	30364365	\N	\N	t	2026-02-03 19:59:33.209583	41618-P
182	2380162421607	Heleodoro Cu	Caal	UEI	Sub Inspector	31286312	\N	\N	t	2026-02-03 19:59:33.209583	27747-P
445	1999357690404	Timoteo Pichiya	Pichiya	INVESTIGACIONES SGAIA	Oficial Tercero	54111599	\N	\N	t	2026-02-03 19:59:33.209583	43416-P
784	2168462500101	Leslie Analí	Barrientos Gómez	CAT - SGIC	Agente	54113171	\N	\N	t	2026-02-03 19:59:33.209583	46911-P
785	2667976280401	Amilcar de	Jesus Zuleta Argueta	CAT - SGIC	Agente	40927800	\N	\N	t	2026-02-03 19:59:33.209583	72527-P
786	2909134380610	Belter Rocael	Véliz Serrano	CAT - SGIC	Agente	41450952	\N	\N	t	2026-02-03 19:59:33.209583	72510-P
787	3360666431701	Damaris Yadira	Ponce López	CAT - SGIC	Agente	47934212	\N	\N	t	2026-02-03 19:59:33.209583	66475-P
788	2166334190401	Angel René	Eliezer Santiago Pichayá	CAT - SGIC	Agente	47934217	\N	\N	t	2026-02-03 19:59:33.209583	55045-P
789	3131607841502	Elvis Mardoqueo	Tolón Jerónimo	CAT - SGIC	Agente	51243019	\N	\N	t	2026-02-03 19:59:33.209583	65128-P
790	3421352872201	Diana Estefanía	López Alay	CAT - SGIC	Agente	35731349	\N	\N	t	2026-02-03 19:59:33.209583	66058-P
791	1837114750404	Fredy Leonardo	Poyón Cumez	CAT - SGIC	Agente	31536427	\N	\N	t	2026-02-03 19:59:33.209583	37938-P
792	3368222351909	Tulio Isaac	Suchite Asmén	CAT - SGIC	Agente	54801891	\N	\N	t	2026-02-03 19:59:33.209583	58357-P
793	1627918010411	Jose Luis	Loch Ajchejay	CAT - SGIC	Agente	41876904	\N	\N	t	2026-02-03 19:59:33.209583	30553-P
433	1784007181601	Sergio Helmuth	Chun Coy	CAT - SGIC	Subinspector	31529648	\N	\N	t	2026-02-03 19:59:33.209583	26926-P
794	1936667580601	Juan Carlos	Rosales Gonzalez	CAT - SGIC	Subinspector	53572399	\N	\N	t	2026-02-03 19:59:33.209583	38085-P
102	2114869730101	Edgar Rolando	Aceytuno Felipe	CAT - SGIC	Agente	47934221	\N	\N	t	2026-02-03 19:59:33.209583	40422-P
207	2453177751501	Jaime Enrique	Che Adqui	CAT - SGIC	Agente	58112429	\N	\N	t	2026-02-03 19:59:33.209583	21568-P
310	2139962000614	Luswyn Steeben	Aguilar Abrego	CAT - SGIC	Agente	41745981	\N	\N	t	2026-02-03 19:59:33.209583	40424-P
46	1834971121601	Blanca Viviana	Chun Coy	CAT - SGIC	Agente	41742314	\N	\N	t	2026-02-03 19:59:33.209583	35588-P
795	1975241251708	Victoria Ramos	Diaz	CAT - SGIC	Agente	46665852	\N	\N	t	2026-02-03 19:59:33.209583	26188-P
273	2537098140101	Julio Francisco	Vides Guzman	CAT - SGIC	Agente	31531953	\N	\N	t	2026-02-03 19:59:33.209583	32962-P
72	1908658732217	Christian de Jesus	Gutierrez de la Rosa	CAT - SGIC	Agente	47934211	\N	\N	t	2026-02-03 19:59:33.209583	37327-P
342	1789214752101	Mercedes Cruz	Ramirez	CAT - SGIC	Agente	31533814	\N	\N	t	2026-02-03 19:59:33.209583	37035-P
70	2167849480919	Cesar Orlando	Godinez Pedro	CAT - SGIC	Agente	58222945	\N	\N	t	2026-02-03 19:59:33.209583	42737-P
312	2148949161502	Manuel Canahui	Lopez	CAT - SGIC	Agente	54774548	\N	\N	t	2026-02-03 19:59:33.209583	55705-P
235	2201249140114	Jorge Humberto	Reyes Barrera	CAT - SGIC	Agente	31533062	\N	\N	t	2026-02-03 19:59:33.209583	26204-P
210	2518845030101	Jairo Daniel	Velasquez Aguilar	CAT - SGIC	Agente	31530823	\N	\N	t	2026-02-03 19:59:33.209583	29802-P
189	2088135942201	Herminia Magdalena	Lopez Cruz	CAT - SGIC	Agente	36203914	\N	\N	t	2026-02-03 19:59:33.209583	39409-P
796	1852691840412	Welfred Isai	Cos Xinic	CAT - SGIC	Agente	43404274	\N	\N	t	2026-02-03 19:59:33.209583	54548-P
55	2697293990301	Carlo Albert	Gonzalez Marin	CAT - SGIC	Agente	31314563	\N	\N	t	2026-02-03 19:59:33.209583	65885-P
384	2409957911109	Pedro Leonel	Perez Sanchez	CAT - SGIC	Agente	59541043	\N	\N	t	2026-02-03 19:59:33.209583	59592-P
91	2143505681716	Diego René	Martinez Felipe	CAT - SGIC	Agente	30116448	\N	\N	t	2026-02-03 19:59:33.209583	43102-P
320	2303417480410	Maria Francisca	Pichiya Pata	CAT - SGIC	Agente	47934228	\N	\N	t	2026-02-03 19:59:33.209583	41628-P
12	2141172411006	Alexander Gonzalo	Chanchavac Ardon	CAT - SGIC	Agente	55982721	\N	\N	t	2026-02-03 19:59:33.209583	54510-P
797	1817790212211	Elman Antonio	García Sanchez	SGAIA-PNC	Subinspector	47934152	\N	\N	t	2026-02-03 19:59:33.209583	32272-P
798	1953740610101	Mooris Ismael	Florian Rodriguez	SGAIA-PNC	Agente	30335207	\N	\N	t	2026-02-03 19:59:33.209583	26468-P
799	2840448732201	Suceli Marilú	Lemus García	SGAIA-PNC	Agente	47289662	\N	\N	t	2026-02-03 19:59:33.209583	61358-P
800	2042734390201	Eddi Estuardo	Orellana Herrera	SGAIA-PNC	Agente	40015735	\N	\N	t	2026-02-03 19:59:33.209583	50450-P
801	2495576651105	Rosalinda Sontay	Hernández	SGAIA-PNC	Agente	30358517	\N	\N	t	2026-02-03 19:59:33.209583	29770-P
802	1842548840717	Edgar Arnoldo	Cua Monrroy	SGAIA-PNC	Agente	30084363	\N	\N	t	2026-02-03 19:59:33.209583	26455-P
803	2426118180101	Ronu Estuardo	Sanros Lorenzo	SGAIA-PNC	Agente	40025422	\N	\N	t	2026-02-03 19:59:33.209583	32839-P
315	1823770181201	Marco Vinicio	Lopez Chonay	DEIC	Oficial Segundo	38652024	\N	\N	t	2026-02-03 19:59:33.209583	16614-P
21	2788053370101	Amparo Liseth	Ortega Alfaro	DEIC	Oficial Tercero	36840736	\N	\N	t	2026-02-03 19:59:33.209583	52767-P
804	2984461110203	Gerson Alejandro	Ramos Leon	DEIC	Oficial Tercero	57491670	\N	\N	t	2026-02-03 19:59:33.209583	54984-P
805	2916324590203	Robinson Araely	Lopez Perez	DEIC	Oficial Tercero	47790301	\N	\N	t	2026-02-03 19:59:33.209583	54760-P
806	1795580132201	Jose Estuardo	Cordero Florian	DEIC	Oficial Tercero	58094802	\N	\N	t	2026-02-03 19:59:33.209583	33532-P
291	2150685800101	Lesbia Karina	Yac Sucuquiej	DEIC	Subinspector	30426984	\N	\N	t	2026-02-03 19:59:33.209583	43889-P
436	2304200600612	Silvia Marisol	Ramirez Franco	DEIC	Subinspector	34314647	\N	\N	t	2026-02-03 19:59:33.209583	27133-P
367	2600358900410	Noelio Rosveli	Sirin Chicop	DEIC	Agente	38652024	\N	\N	t	2026-02-03 19:59:33.209583	52497-P
19	1890492861212	Amarildo Margarito	Lopez Cardona	DEIC	Agente	59505636	\N	\N	t	2026-02-03 19:59:33.209583	37470-P
186	2161563431712	Henry Leonel	Juarez Sucup	DEIC	Agente	33063409	\N	\N	t	2026-02-03 19:59:33.209583	50160-P
400	2665530010113	Rolando Artemio	Tobias Perez	DEIC	Agente	39725353	\N	\N	t	2026-02-03 19:59:33.209583	66724-P
713	3175894311504	Edgar Daniel	Canto Hernandez	DEIC	Agente	57504320	\N	\N	t	2026-02-03 19:59:33.209583	65455-P
562	1947293701603	Jimi Mc	Donal Jom Tzí	DEIC	Agente	56976623	\N	\N	t	2026-02-03 19:59:33.209583	41242-P
438	2194933281415	Simeon Coc	Yat	DEIC	Agente	57853283	\N	\N	t	2026-02-03 19:59:33.209583	53751-P
807	1814900051519	Carlos Enrique	Pop Tzi	DEIC	Oficial Tercero	31400372	\N	\N	t	2026-02-03 19:59:33.209583	26982-P
808	2157941760806	Miguel Yovani	Maldonado Castro	DEIC	Oficial Tercero	58067030	\N	\N	t	2026-02-03 19:59:33.209583	41374-P
809	2372921141208	David Arsenio	Roblero Velasquez	DEIC	Subinspector	32587787	\N	\N	t	2026-02-03 19:59:33.209583	54091-P
810	2968397522211	Alberns Wellington	Hernandez Martinez	DEIC	Agente	47151533	\N	\N	t	2026-02-03 19:59:33.209583	55409-P
811	3539585221202	Erik Obed	Ramirez Fuenes	DEIC	Agente	39237135	\N	\N	t	2026-02-03 19:59:33.209583	63586-P
812	1605844691703	Marvin Rolando	Valiente Genis	DEIC	Inspector	46705280	\N	\N	t	2026-02-03 19:59:33.209583	29794-P
813	1937461230401	Elvis Eliseo	Umul Nimajuan	DIPANDA - DEIC	Agente	51278020	\N	\N	t	2026-02-03 19:59:33.209583	\N
814	1828141712216	Wesfar Roberto	Jiménez Castillo	DIMEI-DEIC	Subcomisario	49443516	\N	\N	t	2026-02-03 19:59:33.209583	28716-P
815	1626320611201	Exludia Cleidi Fuentes	Tul de Gálvez	DIMEI-DEIC	Oficial Primero	39994130	\N	\N	t	2026-02-03 19:59:33.209583	26895-P
816	1767810561910	Edgar Arnoldo	Hernández	DIMEI-DEIC	Inspector	52054747	\N	\N	t	2026-02-03 19:59:33.209583	37344-P
817	3389318561001	Rudy Sir	Jotoyá	DIMEI-DEIC	Subinspector	59129539	\N	\N	t	2026-02-03 19:59:33.209583	65074-P
818	1707212481610	Herson Eduardo	Chen Xol	DIMEI-DEIC	Agente	45159331	\N	\N	t	2026-02-03 19:59:33.209583	49728-P
819	2119571002106	Mariana de	Jesús Vásquez Andrade	DIMEI-DEIC	Agente	41178586	\N	\N	t	2026-02-03 19:59:33.209583	62175-P
820	1662697000717	Andres Yojcom	Mendoza	DIPANDA - DEIC	Agente	42269430	\N	\N	t	2026-02-03 19:59:33.209583	43893-P
821	2093605422101	ADELMO CRUZ	GONZALEZ	SGAIA-PNC	AGENTE	42945600	\N	\N	t	2026-02-03 19:59:33.209583	52961-P
822	3084105560404	LESLY MERLENY	ROQUEL CUMES	SGAIA-PNC	AGENTE	41258731	\N	\N	t	2026-02-03 19:59:33.209583	52803-P
823	1872384080610	REGINALDA DEL	CID CASTILLO	SGAIA-PNC	AGENTE	51381740	\N	\N	t	2026-02-03 19:59:33.209583	52671-P
824	2059172322101	MILDRED MAGALY	CORTEZ LOPEZ	SGAIA-PNC	AGENTE	40137486	\N	\N	t	2026-02-03 19:59:33.209583	49806-P
825	1834933381207	ROSENDO EDIBERTO	VICENTE VELAZQUEZ	SGAIA-PNC	AGENTE	58727792	\N	\N	t	2026-02-03 19:59:33.209583	38355-P
826	2316940161603	ADOLFO BENJAMIN	LAJ YAT	SGAIA-PNC	AGENTE	37770809	\N	\N	t	2026-02-03 19:59:33.209583	50168-P
827	3115364760703	ROBIN GUSTABO	SOSA CHOX	SGAIA-PNC	AGENTE	42893283	\N	\N	t	2026-02-03 19:59:33.209583	63651-P
828	2753095731603	JUAN LUCAS	LANCERIO SIS	SGAIA-PNC	AGENTE	33215158	\N	\N	t	2026-02-03 19:59:33.209583	68132-P
829	3428509382206	BANDER RANDOLFO	GODOY ORTEGA	SGAIA-PNC	AGENTE	46272742	\N	\N	t	2026-02-03 19:59:33.209583	67044-P
\.


--
-- TOC entry 5129 (class 0 OID 16624)
-- Dependencies: 242
-- Data for Name: sesiones_login; Type: TABLE DATA; Schema: public; Owner: vpn_user
--

COPY public.sesiones_login (id, usuario_id, token_hash, ip_origen, user_agent, fecha_inicio, fecha_expiracion, activa) FROM stdin;
\.


--
-- TOC entry 5107 (class 0 OID 16429)
-- Dependencies: 220
-- Data for Name: solicitudes_vpn; Type: TABLE DATA; Schema: public; Owner: vpn_user
--

COPY public.solicitudes_vpn (id, persona_id, fecha_solicitud, tipo_solicitud, justificacion, estado, usuario_registro_id, comentarios_admin, fecha_registro, numero_oficio, numero_providencia, fecha_recepcion) FROM stdin;
1	1	2025-01-20	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	07-2025	S/N	2025-01-20
2	2	2024-04-15	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1392-2024	3372-2024	2024-04-15
3	3	2024-07-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1410-2024	6791-2024	2024-07-27
4	4	2024-07-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2742-2024	6763-2024	2024-07-27
5	5	2025-01-20	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	07-2025	S/N	2025-01-20
6	6	2024-01-25	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-01-25
7	7	2024-07-13	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2433-2024	S/N	2024-07-13
8	8	2024-05-28	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2351-2024	5037-2024	2024-05-28
9	9	2024-05-13	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2113-2024	4515-2024	2024-05-13
10	9	2025-01-26	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	288-2025	766-2025	2025-01-26
11	10	2025-01-20	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	C-300/014-2025	604-2025	2025-01-20
12	11	2024-05-09	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1940-2024	4295-2024	2024-05-09
13	11	2024-11-06	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2652-2024	S/N	2024-11-06
14	12	2024-05-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	341-2024	3860-2024	2024-05-23
15	12	2024-12-04	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	983-2024	12387-2024	2024-12-04
16	13	2024-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2488-2024	5310-2024	2024-06-07
17	14	2024-05-26	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	801-2024	5031-2024	2024-05-26
18	15	2024-07-12	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	232-2024	6265-2024	2024-07-12
19	16	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	536-2024	S/N	2024-04-18
20	17	2024-04-22	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1586-2024	3581-2024	2024-04-22
21	18	2024-05-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	341-2024	3860-2024	2024-05-23
22	18	2024-12-04	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	983-2024	12387-2024	2024-12-04
23	19	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1326-2024	3182-2024	2024-04-18
24	20	2024-05-26	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	801-2024	5031-2024	2024-05-26
25	21	2024-07-13	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2433-2024	S/N	2024-07-13
26	22	2025-01-30	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	156-2025	975-2025	2025-01-30
27	23	2024-08-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2024-000743	S/N	2024-08-27
28	24	2024-05-26	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2329-2024	4974-2024	2024-05-26
29	25	2024-12-08	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	5344-2024	12022-2024	2024-12-08
30	26	2024-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2488-2024	5310-2024	2024-06-07
31	27	2024-05-13	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2113-2024	4515-2024	2024-05-13
32	27	2025-01-21	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	238-2025	S/N	2025-01-21
33	28	2024-07-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1410-2024	6791-2024	2024-07-27
34	29	2024-06-22	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2544-2024	5405-2024	2024-06-22
35	30	2025-01-20	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	07-2025	S/N	2025-01-20
36	31	2024-12-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	241-2024	S/N	2024-12-07
37	32	2024-11-01	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4861-2024	10605-2024	2024-11-01
38	33	2024-04-17	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	287-2024	3121-2024	2024-04-17
39	33	2024-12-04	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	983-2024	12387-2024	2024-12-04
40	34	2024-10-01	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4286-2024	9257-2024	2024-10-01
41	35	2024-04-06	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	983-2024	3230-2024	2024-04-06
42	36	2024-12-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	5428-2024	12102-2024	2024-12-07
43	37	2024-02-19	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-02-19
44	38	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1326-2024	3182-2024	2024-04-18
45	39	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3647-2024	7862-2024	2024-08-18
46	40	2024-02-21	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-02-21
47	41	2024-04-17	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-04-17
48	42	2024-05-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	341-2024	3860-2024	2024-05-23
49	43	2024-10-01	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	324-2024	9394-2024	2024-10-01
50	44	2024-04-20	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1588-2024	3580-2024	2024-04-20
51	44	2024-11-06	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2652-2024	S/N	2024-11-06
52	45	2025-01-18	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	104-2025	S/N	2025-01-18
53	46	2024-05-23	CREACION	Importado desde Excel	CANCELADA	1	\N	2026-02-03 19:59:33.209583	341-2024	3860-2024	2024-05-23
54	46	2024-12-20	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	983-2024	12387-2024	2024-12-20
55	47	2024-02-19	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-02-19
56	48	2024-11-29	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	5023-2024	11671-2024	2024-11-29
57	49	2025-01-30	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	156-2025	975-2025	2025-01-30
58	50	2024-02-29	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-02-29
59	50	2025-01-21	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	238-2025	S/N	2025-01-21
60	51	2024-06-13	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-06-13
61	52	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	347-2024	7432-2024	2024-08-18
62	53	2024-12-08	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4029-2024	12145-2024	2024-12-08
63	54	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3647-2024	7862-2024	2024-08-18
64	55	2024-04-17	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	287-2024	3121-2024	2024-04-17
65	56	2024-07-06	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1546-2024	S/N	2024-07-06
66	57	2024-03-17	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-03-17
67	57	2025-01-21	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	238-2025	S/N	2025-01-21
68	58	2024-12-10	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1680-2024	12252-2024	2024-12-10
69	59	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	211-2024	S/N	2024-04-18
70	60	2024-04-14	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1115-2024	2883-2024	2024-04-14
71	61	2024-07-08	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-07-08
72	62	2025-01-03	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	16-2025	S/N	2025-01-03
73	63	2025-01-30	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	156-2025	975-2025	2025-01-30
74	64	2024-05-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	341-2024	3860-2024	2024-05-23
75	65	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	536-2024	S/N	2024-04-18
76	66	2024-07-08	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-07-08
77	67	2024-02-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-02-07
78	68	2024-04-29	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1782-2024	4054-2024	2024-04-29
79	69	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3647-2024	7862-2024	2024-08-18
80	70	2024-05-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	341-2024	3860-2024	2024-05-23
81	70	2024-12-04	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	983-2024	12387-2024	2024-12-04
82	71	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	347-2024	7432-2024	2024-08-18
83	72	2024-04-17	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	287-2024	3121-2024	2024-04-17
84	72	2024-12-04	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	983-2024	12387-2024	2024-12-04
85	73	2024-12-08	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3987-2024	11933-2024	2024-12-08
86	74	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	536-2024	S/N	2024-04-18
87	75	2024-02-05	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-02-05
88	76	2024-07-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1410-2024	6791-2024	2024-07-27
89	77	2024-07-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2742-2024	6763-2024	2024-07-27
90	78	2024-07-06	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1546-2024	S/N	2024-07-06
91	79	2024-01-20	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-01-20
92	80	2024-04-17	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4704-2024	10158-2024	2024-04-17
93	81	2024-05-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-05-07
94	82	2024-09-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	460-2024	S/N	2024-09-23
95	83	2025-01-20	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	07-2025	S/N	2025-01-20
96	84	2024-05-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1873-2024	4134-2024	2024-05-07
97	85	2024-04-17	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-04-17
98	86	2024-07-12	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2975-2024	6396-2024	2024-07-12
99	87	2024-07-13	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2433-2024	S/N	2024-07-13
100	88	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3647-2024	7862-2024	2024-08-18
101	89	2024-12-08	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3987-2024	11933-2024	2024-12-08
102	90	2024-01-03	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-01-03
103	91	2024-05-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	341-2024	3860-2024	2024-05-23
104	92	2024-12-04	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	983-2024	12387-2024	2024-12-04
105	93	2024-06-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-06-27
106	94	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1326-2024	3182-2024	2024-04-18
107	95	2024-03-06	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-03-06
108	95	2025-01-21	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	238-2025	S/N	2025-01-21
109	96	2024-09-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	460-2024	S/N	2024-09-23
110	97	2024-04-06	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	983-2024	3230-2024	2024-04-06
111	98	2024-09-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	460-2024	S/N	2024-09-23
112	99	2024-04-22	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1586-2024	3581-2024	2024-04-22
113	100	2024-01-30	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-01-30
114	101	2024-11-29	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	5294-2024	11626-2024	2024-11-29
115	102	2024-04-17	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	287-2024	3121-2024	2024-04-17
116	103	2024-04-18	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	518-2024	S/N	2024-04-18
117	104	2024-05-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	341-2024	3860-2024	2024-05-23
118	105	2024-11-01	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4861-2024	10605-2024	2024-11-01
119	106	2024-11-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	760-2024	16836-2024	2024-11-07
120	107	2024-11-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	5018-2024	11001-2024	2024-11-07
121	108	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1326-2024	3182-2024	2024-04-18
122	109	2024-12-10	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1680-2024	12252-2024	2024-12-10
123	110	2024-01-22	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-01-22
124	111	2024-11-01	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4881-2024	10710-2024	2024-11-01
125	112	2024-07-06	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1546-2024	S/N	2024-07-06
126	113	2024-07-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1410-2024	6791-2024	2024-07-27
127	114	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	536-2024	S/N	2024-04-18
128	115	2024-06-22	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2765-2024	5951-2024	2024-06-22
129	116	2024-07-29	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-07-29
130	117	2024-02-05	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-02-05
131	118	2024-04-17	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4704-2024	10158-2024	2024-04-17
132	119	2024-04-19	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-04-19
133	120	2024-01-26	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-01-26
134	121	2024-12-10	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1680-2024	12252-2024	2024-12-10
135	122	2024-03-20	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-03-20
136	123	2024-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2488-2024	5310-2024	2024-06-07
137	124	2024-07-13	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2433-2024	S/N	2024-07-13
138	125	2024-11-01	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4861-2024	10605-2024	2024-11-01
139	126	2024-04-19	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	908-2024	S/N	2024-04-19
140	127	2024-04-17	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	287-2024	3121-2024	2024-04-17
141	127	2024-12-04	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	983-2024	12387-2024	2024-12-04
142	128	2024-04-22	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1586-2024	3581-2024	2024-04-22
143	129	2024-05-09	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1940-2024	4295-2024	2024-05-09
144	129	2024-11-06	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2652-2024	S/N	2024-11-06
145	130	2024-01-03	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-01-03
146	131	2024-08-18	CREACION	Importado desde Excel	CANCELADA	1	\N	2026-02-03 19:59:33.209583	3647-2024	7862-2024	2024-08-18
147	132	2024-12-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	5428-2024	12102-2024	2024-12-07
148	133	2024-01-01	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-01-01
149	134	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3647-2024	7862-2024	2024-08-18
150	135	2024-04-06	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	983-2024	3230-2024	2024-04-06
151	136	2024-05-11	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1034-2024	4443-2024	2024-05-11
152	137	2024-11-14	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4998-2024	4998-2025	2024-11-14
153	45	2024-03-10	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-03-10
154	138	2024-09-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	460-2024	S/N	2024-09-23
155	139	2024-06-12	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2416-2024	5234-2024	2024-06-12
156	140	2024-05-26	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	801-2024	5031-2024	2024-05-26
157	141	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	536-2024	S/N	2024-04-18
158	142	2024-12-08	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	5344-2024	12022-2024	2024-12-08
159	143	2024-05-15	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	980-2024	4566-2024	2024-05-15
160	144	2025-01-30	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	156-2025	975-2025	2025-01-30
161	145	2024-02-29	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-02-29
162	145	2025-01-21	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	238-2025	S/N	2025-01-21
163	146	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3647-2024	7862-2024	2024-08-18
164	147	2024-12-08	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4029-2024	12145-2024	2024-12-08
165	148	2024-05-26	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	801-2024	5031-2024	2024-05-26
166	149	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	211-2024	S/N	2024-04-18
167	150	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3647-2024	7862-2024	2024-08-18
168	151	2024-05-26	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	801-2024	5031-2024	2024-05-26
169	152	2024-04-14	CREACION	Importado desde Excel	CANCELADA	1	\N	2026-02-03 19:59:33.209583	1115-2024	2883-2024	2024-04-14
170	153	2024-04-26	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-04-26
171	154	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1326-2024	3182-2024	2024-04-18
172	155	2024-08-01	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3363-2024	7215-2024	2024-08-01
173	156	2024-11-01	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4861-2024	10605-2024	2024-11-01
174	157	2024-08-18	CREACION	Importado desde Excel	CANCELADA	1	\N	2026-02-03 19:59:33.209583	3647-2024	7862-2024	2024-08-18
175	158	2024-12-10	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1680-2024	12252-2024	2024-12-10
176	159	2024-08-06	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-08-06
177	160	2024-12-10	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1680-2024	12252-2024	2024-12-10
178	161	2024-03-06	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-03-06
179	161	2025-01-21	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	238-2025	S/N	2025-01-21
180	162	2024-01-25	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-01-25
181	163	2024-03-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-03-27
182	164	2024-01-08	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-01-08
183	165	2025-01-30	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	156-2025	975-2025	2025-01-30
184	166	2024-08-01	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3376-2024	7212-2024	2024-08-01
185	167	2025-02-01	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	343-2025	947-2025	2025-02-01
186	168	2024-02-11	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-02-11
187	169	2024-07-13	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2433-2024	S/N	2024-07-13
188	170	2024-09-13	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1880-2024	S/N	2024-09-13
189	171	2024-05-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	341-2024	3860-2024	2024-05-23
190	171	2024-12-04	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	983-2024	12387-2024	2024-12-04
191	172	2024-07-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3223-2024	6896-2024	2024-07-27
192	173	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3647-2024	7862-2024	2024-08-18
193	174	2024-07-13	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2433-2024	S/N	2024-07-13
194	175	2024-12-10	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1680-2024	12252-2024	2024-12-10
195	176	2024-05-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1873-2024	4134-2024	2024-05-07
196	177	2024-04-14	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1115-2024	2883-2024	2024-04-14
197	178	2024-04-22	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1586-2024	3581-2024	2024-04-22
198	179	2024-01-25	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-01-25
199	180	2024-05-26	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	801-2024	5031-2024	2024-05-26
200	181	2024-07-13	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2433-2024	S/N	2024-07-13
201	182	2024-12-10	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1680-2024	12252-2024	2024-12-10
202	183	2024-04-22	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1586-2024	3581-2024	2024-04-22
203	184	2024-02-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-02-27
204	184	2025-01-24	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	20-2025	767-2025	2025-01-24
205	185	2024-12-10	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1680-2024	12252-2024	2024-12-10
206	186	2024-11-01	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4881-2024	10710-2024	2024-11-01
207	187	2024-01-01	CREACION	Importado desde Excel	CANCELADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-01-01
208	187	2024-12-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2502-2024	S/N	2024-12-07
209	188	2024-02-20	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-02-20
210	189	2024-01-01	CREACION	Importado desde Excel	CANCELADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-01-01
211	189	2024-12-04	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	983-2024	12387-2024	2024-12-04
212	190	2024-12-10	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1680-2024	12252-2024	2024-12-10
213	191	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3647-2024	7862-2024	2024-08-18
214	192	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	211-2024	S/N	2024-04-18
215	192	2024-11-30	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2111-2024	S/N	2024-11-30
216	193	2024-07-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2742-2024	6763-2024	2024-07-27
217	194	2024-07-12	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	232-2024	6265-2024	2024-07-12
218	195	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3647-2024	7862-2024	2024-08-18
219	196	2024-02-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-02-07
220	197	2024-08-01	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-08-01
221	198	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3647-2024	7862-2024	2024-08-18
222	199	2024-06-22	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2544-2024	5405-2024	2024-06-22
223	200	2024-10-29	CREACION	Importado desde Excel	CANCELADA	1	\N	2026-02-03 19:59:33.209583	1580-2024	10048-2024	2024-10-29
224	201	2024-12-10	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1680-2024	12252-2024	2024-12-10
225	202	2025-01-20	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	07-2025	S/N	2025-01-20
226	203	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3426-2024	7300-2024	2024-08-18
227	204	2024-12-10	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1680-2024	12252-2024	2024-12-10
228	205	2024-05-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1873-2024	4134-2024	2024-05-07
229	206	2024-08-01	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3376-2024	7212-2024	2024-08-01
230	207	2024-05-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	341-2024	3860-2024	2024-05-23
231	207	2024-12-04	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	983-2024	12387-2024	2024-12-04
232	208	2024-11-01	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4861-2024	10605-2024	2024-11-01
233	209	2025-01-21	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	238-2025	S/N	2025-01-21
234	210	2024-05-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	341-2024	3860-2024	2024-05-23
235	210	2024-12-04	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	983-2024	12387-2024	2024-12-04
236	211	2024-04-17	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	287-2024	3121-2024	2024-04-17
237	211	2024-12-04	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	983-2024	12387-2024	2024-12-04
238	212	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3647-2024	7862-2024	2024-08-18
239	213	2024-12-16	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	5563-2024	12370-2024	2024-12-16
240	214	2024-05-26	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	801-2024	5031-2024	2024-05-26
241	215	2024-07-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1410-2024	6791-2024	2024-07-27
242	216	2024-08-11	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1600-2024	7592-2024	2024-08-11
243	217	2024-10-01	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	324-2024	9394-2024	2024-10-01
244	218	2024-09-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	460-2024	S/N	2024-09-23
245	219	2024-09-04	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3037-2024	S/N	2024-09-04
246	220	2024-02-29	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-02-29
247	220	2025-01-21	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	238-2025	S/N	2025-01-21
248	221	2024-10-29	CREACION	Importado desde Excel	CANCELADA	1	\N	2026-02-03 19:59:33.209583	1580-2024	10048-2024	2024-10-29
249	222	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	536-2024	S/N	2024-04-18
250	223	2024-05-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1873-2024	4134-2024	2024-05-07
251	224	2024-07-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2742-2024	6763-2024	2024-07-27
252	225	2025-01-26	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	288-2025	766-2025	2025-01-26
253	226	2024-05-07	CREACION	Importado desde Excel	CANCELADA	1	\N	2026-02-03 19:59:33.209583	1873-2024	4134-2024	2024-05-07
254	227	2024-09-04	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3037-2024	S/N	2024-09-04
255	228	2024-06-22	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2544-2024	5405-2024	2024-06-22
256	229	2024-02-05	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-02-05
257	230	2024-03-17	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-03-17
258	230	2025-01-21	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	238-2025	S/N	2025-01-21
259	231	2025-01-30	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	156-2025	975-2025	2025-01-30
260	232	2024-03-20	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-03-20
261	233	2024-03-17	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-03-17
262	233	2025-01-21	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	238-2025	S/N	2025-01-21
263	234	2025-01-30	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	156-2025	975-2025	2025-01-30
264	235	2024-05-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	341-2024	3860-2024	2024-05-23
265	235	2024-12-04	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	983-2024	12387-2024	2024-12-04
266	236	2024-05-26	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	801-2024	5031-2024	2024-05-26
267	237	2024-05-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	341-2024	3860-2024	2024-05-23
268	237	2024-12-04	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	983-2024	12387-2024	2024-12-04
269	238	2025-01-30	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	156-2025	975-2025	2025-01-30
270	239	2024-08-01	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3363-2024	7215-2024	2024-08-01
271	240	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	211-2024	S/N	2024-04-18
272	241	2025-01-30	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	237-2025	1031-2025	2025-01-30
273	242	2024-12-10	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1680-2024	12252-2024	2024-12-10
274	243	2024-09-19	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-09-19
275	244	2024-05-11	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1034-2024	4443-2024	2024-05-11
276	245	2024-11-01	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4861-2024	10605-2024	2024-11-01
277	246	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3637-2024	7859-2024	2024-08-18
278	247	2024-05-26	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	801-2024	5031-2024	2024-05-26
279	248	2024-01-30	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-01-30
280	249	2024-05-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	341-2024	3860-2024	2024-05-23
281	249	2024-12-04	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	983-2024	12387-2024	2024-12-04
282	250	2024-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2447-2024	5232-2024	2024-06-07
283	251	2024-07-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2742-2024	6763-2024	2024-07-27
284	252	2024-05-11	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1034-2024	4443-2024	2024-05-11
285	253	2024-12-08	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	5344-2024	12022-2024	2024-12-08
286	254	2024-11-01	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4861-2024	10605-2024	2024-11-01
287	255	2024-05-09	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1940-2024	4295-2024	2024-05-09
288	255	2024-11-06	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2652-2024	S/N	2024-11-06
289	256	2025-01-21	ACTUALIZACION	Importado desde Excel	CANCELADA	1	\N	2026-02-03 19:59:33.209583	238-2025	S/N	2025-01-21
290	257	2024-08-22	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2931-2024	6267-2024	2024-08-22
291	258	2024-12-08	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	5344-2024	12022-2024	2024-12-08
292	259	2024-07-13	CREACION	Importado desde Excel	CANCELADA	1	\N	2026-02-03 19:59:33.209583	2433-2024	S/N	2024-07-13
293	260	2024-07-27	CREACION	Importado desde Excel	CANCELADA	1	\N	2026-02-03 19:59:33.209583	1410-2024	6791-2024	2024-07-27
294	261	2024-04-17	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	287-2024	3121-2024	2024-04-17
295	261	2024-12-04	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	983-2024	12387-2024	2024-12-04
296	262	2024-11-01	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4861-2024	10605-2024	2024-11-01
297	263	2024-01-26	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-01-26
298	264	2024-01-21	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-01-21
299	265	2025-01-30	CREACION	Importado desde Excel	CANCELADA	1	\N	2026-02-03 19:59:33.209583	156-2025	975-2025	2025-01-30
300	266	2024-05-26	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	801-2024	5031-2024	2024-05-26
301	267	2024-07-13	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2982-2024	6397-2024	2024-07-13
302	268	2024-03-17	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-03-17
303	268	2025-01-21	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	238-2025	S/N	2025-01-21
304	269	2024-02-11	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-02-11
305	270	2024-05-15	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	980-2024	4566-2024	2024-05-15
306	271	2024-10-01	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	324-2024	9394-2024	2024-10-01
307	272	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3647-2024	7862-2024	2024-08-18
308	273	2024-05-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	341-2024	3860-2024	2024-05-23
309	273	2024-12-04	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	983-2024	12387-2024	2024-12-04
310	274	2024-03-16	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-03-16
311	275	2025-01-20	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	07-2025	S/N	2025-01-20
312	276	2024-12-16	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	5563-2024	12370-2024	2024-12-16
313	277	2024-12-10	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1680-2024	12252-2024	2024-12-10
314	278	2024-05-26	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	801-2024	5031-2024	2024-05-26
315	279	2024-09-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	460-2024	S/N	2024-09-23
316	280	2024-12-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	241-2024	S/N	2024-12-07
317	281	2024-05-26	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	801-2024	5031-2024	2024-05-26
318	282	2024-04-22	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1586-2024	3581-2024	2024-04-22
319	283	2024-04-22	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1586-2024	3581-2024	2024-04-22
320	284	2024-04-14	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1115-2024	2883-2024	2024-04-14
321	285	2024-11-01	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4861-2024	10605-2024	2024-11-01
322	286	2024-03-06	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-03-06
323	286	2025-01-21	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	238-2025	S/N	2025-01-21
324	287	2024-07-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1410-2024	6791-2024	2024-07-27
325	288	2024-05-24	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3595-2024	S/N	2024-05-24
326	289	2024-09-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	460-2024	S/N	2024-09-23
327	290	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1326-2024	3182-2024	2024-04-18
328	291	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3638-2024	7861-2024	2024-08-18
329	292	2024-08-01	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-08-01
330	293	2024-06-07	CREACION	Importado desde Excel	CANCELADA	1	\N	2026-02-03 19:59:33.209583	2447-2024	5232-2024	2024-06-07
331	294	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1326-2024	3182-2024	2024-04-18
332	295	2024-08-01	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3363-2024	7215-2024	2024-08-01
333	296	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	211-2024	S/N	2024-04-18
334	297	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3638-2024	7861-2024	2024-08-18
335	298	2024-01-20	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-01-20
336	298	2024-12-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2502-2024	S/N	2024-12-07
337	299	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3638-2024	7861-2024	2024-08-18
338	300	2025-01-30	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	237-2025	1031-2025	2025-01-30
339	301	2024-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2488-2024	5310-2024	2024-06-07
340	302	2024-04-17	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	287-2024	3121-2024	2024-04-17
341	302	2024-12-04	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	983-2024	12387-2024	2024-12-04
342	303	2024-04-17	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-04-17
343	304	2024-05-13	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2113-2024	4515-2024	2024-05-13
344	304	2025-01-21	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	238-2025	S/N	2025-01-21
345	305	2024-02-24	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-02-24
346	306	2024-02-24	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-02-24
347	307	2024-04-06	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	983-2024	3230-2024	2024-04-06
348	308	2024-09-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	460-2024	S/N	2024-09-23
349	309	2025-01-26	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	288-2025	766-2025	2025-01-26
350	310	2024-05-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	341-2024	3860-2024	2024-05-23
351	311	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3603-2024	7860-2024	2024-08-18
352	312	2024-05-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	341-2024	3860-2024	2024-05-23
353	312	2024-12-04	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	983-2024	12387-2024	2024-12-04
354	313	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1444-2024	3375-2024	2024-04-18
355	314	2024-07-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3223-2024	6896-2024	2024-07-27
356	315	2024-11-11	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	5067-2024	11121-2024	2024-11-11
357	316	2024-03-16	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-03-16
358	317	2024-11-14	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4998-2024	4998-2025	2024-11-14
359	318	2024-11-14	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4998-2024	4998-2025	2024-11-14
360	319	2024-07-13	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2433-2024	S/N	2024-07-13
361	320	2024-04-17	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	287-2024	3121-2024	2024-04-17
362	320	2024-12-04	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	983-2024	12387-2024	2024-12-04
363	321	2024-02-20	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-02-20
364	322	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	536-2024	S/N	2024-04-18
365	323	2024-07-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1410-2024	6791-2024	2024-07-27
366	324	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3603-2024	7860-2024	2024-08-18
367	325	2024-03-14	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-03-14
368	326	2024-09-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	460-2024	S/N	2024-09-23
369	327	2024-07-13	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2433-2024	S/N	2024-07-13
370	328	2024-06-12	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2751-2024	5746-2024	2024-06-12
371	329	2024-04-22	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1586-2024	3581-2024	2024-04-22
372	330	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	536-2024	S/N	2024-04-18
373	331	2024-08-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2024-000743	S/N	2024-08-27
374	332	2024-11-14	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4998-2024	4998-2025	2024-11-14
375	333	2024-01-03	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-01-03
376	334	2024-04-06	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	983-2024	3230-2024	2024-04-06
377	335	2024-02-05	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-02-05
378	336	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1444-2024	3375-2024	2024-04-18
379	337	2024-12-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	241-2024	S/N	2024-12-07
380	338	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	211-2024	S/N	2024-04-18
381	339	2024-04-26	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-04-26
382	340	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	536-2024	S/N	2024-04-18
383	341	2024-04-20	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1588-2024	3580-2024	2024-04-20
384	341	2024-11-06	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2652-2024	S/N	2024-11-06
385	342	2024-05-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	341-2024	3860-2024	2024-05-23
386	342	2024-12-04	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	983-2024	12387-2024	2024-12-04
387	343	2024-11-25	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	DAC/G2024	11609-2024	2024-11-25
388	344	2024-04-22	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1586-2024	3581-2024	2024-04-22
389	345	2024-01-12	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-01-12
390	346	2024-03-17	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-03-17
391	347	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1444-2024	3375-2024	2024-04-18
392	348	2024-03-06	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-03-06
393	348	2025-01-21	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	238-2025	S/N	2025-01-21
394	349	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	347-2024	7432-2024	2024-08-18
395	350	2025-01-30	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	237-2025	1031-2025	2025-01-30
396	351	2024-11-29	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	5294-2024	11626-2024	2024-11-29
397	352	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	347-2024	7432-2024	2024-08-18
398	353	2025-01-30	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	156-2025	975-2025	2025-01-30
399	354	2024-11-29	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	5023-2024	11671-2024	2024-11-29
400	355	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3638-2024	7861-2024	2024-08-18
401	356	2025-01-20	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	07-2025	S/N	2025-01-20
402	357	2024-07-13	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2433-2024	S/N	2024-07-13
403	358	2024-09-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	460-2024	S/N	2024-09-23
404	359	2024-05-26	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	801-2024	5031-2024	2024-05-26
405	360	2024-08-01	CREACION	Importado desde Excel	CANCELADA	1	\N	2026-02-03 19:59:33.209583	3376-2024	7212-2024	2024-08-01
406	361	2024-05-24	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3595-2024	S/N	2024-05-24
407	362	2024-05-24	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3595-2024	S/N	2024-05-24
408	363	2024-02-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-02-07
409	364	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	536-2024	S/N	2024-04-18
410	365	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3647-2024	7862-2024	2024-08-18
411	366	2024-05-13	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2113-2024	4515-2024	2024-05-13
412	367	2024-11-01	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4861-2024	10605-2024	2024-11-01
413	368	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3647-2024	7862-2024	2024-08-18
414	369	2024-07-13	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2433-2024	S/N	2024-07-13
415	370	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	211-2024	S/N	2024-04-18
416	371	2024-05-24	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3595-2024	S/N	2024-05-24
417	372	2024-04-06	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	983-2024	3230-2024	2024-04-06
418	373	2024-11-11	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	975-2024	11119-2024	2024-11-11
419	374	2024-02-05	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-02-05
420	375	2024-02-20	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-02-20
421	376	2024-07-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1410-2024	6791-2024	2024-07-27
422	377	2024-07-06	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1546-2024	S/N	2024-07-06
423	378	2024-02-06	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-02-06
424	379	2025-01-20	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	07-2025	S/N	2025-01-20
425	380	2024-06-22	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2544-2024	5405-2024	2024-06-22
426	381	2024-02-10	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-02-10
427	382	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3647-2024	7862-2024	2024-08-18
428	383	2024-04-15	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-04-15
429	384	2024-05-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	341-2024	3860-2024	2024-05-23
430	385	2024-11-29	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	5294-2024	11626-2024	2024-11-29
431	386	2024-04-22	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1586-2024	3581-2024	2024-04-22
432	387	2024-08-01	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3376-2024	7212-2024	2024-08-01
433	388	2024-07-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1410-2024	6791-2024	2024-07-27
434	389	2024-04-14	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1115-2024	2883-2024	2024-04-14
435	390	2024-09-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	460-2024	S/N	2024-09-23
436	391	2024-04-22	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1586-2024	3581-2024	2024-04-22
437	392	2024-03-16	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-03-16
438	393	2024-02-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-02-07
439	394	2024-07-13	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2433-2024	S/N	2024-07-13
440	395	2024-04-17	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	287-2024	3121-2024	2024-04-17
441	395	2024-12-04	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	983-2024	12387-2024	2024-12-04
442	396	2024-05-28	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2351-2024	5037-2024	2024-05-28
443	397	2024-12-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	5428-2024	12102-2024	2024-12-07
444	398	2024-01-01	CREACION	Importado desde Excel	CANCELADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-01-01
445	399	2024-12-10	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1680-2024	12252-2024	2024-12-10
446	400	2024-11-01	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4861-2024	10605-2024	2024-11-01
447	401	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3638-2024	7861-2024	2024-08-18
448	402	2025-01-21	ACTUALIZACION	Importado desde Excel	CANCELADA	1	\N	2026-02-03 19:59:33.209583	238-2025	S/N	2025-01-21
449	403	2024-09-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	460-2024	S/N	2024-09-23
450	404	2024-12-08	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3987-2024	11933-2024	2024-12-08
451	405	2024-09-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	460-2024	S/N	2024-09-23
452	406	2024-05-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	341-2024	3860-2024	2024-05-23
453	406	2024-12-04	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	983-2024	12387-2024	2024-12-04
454	407	2025-01-20	CREACION	Importado desde Excel	CANCELADA	1	\N	2026-02-03 19:59:33.209583	07-2025	S/N	2025-01-20
455	408	2024-04-17	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4704-2024	10158-2024	2024-04-17
456	409	2024-07-31	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-07-31
457	410	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1326-2024	3182-2024	2024-04-18
458	411	2024-02-02	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-02-02
459	412	2025-01-20	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	70-2025	592-2025	2025-01-20
460	413	2024-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2447-2024	5232-2024	2024-06-07
461	414	2024-04-22	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1586-2024	3581-2024	2024-04-22
462	415	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1326-2024	3182-2024	2024-04-18
463	416	2024-04-17	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	287-2024	3121-2024	2024-04-17
464	417	2024-03-17	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-03-17
465	417	2025-01-21	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	238-2025	S/N	2025-01-21
466	418	2024-03-20	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-03-20
467	419	2024-05-11	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1034-2024	4443-2024	2024-05-11
468	420	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3638-2024	7861-2024	2024-08-18
469	421	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3647-2024	7862-2024	2024-08-18
470	422	2024-08-01	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3363-2024	7215-2024	2024-08-01
471	423	2024-07-05	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2024-07-05
472	424	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	347-2024	7432-2024	2024-08-18
473	425	2024-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2447-2024	5232-2024	2024-06-07
474	426	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	536-2024	S/N	2024-04-18
475	427	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3647-2024	7862-2024	2024-08-18
476	428	2024-07-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1410-2024	6791-2024	2024-07-27
477	429	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1444-2024	3375-2024	2024-04-18
478	430	2024-02-20	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-02-20
479	431	2024-05-29	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-05-29
480	432	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3638-2024	7861-2024	2024-08-18
481	433	2024-05-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	341-2024	3860-2024	2024-05-23
482	433	2024-12-04	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	983-2024	12387-2024	2024-12-04
483	434	2024-06-22	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2544-2024	5405-2024	2024-06-22
484	435	2024-12-10	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1680-2024	12252-2024	2024-12-10
485	436	2024-04-15	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1392-2024	3372-2024	2024-04-15
486	437	2024-07-06	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1546-2024	S/N	2024-07-06
487	438	2024-01-12	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-01-12
488	439	2025-01-30	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	156-2025	975-2025	2025-01-30
489	440	2024-02-05	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-02-05
490	441	2024-08-01	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3376-2024	7212-2024	2024-08-01
491	442	2024-04-18	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	518-2024	S/N	2024-04-18
492	443	2024-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2488-2024	5310-2024	2024-06-07
493	444	2024-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2447-2024	5232-2024	2024-06-07
494	445	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3515-2024	7421-2024	2024-08-18
495	446	2024-05-09	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1940-2024	4295-2024	2024-05-09
496	446	2024-11-06	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2652-2024	S/N	2024-11-06
497	447	2024-01-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-01-23
498	448	2024-04-22	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1586-2024	3581-2024	2024-04-22
499	448	2024-11-30	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2111-2024	S/N	2024-11-30
500	449	2025-01-30	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	156-2025	975-2025	2025-01-30
501	450	2024-04-17	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4704-2024	10158-2024	2024-04-17
502	451	2024-12-16	CREACION	Importado desde Excel	CANCELADA	1	\N	2026-02-03 19:59:33.209583	5563-2024	12370-2024	2024-12-16
503	452	2024-05-24	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3595-2024	S/N	2024-05-24
504	453	2024-04-29	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1782-2024	4054-2024	2024-04-29
505	454	2024-08-18	CREACION	Importado desde Excel	CANCELADA	1	\N	2026-02-03 19:59:33.209583	3647-2024	7862-2024	2024-08-18
506	455	2024-10-14	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4486-2024	9763-2024	2024-10-14
507	456	2024-05-28	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2351-2024	5037-2024	2024-05-28
508	457	2024-05-26	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	801-2024	5031-2024	2024-05-26
509	458	2024-11-01	CREACION	Importado desde Excel	CANCELADA	1	\N	2026-02-03 19:59:33.209583	4861-2024	10605-2024	2024-11-01
510	459	2024-01-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-01-23
511	460	2025-01-20	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	07-2025	S/N	2025-01-20
512	461	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	211-2024	S/N	2024-04-18
513	462	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	347-2024	7432-2024	2024-08-18
514	463	2024-04-14	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1115-2024	2883-2024	2024-04-14
515	463	2024-12-20	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4186-2024	S/N	2024-12-20
516	464	2024-08-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3603-2024	7860-2024	2024-08-18
517	465	2024-02-14	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-02-14
518	466	2024-04-22	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1586-2024	3581-2024	2024-04-22
519	467	2024-11-01	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4861-2024	10605-2024	2024-11-01
520	468	2024-12-08	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	5344-2024	12022-2024	2024-12-08
521	469	2024-07-06	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1546-2024	S/N	2024-07-06
522	470	2024-04-18	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	211-2024	S/N	2024-04-18
523	471	2024-12-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	241-2024	S/N	2024-12-07
524	472	2024-09-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	460-2024	S/N	2024-09-23
525	473	2024-12-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	5428-2024	12102-2024	2024-12-07
526	474	2024-02-21	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-02-21
527	475	2024-07-29	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-07-29
528	476	2024-06-12	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2416-2024	5234-2024	2024-06-12
529	477	2024-09-23	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	460-2024	S/N	2024-09-23
530	478	2024-09-20	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4190-2024	S/N	2024-09-20
531	479	2024-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2447-2024	5232-2024	2024-06-07
532	480	2024-09-04	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3037-2024	S/N	2024-09-04
533	481	2024-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2488-2024	5310-2024	2024-06-07
534	482	2024-05-24	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3595-2024	S/N	2024-05-24
535	483	2025-01-30	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	237-2025	1031-2025	2025-01-30
536	484	2024-09-04	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	3037-2024	S/N	2024-09-04
537	485	2024-04-18	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	518-2024	S/N	2024-04-18
538	486	2024-04-16	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2024-04-16
539	487	2024-06-12	CREACION	Importado desde Excel	CANCELADA	1	\N	2026-02-03 19:59:33.209583	2751-2024	5746-2024	2024-06-12
540	488	2025-02-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	452-2025	S/N	2025-02-11
541	149	2025-05-29	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	672-2025	S/N	2025-05-29
542	307	2025-05-29	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	672-2025	S/N	2025-05-29
543	489	2025-02-13	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	491-2025	1231-2025	2025-02-13
544	414	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
545	490	2025-02-13	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	491-2025	1231-2025	2025-02-13
546	491	2025-02-13	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	513-2025	1273-2025	2025-02-13
547	54	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
548	150	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
549	492	2025-02-13	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	513-2025	1273-2025	2025-02-13
550	88	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
551	493	2025-02-13	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	513-2025	1273-2025	2025-02-13
552	173	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
553	494	2025-02-13	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	513-2025	1273-2025	2025-02-13
554	495	2025-02-13	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	513-2025	1273-2025	2025-02-13
555	38	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
556	496	2025-02-13	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	513-2025	1273-2025	2025-02-13
557	65	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
558	372	2025-02-17	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	461-2025	S/N	2025-02-17
559	338	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
560	296	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
561	135	2025-02-17	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	459-2025	S/N	2025-02-17
562	464	2025-02-19	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	224-2025	S/N	2025-02-19
563	448	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
564	324	2025-02-19	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	224-2025	S/N	2025-02-19
565	497	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
566	311	2025-02-19	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	224-2025	S/N	2025-02-19
567	498	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
568	499	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
569	86	2025-02-24	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	pendiente	pendiente	2025-02-24
570	90	5052-02-22	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	127-2025	1625-2025	5052-02-22
571	53	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
572	332	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
573	500	2025-02-22	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	245-2025	1810-2025	2025-02-22
574	200	5052-02-22	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	245-2025	1810-2025	5052-02-22
575	147	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
576	501	5052-02-22	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	245-2025	1810-2025	5052-02-22
577	89	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
578	221	5052-02-22	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	245-2025	1810-2025	5052-02-22
579	203	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
580	423	2025-02-22	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	690-2025	1810-2025	2025-02-22
581	502	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
582	240	2024-04-12	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2252024	1684-2025	2024-04-12
583	503	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
584	504	2025-02-28	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	515-2025	2429-2025	2025-02-28
585	505	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
586	506	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
587	507	2025-02-28	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	515-2025	2429-2025	2025-02-28
588	508	2025-02-28	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	515-2025	2429-2025	2025-02-28
589	325	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
590	509	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
591	510	2025-02-28	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	515-2025	2429-2025	2025-02-28
592	511	2025-03-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	911-2025	S/N	2025-03-07
593	396	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
594	292	2024-08-01	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	58-2025	19624-2025	2024-08-01
595	226	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
596	197	2024-08-01	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	58-2025	19624-2025	2024-08-01
597	176	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
598	512	2025-03-03	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	186-2025	4290-2025	2025-03-03
599	223	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
600	341	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
601	513	2025-03-03	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	186-2025	4290-2025	2025-03-03
602	514	2025-03-03	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	186-2025	4290-2025	2025-03-03
603	11	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
604	44	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
605	515	2025-03-03	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	186-2025	4290-2025	2025-03-03
606	446	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
607	516	2025-03-03	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	186-2025	4290-2025	2025-03-03
608	274	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
609	517	2025-04-15	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	DIGICI-1D.1C-2025	26448-2025	2025-04-15
610	518	2025-04-29	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	79-2025	S/N	2025-04-29
611	24	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
612	267	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2025	7188-2025	2025-06-07
613	519	2025-04-29	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	79-2025	S/N	2025-04-29
614	478	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2026	7188-2026	2025-06-07
615	520	2025-05-28	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2025-225-JRGM	6354-2025	2025-05-28
616	331	2025-05-28	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2025-225-JRGM	6354-2025	2025-05-28
617	205	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2027	7188-2027	2025-06-07
618	57	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2027	7188-2027	2025-06-07
619	23	2025-05-28	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2025-225-JRGM	6354-2025	2025-05-28
620	220	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2027	7188-2027	2025-06-07
621	521	2025-05-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	6642-2025	2695-2025	2025-05-27
622	522	2025-05-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	6642-2025	2695-2025	2025-05-27
623	9	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2027	7188-2027	2025-06-07
624	523	2025-05-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	38-2025	5755-2025	2025-05-27
625	524	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2027	7188-2027	2025-06-07
626	251	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2027	7188-2027	2025-06-07
627	479	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2027	7188-2027	2025-06-07
628	4	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2027	7188-2027	2025-06-07
629	444	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2027	7188-2027	2025-06-07
630	193	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2027	7188-2027	2025-06-07
631	425	2025-06-07	ACTUALIZACION	Importado desde Excel	CANCELADA	1	\N	2026-02-03 19:59:33.209583	2431-2027	7188-2027	2025-06-07
632	86	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2027	7188-2027	2025-06-07
633	172	2025-06-07	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2027	7188-2027	2025-06-07
634	525	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2431-2027	7188-2027	2025-06-07
635	10	2025-06-09	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	176-2025	7420-2025	2025-06-09
636	526	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
637	527	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
638	528	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
639	529	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
640	139	2025-06-07	ACTUALIZACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
641	530	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
642	531	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
643	532	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
644	533	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
645	534	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
646	535	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
647	536	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
648	537	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
649	538	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
650	539	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
651	540	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
652	541	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
653	542	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
654	543	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
655	544	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
656	545	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
657	546	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
658	547	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
659	548	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
660	549	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
661	550	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
662	551	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
663	552	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
664	553	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
665	554	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
666	555	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
667	556	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
668	25	2025-06-07	ACTUALIZACION	Importado desde Excel	CANCELADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
669	557	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
670	558	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
671	559	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
672	560	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
673	561	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
674	562	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
675	563	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
676	564	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
677	565	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
678	566	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
679	567	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
680	568	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
681	569	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
682	570	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
683	489	2025-06-07	ACTUALIZACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
684	571	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
685	572	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
686	573	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
687	574	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
688	575	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
689	576	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
690	577	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
691	578	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
692	579	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
693	580	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
694	581	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
695	582	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
696	583	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
697	584	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
698	585	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
699	586	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
700	587	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
701	588	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
702	589	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
703	590	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
704	591	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
705	592	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
706	593	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
707	594	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
708	595	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
709	596	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
710	597	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
711	598	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
712	599	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
713	600	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
714	601	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
715	602	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
716	603	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
717	604	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
718	605	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
719	606	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
720	607	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
721	608	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
722	609	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
723	610	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
724	611	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
725	612	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
726	613	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
727	614	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
728	615	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
729	616	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
730	617	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
731	618	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
732	619	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
733	620	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
734	621	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
735	622	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
736	623	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
737	454	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
738	624	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
739	625	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
740	626	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
741	627	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
742	628	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
743	629	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
744	630	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
745	631	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
746	632	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
747	633	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
748	634	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
749	635	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
750	419	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
751	636	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
752	637	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
753	638	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
754	639	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
755	640	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
756	641	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
757	642	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
758	643	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
759	644	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
760	645	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
761	646	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
762	647	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
763	648	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
764	649	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
765	650	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
766	651	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
767	652	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
768	653	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
769	654	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
770	655	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
771	656	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
772	657	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
773	658	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
774	209	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
775	659	2025-06-07	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
776	413	2025-06-07	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2432-2025	7191-2025	2025-06-07
777	151	2025-06-20	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	842-2025	S/N	2025-06-20
778	457	2025-06-20	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	842-2025	S/N	2025-06-20
779	148	2025-06-20	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	842-2025	S/N	2025-06-20
780	180	2025-06-20	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	842-2025	S/N	2025-06-20
781	660	2025-06-20	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	842-2025	S/N	2025-06-20
782	661	2025-06-20	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	842-2025	S/N	2025-06-20
783	140	2025-06-20	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	842-2025	S/N	2025-06-20
784	662	2025-06-20	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	842-2025	S/N	2025-06-20
785	257	2025-06-17	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2627-2025	8781-2025	2025-06-17
786	502	2025-06-17	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2627-2025	8781-2025	2025-06-17
787	232	2025-06-17	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2627-2025	8781-2025	2025-06-17
788	272	2025-06-17	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2627-2025	8781-2025	2025-06-17
789	94	2025-06-17	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2627-2025	8781-2025	2025-06-17
790	452	2025-06-17	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2627-2025	8781-2025	2025-06-17
791	663	2025-06-17	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2627-2025	8781-2025	2025-06-17
792	664	2025-06-17	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2627-2025	8781-2025	2025-06-17
793	116	2025-06-17	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2627-2025	8781-2025	2025-06-17
794	252	2025-06-17	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2627-2025	8781-2025	2025-06-17
795	665	2025-06-17	CREACION	Importado desde Excel	CANCELADA	1	\N	2026-02-03 19:59:33.209583	2627-2025	8781-2025	2025-06-17
796	463	2025-06-17	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2627-2025	8781-2025	2025-06-17
797	371	2025-06-17	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2627-2025	8781-2025	2025-06-17
798	362	2025-06-17	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2627-2025	8781-2025	2025-06-17
799	666	2025-06-17	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2627-2025	8781-2025	2025-06-17
800	8	2025-06-17	ACTUALIZACION	Importado desde Excel	CANCELADA	1	\N	2026-02-03 19:59:33.209583	2627-2025	8781-2025	2025-06-17
801	667	2025-06-17	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2627-2025	8781-2025	2025-06-17
802	668	2025-06-17	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2627-2025	8781-2025	2025-06-17
803	669	2025-06-17	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2627-2025	8781-2025	2025-06-17
804	670	2025-06-17	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2627-2025	8781-2025	2025-06-17
805	671	2025-07-10	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2611-2025	8780-2025	2025-07-10
806	672	2025-07-10	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2611-2025	8780-2025	2025-07-10
807	673	2025-07-10	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2611-2025	8780-2025	2025-07-10
808	674	2025-07-10	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2611-2025	8780-2025	2025-07-10
809	675	2025-07-10	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2611-2025	8780-2025	2025-07-10
810	676	2025-07-10	CREACION	Importado desde Excel	CANCELADA	1	\N	2026-02-03 19:59:33.209583	2611-2025	8780-2025	2025-07-10
811	584	2025-07-10	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2611-2025	8780-2025	2025-07-10
812	677	2025-07-10	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2611-2025	8780-2025	2025-07-10
813	678	2025-07-10	CREACION	Importado desde Excel	CANCELADA	1	\N	2026-02-03 19:59:33.209583	2611-2025	8780-2025	2025-07-10
814	194	2025-07-12	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	236-2025	S/N	2025-07-12
815	679	2025-07-12	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	236-2025	S/N	2025-07-12
816	15	2025-07-12	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	236-2025	S/N	2025-07-12
817	43	2025-07-12	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	236-2025	S/N	2025-07-12
818	680	2025-07-15	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	188-2025	9030-2025	2025-07-15
819	681	2025-07-15	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	191-2025	9031-2025	2025-07-15
820	682	2025-07-15	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	191-2025	9031-2025	2025-07-15
821	683	2025-07-15	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	128-2025	9028-2025	2025-07-15
822	143	2025-07-15	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	128-2025	9028-2025	2025-07-15
823	684	2025-07-22	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	132-2025	9364-2025	2025-07-22
824	358	2025-07-04	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	252-2025	9362-2025	2025-07-04
825	685	2025-07-04	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	252-2025	9362-2025	2025-07-04
826	686	2025-07-04	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	252-2025	9362-2025	2025-07-04
827	687	2025-07-04	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	252-2025	9362-2025	2025-07-04
828	378	2025-07-26	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	250-2025	9487-2025	2025-07-26
829	374	2025-07-26	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	250-2025	9487-2025	2025-07-26
830	75	2025-07-26	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	250-2025	9487-2025	2025-07-26
831	405	2025-07-26	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	250-2025	9487-2025	2025-07-26
832	335	2025-07-26	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	250-2025	9487-2025	2025-07-26
833	390	2025-07-26	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	250-2025	9487-2025	2025-07-26
834	117	2025-07-26	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	250-2025	9487-2025	2025-07-26
835	465	2025-07-26	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	250-2025	9487-2025	2025-07-26
836	138	2025-07-26	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	250-2025	9487-2025	2025-07-26
837	229	2025-07-26	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	250-2025	9487-2025	2025-07-26
838	289	2025-07-26	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	250-2025	9487-2025	2025-07-26
839	688	2025-08-03	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	287-2025	53086-2025	2025-08-03
840	432	2025-08-15	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	968-2025	\N	2025-08-15
841	689	2025-08-21	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	\N	\N	2025-08-21
842	690	2025-08-21	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	3532-2025	10884-2025	2025-08-21
843	459	2025-08-21	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	298-2025	S/N	2025-08-21
844	447	2025-08-21	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	298-2025	S/N	2025-08-21
845	187	2025-08-13	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1294-2025	11297-2025	2025-08-13
846	79	2025-08-13	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1294-2025	11297-2025	2025-08-13
847	298	2025-08-13	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1294-2025	11297-2025	2025-08-13
848	691	2025-08-29	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	497-2025	\N	2025-08-29
849	103	2025-09-02	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1040-2025	11561-2025	2025-09-02
850	126	2025-09-02	ACTUALIZACION	Importado desde Excel	CANCELADA	1	\N	2026-02-03 19:59:33.209583	1040-2025	11561-2025	2025-09-02
851	692	2025-09-02	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1040-2025	11561-2025	2025-09-02
852	485	2025-09-02	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1040-2025	11561-2025	2025-09-02
853	130	2025-09-02	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1040-2025	11561-2025	2025-09-02
854	442	2025-09-02	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1040-2025	11561-2025	2025-09-02
855	693	2025-09-02	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1040-2025	11561-2025	2025-09-02
856	153	2025-09-02	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1040-2025	11561-2025	2025-09-02
857	694	2025-09-02	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1040-2025	11561-2025	2025-09-02
858	695	2025-09-02	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4021-2025	11507-2025	2025-09-02
859	696	2025-09-02	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4021-2025	11507-2025	2025-09-02
860	697	2025-09-02	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	4021-2025	11507-2025	2025-09-02
861	698	2025-09-02	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4021-2025	11507-2025	2025-09-02
862	699	2025-09-02	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	4021-2025	11507-2025	2025-09-02
863	700	2025-09-02	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4021-2025	11507-2025	2025-09-02
864	701	2025-09-02	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4021-2025	11507-2025	2025-09-02
865	702	2025-09-02	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4021-2025	11507-2025	2025-09-02
866	703	2025-09-02	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4021-2025	11507-2025	2025-09-02
867	704	2025-09-02	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4021-2025	11507-2025	2025-09-02
868	705	2025-09-02	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4021-2025	11507-2025	2025-09-02
869	706	2025-09-02	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4021-2025	11507-2025	2025-09-02
870	707	2025-09-02	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4021-2025	11507-2025	2025-09-02
871	708	2025-09-02	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4021-2025	11507-2025	2025-09-02
872	709	2025-09-02	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4021-2025	11507-2025	2025-09-02
873	710	2025-09-02	CREACION	Importado desde Excel	CANCELADA	1	\N	2026-02-03 19:59:33.209583	4021-2025	11507-2025	2025-09-02
874	711	2025-09-02	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4021-2025	11507-2025	2025-09-02
875	712	2025-09-02	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	4021-2025	11507-2025	2025-09-02
876	713	2025-09-02	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4021-2025	11507-2025	2025-09-02
877	714	2025-09-02	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	4021-2025	11507-2025	2025-09-02
878	715	2025-09-02	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4021-2025	11507-2025	2025-09-02
879	716	2025-09-02	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4021-2025	11507-2025	2025-09-02
880	717	2025-09-02	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4021-2025	11507-2025	2025-09-02
881	718	2025-09-02	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4021-2025	11507-2025	2025-09-02
882	630	2025-09-02	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4021-2025	11507-2025	2025-09-02
883	719	2025-09-02	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4021-2025	11507-2025	2025-09-02
884	720	2025-09-02	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4021-2025	11507-2025	2025-09-02
885	721	2025-09-02	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4021-2025	11507-2025	2025-09-02
886	722	2025-09-09	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	374-2025	62083-2025	2025-09-09
887	316	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4020-2025	11449-2025	2025-09-11
888	723	2025-09-11	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4020-2025	11449-2025	2025-09-11
889	294	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4020-2025	11449-2025	2025-09-11
890	162	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4020-2025	11449-2025	2025-09-11
891	270	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4020-2025	11449-2025	2025-09-11
892	290	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4020-2025	11449-2025	2025-09-11
893	258	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4020-2025	11449-2025	2025-09-11
894	154	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4020-2025	11449-2025	2025-09-11
895	330	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4020-2025	11449-2025	2025-09-11
896	426	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4020-2025	11449-2025	2025-09-11
897	322	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4020-2025	11449-2025	2025-09-11
898	340	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4020-2025	11449-2025	2025-09-11
899	74	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4020-2025	11449-2025	2025-09-11
900	364	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4020-2025	11449-2025	2025-09-11
901	366	2025-09-11	ACTUALIZACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	4020-2025	11449-2025	2025-09-11
902	420	2025-09-11	ACTUALIZACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	4020-2025	11449-2025	2025-09-11
903	305	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4020-2025	11449-2025	2025-09-11
904	355	2025-09-11	ACTUALIZACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	4020-2025	11449-2025	2025-09-11
905	314	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4020-2025	11449-2025	2025-09-11
906	456	2025-09-11	ACTUALIZACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	4020-2025	11449-2025	2025-09-11
907	156	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4020-2025	11449-2025	2025-09-11
908	25	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4020-2025	11449-2025	2025-09-11
909	468	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4020-2025	11449-2025	2025-09-11
910	253	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4020-2025	11449-2025	2025-09-11
911	142	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4020-2025	11449-2025	2025-09-11
912	295	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4020-2025	11449-2025	2025-09-11
913	392	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4020-2025	11449-2025	2025-09-11
914	724	2025-09-11	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4020-2025	11449-2025	2025-09-11
915	725	2025-09-11	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4020-2025	11449-2025	2025-09-11
916	726	2025-09-11	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4020-2025	11449-2025	2025-09-11
917	727	2025-09-11	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4020-2025	11449-2025	2025-09-11
918	728	2025-09-11	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4020-2025	11449-2025	2025-09-11
919	124	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2878-2025	S/N	2025-09-11
920	14	2025-09-11	ACTUALIZACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2878-2025	S/N	2025-09-11
921	259	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2878-2025	S/N	2025-09-11
922	729	2025-09-11	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2878-2025	S/N	2025-09-11
923	174	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2878-2025	S/N	2025-09-11
924	484	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2878-2025	S/N	2025-09-11
925	169	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2878-2025	S/N	2025-09-11
926	219	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2878-2025	S/N	2025-09-11
927	87	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2878-2025	S/N	2025-09-11
928	227	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2878-2025	S/N	2025-09-11
929	357	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2878-2025	S/N	2025-09-11
930	730	2025-09-11	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2878-2025	S/N	2025-09-11
931	394	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2878-2025	S/N	2025-09-11
932	7	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2878-2025	S/N	2025-09-11
933	731	2025-09-11	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	2878-2025	S/N	2025-09-11
934	319	2025-09-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2878-2025	S/N	2025-09-11
935	732	2025-09-11	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2878-2025	S/N	2025-09-11
936	733	2025-09-11	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2878-2025	S/N	2025-09-11
937	734	2025-09-13	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	1950-2025	2025-09-13
938	126	2025-09-23	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	758-2025	S/N	2025-09-23
939	113	2025-10-04	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	2021-2025	s/N	2025-10-04
940	735	2025-10-14	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4661-2025	S/N	2025-10-14
941	132	2025-10-14	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4662-2025	S/N	2025-10-14
942	736	2025-10-05	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	11600-2025	S/N	2025-10-05
943	737	2025-10-01	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	289-2025	12934-2025	2025-10-01
944	352	2025-10-14	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4662-2025	S/N	2025-10-14
945	349	2025-10-14	ACTUALIZACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	4662-2025	S/N	2025-10-14
946	482	2025-10-14	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4662-2025	S/N	2025-10-14
947	167	2025-10-14	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4662-2025	S/N	2025-10-14
948	456	2025-10-17	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4279-2025	S/N	2025-10-17
949	429	2025-10-14	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4662-2025	S/N	2025-10-14
950	6	2025-10-15	ACTUALIZACION	Importado desde Excel	CANCELADA	1	\N	2026-02-03 19:59:33.209583	4662-2026	S/N	2025-10-15
951	500	2025-10-16	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4662-2027	S/N	2025-10-16
952	200	2025-10-17	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4662-2028	S/N	2025-10-17
953	71	2025-10-18	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4662-2029	S/N	2025-10-18
954	501	2025-10-19	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4662-2030	S/N	2025-10-19
955	221	2025-10-20	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4662-2031	S/N	2025-10-20
956	462	2025-10-21	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4662-2032	S/N	2025-10-21
957	52	2025-10-22	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4662-2033	S/N	2025-10-22
958	738	2025-10-23	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4662-2034	S/N	2025-10-23
959	455	2025-10-24	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4662-2035	S/N	2025-10-24
960	739	2025-10-17	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4156-2025	S/N	2025-10-17
961	740	2025-10-19	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-10-19
962	741	2025-10-20	ACTUALIZACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-10-20
963	742	2025-10-21	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-10-21
964	743	2025-10-22	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-10-22
965	744	2025-10-23	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-10-23
966	148	2025-10-24	ACTUALIZACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-10-24
967	745	2025-10-25	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-10-25
968	746	2025-10-26	ACTUALIZACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-10-26
969	747	2025-10-27	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-10-27
970	748	2025-10-28	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-10-28
971	749	2025-10-29	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-10-29
972	750	2025-10-30	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-10-30
973	751	2025-10-31	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-10-31
974	752	2025-11-01	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-11-01
975	214	2025-11-02	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-11-02
976	753	2025-11-03	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-11-03
977	754	2025-11-04	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-11-04
978	755	2025-11-05	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-11-05
979	499	2024-12-08	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4029-2024	12145-2024	2024-12-08
980	756	2025-11-05	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-11-05
981	281	2025-11-05	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-11-05
982	20	2025-11-05	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-11-05
983	180	2025-11-05	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-11-05
984	359	2025-11-05	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-11-05
985	204	2025-11-05	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-11-05
986	399	2025-11-05	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-11-05
987	58	2025-11-05	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-11-05
988	277	2025-11-05	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-11-05
989	158	2025-11-05	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-11-05
990	201	2025-11-05	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-11-05
991	242	2025-11-05	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-11-05
992	160	2025-11-05	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-11-05
993	185	2025-11-05	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-11-05
994	435	2025-11-05	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-11-05
995	175	2025-11-05	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-11-05
996	121	2025-11-05	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-11-05
997	336	2025-11-05	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	S/N	2025-11-05
998	757	2025-11-25	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	195-2025	S/N	2025-11-25
999	471	2025-11-26	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	195-2025	S/N	2025-11-26
1000	31	2025-11-27	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	195-2025	S/N	2025-11-27
1001	758	2025-11-28	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	195-2025	S/N	2025-11-28
1002	759	2025-11-29	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	195-2025	S/N	2025-11-29
1003	760	2025-11-30	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	195-2025	S/N	2025-11-30
1004	337	2025-12-01	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	195-2025	S/N	2025-12-01
1005	761	2025-12-02	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	195-2025	S/N	2025-12-02
1006	395	2025-10-27	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	982-2025	13502	2025-10-27
1007	235	2025-10-28	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	982-2025	13502	2025-10-28
1008	127	2025-10-29	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	982-2025	13502	2025-10-29
1009	302	2025-10-30	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	982-2025	13502	2025-10-30
1010	416	2025-10-31	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	982-2025	13502	2025-10-31
1011	762	2025-10-24	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	1426-2025	S/N	2025-10-24
1012	763	2025-10-24	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	1426-2025	S/N	2025-10-24
1013	764	2025-10-24	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1426-2025	S/N	2025-10-24
1014	765	2025-10-24	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1426-2025	S/N	2025-10-24
1015	766	2025-10-24	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1426-2025	S/N	2025-10-24
1016	767	2025-10-24	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1426-2025	S/N	2025-10-24
1017	768	2025-10-24	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1426-2025	S/N	2025-10-24
1018	769	2025-10-24	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1426-2025	S/N	2025-10-24
1019	770	2025-10-24	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1426-2025	S/N	2025-10-24
1020	771	2025-10-24	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1426-2025	S/N	2025-10-24
1021	772	2025-10-24	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	1426-2025	S/N	2025-10-24
1022	773	2025-10-24	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1426-2025	S/N	2025-10-24
1023	774	2025-10-24	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1426-2025	S/N	2025-10-24
1024	775	2025-10-24	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1426-2025	S/N	2025-10-24
1025	776	2025-10-24	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1426-2025	S/N	2025-10-24
1026	777	2025-10-29	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1631-2025	S/N	2025-10-29
1027	778	2025-10-29	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1631-2025	S/N	2025-10-29
1028	779	2025-10-29	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1428-2025	S/N	2025-10-29
1029	780	2025-10-30	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1428-2025	S/N	2025-10-30
1030	781	2025-10-31	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1428-2025	S/N	2025-10-31
1031	782	2025-11-06	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4998-2025	14726-2025	2025-11-06
1032	443	2025-11-06	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4998-2025	14726-2025	2025-11-06
1033	783	2025-10-31	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	4999-2025	14513-2025	2025-10-31
1034	149	2025-10-19	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	289-2025	2025-10-19
1035	182	2025-10-19	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1427-2025	289-2025	2025-10-19
1036	445	2025-12-01	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	15916-2025	2025-12-01
1037	784	2025-11-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1200-2025	S/N	2025-11-27
1038	785	2025-11-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1200-2025	S/N	2025-11-27
1039	786	2025-11-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1200-2025	S/N	2025-11-27
1040	787	2025-11-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1200-2025	S/N	2025-11-27
1041	788	2025-11-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1200-2025	S/N	2025-11-27
1042	789	2025-11-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1200-2025	S/N	2025-11-27
1043	790	2025-11-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1200-2025	S/N	2025-11-27
1044	791	2025-11-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1200-2025	S/N	2025-11-27
1045	792	2025-11-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1200-2025	S/N	2025-11-27
1046	793	2025-12-27	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1200-2025	S/N	2025-12-27
1047	433	2025-12-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1190-2025	S/N	2025-12-11
1048	794	2025-12-30	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1190-2025	S/N	2025-12-30
1049	102	2025-12-12	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1190-2025	S/N	2025-12-12
1050	207	2026-01-02	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1190-2025	S/N	2026-01-02
1051	310	2025-12-16	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1190-2025	S/N	2025-12-16
1052	46	2026-01-02	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1190-2025	S/N	2026-01-02
1053	795	2025-12-27	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1190-2025	S/N	2025-12-27
1054	273	2025-12-16	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1190-2025	S/N	2025-12-16
1055	237	2025-12-16	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1190-2025	S/N	2025-12-16
1056	72	2025-12-30	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1190-2025	S/N	2025-12-30
1057	342	2024-01-01	ACTUALIZACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	1190-2025	S/N	2024-01-01
1058	70	2024-01-01	ACTUALIZACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	1190-2025	S/N	2024-01-01
1059	312	2025-12-26	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1190-2025	S/N	2025-12-26
1060	235	2024-01-01	ACTUALIZACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	1190-2025	S/N	2024-01-01
1061	210	2025-12-11	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1190-2025	S/N	2025-12-11
1062	189	2026-01-05	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1190-2025	S/N	2026-01-05
1063	796	2025-12-18	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1190-2025	S/N	2025-12-18
1064	55	2025-12-12	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1190-2025	S/N	2025-12-12
1065	384	2026-01-05	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1190-2025	S/N	2026-01-05
1066	91	2025-12-27	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1190-2025	S/N	2025-12-27
1067	320	2025-12-12	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1288-2025	S/N	2025-12-12
1068	12	2025-12-12	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1288-2025	S/N	2025-12-12
1069	797	2025-12-08	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	620-2025	16226-2025	2025-12-08
1070	798	2025-12-08	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	620-2025	16226-2025	2025-12-08
1071	799	2025-12-08	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	620-2025	16226-2025	2025-12-08
1072	800	2025-12-08	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	620-2025	16226-2025	2025-12-08
1073	801	2025-12-08	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	620-2025	16226-2025	2025-12-08
1074	802	2025-12-08	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	620-2025	16226-2025	2025-12-08
1075	803	2025-12-08	ACTUALIZACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	620-2025	16226-2025	2025-12-08
1076	315	2025-12-12	ACTUALIZACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	5701-2025	16717-2025	2025-12-12
1077	21	2025-12-12	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	5701-2025	16717-2025	2025-12-12
1078	804	2025-12-12	ACTUALIZACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	5701-2025	16717-2025	2025-12-12
1079	805	2025-12-12	ACTUALIZACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	5701-2025	16717-2025	2025-12-12
1080	806	2025-12-12	ACTUALIZACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	5701-2025	16717-2025	2025-12-12
1081	291	2025-12-12	ACTUALIZACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	5701-2025	16717-2025	2025-12-12
1082	436	2025-12-12	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	5701-2025	16717-2025	2025-12-12
1083	367	2025-12-12	ACTUALIZACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	5701-2025	16717-2025	2025-12-12
1084	19	2025-12-12	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	5701-2025	16717-2025	2025-12-12
1085	186	2025-12-12	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	5701-2025	16717-2025	2025-12-12
1086	400	2025-12-12	ACTUALIZACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	5701-2025	16717-2025	2025-12-12
1087	713	2025-12-12	ACTUALIZACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	5701-2025	16717-2025	2025-12-12
1088	562	2025-12-12	ACTUALIZACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	5701-2025	16717-2025	2025-12-12
1089	438	2025-12-12	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	5701-2025	16717-2025	2025-12-12
1090	807	2025-12-18	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	5698-2025	16754-2025	2025-12-18
1091	808	2025-12-19	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	5698-2026	16754-2026	2025-12-19
1092	696	2025-12-20	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	5698-2027	16754-2027	2025-12-20
1093	809	2025-12-21	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	5698-2028	16754-2028	2025-12-21
1094	810	2025-12-22	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	5698-2029	16754-2029	2025-12-22
1095	811	2025-12-23	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	5698-2030	16754-2030	2025-12-23
1096	812	2025-12-30	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	272-2025	s/n	2025-12-30
1097	813	2025-12-29	ACTUALIZACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2025-12-29
1098	814	2025-12-30	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	840-2025	17114-2025	2025-12-30
1099	815	2025-12-30	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	840-2025	17114-2025	2025-12-30
1100	816	2025-12-30	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	840-2025	17114-2025	2025-12-30
1101	817	2025-12-30	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	840-2025	17114-2025	2025-12-30
1102	818	2025-12-30	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	840-2025	17114-2025	2025-12-30
1103	819	2025-12-30	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	840-2025	17114-2025	2025-12-30
1104	820	2025-12-29	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	S/N	S/N	2025-12-29
1105	821	2026-01-08	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1846-2025	16148-2025	2026-01-08
1106	822	2026-01-08	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1846-2025	16148-2025	2026-01-08
1107	823	2026-01-08	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1846-2025	16148-2025	2026-01-08
1108	824	2026-01-08	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1846-2025	16148-2025	2026-01-08
1109	825	2026-01-14	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1846-2025	16148-2025	2026-01-14
1110	826	2026-01-08	CREACION	Importado desde Excel	APROBADA	1	\N	2026-02-03 19:59:33.209583	1846-2025	16148-2025	2026-01-08
1111	827	2026-01-08	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	1846-2025	16148-2025	2026-01-08
1112	828	2026-01-08	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	1846-2025	16148-2025	2026-01-08
1113	829	2026-01-08	CREACION	Importado desde Excel	PENDIENTE	1	\N	2026-02-03 19:59:33.209583	1846-2025	16148-2025	2026-01-08
\.


--
-- TOC entry 5103 (class 0 OID 16401)
-- Dependencies: 216
-- Data for Name: usuarios_sistema; Type: TABLE DATA; Schema: public; Owner: vpn_user
--

COPY public.usuarios_sistema (id, username, password_hash, nombre_completo, email, rol, activo, fecha_creacion, fecha_ultimo_login) FROM stdin;
2	jcate	$2b$12$Cbcy2EBcl4Xt9.NOLXoxkunKz.k3GrDcC6dGCIP5FywP25NS4lMSe	JONATHAN MIGUEL CATE CATU	jonxycate@gmail.com	ADMIN	t	2026-01-10 12:55:39.961993	2026-02-03 16:58:57.24869
1	admin	$2b$12$iq7h5i.pBClxAHHxYscC4uIm6HWVutjnDiMMk1n9.5y5Y6PfAbWmG	Administrador del Sistema	admin@institucion.gob.gt	SUPERADMIN	t	2025-12-29 12:08:57.844089	2026-02-04 01:59:21.847803
\.


--
-- TOC entry 5211 (class 0 OID 0)
-- Dependencies: 221
-- Name: accesos_vpn_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vpn_user
--

SELECT pg_catalog.setval('public.accesos_vpn_id_seq', 1004, true);


--
-- TOC entry 5212 (class 0 OID 0)
-- Dependencies: 233
-- Name: alertas_sistema_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vpn_user
--

SELECT pg_catalog.setval('public.alertas_sistema_id_seq', 1, false);


--
-- TOC entry 5213 (class 0 OID 0)
-- Dependencies: 227
-- Name: archivos_adjuntos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vpn_user
--

SELECT pg_catalog.setval('public.archivos_adjuntos_id_seq', 1, false);


--
-- TOC entry 5214 (class 0 OID 0)
-- Dependencies: 231
-- Name: auditoria_eventos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vpn_user
--

SELECT pg_catalog.setval('public.auditoria_eventos_id_seq', 418, true);


--
-- TOC entry 5215 (class 0 OID 0)
-- Dependencies: 223
-- Name: bloqueos_vpn_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vpn_user
--

SELECT pg_catalog.setval('public.bloqueos_vpn_id_seq', 436, true);


--
-- TOC entry 5216 (class 0 OID 0)
-- Dependencies: 225
-- Name: cartas_responsabilidad_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vpn_user
--

SELECT pg_catalog.setval('public.cartas_responsabilidad_id_seq', 993, true);


--
-- TOC entry 5217 (class 0 OID 0)
-- Dependencies: 239
-- Name: catalogos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vpn_user
--

SELECT pg_catalog.setval('public.catalogos_id_seq', 7, true);


--
-- TOC entry 5218 (class 0 OID 0)
-- Dependencies: 229
-- Name: comentarios_admin_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vpn_user
--

SELECT pg_catalog.setval('public.comentarios_admin_id_seq', 1, false);


--
-- TOC entry 5219 (class 0 OID 0)
-- Dependencies: 237
-- Name: configuracion_sistema_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vpn_user
--

SELECT pg_catalog.setval('public.configuracion_sistema_id_seq', 4, true);


--
-- TOC entry 5220 (class 0 OID 0)
-- Dependencies: 235
-- Name: importaciones_excel_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vpn_user
--

SELECT pg_catalog.setval('public.importaciones_excel_id_seq', 1, false);


--
-- TOC entry 5221 (class 0 OID 0)
-- Dependencies: 217
-- Name: personas_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vpn_user
--

SELECT pg_catalog.setval('public.personas_id_seq', 829, true);


--
-- TOC entry 5222 (class 0 OID 0)
-- Dependencies: 241
-- Name: sesiones_login_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vpn_user
--

SELECT pg_catalog.setval('public.sesiones_login_id_seq', 1, false);


--
-- TOC entry 5223 (class 0 OID 0)
-- Dependencies: 219
-- Name: solicitudes_vpn_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vpn_user
--

SELECT pg_catalog.setval('public.solicitudes_vpn_id_seq', 1113, true);


--
-- TOC entry 5224 (class 0 OID 0)
-- Dependencies: 215
-- Name: usuarios_sistema_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vpn_user
--

SELECT pg_catalog.setval('public.usuarios_sistema_id_seq', 2, true);


--
-- TOC entry 4884 (class 2606 OID 16460)
-- Name: accesos_vpn accesos_vpn_pkey; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.accesos_vpn
    ADD CONSTRAINT accesos_vpn_pkey PRIMARY KEY (id);


--
-- TOC entry 4920 (class 2606 OID 16571)
-- Name: alertas_sistema alertas_sistema_pkey; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.alertas_sistema
    ADD CONSTRAINT alertas_sistema_pkey PRIMARY KEY (id);


--
-- TOC entry 4905 (class 2606 OID 16519)
-- Name: archivos_adjuntos archivos_adjuntos_pkey; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.archivos_adjuntos
    ADD CONSTRAINT archivos_adjuntos_pkey PRIMARY KEY (id);


--
-- TOC entry 4913 (class 2606 OID 16555)
-- Name: auditoria_eventos auditoria_eventos_pkey; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.auditoria_eventos
    ADD CONSTRAINT auditoria_eventos_pkey PRIMARY KEY (id);


--
-- TOC entry 4892 (class 2606 OID 16481)
-- Name: bloqueos_vpn bloqueos_vpn_pkey; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.bloqueos_vpn
    ADD CONSTRAINT bloqueos_vpn_pkey PRIMARY KEY (id);


--
-- TOC entry 4898 (class 2606 OID 16499)
-- Name: cartas_responsabilidad cartas_responsabilidad_pkey; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.cartas_responsabilidad
    ADD CONSTRAINT cartas_responsabilidad_pkey PRIMARY KEY (id);


--
-- TOC entry 4932 (class 2606 OID 16620)
-- Name: catalogos catalogos_pkey; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.catalogos
    ADD CONSTRAINT catalogos_pkey PRIMARY KEY (id);


--
-- TOC entry 4934 (class 2606 OID 16622)
-- Name: catalogos catalogos_tipo_codigo_key; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.catalogos
    ADD CONSTRAINT catalogos_tipo_codigo_key UNIQUE (tipo, codigo);


--
-- TOC entry 4909 (class 2606 OID 16540)
-- Name: comentarios_admin comentarios_admin_pkey; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.comentarios_admin
    ADD CONSTRAINT comentarios_admin_pkey PRIMARY KEY (id);


--
-- TOC entry 4928 (class 2606 OID 16607)
-- Name: configuracion_sistema configuracion_sistema_clave_key; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.configuracion_sistema
    ADD CONSTRAINT configuracion_sistema_clave_key UNIQUE (clave);


--
-- TOC entry 4930 (class 2606 OID 16605)
-- Name: configuracion_sistema configuracion_sistema_pkey; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.configuracion_sistema
    ADD CONSTRAINT configuracion_sistema_pkey PRIMARY KEY (id);


--
-- TOC entry 4926 (class 2606 OID 16589)
-- Name: importaciones_excel importaciones_excel_pkey; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.importaciones_excel
    ADD CONSTRAINT importaciones_excel_pkey PRIMARY KEY (id);


--
-- TOC entry 4872 (class 2606 OID 16427)
-- Name: personas personas_dpi_key; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.personas
    ADD CONSTRAINT personas_dpi_key UNIQUE (dpi);


--
-- TOC entry 4874 (class 2606 OID 16425)
-- Name: personas personas_pkey; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.personas
    ADD CONSTRAINT personas_pkey PRIMARY KEY (id);


--
-- TOC entry 4939 (class 2606 OID 16633)
-- Name: sesiones_login sesiones_login_pkey; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.sesiones_login
    ADD CONSTRAINT sesiones_login_pkey PRIMARY KEY (id);


--
-- TOC entry 4882 (class 2606 OID 16439)
-- Name: solicitudes_vpn solicitudes_vpn_pkey; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.solicitudes_vpn
    ADD CONSTRAINT solicitudes_vpn_pkey PRIMARY KEY (id);


--
-- TOC entry 4863 (class 2606 OID 16412)
-- Name: usuarios_sistema usuarios_sistema_pkey; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.usuarios_sistema
    ADD CONSTRAINT usuarios_sistema_pkey PRIMARY KEY (id);


--
-- TOC entry 4865 (class 2606 OID 16414)
-- Name: usuarios_sistema usuarios_sistema_username_key; Type: CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.usuarios_sistema
    ADD CONSTRAINT usuarios_sistema_username_key UNIQUE (username);


--
-- TOC entry 4885 (class 1259 OID 16651)
-- Name: idx_accesos_estado; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_accesos_estado ON public.accesos_vpn USING btree (estado_vigencia);


--
-- TOC entry 4886 (class 1259 OID 16652)
-- Name: idx_accesos_fecha_fin; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_accesos_fecha_fin ON public.accesos_vpn USING btree (fecha_fin);


--
-- TOC entry 4887 (class 1259 OID 16653)
-- Name: idx_accesos_fecha_inicio; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_accesos_fecha_inicio ON public.accesos_vpn USING btree (fecha_inicio);


--
-- TOC entry 4888 (class 1259 OID 16654)
-- Name: idx_accesos_gracia; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_accesos_gracia ON public.accesos_vpn USING btree (fecha_fin_con_gracia);


--
-- TOC entry 4889 (class 1259 OID 16650)
-- Name: idx_accesos_solicitud; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_accesos_solicitud ON public.accesos_vpn USING btree (solicitud_id);


--
-- TOC entry 4890 (class 1259 OID 24805)
-- Name: idx_accesos_vigencia_fecha; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_accesos_vigencia_fecha ON public.accesos_vpn USING btree (estado_vigencia, fecha_fin_con_gracia);


--
-- TOC entry 4921 (class 1259 OID 16672)
-- Name: idx_alertas_acceso; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_alertas_acceso ON public.alertas_sistema USING btree (acceso_vpn_id);


--
-- TOC entry 4922 (class 1259 OID 16671)
-- Name: idx_alertas_fecha; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_alertas_fecha ON public.alertas_sistema USING btree (fecha_generacion);


--
-- TOC entry 4923 (class 1259 OID 16670)
-- Name: idx_alertas_leida; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_alertas_leida ON public.alertas_sistema USING btree (leida);


--
-- TOC entry 4924 (class 1259 OID 16669)
-- Name: idx_alertas_tipo; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_alertas_tipo ON public.alertas_sistema USING btree (tipo);


--
-- TOC entry 4906 (class 1259 OID 16660)
-- Name: idx_archivos_carta; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_archivos_carta ON public.archivos_adjuntos USING btree (carta_id);


--
-- TOC entry 4907 (class 1259 OID 16661)
-- Name: idx_archivos_hash; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_archivos_hash ON public.archivos_adjuntos USING btree (hash_integridad);


--
-- TOC entry 4914 (class 1259 OID 16666)
-- Name: idx_auditoria_accion; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_auditoria_accion ON public.auditoria_eventos USING btree (accion);


--
-- TOC entry 4915 (class 1259 OID 16668)
-- Name: idx_auditoria_detalle; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_auditoria_detalle ON public.auditoria_eventos USING gin (detalle_json);


--
-- TOC entry 4916 (class 1259 OID 16667)
-- Name: idx_auditoria_entidad; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_auditoria_entidad ON public.auditoria_eventos USING btree (entidad, entidad_id);


--
-- TOC entry 4917 (class 1259 OID 16665)
-- Name: idx_auditoria_fecha; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_auditoria_fecha ON public.auditoria_eventos USING btree (fecha);


--
-- TOC entry 4918 (class 1259 OID 16664)
-- Name: idx_auditoria_usuario; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_auditoria_usuario ON public.auditoria_eventos USING btree (usuario_id);


--
-- TOC entry 4893 (class 1259 OID 16655)
-- Name: idx_bloqueos_acceso; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_bloqueos_acceso ON public.bloqueos_vpn USING btree (acceso_vpn_id);


--
-- TOC entry 4894 (class 1259 OID 16656)
-- Name: idx_bloqueos_estado; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_bloqueos_estado ON public.bloqueos_vpn USING btree (estado);


--
-- TOC entry 4895 (class 1259 OID 16657)
-- Name: idx_bloqueos_fecha; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_bloqueos_fecha ON public.bloqueos_vpn USING btree (fecha_cambio);


--
-- TOC entry 4896 (class 1259 OID 24806)
-- Name: idx_bloqueos_fecha_desc; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_bloqueos_fecha_desc ON public.bloqueos_vpn USING btree (acceso_vpn_id, fecha_cambio DESC);


--
-- TOC entry 4899 (class 1259 OID 24807)
-- Name: idx_cartas_anio; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_cartas_anio ON public.cartas_responsabilidad USING btree (anio_carta, numero_carta);


--
-- TOC entry 4900 (class 1259 OID 24804)
-- Name: idx_cartas_eliminada; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_cartas_eliminada ON public.cartas_responsabilidad USING btree (eliminada);


--
-- TOC entry 4901 (class 1259 OID 16658)
-- Name: idx_cartas_solicitud; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_cartas_solicitud ON public.cartas_responsabilidad USING btree (solicitud_id);


--
-- TOC entry 4902 (class 1259 OID 16659)
-- Name: idx_cartas_tipo; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_cartas_tipo ON public.cartas_responsabilidad USING btree (tipo);


--
-- TOC entry 4910 (class 1259 OID 16662)
-- Name: idx_comentarios_entidad; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_comentarios_entidad ON public.comentarios_admin USING btree (entidad, entidad_id);


--
-- TOC entry 4911 (class 1259 OID 16663)
-- Name: idx_comentarios_fecha; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_comentarios_fecha ON public.comentarios_admin USING btree (fecha);


--
-- TOC entry 4903 (class 1259 OID 24670)
-- Name: idx_numero_carta_anio; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE UNIQUE INDEX idx_numero_carta_anio ON public.cartas_responsabilidad USING btree (numero_carta, anio_carta);


--
-- TOC entry 4866 (class 1259 OID 16645)
-- Name: idx_personas_activo; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_personas_activo ON public.personas USING btree (activo);


--
-- TOC entry 4867 (class 1259 OID 16644)
-- Name: idx_personas_apellidos; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_personas_apellidos ON public.personas USING btree (apellidos);


--
-- TOC entry 4868 (class 1259 OID 16642)
-- Name: idx_personas_dpi; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_personas_dpi ON public.personas USING btree (dpi);


--
-- TOC entry 4869 (class 1259 OID 16691)
-- Name: idx_personas_nip; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_personas_nip ON public.personas USING btree (nip);


--
-- TOC entry 4870 (class 1259 OID 16643)
-- Name: idx_personas_nombres; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_personas_nombres ON public.personas USING btree (nombres);


--
-- TOC entry 4935 (class 1259 OID 16674)
-- Name: idx_sesiones_activa; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_sesiones_activa ON public.sesiones_login USING btree (activa);


--
-- TOC entry 4936 (class 1259 OID 16675)
-- Name: idx_sesiones_fecha; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_sesiones_fecha ON public.sesiones_login USING btree (fecha_inicio);


--
-- TOC entry 4937 (class 1259 OID 16673)
-- Name: idx_sesiones_usuario; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_sesiones_usuario ON public.sesiones_login USING btree (usuario_id);


--
-- TOC entry 4875 (class 1259 OID 16647)
-- Name: idx_solicitudes_estado; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_solicitudes_estado ON public.solicitudes_vpn USING btree (estado);


--
-- TOC entry 4876 (class 1259 OID 16648)
-- Name: idx_solicitudes_fecha; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_solicitudes_fecha ON public.solicitudes_vpn USING btree (fecha_solicitud);


--
-- TOC entry 4877 (class 1259 OID 16692)
-- Name: idx_solicitudes_oficio; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_solicitudes_oficio ON public.solicitudes_vpn USING btree (numero_oficio);


--
-- TOC entry 4878 (class 1259 OID 16646)
-- Name: idx_solicitudes_persona; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_solicitudes_persona ON public.solicitudes_vpn USING btree (persona_id);


--
-- TOC entry 4879 (class 1259 OID 16693)
-- Name: idx_solicitudes_providencia; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_solicitudes_providencia ON public.solicitudes_vpn USING btree (numero_providencia);


--
-- TOC entry 4880 (class 1259 OID 16649)
-- Name: idx_solicitudes_tipo; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_solicitudes_tipo ON public.solicitudes_vpn USING btree (tipo_solicitud);


--
-- TOC entry 4860 (class 1259 OID 16641)
-- Name: idx_usuarios_activo; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_usuarios_activo ON public.usuarios_sistema USING btree (activo);


--
-- TOC entry 4861 (class 1259 OID 16640)
-- Name: idx_usuarios_username; Type: INDEX; Schema: public; Owner: vpn_user
--

CREATE INDEX idx_usuarios_username ON public.usuarios_sistema USING btree (username);


--
-- TOC entry 4956 (class 2620 OID 16679)
-- Name: accesos_vpn trigger_calcular_fecha_gracia; Type: TRIGGER; Schema: public; Owner: vpn_user
--

CREATE TRIGGER trigger_calcular_fecha_gracia BEFORE INSERT OR UPDATE ON public.accesos_vpn FOR EACH ROW EXECUTE FUNCTION public.calcular_fecha_gracia();


--
-- TOC entry 4942 (class 2606 OID 16461)
-- Name: accesos_vpn accesos_vpn_solicitud_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.accesos_vpn
    ADD CONSTRAINT accesos_vpn_solicitud_id_fkey FOREIGN KEY (solicitud_id) REFERENCES public.solicitudes_vpn(id);


--
-- TOC entry 4943 (class 2606 OID 16466)
-- Name: accesos_vpn accesos_vpn_usuario_creacion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.accesos_vpn
    ADD CONSTRAINT accesos_vpn_usuario_creacion_id_fkey FOREIGN KEY (usuario_creacion_id) REFERENCES public.usuarios_sistema(id);


--
-- TOC entry 4952 (class 2606 OID 16572)
-- Name: alertas_sistema alertas_sistema_acceso_vpn_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.alertas_sistema
    ADD CONSTRAINT alertas_sistema_acceso_vpn_id_fkey FOREIGN KEY (acceso_vpn_id) REFERENCES public.accesos_vpn(id);


--
-- TOC entry 4948 (class 2606 OID 16520)
-- Name: archivos_adjuntos archivos_adjuntos_carta_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.archivos_adjuntos
    ADD CONSTRAINT archivos_adjuntos_carta_id_fkey FOREIGN KEY (carta_id) REFERENCES public.cartas_responsabilidad(id);


--
-- TOC entry 4949 (class 2606 OID 16525)
-- Name: archivos_adjuntos archivos_adjuntos_usuario_subida_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.archivos_adjuntos
    ADD CONSTRAINT archivos_adjuntos_usuario_subida_id_fkey FOREIGN KEY (usuario_subida_id) REFERENCES public.usuarios_sistema(id);


--
-- TOC entry 4951 (class 2606 OID 16556)
-- Name: auditoria_eventos auditoria_eventos_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.auditoria_eventos
    ADD CONSTRAINT auditoria_eventos_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios_sistema(id);


--
-- TOC entry 4944 (class 2606 OID 16482)
-- Name: bloqueos_vpn bloqueos_vpn_acceso_vpn_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.bloqueos_vpn
    ADD CONSTRAINT bloqueos_vpn_acceso_vpn_id_fkey FOREIGN KEY (acceso_vpn_id) REFERENCES public.accesos_vpn(id);


--
-- TOC entry 4945 (class 2606 OID 16487)
-- Name: bloqueos_vpn bloqueos_vpn_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.bloqueos_vpn
    ADD CONSTRAINT bloqueos_vpn_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios_sistema(id);


--
-- TOC entry 4946 (class 2606 OID 16505)
-- Name: cartas_responsabilidad cartas_responsabilidad_generada_por_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.cartas_responsabilidad
    ADD CONSTRAINT cartas_responsabilidad_generada_por_usuario_id_fkey FOREIGN KEY (generada_por_usuario_id) REFERENCES public.usuarios_sistema(id);


--
-- TOC entry 4947 (class 2606 OID 16500)
-- Name: cartas_responsabilidad cartas_responsabilidad_solicitud_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.cartas_responsabilidad
    ADD CONSTRAINT cartas_responsabilidad_solicitud_id_fkey FOREIGN KEY (solicitud_id) REFERENCES public.solicitudes_vpn(id);


--
-- TOC entry 4950 (class 2606 OID 16541)
-- Name: comentarios_admin comentarios_admin_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.comentarios_admin
    ADD CONSTRAINT comentarios_admin_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios_sistema(id);


--
-- TOC entry 4954 (class 2606 OID 16608)
-- Name: configuracion_sistema configuracion_sistema_modificado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.configuracion_sistema
    ADD CONSTRAINT configuracion_sistema_modificado_por_fkey FOREIGN KEY (modificado_por) REFERENCES public.usuarios_sistema(id);


--
-- TOC entry 4953 (class 2606 OID 16590)
-- Name: importaciones_excel importaciones_excel_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.importaciones_excel
    ADD CONSTRAINT importaciones_excel_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios_sistema(id);


--
-- TOC entry 4955 (class 2606 OID 16634)
-- Name: sesiones_login sesiones_login_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.sesiones_login
    ADD CONSTRAINT sesiones_login_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios_sistema(id);


--
-- TOC entry 4940 (class 2606 OID 16440)
-- Name: solicitudes_vpn solicitudes_vpn_persona_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.solicitudes_vpn
    ADD CONSTRAINT solicitudes_vpn_persona_id_fkey FOREIGN KEY (persona_id) REFERENCES public.personas(id);


--
-- TOC entry 4941 (class 2606 OID 16445)
-- Name: solicitudes_vpn solicitudes_vpn_usuario_registro_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vpn_user
--

ALTER TABLE ONLY public.solicitudes_vpn
    ADD CONSTRAINT solicitudes_vpn_usuario_registro_id_fkey FOREIGN KEY (usuario_registro_id) REFERENCES public.usuarios_sistema(id);


--
-- TOC entry 5141 (class 0 OID 0)
-- Dependencies: 222
-- Name: TABLE accesos_vpn; Type: ACL; Schema: public; Owner: vpn_user
--

GRANT ALL ON TABLE public.accesos_vpn TO postgres;


--
-- TOC entry 5143 (class 0 OID 0)
-- Dependencies: 221
-- Name: SEQUENCE accesos_vpn_id_seq; Type: ACL; Schema: public; Owner: vpn_user
--

GRANT ALL ON SEQUENCE public.accesos_vpn_id_seq TO postgres;


--
-- TOC entry 5145 (class 0 OID 0)
-- Dependencies: 234
-- Name: TABLE alertas_sistema; Type: ACL; Schema: public; Owner: vpn_user
--

GRANT ALL ON TABLE public.alertas_sistema TO postgres;


--
-- TOC entry 5147 (class 0 OID 0)
-- Dependencies: 233
-- Name: SEQUENCE alertas_sistema_id_seq; Type: ACL; Schema: public; Owner: vpn_user
--

GRANT ALL ON SEQUENCE public.alertas_sistema_id_seq TO postgres;


--
-- TOC entry 5151 (class 0 OID 0)
-- Dependencies: 228
-- Name: TABLE archivos_adjuntos; Type: ACL; Schema: public; Owner: vpn_user
--

GRANT ALL ON TABLE public.archivos_adjuntos TO postgres;


--
-- TOC entry 5153 (class 0 OID 0)
-- Dependencies: 227
-- Name: SEQUENCE archivos_adjuntos_id_seq; Type: ACL; Schema: public; Owner: vpn_user
--

GRANT ALL ON SEQUENCE public.archivos_adjuntos_id_seq TO postgres;


--
-- TOC entry 5156 (class 0 OID 0)
-- Dependencies: 232
-- Name: TABLE auditoria_eventos; Type: ACL; Schema: public; Owner: vpn_user
--

GRANT ALL ON TABLE public.auditoria_eventos TO postgres;


--
-- TOC entry 5158 (class 0 OID 0)
-- Dependencies: 231
-- Name: SEQUENCE auditoria_eventos_id_seq; Type: ACL; Schema: public; Owner: vpn_user
--

GRANT ALL ON SEQUENCE public.auditoria_eventos_id_seq TO postgres;


--
-- TOC entry 5161 (class 0 OID 0)
-- Dependencies: 224
-- Name: TABLE bloqueos_vpn; Type: ACL; Schema: public; Owner: vpn_user
--

GRANT ALL ON TABLE public.bloqueos_vpn TO postgres;


--
-- TOC entry 5163 (class 0 OID 0)
-- Dependencies: 223
-- Name: SEQUENCE bloqueos_vpn_id_seq; Type: ACL; Schema: public; Owner: vpn_user
--

GRANT ALL ON SEQUENCE public.bloqueos_vpn_id_seq TO postgres;


--
-- TOC entry 5167 (class 0 OID 0)
-- Dependencies: 226
-- Name: TABLE cartas_responsabilidad; Type: ACL; Schema: public; Owner: vpn_user
--

GRANT ALL ON TABLE public.cartas_responsabilidad TO postgres;


--
-- TOC entry 5169 (class 0 OID 0)
-- Dependencies: 225
-- Name: SEQUENCE cartas_responsabilidad_id_seq; Type: ACL; Schema: public; Owner: vpn_user
--

GRANT ALL ON SEQUENCE public.cartas_responsabilidad_id_seq TO postgres;


--
-- TOC entry 5171 (class 0 OID 0)
-- Dependencies: 240
-- Name: TABLE catalogos; Type: ACL; Schema: public; Owner: vpn_user
--

GRANT ALL ON TABLE public.catalogos TO postgres;


--
-- TOC entry 5173 (class 0 OID 0)
-- Dependencies: 239
-- Name: SEQUENCE catalogos_id_seq; Type: ACL; Schema: public; Owner: vpn_user
--

GRANT ALL ON SEQUENCE public.catalogos_id_seq TO postgres;


--
-- TOC entry 5175 (class 0 OID 0)
-- Dependencies: 230
-- Name: TABLE comentarios_admin; Type: ACL; Schema: public; Owner: vpn_user
--

GRANT ALL ON TABLE public.comentarios_admin TO postgres;


--
-- TOC entry 5177 (class 0 OID 0)
-- Dependencies: 229
-- Name: SEQUENCE comentarios_admin_id_seq; Type: ACL; Schema: public; Owner: vpn_user
--

GRANT ALL ON SEQUENCE public.comentarios_admin_id_seq TO postgres;


--
-- TOC entry 5179 (class 0 OID 0)
-- Dependencies: 238
-- Name: TABLE configuracion_sistema; Type: ACL; Schema: public; Owner: vpn_user
--

GRANT ALL ON TABLE public.configuracion_sistema TO postgres;


--
-- TOC entry 5181 (class 0 OID 0)
-- Dependencies: 237
-- Name: SEQUENCE configuracion_sistema_id_seq; Type: ACL; Schema: public; Owner: vpn_user
--

GRANT ALL ON SEQUENCE public.configuracion_sistema_id_seq TO postgres;


--
-- TOC entry 5183 (class 0 OID 0)
-- Dependencies: 236
-- Name: TABLE importaciones_excel; Type: ACL; Schema: public; Owner: vpn_user
--

GRANT ALL ON TABLE public.importaciones_excel TO postgres;


--
-- TOC entry 5185 (class 0 OID 0)
-- Dependencies: 235
-- Name: SEQUENCE importaciones_excel_id_seq; Type: ACL; Schema: public; Owner: vpn_user
--

GRANT ALL ON SEQUENCE public.importaciones_excel_id_seq TO postgres;


--
-- TOC entry 5189 (class 0 OID 0)
-- Dependencies: 218
-- Name: TABLE personas; Type: ACL; Schema: public; Owner: vpn_user
--

GRANT ALL ON TABLE public.personas TO postgres;


--
-- TOC entry 5191 (class 0 OID 0)
-- Dependencies: 217
-- Name: SEQUENCE personas_id_seq; Type: ACL; Schema: public; Owner: vpn_user
--

GRANT ALL ON SEQUENCE public.personas_id_seq TO postgres;


--
-- TOC entry 5193 (class 0 OID 0)
-- Dependencies: 242
-- Name: TABLE sesiones_login; Type: ACL; Schema: public; Owner: vpn_user
--

GRANT ALL ON TABLE public.sesiones_login TO postgres;


--
-- TOC entry 5195 (class 0 OID 0)
-- Dependencies: 241
-- Name: SEQUENCE sesiones_login_id_seq; Type: ACL; Schema: public; Owner: vpn_user
--

GRANT ALL ON SEQUENCE public.sesiones_login_id_seq TO postgres;


--
-- TOC entry 5202 (class 0 OID 0)
-- Dependencies: 220
-- Name: TABLE solicitudes_vpn; Type: ACL; Schema: public; Owner: vpn_user
--

GRANT ALL ON TABLE public.solicitudes_vpn TO postgres;


--
-- TOC entry 5204 (class 0 OID 0)
-- Dependencies: 219
-- Name: SEQUENCE solicitudes_vpn_id_seq; Type: ACL; Schema: public; Owner: vpn_user
--

GRANT ALL ON SEQUENCE public.solicitudes_vpn_id_seq TO postgres;


--
-- TOC entry 5208 (class 0 OID 0)
-- Dependencies: 216
-- Name: TABLE usuarios_sistema; Type: ACL; Schema: public; Owner: vpn_user
--

GRANT ALL ON TABLE public.usuarios_sistema TO postgres;


--
-- TOC entry 5210 (class 0 OID 0)
-- Dependencies: 215
-- Name: SEQUENCE usuarios_sistema_id_seq; Type: ACL; Schema: public; Owner: vpn_user
--

GRANT ALL ON SEQUENCE public.usuarios_sistema_id_seq TO postgres;


--
-- TOC entry 2116 (class 826 OID 24826)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;


--
-- TOC entry 2115 (class 826 OID 24825)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO postgres;


-- Completed on 2026-02-03 20:00:27

--
-- PostgreSQL database dump complete
--

\unrestrict 8czH3YlB07WofLHRaJzdcm2NuKMKqemn3Y7uQ4kSgE1RabFxZRKIYfp607WbDTw

