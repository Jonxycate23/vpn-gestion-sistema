// GESTIÓN DE CARTAS - ELIMINAR Y REGENERAR (SOLO SUPERADMIN)
const GestionCartas = {
    
    /**
     * Verificar si el usuario es SUPERADMIN
     */
    esSuperadmin() {
        const user = UserStorage.get();
        return user && user.rol === 'SUPERADMIN';
    },
    
    /**
     * Eliminar una carta (SOLO SUPERADMIN)
     */
    async eliminarCarta(cartaId, numeroCarta, anioCarta, solicitudId) {
        if (!this.esSuperadmin()) {
            showError('⛔ Solo SUPERADMIN puede eliminar cartas');
            return;
        }
        
        // Confirmación doble
        const confirmar1 = await CustomConfirm.show({
            title: '⚠️ Eliminar Carta de Responsabilidad',
            message: `¿Estás seguro de eliminar la carta ${numeroCarta}-${anioCarta}?\n\nEsta acción:\n• Eliminará el acceso VPN\n• Cambiará la solicitud a PENDIENTE\n• MANTENDRÁ el número de carta para regenerar`,
            type: 'warning',
            confirmText: 'Sí, continuar',
            cancelText: 'Cancelar'
        });
        
        if (!confirmar1) return;
        
        const confirmar2 = await CustomConfirm.show({
            title: '🚨 Confirmación Final',
            message: `¿REALMENTE deseas eliminar la carta ${numeroCarta}-${anioCarta}?\n\nAsegúrate de haber verificado los datos correctos antes de regenerar.`,
            type: 'danger',
            confirmText: 'Sí, eliminar',
            cancelText: 'Cancelar'
        });
        
        if (!confirmar2) return;
        
        try {
            showLoading();
            
            await API.delete(`/cartas/${cartaId}`);
            
            hideLoading();
            
            // Mostrar confirmación y opciones
            showModal('✅ Carta Eliminada', `
                <div style="background: #d1fae5; padding: 1.5rem; border-radius: 4px; margin-bottom: 1rem;">
                    <h3 style="color: #065f46; margin-bottom: 1rem;">
                        ✅ Carta ${numeroCarta}-${anioCarta} eliminada exitosamente
                    </h3>
                    
                    <p style="margin-bottom: 1rem;">
                        El acceso VPN ha sido eliminado y la solicitud cambió a estado PENDIENTE.
                    </p>
                    
                    <div style="background: #fef3c7; padding: 1rem; border-radius: 4px; margin-bottom: 1rem;">
                        <strong>📝 Siguiente Paso:</strong><br>
                        1. Edita los datos de la persona si es necesario<br>
                        2. Regenera la carta con el MISMO número (${numeroCarta}-${anioCarta})
                    </div>
                </div>
                
                <div style="display: flex; gap: 1rem;">
                    <button class="btn btn-primary" style="flex: 1;" 
                            onclick="GestionCartas.mostrarOpcionEditar(${solicitudId}); hideModal();">
                        ✏️ Editar Datos de Persona
                    </button>
                    
                    <button class="btn btn-success" style="flex: 1;" 
                            onclick="GestionCartas.regenerarCarta(${solicitudId}, ${numeroCarta}, ${anioCarta}); hideModal();">
                        🔄 Regenerar Carta Ahora
                    </button>
                </div>
                
                <button class="btn btn-outline btn-block" style="margin-top: 1rem;" onclick="hideModal(); location.reload();">
                    Cerrar y Recargar
                </button>
            `);
            
        } catch (error) {
            hideLoading();
            showError('Error al eliminar carta: ' + error.message);
        }
    },
    
    /**
     * Mostrar opciones para editar persona
     */
    async mostrarOpcionEditar(solicitudId) {
        try {
            showLoading();
            const sol = await API.get(`/solicitudes/${solicitudId}`);
            hideLoading();
            
            showModal('✏️ Editar Datos de la Persona', `
                <div style="background: #fef3c7; padding: 1rem; border-radius: 4px; margin-bottom: 1.5rem;">
                    <strong>⚠️ IMPORTANTE:</strong><br>
                    Como SUPERADMIN puedes editar TODOS los datos, incluyendo:<br>
                    • Nombres y Apellidos<br>
                    • DPI<br>
                    • NIP
                </div>
                
                <form id="formEditarPersonaCompleta">
                    <div class="form-group">
                        <label>Nombres *</label>
                        <input type="text" id="nombres" required value="${sol.persona.nombres}">
                    </div>
                    
                    <div class="form-group">
                        <label>Apellidos *</label>
                        <input type="text" id="apellidos" required value="${sol.persona.apellidos}">
                    </div>
                    
                    <div class="form-group">
                        <label>DPI * (13 dígitos)</label>
                        <input type="text" id="dpi" required 
                               pattern="[0-9]{13}" maxlength="13" 
                               value="${sol.persona.dpi}">
                    </div>
                    
                    <div class="form-group">
                        <label>NIP</label>
                        <input type="text" id="nip" value="${sol.persona.nip || ''}">
                    </div>
                    
                    <div class="form-group">
                        <label>Email</label>
                        <input type="email" id="email" value="${sol.persona.email || ''}">
                    </div>
                    
                    <div class="form-group">
                        <label>Cargo/Grado</label>
                        <input type="text" id="cargo" value="${sol.persona.cargo || ''}">
                    </div>
                    
                    <div class="form-group">
                        <label>Institución</label>
                        <input type="text" id="institucion" value="${sol.persona.institucion || ''}">
                    </div>
                    
                    <div class="form-group">
                        <label>Teléfono</label>
                        <input type="text" id="telefono" value="${sol.persona.telefono || ''}">
                    </div>
                    
                    <button type="submit" class="btn btn-success btn-block">
                        💾 Guardar Cambios
                    </button>
                </form>
            `);
            
            document.getElementById('formEditarPersonaCompleta').addEventListener('submit', async (e) => {
                e.preventDefault();
                await this.guardarEdicionCompleta(sol.persona.id, solicitudId);
            });
            
        } catch (error) {
            hideLoading();
            showError('Error: ' + error.message);
        }
    },
    
    /**
     * Guardar edición completa de persona
     */
    async guardarEdicionCompleta(personaId, solicitudId) {
        try {
            showLoading();
            
            const data = {
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
            if (!/^\d{13}$/.test(data.dpi)) {
                throw new Error('El DPI debe tener exactamente 13 dígitos');
            }
            
            await API.put(`/personas/editar-completa/${personaId}`, data);
            
            hideLoading();
            hideModal();
            
            showSuccess('✅ Datos actualizados correctamente');
            
            // Preguntar si desea regenerar carta ahora
            const regenerar = await CustomConfirm.show({
                title: '🔄 ¿Regenerar Carta?',
                message: 'Los datos se actualizaron correctamente.\n\n¿Deseas regenerar la carta ahora con los datos corregidos?',
                type: 'info',
                confirmText: 'Sí, regenerar',
                cancelText: 'No, después'
            });
            
            if (regenerar) {
                // Necesitamos obtener el número de carta eliminada
                location.reload(); // Por simplicidad, recargar para ver botón de regenerar
            }
            
        } catch (error) {
            hideLoading();
            showError('Error al guardar: ' + error.message);
        }
    },
    
    /**
     * Regenerar carta con el mismo número
     */
    async regenerarCarta(solicitudId, numeroOriginal, anioOriginal) {
        if (!this.esSuperadmin()) {
            showError('⛔ Solo SUPERADMIN puede regenerar cartas');
            return;
        }
        
        const confirmar = await CustomConfirm.show({
            title: '🔄 Regenerar Carta',
            message: `¿Regenerar la carta ${numeroOriginal}-${anioOriginal}?\n\nSe creará una nueva carta con:\n• El MISMO número: ${numeroOriginal}-${anioOriginal}\n• Los datos actualizados de la persona\n• Un nuevo acceso VPN`,
            type: 'info',
            confirmText: 'Regenerar',
            cancelText: 'Cancelar'
        });
        
        if (!confirmar) return;
        
        try {
            showLoading();
            
            const response = await API.post(`/cartas/regenerar/${solicitudId}`, {});
            
            hideLoading();
            
            showModal('✅ Carta Regenerada', `
                <div style="background: #d1fae5; padding: 1.5rem; border-radius: 4px; margin-bottom: 1rem;">
                    <h3 style="color: #065f46; margin-bottom: 1rem;">
                        ✅ Carta ${response.numero_carta}-${response.anio_carta} regenerada
                    </h3>
                    
                    <p style="margin-bottom: 0.5rem;">
                        <strong>Carta ID:</strong> ${response.carta_id}
                    </p>
                    <p style="margin-bottom: 0.5rem;">
                        <strong>Acceso VPN ID:</strong> ${response.acceso_id}
                    </p>
                    
                    <div style="background: #dbeafe; padding: 1rem; border-radius: 4px; margin-top: 1rem;">
                        <strong>✅ Todo listo:</strong><br>
                        • Carta regenerada con número original<br>
                        • Acceso VPN creado<br>
                        • PDF disponible para descarga
                    </div>
                </div>
                
                <div style="display: flex; gap: 1rem; margin-bottom: 1rem;">
                    <button class="btn btn-primary" style="flex: 1;" 
                            onclick="Solicitudes.verCarta(${solicitudId}); hideModal();">
                        📄 Ver Carta
                    </button>
                    
                    <button class="btn btn-success" style="flex: 1;" 
                            onclick="Solicitudes.descargarPDF(${solicitudId}); hideModal();">
                        📥 Descargar PDF
                    </button>
                </div>
                
                <button class="btn btn-outline btn-block" onclick="hideModal(); location.reload();">
                    Cerrar y Recargar
                </button>
            `);
            
        } catch (error) {
            hideLoading();
            showError('Error al regenerar carta: ' + error.message);
        }
    },
    
    /**
     * Agregar botones de gestión en la vista de detalle de solicitud
     */
    agregarBotonesGestion(solicitudId, cartaId, numeroCarta, anioCarta) {
        if (!this.esSuperadmin()) return '';
        
        return `
            <div style="background: #fee2e2; padding: 1rem; border-radius: 4px; margin-top: 1rem;">
                <h4 style="color: #991b1b; margin-bottom: 0.5rem;">
                    🔧 Herramientas SUPERADMIN
                </h4>
                <p style="margin-bottom: 1rem; font-size: 0.9rem;">
                    Si hay errores en los datos, puedes eliminar la carta y regenerarla con el mismo número.
                </p>
                <button class="btn btn-danger btn-block" 
                        onclick="GestionCartas.eliminarCarta(${cartaId}, ${numeroCarta}, ${anioCarta}, ${solicitudId})">
                    🗑️ Eliminar Carta y Corregir Datos
                </button>
            </div>
        `;
    }
};

// Hacer disponible globalmente
window.GestionCartas = GestionCartas;

console.log('✅ Gestión de Cartas cargado (SUPERADMIN)');