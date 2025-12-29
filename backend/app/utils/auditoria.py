"""
Utilidades de auditoría
"""
from sqlalchemy.orm import Session
from app.models import AuditoriaEvento, UsuarioSistema
from typing import Optional, Any
import json


class AuditoriaService:
    """Servicio de auditoría centralizado"""
    
    @staticmethod
    def registrar_evento(
        db: Session,
        usuario: Optional[UsuarioSistema],
        accion: str,
        entidad: str,
        entidad_id: Optional[int] = None,
        detalle: Optional[dict[str, Any]] = None,
        ip_origen: Optional[str] = None
    ) -> AuditoriaEvento:
        """
        Registrar evento de auditoría
        
        Args:
            db: Sesión de base de datos
            usuario: Usuario que realiza la acción (puede ser None para acciones del sistema)
            accion: Acción realizada (CREATE, UPDATE, DELETE, LOGIN, etc.)
            entidad: Tipo de entidad (PERSONA, SOLICITUD, ACCESO, etc.)
            entidad_id: ID de la entidad afectada
            detalle: Diccionario con detalles adicionales
            ip_origen: IP de origen de la acción
            
        Returns:
            AuditoriaEvento creado
        """
        evento = AuditoriaEvento(
            usuario_id=usuario.id if usuario else None,
            accion=accion,
            entidad=entidad,
            entidad_id=entidad_id,
            detalle_json=detalle,
            ip_origen=ip_origen
        )
        
        db.add(evento)
        db.commit()
        db.refresh(evento)
        
        return evento
    
    @staticmethod
    def registrar_login(
        db: Session,
        usuario: UsuarioSistema,
        ip_origen: str,
        exito: bool = True
    ) -> None:
        """Registrar intento de login"""
        AuditoriaService.registrar_evento(
            db=db,
            usuario=usuario if exito else None,
            accion="LOGIN_EXITOSO" if exito else "LOGIN_FALLIDO",
            entidad="SISTEMA",
            detalle={"username": usuario.username},
            ip_origen=ip_origen
        )
    
    @staticmethod
    def registrar_logout(
        db: Session,
        usuario: UsuarioSistema,
        ip_origen: str
    ) -> None:
        """Registrar logout"""
        AuditoriaService.registrar_evento(
            db=db,
            usuario=usuario,
            accion="LOGOUT",
            entidad="SISTEMA",
            ip_origen=ip_origen
        )
    
    @staticmethod
    def registrar_cambio_password(
        db: Session,
        usuario: UsuarioSistema,
        ip_origen: str
    ) -> None:
        """Registrar cambio de contraseña"""
        AuditoriaService.registrar_evento(
            db=db,
            usuario=usuario,
            accion="CAMBIO_PASSWORD",
            entidad="USUARIO",
            entidad_id=usuario.id,
            ip_origen=ip_origen
        )
    
    @staticmethod
    def registrar_crear(
        db: Session,
        usuario: UsuarioSistema,
        entidad: str,
        entidad_id: int,
        detalle: dict[str, Any],
        ip_origen: str
    ) -> None:
        """Registrar creación de entidad"""
        AuditoriaService.registrar_evento(
            db=db,
            usuario=usuario,
            accion="CREAR",
            entidad=entidad,
            entidad_id=entidad_id,
            detalle=detalle,
            ip_origen=ip_origen
        )
    
    @staticmethod
    def registrar_actualizar(
        db: Session,
        usuario: UsuarioSistema,
        entidad: str,
        entidad_id: int,
        cambios: dict[str, Any],
        ip_origen: str
    ) -> None:
        """Registrar actualización de entidad"""
        AuditoriaService.registrar_evento(
            db=db,
            usuario=usuario,
            accion="ACTUALIZAR",
            entidad=entidad,
            entidad_id=entidad_id,
            detalle={"cambios": cambios},
            ip_origen=ip_origen
        )
    
    @staticmethod
    def registrar_eliminar(
        db: Session,
        usuario: UsuarioSistema,
        entidad: str,
        entidad_id: int,
        motivo: str,
        ip_origen: str
    ) -> None:
        """Registrar eliminación de entidad"""
        AuditoriaService.registrar_evento(
            db=db,
            usuario=usuario,
            accion="ELIMINAR",
            entidad=entidad,
            entidad_id=entidad_id,
            detalle={"motivo": motivo},
            ip_origen=ip_origen
        )
    
    @staticmethod
    def registrar_bloqueo(
        db: Session,
        usuario: UsuarioSistema,
        acceso_id: int,
        bloqueado: bool,
        motivo: str,
        ip_origen: str
    ) -> None:
        """Registrar bloqueo/desbloqueo de acceso"""
        accion = "BLOQUEAR" if bloqueado else "DESBLOQUEAR"
        AuditoriaService.registrar_evento(
            db=db,
            usuario=usuario,
            accion=accion,
            entidad="ACCESO",
            entidad_id=acceso_id,
            detalle={"motivo": motivo},
            ip_origen=ip_origen
        )
    
    @staticmethod
    def registrar_aprobacion(
        db: Session,
        usuario: UsuarioSistema,
        solicitud_id: int,
        aprobada: bool,
        motivo: Optional[str],
        ip_origen: str
    ) -> None:
        """Registrar aprobación/rechazo de solicitud"""
        accion = "APROBAR_SOLICITUD" if aprobada else "RECHAZAR_SOLICITUD"
        AuditoriaService.registrar_evento(
            db=db,
            usuario=usuario,
            accion=accion,
            entidad="SOLICITUD",
            entidad_id=solicitud_id,
            detalle={"motivo": motivo} if motivo else None,
            ip_origen=ip_origen
        )
