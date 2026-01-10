// 📄 SISTEMA DE PAGINACIÓN UNIVERSAL PARA TABLAS - VERSIÓN CORREGIDA
// 📂 Ubicación: frontend/js/pagination.js
// ✅ CORRIGE: Bloqueo al cambiar de página y datos que desaparecen

const Paginator = {
    // Configuración por tabla
    configs: {},
    
    /**
     * Inicializar paginación en una tabla
     * @param {string} tableId - ID de la tabla
     * @param {number} itemsPerPage - Elementos por página (default: 50)
     * @param {string} containerId - ID del contenedor donde colocar los controles (opcional)
     */
    init(tableId, itemsPerPage = 50, containerId = null) {
        const table = document.getElementById(tableId);
        if (!table) {
            console.error(`Tabla ${tableId} no encontrada`);
            return;
        }
        
        // Configuración inicial
        this.configs[tableId] = {
            currentPage: 1,
            itemsPerPage: itemsPerPage,
            totalPages: 0,
            totalItems: 0,
            containerId: containerId
        };
        
        // Crear controles de paginación
        this.createPaginationControls(tableId);
        
        // Aplicar paginación inicial
        this.paginate(tableId);
    },
    
    /**
     * Crear controles de paginación
     */
    createPaginationControls(tableId) {
        const config = this.configs[tableId];
        const table = document.getElementById(tableId);
        
        // Determinar dónde colocar los controles
        let container;
        if (config.containerId) {
            container = document.getElementById(config.containerId);
        } else {
            // Buscar si ya existe el contenedor
            container = document.getElementById(`${tableId}_pagination_container`);
            if (!container) {
                // Crear contenedor después de la tabla
                container = document.createElement('div');
                container.id = `${tableId}_pagination_container`;
                table.parentNode.insertBefore(container, table.nextSibling);
            }
        }
        
        container.className = 'pagination-container';
        container.innerHTML = `
            <div style="display: flex; justify-content: space-between; align-items: center; padding: 1rem; background: white; border-radius: 8px; margin-top: 1rem; box-shadow: 0 1px 3px rgba(0,0,0,0.1);">
                
                <!-- Información de registros -->
                <div style="color: #666; font-size: 0.9rem;">
                    Mostrando <strong id="${tableId}_showing_start">0</strong> - <strong id="${tableId}_showing_end">0</strong> 
                    de <strong id="${tableId}_total_items">0</strong> registros
                </div>
                
                <!-- Botones de paginación -->
                <div id="${tableId}_pagination_buttons" style="display: flex; gap: 0.5rem; align-items: center;">
                    <!-- Se generarán dinámicamente -->
                </div>
                
                <!-- Selector de items por página -->
                <div style="display: flex; align-items: center; gap: 0.5rem;">
                    <label style="font-size: 0.9rem; color: #666;">Por página:</label>
                    <select id="${tableId}_items_per_page" 
                            onchange="Paginator.changeItemsPerPage('${tableId}', this.value)"
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
    },
    
    /**
     * Aplicar paginación a la tabla - VERSIÓN CORREGIDA
     */
    paginate(tableId) {
        const config = this.configs[tableId];
        const table = document.getElementById(tableId);
        const tbody = table.querySelector('tbody');
        
        if (!tbody) {
            console.error(`No se encontró tbody en tabla ${tableId}`);
            return;
        }
        
        // ✅ CORRECCIÓN 1: Obtener TODAS las filas, sin filtrar por display
        const allRows = Array.from(tbody.querySelectorAll('tr'));
        
        // ✅ CORRECCIÓN 2: Filtrar solo filas válidas (no mensajes de "Cargando...", "No hay datos", etc.)
        const validRows = allRows.filter(row => {
            // Verificar si tiene celdas
            if (row.cells.length === 0) return false;
            
            // Verificar si es una fila de mensaje (no-results-row, loading, etc.)
            if (row.classList.contains('no-results-row')) return false;
            
            // Verificar contenido de la primera celda
            const firstCell = row.cells[0];
            if (!firstCell) return false;
            
            const text = firstCell.textContent.trim().toLowerCase();
            
            // Excluir mensajes comunes
            if (text === 'cargando...' || 
                text === 'no hay datos' || 
                text === 'no hay registros' ||
                text.includes('no se encontraron')) {
                return false;
            }
            
            // Es una fila válida
            return true;
        });
        
        console.log(`📊 Tabla ${tableId}: ${validRows.length} filas válidas encontradas`);
        
        config.totalItems = validRows.length;
        config.totalPages = Math.ceil(config.totalItems / config.itemsPerPage);
        
        // Si no hay registros válidos
        if (config.totalItems === 0) {
            this.updatePaginationInfo(tableId);
            this.updatePaginationButtons(tableId);
            return;
        }
        
        // ✅ CORRECCIÓN 3: Asegurar que la página actual sea válida
        if (config.currentPage > config.totalPages) {
            config.currentPage = config.totalPages;
        }
        if (config.currentPage < 1) {
            config.currentPage = 1;
        }
        
        // Calcular índices
        const startIndex = (config.currentPage - 1) * config.itemsPerPage;
        const endIndex = startIndex + config.itemsPerPage;
        
        console.log(`📄 Página ${config.currentPage}: mostrando filas ${startIndex} - ${endIndex}`);
        
        // ✅ CORRECCIÓN 4: Mostrar/ocultar filas según la página actual
        validRows.forEach((row, index) => {
            if (index >= startIndex && index < endIndex) {
                row.style.display = ''; // Mostrar
            } else {
                row.style.display = 'none'; // Ocultar
            }
        });
        
        // Actualizar controles
        this.updatePaginationInfo(tableId);
        this.updatePaginationButtons(tableId);
        
        // ✅ CORRECCIÓN 5: Eliminar scroll automático que causa problemas
        // Opcional: descomenta si quieres scroll suave
        // table.scrollIntoView({ behavior: 'smooth', block: 'start' });
    },
    
    /**
     * Actualizar información de paginación
     */
    updatePaginationInfo(tableId) {
        const config = this.configs[tableId];
        
        const startElement = document.getElementById(`${tableId}_showing_start`);
        const endElement = document.getElementById(`${tableId}_showing_end`);
        const totalElement = document.getElementById(`${tableId}_total_items`);
        
        if (!startElement || !endElement || !totalElement) {
            console.warn(`No se encontraron elementos de información para ${tableId}`);
            return;
        }
        
        const start = config.totalItems === 0 ? 0 : (config.currentPage - 1) * config.itemsPerPage + 1;
        const end = Math.min(config.currentPage * config.itemsPerPage, config.totalItems);
        
        startElement.textContent = start;
        endElement.textContent = end;
        totalElement.textContent = config.totalItems;
    },
    
    /**
     * Actualizar botones de paginación
     */
    updatePaginationButtons(tableId) {
        const config = this.configs[tableId];
        const container = document.getElementById(`${tableId}_pagination_buttons`);
        
        if (!container) {
            console.warn(`No se encontró contenedor de botones para ${tableId}`);
            return;
        }
        
        // Si no hay páginas, ocultar botones
        if (config.totalPages === 0) {
            container.innerHTML = '<span style="color: #999;">No hay registros</span>';
            return;
        }
        
        let buttons = [];
        
        // Botón "Previous"
        buttons.push(`
            <button class="pagination-btn ${config.currentPage === 1 ? 'disabled' : ''}" 
                    onclick="Paginator.goToPage('${tableId}', ${config.currentPage - 1})"
                    ${config.currentPage === 1 ? 'disabled' : ''}>
                Previous
            </button>
        `);
        
        // Generar botones de números
        const pageButtons = this.generatePageButtons(config.currentPage, config.totalPages);
        
        pageButtons.forEach(page => {
            if (page === '...') {
                buttons.push(`<span style="padding: 0 0.5rem; color: #666;">...</span>`);
            } else {
                buttons.push(`
                    <button class="pagination-btn ${page === config.currentPage ? 'active' : ''}" 
                            onclick="Paginator.goToPage('${tableId}', ${page})">
                        ${page}
                    </button>
                `);
            }
        });
        
        // Botón "Next"
        buttons.push(`
            <button class="pagination-btn ${config.currentPage === config.totalPages ? 'disabled' : ''}" 
                    onclick="Paginator.goToPage('${tableId}', ${config.currentPage + 1})"
                    ${config.currentPage === config.totalPages ? 'disabled' : ''}>
                Next
            </button>
        `);
        
        container.innerHTML = buttons.join('');
    },
    
    /**
     * Generar números de página con lógica inteligente
     * Muestra: 1 ... 4 5 [6] 7 8 ... 50
     */
    generatePageButtons(currentPage, totalPages) {
        const pages = [];
        const maxButtons = 7; // Máximo de botones numéricos a mostrar
        
        if (totalPages <= maxButtons) {
            // Si hay pocas páginas, mostrar todas
            for (let i = 1; i <= totalPages; i++) {
                pages.push(i);
            }
        } else {
            // Siempre mostrar la primera página
            pages.push(1);
            
            // Calcular rango alrededor de la página actual
            let startPage = Math.max(2, currentPage - 2);
            let endPage = Math.min(totalPages - 1, currentPage + 2);
            
            // Agregar "..." si hay gap al inicio
            if (startPage > 2) {
                pages.push('...');
            }
            
            // Agregar páginas del rango
            for (let i = startPage; i <= endPage; i++) {
                pages.push(i);
            }
            
            // Agregar "..." si hay gap al final
            if (endPage < totalPages - 1) {
                pages.push('...');
            }
            
            // Siempre mostrar la última página
            pages.push(totalPages);
        }
        
        return pages;
    },
    
    /**
     * Ir a una página específica - VERSIÓN CORREGIDA
     */
    goToPage(tableId, page) {
        const config = this.configs[tableId];
        
        // ✅ CORRECCIÓN 6: Validaciones más estrictas
        page = parseInt(page);
        
        if (isNaN(page)) {
            console.error(`Página inválida: ${page}`);
            return;
        }
        
        if (page < 1 || page > config.totalPages) {
            console.warn(`Página fuera de rango: ${page} (total: ${config.totalPages})`);
            return;
        }
        
        if (page === config.currentPage) {
            console.log(`Ya estás en la página ${page}`);
            return;
        }
        
        console.log(`📄 Cambiando a página ${page}`);
        
        config.currentPage = page;
        this.paginate(tableId);
    },
    
    /**
     * Cambiar items por página
     */
    changeItemsPerPage(tableId, newValue) {
        const config = this.configs[tableId];
        config.itemsPerPage = parseInt(newValue);
        config.currentPage = 1; // Resetear a primera página
        console.log(`📊 Items por página cambiados a: ${config.itemsPerPage}`);
        this.paginate(tableId);
    },
    
    /**
     * Refresh - útil después de aplicar filtros
     */
    refresh(tableId) {
        const config = this.configs[tableId];
        if (!config) {
            console.error(`No existe configuración para tabla ${tableId}`);
            return;
        }
        config.currentPage = 1; // Volver a página 1
        console.log(`🔄 Refrescando paginación de ${tableId}`);
        this.paginate(tableId);
    }
};

// ========================================
// INTEGRACIÓN CON BUSCADOR
// ========================================

// Modificar BuscadorVPN para que actualice la paginación después de filtrar
if (typeof BuscadorVPN !== 'undefined') {
    console.log('🔍 Integrando Paginator con BuscadorVPN...');
    
    const originalFiltrarSolicitudes = BuscadorVPN.filtrarSolicitudes;
    BuscadorVPN.filtrarSolicitudes = function(searchTerm, estadoFilter) {
        originalFiltrarSolicitudes.call(this, searchTerm, estadoFilter);
        if (Paginator.configs['solicitudesTable']) {
            Paginator.refresh('solicitudesTable');
        }
    };
    
    const originalFiltrarAccesos = BuscadorVPN.filtrarAccesos;
    BuscadorVPN.filtrarAccesos = function(searchTerm, estadoFilter, bloqueoFilter) {
        originalFiltrarAccesos.call(this, searchTerm, estadoFilter, bloqueoFilter);
        if (Paginator.configs['accesosTable']) {
            Paginator.refresh('accesosTable');
        }
    };
}

// ========================================
// ESTILOS CSS PARA BOTONES DE PAGINACIÓN
// ========================================

const paginationStyles = document.createElement('style');
paginationStyles.textContent = `
    .pagination-btn {
        padding: 0.5rem 1rem;
        border: 1px solid #ddd;
        background: white;
        color: #374151;
        border-radius: 4px;
        cursor: pointer;
        font-size: 0.9rem;
        font-weight: 500;
        transition: all 0.2s;
    }
    
    .pagination-btn:hover:not(.disabled):not(.active) {
        background: #f3f4f6;
        border-color: #2563eb;
        color: #2563eb;
    }
    
    .pagination-btn.active {
        background: #2563eb;
        color: white;
        border-color: #2563eb;
        font-weight: 600;
    }
    
    .pagination-btn.disabled {
        background: #f9fafb;
        color: #9ca3af;
        cursor: not-allowed;
        border-color: #e5e7eb;
    }
    
    .pagination-container {
        animation: fadeIn 0.3s ease-in;
    }
    
    @keyframes fadeIn {
        from { opacity: 0; transform: translateY(-10px); }
        to { opacity: 1; transform: translateY(0); }
    }
`;
document.head.appendChild(paginationStyles);

// ========================================
// AUTO-INICIALIZACIÓN
// ========================================

// Inicializar paginación automáticamente en las tablas principales
document.addEventListener('DOMContentLoaded', () => {
    console.log('📄 Paginator: DOM cargado, esperando tablas...');
    // Esperar a que las tablas se carguen
    setTimeout(() => {
        initPaginationForAllTables();
    }, 2000);
});

function initPaginationForAllTables() {
    console.log('📄 Inicializando paginación en todas las tablas...');
    
    // Dashboard (50 registros por página)
    if (document.getElementById('dashboardTable')) {
        console.log('📊 Inicializando paginación en dashboardTable');
        Paginator.init('dashboardTable', 50);
    }
    
    // Solicitudes (100 registros por página)
    if (document.getElementById('solicitudesTable')) {
        console.log('📄 Inicializando paginación en solicitudesTable');
        Paginator.init('solicitudesTable', 100);
    }
    
    // Accesos (100 registros por página)
    if (document.getElementById('accesosTable')) {
        console.log('🔑 Inicializando paginación en accesosTable');
        Paginator.init('accesosTable', 100);
    }
    
    // Usuarios (50 registros por página)
    if (document.getElementById('usuariosTable')) {
        console.log('👥 Inicializando paginación en usuariosTable');
        Paginator.init('usuariosTable', 50);
    }
}

// ========================================
// INTEGRACIÓN CON MÓDULOS EXISTENTES
// ========================================

// Modificar Solicitudes.load() para inicializar paginación
if (typeof Solicitudes !== 'undefined') {
    console.log('📄 Integrando Paginator con Solicitudes...');
    const originalSolicitudesLoad = Solicitudes.load;
    Solicitudes.load = async function() {
        await originalSolicitudesLoad.call(this);
        setTimeout(() => {
            if (!Paginator.configs['solicitudesTable']) {
                Paginator.init('solicitudesTable', 100);
            } else {
                Paginator.refresh('solicitudesTable');
            }
        }, 500);
    };
}

// Modificar Accesos.load() para inicializar paginación
if (typeof Accesos !== 'undefined') {
    console.log('🔑 Integrando Paginator con Accesos...');
    const originalAccesosLoad = Accesos.load;
    Accesos.load = async function() {
        await originalAccesosLoad.call(this);
        setTimeout(() => {
            if (!Paginator.configs['accesosTable']) {
                Paginator.init('accesosTable', 100);
            } else {
                Paginator.refresh('accesosTable');
            }
        }, 500);
    };
}

// Modificar Usuarios.load() para inicializar paginación
if (typeof Usuarios !== 'undefined') {
    console.log('👥 Integrando Paginator con Usuarios...');
    const originalUsuariosLoad = Usuarios.load;
    Usuarios.load = async function() {
        await originalUsuariosLoad.call(this);
        setTimeout(() => {
            if (!Paginator.configs['usuariosTable']) {
                Paginator.init('usuariosTable', 50);
            } else {
                Paginator.refresh('usuariosTable');
            }
        }, 500);
    };
}

console.log('✅ Sistema de Paginación Universal cargado correctamente (VERSIÓN CORREGIDA)');