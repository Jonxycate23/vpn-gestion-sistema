// 🔍 BUSCADOR UNIVERSAL PARA SOLICITUDES Y ACCESOS VPN
// 📂 Ubicación: frontend/js/buscador.js
// ✅ Busca por NIP, DPI, Nombre, Usuario, Oficio, Providencia

const BuscadorVPN = {
    // Función para agregar el buscador a Solicitudes
    agregarBuscadorSolicitudes() {
        const container = document.getElementById('solicitudesView');
        if (!container) return;

        // Verificar si ya existe el buscador
        if (container.querySelector('.search-container')) return;

        const header = container.querySelector('.view-header');
        if (!header) return;

        // Insertar buscador después del header
        const searchHTML = `
            <div class="search-container" style="margin-bottom: 1.5rem; display: flex; gap: 1rem; align-items: center;">
                <div style="flex: 1; position: relative;">
                    <input 
                        type="text" 
                        id="searchSolicitudes" 
                        placeholder="Buscar por nombre, DPI, NIP, oficio, providencia..." 
                        style="width: 100%; padding: 0.75rem 1rem 0.75rem 2.5rem; border: 1px solid #ddd; border-radius: 8px; font-size: 0.95rem;"
                    >
                    <span style="position: absolute; left: 0.75rem; top: 50%; transform: translateY(-50%); color: #666;">🔍</span>
                </div>
                <select id="filterEstadoSolicitudes" style="padding: 0.75rem; border: 1px solid #ddd; border-radius: 8px; min-width: 150px;">
                    <option value="">Todos los estados</option>
                    <option value="APROBADA">✅ Aprobadas</option>
                    <option value="RECHAZADA">❌ Rechazadas</option>
                    <option value="CANCELADA">🚫 Canceladas</option>
                </select>
                <button id="btnLimpiarSolicitudes" class="btn btn-outline" style="white-space: nowrap;">
                    🔄 Limpiar
                </button>
            </div>
        `;

        header.insertAdjacentHTML('afterend', searchHTML);

        // Event listeners
        document.getElementById('searchSolicitudes').addEventListener('input', (e) => {
            this.filtrarSolicitudes(e.target.value, document.getElementById('filterEstadoSolicitudes').value);
        });

        document.getElementById('filterEstadoSolicitudes').addEventListener('change', (e) => {
            this.filtrarSolicitudes(document.getElementById('searchSolicitudes').value, e.target.value);
        });

        document.getElementById('btnLimpiarSolicitudes').addEventListener('click', () => {
            document.getElementById('searchSolicitudes').value = '';
            document.getElementById('filterEstadoSolicitudes').value = '';
            this.filtrarSolicitudes('', '');
        });
    },

    // Función para agregar el buscador a Accesos
    agregarBuscadorAccesos() {
        const container = document.getElementById('accesosView');
        if (!container) return;

        // Verificar si ya existe el buscador
        if (container.querySelector('.search-container')) return;

        const header = container.querySelector('.view-header');
        if (!header) return;

        // Insertar buscador después del header
        const searchHTML = `
            <div class="search-container" style="margin-bottom: 1.5rem; display: flex; gap: 1rem; align-items: center;">
                <div style="flex: 1; position: relative;">
                    <input 
                        type="text" 
                        id="searchAccesos" 
                        placeholder="Buscar por nombre, DPI, NIP, usuario VPN..." 
                        style="width: 100%; padding: 0.75rem 1rem 0.75rem 2.5rem; border: 1px solid #ddd; border-radius: 8px; font-size: 0.95rem;"
                    >
                    <span style="position: absolute; left: 0.75rem; top: 50%; transform: translateY(-50%); color: #666;">🔍</span>
                </div>
                <select id="filterEstadoAccesos" style="padding: 0.75rem; border: 1px solid #ddd; border-radius: 8px; min-width: 150px;">
                    <option value="">Todos los estados</option>
                    <option value="ACTIVO">✅ Activos</option>
                    <option value="POR_VENCER">⚠️ Por vencer</option>
                    <option value="VENCIDO">❌ Vencidos</option>
                </select>
                <select id="filterBloqueoAccesos" style="padding: 0.75rem; border: 1px solid #ddd; border-radius: 8px; min-width: 150px;">
                    <option value="">Todos</option>
                    <option value="DESBLOQUEADO">🔓 Desbloqueados</option>
                    <option value="BLOQUEADO">🔒 Bloqueados</option>
                </select>
                <button id="btnLimpiarAccesos" class="btn btn-outline" style="white-space: nowrap;">
                    🔄 Limpiar
                </button>
            </div>
        `;

        header.insertAdjacentHTML('afterend', searchHTML);

        // Event listeners
        document.getElementById('searchAccesos').addEventListener('input', (e) => {
            this.filtrarAccesos(
                e.target.value, 
                document.getElementById('filterEstadoAccesos').value,
                document.getElementById('filterBloqueoAccesos').value
            );
        });

        document.getElementById('filterEstadoAccesos').addEventListener('change', (e) => {
            this.filtrarAccesos(
                document.getElementById('searchAccesos').value, 
                e.target.value,
                document.getElementById('filterBloqueoAccesos').value
            );
        });

        document.getElementById('filterBloqueoAccesos').addEventListener('change', (e) => {
            this.filtrarAccesos(
                document.getElementById('searchAccesos').value, 
                document.getElementById('filterEstadoAccesos').value,
                e.target.value
            );
        });

        document.getElementById('btnLimpiarAccesos').addEventListener('click', () => {
            document.getElementById('searchAccesos').value = '';
            document.getElementById('filterEstadoAccesos').value = '';
            document.getElementById('filterBloqueoAccesos').value = '';
            this.filtrarAccesos('', '', '');
        });
    },

    // Filtrar solicitudes
    filtrarSolicitudes(searchTerm, estadoFilter) {
        const tbody = document.querySelector('#solicitudesTable tbody');
        if (!tbody) return;

        const rows = tbody.querySelectorAll('tr');
        const term = searchTerm.toLowerCase().trim();
        let visibleCount = 0;

        rows.forEach(row => {
            // Obtener el contenido de todas las celdas
            const cells = row.querySelectorAll('td');
            if (cells.length === 0) return; // Skip header or empty rows

            const nip = cells[1]?.textContent.toLowerCase() || '';
            const oficio = cells[2]?.textContent.toLowerCase() || '';
            const providencia = cells[3]?.textContent.toLowerCase() || '';
            const nombre = cells[5]?.textContent.toLowerCase() || '';
            const estadoHTML = cells[6]?.innerHTML || '';
            
            // Extraer el DPI del nombre completo si está visible
            const dpi = nombre.match(/\d{13}/) ? nombre.match(/\d{13}/)[0] : '';

            // Determinar el estado actual de la fila
            let estadoActual = '';
            if (estadoHTML.includes('APROBADA')) estadoActual = 'APROBADA';
            else if (estadoHTML.includes('RECHAZADA')) estadoActual = 'RECHAZADA';
            else if (estadoHTML.includes('CANCELADA')) estadoActual = 'CANCELADA';

            // Verificar si coincide con el término de búsqueda
            const matchSearch = !term || 
                nip.includes(term) || 
                oficio.includes(term) || 
                providencia.includes(term) || 
                nombre.includes(term) ||
                dpi.includes(term);

            // Verificar si coincide con el filtro de estado
            const matchEstado = !estadoFilter || estadoActual === estadoFilter;

            // Mostrar u ocultar fila
            if (matchSearch && matchEstado) {
                row.style.display = '';
                visibleCount++;
            } else {
                row.style.display = 'none';
            }
        });

        // Mostrar mensaje si no hay resultados
        this.mostrarMensajeNoResultados('solicitudesTable', visibleCount, term || estadoFilter);
    },

    // Filtrar accesos
    filtrarAccesos(searchTerm, estadoFilter, bloqueoFilter) {
        const tbody = document.querySelector('#accesosTable tbody');
        if (!tbody) return;

        const rows = tbody.querySelectorAll('tr');
        const term = searchTerm.toLowerCase().trim();
        let visibleCount = 0;

        rows.forEach(row => {
            const cells = row.querySelectorAll('td');
            if (cells.length === 0) return;

            const nip = cells[0]?.textContent.toLowerCase() || '';
            const nombre = cells[1]?.textContent.toLowerCase() || '';
            const usuario = cells[2]?.textContent.toLowerCase() || '';
            const estadoHTML = cells[5]?.innerHTML || '';
            const bloqueoHTML = cells[7]?.innerHTML || '';

            // Determinar estado de vigencia
            let estadoActual = '';
            if (estadoHTML.includes('ACTIVO')) estadoActual = 'ACTIVO';
            else if (estadoHTML.includes('POR_VENCER')) estadoActual = 'POR_VENCER';
            else if (estadoHTML.includes('VENCIDO')) estadoActual = 'VENCIDO';

            // Determinar estado de bloqueo
            let bloqueoActual = '';
            if (bloqueoHTML.includes('BLOQUEADO')) bloqueoActual = 'BLOQUEADO';
            else if (bloqueoHTML.includes('DESBLOQUEADO')) bloqueoActual = 'DESBLOQUEADO';

            // Verificar coincidencias
            const matchSearch = !term || 
                nip.includes(term) || 
                nombre.includes(term) || 
                usuario.includes(term);

            const matchEstado = !estadoFilter || estadoActual === estadoFilter;
            const matchBloqueo = !bloqueoFilter || bloqueoActual === bloqueoFilter;

            // Mostrar u ocultar
            if (matchSearch && matchEstado && matchBloqueo) {
                row.style.display = '';
                visibleCount++;
            } else {
                row.style.display = 'none';
            }
        });

        // Mostrar mensaje si no hay resultados
        this.mostrarMensajeNoResultados('accesosTable', visibleCount, term || estadoFilter || bloqueoFilter);
    },

    // Mostrar mensaje cuando no hay resultados
    mostrarMensajeNoResultados(tableId, count, filterActive) {
        const tbody = document.querySelector(`#${tableId} tbody`);
        if (!tbody) return;

        // Remover mensaje anterior si existe
        const existingMsg = tbody.querySelector('.no-results-row');
        if (existingMsg) existingMsg.remove();

        // Si no hay resultados y hay un filtro activo, mostrar mensaje
        if (count === 0 && filterActive) {
            const colCount = tbody.querySelector('tr')?.querySelectorAll('td').length || 9;
            const noResultsRow = document.createElement('tr');
            noResultsRow.className = 'no-results-row';
            noResultsRow.innerHTML = `
                <td colspan="${colCount}" style="text-align: center; padding: 2rem; color: #666;">
                    🔍 No se encontraron resultados con los criterios de búsqueda
                </td>
            `;
            tbody.appendChild(noResultsRow);
        }
    }
};

// ========================================
// INTEGRACIÓN CON SOLICITUDES Y ACCESOS
// ========================================

// Modificar la función load de Solicitudes
const SolicitudesOriginalLoad = Solicitudes.load;
Solicitudes.load = async function() {
    await SolicitudesOriginalLoad.call(this);
    BuscadorVPN.agregarBuscadorSolicitudes();
};

// Modificar la función load de Accesos
const AccesosOriginalLoad = Accesos.load;
Accesos.load = async function() {
    await AccesosOriginalLoad.call(this);
    BuscadorVPN.agregarBuscadorAccesos();
};

console.log('✅ Buscador VPN cargado correctamente');