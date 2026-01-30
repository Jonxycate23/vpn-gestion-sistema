"""
Prueba de imports 
"""

print("Probando imports...")

try:
    from pydantic import BaseModel, Field
    print("✅ Pydantic OK")
except ImportError as e:
    print(f"❌ Pydantic ERROR: {e}")

try:
    from pydantic_settings import BaseSettings
    print("✅ Pydantic Settings OK")
except ImportError as e:
    print(f"❌ Pydantic Settings ERROR: {e}")

try:
    from fastapi import FastAPI
    print("✅ FastAPI OK")
except ImportError as e:
    print(f"❌ FastAPI ERROR: {e}")

try:
    from sqlalchemy import create_engine
    print("✅ SQLAlchemy OK")
except ImportError as e:
    print(f"❌ SQLAlchemy ERROR: {e}")

try:
    from passlib.context import CryptContext
    print("✅ Passlib OK")
except ImportError as e:
    print(f"❌ Passlib ERROR: {e}")

try:
    import bcrypt
    print(f"✅ bcrypt OK - version: {bcrypt.__version__}")
except ImportError as e:
    print(f"❌ bcrypt ERROR: {e}")

try:
    from jose import jwt
    print("✅ python-jose OK")
except ImportError as e:
    print(f"❌ python-jose ERROR: {e}")

print("\n✨ Si todos muestran ✅, puedes iniciar el servidor!")