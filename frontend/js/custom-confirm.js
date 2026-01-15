// 🎨 SISTEMA DE CONFIRMACIÓN PERSONALIZADO
// 📂 Ubicación: frontend/js/custom-confirm.js
// ✅ Reemplaza los alerts nativos con modales elegantes

const CustomConfirm = {
    
    /**
     * Mostrar confirmación personalizada
     * @param {object} options - Opciones de configuración
     * @returns {Promise<boolean>} - true si acepta, false si cancela
     */
    show(options = {}) {
        return new Promise((resolve) => {
            const {
                title = '⚠️ Confirmación',
                message = '¿Estás seguro de realizar esta acción?',
                confirmText = 'Aceptar',
                cancelText = 'Cancelar',
                type = 'warning', // 'warning', 'danger', 'info', 'success'
                icon = this.getIcon(type)
            } = options;
            
            // Crear overlay
            const overlay = document.createElement('div');
            overlay.className = 'custom-confirm-overlay';
            overlay.style.cssText = `
                position: fixed;
                top: 0;
                left: 0;
                right: 0;
                bottom: 0;
                background: rgba(0, 0, 0, 0.6);
                display: flex;
                align-items: center;
                justify-content: center;
                z-index: 99999;
                backdrop-filter: blur(4px);
                animation: fadeIn 0.2s ease;
            `;
            
            // Crear modal
            const modal = document.createElement('div');
            modal.className = `custom-confirm-modal custom-confirm-${type}`;
            modal.style.cssText = `
                background: white;
                border-radius: 16px;
                padding: 2rem;
                max-width: 450px;
                width: 90%;
                box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
                animation: slideDown 0.3s ease;
                position: relative;
            `;
            
            // Contenido del modal
            modal.innerHTML = `
                <div style="text-align: center;">
                    <div style="
                        font-size: 4rem;
                        margin-bottom: 1rem;
                        animation: bounce 0.5s ease;
                    ">
                        ${icon}
                    </div>
                    
                    <h2 style="
                        font-size: 1.5rem;
                        font-weight: 700;
                        color: #1f2937;
                        margin-bottom: 1rem;
                    ">
                        ${title}
                    </h2>
                    
                    <p style="
                        font-size: 1rem;
                        color: #6b7280;
                        line-height: 1.6;
                        margin-bottom: 2rem;
                        white-space: pre-line;
                    ">
                        ${message}
                    </p>
                    
                    <div style="
                        display: flex;
                        gap: 1rem;
                        justify-content: center;
                    ">
                        <button id="customConfirmCancel" style="
                            flex: 1;
                            padding: 0.875rem 1.5rem;
                            border: 2px solid #e5e7eb;
                            background: white;
                            color: #6b7280;
                            border-radius: 10px;
                            font-weight: 600;
                            font-size: 1rem;
                            cursor: pointer;
                            transition: all 0.2s ease;
                        ">
                            ${cancelText}
                        </button>
                        
                        <button id="customConfirmAccept" style="
                            flex: 1;
                            padding: 0.875rem 1.5rem;
                            border: none;
                            background: ${this.getColor(type)};
                            color: white;
                            border-radius: 10px;
                            font-weight: 600;
                            font-size: 1rem;
                            cursor: pointer;
                            transition: all 0.2s ease;
                            box-shadow: 0 4px 12px ${this.getColor(type)}40;
                        ">
                            ${confirmText}
                        </button>
                    </div>
                </div>
            `;
            
            // Agregar animaciones CSS
            const style = document.createElement('style');
            style.textContent = `
                @keyframes fadeIn {
                    from { opacity: 0; }
                    to { opacity: 1; }
                }
                
                @keyframes slideDown {
                    from {
                        opacity: 0;
                        transform: translateY(-50px) scale(0.9);
                    }
                    to {
                        opacity: 1;
                        transform: translateY(0) scale(1);
                    }
                }
                
                @keyframes bounce {
                    0%, 100% { transform: translateY(0); }
                    50% { transform: translateY(-10px); }
                }
                
                @keyframes fadeOut {
                    from { opacity: 1; }
                    to { opacity: 0; }
                }
                
                @keyframes slideUp {
                    from {
                        opacity: 1;
                        transform: translateY(0) scale(1);
                    }
                    to {
                        opacity: 0;
                        transform: translateY(-50px) scale(0.9);
                    }
                }
                
                #customConfirmCancel:hover {
                    background: #f3f4f6;
                    border-color: #d1d5db;
                    transform: translateY(-2px);
                }
                
                #customConfirmAccept:hover {
                    transform: translateY(-2px);
                    box-shadow: 0 6px 16px ${this.getColor(type)}60;
                }
                
                #customConfirmCancel:active,
                #customConfirmAccept:active {
                    transform: translateY(0);
                }
            `;
            document.head.appendChild(style);
            
            // Agregar al DOM
            overlay.appendChild(modal);
            document.body.appendChild(overlay);
            
            // Función para cerrar con animación
            const closeModal = (result) => {
                overlay.style.animation = 'fadeOut 0.2s ease';
                modal.style.animation = 'slideUp 0.3s ease';
                
                setTimeout(() => {
                    if (overlay.parentNode) {
                        overlay.parentNode.removeChild(overlay);
                    }
                    if (style.parentNode) {
                        style.parentNode.removeChild(style);
                    }
                    resolve(result);
                }, 200);
            };
            
            // Event listeners
            const btnCancel = modal.querySelector('#customConfirmCancel');
            const btnAccept = modal.querySelector('#customConfirmAccept');
            
            btnCancel.addEventListener('click', () => closeModal(false));
            btnAccept.addEventListener('click', () => closeModal(true));
            
            // Cerrar al hacer clic en el overlay
            overlay.addEventListener('click', (e) => {
                if (e.target === overlay) {
                    closeModal(false);
                }
            });
            
            // Cerrar con ESC
            const handleEscape = (e) => {
                if (e.key === 'Escape') {
                    closeModal(false);
                    document.removeEventListener('keydown', handleEscape);
                }
            };
            document.addEventListener('keydown', handleEscape);
            
            // Enfocar botón de aceptar por defecto
            setTimeout(() => btnAccept.focus(), 100);
        });
    },
    
    /**
     * Obtener icono según el tipo
     */
    getIcon(type) {
        const icons = {
            warning: '⚠️',
            danger: '🚫',
            info: 'ℹ️',
            success: '✅',
            question: '❓'
        };
        return icons[type] || '⚠️';
    },
    
    /**
     * Obtener color según el tipo
     */
    getColor(type) {
        const colors = {
            warning: '#f59e0b',
            danger: '#ef4444',
            info: '#3b82f6',
            success: '#10b981',
            question: '#8b5cf6'
        };
        return colors[type] || '#f59e0b';
    },
    
    // ========================================
    // ATAJOS RÁPIDOS
    // ========================================
    
    /**
     * Confirmación de peligro (rojo)
     */
    danger(title, message) {
        return this.show({
            title,
            message,
            type: 'danger',
            confirmText: 'Sí, eliminar',
            cancelText: 'Cancelar'
        });
    },
    
    /**
     * Confirmación de advertencia (amarillo)
     */
    warning(title, message) {
        return this.show({
            title,
            message,
            type: 'warning',
            confirmText: 'Continuar',
            cancelText: 'Cancelar'
        });
    },
    
    /**
     * Confirmación de información (azul)
     */
    info(title, message) {
        return this.show({
            title,
            message,
            type: 'info',
            confirmText: 'Entendido',
            cancelText: 'Cerrar'
        });
    },
    
    /**
     * Confirmación de éxito (verde)
     */
    success(title, message) {
        return this.show({
            title,
            message,
            type: 'success',
            confirmText: 'Aceptar',
            cancelText: 'Cerrar'
        });
    }
};

