// Módulo Control de Cartas
const ControlCartas = {
    filtros: { anio: '', numero: '', nombre: '', nip: '' },
    pagina: 1,
    porPagina: 50,
    total: 0,
    aniosDisponibles: [],
    _estructuraRenderizada: false,

    async load() {
        this._estructuraRenderizada = false; // forzar re-render al navegar
        this.pagina = 1;
        this.filtros = { anio: '', numero: '', nombre: '', nip: '' };
        await this.cargar();
    },

    async cargar() {
        try {
            showLoading();

            const params = new URLSearchParams();
            params.set('skip', (this.pagina - 1) * this.porPagina);
            params.set('limit', this.porPagina);
            if (this.filtros.anio) params.set('anio', this.filtros.anio);
            if (this.filtros.numero) params.set('numero', this.filtros.numero);
            if (this.filtros.nombre) params.set('nombre', this.filtros.nombre);
            if (this.filtros.nip) params.set('nip', this.filtros.nip);

            const data = await API.get(`/cartas/control?${params}`);
            hideLoading();

            if (!data || !data.success) {
                showError('Error al cargar cartas');
                return;
            }

            this.total = data.total;
            this.aniosDisponibles = data.anios_disponibles || [];

            // Primera carga: dibujar estructura completa
            if (!this._estructuraRenderizada) {
                this.renderEstructura();
                this._estructuraRenderizada = true;
            }

            // Siempre actualizar solo los resultados (sin tocar inputs)
            this.renderResultados(data.cartas);

        } catch (err) {
            hideLoading();
            showError('Error: ' + err.message);
        }
    },

    // ─── Dibuja el esqueleto UNA sola vez ────────────────────────────────────
    renderEstructura() {
        const contenedor = document.getElementById('controlCartasView');
        if (!contenedor) return;

        const opcionesAnio = this.aniosDisponibles.map(a =>
            `<option value="${a}">${a}</option>`
        ).join('');

        contenedor.innerHTML = `
            <div class="view-header" style="display:flex;justify-content:space-between;align-items:center;margin-bottom:1.5rem;">
                <h1>📋 Control de Cartas</h1>
                <span id="ccTotalBadge"
                      style="background:#dbeafe;color:#1e40af;padding:0.4rem 1rem;border-radius:20px;font-size:0.9rem;font-weight:600;">
                    📄 0 cartas
                </span>
            </div>

            <!-- Filtros (se dibujan una vez, nunca se destruyen) -->
            <div class="card" style="margin-bottom:1rem;background:linear-gradient(135deg,#f0f9ff 0%,#e0f2fe 100%);border:1px solid #bae6fd;">
                <div style="padding:0.75rem 1rem;border-bottom:1px solid #bae6fd;">
                    <span style="font-weight:700;color:#0369a1;font-size:0.9rem;">🔍 Filtros de búsqueda</span>
                </div>
                <div style="display:flex;flex-wrap:wrap;gap:0.75rem;padding:1rem;align-items:flex-end;">

                    <div style="flex:0 0 auto;">
                        <label style="font-size:0.78rem;font-weight:700;display:block;margin-bottom:0.3rem;color:#0369a1;text-transform:uppercase;letter-spacing:0.05em;">📅 Año</label>
                        <select id="filtroAnio"
                                style="padding:0.5rem 0.75rem;border:2px solid #7dd3fc;border-radius:8px;background:white;color:#0c4a6e;font-weight:600;min-width:95px;outline:none;"
                                onchange="ControlCartas.aplicarFiltros()">
                            <option value="">Todos</option>
                            ${opcionesAnio}
                        </select>
                    </div>

                    <div style="flex:0 0 auto;">
                        <label style="font-size:0.78rem;font-weight:700;display:block;margin-bottom:0.3rem;color:#7c3aed;text-transform:uppercase;letter-spacing:0.05em;">🔢 Nº Carta</label>
                        <input type="number" id="filtroNumero" placeholder="Ej: 15"
                               style="padding:0.5rem 0.75rem;border:2px solid #c4b5fd;border-radius:8px;width:85px;font-weight:600;outline:none;"
                               oninput="ControlCartas.debounce()">
                    </div>

                    <div style="flex:0 0 auto;">
                        <label style="font-size:0.78rem;font-weight:700;display:block;margin-bottom:0.3rem;color:#065f46;text-transform:uppercase;letter-spacing:0.05em;">👤 Nombre</label>
                        <input type="text" id="filtroNombre" placeholder="Buscar nombre..."
                               style="padding:0.5rem 0.75rem;border:2px solid #6ee7b7;border-radius:8px;width:180px;outline:none;"
                               oninput="ControlCartas.debounce()">
                    </div>

                    <div style="flex:0 0 auto;">
                        <label style="font-size:0.78rem;font-weight:700;display:block;margin-bottom:0.3rem;color:#92400e;text-transform:uppercase;letter-spacing:0.05em;">🪪 NIP</label>
                        <input type="text" id="filtroNip" placeholder="NIP..."
                               style="padding:0.5rem 0.75rem;border:2px solid #fcd34d;border-radius:8px;width:110px;outline:none;"
                               oninput="ControlCartas.debounce()">
                    </div>

                    <div style="flex:0 0 auto;margin-top:1.4rem;">
                        <button onclick="ControlCartas.limpiarFiltros()"
                                style="padding:0.5rem 1.1rem;border:2px solid #f87171;border-radius:8px;background:white;color:#dc2626;font-weight:600;cursor:pointer;transition:all 0.2s;"
                                onmouseover="this.style.background='#fee2e2'" onmouseout="this.style.background='white'">
                            🗑️ Limpiar
                        </button>
                    </div>
                </div>
            </div>

            <!-- Tabla con scroll -->
            <div class="card">
                <div style="overflow-x:auto;overflow-y:auto;max-height:60vh;">
                    <table class="table" style="min-width:650px;">
                        <thead style="position:sticky;top:0;z-index:1;background:#f8fafc;">
                            <tr>
                                <th>NIP</th>
                                <th>Nombre Completo</th>
                                <th>Estado Acceso</th>
                                <th style="text-align:center;">Nº Carta</th>
                                <th>Fecha Generación</th>
                                <th>Acciones</th>
                            </tr>
                        </thead>
                        <tbody id="ccTbody">
                            <tr><td colspan="6" style="text-align:center;padding:2rem;color:#9ca3af;">Cargando...</td></tr>
                        </tbody>
                    </table>
                </div>
                <div id="ccFooter"
                     style="display:flex;justify-content:space-between;align-items:center;padding:0.75rem 1.5rem;border-top:1px solid #e5e7eb;flex-wrap:wrap;gap:0.5rem;background:#f9fafb;">
                </div>
            </div>
        `;
    },

    // ─── Actualiza SOLO tbody + footer (los inputs no se tocan) ──────────────
    renderResultados(cartas) {
        const totalPaginas = Math.ceil(this.total / this.porPagina);
        const inicio = (this.pagina - 1) * this.porPagina + 1;
        const fin = Math.min(this.pagina * this.porPagina, this.total);

        // Badge
        const badge = document.getElementById('ccTotalBadge');
        if (badge) badge.textContent = `📄 ${this.total} carta${this.total !== 1 ? 's' : ''}`;

        // Estado badge helper
        const estadoBadge = (estado) => {
            const map = {
                'ACTIVO': { cls: 'status-activo', label: '✅ ACTIVO' },
                'POR_VENCER': { cls: 'status-por-vencer', label: '⚠️ POR VENCER' },
                'VENCIDO': { cls: 'status-vencido', label: '❌ VENCIDO' },
                'BLOQUEADO': { cls: 'status-bloqueado', label: '🚫 BLOQUEADO' },
                'SIN_ACCESO': { cls: 'status-vencido', label: '— SIN ACCESO' },
            };
            const s = map[estado] || { cls: '', label: estado };
            return `<span class="status-badge ${s.cls}">${s.label}</span>`;
        };

        // Filas
        const filas = cartas.length === 0
            ? `<tr><td colspan="6" style="text-align:center;padding:2rem;color:#9ca3af;">
                  <div style="font-size:2rem;">📋</div>
                  <p>No se encontraron cartas con los filtros aplicados</p>
               </td></tr>`
            : cartas.map(c => `
                <tr>
                    <td><strong>${c.nip}</strong></td>
                    <td>${c.nombre}</td>
                    <td>${estadoBadge(c.estado_acceso)}</td>
                    <td style="text-align:center;font-weight:700;">
                        <span style="background:#dbeafe;color:#1e40af;padding:0.2rem 0.7rem;border-radius:12px;">
                            ${c.numero_display}
                        </span>
                    </td>
                    <td style="font-size:0.85rem;color:#6b7280;">${c.fecha_generacion ? formatDate(c.fecha_generacion) : '—'}</td>
                    <td>
                        <div style="display:flex;gap:0.4rem;align-items:center;">
                            <button class="btn btn-sm btn-primary"
                                    onclick="Solicitudes.verCarta(${c.solicitud_id})"
                                    title="Ver carta PDF">
                                👁️ Ver Carta
                            </button>
                            <button class="btn btn-sm"
                                    style="background:#6366f1;color:white;"
                                    title="Ver justificación / prórroga"
                                    onclick='ControlCartas.verJustificacion(${JSON.stringify({ nombre: c.nombre, estado: c.estado_acceso, justificacion: c.justificacion, fecha_fin: c.fecha_fin_con_gracia, dias_gracia: c.dias_gracia, dias_restantes: c.dias_restantes }).replace(/'/g, "&apos;")})'>
                                💬
                            </button>
                        </div>
                    </td>
                </tr>`).join('');

        const tbody = document.getElementById('ccTbody');
        if (tbody) tbody.innerHTML = filas;

        const footer = document.getElementById('ccFooter');
        if (footer) {
            footer.innerHTML = `
                <span style="color:#6b7280;font-size:0.85rem;">
                    ${this.total > 0
                    ? `Mostrando <strong>${inicio}–${fin}</strong> de <strong>${this.total}</strong>`
                    : 'Sin resultados'}
                </span>
                <div style="display:flex;gap:0.4rem;flex-wrap:wrap;">${this.buildPaginacion(totalPaginas)}</div>
            `;
        }
    },

    // ─── Paginación ───────────────────────────────────────────────────────────
    buildPaginacion(totalPaginas) {
        if (totalPaginas <= 1) return '';
        const current = this.pagina;
        let btns = [];

        btns.push(`<button class="btn btn-sm btn-outline" ${current === 1 ? 'disabled' : ''}
                   onclick="ControlCartas.irPagina(${current - 1})">‹ Ant</button>`);

        let start = Math.max(1, current - 3);
        let end = Math.min(totalPaginas, current + 3);

        if (start > 1) btns.push(`<button class="btn btn-sm btn-outline" onclick="ControlCartas.irPagina(1)">1</button>`);
        if (start > 2) btns.push(`<span style="padding:0 0.3rem;color:#9ca3af;">…</span>`);

        for (let p = start; p <= end; p++) {
            const cls = p === current ? 'btn-primary' : 'btn-outline';
            btns.push(`<button class="btn btn-sm ${cls}" onclick="ControlCartas.irPagina(${p})">${p}</button>`);
        }

        if (end < totalPaginas - 1) btns.push(`<span style="padding:0 0.3rem;color:#9ca3af;">…</span>`);
        if (end < totalPaginas) btns.push(`<button class="btn btn-sm btn-outline" onclick="ControlCartas.irPagina(${totalPaginas})">${totalPaginas}</button>`);

        btns.push(`<button class="btn btn-sm btn-outline" ${current === totalPaginas ? 'disabled' : ''}
                   onclick="ControlCartas.irPagina(${current + 1})">Sig ›</button>`);

        return btns.join('');
    },

    async irPagina(p) {
        const totalPaginas = Math.ceil(this.total / this.porPagina);
        if (p < 1 || p > totalPaginas) return;
        this.pagina = p;
        await this.cargar();
    },

    // ─── Debounce (600ms) — solo lee valores, no re-dibuja inputs ────────────
    _debounceTimer: null,
    debounce() {
        clearTimeout(this._debounceTimer);
        this._debounceTimer = setTimeout(() => this.aplicarFiltros(), 600);
    },

    aplicarFiltros() {
        this.filtros.anio = document.getElementById('filtroAnio')?.value || '';
        this.filtros.numero = document.getElementById('filtroNumero')?.value || '';
        this.filtros.nombre = document.getElementById('filtroNombre')?.value || '';
        this.filtros.nip = document.getElementById('filtroNip')?.value || '';
        this.pagina = 1;
        this.cargar();
    },

    limpiarFiltros() {
        this.filtros = { anio: '', numero: '', nombre: '', nip: '' };
        // Limpiar inputs manualmente sin re-dibujar la estructura
        ['filtroAnio', 'filtroNumero', 'filtroNombre', 'filtroNip'].forEach(id => {
            const el = document.getElementById(id);
            if (el) el.value = '';
        });
        this.pagina = 1;
        this.cargar();
    },

    // ─── Modal de Justificación / Prórroga ──────────────────────────────────
    verJustificacion(data) {
        if (typeof data === 'string') {
            try { data = JSON.parse(data); } catch (e) { data = {}; }
        }

        const estado = data.estado || '';
        const estadoColor = estado === 'VENCIDO' ? '#fee2e2' :
            estado === 'POR_VENCER' ? '#fef3c7' : '#d1fae5';
        const estadoTxt = estado === 'VENCIDO' ? '\u274c VENCIDO' :
            estado === 'POR_VENCER' ? '\u26a0\ufe0f POR VENCER' : '\u2705 VIGENTE';

        const dias = data.dias_restantes;
        const diasTxt = dias === null || dias === undefined ? '—'
            : dias <= 0 ? `Venció hace ${Math.abs(dias)} día(s)`
                : `${dias} día(s) restantes`;

        const justif = data.justificacion ? data.justificacion : '<em style="color:#9ca3af;">Sin comentario registrado</em>';

        showModal('💬 Justificación del Acceso', `
            <div style="display:flex;flex-direction:column;gap:1rem;">
                <div style="font-size:1rem;font-weight:700;">${data.nombre || '—'}</div>

                <div style="background:${estadoColor};padding:0.6rem 1rem;border-radius:8px;font-weight:700;">
                    ${estadoTxt}
                </div>

                <table style="width:100%;border-collapse:collapse;font-size:0.9rem;">
                    <tr>
                        <td style="padding:0.4rem 0;color:#6b7280;width:50%;">Fecha válida hasta:</td>
                        <td style="padding:0.4rem 0;font-weight:600;">${data.fecha_fin ? formatDate(data.fecha_fin) : '—'}</td>
                    </tr>
                    <tr>
                        <td style="padding:0.4rem 0;color:#6b7280;">Días de gracia:</td>
                        <td style="padding:0.4rem 0;font-weight:600;">${data.dias_gracia ?? 0} día(s)</td>
                    </tr>
                    <tr>
                        <td style="padding:0.4rem 0;color:#6b7280;">Tiempo:</td>
                        <td style="padding:0.4rem 0;font-weight:600;">${diasTxt}</td>
                    </tr>
                </table>

                <div style="border-top:1px solid #e5e7eb;padding-top:0.8rem;">
                    <p style="margin:0 0 0.4rem;font-size:0.8rem;font-weight:700;color:#374151;">💬 COMENTARIO / JUSTIFICACIÓN:</p>
                    <div style="background:#f9fafb;border:1px solid #e5e7eb;border-radius:6px;padding:0.8rem;min-height:3rem;">
                        ${justif}
                    </div>
                </div>

                <button class="btn btn-secondary" onclick="hideModal()">Cerrar</button>
            </div>
        `);
    }
};
