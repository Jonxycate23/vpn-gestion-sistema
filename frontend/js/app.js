// Archivo principal de la aplicación - CORREGIDO
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
                
                // Remover active de todos
                menuItems.forEach(mi => mi.classList.remove('active'));
                
                // Agregar active al clickeado
                item.classList.add('active');
                
                // Mostrar vista correspondiente
                const viewName = item.dataset.view;
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
        this.currentView = viewName;
        
        // Ocultar todas las vistas
        document.querySelectorAll('.view').forEach(view => {
            view.classList.remove('active');
        });
        
        // Mostrar vista seleccionada
        const view = document.getElementById(`${viewName}View`);
        if (view) {
            view.classList.add('active');
            
            // Cargar datos de la vista
            this.loadViewData(viewName);
        }
    },
    
    loadViewData(viewName) {
        try {
            switch(viewName) {
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
                    if (typeof Usuarios !== 'undefined' && Usuarios.load) {
                        Usuarios.load();
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
