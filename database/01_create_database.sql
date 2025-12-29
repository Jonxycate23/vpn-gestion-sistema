-- =====================================================
-- SISTEMA DE GESTIÓN DE ACCESOS VPN
-- Base de Datos PostgreSQL
-- Institución Pública - Intranet
-- =====================================================

-- Crear la base de datos (ejecutar como superusuario)
CREATE DATABASE vpn_gestion
    WITH
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'es_GT.UTF-8'
    LC_CTYPE = 'es_GT.UTF-8'
    TEMPLATE = template0;

-- Conectarse a la base de datos
\c vpn_gestion;

-- Crear extensiones útiles
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
