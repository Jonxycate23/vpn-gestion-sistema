// Módulo de Solicitudes
const Solicitudes = {
    async load() {
        await this.loadSolicitudes();
    },
    
    async loadSolicitudes() {
        try {
            const data = await API.get('/solicitudes/?limit=50');
            const tbody = document.querySelector('#solicitudesTable tbody');
            
            if (data.solicitudes.length === 0) {
                tbody.innerHTML = '<tr><td colspan="6" style="text-align: center;">No hay solicitudes registradas</td></tr>';
                return;
            }
            
            tbody.innerHTML = data.solicitudes.map(sol => `
                <tr>
                    <td>${formatDate(sol.fecha_solicitud)}</td>
                    <td>${sol.persona_dpi}</td>
                    <td>${sol.persona_nombres} ${sol.persona_apellidos}</td>
                    <td>${sol.tipo_solicitud}</td>
                    <td>${getStatusBadge(sol.estado)}</td>
                    <td>
                        <button class="btn btn-sm" onclick="verDetalleSolicitud(${sol.id})">
                            Ver
                        </button>
                    </td>
                </tr>
            `).join('');
        } catch (error) {
            console.error('Error loading solicitudes:', error);
        }
    }
};

// Módulo de Accesos
const Accesos = {
    async load() {
        await this.loadAccesos();
    },
    
    async loadAccesos() {
        try {
            const data = await API.get('/dashboard/accesos-actuales?limit=100');
            const tbody = document.querySelector('#accesosTable tbody');
            
            if (data.accesos.length === 0) {
                tbody.innerHTML = '<tr><td colspan="8" style="text-align: center;">No hay accesos registrados</td></tr>';
                return;
            }
            
            tbody.innerHTML = data.accesos.map(acceso => `
                <tr>
                    <td>${acceso.dpi}</td>
                    <td>${acceso.nombres} ${acceso.apellidos}</td>
                    <td>${formatDate(acceso.fecha_inicio)}</td>
                    <td>${formatDate(acceso.fecha_fin_con_gracia)}</td>
                    <td>${getStatusBadge(acceso.estado_vigencia)}</td>
                    <td>${acceso.dias_restantes} días</td>
                    <td>${getStatusBadge(acceso.estado_bloqueo || 'DESBLOQUEADO')}</td>
                    <td>
                        <button class="btn btn-sm btn-warning" onclick="Accesos.prorrogar(${acceso.acceso_id})">
                            ⏰ Prorrogar
                        </button>
                        <button class="btn btn-sm btn-danger" onclick="Accesos.bloquear(${acceso.acceso_id})">
                            🚫 Bloquear
                        </button>
                    </td>
                </tr>
            `).join('');
        } catch (error) {
            console.error('Error loading accesos:', error);
        }
    },
    
    async prorrogar(accesoId) {
        const form = `
            <form id="formProrrogar">
                <div class="form-group">
                    <label>Días adicionales *</label>
                    <input type="number" id="dias_adicionales" required min="1" max="90">
                </div>
                <div class="form-group">
                    <label>Motivo *</label>
                    <textarea id="motivo" required></textarea>
                </div>
                <button type="submit" class="btn btn-primary">Prorrogar Acceso</button>
            </form>
        `;
        
        showModal('Prorrogar Acceso VPN', form);
        
        document.getElementById('formProrrogar').addEventListener('submit', async (e) => {
            e.preventDefault();
            
            const data = {
                dias_adicionales: parseInt(document.getElementById('dias_adicionales').value),
                motivo: document.getElementById('motivo').value
            };
            
            try {
                await API.post(`/accesos/${accesoId}/prorrogar`, data);
                hideModal();
                showSuccess('Prórroga aplicada exitosamente');
                this.load();
            } catch (error) {
                showError(error.message);
            }
        });
    },
    
    async bloquear(accesoId) {
        const form = `
            <form id="formBloquear">
                <div class="form-group">
                    <label>Acción *</label>
                    <select id="estado" required>
                        <option value="BLOQUEADO">Bloquear Acceso</option>
                        <option value="DESBLOQUEADO">Desbloquear Acceso</option>
                    </select>
                </div>
                <div class="form-group">
                    <label>Motivo *</label>
                    <textarea id="motivo" required></textarea>
                </div>
                <button type="submit" class="btn btn-primary">Confirmar</button>
            </form>
        `;
        
        showModal('Bloquear/Desbloquear Acceso VPN', form);
        
        document.getElementById('formBloquear').addEventListener('submit', async (e) => {
            e.preventDefault();
            
            const data = {
                acceso_vpn_id: accesoId,
                estado: document.getElementById('estado').value,
                motivo: document.getElementById('motivo').value
            };
            
            try {
                await API.post('/accesos/bloquear', data);
                hideModal();
                showSuccess('Estado actualizado exitosamente');
                this.load();
            } catch (error) {
                showError(error.message);
            }
        });
    }
};

// Funciones globales
function verDetalleSolicitud(id) {
    alert(`Ver detalle solicitud ${id} - Funcionalidad pendiente`);
}

function verDetalleAcceso(id) {
    alert(`Ver detalle acceso ${id} - Funcionalidad pendiente`);
}
