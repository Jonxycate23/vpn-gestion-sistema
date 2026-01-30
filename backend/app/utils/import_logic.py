"""
Lógica de Importación Masiva de Excel
Adaptada para ser usada desde la API
"""

import pandas as pd
import psycopg2
from datetime import datetime, timedelta
import re
from typing import Optional, Tuple
import warnings
import io
from app.core.config import settings

warnings.filterwarnings('ignore')

# ========================================
# CONSTANTES
# ========================================

USUARIO_IMPORTACION_ID = 1  # ID por defecto para importaciones
FECHA_FICTICIA = datetime(2024, 1, 1)

# ========================================
# FUNCIONES AUXILIARES
# ========================================

def limpiar_texto(texto) -> Optional[str]:
    """Limpia y normaliza texto"""
    if pd.isna(texto) or texto == '' or str(texto).strip() == '':
        return None
    texto_limpio = str(texto).strip()
    if texto_limpio == '' or texto_limpio.upper() in ['N/A', 'NAN']:
        return None
    return texto_limpio

def separar_nombre_completo(nombre_completo: str) -> Tuple[str, str]:
    """Separa nombre completo en nombres y apellidos"""
    if not nombre_completo or pd.isna(nombre_completo):
        return "Sin Nombre", "Sin Apellido"
    
    nombre_limpio = str(nombre_completo).strip()
    
    if nombre_limpio == '' or nombre_limpio.upper() in ['N/A', 'NAN', 'NINGUNO']:
        return "Sin Nombre", "Sin Apellido"
    
    partes = nombre_limpio.split()
    
    if len(partes) == 0:
        return "Sin Nombre", "Sin Apellido"
    elif len(partes) == 1:
        return partes[0], "Sin Apellido"
    elif len(partes) == 2:
        return partes[0], partes[1]
    elif len(partes) == 3:
        return " ".join(partes[:2]), partes[2]
    else:
        mitad = len(partes) // 2
        return " ".join(partes[:mitad]), " ".join(partes[mitad:])

def validar_dpi(dpi) -> Optional[str]:
    """Valida y normaliza DPI (13 dígitos)"""
    if pd.isna(dpi):
        return None
    dpi_str = str(dpi).strip().replace(' ', '')
    dpi_str = re.sub(r'[^\d]', '', dpi_str)
    if len(dpi_str) == 13 and dpi_str.isdigit():
        return dpi_str
    if len(dpi_str) > 0 and dpi_str.isdigit():
        return dpi_str.zfill(13)
    return None

def validar_nip(nip) -> Optional[str]:
    """Valida y normaliza NIP (formato: 12345-P)"""
    if pd.isna(nip):
        return None
    nip_str = str(nip).strip().upper()
    if nip_str == '' or nip_str == 'NAN':
        return None
    if re.match(r'^\d{5}-P$', nip_str):
        return nip_str
    numeros = re.sub(r'[^\d]', '', nip_str)
    if numeros and len(numeros) >= 1:
        nip_limpio = numeros[:5].zfill(5)
        return f"{nip_limpio}-P"
    return None

def validar_telefono(telefono) -> Optional[str]:
    """Valida teléfono (8 dígitos)"""
    if pd.isna(telefono):
        return None
    tel_str = str(telefono).strip()
    numeros = re.sub(r'[^\d]', '', tel_str)
    if len(numeros) == 8:
        return numeros
    elif len(numeros) > 8:
        return numeros[:8]
    return None

def normalizar_tipo_solicitud(tipo: str) -> str:
    """Normaliza tipo de solicitud"""
    if not tipo or pd.isna(tipo):
        return 'CREACION'
    tipo_upper = str(tipo).strip().upper()
    if 'RENOV' in tipo_upper or 'ACTUAL' in tipo_upper:
        return 'ACTUALIZACION'
    return 'CREACION'

def parsear_fecha(fecha) -> Optional[datetime]:
    """Parsea fecha en múltiples formatos"""
    if pd.isna(fecha):
        return None
    
    if isinstance(fecha, datetime):
        return fecha
    
    if isinstance(fecha, str):
        formatos = ['%d/%m/%Y', '%Y-%m-%d', '%d-%m-%Y']
        for formato in formatos:
            try:
                return datetime.strptime(fecha, formato)
            except:
                continue
    
    return None

