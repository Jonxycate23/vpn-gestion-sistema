/**
 * Módulo de Solicitudes VPN - VERSIÓN DEFINITIVA
 * Crea la estructura HTML si no existe
 * 📍 Ubicación: frontend/js/solicitudes.js
 */

const Solicitudes = {
    personaActual: null,
    
    async load() {
        console.log('Cargando Solicitudes...');
        
        // Setup botón Nueva Solicitud
        const btnNueva = document.getElementById('btnNuevaSolicitud');
        if (btnNueva) {
            btnNueva.onclick = () => this.nuevaSolicitud();
        }
        
        // Verificar y crear estructura de tabla si no existe
        this.verificarEstructuraTabla();
        
        await this.listarSolicitudes();
    },
    
    verificarEstructuraTabla() {
        // Buscar contenedor de solicitudes
        let contenedor = document.getElementById('solicitudesView');
        if (!contenedor) {
            console.error('No se encontró solicitudesView');
            return;
        }
        
        // Verificar si ya existe la tabla
        let tabla = contenedor.querySelector('#solicitudesTable');
        if (tabla) {
            console.log('✅ Tabla ya existe');
            return;
        }
        
        // Crear estructura de tabla
        console.log('🔧 Creando estructura de tabla...');
        contenedor.innerHTML = `
            <div class="view-header" style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem;">
                <h1>📄 Gestión de Solicitudes VPN</h1>
                <button id="btnNuevaSolicitud" class="btn btn-primary">➕ Nueva Solicitud</button>
            </div>
            
            <div class="card">
                <div class="card-body">
                    <table class="table" id="solicitudesTable">
                        <thead>
                            <tr>
                                <th>No.</th>
                                <th>Fecha</th>
                                <th>DPI</th>
                                <th>Nombre</th>
                                <th>Tipo</th>
                                <th>Estado</th>
                                <th>Acciones</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr><td colspan="7" style="text-align: center;">Cargando...</td></tr>
                        </tbody>
                    </table>
                </div>
            </div>
        `;
        
        // Reconectar el botón
        const btnNueva = document.getElementById('btnNuevaSolicitud');
        if (btnNueva) {
            btnNueva.onclick = () => this.nuevaSolicitud();
        }
    },
    
    async listarSolicitudes() {
        try {
            const data = await API.get('/solicitudes/?limit=100');
            
            console.log('Solicitudes cargadas:', data.solicitudes ? data.solicitudes.length : 0);
            
            const tbody = document.querySelector('#solicitudesTable tbody');
            if (!tbody) {
                console.error('❌ No se encontró #solicitudesTable tbody');
                return;
            }
            
            if (!data || !data.solicitudes || data.solicitudes.length === 0) {
                tbody.innerHTML = '<tr><td colspan="7" style="text-align: center;">No hay solicitudes registradas</td></tr>';
                return;
            }
            
            tbody.innerHTML = data.solicitudes.map(sol => {
                const tieneCarta = sol.carta_generada === true;
                const puedeEditar = !tieneCarta && !sol.acceso_id;
                const puedeEliminar = !tieneCarta && !sol.acceso_id;
                const esNoPresentado = sol.estado === 'CANCELADA' && sol.comentarios_admin && sol.comentarios_admin.includes('NO_PRESENTADO');
                
                return `
                    <tr>
                        <td>${sol.id}</td>
                        <td>${formatDate(sol.fecha_solicitud)}</td>
                        <td>${sol.persona_dpi}</td>
                        <td>${sol.persona_nombres} ${sol.persona_apellidos}</td>
                        <td>${sol.tipo_solicitud}</td>
                        <td>${getStatusBadge(sol.estado)}</td>
                        <td style="white-space: nowrap;">
                            <button class="btn btn-sm btn-info" onclick="Solicitudes.verDetalle(${sol.id})" title="Ver detalle">
                                👁️
                            </button>
                            
                            ${puedeEditar ? `
                                <button class="btn btn-sm btn-warning" onclick="Solicitudes.editar(${sol.id})" title="Editar">
                                    ✏️
                                </button>
                            ` : ''}
                            
                            ${!tieneCarta && sol.estado === 'APROBADA' ? `
                                <button class="btn btn-sm btn-success" onclick="Solicitudes.crearCarta(${sol.id})" title="Crear carta">
                                    📄
                                </button>
                            ` : ''}
                            
                            ${tieneCarta ? `
                                <span style="display: inline-block; background: #10b981; color: white; padding: 0.25rem 0.5rem; border-radius: 4px; font-size: 0.75rem;">
                                    ✅ Carta
                                </span>
                            ` : ''}
                            
                            ${esNoPresentado ? `
                                <button class="btn btn-sm btn-primary" onclick="Solicitudes.reactivar(${sol.id})" title="Reactivar">
                                    🔄
                                </button>
                            ` : ''}
                            
                            ${!tieneCarta && sol.estado === 'APROBADA' && !esNoPresentado ? `
                                <button class="btn btn-sm btn-danger" onclick="Solicitudes.marcarNoPresentado(${sol.id})" title="No se presentó">
                                    🚫
                                </button>
                            ` : ''}
                            
                            ${puedeEliminar ? `
                                <button class="btn btn-sm btn-danger" onclick="Solicitudes.eliminar(${sol.id})" title="Eliminar">
                                    🗑️
                                </button>
                            ` : ''}
                        </td>
                    </tr>
                `;
            }).join('');
            
        } catch (error) {
            console.error('Error al cargar solicitudes:', error);
            showError('Error al cargar solicitudes: ' + error.message);
        }
    },
    
    nuevaSolicitud() {
        showModal('📝 Nueva Solicitud VPN', `
            <h3>Paso 1: Buscar Persona por DPI</h3>
            <p style="color: #666; margin-bottom: 1rem;">Ingrese el DPI de 13 dígitos</p>
            
            <form id="formBuscarDPI" style="margin-bottom: 2rem;">
                <div class="form-group">
                    <label>DPI *</label>
                    <input 
                        type="text" 
                        id="dpi" 
                        required 
                        maxlength="13"
                        pattern="[0-9]{13}"
                        placeholder="1234567891000"
                    >
                    <small>Si no existe, podrás crear la persona</small>
                </div>
                
                <button type="submit" class="btn btn-primary btn-block">
                    🔍 Buscar
                </button>
            </form>
            
            <div id="resultadoBusqueda"></div>
        `);
        
        document.getElementById('formBuscarDPI').addEventListener('submit', async (e) => {
            e.preventDefault();
            const dpi = document.getElementById('dpi').value;
            await this.buscarYMostrarPersona(dpi);
        });
    },
    
    async buscarYMostrarPersona(dpi) {
        try {
            showLoading();
            const resultado = await API.get(`/solicitudes/buscar-dpi/${dpi}`);
            hideLoading();
            
            if (resultado.existe) {
                this.personaActual = resultado;
                this.mostrarFormularioEdicion(resultado);
            } else {
                this.mostrarFormularioCreacion(dpi);
            }
            
        } catch (error) {
            hideLoading();
            showError('Error en búsqueda: ' + error.message);
        }
    },
    
    mostrarFormularioEdicion(persona) {
        const resultadoDiv = document.getElementById('resultadoBusqueda');
        resultadoDiv.innerHTML = `
            <div style="background: #d1fae5; border-left: 4px solid #10b981; padding: 1rem; margin-bottom: 1rem; border-radius: 4px;">
                <strong>✅ Persona encontrada</strong><br>
                ${persona.nombres} ${persona.apellidos}<br>
                DPI: ${persona.dpi}
                ${persona.nip ? `<br>NIP: ${persona.nip}` : ''}
                ${persona.total_solicitudes > 0 ? `<br><small>Tiene ${persona.total_solicitudes} solicitud(es) previa(s)</small>` : ''}
            </div>
            
            <h4>Verificar/Actualizar Datos</h4>
            <form id="formDatosPersona">
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                    <div class="form-group">
                        <label>Nombres (no editable)</label>
                        <input type="text" value="${persona.nombres}" disabled>
                    </div>
                    <div class="form-group">
                        <label>Apellidos (no editable)</label>
                        <input type="text" value="${persona.apellidos}" disabled>
                    </div>
                </div>
                
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                    <div class="form-group">
                        <label>DPI (no editable)</label>
                        <input type="text" value="${persona.dpi}" disabled>
                    </div>
                    <div class="form-group">
                        <label>NIP (Número Policial)</label>
                        <input type="text" id="nip" value="${persona.nip || ''}" placeholder="36250-P">
                    </div>
                </div>
                
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                    <div class="form-group">
                        <label>Email</label>
                        <input type="email" id="email" value="${persona.email || ''}">
                    </div>
                    <div class="form-group">
                        <label>Teléfono</label>
                        <input type="text" id="telefono" value="${persona.telefono || ''}">
                    </div>
                </div>
                
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                    <div class="form-group">
                        <label>Cargo / Grado</label>
                        <input type="text" id="cargo" value="${persona.cargo || ''}" placeholder="Inspector">
                    </div>
                    <div class="form-group">
                        <label>Institución</label>
                        <input type="text" id="institucion" value="${persona.institucion || ''}" placeholder="DEIC">
                    </div>
                </div>
                
                <button type="submit" class="btn btn-success btn-block">
                    ➡️ Continuar con Solicitud
                </button>
            </form>
        `;
        
        document.getElementById('formDatosPersona').addEventListener('submit', async (e) => {
            e.preventDefault();
            await this.actualizarYContinuar();
        });
    },
    
    mostrarFormularioCreacion(dpi) {
        const resultadoDiv = document.getElementById('resultadoBusqueda');
        resultadoDiv.innerHTML = `
            <div style="background: #fef3c7; border-left: 4px solid #f59e0b; padding: 1rem; margin-bottom: 1rem; border-radius: 4px;">
                <strong>✨ Crear Nueva Persona</strong><br>
                DPI: ${dpi}<br>
                <small>Complete todos los datos requeridos</small>
            </div>
            
            <h4>Datos de la Persona</h4>
            <form id="formDatosPersona">
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                    <div class="form-group">
                        <label>Nombres *</label>
                        <input type="text" id="nombres" required>
                    </div>
                    <div class="form-group">
                        <label>Apellidos *</label>
                        <input type="text" id="apellidos" required>
                    </div>
                </div>
                
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                    <div class="form-group">
                        <label>DPI *</label>
                        <input type="text" id="dpi" value="${dpi}" readonly>
                    </div>
                    <div class="form-group">
                        <label>NIP (Opcional)</label>
                        <input type="text" id="nip" placeholder="36250-P">
                    </div>
                </div>
                
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                    <div class="form-group">
                        <label>Email</label>
                        <input type="email" id="email">
                    </div>
                    <div class="form-group">
                        <label>Teléfono</label>
                        <input type="text" id="telefono">
                    </div>
                </div>
                
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                    <div class="form-group">
                        <label>Cargo / Grado</label>
                        <input type="text" id="cargo" placeholder="Inspector">
                    </div>
                    <div class="form-group">
                        <label>Institución</label>
                        <input type="text" id="institucion" placeholder="DEIC">
                    </div>
                </div>
                
                <button type="submit" class="btn btn-success btn-block">
                    ➕ Crear Persona y Continuar
                </button>
            </form>
        `;
        
        document.getElementById('formDatosPersona').addEventListener('submit', async (e) => {
            e.preventDefault();
            await this.crearYContinuar(dpi);
        });
    },
    
    async actualizarYContinuar() {
        try {
            showLoading();
            
            const data = {
                dpi: this.personaActual.dpi,
                nombres: this.personaActual.nombres,
                apellidos: this.personaActual.apellidos,
                nip: document.getElementById('nip').value || null,
                email: document.getElementById('email').value || null,
                cargo: document.getElementById('cargo').value || null,
                telefono: document.getElementById('telefono').value || null,
                institucion: document.getElementById('institucion').value || null
            };
            
            await API.post('/solicitudes/persona', data);
            this.personaActual = { ...this.personaActual, ...data };
            
            hideLoading();
            this.mostrarFormularioSolicitud();
            
        } catch (error) {
            hideLoading();
            showError('Error: ' + error.message);
        }
    },
    
    async crearYContinuar(dpi) {
        try {
            showLoading();
            
            const data = {
                dpi: dpi,
                nip: document.getElementById('nip').value || null,
                nombres: document.getElementById('nombres').value,
                apellidos: document.getElementById('apellidos').value,
                email: document.getElementById('email').value || null,
                cargo: document.getElementById('cargo').value || null,
                telefono: document.getElementById('telefono').value || null,
                institucion: document.getElementById('institucion').value || null
            };
            
            const response = await API.post('/solicitudes/persona', data);
            this.personaActual = {
                id: response.persona_id,
                ...data
            };
            
            hideLoading();
            showSuccess('Persona creada');
            this.mostrarFormularioSolicitud();
            
        } catch (error) {
            hideLoading();
            showError('Error: ' + error.message);
        }
    },
    
    mostrarFormularioSolicitud() {
        const resultadoDiv = document.getElementById('resultadoBusqueda');
        resultadoDiv.innerHTML = `
            <div style="background: #d1fae5; border-left: 4px solid #10b981; padding: 1rem; margin-bottom: 1.5rem; border-radius: 4px;">
                <strong>✅ Datos guardados</strong><br>
                <strong>${this.personaActual.nombres} ${this.personaActual.apellidos}</strong><br>
                DPI: ${this.personaActual.dpi}
                ${this.personaActual.nip ? ` | NIP: ${this.personaActual.nip}` : ''}
            </div>
            
            <h3>Paso 2: Datos de la Solicitud</h3>
            <form id="formSolicitud">
                <div class="form-group">
                    <label>Tipo *</label>
                    <select id="tipoSolicitud" required>
                        <option value="NUEVA">Nueva</option>
                        <option value="RENOVACION">Renovación</option>
                    </select>
                </div>
                
                <div class="form-group">
                    <label>Justificación *</label>
                    <textarea id="justificacion" required rows="4" 
                              placeholder="Describa el motivo..."></textarea>
                </div>
                
                <button type="submit" class="btn btn-success btn-block">
                    📋 Crear Solicitud
                </button>
            </form>
        `;
        
        document.getElementById('formSolicitud').addEventListener('submit', async (e) => {
            e.preventDefault();
            await this.crearSolicitud();
        });
    },
    
    async crearSolicitud() {
        try {
            showLoading();
            
            const data = {
                persona_id: this.personaActual.id,
                fecha_solicitud: new Date().toISOString().split('T')[0],
                tipo_solicitud: document.getElementById('tipoSolicitud').value,
                justificacion: document.getElementById('justificacion').value
            };
            
            await API.post('/solicitudes/', data);
            
            hideLoading();
            hideModal();
            showSuccess('¡Solicitud creada!');
            await this.load();
            
        } catch (error) {
            hideLoading();
            showError('Error: ' + error.message);
        }
    },
    
    async crearCarta(solicitudId) {
        if (!confirm('¿Crear carta de responsabilidad?')) return;
        
        try {
            showLoading();
            await API.post(`/solicitudes/${solicitudId}/crear-carta`, {});
            hideLoading();
            showSuccess('Carta creada');
            await this.load();
        } catch (error) {
            hideLoading();
            showError('Error: ' + error.message);
        }
    },
    
    async marcarNoPresentado(solicitudId) {
        const motivo = prompt('Motivo:', 'No se presentó a firmar');
        if (!motivo) return;
        
        try {
            showLoading();
            await API.post(`/solicitudes/${solicitudId}/no-presentado`, { motivo });
            hideLoading();
            showSuccess('Marcado como "No se presentó"');
            await this.load();
        } catch (error) {
            hideLoading();
            showError('Error: ' + error.message);
        }
    },
    
    async reactivar(solicitudId) {
        if (!confirm('¿Reactivar esta solicitud?')) return;
        
        try {
            showLoading();
            await API.post(`/solicitudes/${solicitudId}/reactivar`, {});
            hideLoading();
            showSuccess('Solicitud reactivada');
            await this.load();
        } catch (error) {
            hideLoading();
            showError('Error: ' + error.message);
        }
    },
    
    async eliminar(solicitudId) {
        if (!confirm('⚠️ ¿ELIMINAR?')) return;
        if (!confirm('¿Está SEGURO?')) return;
        
        try {
            showLoading();
            await API.delete(`/solicitudes/${solicitudId}`);
            hideLoading();
            showSuccess('Eliminada');
            await this.load();
        } catch (error) {
            hideLoading();
            showError('Error: ' + error.message);
        }
    },
    
    async editar(solicitudId) {
        try {
            showLoading();
            const sol = await API.get(`/solicitudes/${solicitudId}`);
            hideLoading();
            
            showModal('Editar Solicitud', `
                <form id="formEditar">
                    <div class="form-group">
                        <label>Tipo</label>
                        <select id="tipoSolicitud">
                            <option value="NUEVA" ${sol.tipo_solicitud === 'NUEVA' ? 'selected' : ''}>Nueva</option>
                            <option value="RENOVACION" ${sol.tipo_solicitud === 'RENOVACION' ? 'selected' : ''}>Renovación</option>
                        </select>
                    </div>
                    
                    <div class="form-group">
                        <label>Justificación</label>
                        <textarea id="justificacion" rows="4">${sol.justificacion}</textarea>
                    </div>
                    
                    <button type="submit" class="btn btn-success btn-block">
                        💾 Guardar
                    </button>
                </form>
            `);
            
            document.getElementById('formEditar').addEventListener('submit', async (e) => {
                e.preventDefault();
                await this.guardarEdicion(solicitudId);
            });
            
        } catch (error) {
            hideLoading();
            showError('Error: ' + error.message);
        }
    },
    
    async guardarEdicion(solicitudId) {
        try {
            showLoading();
            
            const data = {
                tipo_solicitud: document.getElementById('tipoSolicitud').value,
                justificacion: document.getElementById('justificacion').value
            };
            
            await API.put(`/solicitudes/${solicitudId}`, data);
            
            hideLoading();
            hideModal();
            showSuccess('Actualizada');
            await this.load();
            
        } catch (error) {
            hideLoading();
            showError('Error: ' + error.message);
        }
    },
    
    async verDetalle(solicitudId) {
        try {
            showLoading();
            const sol = await API.get(`/solicitudes/${solicitudId}`);
            hideLoading();
            
            const esNoPresentado = sol.estado === 'CANCELADA' && 
                                  sol.comentarios_admin && 
                                  sol.comentarios_admin.includes('NO_PRESENTADO');
            
            showModal(`Solicitud #${sol.id}`, `
                <div style="margin-bottom: 1rem;">
                    <h4>Estado</h4>
                    <p>${getStatusBadge(sol.estado)}</p>
                    ${esNoPresentado ? `<p style="color: #dc2626;">${sol.comentarios_admin}</p>` : ''}
                </div>
                
                <div style="margin-bottom: 1rem;">
                    <h4>Persona</h4>
                    <p><strong>Nombre:</strong> ${sol.persona.nombres} ${sol.persona.apellidos}</p>
                    <p><strong>DPI:</strong> ${sol.persona.dpi}</p>
                    ${sol.persona.nip ? `<p><strong>NIP:</strong> ${sol.persona.nip}</p>` : ''}
                    <p><strong>Cargo:</strong> ${sol.persona.cargo || 'N/A'}</p>
                    <p><strong>Institución:</strong> ${sol.persona.institucion || 'N/A'}</p>
                </div>
                
                <div style="margin-bottom: 1rem;">
                    <h4>Solicitud</h4>
                    <p><strong>Tipo:</strong> ${sol.tipo_solicitud}</p>
                    <p><strong>Fecha:</strong> ${formatDate(sol.fecha_solicitud)}</p>
                    <p><strong>Justificación:</strong> ${sol.justificacion}</p>
                </div>
                
                ${sol.acceso ? `
                    <div style="margin-bottom: 1rem;">
                        <h4>Acceso VPN</h4>
                        <p><strong>Vigencia:</strong> ${formatDate(sol.acceso.fecha_inicio)} - ${formatDate(sol.acceso.fecha_fin)}</p>
                        <p><strong>Días Restantes:</strong> ${sol.acceso.dias_restantes}</p>
                        <p>${getStatusBadge(sol.acceso.estado_vigencia)}</p>
                    </div>
                ` : ''}
            `);
            
        } catch (error) {
            hideLoading();
            showError('Error: ' + error.message);
        }
    }
};