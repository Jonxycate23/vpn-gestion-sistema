// BÚSQUEDA, PAGINACIÓN Y ORDENAMIENTO
const IntegratedTableSystem = {
    configs: {},

    /**
     * Inicializar sistema completo en una tabla
     * @param {string} tableId - ID de la tabla
     * @param {object} options - Opciones de configuración
     */
    init(tableId, options = {}) {
        const defaults = {
            itemsPerPage: 50,
            searchable: true,
            sortable: true,
            defaultSort: { column: 'id', order: 'desc' },
            searchPlaceholder: 'Buscar...',
            searchColumns: [], // Vacío = buscar en todas
            filters: [] // Filtros adicionales tipo select
        };

        const config = { ...defaults, ...options };

        // Guardar configuración
        this.configs[tableId] = {
            ...config,
            currentPage: 1,
            totalPages: 0,
            totalItems: 0,
            filteredItems: 0,
            sortColumn: config.defaultSort.column,
            sortOrder: config.defaultSort.order,
            searchTerm: '',
            filterValues: {}
        };

        // Construir controles
        this.buildControls(tableId);

        // Inicializar ordenamiento en headers
        if (config.sortable) {
            this.initSortableHeaders(tableId);
        }

        // Aplicar todo
        this.refresh(tableId);
    },

    /**
     * Construir controles de búsqueda, filtros y paginación
     */
    buildControls(tableId) {
        const config = this.configs[tableId];
        const table = document.getElementById(tableId);
        if (!table) return;

        // 1. BÚSQUEDA Y FILTROS (encima de la tabla)
        if (config.searchable || config.filters.length > 0) {
            let searchContainer = document.getElementById(`${tableId}_search_container`);

            if (!searchContainer) {
                searchContainer = document.createElement('div');
                searchContainer.id = `${tableId}_search_container`;
                searchContainer.className = 'search-filters-container';

                // Buscar el .card que contiene la tabla
                const cardBody = table.closest('.card-body');
                if (cardBody) {
                    cardBody.parentNode.insertBefore(searchContainer, cardBody);
                } else {
                    table.parentNode.insertBefore(searchContainer, table);
                }
            }

            let html = '<div style="display: flex; gap: 1rem; align-items: center; margin-bottom: 1.5rem;">';

            // Búsqueda
            if (config.searchable) {
                html += `
                    <div style="flex: 1; position: relative;">
                        <input 
                            type="text" 
                            id="${tableId}_search" 
                            placeholder="${config.searchPlaceholder}" 
                            style="width: 100%; padding: 0.75rem 1rem 0.75rem 2.5rem; border: 1px solid #ddd; border-radius: 8px; font-size: 0.95rem;"
                        >
                        <span style="position: absolute; left: 0.75rem; top: 50%; transform: translateY(-50%); color: #666;">🔍</span>
                    </div>
                `;
            }

            // Filtros adicionales
            config.filters.forEach(filter => {
                html += `
                    <select id="${tableId}_filter_${filter.id}" 
                            style="padding: 0.75rem; border: 1px solid #ddd; border-radius: 8px; min-width: 150px;">
                        <option value="">${filter.label}</option>
                        ${filter.options.map(opt =>
                    `<option value="${opt.value}">${opt.label}</option>`
                ).join('')}
                    </select>
                `;
            });

            // Botón limpiar
            html += `
                <button id="${tableId}_clear" class="btn btn-outline" style="white-space: nowrap;">
                    🔄 Limpiar
                </button>
            `;

            html += '</div>';
            searchContainer.innerHTML = html;

            // Event listeners
            if (config.searchable) {
                const searchInput = document.getElementById(`${tableId}_search`);
                searchInput.addEventListener('input', (e) => {
                    this.configs[tableId].searchTerm = e.target.value;
                    this.configs[tableId].currentPage = 1; // Reset a página 1
                    this.refresh(tableId);
                });
            }

            config.filters.forEach(filter => {
                const filterSelect = document.getElementById(`${tableId}_filter_${filter.id}`);
                filterSelect.addEventListener('change', (e) => {
                    this.configs[tableId].filterValues[filter.id] = e.target.value;
                    this.configs[tableId].currentPage = 1; // Reset a página 1
                    this.refresh(tableId);
                });
            });

            const clearBtn = document.getElementById(`${tableId}_clear`);
            clearBtn.addEventListener('click', () => {
                this.clearFilters(tableId);
            });
        }

        // 2. PAGINACIÓN (debajo de la tabla)
        let paginationContainer = document.getElementById(`${tableId}_pagination_container`);

        if (!paginationContainer) {
            paginationContainer = document.createElement('div');
            paginationContainer.id = `${tableId}_pagination_container`;
            table.parentNode.insertBefore(paginationContainer, table.nextSibling);
        }

        paginationContainer.className = 'pagination-container';
        paginationContainer.innerHTML = `
            <div style="display: flex; justify-content: space-between; align-items: center; padding: 1rem; background: white; border-radius: 8px; margin-top: 1rem; box-shadow: 0 1px 3px rgba(0,0,0,0.1);">
                
                <div style="color: #666; font-size: 0.9rem;">
                    Mostrando <strong id="${tableId}_showing_start">0</strong> - <strong id="${tableId}_showing_end">0</strong> 
                    de <strong id="${tableId}_showing_total">0</strong> registros
                    <span id="${tableId}_filtered_info" style="color: #f59e0b;"></span>
                </div>
                
                <div id="${tableId}_pagination_buttons" style="display: flex; gap: 0.5rem; align-items: center;">
                    <!-- Se generarán dinámicamente -->
                </div>
                
                <div style="display: flex; align-items: center; gap: 0.5rem;">
                    <label style="font-size: 0.9rem; color: #666;">Por página:</label>
                    <select id="${tableId}_items_per_page" 
                            style="padding: 0.5rem; border: 1px solid #ddd; border-radius: 4px; font-size: 0.9rem;">
                        <option value="25" ${config.itemsPerPage === 25 ? 'selected' : ''}>25</option>
                        <option value="50" ${config.itemsPerPage === 50 ? 'selected' : ''}>50</option>
                        <option value="100" ${config.itemsPerPage === 100 ? 'selected' : ''}>100</option>
                        <option value="250" ${config.itemsPerPage === 250 ? 'selected' : ''}>250</option>
                        <option value="500" ${config.itemsPerPage === 500 ? 'selected' : ''}>500</option>
                    </select>
                </div>
            </div>
        `;

        // Event listener para cambiar items por página
        const itemsPerPageSelect = document.getElementById(`${tableId}_items_per_page`);
        itemsPerPageSelect.addEventListener('change', (e) => {
            this.configs[tableId].itemsPerPage = parseInt(e.target.value);
            this.configs[tableId].currentPage = 1;
            this.refresh(tableId);
        });
    },

    /**
     * Inicializar headers ordenables
     */
    initSortableHeaders(tableId) {
        const table = document.getElementById(tableId);
        if (!table) return;

        const headers = table.querySelectorAll('thead th');
        headers.forEach((header, index) => {
            const sortable = header.dataset.sortable !== 'false';
            const columnName = header.dataset.sort || `col${index}`;

            if (sortable && columnName !== 'actions') {
                // ✅ LIMPIAR FLECHITAS ANTERIORES (CRÍTICO)
                const oldIndicators = header.querySelectorAll('.sort-indicator');
                oldIndicators.forEach(ind => ind.remove());

                header.style.cursor = 'pointer';
                header.style.userSelect = 'none';
                header.dataset.sort = columnName;

                // Agregar indicador NUEVO
                const indicator = document.createElement('span');
                indicator.className = 'sort-indicator';
                indicator.innerHTML = '⇅';
                indicator.style.marginLeft = '0.5rem';
                indicator.style.opacity = '0.3';
                header.appendChild(indicator);

                // ✅ REMOVER LISTENERS ANTERIORES (evitar duplicados)
                const newHeader = header.cloneNode(true);
                header.parentNode.replaceChild(newHeader, header);

                // Agregar nuevo listener
                newHeader.addEventListener('click', () => {
                    this.toggleSort(tableId, columnName);
                });
            }
        });
    },

    /**
     * Toggle ordenamiento
     */
    toggleSort(tableId, column) {
        const config = this.configs[tableId];

        if (config.sortColumn === column) {
            // Cambiar orden
            config.sortOrder = config.sortOrder === 'asc' ? 'desc' : 'asc';
        } else {
            // Nueva columna
            config.sortColumn = column;
            config.sortOrder = 'asc';
        }

        this.refresh(tableId);
    },

    /**
     * Actualizar indicadores de ordenamiento
     */
    updateSortIndicators(tableId) {
        const config = this.configs[tableId];
        const table = document.getElementById(tableId);
        if (!table) return;

        const headers = table.querySelectorAll('thead th');
        headers.forEach(header => {
            const indicator = header.querySelector('.sort-indicator');
            if (!indicator) return;

            const column = header.dataset.sort;

            if (column === config.sortColumn) {
                indicator.style.opacity = '1';
                indicator.innerHTML = config.sortOrder === 'asc' ? '▲' : '▼';
                header.style.fontWeight = 'bold';
                header.style.color = '#2563eb';
            } else {
                indicator.style.opacity = '0.3';
                indicator.innerHTML = '⇅';
                header.style.fontWeight = '600';
                header.style.color = '';
            }
        });
    },

    /**
     * FUNCIÓN PRINCIPAL: Aplicar todo (filtrado + ordenamiento + paginación)
     */
    refresh(tableId) {
        const config = this.configs[tableId];
        const table = document.getElementById(tableId);
        if (!table) return;

        const tbody = table.querySelector('tbody');
        if (!tbody) return;

        // 1. OBTENER TODAS LAS FILAS VÁLIDAS
        const allRows = Array.from(tbody.querySelectorAll('tr')).filter(row => {
            if (row.cells.length === 0) return false;
            if (row.classList.contains('no-results-row')) return false;

            const text = row.cells[0].textContent.trim().toLowerCase();
            if (text === 'cargando...' || text === 'no hay datos') return false;

            return true;
        });

        config.totalItems = allRows.length;

        // 2. APLICAR BÚSQUEDA Y FILTROS
        let filteredRows = allRows.filter(row => {
            // Búsqueda por texto
            if (config.searchTerm) {
                const searchLower = config.searchTerm.toLowerCase().trim();
                const rowText = Array.from(row.cells)
                    .map(cell => cell.textContent.toLowerCase())
                    .join(' ');

                if (!rowText.includes(searchLower)) {
                    return false;
                }
            }

            // Filtros adicionales
            for (const filterId in config.filterValues) {
                const filterValue = config.filterValues[filterId];
                if (!filterValue) continue;

                const filter = config.filters.find(f => f.id === filterId);
                if (!filter) continue;

                const cellIndex = filter.columnIndex;
                const cellValue = row.cells[cellIndex]?.textContent.trim().toUpperCase() || '';

                // Filtro de bloqueo: comparación exacta para evitar que DESBLOQUEADO matchee BLOQUEADO
                if (filterValue === 'BLOQUEADO_EXACT') {
                    if (cellValue !== 'BLOQUEADO') return false;
                } else if (!cellValue.includes(filterValue.toUpperCase())) {
                    return false;
                }
            }

            return true;
        });

        config.filteredItems = filteredRows.length;

        // 3. APLICAR ORDENAMIENTO
        if (config.sortable && config.sortColumn) {
            const headers = Array.from(table.querySelectorAll('thead th'));
            const columnIndex = headers.findIndex(h => h.dataset.sort === config.sortColumn);

            if (columnIndex !== -1) {
                filteredRows.sort((a, b) => {
                    const cellA = a.cells[columnIndex];
                    const cellB = b.cells[columnIndex];

                    if (!cellA || !cellB) return 0;

                    let valueA = this.getCellValue(cellA);
                    let valueB = this.getCellValue(cellB);

                    let comparison = 0;

                    // Intentar extraer números si parece ser un campo numérico con texto (e.g. "-7 días")
                    let numA = this._extractNumber(valueA);
                    let numB = this._extractNumber(valueB);

                    if (numA !== null && numB !== null) {
                        comparison = numA - numB;
                    }
                    // Fecha
                    else if (this.isDate(valueA) && this.isDate(valueB)) {
                        const dateA = new Date(valueA.split('/').reverse().join('-')); // DD/MM/YYYY -> YYYY-MM-DD
                        const dateB = new Date(valueB.split('/').reverse().join('-'));
                        comparison = dateA - dateB;
                    }
                    // Texto
                    else {
                        comparison = valueA.localeCompare(valueB, 'es', { numeric: true });
                    }

                    return config.sortOrder === 'asc' ? comparison : -comparison;
                });
            }
        }

        // 4. CALCULAR PAGINACIÓN
        config.totalPages = Math.ceil(config.filteredItems / config.itemsPerPage);

        if (config.currentPage > config.totalPages && config.totalPages > 0) {
            config.currentPage = config.totalPages;
        }
        if (config.currentPage < 1) {
            config.currentPage = 1;
        }

        const startIndex = (config.currentPage - 1) * config.itemsPerPage;
        const endIndex = startIndex + config.itemsPerPage;

        // 5. MOSTRAR/OCULTAR FILAS
        allRows.forEach(row => row.style.display = 'none'); // Ocultar todas

        filteredRows.forEach((row, index) => {
            if (index >= startIndex && index < endIndex) {
                row.style.display = ''; // Mostrar solo las de la página actual
            }
        });

        // Reordenar en el DOM para que el orden visual coincida
        filteredRows.forEach(row => tbody.appendChild(row));

        // 6. ACTUALIZAR CONTROLES
        this.updatePaginationInfo(tableId);
        this.updatePaginationButtons(tableId);
        this.updateSortIndicators(tableId);

        // 7. MENSAJE DE "NO HAY RESULTADOS"
        if (config.filteredItems === 0 && (config.searchTerm || Object.keys(config.filterValues).length > 0)) {
            const noResultsRow = tbody.querySelector('.no-results-row');
            if (noResultsRow) noResultsRow.remove();

            const tr = document.createElement('tr');
            tr.className = 'no-results-row';
            tr.innerHTML = `
                <td colspan="${table.querySelectorAll('thead th').length}" 
                    style="text-align: center; padding: 2rem; color: #666;">
                    🔍 No se encontraron resultados con los criterios de búsqueda
                </td>
            `;
            tbody.appendChild(tr);
        }
    },

    /**
     * Actualizar información de paginación
     */
    updatePaginationInfo(tableId) {
        const config = this.configs[tableId];

        const startEl = document.getElementById(`${tableId}_showing_start`);
        const endEl = document.getElementById(`${tableId}_showing_end`);
        const totalEl = document.getElementById(`${tableId}_showing_total`);
        const filteredEl = document.getElementById(`${tableId}_filtered_info`);

        if (!startEl || !endEl || !totalEl) return;

        const start = config.filteredItems === 0 ? 0 : (config.currentPage - 1) * config.itemsPerPage + 1;
        const end = Math.min(config.currentPage * config.itemsPerPage, config.filteredItems);

        startEl.textContent = start;
        endEl.textContent = end;
        totalEl.textContent = config.filteredItems;

        // Mostrar si hay filtros aplicados
        if (filteredEl) {
            if (config.filteredItems < config.totalItems) {
                filteredEl.textContent = ` (filtrados de ${config.totalItems} totales)`;
            } else {
                filteredEl.textContent = '';
            }
        }
    },

    /**
     * Actualizar botones de paginación
     */
    updatePaginationButtons(tableId) {
        const config = this.configs[tableId];
        const container = document.getElementById(`${tableId}_pagination_buttons`);
        if (!container) return;

        if (config.totalPages === 0) {
            container.innerHTML = '<span style="color: #999;">Sin registros</span>';
            return;
        }

        let buttons = [];

        // Previous
        buttons.push(`
            <button class="pagination-btn ${config.currentPage === 1 ? 'disabled' : ''}" 
                    onclick="IntegratedTableSystem.goToPage('${tableId}', ${config.currentPage - 1})"
                    ${config.currentPage === 1 ? 'disabled' : ''}>
                ◀
            </button>
        `);

        // Números
        const pageButtons = this.generatePageButtons(config.currentPage, config.totalPages);
        pageButtons.forEach(page => {
            if (page === '...') {
                buttons.push(`<span style="padding: 0 0.5rem; color: #666;">...</span>`);
            } else {
                buttons.push(`
                    <button class="pagination-btn ${page === config.currentPage ? 'active' : ''}" 
                            onclick="IntegratedTableSystem.goToPage('${tableId}', ${page})">
                        ${page}
                    </button>
                `);
            }
        });

        // Next
        buttons.push(`
            <button class="pagination-btn ${config.currentPage === config.totalPages ? 'disabled' : ''}" 
                    onclick="IntegratedTableSystem.goToPage('${tableId}', ${config.currentPage + 1})"
                    ${config.currentPage === config.totalPages ? 'disabled' : ''}>
                ▶
            </button>
        `);

        container.innerHTML = buttons.join('');
    },

    generatePageButtons(current, total) {
        const pages = [];
        const maxButtons = 7;

        if (total <= maxButtons) {
            for (let i = 1; i <= total; i++) {
                pages.push(i);
            }
        } else {
            pages.push(1);

            const start = Math.max(2, current - 2);
            const end = Math.min(total - 1, current + 2);

            if (start > 2) pages.push('...');

            for (let i = start; i <= end; i++) {
                pages.push(i);
            }

            if (end < total - 1) pages.push('...');

            pages.push(total);
        }

        return pages;
    },

    goToPage(tableId, page) {
        const config = this.configs[tableId];
        page = parseInt(page);

        if (isNaN(page) || page < 1 || page > config.totalPages) return;
        if (page === config.currentPage) return;

        config.currentPage = page;
        this.refresh(tableId);
    },

    clearFilters(tableId) {
        const config = this.configs[tableId];

        // Limpiar búsqueda
        const searchInput = document.getElementById(`${tableId}_search`);
        if (searchInput) searchInput.value = '';
        config.searchTerm = '';

        // Limpiar filtros
        config.filters.forEach(filter => {
            const filterSelect = document.getElementById(`${tableId}_filter_${filter.id}`);
            if (filterSelect) filterSelect.value = '';
        });
        config.filterValues = {};

        config.currentPage = 1;
        this.refresh(tableId);
    },

    /**
     * Reseteo completo de la tabla (para cambio de vistas)
     */
    reset(tableId) {
        if (!this.configs[tableId]) return;

        this.clearFilters(tableId);
        this.configs[tableId].searchTerm = '';
        this.configs[tableId].filterValues = {};
        this.configs[tableId].currentPage = 1;

        // Limpieza profunda del DOM por si acaso
        const searchInput = document.getElementById(`${tableId}_search`);
        if (searchInput) searchInput.value = '';
    },

    // Utilidades
    getCellValue(cell) {
        const badge = cell.querySelector('.status-badge');
        if (badge) return badge.textContent.trim();

        const strong = cell.querySelector('strong');
        if (strong) return strong.textContent.trim();

        const code = cell.querySelector('code');
        if (code) return code.textContent.trim();

        return cell.textContent.trim();
    },

    /**
     * Extraer número de una cadena (soporta negativos)
     * Útil para "10 días", "-5 días", etc.
     */
    _extractNumber(str) {
        if (!str) return null;
        // Buscar el primer número (puede empezar con -)
        const match = str.match(/-?\d+/);
        return match ? parseInt(match[0], 10) : null;
    },

    isDate(value) {
        if (!value || value === '-' || value === 'N/A') return false;

        const datePattern = /^\d{2}\/\d{2}\/\d{4}$/;
        if (datePattern.test(value)) return true;

        const isoPattern = /^\d{4}-\d{2}-\d{2}/;
        if (isoPattern.test(value)) return true;

        return false;
    }
};

