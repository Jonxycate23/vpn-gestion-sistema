#!/bin/bash

# =====================================================
# SCRIPT MAESTRO DE INSTALACIÓN DE BASE DE DATOS
# Sistema de Gestión de Accesos VPN
# =====================================================

echo "=================================================="
echo "SISTEMA DE GESTIÓN DE ACCESOS VPN"
echo "Instalación de Base de Datos PostgreSQL"
echo "=================================================="
echo ""

# Configuración
DB_NAME="vpn_gestion"
DB_USER="postgres"
DB_HOST="localhost"
DB_PORT="5432"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para ejecutar SQL
execute_sql() {
    local file=$1
    local description=$2
    
    echo -e "${YELLOW}Ejecutando: ${description}...${NC}"
    
    if [ -f "$file" ]; then
        PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -f "$file"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Completado: ${description}${NC}"
        else
            echo -e "${RED}✗ Error en: ${description}${NC}"
            exit 1
        fi
    else
        echo -e "${RED}✗ Archivo no encontrado: ${file}${NC}"
        exit 1
    fi
    echo ""
}

# Verificar que PostgreSQL esté instalado
if ! command -v psql &> /dev/null; then
    echo -e "${RED}Error: PostgreSQL no está instalado${NC}"
    echo "Instalar con: sudo apt-get install postgresql postgresql-contrib"
    exit 1
fi

# Pedir contraseña del usuario postgres
echo -e "${YELLOW}Ingrese la contraseña del usuario postgres:${NC}"
read -s DB_PASSWORD
export PGPASSWORD=$DB_PASSWORD
echo ""

# Verificar conexión
echo -e "${YELLOW}Verificando conexión a PostgreSQL...${NC}"
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -c "SELECT version();" > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ No se pudo conectar a PostgreSQL${NC}"
    echo "Verifique que el servicio esté corriendo: sudo service postgresql status"
    exit 1
fi
echo -e "${GREEN}✓ Conexión exitosa${NC}"
echo ""

# Crear la base de datos
echo -e "${YELLOW}Creando base de datos...${NC}"
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -c "DROP DATABASE IF EXISTS $DB_NAME;" > /dev/null 2>&1
execute_sql "01_create_database.sql" "Crear base de datos"

# Cambiar a la nueva base de datos para ejecutar los siguientes scripts
export PGDATABASE=$DB_NAME

# Ejecutar scripts en orden
execute_sql "02_create_tables.sql" "Crear tablas"
execute_sql "03_create_indexes.sql" "Crear índices"
execute_sql "04_functions_triggers.sql" "Crear funciones y triggers"
execute_sql "05_initial_data.sql" "Cargar datos iniciales"

echo ""
echo "=================================================="
echo -e "${GREEN}✓ INSTALACIÓN COMPLETADA EXITOSAMENTE${NC}"
echo "=================================================="
echo ""
echo "Credenciales por defecto:"
echo "  Usuario: admin"
echo "  Contraseña: Admin123!"
echo ""
echo -e "${RED}¡IMPORTANTE!${NC}"
echo "  1. Cambiar la contraseña del usuario admin inmediatamente"
echo "  2. Crear usuarios adicionales según sea necesario"
echo "  3. Configurar backups automáticos"
echo "  4. Revisar la configuración en la tabla configuracion_sistema"
echo ""
echo "Base de datos: $DB_NAME"
echo "Host: $DB_HOST:$DB_PORT"
echo ""
echo "Para conectarse:"
echo "  psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME"
echo ""
echo "=================================================="
