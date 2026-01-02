// Cliente de API
const API = {
    BASE_URL: CONFIG.API_URL, // ✅ AGREGADO
    
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
                // Manejar error 422 correctamente
                let errorMessage = 'Error en la petición';
                
                if (data.detail) {
                    if (typeof data.detail === 'string') {
                        errorMessage = data.detail;
                    } else if (Array.isArray(data.detail)) {
                        errorMessage = data.detail.map(err => err.msg).join(', ');
                    } else {
                        errorMessage = JSON.stringify(data.detail);
                    }
                }
                
                throw new Error(errorMessage);
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
    },
    
    // ✅ NUEVA FUNCIÓN PARA DESCARGAR ARCHIVOS
    async downloadFile(endpoint, filename) {
        try {
            const url = `${CONFIG.API_URL}${endpoint}`;
            const token = TokenStorage.get();
            
            if (!token) {
                throw new Error('No hay sesión activa');
            }
            
            showLoading();
            
            const response = await fetch(url, {
                method: 'GET',
                headers: {
                    'Authorization': `Bearer ${token}`
                }
            });
            
            if (response.status === 401) {
                Auth.logout();
                throw new Error('Sesión expirada. Por favor inicia sesión nuevamente.');
            }
            
            if (!response.ok) {
                const errorText = await response.text();
                throw new Error(`Error ${response.status}: ${errorText}`);
            }
            
            const blob = await response.blob();
            const blobUrl = window.URL.createObjectURL(blob);
            
            const a = document.createElement('a');
            a.href = blobUrl;
            a.download = filename;
            document.body.appendChild(a);
            a.click();
            
            window.URL.revokeObjectURL(blobUrl);
            document.body.removeChild(a);
            
            hideLoading();
            return true;
        } catch (error) {
            hideLoading();
            console.error('Download error:', error);
            throw error;
        }
    }
};

// Utilidades UI
function showLoading() {
    const overlay = document.getElementById('loadingOverlay');
    if (overlay) {
        overlay.classList.add('active');
    }
}

function hideLoading() {
    const overlay = document.getElementById('loadingOverlay');
    if (overlay) {
        overlay.classList.remove('active');
    }
}

function showError(message) {
    alert('❌ Error: ' + message);
}

function showSuccess(message) {
    alert('✅ ' + message);
}

function showModal(title, content) {
    const modal = document.getElementById('modal');
    const modalTitle = document.getElementById('modalTitle');
    const modalBody = document.getElementById('modalBody');
    
    if (modal && modalTitle && modalBody) {
        modalTitle.textContent = title;
        modalBody.innerHTML = content;
        modal.classList.add('active');
    } else {
        console.error('Modal elements not found!');
    }
}

function hideModal() {
    const modal = document.getElementById('modal');
    if (modal) {
        modal.classList.remove('active');
    }
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
        'PENDIENTE': '<span class="status-badge status-por-vencer">Pendiente</span>',
        'RECHAZADA': '<span class="status-badge status-rechazada">Rechazada</span>',
        'CANCELADA': '<span class="status-badge status-vencido">Cancelada</span>',
        'NUEVA': '<span class="status-badge status-activo">Nueva</span>',
        'RENOVACION': '<span class="status-badge status-warning">Renovación</span>'
    };
    return statusMap[status] || `<span class="status-badge">${status}</span>`;
}