// Archivo principal de la aplicación
const App = {
    currentView: 'dashboard',

    init() {
        // Verificar autenticación al cargar
        Auth.checkAuth();

        // Setup navigation
        this.setupNavigation();

        // Setup modal close
        this.setupModal();
    },

    setupNavigation() {
        const menuItems = document.querySelectorAll('.menu-item');

        menuItems.forEach(item => {
            item.addEventListener('click', (e) => {
                e.preventDefault();

                const viewName = item.dataset.view;

                // ✅ VERIFICAR PERMISOS ANTES DE CAMBIAR DE VISTA
                if (!Auth.tienePermisoParaVista(viewName)) {
                    showError('⛔ No tienes permiso para acceder a esta sección');
                    console.log(`🚫 Acceso denegado a vista: ${viewName}`);
                    return;
                }

                // Remover active de todos
                menuItems.forEach(mi => mi.classList.remove('active'));

                // Agregar active al clickeado
                item.classList.add('active');

                // Mostrar vista correspondiente
                this.showView(viewName);
            });
        });
    },

    setupModal() {
        const modal = document.getElementById('modal');
        const closeBtn = document.querySelector('.modal-close');

        if (closeBtn) {
            closeBtn.addEventListener('click', hideModal);
        }

        if (modal) {
            modal.addEventListener('click', (e) => {
                if (e.target === modal) {
                    hideModal();
                }
            });
        }
    },

    showView(viewName) {
        // ✅ VERIFICAR PERMISOS
        if (!Auth.tienePermisoParaVista(viewName)) {
            console.log(`🚫 Redirigiendo a dashboard (sin permiso para ${viewName})`);
            viewName = 'dashboard';
        }

        this.currentView = viewName;

        // Ocultar todas las vistas
        document.querySelectorAll('.view').forEach(view => {
            view.classList.remove('active');
        });

        // Actualizar menú activo
        document.querySelectorAll('.menu-item').forEach(item => {
            item.classList.remove('active');
        });

        const activeMenuItem = document.querySelector(`[data-view="${viewName}"]`);
        if (activeMenuItem) {
            activeMenuItem.classList.add('active');
        }

        // ✅ MANEJAR SUBMENU VPN
        const vpnViews = ['solicitudes', 'accesos'];
        const vpnSubmenu = document.getElementById('vpnSubmenu');
        const vpnSection = document.getElementById('vpnMenuSection');

        if (vpnViews.includes(viewName)) {
            // Expandir submenu VPN si estamos en una vista VPN
            if (vpnSubmenu && vpnSection) {
                vpnSubmenu.classList.add('show');
                vpnSubmenu.style.display = 'block';
                vpnSection.classList.add('expanded');
            }
        } else {
            // Colapsar submenu VPN si estamos en otra vista
            if (vpnSubmenu && vpnSection) {
                vpnSubmenu.classList.remove('show');
                vpnSubmenu.style.display = 'none';
                vpnSection.classList.remove('expanded');
            }
        }

        // Mostrar vista seleccionada
        const view = document.getElementById(`${viewName}View`);
        if (view) {
            view.classList.add('active');

            // Cargar datos de la vista
            this.loadViewData(viewName);
        } else {
            console.error(`❌ Vista ${viewName}View no encontrada`);
        }
    },

    loadViewData(viewName) {
        try {
            switch (viewName) {
                case 'dashboard':
                    if (typeof Dashboard !== 'undefined' && Dashboard.load) {
                        Dashboard.load();
                    }
                    break;
                case 'solicitudes':
                    if (typeof Solicitudes !== 'undefined' && Solicitudes.load) {
                        Solicitudes.load();
                    }
                    break;
                case 'accesos':
                    if (typeof Accesos !== 'undefined' && Accesos.load) {
                        Accesos.load();
                    }
                    break;
                case 'usuarios':
                    // ✅ VERIFICACIÓN ADICIONAL para usuarios
                    const user = UserStorage.get();
                    if (user && user.rol === 'SUPERADMIN') {
                        if (typeof Usuarios !== 'undefined' && Usuarios.load) {
                            Usuarios.load();
                        }
                    } else {
                        console.log('🚫 Acceso denegado a módulo de usuarios');
                        this.showView('dashboard');
                    }
                    break;
            }
        } catch (error) {
            console.error(`Error loading ${viewName}:`, error);
        }
    }
};

// Inicializar aplicación cuando el DOM esté listo
document.addEventListener('DOMContentLoaded', () => {
    App.init();
});

// ========================================
// FUNCIÓN PARA TOGGLE DEL MENÚ VPN
// ========================================
function toggleVpnMenu() {
    const vpnSubmenu = document.getElementById('vpnSubmenu');
    const vpnSection = document.getElementById('vpnMenuSection');

    if (!vpnSubmenu || !vpnSection) return;

    const isExpanded = vpnSection.classList.contains('expanded');

    if (isExpanded) {
        // Colapsar
        vpnSubmenu.classList.remove('show');
        vpnSubmenu.style.display = 'none';
        vpnSection.classList.remove('expanded');
    } else {
        // Expandir
        vpnSubmenu.classList.add('show');
        vpnSubmenu.style.display = 'block';
        vpnSection.classList.add('expanded');
    }
}