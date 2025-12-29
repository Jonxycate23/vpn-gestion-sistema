// Archivo principal de la aplicación
const App = {
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
        
        closeBtn.addEventListener('click', hideModal);
        
        modal.addEventListener('click', (e) => {
            if (e.target === modal) {
                hideModal();
            }
        });
    },
    
    showView(viewName) {
        // Ocultar todas las vistas
        document.querySelectorAll('.view').forEach(view => {
            view.classList.remove('active');
        });
        
        // Mostrar vista seleccionada
        const view = document.getElementById(`${viewName}View`);
        if (view) {
            view.classList.add('active');
            
            // Cargar datos de la vista
            switch(viewName) {
                case 'dashboard':
                    Dashboard.load();
                    break;
                case 'personas':
                    Personas.load();
                    break;
                case 'solicitudes':
                    Solicitudes.load();
                    break;
                case 'accesos':
                    Accesos.load();
                    break;
            }
        }
    }
};

// Inicializar aplicación cuando el DOM esté listo
document.addEventListener('DOMContentLoaded', () => {
    App.init();
});
