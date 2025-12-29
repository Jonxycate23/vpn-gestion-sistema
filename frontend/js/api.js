// Cliente de API
const API = {
    async request(endpoint, options = {}) {
        const url = `${CONFIG.API_URL}${endpoint}`;
        const token = TokenStorage.get();
        
        const headers = {
            'Content-Type': 'application/json',
            ...options.headers
        };
        
        if (token) {
            headers['Authorization'] = `Bearer ${token}`;
        }
        
        try {
            showLoading();
            const response = await fetch(url, {
                ...options,
                headers
            });
            
            if (response.status === 401) {
                // Token inválido o expirado
                Auth.logout();
                return null;
            }
            
            const data = await response.json();
            
            if (!response.ok) {
                throw new Error(data.detail || 'Error en la petición');
            }
            
            return data;
        } catch (error) {
            console.error('API Error:', error);
            showError(error.message);
            throw error;
        } finally {
            hideLoading();
        }
    },
    
    get(endpoint) {
        return this.request(endpoint);
    },
    
    post(endpoint, data) {
        return this.request(endpoint, {
            method: 'POST',
            body: JSON.stringify(data)
        });
    },
    
    put(endpoint, data) {
        return this.request(endpoint, {
            method: 'PUT',
            body: JSON.stringify(data)
        });
    },
    
    delete(endpoint) {
        return this.request(endpoint, {
            method: 'DELETE'
        });
    }
};

// Utilidades UI
function showLoading() {
    document.getElementById('loadingOverlay').classList.add('active');
}

function hideLoading() {
    document.getElementById('loadingOverlay').classList.remove('active');
}

function showError(message) {
    alert('Error: ' + message);
}

function showSuccess(message) {
    alert('Éxito: ' + message);
}

function showModal(title, content) {
    const modal = document.getElementById('modal');
    document.getElementById('modalTitle').textContent = title;
    document.getElementById('modalBody').innerHTML = content;
    modal.classList.add('active');
}

function hideModal() {
    document.getElementById('modal').classList.remove('active');
}

// Formateo de fechas
function formatDate(dateString) {
    if (!dateString) return '-';
    const date = new Date(dateString);
    return date.toLocaleDateString('es-GT');
}

// Formateo de estado
function getStatusBadge(status) {
    const statusMap = {
        'ACTIVO': '<span class="status-badge status-activo">Activo</span>',
        'POR_VENCER': '<span class="status-badge status-por-vencer">Por Vencer</span>',
        'VENCIDO': '<span class="status-badge status-vencido">Vencido</span>',
        'BLOQUEADO': '<span class="status-badge status-bloqueado">Bloqueado</span>',
        'DESBLOQUEADO': '<span class="status-badge status-activo">Desbloqueado</span>',
        'APROBADA': '<span class="status-badge status-aprobada">Aprobada</span>',
        'RECHAZADA': '<span class="status-badge status-rechazada">Rechazada</span>'
    };
    return statusMap[status] || status;
}
