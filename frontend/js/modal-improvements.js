// 🎨 MEJORAS DE MODALES - NO SE CIERRAN AL HACER CLIC AFUERA
// 📂 Ubicación: frontend/js/modal-improvements.js
// ✅ Mejora la experiencia de usuario con los modales

const ModalManager = {
    /**
     * Mejorar la función showModal existente
     */
    enhance() {
        // Guardar referencia a la función original
        const originalShowModal = window.showModal;
        
        // Sobreescribir con versión mejorada
        window.showModal = function(title, content, size = 'normal') {
            const modal = document.getElementById('modal');
            const modalTitle = document.getElementById('modalTitle');
            const modalBody = document.getElementById('modalBody');
            const modalContent = modal?.querySelector('.modal-content');
            
            if (!modal || !modalTitle || !modalBody) {
                console.error('❌ Elementos del modal no encontrados');
                return;
            }
            
            // Establecer contenido
            modalTitle.textContent = title;
            modalBody.innerHTML = content;
            
            // Aplicar tamaño si es 'large'
            if (size === 'large' && modalContent) {
                modalContent.classList.add('large');
            } else if (modalContent) {
                modalContent.classList.remove('large');
            }
            
            // Mostrar modal con animación
            modal.classList.add('active');
            
            // ✅ CRITICAL: Remover el event listener que cierra al hacer clic afuera
            ModalManager.removeClickOutsideListener(modal);
            
            // Agregar listener para ESC (opcional - mantener)
            ModalManager.addEscapeListener();
            
            // Focus en el primer input si existe
            setTimeout(() => {
                const firstInput = modalBody.querySelector('input:not([type="hidden"]), textarea, select');
                if (firstInput) {
                    firstInput.focus();
                }
            }, 100);
        };
        
        // Mejorar hideModal
        const originalHideModal = window.hideModal;
        
        window.hideModal = function() {
            const modal = document.getElementById('modal');
            if (!modal) return;
            
            // Animación de salida
            modal.classList.add('closing');
            
            setTimeout(() => {
                modal.classList.remove('active', 'closing');
                
                // Limpiar contenido
                const modalBody = document.getElementById('modalBody');
                if (modalBody) {
                    modalBody.innerHTML = '';
                }
                
                // Remover clase large
                const modalContent = modal.querySelector('.modal-content');
                if (modalContent) {
                    modalContent.classList.remove('large');
                }
            }, 300);
        };
        
        console.log('✅ Modales mejorados - NO se cierran al hacer clic afuera');
    },
    
    /**
     * Remover el listener que cierra el modal al hacer clic afuera
     */
    removeClickOutsideListener(modal) {
        // Clonar el elemento para remover todos los listeners antiguos
        const newModal = modal.cloneNode(true);
        modal.parentNode.replaceChild(newModal, modal);
        
        // Agregar SOLO el listener del botón de cerrar
        const closeBtn = newModal.querySelector('.modal-close');
        if (closeBtn) {
            closeBtn.addEventListener('click', () => {
                window.hideModal();
            });
        }
        
        // ❌ NO agregar listener para cerrar al hacer clic en el overlay
        // Esto es intencional para evitar que se cierre accidentalmente
    },
    
    /**
     * Agregar listener para cerrar con ESC (opcional)
     */
    addEscapeListener() {
        // Remover listeners anteriores
        document.removeEventListener('keydown', ModalManager.escapeHandler);
        
        // Agregar nuevo listener
        document.addEventListener('keydown', ModalManager.escapeHandler);
    },
    
    /**
     * Handler para la tecla ESC
     */
    escapeHandler(e) {
        if (e.key === 'Escape') {
            const modal = document.getElementById('modal');
            if (modal && modal.classList.contains('active')) {
                window.hideModal();
            }
        }
    },
    
    /**
     * Mostrar modal de confirmación
     */
    confirm(message, title = '⚠️ Confirmación', onConfirm = null, onCancel = null) {
        const content = `
            <div style="text-align: center; padding: 1rem;">
                <p style="font-size: 1.1rem; color: #374151; margin-bottom: 2rem;">
                    ${message}
                </p>
                <div style="display: flex; gap: 1rem; justify-content: center;">
                    <button class="btn btn-outline" onclick="ModalManager.handleCancel()">
                        Cancelar
                    </button>
                    <button class="btn btn-primary" onclick="ModalManager.handleConfirm()">
                        Confirmar
                    </button>
                </div>
            </div>
        `;
        
        this.confirmCallback = onConfirm;
        this.cancelCallback = onCancel;
        
        window.showModal(title, content);
    },
    
    handleConfirm() {
        if (this.confirmCallback) {
            this.confirmCallback();
        }
        window.hideModal();
    },
    
    handleCancel() {
        if (this.cancelCallback) {
            this.cancelCallback();
        }
        window.hideModal();
    }
};

// ========================================
// AUTO-INICIALIZAR AL CARGAR
// ========================================
document.addEventListener('DOMContentLoaded', () => {
    // Esperar un poco para que todo esté cargado
    setTimeout(() => {
        ModalManager.enhance();
    }, 100);
});

// ========================================
// ATAJOS GLOBALES
// ========================================

/**
 * Mostrar modal de confirmación
 * 
 * @example
 * confirmModal('¿Eliminar este registro?', '🗑️ Confirmar Eliminación', () => {
 *     console.log('Confirmado');
 * });
 */
window.confirmModal = function(message, title, onConfirm, onCancel) {
    ModalManager.confirm(message, title, onConfirm, onCancel);
};

console.log('✅ Modal Improvements cargado');