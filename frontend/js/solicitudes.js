const Solicitudes = {
    personaActual: null,
    usuarioActual: null,
    ordenActual: 'desc',
    datosOriginales: [],

    async load() {
        console.log('Cargando Solicitudes...');

        this.usuarioActual = await this.obtenerUsuarioActual();

        const btnNueva = document.getElementById('btnNuevaSolicitud');
        if (btnNueva) {
            btnNueva.onclick = () => this.nuevaSolicitud();
        }

        this.verificarEstructuraTabla();
        await this.listarSolicitudes();

        // ✅ SOLO REFRESCAR SI YA ESTÁ INICIALIZADA
        if (typeof tablesInitialized !== 'undefined' && tablesInitialized.solicitudesTable) {
            console.log('🔄 Refrescando tabla de solicitudes...');
            IntegratedTableSystem.refresh('solicitudesTable');
        }
    },


    async obtenerUsuarioActual() {
        try {
            const response = await API.get('/auth/me');
            return response;
        } catch (error) {
            console.error('Error obteniendo usuario:', error);
            return { nombre_completo: 'Usuario del Sistema', rol: 'USER' };
        }
    },

    verificarEstructuraTabla() {
        let contenedor = document.getElementById('solicitudesView');
        if (!contenedor) {
            console.error('No se encontró solicitudesView');
            return;
        }

        // ✅ BUTTONS HTML TEMPLATE
        const buttonsHTML = `
            <div id="importExportButtons" style="margin-top: 1rem; display: flex; gap: 1rem; justify-content: flex-end;">
                <input type="file" id="fileImportInput" accept=".xlsx, .xls" style="display: none;" onchange="Solicitudes.procesarImportacion(this)">
                
                <button class="btn btn-outline" onclick="document.getElementById('fileImportInput').click()" title="Cargar desde Excel">
                    📥 Importar Excel
                </button>
                
                <button class="btn btn-outline" onclick="Solicitudes.exportarExcel()" title="Descargar todo">
                    📤 Exportar Datos
                </button>
            </div>
        `;

        let tabla = contenedor.querySelector('#solicitudesTable');
        if (tabla) {
            // ✅ FIX: Si la tabla existe pero los botones no, agregarlos
            if (!document.getElementById('importExportButtons')) {
                contenedor.insertAdjacentHTML('beforeend', buttonsHTML);
            }
            return;
        }

        contenedor.innerHTML = `
            <div class="view-header" style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem;">
                <div style="display: flex; align-items: center; gap: 1rem;">
                    <h1>📄 Gestión de Solicitudes VPN</h1>
                </div>
                <button id="btnNuevaSolicitud" class="btn btn-primary">➕ Ingresar</button>
            </div>
            
            <div class="card">
                <div class="card-body">
                    <div class="table-wrapper">
                        <table class="table" id="solicitudesTable">
                            <thead>
                                <tr>
                                    <th>No.</th>
                                    <th>NIP</th>
                                    <th>Oficio</th>
                                    <th>Providencia</th>
                                    <th>Fecha Recep.</th>
                                    <th>Nombre</th>
                                    <th>Estado</th>
                                    <th>Acciones</th>
                                </tr>
                            </thead>
                            <tbody>
                                <tr><td colspan="8" style="text-align: center;">Cargando...</td></tr>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
            
            <!-- ✅ BOTONES DE IMPORTAR/EXPORTAR (ABAJO) -->
            ${buttonsHTML}
        `;

        const btnNueva = document.getElementById('btnNuevaSolicitud');
        if (btnNueva) {
            btnNueva.onclick = () => this.nuevaSolicitud();
        }
    },

    // ✅ FUNCIONES DE IMPORTACIÓN/EXPORTACIÓN
    async procesarImportacion(input) {
        if (!input.files || input.files.length === 0) return;

        const file = input.files[0];
        const formData = new FormData();
        formData.append('file', file);

        // Mostrar indicador de carga
        const btnImportar = document.querySelector('button[title="Cargar desde Excel"]');
        const textoOriginal = btnImportar.innerHTML;
        btnImportar.innerHTML = '⏳ Subiendo...';
        btnImportar.disabled = true;

        try {
            const response = await fetch(`${API.BASE_URL}/data/import/excel`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${TokenStorage.get()}`
                },
                body: formData
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.detail || 'Error en la importación');
            }

            const result = await response.json();

            // Mostrar resumen
            let mensaje = `Importación completada.\n\n` +
                `Total: ${result.estadisticas.total} \n` +
                `Exitosos: ${result.estadisticas.exitosos} \n` +
                `Fallidos: ${result.estadisticas.fallidos} `;

            if (result.estadisticas.errores && result.estadisticas.errores.length > 0) {
                mensaje += `\n\nErrores(ver consola para más detalle): \n` +
                    result.estadisticas.errores.slice(0, 3).join('\n') +
                    (result.estadisticas.errores.length > 3 ? '\n...' : '');
            }

            showSuccess(mensaje);

            // Recargar tabla
            this.load();

        } catch (error) {
            console.error('Error importando:', error);
            showError(`Error: ${error.message}`);
        } finally {
            btnImportar.innerHTML = textoOriginal;
            btnImportar.disabled = false;
            input.value = ''; // Reset input
        }
    },

    async exportarExcel() {
        const btnExportar = document.querySelector('button[title="Descargar todo"]');
        const textoOriginal = btnExportar.innerHTML;
        btnExportar.innerHTML = '⏳ Generando...';
        btnExportar.disabled = true;

        try {
            const response = await fetch(`${API.BASE_URL}/data/export/excel`, {
                method: 'GET',
                headers: {
                    'Authorization': `Bearer ${TokenStorage.get()}`
                }
            });

            if (!response.ok) throw new Error('Error al exportar datos');

            // Descargar archivo
            const blob = await response.blob();
            const url = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `reporte_vpn_${new Date().toISOString().slice(0, 10)}.xlsx`;
            document.body.appendChild(a);
            a.click();
            window.URL.revokeObjectURL(url);
            document.body.removeChild(a);

        } catch (error) {
            console.error('Error exportando:', error);
            showError('Error al exportar datos. Intente nuevamente.');
        } finally {
            btnExportar.innerHTML = textoOriginal;
            btnExportar.disabled = false;
        }
    },



    async listarSolicitudes() {
        try {
            const data = await API.get('/solicitudes/?limit=3000');

            const tbody = document.querySelector('#solicitudesTable tbody');
            if (!tbody) {
                console.error('❌ No se encontró tbody');
                return;
            }

            if (!data || !data.solicitudes || data.solicitudes.length === 0) {
                tbody.innerHTML = '<tr><td colspan="8" style="text-align: center;">No hay solicitudes</td></tr>';
                return;
            }

            // ✅ Guardar datos originales
            this.datosOriginales = data.solicitudes;

            // ✅ Renderizar con el orden actual
            this.renderizarSolicitudes();

        } catch (error) {
            console.error('Error:', error);
            showError('Error al cargar solicitudes');
        }
    },

    // ✅ NUEVA FUNCIÓN: Renderizar tabla con orden actual
    renderizarSolicitudes() {
        const tbody = document.querySelector('#solicitudesTable tbody');
        if (!tbody) return;

        // ✅ Ordenar según el estado actual
        const solicitudesOrdenadas = [...this.datosOriginales].sort((a, b) => {
            if (this.ordenActual === 'desc') {
                return b.id - a.id; // Descendente: 1107, 1106, 1105...
            } else {
                return a.id - b.id; // Ascendente: 1, 2, 3...
            }
        });

        tbody.innerHTML = solicitudesOrdenadas.map(sol => {
            const tieneCarta = sol.carta_generada === true;
            const puedeEditar = !tieneCarta && !sol.acceso_id;
            const esNoPresentado = sol.estado === 'CANCELADA' && sol.comentarios_admin && sol.comentarios_admin.includes('NO_PRESENTADO');

            const esPendiente = sol.estado === 'PENDIENTE';
            const esAprobada = sol.estado === 'APROBADA';

            return `
                <tr>
                    <td><strong>${sol.id}</strong></td>
                    <td><strong>${sol.persona_nip || 'N/A'}</strong></td>
                    <td>${sol.numero_oficio || 'N/A'}</td>
                    <td>${sol.numero_providencia || 'N/A'}</td>
                    <td>${formatDate(sol.fecha_recepcion || sol.fecha_solicitud)}</td>
                    <td>${sol.persona_nombres} ${sol.persona_apellidos}</td>
                    <td>${getStatusBadge(sol.estado)}</td>
                    <td style="white-space: nowrap;">
                        <button class="btn btn-sm btn-info" onclick="Solicitudes.verDetalle(${sol.id})" title="Ver">
                            👁️
                        </button>
                        
                        ${esPendiente && !tieneCarta ? `
                            <button class="btn btn-sm btn-success" onclick="Solicitudes.crearCarta(${sol.id})" title="Crear carta">
                                📄 Carta
                            </button>
                        ` : ''}
                        
                        ${tieneCarta && esAprobada ? `
                            <button class="btn btn-sm" style="background: #10b981; color: white;" 
                                    onclick="Solicitudes.verCarta(${sol.id})" title="Ver carta">
                                ✅ Ver Carta
                            </button>
                        ` : ''}
                        
                        ${esNoPresentado ? `
                            <button class="btn btn-sm btn-primary" onclick="Solicitudes.reactivar(${sol.id})" title="Reactivar">
                                🔄
                            </button>
                        ` : ''}
                        
                        ${esPendiente && !tieneCarta && !esNoPresentado ? `
                            <button class="btn btn-sm btn-danger" onclick="Solicitudes.marcarNoPresentado(${sol.id})" title="No presentado">
                                🚫
                            </button>
                        ` : ''}
                    </td>
                </tr>
    `;
        }).join('');

        console.log(`✅ ${solicitudesOrdenadas.length} solicitudes ordenadas(${this.ordenActual.toUpperCase()})`);

        // ✅ Refrescar paginación si existe
        if (typeof Paginator !== 'undefined' && Paginator.configs['solicitudesTable']) {
            Paginator.refresh('solicitudesTable');
        }
    },

    nuevaSolicitud() {
        showModal('📝 NUEVO REGISTRO', `
    <h3> INGRESE NIP</h3>
            <form id="formBuscarNIP" style="margin-bottom: 2rem;">
                <div class="form-group">
                    <label>(Número de Identificación Policial) *</label>
                    <input type="text" id="nip" required maxlength="20" placeholder="Ej: 36250-P">
                </div>
                <button type="submit" class="btn btn-primary btn-block">🔍 Buscar</button>
            </form>
            <div id="resultadoBusqueda"></div>
`);

        document.getElementById('formBuscarNIP').addEventListener('submit', async (e) => {
            e.preventDefault();
            const nip = document.getElementById('nip').value;
            await this.buscarYMostrarPersona(nip);
        });
    },

    async buscarYMostrarPersona(nip) {
        try {
            showLoading();
            const resultado = await API.get(`/solicitudes/buscar-nip/${nip}`);
            hideLoading();

            if (resultado.existe) {
                this.personaActual = resultado;
                this.mostrarFormularioEdicion(resultado);
            } else {
                this.mostrarFormularioCreacion(nip);
            }

        } catch (error) {
            hideLoading();
            showError('Error en búsqueda: ' + error.message);
        }
    },

    mostrarFormularioEdicion(persona) {
        const resultadoDiv = document.getElementById('resultadoBusqueda');
        resultadoDiv.innerHTML = `
    <div style="background: #d1fae5; padding: 1rem; margin-bottom: 1rem; border-radius: 4px;">
                <strong>✅ Datos de la Persona</strong><br>
                ${persona.nombres} ${persona.apellidos}<br>
                NIP: ${persona.nip} | DPI: ${persona.dpi}
            </div>
            
            <h4>Verificar/Actualizar Datos</h4>
            <form id="formDatosPersona">
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                    <div class="form-group">
                        <label>Nombres</label>
                        <input type="text" value="${persona.nombres}" disabled>
                    </div>
                    <div class="form-group">
                        <label>Apellidos</label>
                        <input type="text" value="${persona.apellidos}" disabled>
                    </div>
                </div>
                
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                    <div class="form-group">
                        <label>NIP</label>
                        <input type="text" value="${persona.nip}" disabled>
                    </div>
                    <div class="form-group">
                        <label>DPI</label>
                        <input type="text" value="${persona.dpi}" disabled>
                    </div>
                </div>
                
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                    <div class="form-group">
                        <label>Email</label>
                        <input type="email" id="email" value="${persona.email || ''}">
                    </div>
                    <div class="form-group">
                        <label>Teléfono</label>
                        <input type="text" id="telefono" value="${persona.telefono || ''}">
                    </div>
                </div>
                
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                    <div class="form-group">
                        <label>Cargo/Grado</label>
                        <input type="text" id="cargo" value="${persona.cargo || ''}">
                    </div>
                    <div class="form-group">
                        <label>Institución</label>
                        <input type="text" id="institucion" value="${persona.institucion || ''}">
                    </div>
                </div>
                
                <button type="submit" class="btn btn-success btn-block">
                    ➡️ Continuar con Solicitud
                </button>
            </form>
        `;

        document.getElementById('formDatosPersona').addEventListener('submit', async (e) => {
            e.preventDefault();
            await this.actualizarYContinuar();
        });
    },

    mostrarFormularioCreacion(nip) {
        const resultadoDiv = document.getElementById('resultadoBusqueda');
        resultadoDiv.innerHTML = `
            <div style="background: #fef3c7; padding: 1rem; margin-bottom: 1rem; border-radius: 4px;">
                <strong>✨ Crear Nueva Persona</strong><br>
                NIP: ${nip}
            </div>
            
            <h4>Datos de la Persona</h4>
            <form id="formDatosPersona">
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                    <div class="form-group">
                        <label>Nombres *</label>
                        <input type="text" id="nombres" required>
                    </div>
                    <div class="form-group">
                        <label>Apellidos *</label>
                        <input type="text" id="apellidos" required>
                    </div>
                </div>
                
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                    <div class="form-group">
                        <label>NIP *</label>
                        <input type="text" id="nip" value="${nip}" readonly>
                    </div>
                    <div class="form-group">
                        <label>DPI *</label>
                        <input type="text" id="dpi" required maxlength="13" pattern="[0-9]{13}">
                    </div>
                </div>
                
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                    <div class="form-group">
                        <label>Email</label>
                        <input type="email" id="email">
                    </div>
                    <div class="form-group">
                        <label>Teléfono</label>
                        <input type="text" id="telefono">
                    </div>
                </div>
                
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                    <div class="form-group">
                        <label>Cargo/Grado</label>
                        <input type="text" id="cargo">
                    </div>
                    <div class="form-group">
                        <label>Institución</label>
                        <input type="text" id="institucion">
                    </div>
                </div>
                
                <button type="submit" class="btn btn-success btn-block">
                    ➕ Crear Persona y Continuar
                </button>
            </form>
        `;

        document.getElementById('formDatosPersona').addEventListener('submit', async (e) => {
            e.preventDefault();
            await this.crearYContinuar(nip);
        });
    },

    async actualizarYContinuar() {
        try {
            showLoading();

            const data = {
                dpi: this.personaActual.dpi,
                nip: this.personaActual.nip,
                nombres: this.personaActual.nombres,
                apellidos: this.personaActual.apellidos,
                email: document.getElementById('email').value || null,
                cargo: document.getElementById('cargo').value || null,
                telefono: document.getElementById('telefono').value || null,
                institucion: document.getElementById('institucion').value || null
            };

            await API.post('/solicitudes/persona', data);
            this.personaActual = { ...this.personaActual, ...data };

            hideLoading();
            this.mostrarFormularioSolicitud();

        } catch (error) {
            hideLoading();
            showError('Error: ' + error.message);
        }
    },

    async crearYContinuar(nip) {
        try {
            showLoading();

            const data = {
                nip: nip,
                dpi: document.getElementById('dpi').value,
                nombres: document.getElementById('nombres').value,
                apellidos: document.getElementById('apellidos').value,
                email: document.getElementById('email').value || null,
                cargo: document.getElementById('cargo').value || null,
                telefono: document.getElementById('telefono').value || null,
                institucion: document.getElementById('institucion').value || null
            };

            const response = await API.post('/solicitudes/persona', data);
            this.personaActual = {
                id: response.persona_id,
                ...data
            };

            hideLoading();
            showSuccess('Persona creada');
            this.mostrarFormularioSolicitud();

        } catch (error) {
            hideLoading();
            showError('Error: ' + error.message);
        }
    },

    mostrarFormularioSolicitud() {
        const resultadoDiv = document.getElementById('resultadoBusqueda');
        const hoy = new Date().toISOString().split('T')[0];

        resultadoDiv.innerHTML = `
            <div style="background: #d1fae5; padding: 1rem; margin-bottom: 1.5rem; border-radius: 4px;">
                <strong>✅ Datos guardados</strong><br>
                <strong>${this.personaActual.nombres} ${this.personaActual.apellidos}</strong><br>
                NIP: ${this.personaActual.nip} | DPI: ${this.personaActual.dpi}
            </div>
            
            <h3>Paso 2: Datos de la Solicitud</h3>
            <form id="formSolicitud">
                <div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 1rem;">
                    <div class="form-group">
                        <label>Número de Oficio</label>
                        <input type="text" id="numeroOficio" placeholder="Ej: 07-2025">
                    </div>
                    <div class="form-group">
                        <label>Número de Providencia</label>
                        <input type="text" id="numeroProvidencia" placeholder="Ej: 3372-2024">
                    </div>
                    <div class="form-group">
                        <label>Fecha de Recepción</label>
                        <input type="date" id="fechaRecepcion" value="${hoy}">
                    </div>
                </div>
                
                <div class="form-group">
                    <label>Tipo *</label>
                    <select id="tipoSolicitud" required>
                        <option value="NUEVA">Creación</option>
                        <option value="ACTUALIZACION">Actualización</option>
                    </select>
                </div>
                
                <div class="form-group">
                    <label>Justificación *</label>
                    <textarea id="justificacion" required rows="4"></textarea>
                </div>
                
                <button type="submit" class="btn btn-success btn-block">
                    📋 Crear Solicitud
                </button>
            </form>
        `;

        document.getElementById('formSolicitud').addEventListener('submit', async (e) => {
            e.preventDefault();
            await this.crearSolicitud();
        });
    },

    async crearSolicitud() {
        try {
            showLoading();

            const data = {
                persona_id: this.personaActual.id,
                numero_oficio: document.getElementById('numeroOficio').value || null,
                numero_providencia: document.getElementById('numeroProvidencia').value || null,
                fecha_recepcion: document.getElementById('fechaRecepcion').value || null,
                fecha_solicitud: new Date().toISOString().split('T')[0],
                tipo_solicitud: document.getElementById('tipoSolicitud').value,
                justificacion: document.getElementById('justificacion').value
            };

            await API.post('/solicitudes/', data);

            hideLoading();
            hideModal();
            showSuccess('¡Solicitud creada!');
            await this.load();

        } catch (error) {
            hideLoading();
            showError('Error: ' + error.message);
        }
    },

    async crearCarta(solicitudId) {
        if (!confirm('¿Crear carta de responsabilidad?\n\nEsto generará el PDF y creará el acceso VPN automáticamente.')) return;

        try {
            showLoading();
            const response = await API.post(`/solicitudes/${solicitudId}/crear-carta`, {});
            hideLoading();

            showSuccess(`✅ ¡Carta Creada!\n\nCarta #${response.carta_id}\nAcceso VPN #${response.acceso_id}\n\nYa puedes ver la carta y descargar el PDF`);

            await this.load();
        } catch (error) {
            hideLoading();
            showError('Error al crear carta: ' + error.message);
        }
    },

    async verCarta(solicitudId) {
        try {
            showLoading();
            const sol = await API.get(`/solicitudes/${solicitudId}`);
            hideLoading();

            // ✅ CORRECCIÓN: Usar la fecha correcta
            const fechaGeneracion = sol.carta_fecha_generacion
                ? new Date(sol.carta_fecha_generacion + 'T00:00:00')  // ✅ 
                : new Date();

            const fechaExpiracion = new Date(fechaGeneracion);
            fechaExpiracion.setFullYear(fechaExpiracion.getFullYear() + 1);

            const nombresArray = sol.persona.nombres.toLowerCase().split(' ');
            const apellidosArray = sol.persona.apellidos.toLowerCase().split(' ');
            const username = `${nombresArray[0]}.${apellidosArray[0]}`;

            const meses = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
            const dias = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];

            // ✅ CORRECCIÓN: Usar getDate() en lugar de getDay()
            const fechaTexto = `Ciudad de Guatemala, ${dias[fechaGeneracion.getDay()]}, ${fechaGeneracion.getDate()} de ${meses[fechaGeneracion.getMonth()]} de ${fechaGeneracion.getFullYear()}`;

            const nombreUsuarioSistema = this.usuarioActual?.nombre_completo || 'Usuario del Sistema';

            // CORRECCION: Mostrar fechas correctas
            console.log('📅 Fecha de generación:', fechaGeneracion);
            console.log('📅 Fecha de expiración:', fechaExpiracion);

            showModal('📄 Carta de Responsabilidad', `
                <div style="max-height: 70vh; overflow-y: auto; padding: 2rem; background: white; border: 1px solid #ccc;">
                    <div style="text-align: center; margin-bottom: 1.5rem;">
                        <h2 style="font-size: 11px; margin-bottom: 0.3rem; font-weight: bold;">CARTA DE RESPONSABILIDAD DE USO Y ACCESO POR VPN A LA RED INSTITUCIONAL DE LA</h2>
                        <h2 style="font-size: 11px; font-weight: bold;">POLICÍA NACIONAL CIVIL.</h2>
                        <p style="margin-top: 1rem; font-weight: bold; font-size: 10px;">Documento No: ${sol.numero_carta || 'N/A'}-${sol.anio_carta || 'N/A'}</p>
                    </div>
                    
                    <div style="text-align: justify; font-size: 9px; line-height: 1.4; margin-bottom: 1rem;">
                        <p>En las instalaciones que ocupa el Departamento de Operaciones de Seguridad Informática de la 
                        Subdirección General de Tecnologías de la Información y la Comunicación, se suscribe la presente 
                        CARTA DE RESPONSABILIDAD con la que EL USUARIO acepta formalmente las condiciones de uso 
                        y acceso por medio del servicio de VPN, por medio de un "usuario" y "contraseña" con los cuales se le 
                        otorga la facultad de acceder al sistema de Escritorio Policial y Sistema Solvencias de la Policía Nacional 
                        Civil, de conformidad con lo antes expuesto, declara su compromiso de cumplir con lo siguiente:</p>
                    </div>
                    
                    <div style="font-size: 9px; margin-bottom: 1rem; line-height: 1.3;">
                        <p style="margin-bottom: 0.4rem;"><strong>1.</strong> EL USUARIO y CONTRASEÑA asignados son datos intransferibles, confidenciales y personales; el titular es responsable directo de su uso.</p>
                        <p style="margin-bottom: 0.4rem;"><strong>2.</strong> EL USUARIO tiene prohibido utilizar cualquier medio digital, impreso y otros para dar a conocer información de carácter confidencial contenido en los accesos obtenidos.</p>
                        <p style="margin-bottom: 0.4rem;"><strong>3.</strong> El USUARIO se compromete a utilizar el servicio de VPN únicamente para fines expresamente laborales, la Subdirección General de Tecnologías de la Información y la Comunicación, se reserva el derecho de registrar y monitorear todas las actividades realizadas, mediante la utilización de mecanismos de auditoría y bitácoras. Los registros se considerarán pruebas fehacientes del uso en cualquier situación administrativa; y, se procederá inmediatamente al bloqueo inmediato del acceso.</p>
                        <p style="margin-bottom: 0.4rem;"><strong>4.</strong> EL USUARIO tiene la obligación de reportar inmediatamente al Departamento de Operaciones de Seguridad Informática de la Subdirección General de Tecnologías de la Información y la Comunicación en caso de pérdida o sustracción del acceso, cuando sea cambiado de destino o haya terminado su relación laboral con la institución policial.</p>
                        <p style="margin-bottom: 0.4rem;"><strong>5.</strong> EL USUARIO se compromete a renovar el acceso en el tiempo estipulado en el presente numeral, para esto gestionará en la unidad a la que pertenece para que envíen la solicitud respectiva. La vigencia del acceso es de 12 meses, siendo el sexto mes de recepción de solicitudes para renovación. La Subdirección General de Tecnologías de la Información y la Comunicación se reserva el derecho de bloquear los usuarios que no aparezcan en los oficios de solicitud recibidos, la presente disposición se encuentra sujeta a cambios sin previo aviso.</p>
                        <p style="margin-bottom: 0.4rem;"><strong>6.</strong> EL USUARIO acepta haber leído y comprendido los lineamientos de seguridad descritos en este documento y se compromete a cumplirlos en su totalidad, sin menoscabo de las obligaciones y prohibiciones establecidas en los artículos 274 "A", 274 "B", 274 "C", 274 "D", 274 "E", 274 "F", ordinal 30 del artículo 369, y 422 del Código Penal, literal F del artículo 34 establecido en el Decreto Numero 11-97 del Congreso de la República, Ley de la Policía Nacional Civil. En el entendido de que el incumplimiento a cualquiera de estos será causa de la aplicación de las sanciones correspondientes.</p>
                        <p style="margin-bottom: 0.4rem;"><strong>7.</strong> La Subdirección General de Tecnologías de la Información y la Comunicación, se reserva el derecho y la facultad para bloquear usuarios, cuando se considere o compruebe el uso inapropiado de los accesos.</p>
                    </div>
                    
                    <table style="width: 100%; border-collapse: collapse; margin-bottom: 1rem; font-size: 9px;">
                        <tr style="border: 1px solid black;">
                            <td style="padding: 6px; border: 1px solid black; font-weight: bold;">Responsable:</td>
                            <td style="padding: 6px; border: 1px solid black;">${sol.persona.nombres} ${sol.persona.apellidos}</td>
                            <td style="padding: 6px; border: 1px solid black; font-weight: bold;">Usuario:</td>
                            <td style="padding: 6px; border: 1px solid black;">${username}</td>
                        </tr>
                        <tr style="border: 1px solid black;">
                            <td style="padding: 6px; border: 1px solid black; font-weight: bold;">DPI:</td>
                            <td style="padding: 6px; border: 1px solid black;">${sol.persona.dpi}</td>
                            <td style="padding: 6px; border: 1px solid black; font-weight: bold;">Correo:</td>
                            <td style="padding: 6px; border: 1px solid black;">${sol.persona.email || ''}</td>
                        </tr>
                        <tr style="border: 1px solid black;">
                            <td style="padding: 6px; border: 1px solid black; font-weight: bold;">NIP:</td>
                            <td style="padding: 6px; border: 1px solid black;">${sol.persona.nip || 'N/A'}</td>
                            <td style="padding: 6px; border: 1px solid black; font-weight: bold;">Teléfono:</td>
                            <td style="padding: 6px; border: 1px solid black;">${sol.persona.telefono || ''}</td>
                        </tr>
                        <tr style="border: 1px solid black;">
                            <td colspan="2" style="padding: 6px; border: 1px solid black;">Subdirección General de Investigación Criminal SGIC</td>
                            <td style="padding: 6px; border: 1px solid black; font-weight: bold;">Fecha de Expiración:</td>
                            <td style="padding: 6px; border: 1px solid black;">${fechaExpiracion.toLocaleDateString('es-GT')}</td>
                        </tr>
                        <tr style="border: 1px solid black;">
                            <td colspan="2" style="padding: 6px; border: 1px solid black;">${sol.persona.institucion || 'DIPANDA'}</td>
                            <td style="padding: 6px; border: 1px solid black; font-weight: bold;">Privilegios de red:</td>
                            <td style="padding: 6px; border: 1px solid black;"></td>
                        </tr>
                        <tr style="border: 1px solid black;">
                            <td colspan="2" style="padding: 6px; border: 1px solid black;"></td>
                            <td style="padding: 6px; border: 1px solid black; font-weight: bold;">Escritorio Policial:</td>
                            <td style="padding: 6px; border: 1px solid black;">172.21.68.154</td>
                        </tr>
                    </table>
                    
                    <p style="font-size: 9px; margin-bottom: 1rem;">
                        <strong>Finalidad:</strong> Proveer un túnel VPN para permitir el acceso al sistema de Escritorio Policial y Solvencias, de la Policía Nacional Civil.
                    </p>
                    
                    <p style="font-size: 9px; margin-bottom: 2rem;">
                        ${fechaTexto}
                    </p>
                    
                    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 2rem; margin-top: 2rem;">
                        <div style="text-align: center;">
                            <div style="border-top: 1px solid black; padding-top: 0.5rem;">
                                <p style="font-size: 9px; margin-bottom: 0.2rem;">Firmo y recibo conforme</p>
                                <p style="font-size: 9px; font-weight: bold;">${sol.persona.nombres} ${sol.persona.apellidos}</p>
                            </div>
                        </div>
                        <div style="text-align: center;">
                            <div style="border-top: 1px solid black; padding-top: 0.5rem;">
                                <p style="font-size: 9px; margin-bottom: 0.2rem;">Firmo y entrego DOSI/SGTIC</p>
                                <p style="font-size: 9px; font-weight: bold;">${nombreUsuarioSistema}</p>
                            </div>
                        </div>
                    </div>
                </div>
                
                <div style="margin-top: 1.5rem; text-align: center;">
                    <button class="btn btn-primary" onclick="Solicitudes.descargarPDF(${sol.id})" style="margin-right: 1rem;">
                        📥 Descargar PDF
                    </button>
                    <button class="btn btn-outline" onclick="hideModal()">
                        Cerrar
                    </button>
                </div>
            `);

        } catch (error) {
            hideLoading();
            showError('Error: ' + error.message);
        }
    },

    async descargarPDF(solicitudId) {
        await API.downloadFile(
            `/solicitudes/${solicitudId}/descargar-carta`,
            `CARTA_RESPONSABILIDAD_${solicitudId}.pdf`
        );
        showSuccess('📥 PDF descargado exitosamente');
    },

    async marcarNoPresentado(solicitudId) {
        const motivo = prompt('Motivo:', 'No se presentó a firmar');
        if (!motivo) return;

        try {
            showLoading();
            await API.post(`/solicitudes/${solicitudId}/no-presentado`, { motivo });
            hideLoading();
            showSuccess('Marcado como "No se presentó"');
            await this.load();
        } catch (error) {
            hideLoading();
            showError('Error: ' + error.message);
        }
    },

    async reactivar(solicitudId) {
        if (!confirm('¿Reactivar esta solicitud?')) return;

        try {
            showLoading();
            await API.post(`/solicitudes/${solicitudId}/reactivar`, {});
            hideLoading();
            showSuccess('Solicitud reactivada');
            await this.load();
        } catch (error) {
            hideLoading();
            showError('Error: ' + error.message);
        }
    },

    async eliminar(solicitudId) {
        if (!confirm('⚠️ ¿ELIMINAR ESTA SOLICITUD?\n\nEsta acción no se puede deshacer.')) return;
        if (!confirm('¿Está completamente SEGURO?')) return;

        try {
            showLoading();
            await API.delete(`/solicitudes/${solicitudId}`);
            hideLoading();
            hideModal();
            showSuccess('Solicitud eliminada exitosamente');
            await this.load();
        } catch (error) {
            hideLoading();
            showError('Error: ' + error.message);
        }
    },

    async editar(solicitudId) {
        try {
            showLoading();
            const sol = await API.get(`/solicitudes/${solicitudId}`);
            hideLoading();

            showModal('✏️ Editar Solicitud', `
            <div style="max-height: 75vh; overflow-y: auto;">
                
                <!-- ✅ SECCIÓN 1: DATOS DE LA PERSONA (READ-ONLY) -->
                <div style="background: #e3f2fd; padding: 1rem; border-radius: 4px; margin-bottom: 1.5rem;">
                    <h4 style="margin-bottom: 1rem;">👤 Persona Registrada</h4>
                    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.5rem; font-size: 0.9rem;">
                        <div><strong>Nombre:</strong> ${sol.persona.nombres} ${sol.persona.apellidos}</div>
                        <div><strong>NIP:</strong> ${sol.persona.nip || 'N/A'}</div>
                        <div><strong>DPI:</strong> ${sol.persona.dpi}</div>
                        <div><strong>Institución:</strong> ${sol.persona.institucion || 'N/A'}</div>
                    </div>
                </div>
                
                <!-- ✅ SECCIÓN 2: FORMULARIO EDITABLE -->
                <form id="formEditar">
                    
                    <h4 style="margin-bottom: 1rem;">📝 Datos de la Solicitud</h4>
                    
                    <!-- Números de Oficio y Providencia -->
                    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin-bottom: 1rem;">
                        <div class="form-group">
                            <label>Número de Oficio</label>
                            <input type="text" id="numeroOficio" value="${sol.numero_oficio || ''}" 
                                   placeholder="Ej: 07-2025">
                            <small class="form-text" style="color: #6c757d; font-size: 0.85rem;">Opcional</small>
                        </div>
                        
                        <div class="form-group">
                            <label>Número de Providencia</label>
                            <input type="text" id="numeroProvidencia" value="${sol.numero_providencia || ''}" 
                                   placeholder="Ej: 3372-2024">
                            <small class="form-text" style="color: #6c757d; font-size: 0.85rem;">Opcional</small>
                        </div>
                    </div>
                    
                    <!-- Fecha de Recepción -->
                    <div class="form-group" style="margin-bottom: 1rem;">
                        <label>Fecha de Recepción</label>
                        <input type="date" id="fechaRecepcion" value="${sol.fecha_recepcion || ''}">
                        <small class="form-text" style="color: #6c757d; font-size: 0.85rem;">Fecha en que se recibió la solicitud</small>
                    </div>
                    
                    <!-- Tipo de Solicitud -->
                    <div class="form-group" style="margin-bottom: 1rem;">
                        <label>Tipo de Solicitud *</label>
                        <select id="tipoSolicitud" required style="width: 100%; padding: 0.5rem; border: 1px solid #ddd; border-radius: 4px;">
                            <option value="NUEVA" ${sol.tipo_solicitud === 'NUEVA' ? 'selected' : ''}>Creación</option>
                            <option value="RENOVACION" ${sol.tipo_solicitud === 'RENOVACION' ? 'selected' : ''}>Actualización</option>
                        </select>
                        <small class="form-text" style="color: #6c757d; font-size: 0.85rem;">¿Es un acceso nuevo o una renovación?</small>
                    </div>
                    
                    <!-- Justificación -->
                    <div class="form-group" style="margin-bottom: 1rem;">
                        <label>Justificación *</label>
                        <textarea id="justificacion" required rows="4" 
                                  style="width: 100%; padding: 0.5rem; border: 1px solid #ddd; border-radius: 4px; font-family: inherit;"
                                  placeholder="Describe el motivo de la solicitud...">${sol.justificacion}</textarea>
                        <small class="form-text" style="color: #6c757d; font-size: 0.85rem;">Mínimo 10 caracteres</small>
                    </div>
                    
                    <!-- ✅ SECCIÓN 3: DATOS DE LA PERSONA (EDITABLES) -->
                    <div style="border-top: 2px solid #e0e0e0; padding-top: 1.5rem; margin-top: 1.5rem;">
                        <h4 style="margin-bottom: 1rem;">👤 Actualizar Datos de la Persona</h4>
                        
                        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin-bottom: 1rem;">
                            <div class="form-group">
                                <label>Email</label>
                                <input type="email" id="email" value="${sol.persona.email || ''}" 
                                       placeholder="ejemplo@correo.com">
                            </div>
                            
                            <div class="form-group">
                                <label>Teléfono</label>
                                <input type="text" id="telefono" value="${sol.persona.telefono || ''}" 
                                       placeholder="12345678">
                            </div>
                        </div>
                        
                        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin-bottom: 1rem;">
                            <div class="form-group">
                                <label>Cargo/Grado</label>
                                <input type="text" id="cargo" value="${sol.persona.cargo || ''}" 
                                       placeholder="Ej: Oficial I">
                            </div>
                            
                            <div class="form-group">
                                <label>Institución</label>
                                <input type="text" id="institucion" value="${sol.persona.institucion || ''}" 
                                       placeholder="Ej: DIPANDA">
                            </div>
                        </div>
                    </div>
                    
                    <!-- Botón de Guardar -->
                    <button type="submit" class="btn btn-success btn-block" 
                            style="margin-top: 1.5rem; padding: 0.75rem; font-size: 1rem;">
                        💾 Guardar Todos los Cambios
                    </button>
                </form>
                
            </div>
        `, 'large');

            document.getElementById('formEditar').addEventListener('submit', async (e) => {
                e.preventDefault();
                await this.guardarEdicion(solicitudId, sol.persona);
            });

        } catch (error) {
            hideLoading();
            showError('Error: ' + error.message);
        }
    },

    async guardarEdicion(solicitudId, personaData) {
        try {
            showLoading();

            // ✅ 1. ACTUALIZAR DATOS DE LA SOLICITUD
            const dataSolicitud = {
                numero_oficio: document.getElementById('numeroOficio').value || null,
                numero_providencia: document.getElementById('numeroProvidencia').value || null,
                fecha_recepcion: document.getElementById('fechaRecepcion').value || null,
                tipo_solicitud: document.getElementById('tipoSolicitud').value,
                justificacion: document.getElementById('justificacion').value
            };

            console.log('📤 Enviando datos de solicitud:', dataSolicitud);
            await API.put(`/solicitudes/${solicitudId}`, dataSolicitud);

            // ✅ 2. ACTUALIZAR DATOS DE LA PERSONA
            const dataPersonaCompleta = {
                dpi: personaData.dpi,
                nip: personaData.nip,
                nombres: personaData.nombres,
                apellidos: personaData.apellidos,
                email: document.getElementById('email').value || null,
                telefono: document.getElementById('telefono').value || null,
                cargo: document.getElementById('cargo').value || null,
                institucion: document.getElementById('institucion').value || null
            };

            console.log('📤 Enviando datos de persona:', dataPersonaCompleta);
            await API.post('/solicitudes/persona', dataPersonaCompleta);

            hideLoading();
            hideModal();
            showSuccess('✅ Solicitud y datos de persona actualizados exitosamente');
            await this.load();

        } catch (error) {
            hideLoading();
            console.error('❌ Error completo:', error);
            showError('Error al guardar: ' + error.message);
        }
    },

    async verDetalle(solicitudId) {
        try {
            showLoading();
            const sol = await API.get(`/solicitudes/${solicitudId}`);
            hideLoading();

            // Verificar si el usuario es SUPERADMIN
            const esSuperadmin = this.usuarioActual?.rol === 'SUPERADMIN';

            // Verificar si tiene carta
            const tieneCarta = sol.carta !== null && sol.carta !== undefined;
            const tieneAcceso = sol.acceso !== null && sol.acceso !== undefined;

            // ✅ NUEVO: Botones de gestión de carta para SUPERADMIN
            let botonesGestionCarta = '';
            if (esSuperadmin && tieneCarta) {
                botonesGestionCarta = `
                    <div style="border-top: 2px solid #fee2e2; padding-top: 1.5rem; margin-top: 1.5rem;">
                        <h4 style="color: #991b1b; margin-bottom: 1rem;">
                            🔧 Herramientas SUPERADMIN
                        </h4>
                        
                        <div style="background: #fee2e2; padding: 1rem; border-radius: 4px; margin-bottom: 1rem;">
                            <p style="margin-bottom: 0.5rem; font-size: 0.9rem;">
                                <strong>¿Hay errores en los datos de la persona?</strong>
                            </p>
                            <p style="margin-bottom: 0; font-size: 0.85rem; color: #666;">
                                Puedes eliminar la carta, corregir los datos (nombre, DPI, NIP) 
                                y regenerarla manteniendo el mismo número (${sol.carta?.numero_carta}-${sol.carta?.anio_carta})
                            </p>
                        </div>
                        
                        <button class="btn btn-danger btn-block" 
                               onclick="Solicitudes.eliminarCartaYCorregir(${sol.carta.id}, ${sol.carta.numero_carta}, ${sol.carta.anio_carta}, ${solicitudId}); hideModal();">
                        </button>
                    </div>
                `;
            }

            // ✅ NUEVO: Opción de editar persona completa para SUPERADMIN
            let opcionEditarCompleta = '';
            if (esSuperadmin) {
                opcionEditarCompleta = `
                <button class="btn btn-warning" 
                        onclick="Solicitudes.editarPersonaCompleta(${sol.persona.id}, ${solicitudId});">
                    ✏️ Editar Todos los Datos
                </button>
                `;
            }

            showModal(`📄 Solicitud #${sol.id}`, `
                <div style="max-height: 70vh; overflow-y: auto;">
                    
                    <!-- Datos Administrativos -->
                    <div style="margin-bottom: 1.5rem;">
                        <h4 style="margin-bottom: 1rem;">📋 Datos Administrativos</h4>
                        <p style="margin-bottom: 0.5rem;"><strong>Oficio:</strong> ${sol.numero_oficio || 'N/A'}</p>
                        <p style="margin-bottom: 0.5rem;"><strong>Providencia:</strong> ${sol.numero_providencia || 'N/A'}</p>
                        <p style="margin-bottom: 0.5rem;"><strong>Fecha Recepción:</strong> ${formatDate(sol.fecha_recepcion)}</p>
                        <p style="margin-bottom: 0.5rem;"><strong>Tipo:</strong> ${sol.tipo_solicitud}</p>
                        <p style="margin-bottom: 0.5rem;"><strong>Estado:</strong> ${getStatusBadge(sol.estado)}</p>
                        <p style="margin-bottom: 0.5rem;"><strong>Justificación:</strong> ${sol.justificacion}</p>
                    </div>
                    
                    <!-- Persona -->
                    <div style="margin-bottom: 1.5rem;">
                        <h4 style="margin-bottom: 1rem;">👤 Persona</h4>
                        <p style="margin-bottom: 0.5rem;"><strong>Nombre:</strong> ${sol.persona.nombres} ${sol.persona.apellidos}</p>
                        <p style="margin-bottom: 0.5rem;"><strong>NIP:</strong> ${sol.persona.nip || 'N/A'}</p>
                        <p style="margin-bottom: 0.5rem;"><strong>DPI:</strong> ${sol.persona.dpi}</p>
                        <p style="margin-bottom: 0.5rem;"><strong>Cargo:</strong> ${sol.persona.cargo || 'N/A'}</p>
                        <p style="margin-bottom: 0.5rem;"><strong>Institución:</strong> ${sol.persona.institucion || 'N/A'}</p>
                        <p style="margin-bottom: 0.5rem;"><strong>Email:</strong> ${sol.persona.email || 'N/A'}</p>
                        <p style="margin-bottom: 0.5rem;"><strong>Teléfono:</strong> ${sol.persona.telefono || 'N/A'}</p>
                    </div>
                    
                    <!-- Carta (si existe) -->
                    ${tieneCarta ? `
                        <div style="margin-bottom: 1.5rem;">
                            <h4 style="margin-bottom: 1rem;">📄 Carta de Responsabilidad</h4>
                            <p style="margin-bottom: 0.5rem;"><strong>Número:</strong> ${sol.numero_carta}-${sol.anio_carta}</p>
                            <p style="margin-bottom: 0.5rem;"><strong>Fecha Generación:</strong> ${formatDate(sol.carta_fecha_generacion)}</p>
                        </div>
                    ` : ''}
                    
                    <!-- Acceso VPN (si existe) -->
                    ${tieneAcceso ? `
                        <div style="margin-bottom: 1.5rem;">
                            <h4 style="margin-bottom: 1rem;">🔐 Acceso VPN</h4>
                            <p style="margin-bottom: 0.5rem;"><strong>ID Acceso:</strong> ${sol.acceso.id}</p>
                            <p style="margin-bottom: 0.5rem;"><strong>Fecha de Expiración:</strong> ${formatDate(sol.acceso.fecha_fin)}</p>
                        </div>
                    ` : ''}
                    
                    ${botonesGestionCarta}
                </div>
                
                <!-- Botones de acción -->
                <div style="margin-top: 2rem; display: flex; gap: 1rem; justify-content: center; flex-wrap: wrap;">
                    ${opcionEditarCompleta}
                    
                    ${tieneCarta ? `
                        <button class="btn btn-primary" onclick="Solicitudes.verCarta(${sol.id}); hideModal();">
                            📄 Ver Carta
                        </button>
                    ` : ''}
                    
                    <button class="btn btn-outline" onclick="hideModal()">
                        Cerrar
                    </button>
                </div>
            `);

        } catch (error) {
            hideLoading();
            showError('Error: ' + error.message);
        }
    },

    // ========================================
    // NUEVA FUNCIÓN: Eliminar carta y corregir
    // ========================================

    async eliminarCartaYCorregir(cartaId, numeroCarta, anioCarta, solicitudId) {
        if (!GestionCartas) {
            showError('Módulo de gestión de cartas no disponible');
            return;
        }

        await GestionCartas.eliminarCarta(cartaId, numeroCarta, anioCarta, solicitudId);
    },

    // ========================================
    // NUEVA FUNCIÓN: Editar persona completa (SUPERADMIN)
    // ========================================

    async editarPersonaCompleta(personaId, solicitudId) {
        try {
            showLoading();

            // ✅ OBTENER DATOS COMPLETOS DE LA SOLICITUD (incluye persona completa)
            const sol = await API.get(`/solicitudes/${solicitudId}`);

            // Verificar si tiene cartas activas
            const verificacion = await API.get(`/personas/verificar-carta/${personaId}`);

            hideLoading();

            // Usar los datos de sol.persona que tiene TODOS los campos
            const persona = sol.persona;

            // Mostrar advertencia si tiene cartas activas
            let advertencia = '';
            if (verificacion.tiene_cartas_activas) {
                advertencia = `
                    <div style="background: #fee2e2; padding: 1rem; border-radius: 4px; margin-bottom: 1.5rem;">
                        <h4 style="color: #991b1b; margin-bottom: 0.5rem;">
                            ⚠️ ADVERTENCIA
                        </h4>
                        <p style="margin-bottom: 0.5rem; font-size: 0.9rem;">
                            Esta persona tiene ${verificacion.total_cartas_activas} carta(s) activa(s):
                        </p>
                        <ul style="margin-bottom: 0.5rem; padding-left: 1.5rem;">
                            ${verificacion.cartas.map(c => `
                                <li>Carta ${c.numero} (ID: ${c.carta_id})</li>
                            `).join('')}
                        </ul>
                        <p style="margin-bottom: 0; font-size: 0.85rem; color: #666;">
                            Si cambias datos, deberás regenerar la carta.
                        </p>
                    </div>
                `;
            }

            // Verificar si tiene carta generada
            const tieneCarta = sol.carta_fecha_generacion !== null && sol.carta_fecha_generacion !== undefined;

            showModal('✏️ Editar Todos los Datos (SUPERADMIN)', `
                ${advertencia}
                
                <form id="formEditarPersonaCompleta" style="max-height: 70vh; overflow-y: auto;">
                    
                    <!-- ✅ SECCIÓN 1: DATOS DE LA SOLICITUD -->
                    <div style="background: #e3f2fd; padding: 1rem; border-radius: 4px; margin-bottom: 1.5rem;">
                        <h4 style="margin-bottom: 1rem;">📋 Datos de la Solicitud</h4>
                        
                        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin-bottom: 1rem;">
                            <div class="form-group">
                                <label>Número de Oficio</label>
                                <input type="text" id="numeroOficio" value="${sol.numero_oficio || ''}" 
                                       placeholder="Ej: 5698-2028">
                            </div>
                            
                            <div class="form-group">
                                <label>Número de Providencia</label>
                                <input type="text" id="numeroProvidencia" value="${sol.numero_providencia || ''}" 
                                       placeholder="Ej: 16754-2028">
                            </div>
                        </div>
                        
                        <div class="form-group" style="margin-bottom: 1rem;">
                            <label>Fecha de Recepción</label>
                            <input type="date" id="fechaRecepcion" value="${sol.fecha_recepcion || ''}">
                        </div>
                        
                        <div class="form-group" style="margin-bottom: 1rem;">
                            <label>Tipo de Solicitud *</label>
                            <select id="tipoSolicitud" required style="width: 100%; padding: 0.5rem; border: 1px solid #ddd; border-radius: 4px;">
                                <option value="NUEVA" ${sol.tipo_solicitud === 'NUEVA' ? 'selected' : ''}>CREACION</option>
                                <option value="RENOVACION" ${sol.tipo_solicitud === 'RENOVACION' ? 'selected' : ''}>RENOVACION</option>
                            </select>
                        </div>
                        
                        <div class="form-group">
                            <label>Justificación *</label>
                            <textarea id="justificacion" required rows="3" 
                                      style="width: 100%; padding: 0.5rem; border: 1px solid #ddd; border-radius: 4px; font-family: inherit;"
                                      placeholder="Describe el motivo de la solicitud...">${sol.justificacion || ''}</textarea>
                        </div>
                    </div>
                    
                    ${tieneCarta ? `
                    <!-- ✅ SECCIÓN 2: FECHAS DE LA CARTA (si existe) -->
                    <div style="background: #fef3c7; padding: 1rem; border-radius: 4px; margin-bottom: 1.5rem;">
                        <h4 style="margin-bottom: 1rem;">📄 Fechas de la Carta</h4>
                        <p style="font-size: 0.85rem; color: #92400e; margin-bottom: 1rem;">
                            ⚠️ Solo modifica estas fechas si necesitas corregir errores de importación
                        </p>
                        
                        <div class="form-group">
                            <label>Fecha de Generación de Carta</label>
                            <input type="date" id="fechaGeneracionCarta" value="${sol.carta_fecha_generacion || ''}">
                            <small style="color: #666; font-size: 0.85rem;">Esta es la fecha de creación de la carta</small>
                        </div>
                    </div>
                    ` : ''}
                    
                    <!-- ✅ SECCIÓN 3: DATOS DE LA PERSONA -->
                    <div style="background: #f3f4f6; padding: 1rem; border-radius: 4px; margin-bottom: 1.5rem;">
                        <h4 style="margin-bottom: 1rem;">👤 Datos de la Persona</h4>
                        
                        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                            <div class="form-group">
                                <label>Nombres *</label>
                                <input type="text" id="nombres" required 
                                       value="${persona.nombres}">
                            </div>
                            
                            <div class="form-group">
                                <label>Apellidos *</label>
                                <input type="text" id="apellidos" required 
                                       value="${persona.apellidos}">
                            </div>
                        </div>
                        
                        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                            <div class="form-group">
                                <label>DPI * (13 dígitos)</label>
                                <input type="text" id="dpi" required 
                                       pattern="[0-9]{13}" maxlength="13" 
                                       value="${persona.dpi}">
                            </div>
                            
                            <div class="form-group">
                                <label>NIP</label>
                                <input type="text" id="nip" 
                                       value="${persona.nip || ''}">
                            </div>
                        </div>
                        
                        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                            <div class="form-group">
                                <label>Email</label>
                                <input type="email" id="email" 
                                       value="${persona.email || ''}">
                            </div>
                            
                            <div class="form-group">
                                <label>Teléfono</label>
                                <input type="text" id="telefono" 
                                       value="${persona.telefono || ''}">
                            </div>
                        </div>
                        
                        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                            <div class="form-group">
                                <label>Cargo/Grado</label>
                                <input type="text" id="cargo" 
                                       value="${persona.cargo || ''}">
                            </div>
                            
                            <div class="form-group">
                                <label>Institución</label>
                                <input type="text" id="institucion" 
                                       value="${persona.institucion || ''}">
                            </div>
                        </div>
                    </div>
                    
                    <button type="submit" class="btn btn-success btn-block">
                        💾 Guardar Todos los Cambios
                    </button>
                </form>
            `, 'large');

            document.getElementById('formEditarPersonaCompleta').addEventListener('submit', async (e) => {
                e.preventDefault();
                await this.guardarEdicionCompletaPersona(personaId, solicitudId, tieneCarta);
            });

        } catch (error) {
            hideLoading();
            showError('Error: ' + error.message);
        }
    },

    async guardarEdicionCompletaPersona(personaId, solicitudId, tieneCarta) {
        try {
            showLoading();

            let personaActualizada = false;
            let solicitudActualizada = false;
            let cartaActualizada = false;

            // ✅ 1. ACTUALIZAR DATOS DE LA PERSONA (si hay cambios)
            try {
                const dataPersona = {
                    nombres: document.getElementById('nombres').value.trim(),
                    apellidos: document.getElementById('apellidos').value.trim(),
                    dpi: document.getElementById('dpi').value.trim(),
                    nip: document.getElementById('nip').value.trim() || null,
                    email: document.getElementById('email').value.trim() || null,
                    cargo: document.getElementById('cargo').value.trim() || null,
                    telefono: document.getElementById('telefono').value.trim() || null,
                    institucion: document.getElementById('institucion').value.trim() || null
                };

                // Validar DPI
                if (!/^\d{13}$/.test(dataPersona.dpi)) {
                    throw new Error('El DPI debe tener exactamente 13 dígitos');
                }

                await API.put(`/personas/editar-completa/${personaId}`, dataPersona);
                personaActualizada = true;
            } catch (error) {
                // Si el error es "No hay cambios", continuar silenciosamente
                if (!error.message.includes('No hay cambios')) {
                    throw error; // Re-lanzar si es otro tipo de error
                }
            }

            // ✅ 2. ACTUALIZAR DATOS DE LA SOLICITUD
            try {
                const dataSolicitud = {
                    numero_oficio: document.getElementById('numeroOficio').value.trim() || null,
                    numero_providencia: document.getElementById('numeroProvidencia').value.trim() || null,
                    fecha_recepcion: document.getElementById('fechaRecepcion').value || null,
                    tipo_solicitud: document.getElementById('tipoSolicitud').value,
                    justificacion: document.getElementById('justificacion').value.trim()
                };

                await API.put(`/solicitudes/${solicitudId}`, dataSolicitud);
                solicitudActualizada = true;
            } catch (error) {
                // Silenciosamente continuar con carta si falla solicitud
                if (!error.message.includes('No hay cambios')) {
                    throw error;
                }
            }

            // ✅ 3. ACTUALIZAR FECHAS DE LA CARTA (si existe)
            if (tieneCarta) {
                try {
                    const fechaGeneracionCarta = document.getElementById('fechaGeneracionCarta').value;
                    if (fechaGeneracionCarta) {
                        await API.put(`/solicitudes/${solicitudId}/actualizar-fecha-carta`, {
                            fecha_generacion: fechaGeneracionCarta
                        });
                        cartaActualizada = true;
                    }
                } catch (error) {
                    // Silenciosamente manejar error de carta
                    if (!error.message.includes('No hay cambios')) {
                        throw error;
                    }
                }
            }

            hideLoading();

            // Mostrar mensaje según lo que se actualizó
            if (personaActualizada || solicitudActualizada || cartaActualizada) {
                const partes = [];
                if (personaActualizada) partes.push('persona');
                if (solicitudActualizada) partes.push('solicitud');
                if (cartaActualizada) partes.push('carta');

                showSuccess(`✅ Datos actualizados: ${partes.join(', ')}`);

                // Recargar la tabla
                await this.load();

                // Cerrar modal de edición
                hideModal();
            } else {
                hideModal();
                showSuccess('ℹ️ No se detectaron cambios');
            }

        } catch (error) {
            hideLoading();
            // Solo mostrar error si no es "No hay cambios"
            if (!error.message.includes('No hay cambios')) {
                showError('Error al guardar: ' + error.message);
            }
        }
    }

};