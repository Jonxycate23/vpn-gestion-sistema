// Módulo de Accesos VPN - VERSIÓN CORREGIDA FINAL
// 📍 Ubicación: frontend/js/accesos.js
// ✅ Columna NIP funcionando + Ver motivo de bloqueo funcionando
// COPIAR Y PEGAR COMPLETO

const Accesos = {
    async load() {
        console.log('Cargando Accesos...');
        this.verificarEstructuraTabla();
        await this.loadAccesos();
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
            <div class="view-header">
                <h1>🔐 Gestión de Accesos VPN</h1>
            </div>
            
            <div class="card">
                <div class="card-body">
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
        `;
    },
    
    async loadAccesos() {
        try {
            const data = await API.get('/dashboard/accesos-actuales?limit=200');
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
            
            tbody.innerHTML = accesos.map(acceso => {
                const diasClass = acceso.dias_restantes <= 0 ? 'status-vencido' : 
                                 acceso.dias_restantes <= 7 ? 'status-por-vencer' : 'status-activo';
                
                // ✅ Generar username
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
                            ${acceso.dias_restantes > 0 && acceso.dias_restantes <= 30 ? `
                                <button class="btn btn-sm btn-warning" onclick="Accesos.prorrogar(${acceso.acceso_id})" title="Prorrogar">
                                    ⏰
                                </button>
                            ` : ''}
                            
                            ${acceso.estado_bloqueo === 'BLOQUEADO' ? `
                                <button class="btn btn-sm btn-info" onclick="Accesos.verMotivoBloqueo(${acceso.acceso_id})" title="Ver motivo">
                                    👁️
                                </button>
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
            
        } catch (error) {
            console.error('Error loading accesos:', error);
            showError('Error al cargar accesos: ' + error.message);
        }
    },
    
    async verMotivoBloqueo(accesoId) {
        try {
            showLoading();
            
            // ✅ Obtener información del bloqueo desde la tabla bloqueos_vpn
            const response = await API.get(`/accesos/${accesoId}/bloqueos`);
            
            hideLoading();
            
            if (!response || !response.bloqueos || response.bloqueos.length === 0) {
                showModal('📋 Motivo de Bloqueo', `
                    <div class="alert alert-info">
                        <strong>ℹ️ No se encontró información de bloqueo</strong><br>
                        Este acceso puede haber sido bloqueado automáticamente por el sistema.
                    </div>
                    <div style="margin-top: 1rem; text-align: center;">
                        <button class="btn btn-primary" onclick="hideModal()">Cerrar</button>
                    </div>
                `);
                return;
            }
            
            // Obtener el bloqueo más reciente (estado BLOQUEADO)
            const bloqueoActual = response.bloqueos.find(b => b.estado === 'BLOQUEADO') || response.bloqueos[0];
            
            const fecha_bloqueo = new Date(bloqueoActual.fecha_bloqueo);
            const fecha_formateada = fecha_bloqueo.toLocaleString('es-GT', {
                year: 'numeric',
                month: 'long',
                day: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
            });
            
            showModal('📋 Motivo de Bloqueo', `
                <div class="alert alert-warning">
                    <h4 style="margin-bottom: 0.5rem;">⚠️ Acceso Bloqueado</h4>
                </div>
                
                <div style="margin-bottom: 1.5rem;">
                    <p style="margin-bottom: 0.5rem;"><strong>Fecha de bloqueo:</strong> ${fecha_formateada}</p>
                    <p style="margin-bottom: 0.5rem;"><strong>Bloqueado por:</strong> ${bloqueoActual.usuario_bloqueo || 'Sistema Automático'}</p>
                    <p style="margin-bottom: 0.5rem;"><strong>Estado:</strong> ${getStatusBadge(bloqueoActual.estado)}</p>
                </div>
                
                <div style="padding: 1rem; background: #fff3cd; border: 1px solid #ffc107; border-radius: 4px; margin-bottom: 1rem;">
                    <strong style="color: #856404;">📝 Motivo del bloqueo:</strong>
                    <p style="margin-top: 0.75rem; color: #856404; line-height: 1.5;">
                        ${bloqueoActual.motivo || 'No se especificó motivo de bloqueo'}
                    </p>
                </div>
                
                ${response.bloqueos.length > 1 ? `
                    <div style="margin-top: 1.5rem; padding: 1rem; background: #f8f9fa; border-radius: 4px;">
                        <strong>📋 Historial de bloqueos (${response.bloqueos.length}):</strong>
                        <ul style="margin-top: 0.75rem; padding-left: 1.5rem;">
                            ${response.bloqueos.slice(0, 5).map(b => `
                                <li style="margin-bottom: 0.75rem;">
                                    <strong>${formatDate(b.fecha_bloqueo)}:</strong> ${b.motivo || 'Sin motivo especificado'}
                                    <br><small style="color: #6c757d;">
                                        Por: ${b.usuario_bloqueo || 'Sistema'} | 
                                        Estado: ${b.estado}
                                    </small>
                                </li>
                            `).join('')}
                        </ul>
                    </div>
                ` : ''}
                
                <div style="margin-top: 1.5rem; text-align: center;">
                    <button class="btn btn-primary" onclick="hideModal()">Cerrar</button>
                </div>
            `);
            
        } catch (error) {
            hideLoading();
            console.error('Error obteniendo motivo:', error);
            
            // Mostrar mensaje genérico
            showModal('📋 Motivo de Bloqueo', `
                <div class="alert alert-warning">
                    <h4>⚠️ Acceso Bloqueado</h4>
                    <p>Este acceso ha sido bloqueado por el administrador del sistema.</p>
                    <p><small>No se pudo obtener información detallada del bloqueo.</small></p>
                </div>
                <div style="margin-top: 1rem; text-align: center;">
                    <button class="btn btn-primary" onclick="hideModal()">Cerrar</button>
                </div>
            `);
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
                              placeholder="Ejemplo: Cambio de destino&#10;Ejemplo: Causo Alta></textarea>
                    <small class="form-text">Este motivo quedará registrado y será visible al consultar el bloqueo</small>
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
                showSuccess('Acceso bloqueado exitosamente. El motivo ha sido registrado.');
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
                    <small class="form-text">Este motivo quedará registrado</small>
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