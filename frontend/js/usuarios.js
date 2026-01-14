// 👥 Módulo de Gestión de Usuarios del Sistema - MEJORADO CON CAMBIO DE CONTRASEÑA
// 📂 Ubicación: frontend/js/usuarios.js
// ✅ Solo SUPERADMIN puede acceder

const Usuarios = {
    async load() {
        console.log('Cargando Gestión de Usuarios...');
        
        // Verificar si el usuario actual es SUPERADMIN
        const user = UserStorage.get();
        if (!user || user.rol !== 'SUPERADMIN') {
            this.mostrarAccesoDenegado();
            return;
        }
        
        this.verificarEstructuraVista();
        await this.listarUsuarios();
    },
    
    mostrarAccesoDenegado() {
        const contenedor = document.getElementById('usuariosView');
        if (!contenedor) return;
        
        contenedor.innerHTML = `
            <div style="text-align: center; padding: 4rem;">
                <h2 style="color: #ef4444; margin-bottom: 1rem;">🚫 Acceso Denegado</h2>
                <p style="color: #666; font-size: 1.1rem;">
                    Solo usuarios con rol <strong>SUPERADMIN</strong> pueden acceder a esta sección.
                </p>
            </div>
        `;
    },
    
    verificarEstructuraVista() {
        let contenedor = document.getElementById('usuariosView');
        if (!contenedor) {
            console.error('No se encontró usuariosView');
            return;
        }
        
        let tabla = contenedor.querySelector('#usuariosTable');
        if (tabla) {
            return; // Ya existe la estructura
        }
        
        // Crear estructura completa
        contenedor.innerHTML = `
            <div class="view-header" style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem;">
                <h1>👥 Gestión de Usuarios del Sistema</h1>
                <button id="btnNuevoUsuario" class="btn btn-primary">➕ Crear Usuario</button>
            </div>
            
            <div class="card">
                <div class="card-body">
                    <table class="table" id="usuariosTable">
                        <thead>
                            <tr>
                                <th>ID</th>
                                <th>Username</th>
                                <th>Nombre Completo</th>
                                <th>Email</th>
                                <th>Rol</th>
                                <th>Estado</th>
                                <th>Último Login</th>
                                <th>Acciones</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr><td colspan="8" style="text-align: center;">Cargando...</td></tr>
                        </tbody>
                    </table>
                </div>
            </div>
        `;
        
        // Event listener para crear usuario
        const btnNuevo = document.getElementById('btnNuevoUsuario');
        if (btnNuevo) {
            btnNuevo.onclick = () => this.mostrarFormularioCrear();
        }
    },
    
    async listarUsuarios() {
        try {
            const data = await API.get('/usuarios/?limit=100');
            
            const tbody = document.querySelector('#usuariosTable tbody');
            if (!tbody) {
                console.error('No se encontró tbody de usuarios');
                return;
            }
            
            if (!data || !data.usuarios || data.usuarios.length === 0) {
                tbody.innerHTML = '<tr><td colspan="8" style="text-align: center;">No hay usuarios registrados</td></tr>';
                return;
            }
            
            // Obtener usuario actual para deshabilitar acciones sobre sí mismo
            const currentUser = UserStorage.get();
            
            tbody.innerHTML = data.usuarios.map(usuario => {
                const esUsuarioActual = usuario.id === currentUser.id;
                const ultimoLogin = usuario.fecha_ultimo_login 
                    ? formatDate(usuario.fecha_ultimo_login) 
                    : 'Nunca';
                
                return `
                    <tr>
                        <td><strong>#${usuario.id}</strong></td>
                        <td><code>${usuario.username}</code></td>
                        <td>${usuario.nombre_completo}</td>
                        <td>${usuario.email || '-'}</td>
                        <td>
                            <span class="badge" style="background: ${usuario.rol === 'SUPERADMIN' ? '#ef4444' : '#3b82f6'};">
                                ${usuario.rol}
                            </span>
                        </td>
                        <td>
                            <span class="status-badge ${usuario.activo ? 'status-activo' : 'status-vencido'}">
                                ${usuario.activo ? '✅ Activo' : '❌ Inactivo'}
                            </span>
                        </td>
                        <td>${ultimoLogin}</td>
                        <td style="white-space: nowrap;">
                            ${!esUsuarioActual ? `
                                <button class="btn btn-sm btn-warning" 
                                        onclick="Usuarios.mostrarCambiarPassword(${usuario.id}, '${usuario.nombre_completo}')" 
                                        title="Cambiar Contraseña">
                                    🔑
                                </button>
                                
                                ${usuario.activo ? `
                                    <button class="btn btn-sm btn-danger" 
                                            onclick="Usuarios.desactivar(${usuario.id})" 
                                            title="Desactivar">
                                        🚫
                                    </button>
                                ` : `
                                    <button class="btn btn-sm btn-success" 
                                            onclick="Usuarios.activar(${usuario.id})" 
                                            title="Activar">
                                        ✅
                                    </button>
                                `}
                            ` : `
                                <span style="color: #666; font-size: 0.85rem;">
                                    (Tú)
                                </span>
                            `}
                        </td>
                    </tr>
                `;
            }).join('');
            
        } catch (error) {
            console.error('Error cargando usuarios:', error);
            showError('Error al cargar usuarios: ' + error.message);
        }
    },
    
    mostrarFormularioCrear() {
        showModal('➕ Crear Nuevo Usuario del Sistema', `
            <form id="formCrearUsuario">
                
                <div class="form-group">
                    <label>Nombres *</label>
                    <input type="text" id="nombres" required 
                           placeholder="Ej: Juan Carlos">
                    <small class="form-text">Se usará para generar el username automáticamente</small>
                </div>
                
                <div class="form-group">
                    <label>Apellidos *</label>
                    <input type="text" id="apellidos" required 
                           placeholder="Ej: Pérez López">
                </div>
                
                <div class="form-group">
                    <label>Email *</label>
                    <input type="email" id="email" required 
                           placeholder="usuario@ejemplo.com">
                </div>
                
                <div class="form-group">
                    <label>Rol *</label>
                    <select id="rol" required>
                        <option value="">Seleccione un rol</option>
                        <option value="ADMIN">ADMIN</option>
                        <option value="SUPERADMIN">SUPERADMIN - Acceso completo</option>
                    </select>
                    <small class="form-text">
                        <strong>ADMIN:</strong> Puede gestionar solicitudes y accesos<br>
                        <strong>SUPERADMIN:</strong> Puede gestionar usuarios y configuración
                    </small>
                </div>
                
                <div style="background: #fef3c7; padding: 1rem; border-radius: 4px; margin: 1rem 0;">
                    <strong>ℹ️ Información importante:</strong><br>
                    • El <strong>username</strong> se generará automáticamente<br>
                    • La <strong>contraseña inicial</strong> será: <code>Usuario.2025!</code><br>
                    • El usuario debe cambiarla en su primer login
                </div>
                
                <button type="submit" class="btn btn-success btn-block">
                    ➕ Crear Usuario
                </button>
            </form>
        `);
        
        document.getElementById('formCrearUsuario').addEventListener('submit', async (e) => {
            e.preventDefault();
            await this.crearUsuario();
        });
    },
    
    async crearUsuario() {
        try {
            showLoading();
            
            const data = {
                nombres: document.getElementById('nombres').value.trim(),
                apellidos: document.getElementById('apellidos').value.trim(),
                email: document.getElementById('email').value.trim(),
                rol: document.getElementById('rol').value
            };
            
            // Validaciones
            if (!data.nombres || !data.apellidos || !data.email || !data.rol) {
                throw new Error('Todos los campos son obligatorios');
            }
            
            if (!['ADMIN', 'SUPERADMIN'].includes(data.rol)) {
                throw new Error('Rol inválido');
            }
            
            // Agregar contraseña por defecto
            data.password = 'Usuario.2025!';
            
            // Crear usuario enviando datos en el body como JSON
            const response = await API.post('/usuarios/', data);
            
            hideLoading();
            hideModal();
            
            // Mostrar credenciales generadas
            showModal('✅ Usuario Creado Exitosamente', `
                <div style="background: #d1fae5; padding: 1.5rem; border-radius: 4px; margin-bottom: 1rem;">
                    <h3 style="margin-bottom: 1rem; color: #065f46;">
                        ✅ Usuario creado: ${response.usuario.nombre_completo}
                    </h3>
                    
                    <div style="background: white; padding: 1rem; border-radius: 4px; margin-bottom: 1rem;">
                        <p style="margin-bottom: 0.5rem;"><strong>Username:</strong></p>
                        <code style="font-size: 1.1rem; background: #f3f4f6; padding: 0.5rem; display: block;">
                            ${response.usuario.username}
                        </code>
                    </div>
                    
                    <div style="background: white; padding: 1rem; border-radius: 4px; margin-bottom: 1rem;">
                        <p style="margin-bottom: 0.5rem;"><strong>Contraseña Inicial:</strong></p>
                        <code style="font-size: 1.1rem; background: #f3f4f6; padding: 0.5rem; display: block;">
                            Usuario.2025!
                        </code>
                    </div>
                    
                    <div style="background: #fef3c7; padding: 1rem; border-radius: 4px;">
                        <strong>⚠️ IMPORTANTE:</strong><br>
                        Guarda estas credenciales y entrégalas al usuario.<br>
                        Debe cambiar su contraseña en el primer login.
                    </div>
                </div>
                
                <button class="btn btn-primary btn-block" onclick="hideModal(); Usuarios.load();">
                    Aceptar
                </button>
            `);
            
        } catch (error) {
            hideLoading();
            showError('Error al crear usuario: ' + error.message);
        }
    },
    
    // ========================================
    // NUEVA FUNCIÓN: CAMBIAR CONTRASEÑA (SUPERADMIN)
    // ========================================
    
    mostrarCambiarPassword(usuarioId, nombreCompleto) {
        showModal('🔑 Cambiar Contraseña de Usuario', `
            <form id="formCambiarPassword">
                <div style="background: #e0f2fe; padding: 1rem; border-radius: 4px; margin-bottom: 1.5rem;">
                    <strong>Usuario:</strong> ${nombreCompleto}
                </div>
                
                <div class="form-group">
                    <label>Nueva Contraseña *</label>
                    <input type="password" id="password_nueva" required 
                           minlength="6"
                           placeholder="Mínimo 6 caracteres">
                    <small class="form-text">
                        La contraseña debe tener al menos 6 caracteres
                    </small>
                </div>
                
                <div class="form-group">
                    <label>Confirmar Contraseña *</label>
                    <input type="password" id="password_confirmar" required 
                           minlength="6"
                           placeholder="Repite la contraseña">
                </div>
                
                <div style="background: #fef3c7; padding: 1rem; border-radius: 4px; margin: 1rem 0;">
                    <strong>⚠️ Nota:</strong><br>
                    Esta acción cambiará la contraseña del usuario inmediatamente.
                    Asegúrate de informarle la nueva contraseña.
                </div>
                
                <div style="display: flex; gap: 0.5rem;">
                    <button type="button" class="btn btn-secondary" onclick="hideModal()">
                        Cancelar
                    </button>
                    <button type="submit" class="btn btn-warning" style="flex: 1;">
                        🔑 Cambiar Contraseña
                    </button>
                </div>
            </form>
        `);
        
        document.getElementById('formCambiarPassword').addEventListener('submit', async (e) => {
            e.preventDefault();
            await this.cambiarPasswordUsuario(usuarioId, nombreCompleto);
        });
    },
    
    async cambiarPasswordUsuario(usuarioId, nombreCompleto) {
        try {
            const passwordNueva = document.getElementById('password_nueva').value;
            const passwordConfirmar = document.getElementById('password_confirmar').value;
            
            // Validaciones
            if (!passwordNueva || !passwordConfirmar) {
                throw new Error('Debes completar ambos campos');
            }
            
            if (passwordNueva.length < 6) {
                throw new Error('La contraseña debe tener al menos 6 caracteres');
            }
            
            if (passwordNueva !== passwordConfirmar) {
                throw new Error('Las contraseñas no coinciden');
            }
            
            showLoading();
            
            // Llamar al endpoint de resetear contraseña
            await API.put(`/usuarios/${usuarioId}/resetear-password?password_nueva=${encodeURIComponent(passwordNueva)}`, {});
            
            hideLoading();
            hideModal();
            
            // Mostrar confirmación con la nueva contraseña
            showModal('✅ Contraseña Cambiada', `
                <div style="background: #d1fae5; padding: 1.5rem; border-radius: 4px; margin-bottom: 1rem;">
                    <h3 style="margin-bottom: 1rem; color: #065f46;">
                        ✅ Contraseña actualizada exitosamente
                    </h3>
                    
                    <div style="background: white; padding: 1rem; border-radius: 4px; margin-bottom: 1rem;">
                        <p style="margin-bottom: 0.5rem;"><strong>Usuario:</strong></p>
                        <p style="margin: 0;">${nombreCompleto}</p>
                    </div>
                    
                    <div style="background: white; padding: 1rem; border-radius: 4px; margin-bottom: 1rem;">
                        <p style="margin-bottom: 0.5rem;"><strong>Nueva Contraseña:</strong></p>
                        <code style="font-size: 1.1rem; background: #f3f4f6; padding: 0.5rem; display: block;">
                            ${passwordNueva}
                        </code>
                    </div>
                    
                    <div style="background: #fef3c7; padding: 1rem; border-radius: 4px;">
                        <strong>📝 Recuerda:</strong><br>
                        Entrega esta contraseña al usuario de forma segura.
                    </div>
                </div>
                
                <button class="btn btn-primary btn-block" onclick="hideModal();">
                    Aceptar
                </button>
            `);
            
        } catch (error) {
            hideLoading();
            showError('Error al cambiar contraseña: ' + error.message);
        }
    },
    
    async activar(usuarioId) {
        if (!confirm('¿Activar este usuario?\n\nEl usuario podrá volver a iniciar sesión.')) {
            return;
        }
        
        try {
            showLoading();
            await API.put(`/usuarios/${usuarioId}/toggle-activo?activo=true`, {});
            hideLoading();
            showSuccess('Usuario activado exitosamente');
            await this.load();
        } catch (error) {
            hideLoading();
            showError('Error al activar usuario: ' + error.message);
        }
    },
    
    async desactivar(usuarioId) {
        if (!confirm('⚠️ ¿Desactivar este usuario?\n\nEl usuario no podrá iniciar sesión hasta que sea reactivado.')) {
            return;
        }
        
        try {
            showLoading();
            await API.put(`/usuarios/${usuarioId}/toggle-activo?activo=false`, {});
            hideLoading();
            showSuccess('Usuario desactivado exitosamente');
            await this.load();
        } catch (error) {
            hideLoading();
            showError('Error al desactivar usuario: ' + error.message);
        }
    }
};


