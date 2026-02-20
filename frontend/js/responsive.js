/**
 * Sistema Responsive - Menú móvil
 * Controla el sidebar en dispositivos móviles
 */

const ResponsiveMenu = {

    init() {


        this.createMobileMenuButton();
        this.createOverlay();
        this.setupEventListeners();


    },

    createMobileMenuButton() {
        const topNav = document.querySelector('.top-nav');
        if (!topNav || document.getElementById('mobileMenuBtn')) return;

        // Crear botón hamburguesa
        const btn = document.createElement('button');
        btn.id = 'mobileMenuBtn';
        btn.className = 'mobile-menu-btn';
        btn.setAttribute('aria-label', 'Menú');
        btn.innerHTML = `
            <span></span>
            <span></span>
            <span></span>
        `;

        // Insertar al inicio del nav
        topNav.insertBefore(btn, topNav.firstChild);
    },

    createOverlay() {
        if (document.getElementById('sidebarOverlay')) return;

        const overlay = document.createElement('div');
        overlay.id = 'sidebarOverlay';
        overlay.className = 'sidebar-overlay';
        document.body.appendChild(overlay);
    },

    setupEventListeners() {
        const btn = document.getElementById('mobileMenuBtn');
        const sidebar = document.querySelector('.sidebar');
        const overlay = document.getElementById('sidebarOverlay');

        if (!btn || !sidebar || !overlay) {
            console.warn('Elementos del menú responsive no encontrados');
            return;
        }

        // Click en botón hamburguesa
        btn.addEventListener('click', (e) => {
            e.stopPropagation();
            this.toggleSidebar();
        });

        // Click en overlay
        overlay.addEventListener('click', () => {
            this.closeSidebar();
        });

        // Click en items del menú (cerrar en móvil)
        const menuItems = sidebar.querySelectorAll('.menu-item');
        menuItems.forEach(item => {
            item.addEventListener('click', () => {
                if (window.innerWidth <= 768) {
                    setTimeout(() => this.closeSidebar(), 200);
                }
            });
        });

        // Tecla ESC
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && sidebar.classList.contains('active')) {
                this.closeSidebar();
            }
        });

        // Resize
        window.addEventListener('resize', () => {
            if (window.innerWidth > 768) {
                this.closeSidebar();
            }
        });
    },

    toggleSidebar() {
        const sidebar = document.querySelector('.sidebar');
        if (!sidebar) return;

        if (sidebar.classList.contains('active')) {
            this.closeSidebar();
        } else {
            this.openSidebar();
        }
    },

    openSidebar() {
        const btn = document.getElementById('mobileMenuBtn');
        const sidebar = document.querySelector('.sidebar');
        const overlay = document.getElementById('sidebarOverlay');

        if (!sidebar) return;

        sidebar.classList.add('active');
        if (overlay) overlay.classList.add('active');
        if (btn) btn.classList.add('active');

        document.body.style.overflow = 'hidden';
    },

    closeSidebar() {
        const btn = document.getElementById('mobileMenuBtn');
        const sidebar = document.querySelector('.sidebar');
        const overlay = document.getElementById('sidebarOverlay');

        if (!sidebar) return;

        sidebar.classList.remove('active');
        if (overlay) overlay.classList.remove('active');
        if (btn) btn.classList.remove('active');

        document.body.style.overflow = '';
    }
};

// Inicializar cuando el DOM esté listo
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        ResponsiveMenu.init();
    });
} else {
    // DOM ya está listo
    ResponsiveMenu.init();
}

// Exportar para uso global
window.ResponsiveMenu = ResponsiveMenu;
