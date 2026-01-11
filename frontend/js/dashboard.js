// 📊 Dashboard MEJORADO con Historial de Cartas - VERSIÓN CORREGIDA
// 📍 Ubicación: frontend/js/dashboard.js
// ✅ CORREGIDO: Previene flechitas duplicadas + Filtra usuarios entre -30 y +30 días

const Dashboard = {
    // ✅ PREVENIR INICIALIZACIONES MÚLTIPLES
    _initialized: false,
    _cleanupExecuted: false,
    
    async load() {
        console.log('🔄 Cargando Dashboard Inteligente...');
        
        // ✅ LIMPIEZA DE INDICADORES DUPLICADOS (SOLO UNA VEZ)
        if (!this._cleanupExecuted) {
            this.limpiarIndicadoresDuplicados();
            this._cleanupExecuted = true;
        }
        
        await this.loadStats();
        await this.loadAlertasInteligentes();
    },
    
    // ✅ NUEVA FUNCIÓN: Limpiar flechitas duplicadas
    limpiarIndicadoresDuplicados() {
        console.log('🧹 Limpiando indicadores de ordenamiento duplicados...');
        
        const todasLasTablas = document.querySelectorAll('table');
        todasLasTablas.forEach(tabla => {
            const headers = tabla.querySelectorAll('thead th');
            headers.forEach(header => {
                const indicators = header.querySelectorAll('.sort-indicator');
                
                // Si hay más de 1 indicador, eliminar todos excepto el último
                if (indicators.length > 1) {
                    console.log(`⚠️ Encontradas ${indicators.length} flechitas en una columna. Limpiando...`);
                    for (let i = 0; i < indicators.length - 1; i++) {
                        indicators[i].remove();
                    }
                }
            });
        });
    },
    
    async loadStats() {
        try {
            const data = await API.get('/dashboard/vencimientos');
            
            document.getElementById('statActivos').textContent = data.activos || 0;
            document.getElementById('statPorVencer').textContent = data.por_vencer || 0;
            document.getElementById('statVencidos').textContent = data.vencidos || 0;
            document.getElementById('statBloqueados').textContent = data.bloqueados || 0;
            
            console.log('✅ Estadísticas cargadas:', data);
        } catch (error) {
            console.error('❌ Error loading stats:', error);
        }
    },
    
    async loadAlertasInteligentes() {
        try {
            const data = await API.get('/dashboard/alertas-vencimientos-inteligentes');
            
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
            
            alertContainer.innerHTML = '';
            
            // ✅ FILTRAR: Solo mostrar usuarios entre -30 y +30 días
            const alertasFiltradas = data.alertas.filter(alerta => {
                const diasRestantes = alerta.dias_restantes_acceso_actual;
                return diasRestantes >= -30 && diasRestantes <= 30;
            });
            
            console.log(`📊 Total alertas: ${data.alertas.length} | Filtradas (-30 a +30): ${alertasFiltradas.length}`);
            
            if (alertasFiltradas.length === 0) {
                alertContainer.innerHTML = `
                    <div class="card" style="background: #d1fae5; border: 1px solid #10b981;">
                        <div class="card-body">
                            <h3 style="color: #065f46; text-align: center;">
                                ✅ No hay usuarios por revisar en el rango de -30 a +30 días
                            </h3>
                        </div>
                    </div>
                `;
                return;
            }
            
            // Separar por tipo para el resumen (usando alertas filtradas)
            const vencidosSinRenovacion = alertasFiltradas.filter(a => a.tipo_alerta === 'VENCIDO_SIN_RENOVACION');
            const porVencerUrgente = alertasFiltradas.filter(a => a.tipo_alerta === 'POR_VENCER_URGENTE');
            const porVencer = alertasFiltradas.filter(a => a.tipo_alerta === 'POR_VENCER');
            const conRenovacion = alertasFiltradas.filter(a => a.tipo_alerta === 'CON_RENOVACION');
            
            // ========================================
            // RESUMEN EJECUTIVO
            // ========================================
            const cardResumen = document.createElement('div');
            cardResumen.className = 'card';
            cardResumen.style.marginBottom = '1rem';
            
            cardResumen.innerHTML = `
                <div class="card-body">
                    <h3 style="margin-bottom: 1rem;">📊 Resumen de Alertas (${alertasFiltradas.length} usuarios entre -30 y +30 días)</h3>
                    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem;">
                        <div style="background: #fee2e2; padding: 1rem; border-radius: 4px; border-left: 4px solid #dc2626;">
                            <div style="font-size: 0.9rem; color: #666;">🚨 Vencidos sin renovación</div>
                            <div style="font-size: 2rem; font-weight: bold; color: #dc2626;">${vencidosSinRenovacion.length}</div>
                        </div>
                        <div style="background: #fed7aa; padding: 1rem; border-radius: 4px; border-left: 4px solid #ea580c;">
                            <div style="font-size: 0.9rem; color: #666;">⚠️ Por vencer (≤7 días)</div>
                            <div style="font-size: 2rem; font-weight: bold; color: #ea580c;">${porVencerUrgente.length}</div>
                        </div>
                        <div style="background: #fef3c7; padding: 1rem; border-radius: 4px; border-left: 4px solid #f59e0b;">
                            <div style="font-size: 0.9rem; color: #666;">⏰ Por vencer (≤30 días)</div>
                            <div style="font-size: 2rem; font-weight: bold; color: #f59e0b;">${porVencer.length}</div>
                        </div>
                        <div style="background: #dbeafe; padding: 1rem; border-radius: 4px; border-left: 4px solid #3b82f6;">
                            <div style="font-size: 0.9rem; color: #666;">✅ Con renovación</div>
                            <div style="font-size: 2rem; font-weight: bold; color: #3b82f6;">${conRenovacion.length}</div>
                        </div>
                    </div>
                </div>
            `;
            alertContainer.appendChild(cardResumen);
            
            // ========================================
            // TABLA ÚNICA CON TODAS LAS ALERTAS FILTRADAS
            // ========================================
            const cardTabla = document.createElement('div');
            cardTabla.className = 'card';
            
            cardTabla.innerHTML = `
                <div class="card-header">
                    <h3>📋 Usuarios por Revisar (entre -30 días vencidos y +30 días vigentes)</h3>
                </div>
                <div class="card-body">
                    <div id="tablaTodasAlertas"></div>
                </div>
            `;
            alertContainer.appendChild(cardTabla);
            
            // ✅ Renderizar con alertas filtradas
            this.renderizarTablaCompleta('tablaTodasAlertas', alertasFiltradas);
            
        } catch (error) {
            console.error('❌ Error loading alertas:', error);
        }
    },
    
    renderizarTablaCompleta(containerId, alertas) {
        const container = document.getElementById(containerId);
        if (!container) return;
        
        const html = `
            <div class="table-wrapper" style="max-height: 600px; overflow-y: auto;">
                <table class="table" style="font-size: 0.9rem;" id="tablaDashboardAlertas">
                    <thead>
                        <tr>
                            <th data-sort="prioridad">Prioridad</th>
                            <th data-sort="nip">NIP</th>
                            <th data-sort="nombre">Nombre</th>
                            <th data-sort="total_cartas">Total Cartas</th>
                            <th data-sort="renovo">¿Renovó?</th>
                            <th data-sort="dias">Días Rest.</th>
                            <th data-sort="estado">Estado</th>
                            <th data-sort="bloqueo">Bloqueo</th>
                            <th data-sortable="false">Acciones</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${alertas.map(alerta => {
                            // Determinar color de fondo según prioridad
                            let bgColor = '';
                            let prioridadIcon = '';
                            let prioridadText = '';
                            
                            switch(alerta.tipo_alerta) {
                                case 'VENCIDO_SIN_RENOVACION':
                                    bgColor = '#fee2e2';
                                    prioridadIcon = '🚨';
                                    prioridadText = 'CRÍTICO';
                                    break;
                                case 'POR_VENCER_URGENTE':
                                    bgColor = '#fed7aa';
                                    prioridadIcon = '⚠️';
                                    prioridadText = 'URGENTE';
                                    break;
                                case 'POR_VENCER':
                                    bgColor = '#fef3c7';
                                    prioridadIcon = '⏰';
                                    prioridadText = 'IMPORTANTE';
                                    break;
                                case 'CON_RENOVACION':
                                    bgColor = '#dbeafe';
                                    prioridadIcon = '✅';
                                    prioridadText = 'RENOVADO';
                                    break;
                                default:
                                    bgColor = '#f3f4f6';
                                    prioridadIcon = 'ℹ️';
                                    prioridadText = 'INFO';
                            }
                            
                            return `
                                <tr style="background: ${bgColor};">
                                    <td>
                                        <span style="font-weight: bold;">${prioridadIcon} ${prioridadText}</span>
                                    </td>
                                    <td><strong>${alerta.nip || 'N/A'}</strong></td>
                                    <td>${alerta.nombres} ${alerta.apellidos}</td>
                                    <td style="text-align: center;">
                                        <button class="btn btn-sm btn-outline" 
                                                onclick="Dashboard.verHistorialCartas(${alerta.persona_id})"
                                                title="Ver historial completo">
                                            📄 ${alerta.total_cartas}
                                        </button>
                                    </td>
                                    <td style="text-align: center;">
                                        ${alerta.tiene_carta_vigente ? 
                                            '<span style="color: #10b981; font-size: 1.5rem;" title="Tiene otra carta vigente">✅</span>' : 
                                            '<span style="color: #ef4444; font-size: 1.5rem;" title="NO tiene carta vigente">❌</span>'}
                                    </td>
                                    <td>
                                        <span style="font-weight: bold; color: ${
                                            alerta.dias_restantes_acceso_actual <= 0 ? '#dc2626' :
                                            alerta.dias_restantes_acceso_actual <= 7 ? '#ea580c' : '#059669'
                                        };">
                                            ${alerta.dias_restantes_acceso_actual} días
                                        </span>
                                    </td>
                                    <td>
                                        ${alerta.dias_restantes_acceso_actual <= 0 ? '<span class="status-badge status-vencido">VENCIDO</span>' :
                                          alerta.dias_restantes_acceso_actual <= 7 ? '<span class="status-badge status-por-vencer">POR VENCER</span>' :
                                          '<span class="status-badge status-activo">VIGENTE</span>'}
                                    </td>
                                    <td>${getStatusBadge(alerta.estado_bloqueo)}</td>
                                    <td style="white-space: nowrap;">
                                        ${alerta.requiere_bloqueo && alerta.estado_bloqueo !== 'BLOQUEADO' ? `
                                            <button class="btn btn-sm btn-danger" 
                                                    onclick="Dashboard.bloquearDesdeAlerta(${alerta.acceso_id}, '${alerta.nombres} ${alerta.apellidos}')"
                                                    title="Bloquear ahora">
                                                🚫
                                            </button>
                                        ` : ''}
                                        
                                        <button class="btn btn-sm btn-outline" 
                                                onclick="Accesos.verDetalles(${alerta.acceso_id})"
                                                title="Ver detalles">
                                            👁️
                                        </button>
                                    </td>
                                </tr>
                            `;
                        }).join('')}
                    </tbody>
                </table>
            </div>
        `;
        
        container.innerHTML = html;
        
        // ✅ PREVENIR INICIALIZACIÓN MÚLTIPLE DEL ORDENAMIENTO
        // NO llamar a IntegratedTableSystem aquí si ya se inicializó globalmente
        console.log('✅ Tabla de alertas renderizada (sin reinicializar ordenamiento)');
    },
    
    async verHistorialCartas(personaId) {
        try {
            showLoading();
            const data = await API.get(`/dashboard/historial-cartas/${personaId}`);
            hideLoading();
            
            const persona = data.persona;
            const historial = data.historial;
            
            let htmlCartas = '';
            
            if (historial.length === 0) {
                htmlCartas = '<p style="text-align: center; color: #666;">No hay cartas registradas</p>';
            } else {
                htmlCartas = `
                    <table class="table" style="font-size: 0.9rem;">
                        <thead>
                            <tr>
                                <th>Carta</th>
                                <th>Fecha Generación</th>
                                <th>Vence</th>
                                <th>Días Rest.</th>
                                <th>Estado</th>
                                <th>Acciones</th>
                            </tr>
                        </thead>
                        <tbody>
                            ${historial.map(carta => {
                                let estadoBadge = '';
                                let bgColor = '';
                                
                                if (carta.estado === 'ACTIVA') {
                                    estadoBadge = '<span class="status-badge status-activo">✅ ACTIVA</span>';
                                    bgColor = '#d1fae5';
                                } else if (carta.estado === 'POR_VENCER') {
                                    estadoBadge = '<span class="status-badge status-por-vencer">⚠️ POR VENCER</span>';
                                    bgColor = '#fef3c7';
                                } else {
                                    estadoBadge = '<span class="status-badge status-vencido">❌ VENCIDA</span>';
                                    bgColor = '#fee2e2';
                                }
                                
                                return `
                                    <tr style="background: ${bgColor};">
                                        <td><strong>${carta.numero_carta}</strong></td>
                                        <td>${formatDate(carta.fecha_generacion)}</td>
                                        <td>${formatDate(carta.fecha_vencimiento)}</td>
                                        <td><strong>${carta.dias_restantes}</strong></td>
                                        <td>${estadoBadge}</td>
                                        <td>
                                            <button class="btn btn-sm btn-outline" 
                                                    onclick="Solicitudes.verCarta(${carta.solicitud_id}); hideModal();">
                                                👁️ Ver
                                            </button>
                                        </td>
                                    </tr>
                                `;
                            }).join('')}
                        </tbody>
                    </table>
                `;
            }
            
            showModal(`📄 Historial de Cartas - ${persona.nombres} ${persona.apellidos}`, `
                <div style="margin-bottom: 1.5rem; background: #f3f4f6; padding: 1rem; border-radius: 4px;">
                    <p style="margin-bottom: 0.5rem;"><strong>NIP:</strong> ${persona.nip}</p>
                    <p style="margin-bottom: 0.5rem;"><strong>DPI:</strong> ${persona.dpi}</p>
                    <p style="margin-bottom: 0.5rem;"><strong>Institución:</strong> ${persona.institucion || 'N/A'}</p>
                    <p style="margin-bottom: 0;">
                        <strong>Total Cartas:</strong> ${data.total_cartas} | 
                        <strong>Tiene Vigente:</strong> ${data.tiene_carta_vigente ? '✅ Sí' : '❌ No'}
                    </p>
                </div>
                
                <h4 style="margin-bottom: 1rem;">Historial Completo de Cartas:</h4>
                ${htmlCartas}
                
                <div style="margin-top: 1.5rem; text-align: center;">
                    ${!data.tiene_carta_vigente ? `
                        <div style="background: #fee2e2; padding: 1rem; border-radius: 4px; margin-bottom: 1rem;">
                            <strong>⚠️ ATENCIÓN:</strong> Esta persona NO tiene ninguna carta ACTIVA.
                        </div>
                    ` : ''}
                    <button class="btn btn-outline" onclick="hideModal()">Cerrar</button>
                </div>
            `, 'large');
            
        } catch (error) {
            hideLoading();
            showError('Error al obtener historial: ' + error.message);
        }
    },
    
    async bloquearDesdeAlerta(accesoId, nombrePersona) {
        if (!confirm(`🚫 ¿Bloquear acceso de ${nombrePersona}?\n\nEsta persona NO tiene carta vigente.`)) {
            return;
        }
        
        const motivo = prompt('Motivo del bloqueo:', 'Carta vencida sin renovación');
        if (!motivo) return;
        
        try {
            showLoading();
            await API.post('/accesos/bloquear', {
                acceso_vpn_id: accesoId,
                estado: 'BLOQUEADO',
                motivo: motivo
            });
            hideLoading();
            showSuccess('Acceso bloqueado exitosamente');
            await this.load(); // Recargar dashboard
        } catch (error) {
            hideLoading();
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