// ========================================
// INTEGRACIÓN CON SOLICITUDES Y ACCESOS
// ========================================

// Esperar a que todo esté cargado
document.addEventListener('DOMContentLoaded', () => {
    setTimeout(() => {
        initIntegratedTables();
    }, 2000);
});

// 🔒 Control de inicialización
const tablesInitialized = {
    solicitudesTable: false,
    accesosTable: false,
    tablaDashboardAlertas: false
};


function initIntegratedTables() {

    // Solicitudes
    if (document.getElementById('solicitudesTable')) {
        // ✅ SOLO INICIALIZAR SI NO ESTÁ INICIALIZADO
        if (!tablesInitialized.solicitudesTable) {

            const solHeaders = document.querySelectorAll('#solicitudesTable thead th');
            const solColumns = ['id', 'nip', 'oficio', 'providencia', 'fecha', 'nombre', 'estado', 'actions'];
            solHeaders.forEach((th, i) => {
                th.dataset.sort = solColumns[i];
                if (solColumns[i] === 'actions') {
                    th.dataset.sortable = 'false';
                }
            });

            IntegratedTableSystem.init('solicitudesTable', {
                itemsPerPage: 50,
                searchable: true,
                sortable: true,
                defaultSort: { column: 'id', order: 'desc' },
                searchPlaceholder: 'Buscar por nombre, DPI, NIP, oficio, providencia...',
                filters: [
                    {
                        id: 'estado',
                        label: 'Todos los estados',
                        columnIndex: 6,
                        options: [
                            { value: 'PENDIENTE', label: '⚠️ Pendientes' },
                            { value: 'APROBADA', label: '✅ Aprobadas' },
                            { value: 'RECHAZADA', label: '❌ Rechazadas' },
                            { value: 'CANCELADA', label: '🚫 Canceladas' }
                        ]
                    }
                ]
            });

            tablesInitialized.solicitudesTable = true;
        } else {
            IntegratedTableSystem.refresh('solicitudesTable');
        }
    }

    // Accesos
    if (document.getElementById('accesosTable')) {
        if (!tablesInitialized.accesosTable) {

            const accHeaders = document.querySelectorAll('#accesosTable thead th');
            const accColumns = ['nip', 'nombre', 'usuario', 'fecha_inicio', 'fecha_fin', 'estado', 'dias', 'bloqueo', 'actions'];
            accHeaders.forEach((th, i) => {
                th.dataset.sort = accColumns[i];
                if (accColumns[i] === 'actions') {
                    th.dataset.sortable = 'false';
                }
            });

            IntegratedTableSystem.init('accesosTable', {
                itemsPerPage: 50,
                searchable: true,
                sortable: true,
                defaultSort: { column: 'dias', order: 'asc' },
                searchPlaceholder: 'Buscar por nombre, DPI, NIP, usuario VPN...',
                filters: [
                    {
                        id: 'estado',
                        label: 'Todos los estados',
                        columnIndex: 5,
                        options: [
                            { value: 'ACTIVO', label: '✅ Activos/Vigentes' },
                            { value: 'POR VENCER', label: '⚠️ Por vencer' },
                            { value: 'VENCIDO', label: '❌ Vencidos' }
                        ]
                    },
                    {
                        id: 'bloqueo',
                        label: 'Todos',
                        columnIndex: 7,
                        options: [
                            { value: 'DESBLOQUEADO', label: '🔓 Desbloqueados' },
                            { value: 'BLOQUEADO_EXACT', label: '🔒 Bloqueados' }
                        ]
                    }
                ]
            });

            tablesInitialized.accesosTable = true;
        } else {
            IntegratedTableSystem.refresh('accesosTable');
        }
    }
}

