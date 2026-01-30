"""
Script para aplicar índices de rendimiento a la base de datos
📍 Ubicación: backend/scripts/apply_performance_indexes.py
🎯 Ejecutar: python -m scripts.apply_performance_indexes
"""
import sys
from pathlib import Path

# Agregar el directorio raíz al path
sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import create_engine, text
from app.core.config import settings
from app.core.database import get_db

def apply_indexes():
    """Aplicar índices de rendimiento"""
    
    print("🚀 Aplicando índices de rendimiento...")
    
    # Leer el archivo SQL
    sql_file = Path(__file__).parent.parent.parent / "database" / "migrations" / "add_performance_indexes.sql"
    
    if not sql_file.exists():
        print(f"❌ No se encontró el archivo: {sql_file}")
        return False
    
    with open(sql_file, 'r', encoding='utf-8') as f:
        sql_content = f.read()
    
    # Crear engine
    engine = create_engine(settings.DATABASE_URL)
    
    try:
        with engine.connect() as conn:
            # Ejecutar cada statement
            statements = [s.strip() for s in sql_content.split(';') if s.strip() and not s.strip().startswith('--')]
            
            for i, statement in enumerate(statements, 1):
                # Saltar comentarios y líneas vacías
                if not statement or statement.startswith('--'):
                    continue
                
                try:
                    print(f"📝 Ejecutando statement {i}/{len(statements)}...")
                    conn.execute(text(statement))
                    conn.commit()
                except Exception as e:
                    # Algunos índices pueden ya existir, eso está bien
                    if "already exists" in str(e).lower():
                        print(f"   ⚠️  Índice ya existe (OK)")
                    else:
                        print(f"   ❌ Error: {e}")
            
            print("\n✅ Índices aplicados exitosamente!")
            print("\n📊 Verificando índices creados...")
            
            # Verificar índices
            result = conn.execute(text("""
                SELECT 
                    tablename,
                    indexname
                FROM pg_indexes
                WHERE schemaname = 'public'
                    AND tablename IN ('accesos_vpn', 'bloqueo_vpn', 'solicitudes_vpn', 
                                     'cartas_responsabilidad', 'personas', 'usuarios_sistema')
                    AND indexname LIKE 'idx_%'
                ORDER BY tablename, indexname;
            """))
            
            indices = result.fetchall()
            
            if indices:
                print(f"\n✅ {len(indices)} índices encontrados:")
                current_table = None
                for tabla, indice in indices:
                    if tabla != current_table:
                        print(f"\n  📋 {tabla}:")
                        current_table = tabla
                    print(f"     - {indice}")
            else:
                print("\n⚠️  No se encontraron índices personalizados")
            
            return True
            
    except Exception as e:
        print(f"\n❌ Error aplicando índices: {e}")
        return False

if __name__ == "__main__":
    print("=" * 60)
    print("  APLICAR ÍNDICES DE RENDIMIENTO")
    print("=" * 60)
    print()
    
    success = apply_indexes()
    
    if success:
        print("\n" + "=" * 60)
        print("  ✅ PROCESO COMPLETADO EXITOSAMENTE")
        print("=" * 60)
        sys.exit(0)
    else:
        print("\n" + "=" * 60)
        print("  ❌ PROCESO COMPLETADO CON ERRORES")
        print("=" * 60)
        sys.exit(1)
