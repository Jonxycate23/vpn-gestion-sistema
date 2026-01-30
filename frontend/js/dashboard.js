// 📊 Dashboard Estilo Asperos Geek - VERSIÓN COMPLETA CORREGIDA
// 📍 Ubicación: frontend/js/dashboard.js
// ✅ CORREGIDO: Contadores correctos + Variable hoy definida correctamente

const DashboardAsperos = {
    _initialized: false,
    _cleanupExecuted: false,

    async load() {
        console.log('🚀 Cargando Dashboard Asperos Style...');

        if (!this._cleanupExecuted) {
            this.limpiarIndicadoresDuplicados();
            this._cleanupExecuted = true;
        }

        await this.loadStats();
        await this.loadAlertasInteligentes();
    },

    limpiarIndicadoresDuplicados() {
        const todasLasTablas = document.querySelectorAll('table');
        let totalLimpiados = 0;

        todasLasTablas.forEach(tabla => {
            const headers = tabla.querySelectorAll('thead th');
            headers.forEach(header => {
                const indicators = header.querySelectorAll('.sort-indicator');
                if (indicators.length > 1) {
                    indicators.forEach(ind => ind.remove());
                    totalLimpiados += indicators.length;
                }
            });
        });

        if (totalLimpiados > 0) {
            console.log(`✅ Limpiados ${totalLimpiados} indicadores duplicados`);
        }
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

            console.log('📊 Datos recibidos del backend:', data);

            // ✅ DEFINIR HOY AL INICIO
            const hoy = new Date();
            hoy.setHours(0, 0, 0, 0);

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

            // Filtrar: Solo usuarios entre -30 y +30 días para la TABLA
            const alertasFiltradas = data.alertas.filter(alerta => {
                const diasRestantes = alerta.dias_restantes_acceso_actual;
                return diasRestantes >= -30 && diasRestantes <= 30;
            });

            // ✅ OBTENER CARTAS POR AÑO DESDE EL BACKEND
            const cartas2026 = data.cartas_por_anio['2026'] || 0;
            const cartas2025 = data.cartas_por_anio['2025'] || 0;
            const cartas2024 = data.cartas_por_anio['2024'] || 0;
            const cartas2023 = data.cartas_por_anio['2023'] || 0;

            // ✅ OBTENER PENDIENTES DESDE EL BACKEND
            const pendientes = data.pendientes_sin_carta || 0;

            console.log(`📊 Cartas por año:`);
            console.log(`   2026: ${cartas2026} cartas`);
            console.log(`   2025: ${cartas2025} cartas`);
            console.log(`   2024: ${cartas2024} cartas`);
            console.log(`   2023: ${cartas2023} cartas`);
            console.log(`   Pendientes: ${pendientes} solicitudes sin carta`);

            // ✅ CONTADORES CORRECTOS Y SEPARADOS

            // 1. ACTIVOS: Usuarios VPN desbloqueados con días > 0
            const todosUsuariosActivos = data.alertas.filter(a =>
                a.estado_bloqueo !== 'BLOQUEADO' && a.dias_restantes_acceso_actual > 0
            ).length;

            // 2. VENCIDOS HOY: Solo los que vencen exactamente hoy
            const todosUsuariosVencidosHoy = data.alertas.filter(a => {
                const fechaVencimiento = new Date(a.fecha_vencimiento_acceso_actual);
                fechaVencimiento.setHours(0, 0, 0, 0);

                return fechaVencimiento.getTime() === hoy.getTime() &&
                    a.estado_bloqueo !== 'BLOQUEADO';
            }).length;

            // 3. BLOQUEADOS: Solo usuarios VPN con estado BLOQUEADO
            const todosUsuariosBloqueados = data.alertas.filter(a =>
                a.estado_bloqueo === 'BLOQUEADO'
            ).length;

            // 4. CANCELADOS: Solicitudes con estado CANCELADA (viene del backend)
            const todosUsuariosCancelados = data.total_cancelados || 0;

            console.log(`📊 CONTADORES CORREGIDOS:`);
            console.log(`   Activos (VPN desbloqueados con días > 0): ${todosUsuariosActivos}`);
            console.log(`   Vencidos HOY: ${todosUsuariosVencidosHoy}`);
            console.log(`   Bloqueados (VPN): ${todosUsuariosBloqueados}`);
            console.log(`   Cancelados (Solicitudes): ${todosUsuariosCancelados}`);

            // ========================================
            // 🎨 DISEÑO ESTILO ASPEROS GEEK
            // ========================================
            const dashboardHTML = `
                <div class="dashboard-asperos">
                    <!-- Header Principal -->
                    <div class="dashboard-header-main">
                        <h1>📊 DASHBOARD</h1>
                        <p>SISTEMA | ${new Date().getFullYear()}</p>
                    </div>

                    <!-- Grid de Cards de Cartas -->
                    <div class="cartas-grid">
                        <!-- CARTAS 2026 -->
                        <div class="carta-card cartas-2026">
                            <div class="carta-label">CARTAS 2026</div>
                            <div class="progress-circle">
                                <svg width="120" height="120">
                                    <circle class="circle-bg" cx="60" cy="60" r="45"></circle>
                                </svg>
                                <div class="progress-value">${cartas2026}</div>
                            </div>
                        </div>

                        <!-- CARTAS 2025 -->
                        <div class="carta-card cartas-2025">
                            <div class="carta-label">CARTAS 2025</div>
                            <div class="progress-circle">
                                <svg width="120" height="120">
                                    <circle class="circle-bg" cx="60" cy="60" r="45"></circle>
                                </svg>
                                <div class="progress-value">${cartas2025}</div>
                            </div>
                        </div>

                        <!-- CARTAS 2024 -->
                        <div class="carta-card cartas-2024">
                            <div class="carta-label">CARTAS 2024</div>
                            <div class="progress-circle">
                                <svg width="120" height="120">
                                    <circle class="circle-bg" cx="60" cy="60" r="45"></circle>
                                </svg>
                                <div class="progress-value">${cartas2024}</div>
                            </div>
                        </div>

                        <!-- PENDIENTES POR CREAR -->
                        <div class="carta-card pendientes">
                            <div class="carta-label">PENDIENTES POR CREAR</div>
                            <div class="progress-circle">
                                <svg width="120" height="120">
                                    <circle class="circle-bg" cx="60" cy="60" r="45"></circle>
                                </svg>
                                <div class="progress-value">${pendientes}</div>
                            </div>
                        </div>
                    </div>

                    <!-- Grid de Estados de Usuarios -->
                    <div class="estados-grid">
                        <!-- USUARIOS ACTIVOS -->
                        <div class="estado-card activos">
                            <div class="estado-label">USUARIOS ACTIVOS</div>
                            <div class="estado-icon">✅</div>
                            <div class="estado-value">${todosUsuariosActivos}</div>
                        </div>

                        <!-- USUARIOS VENCIDOS HOY -->
                        <div class="estado-card vencidos">
                            <div class="estado-label">VENCIDOS HOY</div>
                            <div class="estado-icon">🔴</div>
                            <div class="estado-value">${todosUsuariosVencidosHoy}</div>
                        </div>

                        <!-- USUARIOS BLOQUEADOS -->
                        <div class="estado-card bloqueados">
                            <div class="estado-label">USUARIOS BLOQUEADOS</div>
                            <div class="estado-icon">🚫</div>
                            <div class="estado-value">${todosUsuariosBloqueados}</div>
                        </div>

                        <!-- CANCELADOS -->
                        <div class="estado-card cancelados">
                            <div class="estado-label">CANCELADOS</div>
                            <div class="estado-icon">⚠️</div>
                            <div class="estado-value">${todosUsuariosCancelados}</div>
                        </div>
                    </div>

                    <!-- Tabla de Datos -->
                    <div class="tabla-section">
                        <div class="tabla-header">
                            <h3>📋 Usuarios por Revisar (${alertasFiltradas.length})</h3>
                            <div class="tabla-actions">
                                <div class="search-box">
                                    <input type="text" id="searchDashboard" 
                                           placeholder="Buscar por NIP o nombre...">
                                </div>
                                <button class="btn-refresh-table" onclick="DashboardAsperos.load()">
                                    🔄 Actualizar
                                </button>
                            </div>
                        </div>
                        <div id="tablaTodasAlertas"></div>
                    </div>
                </div>
            `;

            alertContainer.innerHTML = dashboardHTML;

            // Renderizar tabla
            this.renderizarTablaCompleta('tablaTodasAlertas', alertasFiltradas);

            // Implementar búsqueda
            this.implementarBusqueda(alertasFiltradas);

        } catch (error) {
            console.error('❌ Error loading alertas:', error);
        }
    },

    implementarBusqueda(alertasOriginales) {
        const searchInput = document.getElementById('searchDashboard');
        if (!searchInput) return;

        searchInput.addEventListener('input', (e) => {
            const term = e.target.value.toLowerCase();

            if (!term) {
                this.renderizarTablaCompleta('tablaTodasAlertas', alertasOriginales);
                return;
            }

            const alertasFiltradas = alertasOriginales.filter(alerta => {
                const nip = (alerta.nip || '').toLowerCase();
                const nombre = `${alerta.nombres} ${alerta.apellidos}`.toLowerCase();
                return nip.includes(term) || nombre.includes(term);
            });

            this.renderizarTablaCompleta('tablaTodasAlertas', alertasFiltradas);
        });
    },

    renderizarTablaCompleta(containerId, alertas) {
        const container = document.getElementById(containerId);
        if (!container) return;

        if (alertas.length === 0) {
            container.innerHTML = `
                <div style="text-align: center; padding: 3rem; color: #6b7280;">
                    <div style="font-size: 4rem; margin-bottom: 1rem;">🔍</div>
                    <h3 style="color: #1f2937;">No se encontraron resultados</h3>
                    <p>Intenta con otro filtro o búsqueda</p>
                </div>
            `;
            return;
        }

        const html = `
            <div class="tabla-wrapper">
                <table class="tabla-datos">
                    <thead>
                        <tr>
                            <th>NIP</th>
                            <th>Nombre Completo</th>
                            <th>Institución</th>
                            <th style="text-align: center;">Cartas</th>
                            <th style="text-align: center;">¿Renovó?</th>
                            <th style="text-align: center;">Días Restantes</th>
                            <th>Estado</th>
                            <th>Bloqueo</th>
                            <th style="text-align: center;">Acciones</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${alertas.map(alerta => {
            let bgColor = '';
            let rowStyle = '';

            if (alerta.tipo_alerta === 'VENCIDO_SIN_RENOVACION') {
                bgColor = '#fee2e2';
                rowStyle = 'background-color: #fee2e2 !important;';
            } else if (alerta.tiene_carta_vigente && alerta.dias_restantes_acceso_actual <= 30) {
                bgColor = '#dbeafe';
                rowStyle = 'background-color: #dbeafe !important;';
            } else if (alerta.dias_restantes_acceso_actual <= 30 && !alerta.tiene_carta_vigente) {
                bgColor = '#fef3c7';
                rowStyle = 'background-color: #fef3c7 !important;';
            }

            return `
                                <tr style="${rowStyle}">
                                    <td><strong>${alerta.nip || 'N/A'}</strong></td>
                                    <td>${alerta.nombres} ${alerta.apellidos}</td>
                                    <td>${alerta.institucion || 'Sin institución'}</td>
                                    <td style="text-align: center;">
                                        <button class="btn-action primary" 
                                                onclick="DashboardAsperos.verHistorialCartas(${alerta.persona_id})"
                                                title="Ver historial">
                                            📄 ${alerta.total_cartas}
                                        </button>
                                    </td>
                                    <td style="text-align: center;">
                                        ${alerta.tiene_carta_vigente ?
                    '<span style="font-size: 1.5rem; color: #10b981;">✅</span>' :
                    '<span style="font-size: 1.5rem; color: #ef4444;">❌</span>'}
                                    </td>
                                    <td style="text-align: center;">
                                        <strong style="font-size: 1.25rem; color: ${alerta.dias_restantes_acceso_actual <= 0 ? '#ef4444' :
                    alerta.dias_restantes_acceso_actual <= 7 ? '#f59e0b' : '#10b981'
                };">
                                            ${alerta.dias_restantes_acceso_actual}
                                        </strong>
                                    </td>
                                    <td>
                                        ${alerta.dias_restantes_acceso_actual <= 0 ?
                    '<span class="badge vencido">VENCIDO</span>' :
                    alerta.dias_restantes_acceso_actual <= 7 ?
                        '<span class="badge pendiente">POR VENCER</span>' :
                        '<span class="badge activo">VIGENTE</span>'}
                                    </td>
                                    <td>
                                        ${alerta.estado_bloqueo === 'BLOQUEADO' ?
                    '<span class="badge bloqueado">BLOQUEADO</span>' :
                    '<span class="badge activo">ACTIVO</span>'}
                                    </td>
                                    <td style="text-align: center;">
                                        ${alerta.requiere_bloqueo && alerta.estado_bloqueo !== 'BLOQUEADO' ? `
                                            <button class="btn-action danger" 
                                                    onclick="DashboardAsperos.bloquearDesdeAlerta(${alerta.acceso_id}, '${alerta.nombres} ${alerta.apellidos}')"
                                                    title="Bloquear">
                                                🚫
                                            </button>
                                        ` : ''}
                                        <button class="btn-action primary" 
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
        console.log(`✅ Tabla renderizada con ${alertas.length} registros`);
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
                                                    onclick="Solicitudes.verCarta(${carta.solicitud_id})">
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
            await this.load();
        } catch (error) {
            hideLoading();
            showError('Error al bloquear: ' + error.message);
        }
    }
};

// Compatibilidad con el sistema actual
window.Dashboard = DashboardAsperos;

// Event Listeners
document.addEventListener('DOMContentLoaded', () => {
    const refreshBtn = document.getElementById('refreshDashboard');
    if (refreshBtn) {
        refreshBtn.addEventListener('click', () => {
            DashboardAsperos.load();
        });
    }
});