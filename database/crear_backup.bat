@echo off
REM ========================================
REM Script para crear backup de la base de datos VPN
REM ========================================

echo ========================================
echo BACKUP DE BASE DE DATOS - VPN GESTION
echo ========================================
echo.

REM Configuración
set DB_NAME=vpn_gestion
set DB_USER=postgres
set BACKUP_DIR=.\backups
set TIMESTAMP=%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set TIMESTAMP=%TIMESTAMP: =0%
set BACKUP_FILE=%BACKUP_DIR%\backup_vpn_gestion_%TIMESTAMP%.sql

REM Crear directorio de backups si no existe
if not exist "%BACKUP_DIR%" (
    echo Creando directorio de backups...
    mkdir "%BACKUP_DIR%"
)

echo.
echo Configuración:
echo - Base de datos: %DB_NAME%
echo - Usuario: %DB_USER%
echo - Archivo de salida: %BACKUP_FILE%
echo.

REM Ejecutar pg_dump
echo Generando backup...
echo.

pg_dump -h localhost -U %DB_USER% -F p -b -v -f "%BACKUP_FILE%" %DB_NAME%

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo ✅ BACKUP COMPLETADO EXITOSAMENTE
    echo ========================================
    echo.
    echo Archivo generado: %BACKUP_FILE%
    
    REM Mostrar tamaño del archivo
    for %%A in ("%BACKUP_FILE%") do (
        echo Tamaño: %%~zA bytes
    )
    
    echo.
    echo Para restaurar este backup, ejecuta:
    echo psql -h localhost -U %DB_USER% -d %DB_NAME% -f "%BACKUP_FILE%"
    echo.
) else (
    echo.
    echo ========================================
    echo ❌ ERROR AL GENERAR EL BACKUP
    echo ========================================
    echo.
    echo Verifica que:
    echo 1. PostgreSQL esté instalado y en el PATH
    echo 2. El usuario %DB_USER% tenga permisos
    echo 3. La base de datos %DB_NAME% exista
    echo.
)

pause