def determinar_estado_solicitud(row) -> dict:
    """
    Determina estado de solicitud según Excel
    """
    estado_excel = limpiar_texto(row.get('Status'))
    
    if not estado_excel:
        return {
            'estado_solicitud': 'APROBADA',
            'crear_carta': True,
            'crear_acceso': True,
            'necesita_bloqueo': False,
            'motivo_bloqueo': None
        }
    
    estado_upper = estado_excel.upper()
    
    if 'CANCEL' in estado_upper:
        return {
            'estado_solicitud': 'CANCELADA',
            'crear_carta': False,
            'crear_acceso': False,
            'necesita_bloqueo': False,
            'motivo_bloqueo': None
        }
    
    if 'BLOQ' in estado_upper:
        return {
            'estado_solicitud': 'APROBADA',
            'crear_carta': True,
            'crear_acceso': True,
            'necesita_bloqueo': True,
            'motivo_bloqueo': f"Importado con estado: {estado_excel}"
        }
    
    if 'TERMINADO' in estado_upper or 'TERMINADA' in estado_upper or 'TERMINO' in estado_upper:
        return {
            'estado_solicitud': 'APROBADA',
            'crear_carta': True,
            'crear_acceso': True,
            'necesita_bloqueo': False,
            'motivo_bloqueo': None
        }
    
    if 'PENDIENTE' in estado_upper:
        return {
            'estado_solicitud': 'PENDIENTE',
            'crear_carta': False,
            'crear_acceso': False,
            'necesita_bloqueo': False,
            'motivo_bloqueo': None
        }
    
    return {
        'estado_solicitud': 'APROBADA',
        'crear_carta': True,
        'crear_acceso': True,
        'necesita_bloqueo': False,
        'motivo_bloqueo': None
    }

def extraer_numero_carta(valor) -> Optional[int]:
    if pd.isna(valor): return None
    texto = str(valor).strip().upper()
    if texto in ['', 'NAN', 'CURSO', 'CANCELADA', 'NINGUNO']: return None
    numeros = re.findall(r'\d+', texto)
    if numeros:
        try:
            return int(numeros[0])
        except:
            pass
    return None

def extraer_anio_carta(valor) -> Optional[int]:
    if pd.isna(valor): return None
    texto = str(valor).strip().upper()
    if texto in ['', 'NAN', 'CURSO', 'CANCELADA', '5025', 'NINGUNO']: return None
    try:
        anio = int(float(texto))
        if anio == 5025: return 2025
        if 2020 <= anio <= 2030: return anio
        if 20 <= anio <= 30: return 2000 + anio
    except:
        pass
    return None

