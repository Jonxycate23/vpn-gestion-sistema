// Módulo de Gestión de Usuarios del Sistema
const Usuarios = {
    async load() {


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
            return;
        }

        contenedor.innerHTML = `
            <div class="view-header" style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem;">
                <h1>👥 Gestión de Usuarios del Sistema</h1>
                <button id="btnNuevoUsuario" class="btn btn-primary">➕ Crear Usuario</button>
            </div>
            
            <div class="card">
                <div style="overflow-x:auto;">
                    <table class="table" id="usuariosTable">
                        <thead>
                            <tr>
                                <th>ID</th>
                                <th>Username</th>
                                <th>Nombre Completo</th>
                                <th>Email</th>
                                <th>Rol</th>
                                <th>Estado</th>
                                <th style="text-align:center">Firma</th>
                                <th>Último Login</th>
                                <th>Acciones</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr><td colspan="9" style="text-align: center;">Cargando...</td></tr>
                        </tbody>
                    </table>
                </div>
            </div>
        `;

        const btnNuevo = document.getElementById('btnNuevoUsuario');
        if (btnNuevo) {
            btnNuevo.onclick = () => this.mostrarFormularioCrear();
        }
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
                <div style="overflow-x:auto;">
                    <table class="table" id="usuariosTable">
                        <thead>
                            <tr>
                                <th>ID</th>
                                <th>Username</th>
                                <th>Nombre Completo</th>
                                <th>Email</th>
                                <th>Rol</th>
                                <th>Estado</th>
                                <th style="text-align:center">Firma</th>
                                <th>Último Login</th>
                                <th>Acciones</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr><td colspan="9" style="text-align: center;">Cargando...</td></tr>
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
                        <td style="text-align:center">
                            ${usuario.tiene_firma
                        ? '<span title="Tiene firma" style="font-size:1.3rem;">✍️</span>'
                        : '<span title="Sin firma" style="color:#d1d5db;font-size:1.1rem;">—</span>'
                    }
                        </td>
                        <td>${ultimoLogin}</td>
                        <td style="white-space: nowrap;">
                            ${!esUsuarioActual ? `
                                <button class="btn btn-sm btn-primary"
                                        onclick="Usuarios.mostrarEditarUsuario(${usuario.id})"
                                        title="Editar Usuario">
                                    ✏️ Editar
                                </button>
                            ` : `
                                <span style="color: #666; font-size: 0.85rem;">(Tú)</span>
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

            if (!data.nombres || !data.apellidos || !data.email || !data.rol) {
                throw new Error('Todos los campos son obligatorios');
            }

            if (!['ADMIN', 'SUPERADMIN'].includes(data.rol)) {
                throw new Error('Rol inválido');
            }

            // data.password no se envía para que el backend la genere aleatoriamente

            const response = await API.post('/usuarios/', data);

            hideLoading();

            // Definir variables para el modal ANTES de cerrar
            const usuarioNombre = response.usuario ? response.usuario.nombre_completo : 'Usuario Creado';
            const usuarioUsername = response.usuario ? response.usuario.username : '---';
            const passwordMostrar = response.password_inicial || 'No disponible';

            // Cerrar el modal de creación
            hideModal();

            // Mostrar modal de éxito con un pequeño delay
            await new Promise(resolve => setTimeout(resolve, 300));

            showModal('✅ Usuario Creado Exitosamente', `
                <div style="background: #d1fae5; padding: 1.5rem; border-radius: 4px; margin-bottom: 1rem;">
                    <h3 style="margin-bottom: 1rem; color: #065f46;">
                        ✅ Usuario creado: ${usuarioNombre}
                    </h3>
                    
                    <div style="background: white; padding: 1rem; border-radius: 4px; margin-bottom: 1rem;">
                        <p style="margin-bottom: 0.5rem;"><strong>Username:</strong></p>
                        <code style="font-size: 1.1rem; background: #f3f4f6; padding: 0.5rem; display: block;">
                            ${usuarioUsername}
                        </code>
                    </div>
                    
                    <div style="background: white; padding: 1rem; border-radius: 4px; margin-bottom: 1rem;">
                        <p style="margin-bottom: 0.5rem;"><strong>Contraseña Inicial (Aleatoria):</strong></p>
                        <div style="display: flex; gap: 0.5rem;">
                             <code style="font-size: 1.1rem; background: #f3f4f6; padding: 0.5rem; display: block; flex: 1; word-break: break-all;">
                                ${passwordMostrar}
                            </code>
                            <button class="btn btn-sm btn-outline" onclick="navigator.clipboard.writeText('${passwordMostrar}').then(() => showSuccess('Copiado'))" title="Copiar">📋</button>
                        </div>
                    </div>
                    
                    <div style="background: #fef3c7; padding: 1rem; border-radius: 4px;">
                        <strong>⚠️ IMPORTANTE:</strong><br>
                        Debe cambiar su contraseña en el primer login.<br>
                        ingrese una contraseña segura y única.
                    </div>
                </div>
                
                <button class="btn btn-primary btn-block" onclick="hideModal(); setTimeout(() => Usuarios.load(), 100);">
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
                    <div class="password-wrapper">
                        <input type="password" id="password_nueva" required 
                               minlength="6"
                               placeholder="Mínimo 6 caracteres">
                        <button type="button" class="toggle-password" onclick="togglePasswordVisibility('password_nueva', this)"
                                aria-label="Mostrar contraseña">
                            <svg class="eye-icon eye-open" xmlns="http://www.w3.org/2000/svg" fill="none"
                                viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                    d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                    d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                            </svg>
                            <svg class="eye-icon eye-closed" xmlns="http://www.w3.org/2000/svg" fill="none"
                                viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                    d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.542-7a10.05 10.05 0 011.574-2.59M5.21 5.21a17.29 17.29 0 0113.58 13.58M1.05 1s14.2 14.2 21.9 21.9" />
                            </svg>
                        </button>
                    </div>
                    <small class="form-text">
                        La contraseña debe tener al menos 6 caracteres
                    </small>
                </div>
                
                <div class="form-group">
                    <label>Confirmar Contraseña *</label>
                    <div class="password-wrapper">
                        <input type="password" id="password_confirmar" required 
                               minlength="6"
                               placeholder="Repite la contraseña">
                        <button type="button" class="toggle-password" onclick="togglePasswordVisibility('password_confirmar', this)"
                                aria-label="Mostrar contraseña">
                            <svg class="eye-icon eye-open" xmlns="http://www.w3.org/2000/svg" fill="none"
                                viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                    d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                    d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                            </svg>
                            <svg class="eye-icon eye-closed" xmlns="http://www.w3.org/2000/svg" fill="none"
                                viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                    d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.542-7a10.05 10.05 0 011.574-2.59M5.21 5.21a17.29 17.29 0 0113.58 13.58M1.05 1s14.2 14.2 21.9 21.9" />
                            </svg>
                        </button>
                    </div>
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

            await API.put(`/usuarios/${usuarioId}/resetear-password?password_nueva=${encodeURIComponent(passwordNueva)}`, {});

            hideLoading();
            hideModal();

            // Mostrar mensaje de éxito con la nueva contraseña
            showSuccess(`✅ Contraseña actualizada exitosamente para ${nombreCompleto}.\n\nNueva contraseña: ${passwordNueva}\n\n📝 Recuerda entregar esta contraseña al usuario de forma segura.`);

            // Recargar la lista de usuarios
            setTimeout(() => this.load(), 500);

        } catch (error) {
            hideLoading();
            showError('Error al cambiar contraseña: ' + error.message);
        }
    },

    // ========================================
    // EDITAR USUARIO
    // ========================================

    async mostrarEditarUsuario(usuarioId) {
        try {
            showLoading();
            // Cargar usuario y estado de firma en paralelo
            const [respUsuario, respFirma] = await Promise.all([
                API.get(`/usuarios/${usuarioId}`),
                API.get(`/usuarios/${usuarioId}/firma-status`)
            ]);
            hideLoading();

            if (!respUsuario.success) {
                showError('Error al cargar datos del usuario');
                return;
            }

            const usuario = respUsuario.usuario;
            const tieneFirma = respFirma.tiene_firma;
            const username = usuario.username;

            // Extraer nombres y apellidos del nombre_completo
            const nombreCompleto = usuario.nombre_completo || '';
            const partes = nombreCompleto.trim().split(' ');
            const mitad = Math.ceil(partes.length / 2);
            const nombres = partes.slice(0, mitad).join(' ');
            const apellidos = partes.slice(mitad).join(' ');

            // URL de la firma con cache busting
            const firmaUrl = `imagenes/firmas/${username}.png?t=${Date.now()}`;

            showModal('✏️ Editar Usuario', `
                <form id="formEditarUsuario">
                    <input type="hidden" id="edit_usuario_id" value="${usuario.id}">

                    <div class="form-group">
                        <label>Username *</label>
                        <input type="text" id="edit_username" value="${usuario.username}" required
                               placeholder="username" style="font-family:monospace;">
                        <small class="form-text">Solo letras, números y guiones. Se guarda en minúsculas.</small>
                    </div>
                    
                    <div class="form-group">
                        <label>Nombres *</label>
                        <input type="text" id="edit_nombres" value="${nombres}" required 
                               placeholder="Nombres del usuario">
                    </div>
                    
                    <div class="form-group">
                        <label>Apellidos *</label>
                        <input type="text" id="edit_apellidos" value="${apellidos}" required 
                               placeholder="Apellidos del usuario">
                    </div>
                    
                    <div class="form-group">
                        <label>Email</label>
                        <input type="email" id="edit_email" value="${usuario.email || ''}" 
                               placeholder="correo@ejemplo.com">
                        <small class="form-text">Opcional</small>
                    </div>
                    
                    <div class="form-group">
                        <label>Rol *</label>
                        <select id="edit_rol" required class="form-control">
                            <option value="ADMIN" ${usuario.rol === 'ADMIN' ? 'selected' : ''}>ADMIN</option>
                            <option value="SUPERADMIN" ${usuario.rol === 'SUPERADMIN' ? 'selected' : ''}>SUPERADMIN</option>
                        </select>
                        <small class="form-text">
                            <strong>ADMIN:</strong> Gestión de solicitudes y accesos<br>
                            <strong>SUPERADMIN:</strong> Control total del sistema
                        </small>
                    </div>

                    <!-- ✍️ SECCIÓN DE FIRMA DIGITAL -->
                    <div style="border: 1px solid #e5e7eb; border-radius: 8px; padding: 1rem; margin: 1rem 0;">
                        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.75rem;">
                            <strong>✍️ Firma Digital</strong>
                            ${tieneFirma
                    ? '<span style="background:#d1fae5;color:#065f46;padding:0.25rem 0.75rem;border-radius:20px;font-size:0.85rem;">✅ Registrada</span>'
                    : '<span style="background:#fee2e2;color:#991b1b;padding:0.25rem 0.75rem;border-radius:20px;font-size:0.85rem;">❌ Sin firma</span>'
                }
                        </div>

                        ${tieneFirma ? `
                            <div style="text-align:center; margin-bottom:0.75rem; background:#f9fafb; border-radius:6px; padding:0.5rem;">
                                <img id="firmaPreview"
                                     src="${firmaUrl}"
                                     alt="Firma de ${username}"
                                     style="max-height:80px; max-width:100%; object-fit:contain;"
                                     onerror="document.getElementById('firmaPreview').style.display='none'; document.getElementById('firmaError').style.display='block';">
                                <p id="firmaError" style="display:none; color:#ef4444; font-size:0.85rem;">No se pudo cargar la imagen</p>
                            </div>
                        ` : `
                            <div style="text-align:center; padding:1rem; background:#f9fafb; border-radius:6px; margin-bottom:0.75rem; color:#9ca3af;">
                                <div style="font-size:2rem;">✍️</div>
                                <p style="font-size:0.85rem; margin:0;">Este usuario no tiene firma registrada</p>
                            </div>
                        `}

                        <div>
                            <label style="font-size:0.9rem; font-weight:600; margin-bottom:0.4rem; display:block;">
                                ${tieneFirma ? '🔄 Reemplazar firma (PNG)' : '📤 Subir firma (PNG/JPG)'}
                            </label>
                            <div style="display:flex; gap:0.5rem; align-items:center;">
                                <input type="file" id="firmaFile" accept="image/png,image/jpeg"
                                       style="flex:1; font-size:0.85rem;"
                                       onchange="document.getElementById('btnSubirFirma').disabled = !this.files.length;">
                                <button type="button" id="btnSubirFirma" 
                                        class="btn btn-sm btn-primary" disabled
                                        onclick="Usuarios.subirFirma(${usuario.id}, '${username}')">
                                    💾 Guardar
                                </button>
                            </div>
                            <small style="color:#6b7280;">La imagen se guardará como <code>${username}.png</code></small>
                        </div>
                    </div>
                    
                    <div style="background: #fef3c7; padding: 0.75rem 1rem; border-radius: 4px; margin: 0.5rem 0;">
                        <strong>⚠️ Nota:</strong> Asegúrate que la firma sea la del Usuario (PNG sin fondo).
                    </div>

                    <!-- Acciones del usuario dentro del modal -->
                    <div style="border:1px solid #e5e7eb;border-radius:8px;padding:1rem;margin:1rem 0;background:#f9fafb;">
                        <p style="margin:0 0 0.75rem;font-size:0.85rem;font-weight:700;color:#374151;">⚡ Acciones rápidas</p>
                        <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:0.5rem;">
                            <button type="button"
                                    style="padding:0.6rem 0.5rem;border:none;border-radius:8px;background:#f59e0b;color:white;font-weight:700;font-size:0.82rem;cursor:pointer;display:flex;align-items:center;justify-content:center;gap:0.3rem;"
                                    onclick="Usuarios.mostrarCambiarPasswordDesdeModal(${usuario.id}, '${usuario.nombre_completo}')">
                                🔑 Cambiar Contraseña
                            </button>
                            ${usuario.activo
                    ? `<button type="button"
                                          style="padding:0.6rem 0.5rem;border:none;border-radius:8px;background:#ef4444;color:white;font-weight:700;font-size:0.82rem;cursor:pointer;display:flex;align-items:center;justify-content:center;gap:0.3rem;"
                                          onclick="Usuarios.desactivar(${usuario.id}).then(r => { if(r !== undefined) hideModal(); })">
                                    🚫 Bloquear
                                   </button>`
                    : `<button type="button"
                                          style="padding:0.6rem 0.5rem;border:none;border-radius:8px;background:#10b981;color:white;font-weight:700;font-size:0.82rem;cursor:pointer;display:flex;align-items:center;justify-content:center;gap:0.3rem;"
                                          onclick="Usuarios.activar(${usuario.id}).then(r => { if(r !== undefined) hideModal(); })">
                                    ✅ Activar
                                   </button>`
                }
                            <button type="button"
                                    style="padding:0.6rem 0.5rem;border:none;border-radius:8px;background:#7f1d1d;color:white;font-weight:700;font-size:0.82rem;cursor:pointer;display:flex;align-items:center;justify-content:center;gap:0.3rem;"
                                    onclick="Usuarios.eliminar(${usuario.id}, '${usuario.nombre_completo}').then(r => { if(r !== undefined) hideModal(); })">
                                🗑️ Eliminar
                            </button>
                        </div>
                    </div>

                    <div style="display: flex; gap: 0.5rem;">
                        <button type="button" class="btn btn-secondary" onclick="hideModal()">
                            Cancelar
                        </button>
                        <button type="submit" class="btn btn-primary" style="flex: 1;">
                            💾 Guardar Cambios
                        </button>
                    </div>
                </form>
            `);

            document.getElementById('formEditarUsuario').addEventListener('submit', async (e) => {
                e.preventDefault();
                await this.actualizarUsuario(usuario.id);
            });

        } catch (error) {
            hideLoading();
            showError('Error al cargar usuario: ' + error.message);
        }
    },

    async subirFirma(usuarioId, username) {
        const fileInput = document.getElementById('firmaFile');
        if (!fileInput || !fileInput.files.length) {
            showError('Selecciona un archivo primero');
            return;
        }

        const file = fileInput.files[0];
        const formData = new FormData();
        formData.append('firma', file);

        try {
            const btn = document.getElementById('btnSubirFirma');
            if (btn) btn.disabled = true;
            showLoading();

            const token = TokenStorage.get();
            const response = await fetch(`${CONFIG.API_URL}/usuarios/${usuarioId}/firma`, {
                method: 'POST',
                headers: { 'Authorization': `Bearer ${token}` },
                body: formData
            });

            hideLoading();

            if (!response.ok) {
                const err = await response.json();
                throw new Error(err.detail || 'Error al subir la firma');
            }

            showSuccess(`✅ Firma guardada como ${username}.png`);

            // Actualizar la vista de firma en el modal sin cerrarlo
            const preview = document.getElementById('firmaPreview');
            if (preview) {
                preview.src = `imagenes/firmas/${username}.png?t=${Date.now()}`;
                preview.style.display = 'block';
            }

            // Reabrir el modal con los datos actualizados
            await this.mostrarEditarUsuario(usuarioId);

        } catch (error) {
            hideLoading();
            showError('Error: ' + error.message);
            const btn = document.getElementById('btnSubirFirma');
            if (btn) btn.disabled = false;
        }
    },


    async actualizarUsuario(usuarioId) {
        const username = document.getElementById('edit_username').value.trim().toLowerCase();
        const nombres = document.getElementById('edit_nombres').value.trim();
        const apellidos = document.getElementById('edit_apellidos').value.trim();
        const email = document.getElementById('edit_email').value.trim();
        const rol = document.getElementById('edit_rol').value;

        if (!username || !nombres || !apellidos) {
            showError('Username, nombres y apellidos son obligatorios');
            return;
        }

        const confirmado = await CustomConfirm.show({
            title: '💾 Guardar Cambios',
            message: '¿Confirmar la actualización de este usuario?',
            type: 'info',
            confirmText: 'Sí, guardar',
            cancelText: 'Cancelar'
        });

        if (!confirmado) {
            return;
        }

        try {
            showLoading();
            await API.put(`/usuarios/${usuarioId}`, {
                username,
                nombres,
                apellidos,
                email: email || null,
                rol
            });
            hideLoading();
            hideModal();
            showSuccess('Usuario actualizado exitosamente');
            await this.load();
        } catch (error) {
            hideLoading();
            showError('Error al actualizar usuario: ' + error.message);
        }
    },

    // ========================================
    // ACTIVAR/DESACTIVAR USUARIO
    // ========================================

    async activar(usuarioId) {
        // ✅ ESPERAR la respuesta del confirm
        const confirmado = await CustomConfirm.show({
            title: '✅ Activar Usuario',
            message: '¿Activar este usuario?\n\nEl usuario podrá volver a iniciar sesión.',
            type: 'info',
            confirmText: 'Sí, activar',
            cancelText: 'Cancelar'
        });

        // ✅ SI NO CONFIRMÓ, SALIR
        if (!confirmado) {

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

    // ========================================
    // ✅ CORREGIDO: DESACTIVAR CON AWAIT
    // ========================================

    async desactivar(usuarioId) {
        // ✅ ESPERAR la respuesta del confirm
        const confirmado = await CustomConfirm.show({
            title: '🚫 Desactivar Usuario',
            message: '⚠️ ¿Desactivar este usuario?\n\nEl usuario no podrá iniciar sesión hasta que sea reactivado.',
            type: 'danger',
            confirmText: 'Sí, desactivar',
            cancelText: 'Cancelar'
        });

        // ✅ SI NO CONFIRMÓ, SALIR
        if (!confirmado) {

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
    },

    // ========================================
    // ELIMINAR USUARIO
    // ========================================

    async eliminar(usuarioId, nombreCompleto) {
        const confirmado = await CustomConfirm.show({
            title: '🗑️ Eliminar Usuario',
            message: `⚠️ ¿ELIMINAR PERMANENTEMENTE al usuario "${nombreCompleto}"?\n\nEsta acción NO se puede deshacer.\nSe eliminarán todos los datos asociados.`,
            type: 'danger',
            confirmText: 'Sí, eliminar',
            cancelText: 'Cancelar'
        });

        if (!confirmado) {

            return;
        }

        try {
            showLoading();
            await API.delete(`/usuarios/${usuarioId}`);
            hideLoading();
            showSuccess('Usuario eliminado exitosamente');
            await this.load();
        } catch (error) {
            hideLoading();
            showError('Error al eliminar usuario: ' + error.message);
        }
    },

    // ========================================
    // CAMBIAR CONTRASEÑA DESDE MODAL EDITAR
    // ========================================

    async mostrarCambiarPasswordDesdeModal(usuarioId, nombreCompleto) {
        // Helper de toggle ojo — inline, sin dependencias externas
        const _eyeSvg = (id) => `
            <button type="button"
                    style="position:absolute;right:10px;top:50%;transform:translateY(-50%);background:none;border:none;cursor:pointer;padding:0;color:#6b7280;"
                    onclick="(function(){
                        var f=document.getElementById('${id}');
                        var isText=f.type==='text';
                        f.type=isText?'password':'text';
                        this.querySelector('.ojo-open').style.display=isText?'block':'none';
                        this.querySelector('.ojo-cerr').style.display=isText?'none':'block';
                    }).call(this)">
                <svg class="ojo-open" xmlns="http://www.w3.org/2000/svg" width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                </svg>
                <svg class="ojo-cerr" xmlns="http://www.w3.org/2000/svg" width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="display:none">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.542-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M3 3l18 18"/>
                </svg>
            </button>`;

        showModal('🔑 Cambiar Contraseña', `
            <form id="formCambiarPwdAdmin">
                <div style="background:#e0f2fe;padding:0.8rem 1rem;border-radius:6px;margin-bottom:1rem;">
                    <strong>Usuario:</strong> ${nombreCompleto}
                </div>

                <div class="form-group">
                    <label>Nueva Contraseña *</label>
                    <div style="position:relative;">
                        <input type="password" id="admin_pwd1" required minlength="6"
                               placeholder="Mínimo 6 caracteres"
                               style="width:100%;padding-right:40px;">
                        ${_eyeSvg('admin_pwd1')}
                    </div>
                </div>

                <div class="form-group">
                    <label>Confirmar Contraseña *</label>
                    <div style="position:relative;">
                        <input type="password" id="admin_pwd2" required minlength="6"
                               placeholder="Repite la nueva contraseña"
                               style="width:100%;padding-right:40px;">
                        ${_eyeSvg('admin_pwd2')}
                    </div>
                </div>

                <div style="display:flex;gap:0.5rem;margin-top:1.2rem;">
                    <button type="button" class="btn btn-secondary"
                            onclick="Usuarios.mostrarEditarUsuario(${usuarioId})">
                        &larr; Volver
                    </button>
                    <button type="submit" class="btn btn-primary" style="flex:1;">
                        🔑 Cambiar Contraseña
                    </button>
                </div>
            </form>
        `);

        document.getElementById('formCambiarPwdAdmin').addEventListener('submit', async (e) => {
            e.preventDefault();
            const nuevaPwd = document.getElementById('admin_pwd1').value;
            const confirmarPwd = document.getElementById('admin_pwd2').value;

            if (nuevaPwd.length < 6) { showError('Mínimo 6 caracteres'); return; }
            if (nuevaPwd !== confirmarPwd) { showError('Las contraseñas no coinciden'); return; }

            const confirmado = await CustomConfirm.show({
                title: '🔑 Cambiar contraseña',
                message: `¿Cambiar la contraseña de ${nombreCompleto}?`,
                type: 'danger',
                confirmText: 'Sí, cambiar',
                cancelText: 'Cancelar'
            });
            if (!confirmado) return;

            try {
                showLoading();
                await API.put(`/usuarios/${usuarioId}/reset-password?nueva_password=${encodeURIComponent(nuevaPwd)}`, {});
                hideLoading();
                hideModal();
                showSuccess('✅ Contraseña cambiada exitosamente');
            } catch (error) {
                hideLoading();
                showError('Error: ' + error.message);
            }
        });
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
                    <div class="password-wrapper">
                        <input type="password" id="password_actual" required 
                               placeholder="Tu contraseña actual">
                        <button type="button" class="toggle-password" onclick="togglePasswordVisibility('password_actual', this)"
                                aria-label="Mostrar contraseña">
                            <svg class="eye-icon eye-open" xmlns="http://www.w3.org/2000/svg" fill="none"
                                viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                    d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                    d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                            </svg>
                            <svg class="eye-icon eye-closed" xmlns="http://www.w3.org/2000/svg" fill="none"
                                viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                    d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.542-7a10.05 10.05 0 011.574-2.59M5.21 5.21a17.29 17.29 0 0113.58 13.58M1.05 1s14.2 14.2 21.9 21.9" />
                            </svg>
                        </button>
                    </div>
                </div>
                
                <div class="form-group">
                    <label>Nueva Contraseña *</label>
                    <div class="password-wrapper">
                        <input type="password" id="password_nueva" required 
                               minlength="6"
                               placeholder="Mínimo 6 caracteres">
                        <button type="button" class="toggle-password" onclick="togglePasswordVisibility('password_nueva', this)"
                                aria-label="Mostrar contraseña">
                            <svg class="eye-icon eye-open" xmlns="http://www.w3.org/2000/svg" fill="none"
                                viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                    d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                    d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                            </svg>
                            <svg class="eye-icon eye-closed" xmlns="http://www.w3.org/2000/svg" fill="none"
                                viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                    d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.542-7a10.05 10.05 0 011.574-2.59M5.21 5.21a17.29 17.29 0 0113.58 13.58M1.05 1s14.2 14.2 21.9 21.9" />
                            </svg>
                        </button>
                    </div>
                    <small class="form-text">
                        La contraseña debe tener al menos 6 caracteres
                    </small>
                </div>
                
                <div class="form-group">
                    <label>Confirmar Nueva Contraseña *</label>
                    <div class="password-wrapper">
                        <input type="password" id="password_confirmar" required 
                               minlength="6"
                               placeholder="Repite la nueva contraseña">
                        <button type="button" class="toggle-password" onclick="togglePasswordVisibility('password_confirmar', this)"
                                aria-label="Mostrar contraseña">
                            <svg class="eye-icon eye-open" xmlns="http://www.w3.org/2000/svg" fill="none"
                                viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                    d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                    d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                            </svg>
                            <svg class="eye-icon eye-closed" xmlns="http://www.w3.org/2000/svg" fill="none"
                                viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                    d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.542-7a10.05 10.05 0 011.574-2.59M5.21 5.21a17.29 17.29 0 0113.58 13.58M1.05 1s14.2 14.2 21.9 21.9" />
                            </svg>
                        </button>
                    </div>
                </div>
                
                <div style="background: #dbeafe; padding: 1rem; border-radius: 4px; margin: 1rem 0;">
                    <strong>💡 Recomendaciones:</strong><br>
                    • Usa una combinación de letras, números y símbolos<br>
                    • No uses contraseñas fáciles de adivinar
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