// ========================================
// MODAL DE CAMBIO DE CONTRASEÑA (USUARIO MISMO)
// ========================================

const CambiarPasswordPropia = {
    mostrar() {
        const user = UserStorage.get();
        if (!user) {
            showError('No hay sesión activa');
            return;
        }
        
        showModal('🔑 Cambiar Mi Contraseña', `
            <form id="formCambiarPasswordPropia">
                <div style="background: #e0f2fe; padding: 1rem; border-radius: 4px; margin-bottom: 1.5rem;">
                    <strong>Usuario:</strong> ${user.nombre_completo}<br>
                    <strong>Username:</strong> <code>${user.username}</code>
                </div>
                
                <div class="form-group">
                    <label>Contraseña Actual *</label>
                    <input type="password" id="password_actual" required 
                           placeholder="Tu contraseña actual">
                </div>
                
                <div class="form-group">
                    <label>Nueva Contraseña *</label>
                    <input type="password" id="password_nueva" required 
                           minlength="6"
                           placeholder="Mínimo 6 caracteres">
                    <small class="form-text">
                        La contraseña debe tener al menos 6 caracteres
                    </small>
                </div>
                
                <div class="form-group">
                    <label>Confirmar Nueva Contraseña *</label>
                    <input type="password" id="password_confirmar" required 
                           minlength="6"
                           placeholder="Repite la nueva contraseña">
                </div>
                
                <div style="background: #dbeafe; padding: 1rem; border-radius: 4px; margin: 1rem 0;">
                    <strong>💡 Recomendaciones:</strong><br>
                    • Usa una combinación de letras, números y símbolos<br>
                    • No uses contraseñas fáciles de adivinar<br>
                    • No compartas tu contraseña con nadie
                </div>
                
                <div style="display: flex; gap: 0.5rem;">
                    <button type="button" class="btn btn-secondary" onclick="hideModal()">
                        Cancelar
                    </button>
                    <button type="submit" class="btn btn-primary" style="flex: 1;">
                        🔑 Cambiar Contraseña
                    </button>
                </div>
            </form>
        `);
        
        document.getElementById('formCambiarPasswordPropia').addEventListener('submit', async (e) => {
            e.preventDefault();
            await this.cambiar();
        });
    },
    
    async cambiar() {
    try {
        const passwordActual = document.getElementById('password_actual').value;
        const passwordNueva = document.getElementById('password_nueva').value;
        const passwordConfirmar = document.getElementById('password_confirmar').value;
        
        // Validaciones
        if (!passwordActual || !passwordNueva || !passwordConfirmar) {
            throw new Error('Debes completar todos los campos');
        }
        
        if (passwordNueva.length < 6) {
            throw new Error('La nueva contraseña debe tener al menos 6 caracteres');
        }
        
        if (passwordNueva !== passwordConfirmar) {
            throw new Error('Las contraseñas nuevas no coinciden');
        }
        
        if (passwordActual === passwordNueva) {
            throw new Error('La nueva contraseña debe ser diferente a la actual');
        }
        
        showLoading();
        
        // ✅ CAMBIO IMPORTANTE: usar query parameters
        const url = `/usuarios/me/cambiar-password?password_actual=${encodeURIComponent(passwordActual)}&password_nueva=${encodeURIComponent(passwordNueva)}`;
        await API.put(url, {});
        
        hideLoading();
        hideModal();
        
        showSuccess('✅ Contraseña cambiada exitosamente');
        
    } catch (error) {
        hideLoading();
        showError('Error al cambiar contraseña: ' + error.message);
    }
    }
};