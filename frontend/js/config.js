// Configuración de la aplicación
const CONFIG = {
    // ✅ URL Dinámica: Funciona en localhost y en servidor (asumiendo puerto 8000)
    API_URL: `${window.location.protocol}//${window.location.hostname}:8000/api`,
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