// Modificar Solicitudes.load()
if (typeof Solicitudes !== 'undefined') {
    const originalSolicitudesLoad = Solicitudes.load;
    Solicitudes.load = async function () {
        // ✅ GUARDAR filtro activo antes de recargar
        const cfg = IntegratedTableSystem.configs['solicitudesTable'];
        const savedSearch = cfg?.searchTerm || '';
        const savedFilters = cfg ? { ...cfg.filterValues } : {};

        await originalSolicitudesLoad.call(this);

        setTimeout(() => {
            if (document.getElementById('solicitudesTable')) {
                initIntegratedTables();
            }

            if (IntegratedTableSystem.configs['solicitudesTable']) {
                if (savedSearch || Object.keys(savedFilters).length > 0) {
                    // ✅ RESTAURAR el filtro que tenía el usuario
                    IntegratedTableSystem.configs['solicitudesTable'].searchTerm = savedSearch;
                    IntegratedTableSystem.configs['solicitudesTable'].filterValues = savedFilters;
                    IntegratedTableSystem.configs['solicitudesTable'].currentPage = 1;

                    // Restaurar el valor visible en el input de búsqueda
                    const searchInput = document.getElementById('solicitudesTable_search');
                    if (searchInput) searchInput.value = savedSearch;

                    // Restaurar selects de filtro
                    for (const filterId in savedFilters) {
                        const filterEl = document.getElementById(`solicitudesTable_filter_${filterId}`);
                        if (filterEl) filterEl.value = savedFilters[filterId];
                    }

                    IntegratedTableSystem.refresh('solicitudesTable');
                } else {
                    // Sin filtro activo: reset normal
                    IntegratedTableSystem.reset('solicitudesTable');
                    IntegratedTableSystem.refresh('solicitudesTable');
                }
            }
        }, 500);
    };

    // Eliminar el ordenamiento manual que tenías
    Solicitudes.toggleOrden = function () {
        const config = IntegratedTableSystem.configs['solicitudesTable'];
        if (config) {
            config.sortOrder = config.sortOrder === 'desc' ? 'asc' : 'desc';
            IntegratedTableSystem.refresh('solicitudesTable');
        }
    };
}

