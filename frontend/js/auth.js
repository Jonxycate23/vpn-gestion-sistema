// Módulo de Autenticación
const Auth = {
    async login(username, password) {
        try {
            const data = await API.post('/auth/login', { username, password });
            
            if (data && data.access_token) {
                TokenStorage.set(data.access_token);
                UserStorage.set(data.usuario);
                this.showMainApp();
                return true;
            }
            return false;
        } catch (error) {
            return false;
        }
    },
    
    logout() {
        TokenStorage.remove();
        UserStorage.remove();
        this.showLoginScreen();
    },
    
    showLoginScreen() {
        document.getElementById('loginScreen').style.display = 'flex';
        document.getElementById('mainApp').style.display = 'none';
    },
    
    showMainApp() {
        document.getElementById('loginScreen').style.display = 'none';
        document.getElementById('mainApp').style.display = 'grid';
        
        const user = UserStorage.get();
        if (user) {
            document.getElementById('userName').textContent = user.nombre_completo;
            document.getElementById('userRole').textContent = user.rol;
        }
        
        // Cargar dashboard por defecto
        Dashboard.load();
    },
    
    checkAuth() {
        if (TokenStorage.exists()) {
            this.showMainApp();
        } else {
            this.showLoginScreen();
        }
    }
};

// Event Listeners de Login
document.getElementById('loginForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const username = document.getElementById('username').value;
    const password = document.getElementById('password').value;
    const errorDiv = document.getElementById('loginError');
    
    errorDiv.classList.remove('active');
    
    const success = await Auth.login(username, password);
    
    if (!success) {
        errorDiv.textContent = 'Usuario o contraseña incorrectos';
        errorDiv.classList.add('active');
    }
});

document.getElementById('logoutBtn').addEventListener('click', () => {
    if (confirm('¿Cerrar sesión?')) {
        Auth.logout();
    }
});
