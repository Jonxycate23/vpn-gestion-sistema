"""
Utilidades para manejo de archivos
"""
import os
import hashlib
import aiofiles
from pathlib import Path
from typing import Optional
from fastapi import UploadFile, HTTPException
from app.core.config import settings


class FileService:
    """Servicio para manejo de archivos"""
    
    @staticmethod
    def validar_extension(filename: str) -> bool:
        """Validar que la extensión del archivo sea permitida"""
        extension = Path(filename).suffix.lower()
        return extension in settings.ALLOWED_EXTENSIONS
    
    @staticmethod
    def generar_nombre_unico(original_filename: str, prefix: str = "") -> str:
        """Generar nombre único para archivo"""
        import uuid
        from datetime import datetime
        
        extension = Path(original_filename).suffix.lower()
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        unique_id = str(uuid.uuid4())[:8]
        
        if prefix:
            return f"{prefix}_{timestamp}_{unique_id}{extension}"
        return f"{timestamp}_{unique_id}{extension}"
    
    @staticmethod
    async def calcular_hash(file_path: str) -> str:
        """Calcular hash SHA-256 de un archivo"""
        sha256_hash = hashlib.sha256()
        
        async with aiofiles.open(file_path, 'rb') as f:
            while True:
                chunk = await f.read(8192)
                if not chunk:
                    break
                sha256_hash.update(chunk)
        
        return sha256_hash.hexdigest()
    
    @staticmethod
    async def guardar_archivo(
        file: UploadFile,
        subdirectorio: str = "",
        prefix: str = ""
    ) -> tuple[str, int, str]:
        """
        Guardar archivo en el sistema de archivos
        
        Args:
            file: Archivo subido
            subdirectorio: Subdirectorio dentro de UPLOAD_DIR
            prefix: Prefijo para el nombre del archivo
            
        Returns:
            Tupla con (ruta_relativa, tamaño_bytes, hash_sha256)
            
        Raises:
            HTTPException: Si hay error al guardar
        """
        # Validar extensión
        if not FileService.validar_extension(file.filename):
            raise HTTPException(
                status_code=400,
                detail=f"Extensión de archivo no permitida. Permitidas: {', '.join(settings.ALLOWED_EXTENSIONS)}"
            )
        
        # Crear directorio si no existe
        upload_dir = Path(settings.UPLOAD_DIR)
        if subdirectorio:
            upload_dir = upload_dir / subdirectorio
        
        upload_dir.mkdir(parents=True, exist_ok=True)
        
        # Generar nombre único
        nuevo_nombre = FileService.generar_nombre_unico(file.filename, prefix)
        file_path = upload_dir / nuevo_nombre
        
        # Guardar archivo
        try:
            contenido = await file.read()
            
            # Validar tamaño
            if len(contenido) > settings.MAX_UPLOAD_SIZE:
                raise HTTPException(
                    status_code=400,
                    detail=f"Archivo demasiado grande. Máximo: {settings.MAX_UPLOAD_SIZE / 1024 / 1024:.2f} MB"
                )
            
            async with aiofiles.open(file_path, 'wb') as f:
                await f.write(contenido)
            
            # Calcular hash
            file_hash = await FileService.calcular_hash(str(file_path))
            
            # Ruta relativa para almacenar en BD
            ruta_relativa = str(Path(subdirectorio) / nuevo_nombre) if subdirectorio else nuevo_nombre
            
            return ruta_relativa, len(contenido), file_hash
            
        except Exception as e:
            # Limpiar archivo si hubo error
            if file_path.exists():
                file_path.unlink()
            raise HTTPException(
                status_code=500,
                detail=f"Error al guardar archivo: {str(e)}"
            )
    
    @staticmethod
    def obtener_ruta_completa(ruta_relativa: str) -> Path:
        """Obtener ruta completa de un archivo"""
        return Path(settings.UPLOAD_DIR) / ruta_relativa
    
    @staticmethod
    def verificar_integridad(file_path: str, hash_esperado: str) -> bool:
        """Verificar integridad de un archivo mediante hash"""
        import asyncio
        hash_actual = asyncio.run(FileService.calcular_hash(file_path))
        return hash_actual == hash_esperado
    
    @staticmethod
    def eliminar_archivo(ruta_relativa: str) -> bool:
        """
        Eliminar archivo del sistema de archivos
        
        Returns:
            True si se eliminó exitosamente, False si no existe
        """
        try:
            file_path = FileService.obtener_ruta_completa(ruta_relativa)
            if file_path.exists():
                file_path.unlink()
                return True
            return False
        except Exception:
            return False
    
    @staticmethod
    def obtener_tipo_mime(filename: str) -> str:
        """Obtener tipo MIME basado en extensión"""
        extension_map = {
            '.pdf': 'application/pdf',
            '.jpg': 'image/jpeg',
            '.jpeg': 'image/jpeg',
            '.png': 'image/png',
        }
        extension = Path(filename).suffix.lower()
        return extension_map.get(extension, 'application/octet-stream')
