"""
Script de Importación Masiva - VERSIÓN FINAL CORREGIDA
✅ Usa valores correctos: NUEVA, RENOVACION (no CREACION, ACTUALIZACION)
"""

import pandas as pd
import psycopg2
from datetime import datetime, timedelta
import re
from typing import Optional, Tuple
import warnings
import os
warnings.filterwarnings('ignore')

# ========================================
# CONFIGURACIÓN
# ========================================

DB_CONFIG = {
    'host': 'localhost',
    'port': 5432,
    'database': 'vpn_gestion',
    'user': 'postgres',              # ✅ Usuario correcto
    'password': 'Pantera.25042009'   # ✅ Password correcto
}

EXCEL_FILE = r'C:\Users\HP\Desktop\VPN-PROJECT\datos.xlsx'
USUARIO_IMPORTACION_ID = 1
FECHA_FICTICIA = datetime(2024, 1, 1)

# ========================================
# FUNCIONES AUXILIARES
# ========================================

def limpiar_texto(texto) -> Optional[str]:
    """Limpia y normaliza texto"""
    if pd.isna(texto) or texto == '' or str(texto).strip() == '':
        return None
    texto_limpio = str(texto).strip()
    if texto_limpio == '' or texto_limpio.upper() == 'N/A':
        return None
    return texto_limpio

def separar_nombre_completo(nombre_completo: str) -> Tuple[str, str]:
    """Separa nombre completo en nombres y apellidos"""
    if not nombre_completo:
        return "Sin Nombre", "Sin Apellido"
    partes = nombre_completo.strip().split()
    if len(partes) == 1:
        return partes[0], "Sin Apellido"
    elif len(partes) == 2:
        return partes[0], partes[1]
    elif len(partes) == 3:
        return partes[0], " ".join(partes[1:])
    else:
        return " ".join(partes[:2]), " ".join(partes[2:])

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
    """
    ✅ CORREGIDO: Usa valores que existen en la BD
    
    BD acepta: 'NUEVA', 'RENOVACION'
    """
    if pd.isna(tipo) or not tipo:
        return 'NUEVA'  # ✅ Cambiado de CREACION a NUEVA
    
    tipo_upper = str(tipo).upper().strip()
    
    # Mapear variaciones a NUEVA
    if any(x in tipo_upper for x in ['CREACION', 'CREAR', 'NUEVA', 'NUEVO', 'NEW']):
        return 'NUEVA'
    
    # Mapear variaciones a RENOVACION
    elif any(x in tipo_upper for x in ['ACTUALIZACION', 'RENOVACION', 'RENOV', 'ACTUALIZAR', 'UPDATE']):
        return 'RENOVACION'
    
    # Default
    return 'NUEVA'

def interpretar_estado(status: str) -> dict:
    """
    Interpreta el estado del Excel
    
    MAPEO CORRECTO:
    - "Terminado/Terminada/Aprobada" → APROBADA (con acceso)
    - "Pendiente" → PENDIENTE (sin acceso)
    - "Bloqueado/Cancelado/Otro" → CANCELADA (con acceso bloqueado)
    """
    if pd.isna(status) or not status or str(status).strip() == '':
        return {
            'estado_solicitud': 'CANCELADA',
            'necesita_acceso': False,
            'necesita_bloqueo': False,
            'motivo_bloqueo': 'Importado de Excel sin status definido'
        }
    
    status_upper = str(status).upper().strip()
    
    if 'TERMINADO' in status_upper or 'TERMINADA' in status_upper or 'APROBADA' in status_upper or 'APROBADO' in status_upper:
        return {
            'estado_solicitud': 'APROBADA',
            'necesita_acceso': True,
            'necesita_bloqueo': False,
            'motivo_bloqueo': None
        }
    elif 'PENDIENTE' in status_upper:
        return {
            'estado_solicitud': 'PENDIENTE',
            'necesita_acceso': False,
            'necesita_bloqueo': False,
            'motivo_bloqueo': None
        }
    else:
        return {
            'estado_solicitud': 'CANCELADA',
            'necesita_acceso': True,
            'necesita_bloqueo': True,
            'motivo_bloqueo': f'Importado de Excel con status: {status}'
        }

def parsear_fecha(fecha) -> Optional[datetime]:
    """Parsea fecha en múltiples formatos"""
    if pd.isna(fecha):
        return None
    if isinstance(fecha, datetime):
        return fecha
    fecha_str = str(fecha).strip()
    if fecha_str == '' or fecha_str.upper() == 'NAN':
        return None
    
    formatos = [
        '%d/%m/%Y', '%Y-%m-%d', '%d-%m-%Y',
        '%m/%d/%Y', '%d/%m/%y', '%Y/%m/%d'
    ]
    
    for formato in formatos:
        try:
            return datetime.strptime(fecha_str, formato)
        except:
            continue
    return None

