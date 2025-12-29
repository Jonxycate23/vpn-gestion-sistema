# Guía de Inicio Rápido

## 🚀 Instalación en 5 Pasos

### 1️⃣ Instalar PostgreSQL

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install postgresql postgresql-contrib

# Iniciar servicio
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Verificar
sudo systemctl status postgresql
```

### 2️⃣ Crear Base de Datos

```bash
cd vpn-gestion-sistema/database
chmod +x install.sh
./install.sh
```

Cuando te pida la contraseña, usa la de tu usuario `postgres`.

**✅ Resultado esperado:**
- Base de datos `vpn_gestion` creada
- 14 tablas creadas
- Usuario `admin` con contraseña `Admin123!`

### 3️⃣ Configurar Backend

```bash
cd ../backend

# Crear entorno virtual
python3 -m venv venv
source venv/bin/activate

# Instalar dependencias
pip install -r requirements.txt

# Configurar .env
cp .env.example .env
nano .env
```

**Editar `.env`:**
```ini
DATABASE_URL=postgresql://postgres:TU_PASSWORD@localhost:5432/vpn_gestion
SECRET_KEY=corre_este_comando: openssl rand -hex 32
DEBUG=True
ENVIRONMENT=development
```

### 4️⃣ Probar Conexión

```bash
# Activar entorno virtual si no está activo
source venv/bin/activate

# Ejecutar backend
uvicorn main:app --reload
```

**✅ Deberías ver:**
```
INFO:     Uvicorn running on http://127.0.0.1:8000
INFO:     Application startup complete.
```

### 5️⃣ Verificar Instalación

Abre tu navegador y visita:
- http://localhost:8000 → Mensaje de bienvenida
- http://localhost:8000/docs → Documentación interactiva
- http://localhost:8000/health → Health check

## 🔐 Primer Login (Cuando esté implementado el endpoint)

```bash
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "Admin123!"}'
```

**⚠️ IMPORTANTE:** Cambiar la contraseña inmediatamente.

## 📊 Verificar Base de Datos

```bash
# Conectarse a PostgreSQL
psql -h localhost -U postgres -d vpn_gestion

# Ver tablas
\dt

# Ver configuración inicial
SELECT * FROM configuracion_sistema;

# Ver usuario admin
SELECT username, rol FROM usuarios_sistema;

# Salir
\q
```

## 🛠️ Comandos Útiles

### Backend

```bash
# Iniciar en desarrollo (con auto-reload)
uvicorn main:app --reload

# Iniciar en producción
uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4

# Ver logs
tail -f /var/log/vpn_gestion.log

# Tests (cuando estén implementados)
pytest
```

### Base de Datos

```bash
# Backup manual
pg_dump -h localhost -U postgres vpn_gestion > backup.sql

# Restaurar backup
psql -h localhost -U postgres vpn_gestion < backup.sql

# Actualizar estados (ejecutar diariamente)
psql -h localhost -U postgres -d vpn_gestion -c "SELECT actualizar_estado_vigencia();"
psql -h localhost -U postgres -d vpn_gestion -c "SELECT generar_alertas_vencimiento();"
```

## 🔧 Solución de Problemas Comunes

### Error: "connection refused"

```bash
# Verificar que PostgreSQL esté corriendo
sudo systemctl status postgresql

# Si no está corriendo
sudo systemctl start postgresql
```

### Error: "password authentication failed"

1. Verificar contraseña en `.env`
2. Verificar archivo `pg_hba.conf`:
   ```bash
   sudo nano /etc/postgresql/*/main/pg_hba.conf
   ```
3. Cambiar `peer` a `md5` o `trust` (desarrollo)
4. Reiniciar PostgreSQL:
   ```bash
   sudo systemctl restart postgresql
   ```

### Error: "port 8000 already in use"

```bash
# Encontrar proceso usando el puerto
sudo lsof -i :8000

# Matar proceso
sudo kill -9 <PID>

# O usar otro puerto
uvicorn main:app --port 8001
```

### Error: "No module named 'app'"

```bash
# Asegúrate de estar en el directorio correcto
cd vpn-gestion-sistema/backend

# Y que el entorno virtual esté activo
source venv/bin/activate

# Verificar instalación
pip list | grep fastapi
```

## 📝 Próximos Pasos

1. **Cambiar contraseña del admin:**
   ```sql
   -- Conéctate a la BD y ejecuta (cuando implementes el endpoint)
   -- O manualmente: password hasheado de bcrypt
   ```

2. **Crear usuarios adicionales**
   - Implementar endpoint de creación
   - Asignar roles apropiados

3. **Configurar sistema:**
   ```sql
   UPDATE configuracion_sistema SET valor = '20' 
   WHERE clave = 'DIAS_ALERTA_VENCIMIENTO';
   ```

4. **Importar datos desde Excel**
   - Preparar Excel con formato correcto
   - Usar endpoint de importación (cuando esté implementado)

5. **Configurar backups automáticos**
   ```bash
   # Agregar a crontab
   crontab -e
   
   # Backup diario a las 2 AM
   0 2 * * * pg_dump -h localhost -U postgres vpn_gestion > /backups/vpn_$(date +\%Y\%m\%d).sql
   ```

6. **Configurar tareas automáticas**
   ```bash
   # Actualizar estados diariamente a las 6 AM
   0 6 * * * psql -h localhost -U postgres -d vpn_gestion -c "SELECT actualizar_estado_vigencia(); SELECT generar_alertas_vencimiento();"
   ```

## 🎯 Checklist de Implementación

- [ ] PostgreSQL instalado y corriendo
- [ ] Base de datos creada exitosamente
- [ ] Backend configurado y corriendo
- [ ] Documentación accesible en /docs
- [ ] Contraseña del admin cambiada
- [ ] Usuarios adicionales creados
- [ ] Configuración del sistema ajustada
- [ ] Backups automáticos configurados
- [ ] Tareas cron configuradas
- [ ] Directorio de archivos creado (`/var/vpn_archivos`)

## 📚 Recursos

- [README Principal](../README.md)
- [Documentación de BD](../database/README.md)
- [FastAPI Docs](https://fastapi.tiangolo.com)
- [PostgreSQL Docs](https://www.postgresql.org/docs/)

---

**¿Problemas?** Revisa los logs y la documentación completa.
