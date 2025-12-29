// Módulo de Dashboard
const Dashboard = {
    async load() {
        await this.loadStats();
        await this.loadRecentAccess();
    },
    
    async loadStats() {
        try {
            const data = await API.get('/dashboard/vencimientos');
            
            document.getElementById('statActivos').textContent = data.activos;
            document.getElementById('statPorVencer').textContent = data.por_vencer;
            document.getElementById('statVencidos').textContent = data.vencidos;
            document.getElementById('statBloqueados').textContent = data.bloqueados;
        } catch (error) {
            console.error('Error loading stats:', error);
        }
    },
    
    async loadRecentAccess() {
        try {
            const data = await API.get('/dashboard/accesos-actuales?limit=10');
            const tbody = document.querySelector('#dashboardTable tbody');
            
            if (data.accesos.length === 0) {
                tbody.innerHTML = '<tr><td colspan="6" style="text-align: center;">No hay accesos registrados</td></tr>';
                return;
            }
            
            tbody.innerHTML = data.accesos.map(acceso => `
                <tr>
                    <td>${acceso.dpi}</td>
                    <td>${acceso.nombres} ${acceso.apellidos}</td>
                    <td>${acceso.institucion || '-'}</td>
                    <td>${getStatusBadge(acceso.estado_vigencia)}</td>
                    <td>${acceso.dias_restantes} días</td>
                    <td>
                        <button class="btn btn-sm" onclick="verDetalleAcceso(${acceso.acceso_id})">
                            Ver
                        </button>
                    </td>
                </tr>
            `).join('');
        } catch (error) {
            console.error('Error loading accesos:', error);
        }
    }
};

// Event Listeners
document.getElementById('refreshDashboard').addEventListener('click', () => {
    Dashboard.load();
});
