"""
Script de Importación Masiva - VERSIÓN CORREGIDA
✅ CORRIGE: Ahora detecta correctamente el estado CANCELADA
✅ Estados soportados: TERMINADO, PENDIENTE, CANCELADA, BLOQUEADO
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
    'user': 'postgres',
    'password': 'Pantera.25042009'
}

EXCEL_FILE = r'C:\Users\HP\Desktop\VPN-PROJECT\datos.xlsx'
USUARIO_IMPORTACION_ID = 1
FECHA_FICTICIA = datetime(2024, 1, 1)

# ========================================
# FUNCIONES AUXILIARES (sin cambios)
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

# ========================================
# ✅ FUNCIÓN CORREGIDA: determinar_estado_solicitud
# ========================================

def determinar_estado_solicitud(row) -> dict:
    """
    ✅ CORREGIDO: Detecta correctamente CANCELADA
    Determina estado de solicitud según Excel
    """
    estado_excel = limpiar_texto(row.get('Status'))
    
    if not estado_excel:
        # Sin estado en Excel = APROBADA con carta
        return {
            'estado_solicitud': 'APROBADA',
            'crear_carta': True,
            'crear_acceso': True,
            'necesita_bloqueo': False,
            'motivo_bloqueo': None
        }
    
    estado_upper = estado_excel.upper()
    
    print(f"  🔍 Analizando estado Excel: '{estado_excel}' → '{estado_upper}'")
    
    # ✅ 1. CANCELADA (debe ir PRIMERO para detectarlo antes que otros)
    if 'CANCEL' in estado_upper:
        print(f"  🚫 DETECTADO: CANCELADA")
        return {
            'estado_solicitud': 'CANCELADA',
            'crear_carta': False,
            'crear_acceso': False,
            'necesita_bloqueo': False,
            'motivo_bloqueo': None
        }
    
    # ✅ 2. BLOQUEADO
    if 'BLOQ' in estado_upper:
        print(f"  🔒 DETECTADO: BLOQUEADO")
        return {
            'estado_solicitud': 'APROBADA',
            'crear_carta': True,
            'crear_acceso': True,
            'necesita_bloqueo': True,
            'motivo_bloqueo': f"Importado con estado: {estado_excel}"
        }
    
    # ✅ 3. TERMINADO (APROBADA con carta)
    if 'TERMINADO' in estado_upper or 'TERMINADA' in estado_upper or 'TERMINO' in estado_upper:
        print(f"  ✅ DETECTADO: TERMINADO (APROBADA)")
        return {
            'estado_solicitud': 'APROBADA',
            'crear_carta': True,
            'crear_acceso': True,
            'necesita_bloqueo': False,
            'motivo_bloqueo': None
        }
    
    # ✅ 4. PENDIENTE
    if 'PENDIENTE' in estado_upper:
        print(f"  ⏳ DETECTADO: PENDIENTE")
        return {
            'estado_solicitud': 'PENDIENTE',
            'crear_carta': False,
            'crear_acceso': False,
            'necesita_bloqueo': False,
            'motivo_bloqueo': None
        }
    
    # ✅ 5. DEFAULT: APROBADA
    print(f"  ℹ️ Estado no reconocido, asignando APROBADA por defecto")
    return {
        'estado_solicitud': 'APROBADA',
        'crear_carta': True,
        'crear_acceso': True,
        'necesita_bloqueo': False,
        'motivo_bloqueo': None
    }

def extraer_numero_carta(valor) -> Optional[int]:
    """Extrae número de carta del Excel"""
    if pd.isna(valor):
        return None
    
    texto = str(valor).strip().upper()
    
    if texto in ['', 'NAN', 'CURSO', 'CANCELADA', 'NINGUNO']:
        return None
    
    numeros = re.findall(r'\d+', texto)
    if numeros:
        try:
            numero = int(numeros[0])
            if 1 <= numero <= 9999:
                return numero
        except:
            pass
    
    return None

def extraer_anio_carta(valor) -> Optional[int]:
    """Extrae año de carta del Excel"""
    if pd.isna(valor):
        return None
    
    texto = str(valor).strip().upper()
    
    if texto in ['', 'NAN', 'CURSO', 'CANCELADA', '5025', 'NINGUNO']:
        return None
    
    try:
        anio = int(float(texto))
        
        if anio == 5025:
            return 2025
        
        if 2020 <= anio <= 2030:
            return anio
        
        if 20 <= anio <= 30:
            return 2000 + anio
            
    except:
        pass
    
    return None

# ========================================
# CLASE IMPORTADOR (resto igual)
# ========================================

class ImportadorVPN:
    def __init__(self):
        self.conn = None
        self.cursor = None
        self.estadisticas = {
            'total': 0,
            'exitosos': 0,
            'fallidos': 0,
            'duplicados_omitidos': 0,
            'personas_nuevas': 0,
            'personas_actualizadas': 0,
            'personas_reutilizadas': 0,
            'solicitudes_creadas': 0,
            'solicitudes_aprobadas': 0,
            'solicitudes_pendientes': 0,
            'solicitudes_canceladas': 0,
            'accesos_creados': 0,
            'cartas_creadas': 0,
            'cartas_omitidas': 0,
            'sin_carta': 0,
            'bloqueos_creados': 0,
            'cartas_auto_numeradas': 0,
            'errores': []
        }
        self.contadores_carta = {}
    
    def conectar_bd(self):
        """Conecta a PostgreSQL"""
        try:
            self.conn = psycopg2.connect(**DB_CONFIG)
            self.cursor = self.conn.cursor()
            print(f"✅ Conectado a {DB_CONFIG['database']}")
        except Exception as e:
            print(f"❌ Error conectando a BD: {e}")
            raise
    
    def cargar_excel(self):
        """Carga Excel y valida"""
        if not os.path.exists(EXCEL_FILE):
            raise FileNotFoundError(f"❌ Archivo no encontrado: {EXCEL_FILE}")
        
        try:
            df = pd.read_excel(EXCEL_FILE)
            print(f"✅ Excel cargado: {len(df)} filas")
            print(f"📋 Columnas detectadas: {list(df.columns)}")
            
            if df.empty:
                raise ValueError("❌ Excel vacío")
            
            self.estadisticas['total'] = len(df)
            return df
        except Exception as e:
            print(f"❌ Error cargando Excel: {e}")
            raise
    
    def obtener_proximo_numero_carta(self, anio: int) -> int:
        """Obtiene el próximo número de carta para un año"""
        if anio in self.contadores_carta:
            self.contadores_carta[anio] += 1
            return self.contadores_carta[anio]
        
        self.cursor.execute("""
            SELECT MAX(numero_carta)
            FROM cartas_responsabilidad
            WHERE anio_carta = %s 
              AND numero_carta IS NOT NULL
        """, (anio,))
        
        resultado = self.cursor.fetchone()[0]
        max_actual = resultado if resultado is not None else 0
        proximo_numero = max_actual + 1
        
        self.contadores_carta[anio] = proximo_numero
        
        print(f"  📊 Año {anio}: Último número = {max_actual}, Próximo = {proximo_numero}")
        
        return proximo_numero
    
    def obtener_o_crear_persona(self, row) -> int:
        """Obtiene o crea persona"""
        nip = validar_nip(row.get('NIP'))
        dpi = validar_dpi(row.get('DPI'))
        
        nombre_completo = None
        posibles_columnas = [
            'Nombres y Apellidos',
            'Nombre',
            'NOMBRE', 
            'Nombres', 
            'NombreCompleto', 
            'Nombre Completo'
        ]
        
        for col in posibles_columnas:
            if col in row and not pd.isna(row.get(col)):
                nombre_completo = limpiar_texto(row.get(col))
                if nombre_completo:
                    break
        
        if not nombre_completo:
            print(f"  ⚠️ ADVERTENCIA: No se encontró nombre")
            nombre_completo = "Desconocido"
        
        nombres, apellidos = separar_nombre_completo(nombre_completo)
        
        print(f"  👤 Procesando: {nombres} {apellidos} (NIP: {nip or 'N/A'}, DPI: {dpi or 'N/A'})")
        
        # Buscar por NIP primero
        if nip:
            self.cursor.execute("SELECT id FROM personas WHERE nip = %s", (nip,))
            resultado = self.cursor.fetchone()
            if resultado:
                persona_id = resultado[0]
                
                # Actualizar datos
                self.cursor.execute("""
                    UPDATE personas 
                    SET 
                        dpi = COALESCE(%s, dpi),
                        nombres = COALESCE(%s, nombres),
                        apellidos = COALESCE(%s, apellidos),
                        institucion = COALESCE(%s, institucion),
                        cargo = COALESCE(%s, cargo),
                        telefono = COALESCE(%s, telefono),
                        email = COALESCE(%s, email)
                    WHERE id = %s
                """, (
                    dpi,
                    nombres,
                    apellidos,
                    limpiar_texto(row.get('Procedencia')),
                    limpiar_texto(row.get('Grado')),
                    validar_telefono(row.get('Teléfono')),
                    limpiar_texto(row.get('Email')),
                    persona_id
                ))
                
                self.estadisticas['personas_actualizadas'] += 1
                return persona_id
        
        # Buscar por DPI
        if dpi:
            self.cursor.execute("SELECT id FROM personas WHERE dpi = %s", (dpi,))
            resultado = self.cursor.fetchone()
            if resultado:
                self.estadisticas['personas_reutilizadas'] += 1
                return resultado[0]
        
        # Crear nueva persona
        if not dpi:
            import random
            dpi = f"9999{random.randint(100000000, 999999999)}"
        
        self.cursor.execute("""
            INSERT INTO personas 
            (nip, dpi, nombres, apellidos, institucion, cargo, telefono, email)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (
            nip,
            dpi,
            nombres,
            apellidos,
            limpiar_texto(row.get('Procedencia')),
            limpiar_texto(row.get('Grado')),
            validar_telefono(row.get('Teléfono')),
            limpiar_texto(row.get('Email'))
        ))
        
        persona_id = self.cursor.fetchone()[0]
        self.estadisticas['personas_nuevas'] += 1
        return persona_id
    
    def crear_solicitud(self, row, persona_id: int, estado_info: dict) -> int:
        """Crea solicitud con el estado correcto según Excel"""
        numero_oficio = limpiar_texto(row.get('Oficio'))
        numero_providencia = limpiar_texto(row.get('Providencia'))
        tipo_solicitud = normalizar_tipo_solicitud(row.get('Tipo de requerimiento'))
        
        estado_solicitud = estado_info['estado_solicitud']
        
        fecha_recepcion = parsear_fecha(row.get('Fecha de recepción'))
        if not fecha_recepcion:
            fecha_recepcion = parsear_fecha(row.get('Fecha de Carta'))
        if not fecha_recepcion:
            fecha_recepcion = FECHA_FICTICIA
        
        self.cursor.execute("""
            INSERT INTO solicitudes_vpn 
            (persona_id, numero_oficio, numero_providencia, fecha_recepcion, 
             fecha_solicitud, tipo_solicitud, justificacion, estado, usuario_registro_id)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (
            persona_id,
            numero_oficio,
            numero_providencia,
            fecha_recepcion,
            fecha_recepcion,
            tipo_solicitud,
            'Importado desde Excel',
            estado_solicitud,
            USUARIO_IMPORTACION_ID
        ))
        
        solicitud_id = self.cursor.fetchone()[0]
        self.estadisticas['solicitudes_creadas'] += 1
        
        if estado_solicitud == 'APROBADA':
            self.estadisticas['solicitudes_aprobadas'] += 1
        elif estado_solicitud == 'PENDIENTE':
            self.estadisticas['solicitudes_pendientes'] += 1
        elif estado_solicitud == 'CANCELADA':
            self.estadisticas['solicitudes_canceladas'] += 1
        
        return solicitud_id
    
    def crear_carta_desde_excel(self, row, solicitud_id: int, estado_info: dict) -> Optional[int]:
        """Crea carta con auto-numeración correcta"""
        if not estado_info['crear_carta']:
            print(f"  ℹ️ Estado no requiere carta, omitiendo...")
            self.estadisticas['sin_carta'] += 1
            return None
        
        numero_carta_excel = extraer_numero_carta(row.get('numero_carta'))
        anio_carta_excel = extraer_anio_carta(row.get('anio_carta'))
        
        if not numero_carta_excel and not anio_carta_excel:
            self.estadisticas['sin_carta'] += 1
            return None
        
        if numero_carta_excel and anio_carta_excel:
            numero_final = numero_carta_excel
            anio_final = anio_carta_excel
            print(f"  📄 Carta del Excel: {numero_final}-{anio_final}")
        
        elif numero_carta_excel and not anio_carta_excel:
            numero_final = numero_carta_excel
            anio_final = datetime.now().year
            print(f"  📄 Carta del Excel (sin año): {numero_final}, usando año actual {anio_final}")
        
        elif not numero_carta_excel and anio_carta_excel:
            numero_final = self.obtener_proximo_numero_carta(anio_carta_excel)
            anio_final = anio_carta_excel
            self.estadisticas['cartas_auto_numeradas'] += 1
            print(f"  📄 Carta AUTO-NUMERADA: {numero_final}-{anio_final}")
        
        fecha_carta = parsear_fecha(row.get('Fecha de Carta'))
        if not fecha_carta:
            fecha_carta = FECHA_FICTICIA
        
        try:
            self.cursor.execute("""
                SELECT id FROM cartas_responsabilidad
                WHERE numero_carta = %s AND anio_carta = %s
            """, (numero_final, anio_final))
            
            if self.cursor.fetchone():
                print(f"  ⚠️ Carta {numero_final}-{anio_final} ya existe, omitiendo...")
                self.estadisticas['cartas_omitidas'] += 1
                return None
            
            self.cursor.execute("""
                INSERT INTO cartas_responsabilidad 
                (solicitud_id, tipo, fecha_generacion, generada_por_usuario_id, 
                 numero_carta, anio_carta)
                VALUES (%s, 'RESPONSABILIDAD', %s, %s, %s, %s)
                RETURNING id
            """, (
                solicitud_id,
                fecha_carta,
                USUARIO_IMPORTACION_ID,
                numero_final,
                anio_final
            ))
            
            carta_id = self.cursor.fetchone()[0]
            self.estadisticas['cartas_creadas'] += 1
            print(f"  ✅ Carta creada: ID={carta_id}, Número={numero_final}-{anio_final}")
            return carta_id
            
        except Exception as e:
            print(f"  ❌ Error creando carta: {e}")
            self.estadisticas['sin_carta'] += 1
            return None
    
    def crear_acceso(self, row, solicitud_id: int, estado_info: dict) -> Optional[int]:
        """Crea acceso VPN si el estado lo permite"""
        if not estado_info['crear_acceso']:
            print(f"  ℹ️ Estado '{estado_info['estado_solicitud']}' no requiere acceso, omitiendo...")
            return None
        
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
            print(f"  🔓 Acceso creado: ID={acceso_id}, Estado={estado_vigencia}")
            return acceso_id
        except Exception as e:
            print(f"  ❌ Error creando acceso: {e}")
            raise
    
    def crear_bloqueo(self, row, acceso_id: int, estado_info: dict):
        """Crea bloqueo solo si el estado lo requiere"""
        if not estado_info['necesita_bloqueo'] or not acceso_id:
            return
        
        try:
            self.cursor.execute("""
                INSERT INTO bloqueos_vpn 
                (acceso_vpn_id, estado, motivo, usuario_id)
                VALUES (%s, 'BLOQUEADO', %s, %s)
            """, (acceso_id, estado_info['motivo_bloqueo'], USUARIO_IMPORTACION_ID))
            
            self.estadisticas['bloqueos_creados'] += 1
            print(f"  🚫 Bloqueo creado: {estado_info['motivo_bloqueo']}")
        except Exception as e:
            print(f"  ⚠️ Error creando bloqueo: {e}")
    
    def procesar_fila(self, row):
        """Procesa fila con lógica de estados"""
        fila_num = row.get('No.')
        
        try:
            estado_info = determinar_estado_solicitud(row)
            print(f"\n🔍 Fila {fila_num} - Estado detectado: {estado_info['estado_solicitud']}")
            
            nip = validar_nip(row.get('NIP'))
            numero_oficio = limpiar_texto(row.get('Oficio'))
            
            # Validar duplicado
            if nip and numero_oficio and numero_oficio.upper() != 'S/N':
                self.cursor.execute("""
                    SELECT s.id 
                    FROM solicitudes_vpn s
                    JOIN personas p ON s.persona_id = p.id
                    WHERE p.nip = %s AND s.numero_oficio = %s
                """, (nip, numero_oficio))
                
                if self.cursor.fetchone():
                    print(f"⚠️ Fila {fila_num}: DUPLICADO (NIP={nip}, Oficio={numero_oficio}), omitiendo...")
                    self.estadisticas['duplicados_omitidos'] += 1
                    return
            
            persona_id = self.obtener_o_crear_persona(row)
            solicitud_id = self.crear_solicitud(row, persona_id, estado_info)
            self.crear_carta_desde_excel(row, solicitud_id, estado_info)
            acceso_id = self.crear_acceso(row, solicitud_id, estado_info)
            self.crear_bloqueo(row, acceso_id, estado_info)
            
            self.estadisticas['exitosos'] += 1
            print(f"✅ Fila {fila_num}: PROCESADA - Estado: {estado_info['estado_solicitud']}")
            
        except Exception as e:
            self.estadisticas['fallidos'] += 1
            error_msg = f"Fila {fila_num}: {str(e)}"
            self.estadisticas['errores'].append(error_msg)
            print(f"❌ {error_msg}")
    
    def importar(self):
        """Proceso principal de importación"""
        try:
            self.conectar_bd()
            df = self.cargar_excel()
            
            print(f"\n{'='*60}")
            print(f"INICIANDO IMPORTACIÓN")
            print(f"{'='*60}\n")
            
            for idx, row in df.iterrows():
                self.procesar_fila(row)
            
            self.conn.commit()
            self.mostrar_resumen()
            
        except Exception as e:
            print(f"\n❌ ERROR CRÍTICO: {e}")
            if self.conn:
                self.conn.rollback()
            raise
        finally:
            if self.cursor:
                self.cursor.close()
            if self.conn:
                self.conn.close()
    
    def mostrar_resumen(self):
        """Muestra resumen de importación"""
        print(f"\n{'='*60}")
        print(f"RESUMEN DE IMPORTACIÓN")
        print(f"{'='*60}")
        print(f"Total de filas procesadas: {self.estadisticas['total']}")
        print(f"✅ Exitosas: {self.estadisticas['exitosos']}")
        print(f"❌ Fallidas: {self.estadisticas['fallidos']}")
        print(f"⚠️  Duplicadas (omitidas): {self.estadisticas['duplicados_omitidos']}")
        print(f"\n📊 PERSONAS:")
        print(f"  - Nuevas: {self.estadisticas['personas_nuevas']}")
        print(f"  - Actualizadas: {self.estadisticas['personas_actualizadas']}")
        print(f"  - Reutilizadas: {self.estadisticas['personas_reutilizadas']}")
        print(f"\n📋 SOLICITUDES:")
        print(f"  - Total creadas: {self.estadisticas['solicitudes_creadas']}")
        print(f"  - 🟢 Aprobadas: {self.estadisticas['solicitudes_aprobadas']}")
        print(f"  - 🟡 Pendientes: {self.estadisticas['solicitudes_pendientes']}")
        print(f"  - ⚫ Canceladas: {self.estadisticas['solicitudes_canceladas']}")
        print(f"\n📄 CARTAS:")
        print(f"  - Creadas: {self.estadisticas['cartas_creadas']}")
        print(f"  - Auto-numeradas: {self.estadisticas['cartas_auto_numeradas']}")
        print(f"  - Omitidas (duplicadas): {self.estadisticas['cartas_omitidas']}")
        print(f"  - Sin carta (no aplica): {self.estadisticas['sin_carta']}")
        print(f"\n🔓 ACCESOS:")
        print(f"  - Creados: {self.estadisticas['accesos_creados']}")
        print(f"\n🚫 BLOQUEOS:")
        print(f"  - Creados: {self.estadisticas['bloqueos_creados']}")
        
        if self.estadisticas['errores']:
            print(f"\n⚠️ ERRORES ENCONTRADOS:")
            for error in self.estadisticas['errores'][:10]:
                print(f"  - {error}")
            if len(self.estadisticas['errores']) > 10:
                print(f"  ... y {len(self.estadisticas['errores']) - 10} errores más")
        
        print(f"\n{'='*60}\n")


# ========================================
# EJECUCIÓN
# ========================================

if __name__ == '__main__':
    print("""
    ╔═══════════════════════════════════════════════════════════╗
    ║   IMPORTADOR VPN - VERSIÓN 3.2 CORREGIDA                 ║
    ║   ✅ CORRIGE: Auto-numeración con MAX() excluyendo NULLs ║
    ║   ✅ Funcionamiento idéntico a solicitudes.py            ║
    ╚═══════════════════════════════════════════════════════════╝
    """)
    
    importador = ImportadorVPN()
    importador.importar()
    
    print("\n✅ Importación completada!")
    input("\nPresiona ENTER para salir...")