/**
 * Módulo de Solicitudes VPN - VERSIÓN COMPLETA
 * Incluye TODOS los campos requeridos según el formato de control
 */

const Solicitudes = {
    personaActual: null,
    
    async load() {
        console.log('Cargando Solicitudes...');
        await this.listarSolicitudes();
    },
    
    async listarSolicitudes() {
        try {
            showLoading();
            const data = await API.get('/solicitudes/?limit=100');
            hideLoading();
            
            const tbody = document.querySelector('#tablaSolicitudes tbody');
            if (!tbody) return;
            
            if (data.solicitudes.length === 0) {
                tbody.innerHTML = '<tr><td colspan="10" class="text-center">No hay solicitudes registradas</td></tr>';
                return;
            }
            
            tbody.innerHTML = data.solicitudes.map(sol => `
                <tr>
                    <td>${sol.id}</td>
                    <td>${sol.numero_oficio || 'N/A'}</td>
                    <td>${sol.numero_providencia || 'N/A'}</td>
                    <td>${formatDate(sol.fecha_recepcion || sol.fecha_solicitud)}</td>
                    <td>${sol.tipo_solicitud}</td>
                    <td>${sol.persona_nombres} ${sol.persona_apellidos}</td>
                    <td>${sol.persona_dpi}</td>
                    <td>
                        <span class="badge badge-${sol.estado === 'APROBADA' ? 'success' : sol.estado === 'RECHAZADA' ? 'danger' : 'warning'}">
                            ${sol.estado}
                        </span>
                    </td>
                    <td>
                        ${sol.acceso_id ? `
                            <span class="badge badge-info">
                                Vence: ${formatDate(sol.fecha_fin)}
                            </span>
                        ` : '-'}
                    </td>
                    <td>
                        <button class="btn btn-sm btn-info" onclick="Solicitudes.verDetalle(${sol.id})">
                            👁️ Ver
                        </button>
                    </td>
                </tr>
            `).join('');
            
        } catch (error) {
            hideLoading();
            showError('Error al cargar solicitudes: ' + error.message);
        }
    },
    
    nuevaSolicitud() {
        const modal = document.getElementById('modalContainer');
        modal.innerHTML = `
            <div class="modal">
                <div class="modal-content modal-lg">
                    <span class="close" onclick="closeModal()">&times;</span>
                    <h2>📝 Nueva Solicitud VPN</h2>
                    
                    <div id="paso1">
                        <h3>Paso 1: Buscar Persona por DPI</h3>
                        <p class="text-muted">DPI (13 dígitos)</p>
                        
                        <form id="formBuscarDPI">
                            <div class="form-group">
                                <label>DPI *</label>
                                <input 
                                    type="text" 
                                    id="dpi" 
                                    required 
                                    maxlength="13"
                                    pattern="[0-9]{13}"
                                    placeholder="1234567891000"
                                    class="form-control"
                                >
                                <small>Si no existe, podrás crear la persona</small>
                            </div>
                            
                            <button type="submit" class="btn btn-primary">
                                🔍 Buscar
                            </button>
                        </form>
                        
                        <div id="resultadoBusqueda" class="mt-3"></div>
                    </div>
                </div>
            </div>
        `;
        
        document.getElementById('formBuscarDPI').addEventListener('submit', async (e) => {
            e.preventDefault();
            const dpi = document.getElementById('dpi').value;
            await this.buscarYMostrarPersona(dpi);
        });
        
        modal.style.display = 'block';
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
            <div class="alert alert-success">
                ✅ <strong>Persona encontrada</strong><br>
                ${persona.nombres} ${persona.apellidos}<br>
                DPI: ${persona.dpi}
                ${persona.nip ? `<br>NIP: ${persona.nip}` : ''}
                ${persona.total_solicitudes > 0 ? `<br><small>Tiene ${persona.total_solicitudes} solicitud(es) previa(s)</small>` : ''}
            </div>
            
            <h3>Verificar/Actualizar Datos</h3>
            <form id="formDatosPersona">
                <div class="form-row">
                    <div class="form-group col-md-6">
                        <label>Nombres (no editable)</label>
                        <input type="text" value="${persona.nombres}" disabled class="form-control">
                    </div>
                    <div class="form-group col-md-6">
                        <label>Apellidos (no editable)</label>
                        <input type="text" value="${persona.apellidos}" disabled class="form-control">
                    </div>
                </div>
                
                <div class="form-row">
                    <div class="form-group col-md-6">
                        <label>DPI (no editable)</label>
                        <input type="text" value="${persona.dpi}" disabled class="form-control">
                    </div>
                    <div class="form-group col-md-6">
                        <label>NIP (Número Policial)</label>
                        <input type="text" id="nip" value="${persona.nip || ''}" placeholder="36250-P" class="form-control">
                    </div>
                </div>
                
                <div class="form-row">
                    <div class="form-group col-md-6">
                        <label>Email / Correo Electrónico</label>
                        <input type="email" id="email" value="${persona.email || ''}" class="form-control">
                    </div>
                    <div class="form-group col-md-6">
                        <label>Teléfono</label>
                        <input type="text" id="telefono" value="${persona.telefono || ''}" class="form-control">
                    </div>
                </div>
                
                <div class="form-row">
                    <div class="form-group col-md-6">
                        <label>Cargo / Grado</label>
                        <input type="text" id="cargo" value="${persona.cargo || ''}" placeholder="Inspector, Agente, etc" class="form-control">
                    </div>
                    <div class="form-group col-md-6">
                        <label>Procedencia / Destino (Institución)</label>
                        <input type="text" id="institucion" value="${persona.institucion || ''}" placeholder="DEIC, SGAIA-PNC, etc" class="form-control">
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
            <div class="alert alert-warning">
                ✨ <strong>Crear Nueva Persona</strong><br>
                DPI: ${dpi}<br>
                <small>Complete todos los datos requeridos</small>
            </div>
            
            <h3>Datos de Identificación</h3>
            <form id="formDatosPersona">
                <div class="form-row">
                    <div class="form-group col-md-4">
                        <label>DPI *</label>
                        <input type="text" id="dpi" value="${dpi}" readonly class="form-control">
                    </div>
                    <div class="form-group col-md-4">
                        <label>NIP (Número Policial)</label>
                        <input type="text" id="nip" placeholder="36250-P" class="form-control">
                    </div>
                </div>
                
                <div class="form-row">
                    <div class="form-group col-md-6">
                        <label>Nombres *</label>
                        <input type="text" id="nombres" required class="form-control">
                    </div>
                    <div class="form-group col-md-6">
                        <label>Apellidos *</label>
                        <input type="text" id="apellidos" required class="form-control">
                    </div>
                </div>
                
                <h3>Datos Adicionales</h3>
                <div class="form-row">
                    <div class="form-group col-md-6">
                        <label>Email / Correo Electrónico</label>
                        <input type="email" id="email" class="form-control">
                    </div>
                    <div class="form-group col-md-6">
                        <label>Teléfono</label>
                        <input type="text" id="telefono" class="form-control">
                    </div>
                </div>
                
                <div class="form-row">
                    <div class="form-group col-md-6">
                        <label>Cargo / Grado</label>
                        <input type="text" id="cargo" placeholder="Inspector, Agente, etc" class="form-control">
                    </div>
                    <div class="form-group col-md-6">
                        <label>Procedencia / Destino (Institución)</label>
                        <input type="text" id="institucion" placeholder="DEIC, SGAIA-PNC, etc" class="form-control">
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
            
            // Actualizar campos editables
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
            
            // Actualizar persona actual
            this.personaActual = {
                ...this.personaActual,
                ...data
            };
            
            hideLoading();
            
            // Continuar con la solicitud
            this.mostrarFormularioSolicitud();
            
        } catch (error) {
            hideLoading();
            showError('Error al actualizar: ' + error.message);
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
            showSuccess('Persona creada exitosamente');
            
            // Continuar con la solicitud
            this.mostrarFormularioSolicitud();
            
        } catch (error) {
            hideLoading();
            showError('Error al crear persona: ' + error.message);
        }
    },
    
    mostrarFormularioSolicitud() {
        const resultadoDiv = document.getElementById('resultadoBusqueda');
        resultadoDiv.innerHTML = `
            <div class="alert alert-success">
                <strong>✅ Datos de persona guardados!</strong><br>
                <strong>${this.personaActual.nombres} ${this.personaActual.apellidos}</strong><br>
                DPI: ${this.personaActual.dpi}
                ${this.personaActual.nip ? ` | NIP: ${this.personaActual.nip}` : ''}
            </div>
            
            <h3>Paso 2: Datos de la Solicitud VPN</h3>
            <form id="formSolicitud">
                <h4>📄 Datos Administrativos</h4>
                <div class="form-row">
                    <div class="form-group col-md-4">
                        <label>Número de Oficio *</label>
                        <input type="text" id="numeroOficio" required placeholder="07-2025" class="form-control">
                        <small>Número del oficio recibido</small>
                    </div>
                    <div class="form-group col-md-4">
                        <label>Número de Providencia *</label>
                        <input type="text" id="numeroProvidencia" required placeholder="S/N, 3372-2024" class="form-control">
                        <small>Escriba "S/N" si no aplica</small>
                    </div>
                    <div class="form-group col-md-4">
                        <label>Fecha de Recepción *</label>
                        <input type="date" id="fechaRecepcion" required class="form-control">
                        <small>Fecha en que se recibió</small>
                    </div>
                </div>
                
                <h4>🔐 Datos de Acceso VPN</h4>
                <div class="form-row">
                    <div class="form-group col-md-6">
                        <label>Tipo de Solicitud *</label>
                        <select id="tipoSolicitud" required class="form-control">
                            <option value="NUEVA">Creación (Nueva)</option>
                            <option value="RENOVACION">Renovación</option>
                        </select>
                    </div>
                    <div class="form-group col-md-6">
                        <label>Vigencia *</label>
                        <select id="vigencia" required class="form-control">
                            <option value="12">12 meses (estándar)</option>
                            <option value="6">6 meses</option>
                            <option value="3">3 meses</option>
                        </select>
                        <small>La vigencia estándar es de 12 meses</small>
                    </div>
                </div>
                
                <div class="form-group">
                    <label>Justificación / Motivo *</label>
                    <textarea 
                        id="justificacion" 
                        required 
                        rows="4"
                        placeholder="Describa el motivo de la solicitud, funciones que desempeñará, etc."
                        class="form-control"
                    ></textarea>
                </div>
                
                <button type="submit" class="btn btn-success btn-lg btn-block">
                    📋 Crear Solicitud y Generar Carta
                </button>
            </form>
        `;
        
        // Setear fecha de hoy por defecto
        document.getElementById('fechaRecepcion').valueAsDate = new Date();
        
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
                numero_oficio: document.getElementById('numeroOficio').value,
                numero_providencia: document.getElementById('numeroProvidencia').value,
                fecha_recepcion: document.getElementById('fechaRecepcion').value,
                tipo_solicitud: document.getElementById('tipoSolicitud').value,
                justificacion: document.getElementById('justificacion').value,
                vigencia_meses: parseInt(document.getElementById('vigencia').value)
            };
            
            const response = await API.post('/solicitudes/', data);
            
            hideLoading();
            
            // Mostrar resultado
            showSuccess('¡Solicitud creada exitosamente!');
            
            // Cerrar modal y recargar
            closeModal();
            await this.load();
            
        } catch (error) {
            hideLoading();
            showError('Error al crear solicitud: ' + error.message);
        }
    },
    
    async verDetalle(solicitudId) {
        try {
            showLoading();
            const sol = await API.get(`/solicitudes/${solicitudId}`);
            hideLoading();
            
            const modal = document.getElementById('modalContainer');
            modal.innerHTML = `
                <div class="modal">
                    <div class="modal-content modal-lg">
                        <span class="close" onclick="closeModal()">&times;</span>
                        <h2>📋 Detalle de Solicitud #${sol.id}</h2>
                        
                        <div class="detail-section">
                            <h3>Datos Administrativos</h3>
                            <p><strong>Oficio:</strong> ${sol.numero_oficio || 'N/A'}</p>
                            <p><strong>Providencia:</strong> ${sol.numero_providencia || 'N/A'}</p>
                            <p><strong>Fecha Recepción:</strong> ${formatDate(sol.fecha_recepcion || sol.fecha_solicitud)}</p>
                            <p><strong>Tipo:</strong> ${sol.tipo_solicitud}</p>
                            <p><strong>Estado:</strong> <span class="badge badge-success">${sol.estado}</span></p>
                        </div>
                        
                        <div class="detail-section">
                            <h3>Datos de la Persona</h3>
                            <p><strong>Nombre:</strong> ${sol.persona.nombres} ${sol.persona.apellidos}</p>
                            <p><strong>DPI:</strong> ${sol.persona.dpi}</p>
                            ${sol.persona.nip ? `<p><strong>NIP:</strong> ${sol.persona.nip}</p>` : ''}
                            <p><strong>Cargo:</strong> ${sol.persona.cargo || 'N/A'}</p>
                            <p><strong>Institución:</strong> ${sol.persona.institucion || 'N/A'}</p>
                        </div>
                        
                        ${sol.acceso ? `
                            <div class="detail-section">
                                <h3>Acceso VPN Asociado</h3>
                                <p><strong>Vigencia:</strong> ${formatDate(sol.acceso.fecha_inicio)} - ${formatDate(sol.acceso.fecha_fin)}</p>
                                <p><strong>Días Restantes:</strong> ${sol.acceso.dias_restantes}</p>
                                <p><strong>Estado:</strong> <span class="badge badge-info">${sol.acceso.estado_vigencia}</span></p>
                            </div>
                        ` : ''}
                        
                        <div class="detail-section">
                            <h3>Justificación</h3>
                            <p>${sol.justificacion}</p>
                        </div>
                    </div>
                </div>
            `;
            
            modal.style.display = 'block';
            
        } catch (error) {
            hideLoading();
            showError('Error al cargar detalle: ' + error.message);
        }
    }
};