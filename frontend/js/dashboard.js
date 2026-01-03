// Módulo de Dashboard - SOLO ALERTAS DE VENCIMIENTOS
const Dashboard = {
    async load() {
        console.log('Cargando Dashboard...');
        await this.loadStats();
        await this.loadVencimientosHoy();
        await this.loadProximosVencer();
    },
    
    async loadStats() {
        try {
            const data = await API.get('/dashboard/vencimientos');
            
            // Actualizar estadísticas
            document.getElementById('statActivos').textContent = data.activos || 0;
            document.getElementById('statPorVencer').textContent = data.por_vencer || 0;
            document.getElementById('statVencidos').textContent = data.vencidos || 0;
            document.getElementById('statBloqueados').textContent = data.bloqueados || 0;
            
            console.log('Estadísticas cargadas:', data);
        } catch (error) {
            console.error('Error loading stats:', error);
        }
    },
    
    async loadVencimientosHoy() {
        try {
            const data = await API.get('/dashboard/vencimientos');
            
            // Buscar contenedor de alertas
            let alertContainer = document.getElementById('alertasContainer');
            if (!alertContainer) {
                alertContainer = document.createElement('div');
                alertContainer.id = 'alertasContainer';
                const dashboardView = document.getElementById('dashboardView');
                const statsGrid = document.querySelector('.stats-grid');
                if (statsGrid) {
                    statsGrid.parentNode.insertBefore(alertContainer, statsGrid.nextSibling);
                }
            }
            
            // Limpiar alertas anteriores
            alertContainer.innerHTML = '';
            
            // Alerta de vencimientos HOY
            if (data.vencen_hoy > 0) {
                const alertaHoy = document.createElement('div');
                alertaHoy.className = 'card';
                alertaHoy.style.background = '#fee2e2';
                alertaHoy.style.border = '2px solid #dc2626';
                alertaHoy.style.marginBottom = '1rem';
                alertaHoy.innerHTML = `
                    <div class="card-body">
                        <h3 style="color: #dc2626; margin-bottom: 1rem;">
                            ⚠️ ATENCIÓN URGENTE: ${data.vencen_hoy} usuario(s) vencen HOY
                        </h3>
                        <p style="margin-bottom: 1rem;">Estos usuarios requieren bloqueo inmediato.</p>
                        <button class="btn btn-danger" onclick="Dashboard.irABloquear()">
                            🚫 Ir a Bloquear Ahora
                        </button>
                    </div>
                `;
                alertContainer.appendChild(alertaHoy);
            }
            
            // Alerta de próximos a vencer (esta semana)
            if (data.vencen_esta_semana > 0) {
                const alertaSemana = document.createElement('div');
                alertaSemana.className = 'card';
                alertaSemana.style.background = '#fef3c7';
                alertaSemana.style.border = '2px solid #f59e0b';
                alertaSemana.style.marginBottom = '1rem';
                alertaSemana.innerHTML = `
                    <div class="card-body">
                        <h3 style="color: #d97706; margin-bottom: 1rem;">
                            ⏰ Próximos a Vencer: ${data.vencen_esta_semana} usuario(s) esta semana
                        </h3>
                        <p style="margin-bottom: 1rem;">Usuarios que vencerán en los próximos 7 días.</p>
                        <button class="btn btn-warning" onclick="Dashboard.verProximosVencer()">
                            📋 Ver Listado
                        </button>
                    </div>
                `;
                alertContainer.appendChild(alertaSemana);
            }
            
        } catch (error) {
            console.error('Error loading vencimientos hoy:', error);
        }
    },
    
    async loadProximosVencer() {
        try {
            const data = await API.get('/dashboard/accesos-actuales?limit=100');
            const tbody = document.querySelector('#dashboardTable tbody');
            
            if (!tbody) {
                console.error('No se encontró la tabla del dashboard');
                return;
            }
            
            // Filtrar solo los que están por vencer (próximos 30 días)
            const proximosVencer = data.accesos.filter(acceso => {
                return acceso.dias_restantes <= 30 && acceso.dias_restantes >= 0;
            }).sort((a, b) => a.dias_restantes - b.dias_restantes);
            
            if (proximosVencer.length === 0) {
                tbody.innerHTML = '<tr><td colspan="6" style="text-align: center; color: #10b981;">✅ No hay usuarios próximos a vencer</td></tr>';
                return;
            }
            
            tbody.innerHTML = proximosVencer.slice(0, 10).map(acceso => {
                let badgeClass = 'status-activo';
                if (acceso.dias_restantes === 0) {
                    badgeClass = 'status-vencido';
                } else if (acceso.dias_restantes <= 7) {
                    badgeClass = 'status-por-vencer';
                }
                
                return `
                    <tr>
                        <td>${acceso.nip}</td>
                        <td>${acceso.nombres} ${acceso.apellidos}</td>
                        <td>${acceso.institucion || '-'}</td>
                        <td><span class="status-badge ${badgeClass}">${acceso.dias_restantes} días</span></td>
                        <td>${formatDate(acceso.fecha_fin_con_gracia)}</td>
                        <td>
                            <button class="btn btn-sm btn-danger" onclick="Dashboard.bloquearRapido(${acceso.acceso_id})">
                                🚫 Bloquear
                            </button>
                        </td>
                    </tr>
                `;
            }).join('');
            
        } catch (error) {
            console.error('Error loading próximos a vencer:', error);
        }
    },
    
    irABloquear() {
        // Cambiar a vista de accesos
        document.querySelector('[data-view="accesos"]').click();
    },
    
    verProximosVencer() {
        // Cambiar a vista de accesos
        document.querySelector('[data-view="accesos"]').click();
    },
    
    async bloquearRapido(accesoId) {
        if (!confirm('¿Bloquear este acceso VPN?')) {
            return;
        }
        
        const motivo = prompt('Motivo del bloqueo:');
        if (!motivo) {
            alert('El motivo es obligatorio');
            return;
        }
        
        try {
            await API.post('/accesos/bloquear', {
                acceso_vpn_id: accesoId,
                estado: 'BLOQUEADO',
                motivo: motivo
            });
            
            showSuccess('Acceso bloqueado exitosamente');
            this.load(); // Recargar dashboard
        } catch (error) {
            showError('Error al bloquear: ' + error.message);
        }
    }
};

// Event Listeners
document.addEventListener('DOMContentLoaded', () => {
    const refreshBtn = document.getElementById('refreshDashboard');
    if (refreshBtn) {
        refreshBtn.addEventListener('click', () => {
            Dashboard.load();
        });
    }
});
