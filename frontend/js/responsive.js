// ========================================
// 📱 SISTEMA RESPONSIVE - JAVASCRIPT
// Funcionalidad para menú móvil y responsive
// Ubicación: frontend/js/responsive.js
// ========================================

const ResponsiveSystem = {
    
    /**
     * Inicializar sistema responsive
     */
    init() {
        console.log('🔄 Inicializando sistema responsive...');
        
        this.createMobileMenuButton();
        this.createSidebarOverlay();
        this.setupEventListeners();
        this.handleResize();
        
        console.log('✅ Sistema responsive inicializado');
    },
    
    /**
     * Crear botón de menú móvil
     */
    createMobileMenuButton() {
        const topNav = document.querySelector('.top-nav');
        const navBrand = document.querySelector('.nav-brand');
        
        if (!topNav || !navBrand) return;
        
        // Verificar si ya existe
        if (document.getElementById('mobileMenuBtn')) return;
        
        // Crear botón hamburguesa
        const btn = document.createElement('button');
        btn.id = 'mobileMenuBtn';
        btn.className = 'mobile-menu-btn';
        btn.innerHTML = `
            <span></span>
            <span></span>
            <span></span>
        `;
        
        // Insertar antes del nav-brand
        topNav.insertBefore(btn, navBrand);
    },
    
    /**
     * Crear overlay para cerrar sidebar
     */
    createSidebarOverlay() {
        // Verificar si ya existe
        if (document.getElementById('sidebarOverlay')) return;
        
        const overlay = document.createElement('div');
        overlay.id = 'sidebarOverlay';
        overlay.className = 'sidebar-overlay';
        
        document.body.appendChild(overlay);
    },
    
    /**
     * Setup event listeners
     */
    setupEventListeners() {
        const btn = document.getElementById('mobileMenuBtn');
        const sidebar = document.querySelector('.sidebar');
        const overlay = document.getElementById('sidebarOverlay');
        
        if (!btn || !sidebar || !overlay) return;
        
        // Toggle sidebar al hacer clic en hamburguesa
        btn.addEventListener('click', (e) => {
            e.stopPropagation();
            this.toggleSidebar();
        });
        
        // Cerrar al hacer clic en overlay
        overlay.addEventListener('click', () => {
            this.closeSidebar();
        });
        
        // Cerrar al hacer clic en un item del menú (solo en móvil)
        const menuItems = sidebar.querySelectorAll('.menu-item');
        menuItems.forEach(item => {
            item.addEventListener('click', () => {
                if (window.innerWidth <= 768) {
                    this.closeSidebar();
                }
            });
        });
        
        // Cerrar con tecla ESC
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                this.closeSidebar();
            }
        });
        
        // Manejar resize
        window.addEventListener('resize', () => {
            this.handleResize();
        });
    },
    
    /**
     * Toggle sidebar
     */
    toggleSidebar() {
        const btn = document.getElementById('mobileMenuBtn');
        const sidebar = document.querySelector('.sidebar');
        const overlay = document.getElementById('sidebarOverlay');
        
        if (!btn || !sidebar || !overlay) return;
        
        const isActive = sidebar.classList.contains('active');
        
        if (isActive) {
            this.closeSidebar();
        } else {
            this.openSidebar();
        }
    },
    
    /**
     * Abrir sidebar
     */
    openSidebar() {
        const btn = document.getElementById('mobileMenuBtn');
        const sidebar = document.querySelector('.sidebar');
        const overlay = document.getElementById('sidebarOverlay');
        
        if (!btn || !sidebar || !overlay) return;
        
        sidebar.classList.add('active');
        overlay.classList.add('active');
        btn.classList.add('active');
        
        // Prevenir scroll del body
        document.body.style.overflow = 'hidden';
    },
    
    /**
     * Cerrar sidebar
     */
    closeSidebar() {
        const btn = document.getElementById('mobileMenuBtn');
        const sidebar = document.querySelector('.sidebar');
        const overlay = document.getElementById('sidebarOverlay');
        
        if (!btn || !sidebar || !overlay) return;
        
        sidebar.classList.remove('active');
        overlay.classList.remove('active');
        btn.classList.remove('active');
        
        // Restaurar scroll del body
        document.body.style.overflow = '';
    },
    
    /**
     * Manejar cambios de tamaño de ventana
     */
    handleResize() {
        const width = window.innerWidth;
        
        // Si pasamos a desktop, cerrar sidebar
        if (width > 768) {
            this.closeSidebar();
        }
    },
    
    /**
     * Detectar tipo de dispositivo
     */
    getDeviceType() {
        const width = window.innerWidth;
        
        if (width <= 480) return 'mobile';
        if (width <= 768) return 'tablet';
        if (width <= 1024) return 'desktop';
        return 'wide';
    },
    
    /**
     * Verificar si es móvil
     */
    isMobile() {
        return window.innerWidth <= 768;
    },
    
    /**
     * Verificar si es tablet
     */
    isTablet() {
        return window.innerWidth > 768 && window.innerWidth <= 1024;
    },
    
    /**
     * Verificar si es desktop
     */
    isDesktop() {
        return window.innerWidth > 1024;
    }
};

