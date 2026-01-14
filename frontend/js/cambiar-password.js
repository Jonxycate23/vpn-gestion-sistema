// ========================================
// VERIFICACIÓN DE CAMBIO DE CONTRASEÑA OBLIGATORIO
// ========================================
// 📂 Ubicación: frontend/js/primer-login-check.js
// 🎯 Propósito: Forzar cambio de contraseña en primer login

const PrimerLoginCheck = {
    
    /**
     * Verificar si el usuario debe cambiar su contraseña
     * Llamar después del login exitoso
     */
    verificarCambioObligatorio() {
        const user = UserStorage.get();
        if (!user) return;
        
        // Verificar si la contraseña es la predeterminada
        // Nota: Esto requiere que el backend incluya un flag en el usuario
        if (this.esPasswordPredeterminada(user)) {
            this.mostrarCambioObligatorio();
        }
    },
    
    /**
     * Verificar si la contraseña es la predeterminada
     * OPCIÓN 1: Usar un flag del backend (RECOMENDADO)
     */
    esPasswordPredeterminada(user) {
        // Si el backend incluye un campo como "debe_cambiar_password"
        if (user.debe_cambiar_password === true) {
            return true;
        }
        
        // OPCIÓN 2: Verificar si nunca ha cambiado la contraseña
        // (requiere campo fecha_cambio_password en el backend)
        if (!user.fecha_cambio_password) {
            return true;
        }
        
        return false;
    },
    
    /**
     * Mostrar modal de cambio obligatorio (no se puede cerrar)
     */
    mostrarCambioObligatorio() {
        const user = UserStorage.get();
        
        // Crear modal que no se puede cerrar
        const modalHTML = `
            <div id="modalCambioObligatorio" style="
                position: fixed;
                top: 0;
                left: 0;
                width: 100%;
                height: 100%;
                background: rgba(0, 0, 0, 0.8);
                display: flex;
                align-items: center;
                justify-content: center;
                z-index: 9999;
            ">
                <div style="
                    background: white;
                    border-radius: 12px;
                    max-width: 500px;
                    width: 90%;
                    padding: 2rem;
                    box-shadow: 0 10px 25px rgba(0, 0, 0, 0.2);
                ">
                    <div style="text-align: center; margin-bottom: 1.5rem;">
                        <div style="
                            font-size: 3rem;
                            margin-bottom: 1rem;
                        ">🔐</div>
                        <h2 style="
                            color: #ef4444;
                            margin-bottom: 0.5rem;
                        ">Cambio de Contraseña Obligatorio</h2>
                        <p style="color: #6b7280;">
                            Por seguridad, debes cambiar tu contraseña antes de continuar.
                        </p>
                    </div>
                    
                    <form id="formCambioObligatorio">
                        <div style="background: #e0f2fe; padding: 1rem; border-radius: 8px; margin-bottom: 1.5rem;">
                            <strong>Usuario:</strong> ${user.nombre_completo}<br>
                            <strong>Username:</strong> <code>${user.username}</code>
                        </div>
                        
                        <div class="form-group">
                            <label style="display: block; margin-bottom: 0.5rem; font-weight: 600;">
                                Contraseña Actual *
                            </label>
                            <input type="password" 
                                   id="password_actual_obligatorio" 
                                   required 
                                   style="width: 100%; padding: 0.75rem; border: 1px solid #d1d5db; border-radius: 6px;"
                                   placeholder="Usuario.2025!">
                        </div>
                        
                        <div class="form-group">
                            <label style="display: block; margin-bottom: 0.5rem; font-weight: 600;">
                                Nueva Contraseña *
                            </label>
                            <input type="password" 
                                   id="password_nueva_obligatorio" 
                                   required 
                                   minlength="6"
                                   style="width: 100%; padding: 0.75rem; border: 1px solid #d1d5db; border-radius: 6px;"
                                   placeholder="Mínimo 6 caracteres">
                            <small style="display: block; margin-top: 0.25rem; color: #6b7280; font-size: 0.875rem;">
                                Debe tener al menos 6 caracteres
                            </small>
                        </div>
                        
                        <div class="form-group">
                            <label style="display: block; margin-bottom: 0.5rem; font-weight: 600;">
                                Confirmar Nueva Contraseña *
                            </label>
                            <input type="password" 
                                   id="password_confirmar_obligatorio" 
                                   required 
                                   minlength="6"
                                   style="width: 100%; padding: 0.75rem; border: 1px solid #d1d5db; border-radius: 6px;"
                                   placeholder="Repite la nueva contraseña">
                        </div>
                        
                        <div style="background: #fef3c7; padding: 1rem; border-radius: 8px; margin: 1rem 0;">
                            <strong>💡 Recomendaciones de seguridad:</strong><br>
                            • Combina letras mayúsculas y minúsculas<br>
                            • Incluye números y símbolos<br>
                            • No uses información personal<br>
                            • No reutilices contraseñas
                        </div>
                        
                        <button type="submit" style="
                            width: 100%;
                            padding: 0.875rem;
                            background: #3b82f6;
                            color: white;
                            border: none;
                            border-radius: 6px;
                            font-weight: 600;
                            cursor: pointer;
                            font-size: 1rem;
                        ">
                            🔑 Cambiar Contraseña y Continuar
                        </button>
                        
                        <div style="text-align: center; margin-top: 1rem;">
                            <button type="button" 
                                    onclick="Auth.logout()"
                                    style="
                                        background: none;
                                        border: none;
                                        color: #6b7280;
                                        cursor: pointer;
                                        text-decoration: underline;
                                    ">
                                Cerrar sesión
                            </button>
                        </div>
                    </form>
                </div>
            </div>
        `;
        
        // Insertar modal en el body
        document.body.insertAdjacentHTML('beforeend', modalHTML);
        
        // Event listener para el formulario
        document.getElementById('formCambioObligatorio').addEventListener('submit', async (e) => {
            e.preventDefault();
            await this.procesarCambioObligatorio();
        });
    },
    
    /**
     * Procesar el cambio de contraseña obligatorio
     */
    async procesarCambioObligatorio() {
        try {
            const passwordActual = document.getElementById('password_actual_obligatorio').value;
            const passwordNueva = document.getElementById('password_nueva_obligatorio').value;
            const passwordConfirmar = document.getElementById('password_confirmar_obligatorio').value;
            
            // Validaciones
            if (!passwordActual || !passwordNueva || !passwordConfirmar) {
                throw new Error('Debes completar todos los campos');
            }
            
            if (passwordNueva.length < 6) {
                throw new Error('La nueva contraseña debe tener al menos 6 caracteres');
            }
            
            if (passwordNueva !== passwordConfirmar) {
                throw new Error('Las contraseñas nuevas no coinciden');
            }
            
            if (passwordActual === passwordNueva) {
                throw new Error('La nueva contraseña debe ser diferente a la actual');
            }
            
            showLoading();
            
            // Llamar al endpoint
            await API.put('/usuarios/me/cambiar-password', {
                password_actual: passwordActual,
                password_nueva: passwordNueva
            });
            
            hideLoading();
            
            // Remover el modal
            const modal = document.getElementById('modalCambioObligatorio');
            if (modal) {
                modal.remove();
            }
            
            // Mostrar mensaje de éxito
            showSuccess('✅ Contraseña cambiada exitosamente. Ya puedes usar el sistema.');
            
            // Opcional: Actualizar el flag en el usuario almacenado
            const user = UserStorage.get();
            if (user) {
                user.debe_cambiar_password = false;
                UserStorage.set(user);
            }
            
        } catch (error) {
            hideLoading();
            showError('Error al cambiar contraseña: ' + error.message);
        }
    }
};


// ========================================
// INTEGRACIÓN CON EL LOGIN
// ========================================

// Modificar tu función de login para incluir la verificación
// Ejemplo de cómo integrar en tu auth.js:

/*
Auth.login = async function(username, password) {
    try {
        const response = await API.post('/auth/login', {
            username,
            password
        });
        
        if (response && response.access_token) {
            TokenStorage.set(response.access_token);
            UserStorage.set(response.usuario);
            
            // ✅ VERIFICAR SI DEBE CAMBIAR CONTRASEÑA
            PrimerLoginCheck.verificarCambioObligatorio();
            
            // Redirigir al dashboard
            window.location.href = '/dashboard';
        }
    } catch (error) {
        showError('Credenciales inválidas');
    }
};
*/