// ========================================
// REEMPLAZAR CONFIRM NATIVO
// ========================================

// Guardar el confirm original por si se necesita
window.nativeConfirm = window.confirm;

// Reemplazar confirm global con versión async
window.confirm = async function(message) {
    // Si el mensaje contiene "eliminar" o "desactivar", usar tipo danger
    const isDanger = message.toLowerCase().includes('eliminar') || 
                     message.toLowerCase().includes('desactivar') ||
                     message.toLowerCase().includes('borrar');
    
    const type = isDanger ? 'danger' : 'warning';
    
    return await CustomConfirm.show({
        title: isDanger ? '🚨 Acción Irreversible' : '⚠️ Confirmación',
        message: message,
        type: type,
        confirmText: isDanger ? 'Sí, continuar' : 'Aceptar',
        cancelText: 'Cancelar'
    });
};

// ========================================
// EJEMPLOS DE USO
// ========================================

/**
 * Uso básico (reemplaza confirm nativo):
 * 
 * if (await confirm('¿Estás seguro?')) {
 *     // Usuario aceptó
 * }
 */

/**
 * Uso avanzado con opciones personalizadas:
 * 
 * const result = await CustomConfirm.show({
 *     title: '🗑️ Eliminar Usuario',
 *     message: 'Esta acción no se puede deshacer.\n¿Estás seguro?',
 *     type: 'danger',
 *     confirmText: 'Sí, eliminar',
 *     cancelText: 'Cancelar'
 * });
 * 
 * if (result) {
 *     // Usuario confirmó
 * }
 */

/**
 * Atajos rápidos:
 * 
 * await CustomConfirm.danger(
 *     '🗑️ Eliminar Usuario',
 *     'Esta acción no se puede deshacer'
 * );
 * 
 * await CustomConfirm.warning(
 *     '⚠️ Advertencia',
 *     'Los cambios no se han guardado'
 * );
 */

console.log('✅ Sistema de Confirmación Personalizado cargado');