/**
 * Módulo de Solicitudes VPN - VERSIÓN DEFINITIVA CON VISTA PREVIA
 * 📍 Ubicación: frontend/js/solicitudes.js
 * REEMPLAZA COMPLETAMENTE EL ARCHIVO ACTUAL
 */

const Solicitudes = {
    personaActual: null,
    
    async load() {
        console.log('Cargando Solicitudes...');
        
        const btnNueva = document.getElementById('btnNuevaSolicitud');
        if (btnNueva) {
            btnNueva.onclick = () => this.nuevaSolicitud();
        }
        
        this.verificarEstructuraTabla();
        await this.listarSolicitudes();
    },
    
    verificarEstructuraTabla() {
        let contenedor = document.getElementById('solicitudesView');
        if (!contenedor) {
            console.error('No se encontró solicitudesView');
            return;
        }
        
        let tabla = contenedor.querySelector('#solicitudesTable');
        if (tabla) {
            return;
        }
        
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
                                <th>Oficio</th>
                                <th>Providencia</th>
                                <th>Fecha Recep.</th>
                                <th>DPI</th>
                                <th>Nombre</th>
                                <th>Estado</th>
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
        
        const btnNueva = document.getElementById('btnNuevaSolicitud');
        if (btnNueva) {
            btnNueva.onclick = () => this.nuevaSolicitud();
        }
    },
    
    async listarSolicitudes() {
        try {
            const data = await API.get('/solicitudes/?limit=100');
            
            const tbody = document.querySelector('#solicitudesTable tbody');
            if (!tbody) {
                console.error('❌ No se encontró tbody');
                return;
            }
            
            if (!data || !data.solicitudes || data.solicitudes.length === 0) {
                tbody.innerHTML = '<tr><td colspan="8" style="text-align: center;">No hay solicitudes</td></tr>';
                return;
            }
            
            tbody.innerHTML = data.solicitudes.map(sol => {
                const tieneCarta = sol.carta_generada === true;
                const puedeEditar = !tieneCarta && !sol.acceso_id;
                const esNoPresentado = sol.estado === 'CANCELADA' && sol.comentarios_admin && sol.comentarios_admin.includes('NO_PRESENTADO');
                
                return `
                    <tr>
                        <td>${sol.id}</td>
                        <td>${sol.numero_oficio || 'N/A'}</td>
                        <td>${sol.numero_providencia || 'N/A'}</td>
                        <td>${formatDate(sol.fecha_recepcion || sol.fecha_solicitud)}</td>
                        <td>${sol.persona_dpi}</td>
                        <td>${sol.persona_nombres} ${sol.persona_apellidos}</td>
                        <td>${getStatusBadge(sol.estado)}</td>
                        <td style="white-space: nowrap;">
                            <button class="btn btn-sm btn-info" onclick="Solicitudes.verDetalle(${sol.id})" title="Ver">
                                👁️
                            </button>
                            
                            ${puedeEditar ? `
                                <button class="btn btn-sm btn-warning" onclick="Solicitudes.editar(${sol.id})" title="Editar">
                                    ✏️
                                </button>
                            ` : ''}
                            
                            ${!tieneCarta && sol.estado === 'APROBADA' ? `
                                <button class="btn btn-sm btn-success" onclick="Solicitudes.crearCarta(${sol.id})" title="Crear carta">
                                    📄 Carta
                                </button>
                            ` : ''}
                            
                            ${tieneCarta ? `
                                <button class="btn btn-sm" style="background: #10b981; color: white;" 
                                        onclick="Solicitudes.verVistaPreviaCarta(${sol.id})" title="Ver carta">
                                    ✅ Ver Carta
                                </button>
                            ` : ''}
                            
                            ${esNoPresentado ? `
                                <button class="btn btn-sm btn-primary" onclick="Solicitudes.reactivar(${sol.id})" title="Reactivar">
                                    🔄
                                </button>
                            ` : ''}
                            
                            ${!tieneCarta && sol.estado === 'APROBADA' && !esNoPresentado ? `
                                <button class="btn btn-sm btn-danger" onclick="Solicitudes.marcarNoPresentado(${sol.id})" title="No presentado">
                                    🚫
                                </button>
                            ` : ''}
                            
                            ${puedeEditar ? `
                                <button class="btn btn-sm btn-danger" onclick="Solicitudes.eliminar(${sol.id})" title="Eliminar">
                                    🗑️
                                </button>
                            ` : ''}
                        </td>
                    </tr>
                `;
            }).join('');
            
        } catch (error) {
            console.error('Error:', error);
            showError('Error al cargar solicitudes');
        }
    },
    
    nuevaSolicitud() {
        showModal('📝 Nueva Solicitud VPN', `
            <h3>Paso 1: Buscar Persona por DPI</h3>
            <form id="formBuscarDPI" style="margin-bottom: 2rem;">
                <div class="form-group">
                    <label>DPI *</label>
                    <input type="text" id="dpi" required maxlength="13" pattern="[0-9]{13}">
                </div>
                <button type="submit" class="btn btn-primary btn-block">🔍 Buscar</button>
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
            showError('Error en búsqueda');
        }
    },
    
    mostrarFormularioEdicion(persona) {
        const resultadoDiv = document.getElementById('resultadoBusqueda');
        resultadoDiv.innerHTML = `
            <div style="background: #d1fae5; padding: 1rem; margin-bottom: 1rem; border-radius: 4px;">
                <strong>✅ Persona encontrada</strong><br>
                ${persona.nombres} ${persona.apellidos}<br>
                DPI: ${persona.dpi}
            </div>
            
            <h4>Verificar/Actualizar Datos</h4>
            <form id="formDatosPersona">
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                    <div class="form-group">
                        <label>Nombres</label>
                        <input type="text" value="${persona.nombres}" disabled>
                    </div>
                    <div class="form-group">
                        <label>Apellidos</label>
                        <input type="text" value="${persona.apellidos}" disabled>
                    </div>
                </div>
                
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                    <div class="form-group">
                        <label>DPI</label>
                        <input type="text" value="${persona.dpi}" disabled>
                    </div>
                    <div class="form-group">
                        <label>NIP</label>
                        <input type="text" id="nip" value="${persona.nip || ''}">
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
                        <label>Cargo/Grado</label>
                        <input type="text" id="cargo" value="${persona.cargo || ''}">
                    </div>
                    <div class="form-group">
                        <label>Institución</label>
                        <input type="text" id="institucion" value="${persona.institucion || ''}">
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
            <div style="background: #fef3c7; padding: 1rem; margin-bottom: 1rem; border-radius: 4px;">
                <strong>✨ Crear Nueva Persona</strong><br>
                DPI: ${dpi}
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
                        <label>NIP</label>
                        <input type="text" id="nip">
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
                        <label>Cargo/Grado</label>
                        <input type="text" id="cargo">
                    </div>
                    <div class="form-group">
                        <label>Institución</label>
                        <input type="text" id="institucion">
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
        const hoy = new Date().toISOString().split('T')[0];
        
        resultadoDiv.innerHTML = `
            <div style="background: #d1fae5; padding: 1rem; margin-bottom: 1.5rem; border-radius: 4px;">
                <strong>✅ Datos guardados</strong><br>
                <strong>${this.personaActual.nombres} ${this.personaActual.apellidos}</strong><br>
                DPI: ${this.personaActual.dpi}
            </div>
            
            <h3>Paso 2: Datos de la Solicitud</h3>
            <form id="formSolicitud">
                <div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 1rem;">
                    <div class="form-group">
                        <label>Número de Oficio</label>
                        <input type="text" id="numeroOficio" placeholder="Ej: 07-2025">
                    </div>
                    <div class="form-group">
                        <label>Número de Providencia</label>
                        <input type="text" id="numeroProvidencia" placeholder="Ej: 3372-2024">
                    </div>
                    <div class="form-group">
                        <label>Fecha de Recepción</label>
                        <input type="date" id="fechaRecepcion" value="${hoy}">
                    </div>
                </div>
                
                <div class="form-group">
                    <label>Tipo *</label>
                    <select id="tipoSolicitud" required>
                        <option value="NUEVA">Nueva</option>
                        <option value="RENOVACION">Renovación</option>
                    </select>
                </div>
                
                <div class="form-group">
                    <label>Justificación *</label>
                    <textarea id="justificacion" required rows="4"></textarea>
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
                numero_oficio: document.getElementById('numeroOficio').value || null,
                numero_providencia: document.getElementById('numeroProvidencia').value || null,
                fecha_recepcion: document.getElementById('fechaRecepcion').value || null,
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
        if (!confirm('¿Crear carta de responsabilidad?\n\nEsto generará el PDF y creará el acceso VPN automáticamente.')) return;
        
        try {
            showLoading();
            const response = await API.post(`/solicitudes/${solicitudId}/crear-carta`, {});
            hideLoading();
            
            alert(`✅ ¡Carta Creada!\n\nCarta #${response.carta_id}\nAcceso VPN #${response.acceso_id}\nPDF: ${response.pdf_path}\n\nYa puedes ver la vista previa.`);
            
            await this.load();
        } catch (error) {
            hideLoading();
            showError('Error: ' + error.message);
        }
    },
    
    async verVistaPreviaCarta(solicitudId) {
        try {
            showLoading();
            const sol = await API.get(`/solicitudes/${solicitudId}`);
            hideLoading();
            
            // Aquí mostramos la vista previa de la carta
            const hoy = new Date();
            const fechaExpiracion = new Date(hoy);
            fechaExpiracion.setFullYear(fechaExpiracion.getFullYear() + 1);
            
            showModal('Vista Previa - Carta de Responsabilidad', `
                <div style="max-height: 70vh; overflow-y: auto; padding: 2rem; background: white; border: 1px solid #ccc;">
                    <div style="text-align: center; margin-bottom: 2rem;">
                        <h2 style="font-size: 14px; margin-bottom: 0.5rem;">CARTA DE RESPONSABILIDAD DE USO Y ACCESO POR VPN</h2>
                        <h3 style="font-size: 13px;">A LA RED INSTITUCIONAL DE LA POLICÍA NACIONAL CIVIL</h3>
                        <p style="margin-top: 1rem; font-weight: bold;">Documento No: ${sol.id}-2025</p>
                    </div>
                    
                    <div style="text-align: justify; font-size: 11px; line-height: 1.6; margin-bottom: 1.5rem;">
                        <p>En las instalaciones que ocupa el Departamento de Operaciones de Seguridad Informática de la 
                        Subdirección General de Tecnologías de la Información y la Comunicación, se suscribe la presente 
                        CARTA DE RESPONSABILIDAD con la que <strong>EL USUARIO</strong> acepta formalmente las condiciones de uso y acceso 
                        por medio del servicio de VPN.</p>
                    </div>
                    
                    <div style="font-size: 11px; margin-bottom: 1.5rem;">
                        <p style="margin-bottom: 0.5rem;"><strong>1.</strong> EL USUARIO y CONTRASEÑA asignados son datos intransferibles, confidenciales y personales.</p>
                        <p style="margin-bottom: 0.5rem;"><strong>2.</strong> EL USUARIO tiene prohibido compartir información confidencial.</p>
                        <p style="margin-bottom: 0.5rem;"><strong>3.</strong> El USUARIO se compromete a utilizar el servicio VPN únicamente para fines laborales.</p>
                        <p style="margin-bottom: 0.5rem;"><strong>4.</strong> EL USUARIO debe reportar inmediatamente cualquier incidente de seguridad.</p>
                        <p style="margin-bottom: 0.5rem;"><strong>5.</strong> El acceso tiene vigencia de 12 meses y debe renovarse oportunamente.</p>
                        <p style="margin-bottom: 0.5rem;"><strong>6.</strong> EL USUARIO acepta cumplir todos los lineamientos de seguridad.</p>
                        <p style="margin-bottom: 0.5rem;"><strong>7.</strong> La Subdirección se reserva el derecho de bloquear usuarios por uso inapropiado.</p>
                    </div>
                    
                    <table style="width: 100%; border-collapse: collapse; margin-bottom: 1.5rem; font-size: 11px;">
                        <tr style="border: 1px solid black;">
                            <td style="padding: 8px; border: 1px solid black; font-weight: bold;">Responsable:</td>
                            <td style="padding: 8px; border: 1px solid black;">${sol.persona.nombres} ${sol.persona.apellidos}</td>
                            <td style="padding: 8px; border: 1px solid black; font-weight: bold;">Usuario:</td>
                            <td style="padding: 8px; border: 1px solid black;">${sol.persona.email || 'N/A'}</td>
                        </tr>
                        <tr style="border: 1px solid black;">
                            <td style="padding: 8px; border: 1px solid black; font-weight: bold;">DPI:</td>
                            <td style="padding: 8px; border: 1px solid black;">${sol.persona.dpi}</td>
                            <td style="padding: 8px; border: 1px solid black; font-weight: bold;">Teléfono:</td>
                            <td style="padding: 8px; border: 1px solid black;">${sol.persona.telefono || 'N/A'}</td>
                        </tr>
                        <tr style="border: 1px solid black;">
                            <td style="padding: 8px; border: 1px solid black; font-weight: bold;">Destino:</td>
                            <td style="padding: 8px; border: 1px solid black;">${sol.persona.institucion || 'N/A'}</td>
                            <td style="padding: 8px; border: 1px solid black; font-weight: bold;">Fecha Expiración:</td>
                            <td style="padding: 8px; border: 1px solid black;">${fechaExpiracion.toLocaleDateString('es-GT')}</td>
                        </tr>
                    </table>
                    
                    <p style="font-size: 11px; margin-bottom: 2rem;">
                        <strong>Finalidad:</strong> Proveer un túnel VPN para permitir el acceso al sistema de Escritorio Policial y Solvencias.
                    </p>
                    
                    <p style="font-size: 11px; margin-bottom: 3rem; font-weight: bold;">
                        Guatemala, ${hoy.toLocaleDateString('es-GT')}
                    </p>
                    
                    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 2rem; margin-top: 3rem;">
                        <div style="text-align: center;">
                            <div style="border-top: 1px solid black; padding-top: 0.5rem;">
                                <p style="font-size: 11px;">Firmo y recibo conforme</p>
                            </div>
                        </div>
                        <div style="text-align: center;">
                            <div style="border-top: 1px solid black; padding-top: 0.5rem;">
                                <p style="font-size: 11px;">Firmo y entrego DOSI/SGTIC</p>
                            </div>
                        </div>
                    </div>
                </div>
                
                <div style="margin-top: 1rem; text-align: center;">
                    <button class="btn btn-primary" onclick="alert('Función de descarga PDF próximamente')">
                        📥 Descargar PDF
                    </button>
                    <button class="btn btn-outline" onclick="hideModal()">
                        Cerrar
                    </button>
                </div>
            `);
            
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
            
            showModal(`Solicitud #${sol.id}`, `
                <div style="margin-bottom: 1rem;">
                    <h4>Datos Administrativos</h4>
                    <p><strong>Oficio:</strong> ${sol.numero_oficio || 'N/A'}</p>
                    <p><strong>Providencia:</strong> ${sol.numero_providencia || 'N/A'}</p>
                    <p><strong>Fecha Recepción:</strong> ${formatDate(sol.fecha_recepcion)}</p>
                    <p><strong>Estado:</strong> ${getStatusBadge(sol.estado)}</p>
                </div>
                
                <div style="margin-bottom: 1rem;">
                    <h4>Persona</h4>
                    <p><strong>Nombre:</strong> ${sol.persona.nombres} ${sol.persona.apellidos}</p>
                    <p><strong>DPI:</strong> ${sol.persona.dpi}</p>
                    ${sol.persona.nip ? `<p><strong>NIP:</strong> ${sol.persona.nip}</p>` : ''}
                    <p><strong>Cargo:</strong> ${sol.persona.cargo || 'N/A'}</p>
                    <p><strong>Institución:</strong> ${sol.persona.institucion || 'N/A'}</p>
                </div>
                
                ${sol.acceso ? `
                    <div style="margin-bottom: 1rem;">
                        <h4>Acceso VPN</h4>
                        <p><strong>ID:</strong> ${sol.acceso.id}</p>
                        <p><strong>Vence:</strong> ${formatDate(sol.acceso.fecha_fin)}</p>
                    </div>
                ` : ''}
            `);
            
        } catch (error) {
            hideLoading();
            showError('Error: ' + error.message);
        }
    }
};