class ImportadorVPN:
    def __init__(self, archivo_bytes):
        self.archivo_bytes = archivo_bytes
        self.conn = None
        self.cursor = None
        self.estadisticas = {
            'total': 0, 'exitosos': 0, 'fallidos': 0, 'duplicados_omitidos': 0,
            'personas_nuevas': 0, 'personas_actualizadas': 0, 'personas_reutilizadas': 0,
            'solicitudes_creadas': 0, 'solicitudes_aprobadas': 0, 'solicitudes_pendientes': 0,
            'solicitudes_canceladas': 0, 'accesos_creados': 0, 'cartas_creadas': 0,
            'bloqueos_creados': 0, 'errores': []
        }
        self.contadores_carta = {}

    def conectar_bd(self):
        try:
            # Psycopg2 no soporta el formato 'postgresql+psycopg2://'
            # Es necesario limpiarlo o usar el formato estándar 'postgresql://'
            db_url = settings.DATABASE_URL
            if db_url.startswith("postgresql+psycopg2://"):
                db_url = db_url.replace("postgresql+psycopg2://", "postgresql://")
            
            self.conn = psycopg2.connect(db_url)
            self.cursor = self.conn.cursor()
        except Exception as e:
            raise Exception(f"Error conectando a BD: {str(e)}")

    def cargar_excel(self):
        try:
            # Leer bytes directamente
            df = pd.read_excel(io.BytesIO(self.archivo_bytes))
            if df.empty:
                raise ValueError("El archivo Excel está vacío")
            self.estadisticas['total'] = len(df)
            return df
        except Exception as e:
            raise ValueError(f"Error leyendo archivo Excel: {str(e)}")

    def obtener_proximo_numero_carta(self, anio: int) -> int:
        if anio in self.contadores_carta:
            self.contadores_carta[anio] += 1
            return self.contadores_carta[anio]
        
        self.cursor.execute("""
            SELECT MAX(numero_carta) FROM cartas_responsabilidad 
            WHERE anio_carta = %s AND numero_carta IS NOT NULL
        """, (anio,))
        resultado = self.cursor.fetchone()[0]
        max_actual = resultado if resultado is not None else 0
        proximo = max_actual + 1
        self.contadores_carta[anio] = proximo
        return proximo

    def obtener_o_crear_persona(self, row) -> int:
        nip = validar_nip(row.get('NIP'))
        dpi = validar_dpi(row.get('DPI'))
        
        nombre_completo = None
        posibles = ['Nombres y Apellidos', 'Nombre', 'NOMBRE', 'Nombres', 'NombreCompleto', 'Nombre Completo']
        for col in posibles:
            if col in row and not pd.isna(row.get(col)):
                nombre_completo = limpiar_texto(row.get(col))
                if nombre_completo: break
        
        if not nombre_completo: nombre_completo = "Desconocido"
        nombres, apellidos = separar_nombre_completo(nombre_completo)

        if nip:
            self.cursor.execute("SELECT id FROM personas WHERE nip = %s", (nip,))
            res = self.cursor.fetchone()
            if res:
                pid = res[0]
                self.cursor.execute("""
                    UPDATE personas SET dpi=COALESCE(%s, dpi), nombres=COALESCE(%s, nombres),
                    apellidos=COALESCE(%s, apellidos), institucion=COALESCE(%s, institucion),
                    cargo=COALESCE(%s, cargo), telefono=COALESCE(%s, telefono), email=COALESCE(%s, email)
                    WHERE id=%s
                """, (dpi, nombres, apellidos, limpiar_texto(row.get('Procedencia')),
                      limpiar_texto(row.get('Grado')), validar_telefono(row.get('Teléfono')),
                      limpiar_texto(row.get('Email')), pid))
                self.estadisticas['personas_actualizadas'] += 1
                return pid

        if dpi:
            self.cursor.execute("SELECT id FROM personas WHERE dpi = %s", (dpi,))
            res = self.cursor.fetchone()
            if res:
                self.estadisticas['personas_reutilizadas'] += 1
                return res[0]

        if not dpi:
            import random
            dpi = f"9999{random.randint(100000000, 999999999)}"

        self.cursor.execute("""
            INSERT INTO personas (nip, dpi, nombres, apellidos, institucion, cargo, telefono, email)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s) RETURNING id
        """, (nip, dpi, nombres, apellidos, limpiar_texto(row.get('Procedencia')),
              limpiar_texto(row.get('Grado')), validar_telefono(row.get('Teléfono')),
              limpiar_texto(row.get('Email'))))
        
        self.estadisticas['personas_nuevas'] += 1
        return self.cursor.fetchone()[0]

    def procesar(self):
        try:
            self.conectar_bd()
            df = self.cargar_excel()
            
            for idx, row in df.iterrows():
                try:
                    estado_info = determinar_estado_solicitud(row)
                    nip = validar_nip(row.get('NIP'))
                    oficio = limpiar_texto(row.get('Oficio'))

                    if nip and oficio and oficio.upper() != 'S/N':
                        self.cursor.execute("""
                            SELECT s.id FROM solicitudes_vpn s
                            JOIN personas p ON s.persona_id = p.id
                            WHERE p.nip = %s AND s.numero_oficio = %s
                        """, (nip, oficio))
                        if self.cursor.fetchone():
                            self.estadisticas['duplicados_omitidos'] += 1
                            continue

                    persona_id = self.obtener_o_crear_persona(row)
                    
                    # Crear Solicitud
                    fecha_recep = parsear_fecha(row.get('Fecha de recepción')) or parsear_fecha(row.get('Fecha de Carta')) or FECHA_FICTICIA
                    self.cursor.execute("""
                        INSERT INTO solicitudes_vpn (persona_id, numero_oficio, numero_providencia, fecha_recepcion,
                        fecha_solicitud, tipo_solicitud, justificacion, estado, usuario_registro_id)
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s) RETURNING id
                    """, (persona_id, oficio, limpiar_texto(row.get('Providencia')), fecha_recep, fecha_recep,
                          normalizar_tipo_solicitud(row.get('Tipo de requerimiento')), 'Importado desde Excel',
                          estado_info['estado_solicitud'], USUARIO_IMPORTACION_ID))
                    solicitud_id = self.cursor.fetchone()[0]
                    self.estadisticas['solicitudes_creadas'] += 1

                    if estado_info['estado_solicitud'] == 'APROBADA': self.estadisticas['solicitudes_aprobadas'] += 1
                    elif estado_info['estado_solicitud'] == 'PENDIENTE': self.estadisticas['solicitudes_pendientes'] += 1
                    elif estado_info['estado_solicitud'] == 'CANCELADA': self.estadisticas['solicitudes_canceladas'] += 1

                    # Carta
                    if estado_info['crear_carta']:
                        num_carta = extraer_numero_carta(row.get('numero_carta'))
                        anio_carta = extraer_anio_carta(row.get('anio_carta'))
                        
                        if not num_carta and anio_carta:
                            num_carta = self.obtener_proximo_numero_carta(anio_carta)
                        elif num_carta and not anio_carta:
                            anio_carta = datetime.now().year
                        
                        if num_carta and anio_carta:
                            self.cursor.execute("SELECT id FROM cartas_responsabilidad WHERE numero_carta=%s AND anio_carta=%s", (num_carta, anio_carta))
                            if not self.cursor.fetchone():
                                fecha_carta = parsear_fecha(row.get('Fecha de Carta')) or FECHA_FICTICIA
                                self.cursor.execute("""
                                    INSERT INTO cartas_responsabilidad (solicitud_id, tipo, fecha_generacion,
                                    generada_por_usuario_id, numero_carta, anio_carta)
                                    VALUES (%s, 'RESPONSABILIDAD', %s, %s, %s, %s)
                                """, (solicitud_id, fecha_carta, USUARIO_IMPORTACION_ID, num_carta, anio_carta))
                                self.estadisticas['cartas_creadas'] += 1

                    # Acceso
                    acceso_id = None
                    if estado_info['crear_acceso']:
                        fecha_ven = parsear_fecha(row.get('Fecha de Vencimiento'))
                        if not fecha_ven:
                            fecha_base = parsear_fecha(row.get('Fecha de Carta')) or FECHA_FICTICIA
                            fecha_ven = fecha_base + timedelta(days=365)
                        
                        fecha_ini = fecha_ven - timedelta(days=365)
                        dias = (fecha_ven.date() - datetime.now().date()).days
                        estado_vig = 'ACTIVO' if dias > 30 else 'POR_VENCER' if dias > 0 else 'VENCIDO'

                        self.cursor.execute("""
                            INSERT INTO accesos_vpn (solicitud_id, fecha_inicio, fecha_fin, dias_gracia,
                            fecha_fin_con_gracia, estado_vigencia, usuario_creacion_id)
                            VALUES (%s, %s, %s, 0, %s, %s, %s) RETURNING id
                        """, (solicitud_id, fecha_ini, fecha_ven, fecha_ven, estado_vig, USUARIO_IMPORTACION_ID))
                        acceso_id = self.cursor.fetchone()[0]
                        self.estadisticas['accesos_creados'] += 1

                    # Bloqueo
                    if estado_info['necesita_bloqueo'] and acceso_id:
                        self.cursor.execute("""
                            INSERT INTO bloqueos_vpn (acceso_vpn_id, estado, motivo, usuario_id)
                            VALUES (%s, 'BLOQUEADO', %s, %s)
                        """, (acceso_id, estado_info['motivo_bloqueo'], USUARIO_IMPORTACION_ID))
                        self.estadisticas['bloqueos_creados'] += 1

                    self.estadisticas['exitosos'] += 1

                except Exception as e:
                    self.estadisticas['fallidos'] += 1
                    self.estadisticas['errores'].append(f"Fila {row.get('No.', '?')}: {str(e)}")
            
            self.conn.commit()
            return self.estadisticas
            
        except Exception as e:
            if self.conn: self.conn.rollback()
            raise e
        finally:
            if self.cursor: self.cursor.close()
            if self.conn: self.conn.close()
