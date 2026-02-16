// Módulo de Accesos VPN 
const Accesos = {
    ordenActual: 'prioridad',
    datosOriginales: [],


    async load() {
        console.log('Cargando Accesos...');
        this.verificarEstructuraTabla();
        await this.loadAccesos();

        // ✅ SOLO REFRESCAR SI YA ESTÁ INICIALIZADA
        if (typeof tablesInitialized !== 'undefined' && tablesInitialized.accesosTable) {
            console.log('🔄 Refrescando tabla de accesos...');
            IntegratedTableSystem.refresh('accesosTable');
        }
    },

    verificarEstructuraTabla() {
        let contenedor = document.getElementById('accesosView');
        if (!contenedor) {
            console.error('No se encontró accesosView');
            return;
        }

        let tabla = contenedor.querySelector('#accesosTable');
        if (tabla) {
            return;
        }

        contenedor.innerHTML = `
            <div class="view-header" style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem;">
                <div style="display: flex; align-items: center; gap: 1rem;">
                    <h1>🔐 Gestión de Accesos VPN</h1>
                    
                    <!-- ✅ SELECTOR DE ORDENAMIENTO -->
                    <select id="selectOrdenAccesos" class="btn btn-sm btn-outline" 
                            onchange="Accesos.cambiarOrden(this.value)"
                            style="padding: 0.5rem; border: 1px solid #ddd; border-radius: 4px; cursor: pointer;">
                        <option value="prioridad">⚡ Por Prioridad (Vencen Pronto)</option>
                        <option value="dias_asc">📅 Días Restantes (Menor a Mayor)</option>
                        <option value="dias_desc">📅 Días Restantes (Mayor a Menor)</option>
                        <option value="nombre_asc">👤 Nombre (A-Z)</option>
                        <option value="nombre_desc">👤 Nombre (Z-A)</option>
                    </select>
                </div>
            </div>
            
            <div class="card">
                <div class="card-body">
                    <div class="table-wrapper">
                        <table class="table" id="accesosTable">
                            <thead>
                                <tr>
                                    <th>NIP</th>
                                    <th>Nombre</th>
                                    <th>Usuario</th>
                                    <th>F. Inicio</th>
                                    <th>F. Fin</th>
                                    <th>Estado</th>
                                    <th>Días Restantes</th>
                                    <th>Bloqueo</th>
                                    <th>Acciones</th>
                                </tr>
                            </thead>
                            <tbody>
                                <tr><td colspan="9" style="text-align: center;">Cargando...</td></tr>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        `;
    },

    cambiarOrden(nuevoOrden) {
        this.ordenActual = nuevoOrden;
        console.log(`🔄 Orden cambiado a: ${nuevoOrden}`);
        this.renderizarAccesos();
    },

    async loadAccesos() {
        try {
            const data = await API.get('/dashboard/accesos-actuales?limit=5000');
            const tbody = document.querySelector('#accesosTable tbody');

            if (!tbody) {
                console.error('No se encontró la tabla de accesos');
                return;
            }

            const accesos = data.accesos || [];

            if (accesos.length === 0) {
                tbody.innerHTML = '<tr><td colspan="9" style="text-align: center;">No hay accesos VPN registrados</td></tr>';
                return;
            }

            // ✅ Guardar datos originales
            this.datosOriginales = accesos;

            // ✅ Renderizar con el orden actual
            this.renderizarAccesos();

        } catch (error) {
            console.error('Error loading accesos:', error);
            showError('Error al cargar accesos: ' + error.message);
        }
    },

    // ✅ NUEVA FUNCIÓN: Renderizar con orden actual
    renderizarAccesos() {
        const tbody = document.querySelector('#accesosTable tbody');
        if (!tbody) return;

        // ✅ Ordenar según la opción seleccionada
        let accesosOrdenados = [...this.datosOriginales];

        switch (this.ordenActual) {
            case 'prioridad':
                // Prioridad: Vencidos y por vencer primero
                accesosOrdenados.sort((a, b) => {
                    if (a.dias_restantes <= 30 && b.dias_restantes > 30) return -1;
                    if (a.dias_restantes > 30 && b.dias_restantes <= 30) return 1;
                    return a.dias_restantes - b.dias_restantes;
                });
                break;

            case 'dias_asc':
                // Días restantes: menor a mayor
                accesosOrdenados.sort((a, b) => a.dias_restantes - b.dias_restantes);
                break;

            case 'dias_desc':
                // Días restantes: mayor a menor
                accesosOrdenados.sort((a, b) => b.dias_restantes - a.dias_restantes);
                break;

            case 'nombre_asc':
                // Nombre: A-Z
                accesosOrdenados.sort((a, b) => {
                    const nombreA = `${a.nombres} ${a.apellidos}`.toLowerCase();
                    const nombreB = `${b.nombres} ${b.apellidos}`.toLowerCase();
                    return nombreA.localeCompare(nombreB);
                });
                break;

            case 'nombre_desc':
                // Nombre: Z-A
                accesosOrdenados.sort((a, b) => {
                    const nombreA = `${a.nombres} ${a.apellidos}`.toLowerCase();
                    const nombreB = `${b.nombres} ${b.apellidos}`.toLowerCase();
                    return nombreB.localeCompare(nombreA);
                });
                break;
        }

        tbody.innerHTML = accesosOrdenados.map(acceso => {
            const diasClass = acceso.dias_restantes < 0 ? 'status-vencido' :
                acceso.dias_restantes <= 7 ? 'status-por-vencer' : 'status-activo';

            // Generar username
            const nombresArray = acceso.nombres.toLowerCase().split(' ');
            const apellidosArray = acceso.apellidos.toLowerCase().split(' ');
            const username = `${nombresArray[0]}.${apellidosArray[0]}`;

            return `
                <tr>
                    <td><strong>${acceso.nip || 'N/A'}</strong></td>
                    <td>${acceso.nombres} ${acceso.apellidos}</td>
                    <td><code>${username}</code></td>
                    <td>${formatDate(acceso.fecha_inicio)}</td>
                    <td>${formatDate(acceso.fecha_fin_con_gracia)}</td>
                    <td>${getStatusBadge(acceso.estado_vigencia)}</td>
                    <td><span class="status-badge ${diasClass}">${acceso.dias_restantes} días</span></td>
                    <td>${getStatusBadge(acceso.estado_bloqueo || 'DESBLOQUEADO')}</td>
                    <td style="white-space: nowrap;">
                        <button class="btn btn-sm btn-info" onclick="Accesos.verDetalles(${acceso.acceso_id})" title="Ver detalles completos">
                            👁️
                        </button>
                        
                        ${acceso.dias_restantes > 0 && acceso.dias_restantes <= 30 ? `
                            <button class="btn btn-sm btn-warning" onclick="Accesos.prorrogar(${acceso.acceso_id})" title="Prorrogar">
                                ⏰
                            </button>
                        ` : ''}
                        
                        ${acceso.estado_bloqueo === 'BLOQUEADO' ? `
                            <button class="btn btn-sm btn-success" onclick="Accesos.desbloquear(${acceso.acceso_id})" title="Desbloquear">
                                ✅
                            </button>
                        ` : `
                            <button class="btn btn-sm btn-danger" onclick="Accesos.bloquear(${acceso.acceso_id})" title="Bloquear">
                                🚫
                            </button>
                        `}
                    </td>
                </tr>
            `;
        }).join('');

        console.log(`✅ ${accesosOrdenados.length} accesos ordenados (${this.ordenActual})`);

        // ✅ Refrescar paginación si existe
        if (typeof Paginator !== 'undefined' && Paginator.configs['accesosTable']) {
            Paginator.refresh('accesosTable');
        }
    },

    async verDetalles(accesoId) {
        try {
            showLoading();

            // Obtener detalles completos del acceso
            const acceso = await API.get(`/accesos/${accesoId}`);

            hideLoading();

            // Generar username
            const nombresArray = acceso.persona.nombres.toLowerCase().split(' ');
            const apellidosArray = acceso.persona.apellidos.toLowerCase().split(' ');
            const username = `${nombresArray[0]}.${apellidosArray[0]}`;

            // Calcular fecha de expiración 
            const fechaExpiracion = new Date(acceso.fecha_fin_con_gracia + 'T00:00:00');

            showModal('📋 Detalles Completos del Acceso VPN', `
                <div style="max-height: 70vh; overflow-y: auto;">
                    
                    <!-- Datos Administrativos -->
                    <div style="background: #f8f9fa; padding: 1rem; border-radius: 4px; margin-bottom: 1rem;">
                        <h4 style="margin-bottom: 1rem;">📋 Datos Administrativos</h4>
                        <p style="margin-bottom: 0.5rem;"><strong>Oficio:</strong> ${acceso.solicitud?.numero_oficio || 'N/A'}</p>
                        <p style="margin-bottom: 0.5rem;"><strong>Providencia:</strong> ${acceso.solicitud?.numero_providencia || 'N/A'}</p>
                        <p style="margin-bottom: 0.5rem;"><strong>Fecha Recepción:</strong> ${formatDate(acceso.solicitud?.fecha_recepcion)}</p>
                        <p style="margin-bottom: 0.5rem;"><strong>Tipo:</strong> ${acceso.solicitud?.tipo_solicitud || 'N/A'}</p>
                        <p style="margin-bottom: 0.5rem;"><strong>Estado:</strong> ${getStatusBadge(acceso.solicitud?.estado || 'APROBADA')}</p>
                    </div>
                    
                    <!-- Persona -->
                    <div style="background: #e3f2fd; padding: 1rem; border-radius: 4px; margin-bottom: 1rem;">
                        <h4 style="margin-bottom: 1rem;">👤 Persona</h4>
                        <p style="margin-bottom: 0.5rem;"><strong>Nombre:</strong> ${acceso.persona.nombres} ${acceso.persona.apellidos}</p>
                        <p style="margin-bottom: 0.5rem;"><strong>NIP:</strong> ${acceso.persona.nip || 'N/A'}</p>
                        <p style="margin-bottom: 0.5rem;"><strong>DPI:</strong> ${acceso.persona.dpi}</p>
                        <p style="margin-bottom: 0.5rem;"><strong>Cargo:</strong> ${acceso.persona.cargo || 'N/A'}</p>
                        <p style="margin-bottom: 0.5rem;"><strong>Institución:</strong> ${acceso.persona.institucion || 'N/A'}</p>
                        <p style="margin-bottom: 0.5rem;"><strong>Email:</strong> ${acceso.persona.email || 'N/A'}</p>
                        <p style="margin-bottom: 0.5rem;"><strong>Teléfono:</strong> ${acceso.persona.telefono || 'N/A'}</p>
                    </div>
                    
                    <!-- Acceso VPN -->
                    <div style="background: #fff3cd; padding: 1rem; border-radius: 4px; margin-bottom: 1rem;">
                        <h4 style="margin-bottom: 1rem;">🔐 Acceso VPN</h4>
                        <p style="margin-bottom: 0.5rem;"><strong>ID Acceso:</strong> ${acceso.id}</p>
                        <p style="margin-bottom: 0.5rem;"><strong>Usuario VPN:</strong> <code>${username}</code></p>
                        <p style="margin-bottom: 0.5rem;"><strong>Fecha Inicio:</strong> ${formatDate(acceso.fecha_inicio)}</p>
                        <p style="margin-bottom: 0.5rem;"><strong>Fecha Fin:</strong> ${formatDate(acceso.fecha_fin)}</p>
                        <p style="margin-bottom: 0.5rem;"><strong>Días de Gracia:</strong> ${acceso.dias_gracia} días</p>
                        <p style="margin-bottom: 0.5rem;"><strong>Fecha Fin (con gracia):</strong> ${formatDate(acceso.fecha_fin_con_gracia)}</p>
                        <p style="margin-bottom: 0.5rem;"><strong>Estado Vigencia:</strong> ${getStatusBadge(acceso.estado_vigencia)}</p>
                        <p style="margin-bottom: 0.5rem;"><strong>Días Restantes:</strong> <span class="status-badge ${acceso.dias_restantes < 0 ? 'status-vencido' : acceso.dias_restantes <= 7 ? 'status-por-vencer' : 'status-activo'}">${acceso.dias_restantes} días</span></p>
                        <p style="margin-bottom: 0.5rem;"><strong>Estado Bloqueo:</strong> ${getStatusBadge(acceso.estado_bloqueo)}</p>
                    </div>
                    
                    <!-- Carta de Responsabilidad -->
                    ${acceso.carta_id ? `
                        <div style="background: #d1f2eb; padding: 1rem; border-radius: 4px; margin-bottom: 1rem;">
                            <h4 style="margin-bottom: 1rem;">📄 Carta de Responsabilidad</h4>
                            <p style="margin-bottom: 0.5rem;"><strong>Número de Carta:</strong> ${acceso.numero_carta || 'N/A'}-${acceso.anio_carta || 'N/A'}</p>
                            <p style="margin-bottom: 0.5rem;"><strong>Fecha Generación:</strong> ${formatDate(acceso.carta_fecha_generacion)}</p>
                            <p style="margin-bottom: 0.5rem;"><strong>Fecha Expiración:</strong> ${fechaExpiracion.toLocaleDateString('es-GT')}</p>
                            
                            <div style="margin-top: 1rem;">
                                <button class="btn btn-primary btn-block" onclick="Accesos.descargarCarta(${acceso.solicitud_id})">
                                    📥 Descargar Carta PDF
                                </button>
                            </div>
                        </div>
                    ` : `
                        <div style="background: #f8d7da; padding: 1rem; border-radius: 4px; margin-bottom: 1rem;">
                            <h4 style="margin-bottom: 0.5rem;">⚠️ Sin Carta de Responsabilidad</h4>
                            <p style="margin-bottom: 0;">Este acceso aún no tiene carta generada.</p>
                        </div>
                    `}
                    
                </div>
                
                <div style="margin-top: 1.5rem; text-align: center;">
                    ${acceso.estado_bloqueo === 'BLOQUEADO' ? `
                        <button class="btn btn-success" onclick="Accesos.desbloquear(${accesoId}); hideModal();" style="margin-right: 0.5rem;">
                            ✅ Desbloquear
                        </button>
                    ` : `
                        <button class="btn btn-danger" onclick="Accesos.bloquear(${accesoId}); hideModal();" style="margin-right: 0.5rem;">
                            🚫 Bloquear
                        </button>
                    `}
                    
                    ${acceso.dias_restantes > 0 && acceso.dias_restantes <= 30 ? `
                        <button class="btn btn-warning" onclick="Accesos.prorrogar(${accesoId}); hideModal();" style="margin-right: 0.5rem;">
                            ⏰ Prorrogar
                        </button>
                    ` : ''}
                    
                    <button class="btn btn-outline" onclick="hideModal()">
                        Cerrar
                    </button>
                </div>
            `);

        } catch (error) {
            hideLoading();
            console.error('Error obteniendo detalles:', error);
            showError('Error al obtener detalles: ' + error.message);
        }
    },

    async descargarCarta(solicitudId) {
        try {
            await API.downloadFile(
                `/solicitudes/${solicitudId}/descargar-carta`,
                `CARTA_RESPONSABILIDAD_${solicitudId}.pdf`
            );
            showSuccess('📥 PDF descargado exitosamente');
        } catch (error) {
            showError('Error al descargar PDF: ' + error.message);
            console.error('Detalle del error:', error);
        }
    },

    async prorrogar(accesoId) {
        const form = `
            <form id="formProrrogar">
                <div class="form-group">
                    <label>Días adicionales de gracia *</label>
                    <input type="number" id="dias_adicionales" required min="1" max="90" value="15">
                    <small class="form-text">Máximo 90 días</small>
                </div>
                <div class="form-group">
                    <label>Motivo de la prórroga *</label>
                    <textarea id="motivo" required rows="3" 
                              placeholder="Justifica la prórroga..."></textarea>
                </div>
                <button type="submit" class="btn btn-primary btn-block">
                    ⏰ Aplicar Prórroga
                </button>
            </form>
        `;

        showModal('Prorrogar Acceso VPN', form);

        document.getElementById('formProrrogar').addEventListener('submit', async (e) => {
            e.preventDefault();

            try {
                showLoading();
                const data = {
                    dias_adicionales: parseInt(document.getElementById('dias_adicionales').value),
                    motivo: document.getElementById('motivo').value
                };

                await API.post(`/accesos/${accesoId}/prorrogar`, data);
                hideLoading();
                hideModal();
                showSuccess('Prórroga aplicada exitosamente');
                this.load();
            } catch (error) {
                hideLoading();
                showError('Error: ' + error.message);
            }
        });
    },

    async bloquear(accesoId) {
        const form = `
            <form id="formBloquear">
                <div class="alert alert-warning">
                    <strong>⚠️ Estás a punto de BLOQUEAR este acceso VPN</strong><br>
                    El usuario no podrá acceder a la VPN hasta que sea desbloqueado.
                </div>
                <div class="form-group">
                    <label>Motivo del bloqueo *</label>
                    <textarea id="motivo" required rows="4" 
                              placeholder="Ejemplo: Cambio de destino&#10;Ejemplo: Causó Alta"></textarea>
                    <small class="form-text">Este motivo quedará registrado</small>
                </div>
                <button type="submit" class="btn btn-danger btn-block">
                    🚫 Confirmar Bloqueo
                </button>
            </form>
        `;

        showModal('Bloquear Acceso VPN', form);

        document.getElementById('formBloquear').addEventListener('submit', async (e) => {
            e.preventDefault();

            try {
                showLoading();
                const data = {
                    acceso_vpn_id: accesoId,
                    estado: 'BLOQUEADO',
                    motivo: document.getElementById('motivo').value
                };

                await API.post('/accesos/bloquear', data);
                hideLoading();
                hideModal();
                showSuccess('Acceso bloqueado exitosamente');
                this.load();
            } catch (error) {
                hideLoading();
                showError('Error: ' + error.message);
            }
        });
    },

    async desbloquear(accesoId) {
        const form = `
            <form id="formDesbloquear">
                <div class="alert alert-info">
                    <strong>✅ Estás a punto de DESBLOQUEAR este acceso VPN</strong><br>
                    El usuario podrá volver a acceder a la VPN.
                </div>
                <div class="form-group">
                    <label>Motivo del desbloqueo *</label>
                    <textarea id="motivo" required rows="4" 
                              placeholder="Ejemplo: Usuario ha regresado a su puesto&#10;Ejemplo: Solicitud de reactivación aprobada"></textarea>
                </div>
                <button type="submit" class="btn btn-success btn-block">
                    ✅ Confirmar Desbloqueo
                </button>
            </form>
        `;

        showModal('Desbloquear Acceso VPN', form);

        document.getElementById('formDesbloquear').addEventListener('submit', async (e) => {
            e.preventDefault();

            try {
                showLoading();
                const data = {
                    acceso_vpn_id: accesoId,
                    estado: 'DESBLOQUEADO',
                    motivo: document.getElementById('motivo').value
                };

                await API.post('/accesos/bloquear', data);
                hideLoading();
                hideModal();
                showSuccess('Acceso desbloqueado exitosamente');
                this.load();
            } catch (error) {
                hideLoading();
                showError('Error: ' + error.message);
            }
        });
    }
};