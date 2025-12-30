"""
Diagnóstico completo del sistema de autenticación
"""
import sys
import psycopg2
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

print("=" * 70)
print("DIAGNÓSTICO COMPLETO DEL SISTEMA")
print("=" * 70)
print()

# Conectar a la base de datos
try:
    conn = psycopg2.connect(
        host="localhost",
        database="vpn_gestion",
        user="postgres",
        password="TU_PASSWORD_AQUI"  # ← CAMBIA ESTO
    )
    print("✅ Conexión a PostgreSQL exitosa")
    
    cursor = conn.cursor()
    cursor.execute("SELECT username, password_hash FROM usuarios_sistema WHERE username = 'admin'")
    result = cursor.fetchone()
    
    if result:
        username, hash_en_bd = result
        print(f"✅ Usuario encontrado: {username}")
        print(f"   Hash en BD: {hash_en_bd}")
        print()
        
        # Probar la contraseña
        password = "Admin123!"
        print(f"🔍 Probando password: {password}")
        print()
        
        try:
            verificacion = pwd_context.verify(password, hash_en_bd)
            
            if verificacion:
                print("✅✅✅ ¡LA CONTRASEÑA ES CORRECTA!")
                print("✅✅✅ ¡EL HASH FUNCIONA!")
                print()
                print("El problema NO es el hash.")
                print("El problema debe ser otra cosa en el código.")
            else:
                print("❌ LA CONTRASEÑA NO COINCIDE")
                print()
                print("Generando nuevo hash correcto...")
                nuevo_hash = pwd_context.hash(password)
                print(f"Nuevo hash: {nuevo_hash}")
                print()
                print("EJECUTA ESTO EN psql:")
                print(f"UPDATE usuarios_sistema SET password_hash = '{nuevo_hash}' WHERE username = 'admin';")
        except Exception as e:
            print(f"❌ Error en verificación: {e}")
            print()
            print("Esto indica un problema de compatibilidad de versiones")
    else:
        print("❌ Usuario 'admin' no encontrado")
    
    cursor.close()
    conn.close()
    
except psycopg2.Error as e:
    print(f"❌ Error de conexión a PostgreSQL: {e}")
    print()
    print("SOLUCIÓN:")
    print("1. Cambia 'TU_PASSWORD_AQUI' en este script")
    print("2. O ejecuta el script test_hash.py en su lugar")

print()
print("=" * 70)
