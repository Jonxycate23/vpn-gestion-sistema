"""
Servicio de gestión de Usuarios del Sistema
"""
from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from typing import List, Optional, Tuple
from app.models import UsuarioSistema
from app.schemas import UsuarioCreate, UsuarioUpdate
from app.core.security import get_password_hash
from app.services.username_generator import UsernameGenerator
from app.utils.auditoria import AuditoriaService


class UsuarioService:
    """Servicio para gestión de usuarios del sistema"""
    
    @staticmethod
    def crear_usuario(
        db: Session,
        nombres: str,
        apellidos: str,
        email: str,
        rol: str,
        usuario_creador_id: int,
        ip_origen: str
    ) -> UsuarioSistema:
        """
        Crear nuevo usuario del sistema
        
        Genera username automáticamente basado en nombres y apellidos
        Genera contraseña inicial: Usuario.2025!
        
        Args:
            db: Sesión de base de datos
            nombres: Nombres del usuario
            apellidos: Apellidos del usuario
            email: Email del usuario
            rol: Rol (ADMIN o SUPERADMIN)
            usuario_creador_id: ID del usuario que está creando
            ip_origen: IP de origen
            
        Returns:
            Usuario creado
        """
        # Generar username único
        username = UsernameGenerator.generar_username(db, nombres, apellidos)
        
        # Contraseña inicial: Usuario.2025!
        password_inicial = "Usuario.2025!"
        password_hash = get_password_hash(password_inicial)
        
        # Crear usuario
        usuario = UsuarioSistema(
            username=username,
            password_hash=password_hash,
            nombre_completo=f"{nombres} {apellidos}",
            email=email,
            rol=rol,
            activo=True
        )
        
        db.add(usuario)
        db.commit()
        db.refresh(usuario)
        
        # Auditoría
        usuario_creador = db.query(UsuarioSistema).filter(
            UsuarioSistema.id == usuario_creador_id
        ).first()
        
        AuditoriaService.registrar_crear(
            db=db,
            usuario=usuario_creador,
            entidad="USUARIO",
            entidad_id=usuario.id,
            detalle={
                "username": usuario.username,
                "nombre_completo": usuario.nombre_completo,
                "rol": usuario.rol,
                "password_inicial": "Usuario.2025!"
            },
            ip_origen=ip_origen
        )
        
        return usuario, password_inicial
    
    @staticmethod
    def listar_usuarios(
        db: Session,
        skip: int = 0,
        limit: int = 50,
        activo: Optional[bool] = None
    ) -> Tuple[List[UsuarioSistema], int]:
        """Listar usuarios del sistema"""
        query = db.query(UsuarioSistema)
        
        if activo is not None:
            query = query.filter(UsuarioSistema.activo == activo)
        
        total = query.count()
        usuarios = query.order_by(UsuarioSistema.nombre_completo).offset(skip).limit(limit).all()
        
        return usuarios, total
    
    @staticmethod
    def activar_desactivar(
        db: Session,
        usuario_id: int,
        activo: bool,
        usuario_modificador_id: int,
        ip_origen: str
    ) -> UsuarioSistema:
        """Activar o desactivar usuario"""
        usuario = db.query(UsuarioSistema).filter(
            UsuarioSistema.id == usuario_id
        ).first()
        
        if not usuario:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Usuario no encontrado"
            )
        
        if usuario.id == usuario_modificador_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No puedes desactivarte a ti mismo"
            )
        
        usuario.activo = activo
        db.commit()
        db.refresh(usuario)
        
        # Auditoría
        usuario_modificador = db.query(UsuarioSistema).filter(
            UsuarioSistema.id == usuario_modificador_id
        ).first()
        
        accion = "ACTIVAR_USUARIO" if activo else "DESACTIVAR_USUARIO"
        AuditoriaService.registrar_evento(
            db=db,
            usuario=usuario_modificador,
            accion=accion,
            entidad="USUARIO",
            entidad_id=usuario.id,
            detalle={
                "username": usuario.username,
                "nuevo_estado": activo
            },
            ip_origen=ip_origen
        )
        
        return usuario