# ========================================
# CLASE PRINCIPAL
# ========================================

class ImportadorVPN:
    def __init__(self):
        self.conn = None
        self.cursor = None
        self.cache_personas = {}
        self.estadisticas = {
            'total': 0,
            'exitosos': 0,
            'fallidos': 0,
            'personas_nuevas': 0,
            'personas_actualizadas': 0,
            'personas_reutilizadas': 0,
            'solicitudes_creadas': 0,
            'accesos_creados': 0,
            'cartas_creadas': 0,
            'bloqueos_creados': 0,
            'errores': []
        }
    
    def conectar_bd(self):
        """Conecta a PostgreSQL"""
        try:
            self.conn = psycopg2.connect(
                host=DB_CONFIG['host'],
                port=DB_CONFIG['port'],
                database=DB_CONFIG['database'],
                user=DB_CONFIG['user'],
                password=DB_CONFIG['password'],
                client_encoding='UTF8'
            )
            self.cursor = self.conn.cursor()
            print("✅ Conexión a BD exitosa")
            
            # Verificar constraint de tipo_solicitud
            self.cursor.execute("""
                SELECT pg_get_constraintdef(oid) 
                FROM pg_constraint 
                WHERE conname = 'solicitudes_vpn_tipo_solicitud_check'
            """)
            result = self.cursor.fetchone()
            if result:
                print(f"📋 Constraint detectado: {result[0]}")
            
        except Exception as e:
            print(f"❌ Error de conexión: {e}")
            raise
    
    def cargar_excel(self):
        """Carga Excel"""
        try:
            if not os.path.exists(EXCEL_FILE):
                raise FileNotFoundError(f"❌ Archivo no encontrado: {EXCEL_FILE}")
            
            print(f"📂 Cargando: {EXCEL_FILE}")
            df = pd.read_excel(EXCEL_FILE, engine='openpyxl')
            print(f"✅ Excel cargado: {len(df)} registros")
            
            df.columns = [str(col).strip() for col in df.columns]
            print(f"📋 Columnas: {', '.join(df.columns[:5])}...")
            
            self.estadisticas['total'] = len(df)
            return df
        except Exception as e:
            print(f"❌ Error cargando Excel: {e}")
            raise
    
    def obtener_o_crear_persona(self, row) -> Optional[int]:
        """Obtiene o crea persona con cache"""
        dpi = validar_dpi(row.get('DPI'))
        if not dpi:
            raise Exception(f"DPI inválido o vacío")
        
        # Cache
        if dpi in self.cache_personas:
            self.estadisticas['personas_reutilizadas'] += 1
            return self.cache_personas[dpi]
        
        nombre_completo = limpiar_texto(row.get('Nombres y Apellidos'))
        if not nombre_completo:
            raise Exception(f"Nombre vacío")
        
        nombres, apellidos = separar_nombre_completo(nombre_completo)
        nip = validar_nip(row.get('NIP'))
        telefono = validar_telefono(row.get('Teléfono'))
        institucion = limpiar_texto(row.get('Procedencia')) or 'INSTITUCIÓN NO ESPECIFICADA'
        cargo = limpiar_texto(row.get('Grado')) or 'SIN ESPECIFICAR'
        
        # Buscar en BD
        self.cursor.execute("SELECT id FROM personas WHERE dpi = %s", (dpi,))
        result = self.cursor.fetchone()
        
        if result:
            persona_id = result[0]
            self.cursor.execute("""
                UPDATE personas 
                SET nip = COALESCE(%s, nip),
                    telefono = COALESCE(%s, telefono),
                    institucion = COALESCE(%s, institucion),
                    cargo = COALESCE(%s, cargo)
                WHERE id = %s
            """, (nip, telefono, institucion, cargo, persona_id))
            self.cache_personas[dpi] = persona_id
            self.estadisticas['personas_actualizadas'] += 1
        else:
            self.cursor.execute("""
                INSERT INTO personas 
                (dpi, nip, nombres, apellidos, institucion, cargo, telefono, activo)
                VALUES (%s, %s, %s, %s, %s, %s, %s, TRUE)
                RETURNING id
            """, (dpi, nip, nombres, apellidos, institucion, cargo, telefono))
            persona_id = self.cursor.fetchone()[0]
            self.cache_personas[dpi] = persona_id
            self.estadisticas['personas_nuevas'] += 1
        
        return persona_id
    
    def crear_solicitud(self, row, persona_id: int) -> Optional[int]:
        """Crea solicitud VPN"""
        numero_oficio = limpiar_texto(row.get('Oficio')) or 'S/N'
        numero_providencia = limpiar_texto(row.get('Providencia')) or 'S/N'
        
        fecha_recepcion = parsear_fecha(row.get('Fecha de recepción'))
        if not fecha_recepcion:
            fecha_recepcion = FECHA_FICTICIA
        
        fecha_solicitud = fecha_recepcion
        
        # ✅ CRÍTICO: Usar normalizar_tipo_solicitud corregido
        tipo_solicitud = normalizar_tipo_solicitud(row.get('Tipo de requerimiento'))
        
        justificacion = 'Registro importado desde archivo Excel - Sistema de migración masiva'
        
        estado_info = interpretar_estado(row.get('Status'))
        estado = estado_info['estado_solicitud']
        
        try:
            self.cursor.execute("""
                INSERT INTO solicitudes_vpn 
                (persona_id, numero_oficio, numero_providencia, fecha_recepcion, 
                 fecha_solicitud, tipo_solicitud, justificacion, estado, usuario_registro_id)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING id
            """, (
                persona_id, numero_oficio, numero_providencia, fecha_recepcion,
                fecha_solicitud, tipo_solicitud, justificacion, estado, USUARIO_IMPORTACION_ID
            ))
            
            solicitud_id = self.cursor.fetchone()[0]
            self.estadisticas['solicitudes_creadas'] += 1
            return solicitud_id
        except Exception as e:
            raise Exception(f"Error creando solicitud: {e}")
    
    def crear_carta(self, row, solicitud_id: int) -> Optional[int]:
        """Crea carta si existe en Excel"""
        numero_carta = limpiar_texto(row.get('# Carta'))
        fecha_carta = parsear_fecha(row.get('Fecha de Carta'))
        
        if not numero_carta:
            return None
        
        if not fecha_carta:
            fecha_carta = FECHA_FICTICIA
        
        try:
            self.cursor.execute("""
                INSERT INTO cartas_responsabilidad 
                (solicitud_id, tipo, fecha_generacion, generada_por_usuario_id)
                VALUES (%s, 'RESPONSABILIDAD', %s, %s)
                RETURNING id
            """, (solicitud_id, fecha_carta, USUARIO_IMPORTACION_ID))
            
            carta_id = self.cursor.fetchone()[0]
            self.estadisticas['cartas_creadas'] += 1
            return carta_id
        except:
            return None
    
    def crear_acceso(self, row, solicitud_id: int) -> Optional[int]:
        """Crea acceso VPN"""
        fecha_vencimiento = parsear_fecha(row.get('Fecha de Vencimiento'))
        
        if not fecha_vencimiento:
            fecha_carta = parsear_fecha(row.get('Fecha de Carta'))
            if fecha_carta:
                fecha_vencimiento = fecha_carta + timedelta(days=365)
            else:
                fecha_vencimiento = FECHA_FICTICIA + timedelta(days=365)
        
        fecha_inicio = fecha_vencimiento - timedelta(days=365)
        
        hoy = datetime.now().date()
        dias_restantes = (fecha_vencimiento.date() - hoy).days
        
        if dias_restantes > 30:
            estado_vigencia = 'ACTIVO'
        elif dias_restantes > 0:
            estado_vigencia = 'POR_VENCER'
        else:
            estado_vigencia = 'VENCIDO'
        
        try:
            self.cursor.execute("""
                INSERT INTO accesos_vpn 
                (solicitud_id, fecha_inicio, fecha_fin, dias_gracia, 
                 fecha_fin_con_gracia, estado_vigencia, usuario_creacion_id)
                VALUES (%s, %s, %s, 0, %s, %s, %s)
                RETURNING id
            """, (
                solicitud_id, fecha_inicio, fecha_vencimiento,
                fecha_vencimiento, estado_vigencia, USUARIO_IMPORTACION_ID
            ))
            
            acceso_id = self.cursor.fetchone()[0]
            self.estadisticas['accesos_creados'] += 1
            return acceso_id
        except Exception as e:
            raise Exception(f"Error creando acceso: {e}")
    
    def crear_bloqueo(self, row, acceso_id: int, estado_info: dict):
        """Crea bloqueo si es necesario"""
        if not estado_info['necesita_bloqueo']:
            return
        
        try:
            self.cursor.execute("""
                INSERT INTO bloqueos_vpn 
                (acceso_vpn_id, estado, motivo, usuario_id)
                VALUES (%s, 'BLOQUEADO', %s, %s)
            """, (acceso_id, estado_info['motivo_bloqueo'], USUARIO_IMPORTACION_ID))
            
            self.estadisticas['bloqueos_creados'] += 1
        except:
            pass
    
    def procesar_fila(self, row):
        """Procesa una fila"""
        fila_num = row.get('No.')
        
        try:
            persona_id = self.obtener_o_crear_persona(row)
            solicitud_id = self.crear_solicitud(row, persona_id)
            
            estado_info = interpretar_estado(row.get('Status'))
            
            if estado_info['necesita_acceso']:
                self.crear_carta(row, solicitud_id)
                acceso_id = self.crear_acceso(row, solicitud_id)
                
                if acceso_id and estado_info['necesita_bloqueo']:
                    self.crear_bloqueo(row, acceso_id, estado_info)
            
            self.estadisticas['exitosos'] += 1
            
            if self.estadisticas['exitosos'] % 50 == 0:
                print(f"  ✅ {self.estadisticas['exitosos']} filas procesadas...")
            
        except Exception as e:
            self.estadisticas['fallidos'] += 1
            error_msg = f"Fila {fila_num}: {str(e)}"
            self.estadisticas['errores'].append(error_msg)
            if self.estadisticas['fallidos'] <= 10:
                print(f"  ❌ {error_msg}")
            
            # ✅ NO hacer rollback aquí - continuar con siguiente fila
    
    def importar(self):
        """Proceso principal CON MANEJO DE ERRORES MEJORADO"""
        print("\n" + "="*60)
        print("🚀 INICIANDO IMPORTACIÓN MASIVA")
        print("="*60)
        
        try:
            self.conectar_bd()
            df = self.cargar_excel()
            
            print("\n📊 Procesando registros...")
            
            # ✅ Procesar en bloques con commits frecuentes
            for idx, row in df.iterrows():
                try:
                    self.procesar_fila(row)
                    
                    # Commit cada 10 registros (más frecuente)
                    if (idx + 1) % 10 == 0:
                        try:
                            self.conn.commit()
                        except Exception as commit_error:
                            print(f"⚠️  Error en commit: {commit_error}")
                            self.conn.rollback()
                    
                    # Mensaje cada 100
                    if (idx + 1) % 100 == 0:
                        print(f"💾 {idx + 1} registros procesados")
                
                except Exception as row_error:
                    # Rollback y continuar
                    self.conn.rollback()
                    print(f"⚠️  Error en fila {idx + 1}, continuando...")
            
            # Commit final
            try:
                self.conn.commit()
                print("\n💾 Guardado final completado")
            except:
                self.conn.rollback()
            
            self.mostrar_estadisticas()
            
        except Exception as e:
            print(f"\n❌ ERROR CRÍTICO: {e}")
            if self.conn:
                self.conn.rollback()
        finally:
            if self.cursor:
                self.cursor.close()
            if self.conn:
                self.conn.close()
            print("\n🔌 Conexión cerrada")
    
    def mostrar_estadisticas(self):
        """Muestra reporte"""
        print("\n" + "="*60)
        print("📊 REPORTE FINAL DE IMPORTACIÓN")
        print("="*60)
        print(f"Total registros:           {self.estadisticas['total']}")
        print(f"✅ Exitosos:               {self.estadisticas['exitosos']}")
        print(f"❌ Fallidos:               {self.estadisticas['fallidos']}")
        print(f"\n👤 Personas:")
        print(f"  Nuevas:                  {self.estadisticas['personas_nuevas']}")
        print(f"  Actualizadas:            {self.estadisticas['personas_actualizadas']}")
        print(f"  Reutilizadas:            {self.estadisticas['personas_reutilizadas']}")
        print(f"\n📄 Solicitudes:            {self.estadisticas['solicitudes_creadas']}")
        print(f"🔐 Accesos:                {self.estadisticas['accesos_creados']}")
        print(f"📋 Cartas:                 {self.estadisticas['cartas_creadas']}")
        print(f"🚫 Bloqueos:               {self.estadisticas['bloqueos_creados']}")
        
        if self.estadisticas['errores']:
            print(f"\n⚠️  ERRORES ({len(self.estadisticas['errores'])}):")
            for i, error in enumerate(self.estadisticas['errores'][:20], 1):
                print(f"  {i}. {error}")
            if len(self.estadisticas['errores']) > 20:
                print(f"  ... y {len(self.estadisticas['errores']) - 20} errores más")
        
        print("="*60)

# ========================================
# EJECUCIÓN
# ========================================

if __name__ == '__main__':
    print("\n⚙️  Configuración:")
    print(f"  📁 Excel: {EXCEL_FILE}")
    print(f"  🗄️  DB: {DB_CONFIG['database']}")
    print(f"  👤 User: {DB_CONFIG['user']}\n")
    
    respuesta = input("¿Continuar? (SI/NO): ")
    if respuesta.upper() not in ['SI', 'S']:
        print("❌ Cancelado")
        exit()
    
    importador = ImportadorVPN()
    importador.importar()