"""
Servicio de Gestión de Usuarios del Sistema - VERSIÓN SIN AUDITORIA
📍 Ubicación: backend/app/services/usuarios.py
✅ Compatible con tu proyecto - NO usa AuditoriaAccion
"""
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import Optional, Tuple, List
from datetime import datetime
from app.models import UsuarioSistema
from app.core.security import get_password_hash
from fastapi import HTTPException, status


class UsuarioService:
    """Servicio para gestión de usuarios del sistema"""
    
    @staticmethod
    def generar_username(nombres: str, apellidos: str) -> str:
        """
        Generar username automático: primera letra nombre + primer apellido
        Ejemplo: Juan Carlos García López -> jgarcia
        """
        # Tomar primera letra del primer nombre
        primera_letra = nombres.strip().split()[0][0].lower()
        
        # Tomar primer apellido completo
        primer_apellido = apellidos.strip().split()[0].lower()
        
        # Remover acentos y caracteres especiales
        username = f"{primera_letra}{primer_apellido}"
        
        # Reemplazar caracteres especiales
        replacements = {
            'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u',
            'ñ': 'n', 'ü': 'u'
        }
        for old, new in replacements.items():
            username = username.replace(old, new)
        
        return username
    
    @staticmethod
    def crear_usuario(
        db: Session,
        nombres: str,
        apellidos: str,
        email: Optional[str],
        password: str,
        rol: str,
        usuario_creador_id: int,
        ip_origen: str
    ) -> Tuple[UsuarioSistema, str]:
        """
        Crear nuevo usuario del sistema
        
        Returns:
            Tuple[UsuarioSistema, str]: (usuario_creado, username)
        """
        # Generar username
        username = UsuarioService.generar_username(nombres, apellidos)
        
        # Verificar si el username ya existe
        username_existe = db.query(UsuarioSistema).filter(
            UsuarioSistema.username == username
        ).first()
        
        if username_existe:
            # Si existe, agregar número al final
            contador = 1
            username_original = username
            while username_existe:
                username = f"{username_original}{contador}"
                username_existe = db.query(UsuarioSistema).filter(
                    UsuarioSistema.username == username
                ).first()
                contador += 1
        
        # Verificar si el email ya existe (si se proporcionó)
        if email:
            email_existe = db.query(UsuarioSistema).filter(
                UsuarioSistema.email == email
            ).first()
            
            if email_existe:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"El email {email} ya está registrado"
                )
        
        # Hashear contraseña
        password_hash = get_password_hash(password)
        
        # Crear usuario
        nuevo_usuario = UsuarioSistema(
            username=username,
            nombre_completo=f"{nombres} {apellidos}",
            email=email,
            password_hash=password_hash,
            rol=rol,
            activo=True,
            fecha_creacion=datetime.now()
        )
        
        db.add(nuevo_usuario)
        db.commit()
        db.refresh(nuevo_usuario)
        
        # ✅ Registrar en auditoría usando AuditoriaEvento (si existe)
        try:
            from app.models import AuditoriaEvento
            auditoria = AuditoriaEvento(
                usuario_id=usuario_creador_id,
                accion="CREAR_USUARIO_SISTEMA",
                entidad="USUARIO",
                entidad_id=nuevo_usuario.id,
                detalle_json={
                    "username": username,
                    "nombre_completo": nuevo_usuario.nombre_completo,
                    "rol": rol
                },
                ip_origen=ip_origen,
                fecha=datetime.now()
            )
            db.add(auditoria)
            db.commit()
        except ImportError:
            # Si no existe AuditoriaEvento, continuar sin auditoría
            pass
        
        return nuevo_usuario, username
    
    @staticmethod
    def listar_usuarios(
        db: Session,
        skip: int = 0,
        limit: int = 50,
        activo: Optional[bool] = None
    ) -> Tuple[List[UsuarioSistema], int]:
        """
        Listar usuarios del sistema con paginación
        
        Returns:
            Tuple[List[UsuarioSistema], int]: (usuarios, total)
        """
        query = db.query(UsuarioSistema)
        
        # Filtrar por estado activo si se especifica
        if activo is not None:
            query = query.filter(UsuarioSistema.activo == activo)
        
        # Contar total
        total = query.count()
        
        # Obtener usuarios paginados
        usuarios = query.order_by(
            UsuarioSistema.fecha_creacion.desc()
        ).offset(skip).limit(limit).all()
        
        return usuarios, total
    
    @staticmethod
    def obtener_por_id(db: Session, usuario_id: int) -> Optional[UsuarioSistema]:
        """Obtener usuario por ID"""
        return db.query(UsuarioSistema).filter(
            UsuarioSistema.id == usuario_id
        ).first()
    
    @staticmethod
    def obtener_por_username(db: Session, username: str) -> Optional[UsuarioSistema]:
        """Obtener usuario por username"""
        return db.query(UsuarioSistema).filter(
            UsuarioSistema.username == username
        ).first()
    
    @staticmethod
    def activar_desactivar(
        db: Session,
        usuario_id: int,
        activo: bool,
        usuario_modificador_id: int,
        ip_origen: str
    ) -> UsuarioSistema:
        """
        Activar o desactivar usuario
        """
        usuario = UsuarioService.obtener_por_id(db, usuario_id)
        
        if not usuario:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Usuario no encontrado"
            )
        
        # No permitir desactivarse a sí mismo
        if usuario_id == usuario_modificador_id and not activo:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No puedes desactivarte a ti mismo"
            )
        
        # Actualizar estado
        usuario.activo = activo
        db.commit()
        db.refresh(usuario)
        
        # Registrar en auditoría (si existe)
        try:
            from app.models import AuditoriaEvento
            accion = "ACTIVAR_USUARIO" if activo else "DESACTIVAR_USUARIO"
            auditoria = AuditoriaEvento(
                usuario_id=usuario_modificador_id,
                accion=accion,
                entidad="USUARIO",
                entidad_id=usuario.id,
                detalle_json={
                    "username": usuario.username,
                    "nuevo_estado": activo
                },
                ip_origen=ip_origen,
                fecha=datetime.now()
            )
            db.add(auditoria)
            db.commit()
        except ImportError:
            pass
        
        return usuario
    
    @staticmethod
    def actualizar_ultimo_login(db: Session, usuario_id: int):
        """Actualizar fecha de último login"""
        usuario = UsuarioService.obtener_por_id(db, usuario_id)
        if usuario:
            usuario.fecha_ultimo_login = datetime.now()
            db.commit()
    
    @staticmethod
    def cambiar_password(
        db: Session,
        usuario_id: int,
        password_actual: str,
        password_nueva: str,
        ip_origen: str
    ) -> bool:
        """
        Cambiar contraseña de usuario
        """
        from app.core.security import verify_password
        
        usuario = UsuarioService.obtener_por_id(db, usuario_id)
        
        if not usuario:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Usuario no encontrado"
            )
        
        # Verificar contraseña actual
        if not verify_password(password_actual, usuario.password_hash):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Contraseña actual incorrecta"
            )
        
        # Validar nueva contraseña
        if len(password_nueva) < 6:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="La nueva contraseña debe tener al menos 6 caracteres"
            )
        
        # Actualizar contraseña
        usuario.password_hash = get_password_hash(password_nueva)
        db.commit()
        
        # Registrar en auditoría (si existe)
        try:
            from app.models import AuditoriaEvento
            auditoria = AuditoriaEvento(
                usuario_id=usuario_id,
                accion="CAMBIAR_PASSWORD",
                entidad="USUARIO",
                entidad_id=usuario.id,
                detalle_json={"mensaje": "Contraseña cambiada por el usuario"},
                ip_origen=ip_origen,
                fecha=datetime.now()
            )
            db.add(auditoria)
            db.commit()
        except ImportError:
            pass
        
        return True
    
    @staticmethod
    def resetear_password(
        db: Session,
        usuario_id: int,
        password_nueva: str,
        usuario_admin_id: int,
        ip_origen: str
    ) -> bool:
        """
        Resetear contraseña de un usuario (solo SUPERADMIN)
        """
        usuario = UsuarioService.obtener_por_id(db, usuario_id)
        
        if not usuario:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Usuario no encontrado"
            )
        
        # Actualizar contraseña
        usuario.password_hash = get_password_hash(password_nueva)
        db.commit()
        
        # Registrar en auditoría (si existe)
        try:
            from app.models import AuditoriaEvento
            auditoria = AuditoriaEvento(
                usuario_id=usuario_admin_id,
                accion="RESETEAR_PASSWORD",
                entidad="USUARIO",
                entidad_id=usuario.id,
                detalle_json={
                    "mensaje": f"Contraseña reseteada para usuario {usuario.username}"
                },
                ip_origen=ip_origen,
                fecha=datetime.now()
            )
            db.add(auditoria)
            db.commit()
        except ImportError:
            pass
        
        return True