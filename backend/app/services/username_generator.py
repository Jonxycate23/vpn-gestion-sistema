"""
Generador Inteligente de Usernames
Evita duplicados usando diferentes combinaciones de nombres
"""
from sqlalchemy.orm import Session
from app.models import UsuarioSistema
import re


class UsernameGenerator:
    """Genera usernames únicos basados en nombres"""
    
    @staticmethod
    def limpiar_texto(texto: str) -> str:
        """
        Limpia texto para username:
        - Remueve acentos
        - Convierte a minúsculas
        - Remueve caracteres especiales
        """
        # Mapa de reemplazo de acentos
        acentos = {
            'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u',
            'Á': 'a', 'É': 'e', 'Í': 'i', 'Ó': 'o', 'Ú': 'u',
            'ü': 'u', 'Ü': 'u',
            'ñ': 'n', 'Ñ': 'n'
        }
        
        texto = texto.lower().strip()
        for acento, reemplazo in acentos.items():
            texto = texto.replace(acento, reemplazo)
        
        # Remover caracteres especiales, dejar solo letras y espacios
        texto = re.sub(r'[^a-z\s]', '', texto)
        
        return texto
    
    @staticmethod
    def separar_nombres(nombre_completo: str) -> list[str]:
        """Separa nombre completo en palabras"""
        limpio = UsernameGenerator.limpiar_texto(nombre_completo)
        palabras = [p for p in limpio.split() if len(p) > 0]
        return palabras
    
    @staticmethod
    def generar_username(
        db: Session,
        nombres: str,
        apellidos: str
    ) -> str:
        """
        Genera username único basado en nombres y apellidos
        
        Algoritmo:
        1. primer_nombre.primer_apellido (juan.perez)
        2. primer_nombre.segundo_apellido (juan.lopez)
        3. segundo_nombre.primer_apellido (ernesto.perez)
        4. segundo_nombre.segundo_apellido (ernesto.lopez)
        5. primer_nombre.primer_apellido + numero (juan.perez2)
        
        Args:
            db: Sesión de base de datos
            nombres: Nombres de la persona (puede ser múltiples)
            apellidos: Apellidos de la persona (puede ser múltiples)
            
        Returns:
            Username único generado
            
        Examples:
            >>> generar_username(db, "Juan", "Perez")
            "juan.perez"
            
            >>> generar_username(db, "Juan Eliezer", "Perez Gomez")
            "juan.perez"  # Si no existe
            # O "juan.gomez" si juan.perez ya existe
            # O "eliezer.perez" si juan.perez y juan.gomez existen
        """
        palabras_nombres = UsernameGenerator.separar_nombres(nombres)
        palabras_apellidos = UsernameGenerator.separar_nombres(apellidos)
        
        if not palabras_nombres or not palabras_apellidos:
            raise ValueError("Se requieren al menos un nombre y un apellido")
        
        # Lista de combinaciones a intentar
        combinaciones = []
        
        # Primer nombre + primer apellido (juan.perez)
        if len(palabras_nombres) >= 1 and len(palabras_apellidos) >= 1:
            combinaciones.append(f"{palabras_nombres[0]}.{palabras_apellidos[0]}")
        
        # Primer nombre + segundo apellido (juan.gomez)
        if len(palabras_nombres) >= 1 and len(palabras_apellidos) >= 2:
            combinaciones.append(f"{palabras_nombres[0]}.{palabras_apellidos[1]}")
        
        # Segundo nombre + primer apellido (eliezer.perez)
        if len(palabras_nombres) >= 2 and len(palabras_apellidos) >= 1:
            combinaciones.append(f"{palabras_nombres[1]}.{palabras_apellidos[0]}")
        
        # Segundo nombre + segundo apellido (eliezer.gomez)
        if len(palabras_nombres) >= 2 and len(palabras_apellidos) >= 2:
            combinaciones.append(f"{palabras_nombres[1]}.{palabras_apellidos[1]}")
        
        # Tercer nombre + primer apellido (si existe tercer nombre)
        if len(palabras_nombres) >= 3 and len(palabras_apellidos) >= 1:
            combinaciones.append(f"{palabras_nombres[2]}.{palabras_apellidos[0]}")
        
        # Intentar cada combinación
        for username in combinaciones:
            existe = db.query(UsuarioSistema).filter(
                UsuarioSistema.username == username
            ).first()
            
            if not existe:
                return username
        
        # Si todas las combinaciones existen, agregar número
        base_username = combinaciones[0]  # primer_nombre.primer_apellido
        numero = 2
        
        while True:
            username = f"{base_username}{numero}"
            existe = db.query(UsuarioSistema).filter(
                UsuarioSistema.username == username
            ).first()
            
            if not existe:
                return username
            
            numero += 1
            
            # Prevenir loop infinito
            if numero > 99:
                raise ValueError("No se pudo generar username único después de 99 intentos")
    
    @staticmethod
    def vista_previa(nombres: str, apellidos: str) -> list[str]:
        """
        Muestra vista previa de posibles usernames (sin verificar BD)
        
        Útil para mostrar al usuario qué username se generará
        """
        palabras_nombres = UsernameGenerator.separar_nombres(nombres)
        palabras_apellidos = UsernameGenerator.separar_nombres(apellidos)
        
        combinaciones = []
        
        if len(palabras_nombres) >= 1 and len(palabras_apellidos) >= 1:
            combinaciones.append(f"{palabras_nombres[0]}.{palabras_apellidos[0]}")
        
        if len(palabras_nombres) >= 1 and len(palabras_apellidos) >= 2:
            combinaciones.append(f"{palabras_nombres[0]}.{palabras_apellidos[1]}")
        
        if len(palabras_nombres) >= 2 and len(palabras_apellidos) >= 1:
            combinaciones.append(f"{palabras_nombres[1]}.{palabras_apellidos[0]}")
        
        if len(palabras_nombres) >= 2 and len(palabras_apellidos) >= 2:
            combinaciones.append(f"{palabras_nombres[1]}.{palabras_apellidos[1]}")
        
        return combinaciones
