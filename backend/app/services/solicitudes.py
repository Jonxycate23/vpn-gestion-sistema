"""
Servicio de gestión de Solicitudes VPN
"""
from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from typing import List, Optional, Tuple
from datetime import date, timedelta
from app.models import (
    SolicitudVPN, AccesoVPN, Persona, UsuarioSistema,
    EstadoSolicitudEnum, TipoSolicitudEnum, EstadoVigenciaEnum
)
from app.schemas import SolicitudCreate, SolicitudAprobar, SolicitudRechazar
from app.utils.auditoria import AuditoriaService


class SolicitudService:
    """Servicio para gestión de solicitudes VPN"""
    
    @staticmethod
    def crear(
        db: Session,
        data: SolicitudCreate,
        usuario_id: int,
        ip_origen: str
    ) -> SolicitudVPN:
        """
        Crear nueva solicitud
        
        Raises:
            HTTPException: Si la persona no existe
        """
        # Verificar que la persona exista
        persona = db.query(Persona).filter(Persona.id == data.persona_id).first()
        if not persona:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Persona no encontrada"
            )
        
        # Verificar si es renovación que tenga solicitud anterior
        if data.tipo_solicitud == TipoSolicitudEnum.RENOVACION:
            tiene_solicitudes = db.query(SolicitudVPN).filter(
                SolicitudVPN.persona_id == data.persona_id,
                SolicitudVPN.estado == EstadoSolicitudEnum.APROBADA
            ).first()
            
            if not tiene_solicitudes:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="No se puede crear renovación sin solicitud anterior aprobada"
                )
        
        # Crear solicitud con estado inicial APROBADA
        # En tu caso específico las solicitudes se crean ya aprobadas
        # Si quieres un flujo de aprobación, cambia el estado inicial
        solicitud = SolicitudVPN(
            persona_id=data.persona_id,
            fecha_solicitud=data.fecha_solicitud,
            tipo_solicitud=data.tipo_solicitud,
            justificacion=data.justificacion,
            estado=EstadoSolicitudEnum.APROBADA,  # Cambiar si necesitas flujo de aprobación
            usuario_registro_id=usuario_id
        )
        
        db.add(solicitud)
        db.commit()
        db.refresh(solicitud)
        
        # Auditoría
        usuario = db.query(UsuarioSistema).filter(UsuarioSistema.id == usuario_id).first()
        AuditoriaService.registrar_crear(
            db=db,
            usuario=usuario,
            entidad="SOLICITUD",
            entidad_id=solicitud.id,
            detalle={
                "persona_dpi": persona.dpi,
                "tipo": data.tipo_solicitud,
                "estado": solicitud.estado
            },
            ip_origen=ip_origen
        )
        
        return solicitud
    
    @staticmethod
    def aprobar(
        db: Session,
        solicitud_id: int,
        data: SolicitudAprobar,
        usuario_id: int,
        ip_origen: str
    ) -> Tuple[SolicitudVPN, AccesoVPN]:
        """
        Aprobar solicitud y crear acceso VPN
        
        Returns:
            Tupla (solicitud, acceso)
        """
        solicitud = db.query(SolicitudVPN).filter(SolicitudVPN.id == solicitud_id).first()
        if not solicitud:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Solicitud no encontrada"
            )
        
        if solicitud.estado == EstadoSolicitudEnum.APROBADA:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="La solicitud ya está aprobada"
            )
        
        # Actualizar solicitud
        solicitud.estado = EstadoSolicitudEnum.APROBADA
        solicitud.comentarios_admin = data.comentarios_admin
        
        # Crear acceso VPN (12 meses)
        fecha_inicio = date.today()
        fecha_fin = fecha_inicio + timedelta(days=365)  # 12 meses
        
        acceso = AccesoVPN(
            solicitud_id=solicitud.id,
            fecha_inicio=fecha_inicio,
            fecha_fin=fecha_fin,
            dias_gracia=data.dias_gracia,
            fecha_fin_con_gracia=fecha_fin + timedelta(days=data.dias_gracia),
            estado_vigencia=EstadoVigenciaEnum.ACTIVO,
            usuario_creacion_id=usuario_id
        )
        
        db.add(acceso)
        db.commit()
        db.refresh(solicitud)
        db.refresh(acceso)
        
        # Auditoría
        usuario = db.query(UsuarioSistema).filter(UsuarioSistema.id == usuario_id).first()
        AuditoriaService.registrar_aprobacion(
            db=db,
            usuario=usuario,
            solicitud_id=solicitud.id,
            aprobada=True,
            motivo=data.comentarios_admin,
            ip_origen=ip_origen
        )
        
        return solicitud, acceso
    
    @staticmethod
    def rechazar(
        db: Session,
        solicitud_id: int,
        data: SolicitudRechazar,
        usuario_id: int,
        ip_origen: str
    ) -> SolicitudVPN:
        """Rechazar solicitud"""
        solicitud = db.query(SolicitudVPN).filter(SolicitudVPN.id == solicitud_id).first()
        if not solicitud:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Solicitud no encontrada"
            )
        
        if solicitud.estado != EstadoSolicitudEnum.APROBADA:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Solo se pueden rechazar solicitudes pendientes"
            )
        
        solicitud.estado = EstadoSolicitudEnum.RECHAZADA
        solicitud.comentarios_admin = data.motivo
        
        db.commit()
        db.refresh(solicitud)
        
        # Auditoría
        usuario = db.query(UsuarioSistema).filter(UsuarioSistema.id == usuario_id).first()
        AuditoriaService.registrar_aprobacion(
            db=db,
            usuario=usuario,
            solicitud_id=solicitud.id,
            aprobada=False,
            motivo=data.motivo,
            ip_origen=ip_origen
        )
        
        return solicitud
    
    @staticmethod
    def listar(
        db: Session,
        skip: int = 0,
        limit: int = 50,
        estado: Optional[str] = None,
        tipo: Optional[str] = None,
        persona_id: Optional[int] = None
    ) -> Tuple[List[SolicitudVPN], int]:
        """Listar solicitudes con filtros"""
        from sqlalchemy.orm import joinedload
        query = db.query(SolicitudVPN).options(
            joinedload(SolicitudVPN.persona),
            joinedload(SolicitudVPN.acceso)
        )
        
        if estado:
            query = query.filter(SolicitudVPN.estado == estado)
        
        if tipo:
            query = query.filter(SolicitudVPN.tipo_solicitud == tipo)
        
        if persona_id:
            query = query.filter(SolicitudVPN.persona_id == persona_id)
        
        total = query.count()
        solicitudes = query.order_by(SolicitudVPN.fecha_solicitud.desc()).offset(skip).limit(limit).all()
        
        return solicitudes, total
    
    @staticmethod
    def obtener_por_id(db: Session, solicitud_id: int) -> Optional[SolicitudVPN]:
        """Obtener solicitud por ID"""
        return db.query(SolicitudVPN).filter(SolicitudVPN.id == solicitud_id).first()
