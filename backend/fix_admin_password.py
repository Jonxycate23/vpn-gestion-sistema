#!/usr/bin/env python3
"""
Script para regenerar el hash de la contraseña del admin
"""
import sys
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

print("=" * 60)
print("REGENERADOR DE HASH DE CONTRASEÑA")
print("=" * 60)
print()

# Generar nuevo hash
password = "Admin123!"
nuevo_hash = pwd_context.hash(password)

print(f"✅ Hash generado exitosamente!")
print()
print("Hash nuevo:")
print(nuevo_hash)
print()
print("=" * 60)
print("AHORA EJECUTA ESTO EN PostgreSQL:")
print("=" * 60)
print()
print("psql -h localhost -U postgres -d vpn_gestion")
print()
print(f"UPDATE usuarios_sistema SET password_hash = '{nuevo_hash}' WHERE username = 'admin';")
print()
print("SELECT username, substring(password_hash, 1, 20) || '...' as hash FROM usuarios_sistema WHERE username = 'admin';")
print()
print("\\q")
print()
print("=" * 60)
print("LUEGO REINICIA EL BACKEND:")
print("=" * 60)
print()
print("python -m uvicorn main:app --reload")
print()
