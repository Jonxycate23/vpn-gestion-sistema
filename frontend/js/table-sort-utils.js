// ORDENAMIENTO DE TABLAS
const TableSorter = {
    // Estado actual de ordenamiento por tabla
    sortStates: {},
    
    /**
     * Inicializar ordenamiento en una tabla
     * @param {string} tableId - ID de la tabla
     * @param {string} defaultColumn - Columna por defecto (ej: 'id')
     * @param {string} defaultOrder - Orden por defecto ('asc' o 'desc')
     */
    init(tableId, defaultColumn = 'id', defaultOrder = 'asc') {
        const table = document.getElementById(tableId);
        if (!table) {
            console.error(`Tabla ${tableId} no encontrada`);
            return;
        }
        
        // Inicializar estado
        this.sortStates[tableId] = {
            column: defaultColumn,
            order: defaultOrder
        };
        
        // Agregar eventos a los headers
        const headers = table.querySelectorAll('thead th');
        headers.forEach((header, index) => {
            const columnName = header.dataset.sort || this.getColumnName(index);
            
            // Solo agregar sort si la columna es ordenable
            if (columnName !== 'actions') {
                header.style.cursor = 'pointer';
                header.style.userSelect = 'none';
                header.style.position = 'relative';
                header.dataset.sort = columnName;
                
                // Agregar indicador de ordenamiento
                const indicator = document.createElement('span');
                indicator.className = 'sort-indicator';
                indicator.innerHTML = '⇅';
                indicator.style.marginLeft = '0.5rem';
                indicator.style.opacity = '0.3';
                header.appendChild(indicator);
                
                header.addEventListener('click', () => {
                    this.sortTable(tableId, columnName);
                });
            }
        });
        
        // Aplicar ordenamiento inicial
        this.sortTable(tableId, defaultColumn, true);
    },
    
    /**
     * Ordenar tabla por columna
     */
    sortTable(tableId, column, skipToggle = false) {
        const table = document.getElementById(tableId);
        if (!table) return;
        
        const tbody = table.querySelector('tbody');
        if (!tbody) return;
        
        const state = this.sortStates[tableId];
        
        // Toggle orden si es la misma columna
        if (!skipToggle && state.column === column) {
            state.order = state.order === 'asc' ? 'desc' : 'asc';
        } else {
            state.column = column;
            if (!skipToggle) {
                state.order = 'asc';
            }
        }
        
        // Actualizar indicadores visuales
        this.updateSortIndicators(table, column, state.order);
        
        // Obtener filas (excepto las vacías o de mensaje)
        const rows = Array.from(tbody.querySelectorAll('tr')).filter(row => {
            const firstCell = row.querySelector('td');
            if (!firstCell) return false;
            const text = firstCell.textContent.trim();
            return text !== 'Cargando...' && 
                   text !== 'No hay datos' && 
                   !text.includes('No se encontraron') &&
                   row.cells.length > 1;
        });
        
        if (rows.length === 0) return;
        
        // Determinar índice de columna
        const headers = Array.from(table.querySelectorAll('thead th'));
        const columnIndex = headers.findIndex(h => h.dataset.sort === column);
        
        if (columnIndex === -1) return;
        
        // Ordenar filas
        rows.sort((a, b) => {
            const cellA = a.cells[columnIndex];
            const cellB = b.cells[columnIndex];
            
            if (!cellA || !cellB) return 0;
            
            let valueA = this.getCellValue(cellA);
            let valueB = this.getCellValue(cellB);
            
            // Comparar
            let comparison = 0;
            
            // Comparación numérica
            if (!isNaN(valueA) && !isNaN(valueB)) {
                comparison = parseFloat(valueA) - parseFloat(valueB);
            }
            // Comparación de fechas
            else if (this.isDate(valueA) && this.isDate(valueB)) {
                const dateA = new Date(valueA);
                const dateB = new Date(valueB);
                comparison = dateA - dateB;
            }
            // Comparación de texto
            else {
                comparison = valueA.localeCompare(valueB, 'es', { numeric: true });
            }
            
            return state.order === 'asc' ? comparison : -comparison;
        });
        
        // Reordenar en el DOM
        rows.forEach(row => tbody.appendChild(row));
        
        // Efecto visual de reordenamiento
        this.highlightReorder(tbody);
    },
    
    /**
     * Obtener valor limpio de una celda
     */
    getCellValue(cell) {
        // Si la celda tiene un badge de estado, extraer el texto
        const badge = cell.querySelector('.status-badge');
        if (badge) {
            return badge.textContent.trim();
        }
        
        // Si tiene un strong, usar ese valor
        const strong = cell.querySelector('strong');
        if (strong) {
            return strong.textContent.trim();
        }
        
        // Si tiene un code, usar ese valor
        const code = cell.querySelector('code');
        if (code) {
            return code.textContent.trim();
        }
        
        // Valor directo
        return cell.textContent.trim();
    },
    
    /**
     * Verificar si un valor es una fecha
     */
    isDate(value) {
        if (!value || value === '-' || value === 'N/A') return false;
        
        // Formato DD/MM/YYYY
        const datePattern = /^\d{2}\/\d{2}\/\d{4}$/;
        if (datePattern.test(value)) return true;
        
        // Formato ISO
        const isoPattern = /^\d{4}-\d{2}-\d{2}/;
        if (isoPattern.test(value)) return true;
        
        return false;
    },
    
    /**
     * Obtener nombre de columna por índice
     */
    getColumnName(index) {
        const names = ['id', 'col1', 'col2', 'col3', 'col4', 'col5', 'col6', 'col7', 'col8', 'col9'];
        return names[index] || `col${index}`;
    },
    
    /**
     * Actualizar indicadores visuales de ordenamiento
     */
    updateSortIndicators(table, activeColumn, order) {
        const headers = table.querySelectorAll('thead th');
        
        headers.forEach(header => {
            const indicator = header.querySelector('.sort-indicator');
            if (!indicator) return;
            
            const column = header.dataset.sort;
            
            if (column === activeColumn) {
                indicator.style.opacity = '1';
                indicator.innerHTML = order === 'asc' ? '▲' : '▼';
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
     * Efecto visual de reordenamiento
     */
    highlightReorder(tbody) {
        tbody.style.transition = 'opacity 0.2s';
        tbody.style.opacity = '0.7';
        setTimeout(() => {
            tbody.style.opacity = '1';
        }, 200);
    },
    
    /**
     * Resetear ordenamiento a valores por defecto
     */
    reset(tableId, defaultColumn = 'id', defaultOrder = 'asc') {
        this.sortStates[tableId] = {
            column: defaultColumn,
            order: defaultOrder
        };
        this.sortTable(tableId, defaultColumn, true);
    }
};

// ========================================
// INTEGRACIÓN AUTOMÁTICA CON TABLAS EXISTENTES
// ========================================

// Esperar a que el DOM esté listo
document.addEventListener('DOMContentLoaded', () => {
    // Inicializar después de un pequeño delay para asegurar que las tablas estén cargadas
    setTimeout(() => {
        initAllTables();
    }, 1000);
});

function initAllTables() {
    // Dashboard: Tabla de próximos a vencer
    const dashboardTable = document.getElementById('dashboardTable');
    if (dashboardTable) {
        addSortableHeaders('dashboardTable', [
            { index: 0, name: 'nip' },
            { index: 1, name: 'nombre' },
            { index: 2, name: 'institucion' },
            { index: 3, name: 'dias' },
            { index: 4, name: 'fecha' }
        ]);
        TableSorter.init('dashboardTable', 'dias', 'asc'); // Ordenar por días restantes ascendente
    }
    
    // Solicitudes: Tabla principal
    const solicitudesTable = document.getElementById('solicitudesTable');
    if (solicitudesTable) {
        addSortableHeaders('solicitudesTable', [
            { index: 0, name: 'id' },
            { index: 1, name: 'nip' },
            { index: 2, name: 'oficio' },
            { index: 3, name: 'providencia' },
            { index: 4, name: 'fecha' },
            { index: 5, name: 'nombre' },
            { index: 6, name: 'estado' }
        ]);
        TableSorter.init('solicitudesTable', 'id', 'desc'); // Ordenar por ID descendente (más recientes primero)
    }
    
    // Accesos: Tabla principal
    const accesosTable = document.getElementById('accesosTable');
    if (accesosTable) {
        addSortableHeaders('accesosTable', [
            { index: 0, name: 'nip' },
            { index: 1, name: 'nombre' },
            { index: 2, name: 'usuario' },
            { index: 3, name: 'fecha_inicio' },
            { index: 4, name: 'fecha_fin' },
            { index: 5, name: 'estado' },
            { index: 6, name: 'dias' },
            { index: 7, name: 'bloqueo' }
        ]);
        TableSorter.init('accesosTable', 'dias', 'asc'); // Ordenar por días restantes ascendente
    }
}

/**
 * Agregar atributos data-sort a los headers de una tabla
 */
function addSortableHeaders(tableId, columns) {
    const table = document.getElementById(tableId);
    if (!table) return;
    
    const headers = table.querySelectorAll('thead th');
    columns.forEach(col => {
        if (headers[col.index]) {
            headers[col.index].dataset.sort = col.name;
        }
    });
}

// ========================================
// BOTONES DE ORDENAMIENTO RÁPIDO
// ========================================

/**
 * Agregar botones de ordenamiento rápido encima de una tabla
 */
function addQuickSortButtons(tableId, containerId) {
    const container = document.getElementById(containerId);
    if (!container) return;
    
    const buttonsHTML = `
        <div class="sort-buttons" style="margin-bottom: 1rem; display: flex; gap: 0.5rem; align-items: center;">
            <span style="font-weight: 600; color: #666; font-size: 0.9rem;">Ordenar:</span>
            <button class="btn btn-sm btn-outline" onclick="TableSorter.sortTable('${tableId}', 'id'); TableSorter.sortStates['${tableId}'].order = 'asc';">
                🔢 ID ↑
            </button>
            <button class="btn btn-sm btn-outline" onclick="TableSorter.sortTable('${tableId}', 'id'); TableSorter.sortStates['${tableId}'].order = 'desc';">
                🔢 ID ↓
            </button>
            <button class="btn btn-sm btn-outline" onclick="TableSorter.sortTable('${tableId}', 'nombre'); TableSorter.sortStates['${tableId}'].order = 'asc';">
                👤 Nombre A-Z
            </button>
            <button class="btn btn-sm btn-outline" onclick="TableSorter.sortTable('${tableId}', 'fecha'); TableSorter.sortStates['${tableId}'].order = 'asc';">
                📅 Fecha ↑
            </button>
            <button class="btn btn-sm btn-outline" onclick="TableSorter.sortTable('${tableId}', 'fecha'); TableSorter.sortStates['${tableId}'].order = 'desc';">
                📅 Fecha ↓
            </button>
        </div>
    `;
    
    container.insertAdjacentHTML('afterbegin', buttonsHTML);
}


