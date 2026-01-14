// ========================================
// 🎨 MENÚ DE USUARIO - FUNCIONALIDAD
// Archivo: user-menu.js
// ========================================

const UserMenu = {
    
    /**
     * Inicializar el menú de usuario
     */
    init() {
        console.log('Inicializando menú de usuario...');
        
        // Setup event listeners
        this.setupEventListeners();
    },
    
    /**
     * Abrir menú
     */
    openMenu() {
        const dropdown = document.getElementById('userDropdown');
        const btn = document.getElementById('btnUserMenu');
        
        if (dropdown && btn) {
            dropdown.classList.add('show');
            btn.classList.add('active');
        }
    },
    
    /**
     * Cerrar menú
     */
    closeMenu() {
        const dropdown = document.getElementById('userDropdown');
        const btn = document.getElementById('btnUserMenu');
        
        if (dropdown && btn) {
            dropdown.classList.remove('show');
            btn.classList.remove('active');
        }
    },
    
    /**
     * Toggle del menú
     */
    toggleMenu() {
        const dropdown = document.getElementById('userDropdown');
        
        if (dropdown) {
            if (dropdown.classList.contains('show')) {
                this.closeMenu();
            } else {
                this.openMenu();
            }
        }
    },
    
    /**
     * Configurar event listeners
     */
    setupEventListeners() {
        const btnMenu = document.getElementById('btnUserMenu');
        const dropdown = document.getElementById('userDropdown');
        
        if (!btnMenu || !dropdown) {
            console.log('⚠️ Elementos del menú aún no disponibles, reintentando...');
            // Reintentar después de un pequeño delay
            setTimeout(() => this.setupEventListeners(), 100);
            return;
        }
        
        console.log('✅ Elementos del menú encontrados, configurando listeners...');
        
        // Toggle del menú
        btnMenu.addEventListener('click', (e) => {
            e.stopPropagation();
            this.toggleMenu();
        });
        
        // Cerrar al hacer clic fuera
        document.addEventListener('click', (e) => {
            if (dropdown.classList.contains('show')) {
                if (!dropdown.contains(e.target) && !btnMenu.contains(e.target)) {
                    this.closeMenu();
                }
            }
        });
        
        // Cerrar con ESC
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                if (dropdown.classList.contains('show')) {
                    this.closeMenu();
                }
            }
        });
        
        // Cerrar al hacer clic en un item del menú
        const dropdownItems = dropdown.querySelectorAll('.dropdown-item');
        dropdownItems.forEach(item => {
            item.addEventListener('click', () => {
                // Pequeño delay para que se vea la animación
                setTimeout(() => {
                    this.closeMenu();
                }, 100);
            });
        });
        
        console.log('✅ Menú de usuario configurado correctamente');
    }
};

// Inicializar el menú cuando el DOM esté listo
document.addEventListener('DOMContentLoaded', () => {
    // Esperar un poco más para asegurarse de que todo esté cargado
    setTimeout(() => {
        UserMenu.init();
    }, 200);
});