// Módulo de Personas
const Personas = {
    async load() {
        await this.loadPersonas();
    },
    
    async loadPersonas(search = '') {
        try {
            const endpoint = search 
                ? `/personas?busqueda=${encodeURIComponent(search)}`
                : '/personas?limit=50';
            
            const data = await API.get(endpoint);
            const tbody = document.querySelector('#personasTable tbody');
            
            if (data.personas.length === 0) {
                tbody.innerHTML = '<tr><td colspan="6" style="text-align: center;">No hay personas registradas</td></tr>';
                return;
            }
            
            tbody.innerHTML = data.personas.map(persona => `
                <tr>
                    <td>${persona.dpi}</td>
                    <td>${persona.nombres}</td>
                    <td>${persona.apellidos}</td>
                    <td>${persona.institucion || '-'}</td>
                    <td>${persona.cargo || '-'}</td>
                    <td>
                        <button class="btn btn-sm btn-primary" onclick="Personas.edit(${persona.id})">
                            ✏️ Editar
                        </button>
                    </td>
                </tr>
            `).join('');
        } catch (error) {
            console.error('Error loading personas:', error);
        }
    },
    
    async create() {
        const form = `
            <form id="formNuevaPersona">
                <div class="form-group">
                    <label>DPI (13 dígitos) *</label>
                    <input type="text" id="dpi" required pattern="[0-9]{13}" maxlength="13">
                </div>
                <div class="form-group">
                    <label>Nombres *</label>
                    <input type="text" id="nombres" required>
                </div>
                <div class="form-group">
                    <label>Apellidos *</label>
                    <input type="text" id="apellidos" required>
                </div>
                <div class="form-group">
                    <label>Institución</label>
                    <input type="text" id="institucion">
                </div>
                <div class="form-group">
                    <label>Cargo</label>
                    <input type="text" id="cargo">
                </div>
                <div class="form-group">
                    <label>Teléfono</label>
                    <input type="text" id="telefono">
                </div>
                <div class="form-group">
                    <label>Email</label>
                    <input type="email" id="email">
                </div>
                <button type="submit" class="btn btn-primary">Crear Persona</button>
            </form>
        `;
        
        showModal('Nueva Persona', form);
        
        document.getElementById('formNuevaPersona').addEventListener('submit', async (e) => {
            e.preventDefault();
            
            const data = {
                dpi: document.getElementById('dpi').value,
                nombres: document.getElementById('nombres').value,
                apellidos: document.getElementById('apellidos').value,
                institucion: document.getElementById('institucion').value || null,
                cargo: document.getElementById('cargo').value || null,
                telefono: document.getElementById('telefono').value || null,
                email: document.getElementById('email').value || null
            };
            
            try {
                await API.post('/personas/', data);
                hideModal();
                showSuccess('Persona creada exitosamente');
                this.load();
            } catch (error) {
                showError(error.message);
            }
        });
    },
    
    edit(id) {
        alert(`Editar persona ${id} - Funcionalidad pendiente`);
    }
};

// Event Listeners
document.getElementById('btnNuevaPersona').addEventListener('click', () => {
    Personas.create();
});

document.getElementById('searchPersonas').addEventListener('input', (e) => {
    const search = e.target.value;
    if (search.length >= 3 || search.length === 0) {
        Personas.loadPersonas(search);
    }
});
