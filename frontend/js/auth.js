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

        // Limpiar campos de login
        const loginForm = document.getElementById('loginForm');
        if (loginForm) loginForm.reset();
    },

    showMainApp() {
        document.getElementById('loginScreen').style.display = 'none';
        document.getElementById('mainApp').style.display = 'grid';

        const user = UserStorage.get();
        if (user) {
            // ✅ Actualizar información del usuario en el header
            document.getElementById('userName').textContent = user.nombre_completo;
            document.getElementById('userRole').textContent = user.rol;

            // ✅ ACTUALIZAR MENÚ SEGÚN ROL
            this.actualizarMenuSegunRol(user.rol);

            // ✅ REDIRIGIR AL DASHBOARD SIEMPRE DESPUÉS DEL LOGIN
            App.showView('dashboard');
        }
    },

    // ✅ NUEVA FUNCIÓN: Actualizar menú según rol del usuario
    actualizarMenuSegunRol(rol) {
        const menuUsuarios = document.querySelector('[data-view="usuarios"]');

        if (!menuUsuarios) {
            console.warn('⚠️ Elemento del menú "usuarios" no encontrado');
            return;
        }

        const liUsuarios = menuUsuarios.closest('li');

        if (rol === 'SUPERADMIN') {
            // SUPERADMIN puede ver todo
            if (liUsuarios) {
                liUsuarios.style.display = '';
            }
            console.log('✅ Menú de Usuarios VISIBLE para SUPERADMIN');
        } else {
            // ADMIN no puede ver "Usuarios del Sistema"
            if (liUsuarios) {
                liUsuarios.style.display = 'none';
            }
            console.log('🚫 Menú de Usuarios OCULTO para ADMIN');
        }
    },

    checkAuth() {
        if (TokenStorage.exists()) {
            this.showMainApp();
        } else {
            this.showLoginScreen();
        }
    },

    // ✅ NUEVA FUNCIÓN: Verificar si el usuario tiene permiso para una vista
    tienePermisoParaVista(viewName) {
        const user = UserStorage.get();
        if (!user) return false;

        // Solo SUPERADMIN puede acceder a "usuarios"
        if (viewName === 'usuarios' && user.rol !== 'SUPERADMIN') {
            return false;
        }

        // Todas las demás vistas están disponibles para todos
        return true;
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

