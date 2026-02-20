"""
Utilidad para obtener la fecha/hora según la zona horaria local del sistema (Guatemala UTC-6).

PROBLEMA: En producción el servidor corre en UTC. date.today() en UTC puede devolver
mañana cuando son las 18:00+ en Guatemala (UTC-6), causando que dias_restantes
sea -1 en lugar de 0 para accesos que vencen hoy.

SOLUCIÓN: Usar la zona horaria local (UTC-6 Guatemala) para calcular la fecha de hoy.
"""
from datetime import datetime, timezone, timedelta, date

# Zona horaria de Guatemala (UTC-6, sin cambio de horario)
GT_TZ = timezone(timedelta(hours=-6))


def hoy_gt() -> date:
    """Retorna la fecha de HOY en la zona horaria de Guatemala (UTC-6)."""
    return datetime.now(GT_TZ).date()
