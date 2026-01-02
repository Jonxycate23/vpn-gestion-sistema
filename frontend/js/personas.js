const Personas = {
    async buscarPorDPI(dpi) {
        try {
            const data = await API.get(`/personas/buscar-dpi/${dpi}`);
            return data;
        } catch (error) {
            console.error('Error buscando DPI:', error);
            return {existe: false};
        }
    },
    
    async crearNuevaConBusqueda() {
        const form = `
            <form id="formNuevaPersona">
                <div class="form-group">
                    <label>DPI (13 dígitos) *</label>
                    <input type="text" id="dpi" required pattern="[0-9]{13}" maxlength="13">
                    <small id="dpiStatus" class="form-text"></small>
                </div>
                
                <div id="datosPersona" style="display: none;">
                    <h4>Datos de la Persona</h4>
                    <div id="datosExistentes" style="display: none;">
                        <div class="alert alert-info">
                            <strong>Persona encontrada!</strong><br>
                            Puedes editar los siguientes campos:
                        </div>
                    </div>
                    
                    <div class="form-group">
                        <label>Nombres * (no editable si existe)</label>
                        <input type="text" id="nombres" required readonly>
                    </div>
                    <div class="form-group">
                        <label>Apellidos * (no editable si existe)</label>
                        <input type="text" id="apellidos" required readonly>
                    </div>
                    <div class="form-group">
                        <label>Email (editable)</label>
                        <input type="email" id="email">
                    </div>
                    <div class="form-group">
                        <label>Cargo / Grado (editable)</label>
                        <input type="text" id="cargo">
                    </div>
                    <div class="form-group">
                        <label>Teléfono (editable)</label>
                        <input type="text" id="telefono">
                    </div>
                    <div class="form-group">
                        <label>Procedencia / Destino (editable)</label>
                        <input type="text" id="institucion">
                    </div>
                    
                    <button type="submit" class="btn btn-primary">
                        Guardar y Continuar
                    </button>
                </div>
            </form>
        `;
        
        showModal('Nueva Solicitud - Paso 1: Buscar Persona', form);
        
        // Event listener para búsqueda automática por DPI
        document.getElementById('dpi').addEventListener('blur', async function() {
            const dpi = this.value;
            if (dpi.length === 13) {
                const resultado = await Personas.buscarPorDPI(dpi);
                
                const datosPersona = document.getElementById('datosPersona');
                const datosExistentes = document.getElementById('datosExistentes');
                const statusDiv = document.getElementById('dpiStatus');
                
                datosPersona.style.display = 'block';
                
                if (resultado.existe) {
                    // Persona existe - autocompletar datos
                    datosExistentes.style.display = 'block';
                    statusDiv.textContent = '✅ Datos de la Persona';
                    statusDiv.style.color = 'green';
                    
                    document.getElementById('nombres').value = resultado.nombres;
                    document.getElementById('apellidos').value = resultado.apellidos;
                    document.getElementById('email').value = resultado.email || '';
                    document.getElementById('cargo').value = resultado.cargo || '';
                    document.getElementById('telefono').value = resultado.telefono || '';
                    document.getElementById('institucion').value = resultado.institucion || '';
                    
                    // Nombres y apellidos no editables
                    document.getElementById('nombres').setAttribute('readonly', true);
                    document.getElementById('apellidos').setAttribute('readonly', true);
                } else {
                    // Persona no existe - permitir crear nueva
                    datosExistentes.style.display = 'none';
                    statusDiv.textContent = '✨ DPI no encontrado - Creando nueva persona';
                    statusDiv.style.color = 'blue';
                    
                    // Limpiar campos
                    document.getElementById('nombres').value = '';
                    document.getElementById('apellidos').value = '';
                    document.getElementById('email').value = '';
                    document.getElementById('cargo').value = '';
                    document.getElementById('telefono').value = '';
                    document.getElementById('institucion').value = '';
                    
                    // Permitir editar nombres y apellidos
                    document.getElementById('nombres').removeAttribute('readonly');
                    document.getElementById('apellidos').removeAttribute('readonly');
                }
            }
        });
        
        // Submit form
        document.getElementById('formNuevaPersona').addEventListener('submit', async (e) => {
            e.preventDefault();
            
            const data = {
                dpi: document.getElementById('dpi').value,
                nombres: document.getElementById('nombres').value,
                apellidos: document.getElementById('apellidos').value,
                email: document.getElementById('email').value || null,
                cargo: document.getElementById('cargo').value || null,
                telefono: document.getElementById('telefono').value || null,
                institucion: document.getElementById('institucion').value || null
            };
            
            try {
                // Guardar persona (crear o actualizar)
                await API.post('/personas/', data);
                hideModal();
                showSuccess('Datos guardados exitosamente');
                
                // Continuar con la solicitud
                Solicitudes.crearNueva(data.dpi);
            } catch (error) {
                showError(error.message);
            }
        });
    }
};