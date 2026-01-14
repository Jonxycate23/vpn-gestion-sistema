// 🎨 ANIMACIÓN DE CÍRCULOS DE PROGRESO
// 📂 Ubicación: frontend/js/dashboard-circle-animation.js
// ✅ Anima los círculos cuando se cargan los datos

const CircleAnimator = {
    /**
     * Animar un círculo de progreso
     * @param {HTMLElement} circle - Elemento .progress-circle
     * @param {number} value - Valor a mostrar
     * @param {number} max - Valor máximo (para calcular porcentaje)
     */
    animate(circle, value, max = 100) {
        const progressCircle = circle.querySelector('.circle-progress');
        const valueEl = circle.querySelector('.progress-value');
        
        if (!progressCircle || !valueEl) return;
        
        // Calcular porcentaje
        const percentage = max > 0 ? (value / max) * 100 : 0;
        
        // Circunferencia del círculo (2πr donde r=45)
        const circumference = 283;
        
        // Calcular offset basado en el porcentaje
        const offset = circumference - (circumference * percentage) / 100;
        
        // Animar el círculo
        setTimeout(() => {
            progressCircle.style.strokeDashoffset = offset;
        }, 100);
        
        // Animar el número
        this.animateNumber(valueEl, 0, value, 1500);
    },
    
    /**
     * Animar un número de 0 al valor final
     */
    animateNumber(element, start, end, duration) {
        const startTime = performance.now();
        
        const updateNumber = (currentTime) => {
            const elapsed = currentTime - startTime;
            const progress = Math.min(elapsed / duration, 1);
            
            // Ease out cubic
            const easeProgress = 1 - Math.pow(1 - progress, 3);
            
            const currentValue = Math.floor(start + (end - start) * easeProgress);
            element.textContent = currentValue;
            
            if (progress < 1) {
                requestAnimationFrame(updateNumber);
            } else {
                element.textContent = end; // Asegurar valor final exacto
            }
        };
        
        requestAnimationFrame(updateNumber);
    },
    
    /**
     * Animar todas las cartas cuando se cargan los datos
     */
    animateAllCards() {
        // Esperar a que el DOM esté listo
        setTimeout(() => {
            // Cartas de años (animar como porcentaje visual)
            const cartas2026 = document.querySelector('.cartas-2026 .progress-circle');
            const cartas2025 = document.querySelector('.cartas-2025 .progress-circle');
            const cartas2024 = document.querySelector('.cartas-2024 .progress-circle');
            const pendientes = document.querySelector('.pendientes .progress-circle');
            
            // Obtener valores reales del DOM
            const val2026 = parseInt(document.querySelector('.cartas-2026 .progress-value')?.textContent || 0);
            const val2025 = parseInt(document.querySelector('.cartas-2025 .progress-value')?.textContent || 0);
            const val2024 = parseInt(document.querySelector('.cartas-2024 .progress-value')?.textContent || 0);
            const valPendientes = parseInt(document.querySelector('.pendientes .progress-value')?.textContent || 0);
            
            // Encontrar el máximo para calcular porcentajes relativos
            const maxValue = Math.max(val2026, val2025, val2024, valPendientes, 1);
            
            // Animar cada círculo
            if (cartas2026) this.animate(cartas2026, val2026, maxValue);
            if (cartas2025) this.animate(cartas2025, val2025, maxValue);
            if (cartas2024) this.animate(cartas2024, val2024, maxValue);
            if (pendientes) this.animate(pendientes, valPendientes, maxValue);
            
            // Animar valores de estados (activos, vencidos, etc.)
            this.animateStateCards();
            
        }, 500);
    },
    
    /**
     * Animar cards de estado (activos, vencidos, bloqueados, cancelados)
     */
    animateStateCards() {
        const stateCards = [
            { selector: '.estado-card.activos .estado-value' },
            { selector: '.estado-card.vencidos .estado-value' },
            { selector: '.estado-card.bloqueados .estado-value' },
            { selector: '.estado-card.cancelados .estado-value' }
        ];
        
        stateCards.forEach((card, index) => {
            const element = document.querySelector(card.selector);
            if (element) {
                const value = parseInt(element.textContent || 0);
                // Delay progresivo para efecto cascada
                setTimeout(() => {
                    this.animateNumber(element, 0, value, 1200);
                }, index * 150);
            }
        });
    }
};

// ========================================
// INTEGRACIÓN CON DASHBOARD
// ========================================

// Modificar el dashboard.js para incluir la animación
if (typeof DashboardAsperos !== 'undefined') {
    const originalLoadAlertasInteligentes = DashboardAsperos.loadAlertasInteligentes;
    
    DashboardAsperos.loadAlertasInteligentes = async function() {
        await originalLoadAlertasInteligentes.call(this);
        
        // Animar círculos después de renderizar
        CircleAnimator.animateAllCards();
    };
}

// También animar cuando se refresca el dashboard
document.addEventListener('DOMContentLoaded', () => {
    const refreshBtn = document.getElementById('refreshDashboard');
    if (refreshBtn) {
        refreshBtn.addEventListener('click', () => {
            setTimeout(() => {
                CircleAnimator.animateAllCards();
            }, 300);
        });
    }
});

console.log('✅ Circle Animator cargado');