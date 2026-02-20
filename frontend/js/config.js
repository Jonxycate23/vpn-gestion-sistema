// Configuración de la aplicación
const CONFIG = {
    // Si estamos en el servidor Ubuntu, usamos '/api' para que pase por el proxy de Nginx.
    // Si estamos en localhost, usamos el puerto 8000 directamente.
    API_URL: window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1'
        ? 'http://localhost:8000/api'
        : '/api',
    TOKEN_KEY: 'vpn_token',
    USER_KEY: 'vpn_user'
};

// Almacenamiento de token
const TokenStorage = {
    set: (token) => localStorage.setItem(CONFIG.TOKEN_KEY, token),
    get: () => localStorage.getItem(CONFIG.TOKEN_KEY),
    remove: () => localStorage.removeItem(CONFIG.TOKEN_KEY),
    exists: () => !!localStorage.getItem(CONFIG.TOKEN_KEY)
};

// Almacenamiento de usuario
const UserStorage = {
    set: (user) => localStorage.setItem(CONFIG.USER_KEY, JSON.stringify(user)),
    get: () => {
        const user = localStorage.getItem(CONFIG.USER_KEY);
        return user ? JSON.parse(user) : null;
    },
    remove: () => localStorage.removeItem(CONFIG.USER_KEY)
};