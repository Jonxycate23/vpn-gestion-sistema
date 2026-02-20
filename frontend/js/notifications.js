/**
 * Sistema de Notificaciones de Vencimiento VPN
 * Campana con badge en el navbar — refresca cada 5 min
 */
const NotifVPN = {
    _datos: [],       // pendientes (cuentan en badge)
    _bloqueados: [],  // ya bloqueados hoy (sección informativa)
    _timer: null,
    _abierto: false,

    // ── Punto de entrada (llamar tras login exitoso) ─────────────────────────
    init() {
        this._inyectarCampana();
        this.refrescar();
        clearInterval(this._timer);
        this._timer = setInterval(() => this.refrescar(), 5 * 60 * 1000);
    },

    // ── Destruir al hacer logout ─────────────────────────────────────────────
    destroy() {
        clearInterval(this._timer);
        const btn = document.getElementById('notifBellBtn');
        if (btn) btn.remove();
        const panel = document.getElementById('notifPanel');
        if (panel) panel.remove();
    },

    // ── Inyectar botón campana en .nav-user, antes de btnUserMenu ───────────
    _inyectarCampana() {
        if (document.getElementById('notifBellBtn')) return;

        const navUser = document.querySelector('.nav-user');
        if (!navUser) return;

        const btnMenu = document.getElementById('btnUserMenu');

        const bell = document.createElement('div');
        bell.id = 'notifBellBtn';
        bell.title = 'Notificaciones de Vencimiento';
        bell.style.cssText = `
            position:relative; cursor:pointer; display:flex; align-items:center;
            justify-content:center; width:38px; height:38px; border-radius:50%;
            background:rgba(99,102,241,0.12); transition:background 0.2s;
            user-select:none;
        `;
        bell.innerHTML = `
            <svg id="notifBellIcon" width="22" height="22" viewBox="0 0 24 24"
                 fill="none" stroke="#6366f1" stroke-width="2"
                 stroke-linecap="round" stroke-linejoin="round">
                <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/>
                <path d="M13.73 21a2 2 0 0 1-3.46 0"/>
            </svg>
            <span id="notifBadge" style="
                display:none; position:absolute; top:-4px; right:-4px;
                background:#ef4444; color:white; border-radius:50%;
                font-size:0.65rem; font-weight:700; min-width:18px; height:18px;
                padding:0 4px; line-height:18px; text-align:center;
                box-shadow:0 0 0 2px white; text-transform:none;
            ">0</span>
        `;
        bell.addEventListener('mouseenter', () => { bell.style.background = 'rgba(99,102,241,0.22)'; });
        bell.addEventListener('mouseleave', () => { bell.style.background = 'rgba(99,102,241,0.12)'; });
        bell.addEventListener('click', (e) => { e.stopPropagation(); this.togglePanel(); });

        navUser.insertBefore(bell, btnMenu);

        document.addEventListener('click', (e) => {
            if (this._abierto && !bell.contains(e.target)) {
                this._cerrarPanel();
            }
        });
    },

    // ── Obtener datos del backend ────────────────────────────────────────────
    async refrescar() {
        try {
            const data = await API.get('/dashboard/notificaciones');
            this._datos = data.notificaciones || [];
            this._bloqueados = data.bloqueados_hoy || [];
            this._actualizarBadge(data.total || 0);
            if (this._abierto) this._renderPanel();
        } catch (e) {
            console.warn('NotifVPN: error al cargar notificaciones', e.message);
        }
    },

    // ── Badge ────────────────────────────────────────────────────────────────
    _actualizarBadge(total) {
        const badge = document.getElementById('notifBadge');
        const icon = document.getElementById('notifBellIcon');
        if (!badge) return;

        if (total === 0) {
            badge.style.display = 'none';
            if (icon) icon.setAttribute('stroke', '#6366f1');
        } else {
            badge.style.display = 'block';
            badge.textContent = total > 99 ? '99+' : String(total);
            if (icon) icon.setAttribute('stroke', '#ef4444');
        }
    },

    // ── Toggle panel ─────────────────────────────────────────────────────────
    togglePanel() {
        this._abierto ? this._cerrarPanel() : this._abrirPanel();
    },

    _abrirPanel() {
        this._abierto = true;
        this._renderPanel();
    },

    _cerrarPanel() {
        this._abierto = false;
        const p = document.getElementById('notifPanel');
        if (p) p.remove();
    },

    // ── Renderizar el dropdown panel ─────────────────────────────────────────
    _renderPanel() {
        const viejo = document.getElementById('notifPanel');
        if (viejo) viejo.remove();

        const bell = document.getElementById('notifBellBtn');
        if (!bell) return;

        const rect = bell.getBoundingClientRect();
        const panel = document.createElement('div');
        panel.id = 'notifPanel';
        panel.style.cssText = `
            position:fixed; top:${rect.bottom + 8}px; right:${window.innerWidth - rect.right}px;
            width:390px; max-height:540px; overflow-y:auto;
            background:white; border-radius:12px;
            box-shadow:0 8px 32px rgba(0,0,0,0.18), 0 0 0 1px rgba(0,0,0,0.06);
            z-index:9999; font-family:inherit;
        `;

        const pendientes = this._datos;
        const bloqueados = this._bloqueados;
        const total = pendientes.length + bloqueados.length;

        let html = `
            <div style="padding:1rem 1.2rem 0.6rem;border-bottom:1px solid #f3f4f6;
                        display:flex;justify-content:space-between;align-items:center;">
                <span style="font-weight:700;font-size:0.95rem;color:#111827;">
                    🔔 Notificaciones
                    <span style="font-size:0.74rem;font-weight:400;color:#6b7280;">
                        (${pendientes.length} pendiente${pendientes.length !== 1 ? 's' : ''})
                    </span>
                </span>
                <button onclick="event.stopPropagation(); NotifVPN.refrescar()"
                        style="border:none;background:none;cursor:pointer;color:#6366f1;
                               font-size:0.78rem;font-weight:600;padding:0;">
                    ↻ Actualizar
                </button>
            </div>`;

        if (total === 0) {
            html += `<div style="padding:2rem;text-align:center;color:#9ca3af;">
                        <div style="font-size:2rem;">✅</div>
                        <p>Sin vencimientos hoy</p>
                     </div>`;
        } else {
            // ── PENDIENTES DE BLOQUEAR
            if (pendientes.length > 0) {
                html += `<div style="padding:0.4rem 1.2rem;background:#fef2f2;
                                     font-size:0.72rem;font-weight:700;color:#991b1b;
                                     letter-spacing:0.05em;">
                            🔴 PENDIENTES DE BLOQUEAR (${pendientes.length})
                         </div>`;
                pendientes.forEach(n => { html += this._tarjeta(n, '#fff5f5', false); });
            }

            // ── YA BLOQUEADOS HOY
            if (bloqueados.length > 0) {
                html += `<div style="padding:0.4rem 1.2rem;background:#f0fdf4;
                                     font-size:0.72rem;font-weight:700;color:#166534;
                                     letter-spacing:0.05em;border-top:2px solid #e5e7eb;">
                            ✅ YA BLOQUEADOS HOY (${bloqueados.length})
                         </div>`;
                bloqueados.forEach(n => { html += this._tarjeta(n, '#f6fef9', true); });
            }
        }

        html += `<div style="padding:0.6rem 1.2rem;border-top:1px solid #f3f4f6;text-align:right;">
                    <button onclick="NotifVPN._cerrarPanel()"
                            style="border:none;background:none;cursor:pointer;
                                   color:#6b7280;font-size:0.8rem;">Cerrar</button>
                 </div>`;

        panel.innerHTML = html;
        panel.addEventListener('click', (e) => e.stopPropagation());
        document.body.appendChild(panel);
    },

    // ── Tarjeta individual ───────────────────────────────────────────────────
    _tarjeta(n, bg, yaBloqueado = false) {
        const gracia = n.dias_gracia > 0
            ? ` <span style="color:#7c3aed;font-size:0.74rem;">(+${n.dias_gracia}d gracia)</span>` : '';

        const justif = n.justificacion
            ? `<div style="font-size:0.73rem;color:#6b7280;margin-top:0.2rem;font-style:italic;
                           white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:280px;"
                    title="${n.justificacion.replace(/"/g, '&quot;')}">💬 ${n.justificacion}</div>` : '';

        const cartaBadge = n.tiene_carta_vigente
            ? `<div style="margin-top:0.3rem;">
                   <span style="display:inline-flex;align-items:center;gap:0.3rem;
                                background:#dbeafe;color:#1e40af;font-size:0.71rem;font-weight:700;
                                padding:0.15rem 0.5rem;border-radius:20px;">
                       ✅ CARTA VIGENTE: ${n.carta_vigente_numero}
                   </span>
               </div>`
            : `<div style="margin-top:0.3rem;">
                   <span style="display:inline-flex;align-items:center;gap:0.3rem;
                                background:#fee2e2;color:#991b1b;font-size:0.71rem;font-weight:700;
                                padding:0.15rem 0.5rem;border-radius:20px;">
                       🔴 SIN CARTA VIGENTE
                   </span>
               </div>`;

        const accionHtml = yaBloqueado
            ? `<div style="flex-shrink:0;text-align:center;min-width:82px;">
                   <span style="display:block;background:#d1fae5;color:#166534;font-size:0.71rem;
                                font-weight:700;border-radius:6px;padding:0.22rem 0.45rem;">
                       🔒 Bloqueado
                   </span>
                   <span style="display:block;font-size:0.67rem;color:#6b7280;margin-top:0.2rem;">
                       por ${n.bloqueado_por || '—'}
                   </span>
               </div>`
            : `<button onclick="NotifVPN.bloquearDesdeNotif(${n.acceso_id}, '${n.nombre.replace(/'/g, "&#39;")}')"
                       style="flex-shrink:0;border:none;border-radius:6px;background:#ef4444;color:white;
                              font-size:0.75rem;font-weight:600;padding:0.3rem 0.6rem;cursor:pointer;
                              white-space:nowrap;text-transform:none !important;">🚫 Bloquear</button>`;

        return `
        <div style="padding:0.7rem 1.2rem;border-bottom:1px solid #f3f4f6;
                    background:${bg};opacity:${yaBloqueado ? '0.78' : '1'};">
            <div style="display:flex;justify-content:space-between;align-items:flex-start;gap:0.5rem;">
                <div style="flex:1;min-width:0;">
                    <div style="font-weight:700;font-size:0.85rem;color:#111827;
                                white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">
                        ${n.nombre}
                    </div>
                    <div style="font-size:0.78rem;color:#4b5563;margin-top:0.1rem;">
                        NIP: <strong>${n.nip}</strong> &nbsp;|&nbsp;
                        Carta: <strong>${n.numero_carta}</strong>
                    </div>
                    <div style="font-size:0.78rem;margin-top:0.2rem;">
                        📅 ${formatDate(n.fecha_fin_con_gracia)}${gracia}
                        &nbsp;— <span style="color:#dc2626;font-weight:700;">Vence HOY</span>
                    </div>
                    ${cartaBadge}${justif}
                </div>
                ${accionHtml}
            </div>
        </div>`;
    },

    // ── Bloquear desde notificación ──────────────────────────────────────────
    async bloquearDesdeNotif(accesoId, nombre) {
        this._cerrarPanel();

        const motivo = window.prompt(
            `Motivo del bloqueo para:\n${nombre}`,
            'Acceso vencido — sin renovación'
        );
        if (!motivo || !motivo.trim()) return;

        const confirmado = await CustomConfirm.show({
            title: '🚫 Bloquear Acceso',
            message: `¿Bloquear a ${nombre}?\n\nMotivo: ${motivo}`,
            type: 'danger',
            confirmText: 'Sí, bloquear',
            cancelText: 'No'
        });
        if (!confirmado) return;

        try {
            showLoading();
            await API.post('/accesos/bloquear', {
                acceso_vpn_id: accesoId,
                estado: 'BLOQUEADO',
                motivo: motivo.trim()
            });
            hideLoading();
            showSuccess('✅ Acceso bloqueado');
            // Actualizar badge y reabrir panel con las secciones actualizadas
            await this.refrescar();
            this._abrirPanel();
            // Refrescar tabla del dashboard si está visible
            if (typeof Dashboard !== 'undefined' && typeof Dashboard.cargarAlertasInteligentes === 'function') {
                Dashboard.cargarAlertasInteligentes();
            } else if (typeof Dashboard !== 'undefined' && typeof Dashboard.cargar === 'function') {
                Dashboard.cargar();
            }
        } catch (err) {
            hideLoading();
            showError('Error al bloquear: ' + err.message);
        }
    }
};
