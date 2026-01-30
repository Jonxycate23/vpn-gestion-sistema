"""
Servicio de autenticación
"""
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from app.core.security import verify_password, get_password_hash, create_access_token
from app.models import UsuarioSistema
from app.schemas import LoginRequest, LoginResponse, UsuarioResponse
from app.utils.auditoria import AuditoriaService
from typing import Optional


class AuthService:
    """Servicio de autenticación"""
    
    @staticmethod
    def authenticate_user(
        db: Session,
        username: str,
        password: str
    ) -> Optional[UsuarioSistema]:
        """
        Autenticar usuario
        
        Returns:
            Usuario si las credenciales son correctas, None si no
        """
        # print(f"🔍 DEBUG: Intentando autenticar usuario: {username}")
        
        usuario = db.query(UsuarioSistema).filter(
            UsuarioSistema.username == username.lower()
        ).first()
        
        if not usuario:
            # print(f"❌ DEBUG: Usuario {username} no encontrado")
            return None
        
        # print(f"✅ DEBUG: Usuario {username} encontrado")
        # print(f"🔑 DEBUG: Hash en BD: {usuario.password_hash[:50]}...")
        # print(f"🔑 DEBUG: Password recibida: {password}")
        
        password_valida = verify_password(password, usuario.password_hash)
        # print(f"🔍 DEBUG: Resultado verify_password: {password_valida}")
        
        if not password_valida:
            # print(f"❌ DEBUG: Contraseña incorrecta para {username}")
            return None
        
        if not usuario.activo:
            # print(f"❌ DEBUG: Usuario {username} está inactivo")
            return None
        
        # print(f"✅ DEBUG: Autenticación exitosa para {username}")
        return usuario
    
    @staticmethod
    def login(
        db: Session,
        credentials: LoginRequest,
        ip_origen: str
    ) -> LoginResponse:
        """
        Realizar login
        
        Raises:
            HTTPException: Si las credenciales son incorrectas
        """
        usuario = AuthService.authenticate_user(
            db=db,
            username=credentials.username,
            password=credentials.password
        )
        
        if not usuario:
            # Registrar intento fallido si el usuario existe
            usuario_existe = db.query(UsuarioSistema).filter(
                UsuarioSistema.username == credentials.username.lower()
            ).first()
            
            if usuario_existe:
                AuditoriaService.registrar_evento(
                    db=db,
                    usuario=None,
                    accion="LOGIN_FALLIDO",
                    entidad="SISTEMA",
                    detalle={"username": credentials.username},
                    ip_origen=ip_origen
                )
            
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Credenciales incorrectas",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        # Actualizar último login
        usuario.fecha_ultimo_login = datetime.utcnow()
        db.commit()
        
        # Registrar login exitoso
        AuditoriaService.registrar_login(
            db=db,
            usuario=usuario,
            ip_origen=ip_origen,
            exito=True
        )
        
        # Crear token JWT
        access_token = create_access_token(data={"sub": usuario.username})
        
        # Convertir usuario a dict para LoginResponse
        usuario_dict = {
            "id": usuario.id,
            "username": usuario.username,
            "nombre_completo": usuario.nombre_completo,
            "email": usuario.email,
            "rol": usuario.rol,
            "activo": usuario.activo,
            "fecha_creacion": usuario.fecha_creacion,
            "fecha_ultimo_login": usuario.fecha_ultimo_login
        }
        
        return LoginResponse(
            access_token=access_token,
            token_type="bearer",
            usuario=usuario_dict
        )
    
    @staticmethod
    def cambiar_password(
        db: Session,
        usuario: UsuarioSistema,
        password_actual: str,
        password_nueva: str,
        ip_origen: str
    ) -> bool:
        """
        Cambiar contraseña del usuario
        
        Returns:
            True si se cambió exitosamente
            
        Raises:
            HTTPException: Si la contraseña actual es incorrecta
        """
        # Verificar contraseña actual
        if not verify_password(password_actual, usuario.password_hash):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Contraseña actual incorrecta"
            )
        
        # Actualizar contraseña
        usuario.password_hash = get_password_hash(password_nueva)
        db.commit()
        
        # Registrar cambio
        AuditoriaService.registrar_cambio_password(
            db=db,
            usuario=usuario,
            ip_origen=ip_origen
        )
        
        return True