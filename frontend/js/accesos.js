// Módulo de Accesos VPN - VERSIÓN MEJORADA
// Solo muestra accesos que tienen carta de responsabilidad creada
const Accesos = {
    async load() {
        console.log('Cargando Accesos...');
        await this.loadAccesos();
    },
    
    async loadAccesos() {
        try {
            const data = await API.get('/dashboard/accesos-actuales?limit=200');
            const tbody = document.querySelector('#accesosTable tbody');
            
            if (!tbody) {
                console.error('No se encontró la tabla de accesos');
                return;
            }
            
            // FILTRAR: Solo mostrar accesos que tienen carta creada
            const accesosConCarta = data.accesos.filter(acceso => acceso.carta_generada === true);
            
            if (!accesosConCarta || accesosConCarta.length === 0) {
                tbody.innerHTML = '<tr><td colspan="8" style="text-align: center;">No hay accesos con carta firmada</td></tr>';
                return;
            }
            
            tbody.innerHTML = accesosConCarta.map(acceso => {
                const diasClass = acceso.dias_restantes <= 0 ? 'status-vencido' : 
                                 acceso.dias_restantes <= 7 ? 'status-por-vencer' : 'status-activo';
                
                return `
                    <tr>
                        <td>${acceso.dpi}</td>
                        <td>${acceso.nombres} ${acceso.apellidos}</td>
                        <td>${formatDate(acceso.fecha_inicio)}</td>
                        <td>${formatDate(acceso.fecha_fin_con_gracia)}</td>
                        <td>${getStatusBadge(acceso.estado_vigencia)}</td>
                        <td><span class="status-badge ${diasClass}">${acceso.dias_restantes} días</span></td>
                        <td>${getStatusBadge(acceso.estado_bloqueo || 'DESBLOQUEADO')}</td>
                        <td>
                            ${acceso.dias_restantes > 0 && acceso.dias_restantes <= 30 ? `
                                <button class="btn btn-sm btn-warning" onclick="Accesos.prorrogar(${acceso.acceso_id})" title="Prorrogar">
                                    ⏰
                                </button>
                            ` : ''}
                            ${acceso.estado_bloqueo !== 'BLOQUEADO' ? `
                                <button class="btn btn-sm btn-danger" onclick="Accesos.bloquear(${acceso.acceso_id})" title="Bloquear">
                                    🚫
                                </button>
                            ` : `
                                <button class="btn btn-sm btn-success" onclick="Accesos.desbloquear(${acceso.acceso_id})" title="Desbloquear">
                                    ✅
                                </button>
                            `}
                        </td>
                    </tr>
                `;
            }).join('');
            
        } catch (error) {
            console.error('Error loading accesos:', error);
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
                              placeholder="Explica el motivo del bloqueo..."></textarea>
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
                              placeholder="Explica el motivo del desbloqueo..."></textarea>
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