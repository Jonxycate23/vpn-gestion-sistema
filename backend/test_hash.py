"""
Script de prueba para verificar el problema de autenticación
"""
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# El hash que está en la BD
hash_en_bd = "$2b$12$iq7h5i.pBClxAHHxYscC4uIm6HWVutjnDiMMk1n9.5y5Y6PfAbWmG"

# La contraseña que estás intentando
password = "Admin123!"

print("=" * 60)
print("PRUEBA DE VERIFICACIÓN DE CONTRASEÑA")
print("=" * 60)
print()
print(f"Hash en BD: {hash_en_bd}")
print(f"Password: {password}")
print()

# Probar verificación
try:
    resultado = pwd_context.verify(password, hash_en_bd)
    print(f"✅ Resultado de verificación: {resultado}")
    
    if resultado:
        print()
        print("✅ ¡EL HASH ES CORRECTO!")
        print("El problema está en OTRO LADO, no en el hash")
    else:
        print()
        print("❌ EL HASH NO COINCIDE")
        print("Generando nuevo hash...")
        nuevo = pwd_context.hash(password)
        print(f"Nuevo hash: {nuevo}")
except Exception as e:
    print(f"❌ ERROR: {e}")

print()
print("=" * 60)