// Modificar Accesos.load()
if (typeof Accesos !== 'undefined') {
    const originalAccesosLoad = Accesos.load;
    Accesos.load = async function () {
        // ✅ GUARDAR filtro activo antes de recargar
        const cfg = IntegratedTableSystem.configs['accesosTable'];
        const savedSearch = cfg?.searchTerm || '';
        const savedFilters = cfg ? { ...cfg.filterValues } : {};

        await originalAccesosLoad.call(this);

        setTimeout(() => {
            if (document.getElementById('accesosTable')) {
                initIntegratedTables();
            }

            if (IntegratedTableSystem.configs['accesosTable']) {
                if (savedSearch || Object.keys(savedFilters).length > 0) {
                    // ✅ RESTAURAR el filtro que tenía el usuario
                    IntegratedTableSystem.configs['accesosTable'].searchTerm = savedSearch;
                    IntegratedTableSystem.configs['accesosTable'].filterValues = savedFilters;
                    IntegratedTableSystem.configs['accesosTable'].currentPage = 1;

                    // Restaurar el valor visible en el input de búsqueda
                    const searchInput = document.getElementById('accesosTable_search');
                    if (searchInput) searchInput.value = savedSearch;

                    // Restaurar selects de filtro
                    for (const filterId in savedFilters) {
                        const filterEl = document.getElementById(`accesosTable_filter_${filterId}`);
                        if (filterEl) filterEl.value = savedFilters[filterId];
                    }

                    IntegratedTableSystem.refresh('accesosTable');
                } else {
                    // Sin filtro activo: reset normal
                    IntegratedTableSystem.reset('accesosTable');
                    IntegratedTableSystem.refresh('accesosTable');
                }
            }
        }, 500);
    };
}


