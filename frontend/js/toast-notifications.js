// SISTEMA DE NOTIFICACIONES MODERNO
const Toast = {
    container: null,
    
    /**
     * Inicializar el contenedor de toasts
     */
    init() {
        if (!this.container) {
            this.container = document.createElement('div');
            this.container.className = 'toast-container';
            document.body.appendChild(this.container);
        }
    },
    
    /**
     * Mostrar un toast
     * @param {string} message - Mensaje a mostrar
     * @param {string} type - Tipo: 'success', 'error', 'warning', 'info'
     * @param {number} duration - Duración en ms (0 = no auto-cerrar)
     * @param {object} options - Opciones adicionales
     */
    show(message, type = 'info', duration = 5000, options = {}) {
        this.init();
        
        const {
            title = this.getDefaultTitle(type),
            icon = this.getDefaultIcon(type),
            action = null
        } = options;
        
        // Crear elemento del toast
        const toast = document.createElement('div');
        toast.className = `toast toast-${type}`;
        
        // Construir HTML
        let html = `
            <div class="toast-icon">${icon}</div>
            <div class="toast-content">
                <div class="toast-title">${title}</div>
                <div class="toast-message">${message}</div>
        `;
        
        // Agregar acción si existe
        if (action) {
            html += `
                <div class="toast-action">
                    <button onclick="${action.onClick}">${action.label}</button>
                </div>
            `;
        }
        
        html += `
            </div>
            <button class="toast-close" onclick="Toast.close(this.parentElement)">×</button>
        `;
        
        toast.innerHTML = html;
        
        // Agregar al contenedor
        this.container.appendChild(toast);
        
        // Auto-cerrar si duration > 0
        if (duration > 0) {
            setTimeout(() => {
                this.close(toast);
            }, duration);
        }
        
        // Cerrar al hacer clic en el toast
        toast.addEventListener('click', (e) => {
            // No cerrar si se hace clic en un botón de acción
            if (!e.target.classList.contains('toast-action') && 
                !e.target.closest('.toast-action')) {
                this.close(toast);
            }
        });
        
        return toast;
    },
    
    /**
     * Cerrar un toast
     */
    close(toast) {
        if (!toast || !toast.parentElement) return;
        
        toast.classList.add('toast-removing');
        
        setTimeout(() => {
            if (toast.parentElement) {
                toast.parentElement.removeChild(toast);
            }
        }, 300);
    },
    
    /**
     * Cerrar todos los toasts
     */
    closeAll() {
        const toasts = this.container?.querySelectorAll('.toast');
        if (toasts) {
            toasts.forEach(toast => this.close(toast));
        }
    },
    
    /**
     * Obtener título por defecto según el tipo
     */
    getDefaultTitle(type) {
        const titles = {
            success: '✅ Éxito',
            error: '❌ Error',
            warning: '⚠️ Advertencia',
            info: 'ℹ️ Información'
        };
        return titles[type] || 'Notificación';
    },
    
    /**
     * Obtener ícono por defecto según el tipo
     */
    getDefaultIcon(type) {
        const icons = {
            success: '✓',
            error: '✕',
            warning: '⚠',
            info: 'ℹ'
        };
        return icons[type] || 'ℹ';
    },
    
    // ========================================
    // ATAJOS RÁPIDOS
    // ========================================
    
    success(message, options = {}) {
        return this.show(message, 'success', 5000, options);
    },
    
    error(message, options = {}) {
        return this.show(message, 'error', 7000, options);
    },
    
    warning(message, options = {}) {
        return this.show(message, 'warning', 6000, options);
    },
    
    info(message, options = {}) {
        return this.show(message, 'info', 5000, options);
    },
    
    loading(message, options = {}) {
        return this.show(message, 'loading', 0, {
            ...options,
            title: options.title || '⏳ Cargando...',
            icon: ''
        });
    }
};

// ========================================
// REEMPLAZAR FUNCIONES ANTIGUAS
// ========================================

// Reemplazar showSuccess global
window.showSuccess = function(message) {
    Toast.success(message);
};

// Reemplazar showError global
window.showError = function(message) {
    Toast.error(message);
};

// Agregar nuevas funciones globales
window.showWarning = function(message) {
    Toast.warning(message);
};

window.showInfo = function(message) {
    Toast.info(message);
};

window.showLoading = function(message = 'Procesando...') {
    // Cerrar loading anteriores
    const loadingToasts = document.querySelectorAll('.toast-loading');
    loadingToasts.forEach(toast => Toast.close(toast));
    
    // Mostrar nuevo loading
    return Toast.loading(message);
};

window.hideLoading = function() {
    const loadingToasts = document.querySelectorAll('.toast-loading');
    loadingToasts.forEach(toast => Toast.close(toast));
};

console.log('✅ Sistema de Toast Notifications cargado');