// ========================================
// UTILIDADES RESPONSIVE
// ========================================

/**
 * Hacer scroll suave a un elemento
 */
function scrollToElement(elementId, offset = 0) {
    const element = document.getElementById(elementId);
    if (!element) return;
    
    const top = element.offsetTop - offset;
    
    window.scrollTo({
        top: top,
        behavior: 'smooth'
    });
}

/**
 * Detectar orientación del dispositivo
 */
function getOrientation() {
    return window.innerWidth > window.innerHeight ? 'landscape' : 'portrait';
}

/**
 * Verificar si el dispositivo soporta touch
 */
function isTouchDevice() {
    return 'ontouchstart' in window || navigator.maxTouchPoints > 0;
}

/**
 * Optimizar tablas para móvil
 */
function optimizeTableForMobile(tableId) {
    const table = document.getElementById(tableId);
    if (!table) return;
    
    const wrapper = table.closest('.table-wrapper');
    if (!wrapper) return;
    
    if (ResponsiveSystem.isMobile()) {
        // Agregar indicador de scroll
        const indicator = document.createElement('div');
        indicator.className = 'scroll-indicator';
        indicator.innerHTML = '← Desliza para ver más →';
        indicator.style.cssText = `
            text-align: center;
            padding: 0.5rem;
            background: #fef3c7;
            color: #92400e;
            font-size: 0.8rem;
            border-radius: 4px;
            margin-bottom: 0.5rem;
        `;
        
        // Solo agregar si no existe
        if (!wrapper.querySelector('.scroll-indicator')) {
            wrapper.parentNode.insertBefore(indicator, wrapper);
        }
        
        // Ocultar indicador después de scroll
        wrapper.addEventListener('scroll', () => {
            if (indicator && wrapper.scrollLeft > 20) {
                indicator.style.display = 'none';
            }
        }, { once: true });
    }
}

/**
 * Adaptar modales para móvil
 */
function adaptModalForMobile() {
    const modals = document.querySelectorAll('.modal');
    
    modals.forEach(modal => {
        modal.addEventListener('click', (e) => {
            // En móvil, solo cerrar si se hace clic en el overlay
            if (ResponsiveSystem.isMobile() && e.target === modal) {
                // Agregar animación de cierre desde abajo
                const content = modal.querySelector('.modal-content');
                if (content) {
                    content.style.animation = 'slideOutDown 0.3s ease';
                    setTimeout(() => {
                        if (typeof hideModal === 'function') {
                            hideModal();
                        }
                    }, 300);
                }
            }
        });
    });
}

/**
 * Optimizar forms para móvil
 */
function optimizeFormsForMobile() {
    if (!ResponsiveSystem.isMobile()) return;
    
    // Hacer que los selects sean más grandes en móvil
    const selects = document.querySelectorAll('select');
    selects.forEach(select => {
        select.style.fontSize = '16px';
        select.style.padding = '0.75rem';
    });
    
    // Mejorar inputs de fecha en móvil
    const dateInputs = document.querySelectorAll('input[type="date"]');
    dateInputs.forEach(input => {
        input.style.fontSize = '16px';
    });
}

// ========================================
// AUTO-INICIALIZACIÓN
// ========================================

// Inicializar cuando el DOM esté listo
document.addEventListener('DOMContentLoaded', () => {
    ResponsiveSystem.init();
    
    // Optimizaciones adicionales
    setTimeout(() => {
        optimizeFormsForMobile();
        adaptModalForMobile();
        
        // Optimizar tablas existentes
        const tables = ['solicitudesTable', 'accesosTable', 'usuariosTable', 'dashboardTable'];
        tables.forEach(tableId => {
            if (document.getElementById(tableId)) {
                optimizeTableForMobile(tableId);
            }
        });
    }, 500);
});

// Agregar clases de dispositivo al body para CSS condicional
window.addEventListener('load', () => {
    const deviceType = ResponsiveSystem.getDeviceType();
    document.body.classList.add(`device-${deviceType}`);
    
    if (isTouchDevice()) {
        document.body.classList.add('touch-device');
    }
});

// Actualizar clases en resize
let resizeTimer;
window.addEventListener('resize', () => {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(() => {
        // Actualizar clase de dispositivo
        document.body.className = document.body.className.replace(/device-\w+/g, '');
        const deviceType = ResponsiveSystem.getDeviceType();
        document.body.classList.add(`device-${deviceType}`);
    }, 250);
});

console.log('✅ Sistema responsive cargado');