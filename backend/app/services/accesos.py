"""
Servicio de gestión de Accesos VPN y Bloqueos
"""
from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from typing import List, Optional
from datetime import date, timedelta
from app.models import AccesoVPN, BloqueoVPN, UsuarioSistema, EstadoBloqueoEnum
from app.schemas import AccesoProrrogar, BloqueoCreate
from app.utils.auditoria import AuditoriaService


class AccesoService:
    """Servicio para gestión de accesos VPN"""
    
    @staticmethod
    def obtener_por_id(db: Session, acceso_id: int) -> Optional[AccesoVPN]:
        """Obtener acceso por ID"""
        return db.query(AccesoVPN).filter(AccesoVPN.id == acceso_id).first()
    
    @staticmethod
    def prorrogar(
        db: Session,
        acceso_id: int,
        data: AccesoProrrogar,
        usuario_id: int,
        ip_origen: str
    ) -> AccesoVPN:
        """
        Prorrogar acceso VPN (agregar días de gracia)
        
        Raises:
            HTTPException: Si el acceso no existe
        """
        acceso = AccesoService.obtener_por_id(db, acceso_id)
        if not acceso:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Acceso no encontrado"
            )
        
        # Guardar valores anteriores para auditoría
        dias_gracia_anterior = acceso.dias_gracia
        fecha_anterior = acceso.fecha_fin_con_gracia
        
        # Actualizar días de gracia del acceso
        acceso.dias_gracia += data.dias_adicionales
        acceso.fecha_fin_con_gracia = acceso.fecha_fin + timedelta(days=acceso.dias_gracia)
        
        # ✅ Actualizar solicitud asociada: estado APROBADA + justificacion con el motivo
        from app.models import SolicitudVPN
        solicitud = db.query(SolicitudVPN).filter(
            SolicitudVPN.id == acceso.solicitud_id
        ).first()
        if solicitud:
            solicitud.estado = 'APROBADA'
            solicitud.justificacion = f"Prórroga +{data.dias_adicionales} días: {data.motivo}"
            db.add(solicitud)
        
        db.commit()
        db.refresh(acceso)
        
        # Auditoría
        usuario = db.query(UsuarioSistema).filter(UsuarioSistema.id == usuario_id).first()
        AuditoriaService.registrar_actualizar(
            db=db,
            usuario=usuario,
            entidad="ACCESO",
            entidad_id=acceso.id,
            cambios={
                "dias_gracia": {
                    "anterior": dias_gracia_anterior,
                    "nuevo": acceso.dias_gracia
                },
                "fecha_fin_con_gracia": {
                    "anterior": str(fecha_anterior),
                    "nuevo": str(acceso.fecha_fin_con_gracia)
                },
                "motivo": data.motivo
            },
            ip_origen=ip_origen
        )
        
        return acceso
    
    @staticmethod
    def obtener_estado_bloqueo(db: Session, acceso_id: int) -> str:
        """Obtener estado actual de bloqueo de un acceso"""
        ultimo_bloqueo = db.query(BloqueoVPN).filter(
            BloqueoVPN.acceso_vpn_id == acceso_id
        ).order_by(BloqueoVPN.fecha_cambio.desc()).first()
        
        if ultimo_bloqueo:
            return ultimo_bloqueo.estado
        return EstadoBloqueoEnum.DESBLOQUEADO.value


class BloqueoService:
    """Servicio para gestión de bloqueos VPN"""
    
    @staticmethod
    def cambiar_estado(
        db: Session,
        data: BloqueoCreate,
        usuario_id: int,
        ip_origen: str
    ) -> BloqueoVPN:
        """
        Bloquear o desbloquear acceso VPN
        
        Raises:
            HTTPException: Si el acceso no existe
        """
        # Verificar que el acceso exista
        acceso = db.query(AccesoVPN).filter(AccesoVPN.id == data.acceso_vpn_id).first()
        if not acceso:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Acceso VPN no encontrado"
            )
        
        # Verificar estado actual
        estado_actual = AccesoService.obtener_estado_bloqueo(db, data.acceso_vpn_id)
        
        if estado_actual == data.estado:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"El acceso ya está en estado {data.estado}"
            )
        
        # ✅ NUEVO: Obtener la solicitud asociada al acceso
        from app.models import SolicitudVPN
        solicitud = db.query(SolicitudVPN).filter(
            SolicitudVPN.id == acceso.solicitud_id
        ).first()
        
        # ✅ NUEVO: Actualizar campos de la solicitud según la acción
        if solicitud:
            if data.estado == EstadoBloqueoEnum.BLOQUEADO:
                # Al bloquear: reemplazar la justificación con el motivo del bloqueo
                solicitud.justificacion = data.motivo
                solicitud.estado = 'CANCELADA'
            else:
                # Al desbloquear: restaurar estado a APROBADA (con acceso y carta activa)
                solicitud.estado = 'APROBADA'
                solicitud.justificacion = f"Desbloqueado: {data.motivo}"
            
            # ✅ Asegurar que los cambios se registren en la sesión
            db.add(solicitud)
        
        # Crear registro de bloqueo/desbloqueo
        bloqueo = BloqueoVPN(
            acceso_vpn_id=data.acceso_vpn_id,
            estado=data.estado,
            motivo=data.motivo,
            usuario_id=usuario_id
        )
        
        db.add(bloqueo)
        
        # ✅ Commit único para guardar todos los cambios (solicitud + bloqueo)
        db.commit()
        db.refresh(bloqueo)
        
        # Auditoría
        usuario = db.query(UsuarioSistema).filter(UsuarioSistema.id == usuario_id).first()
        AuditoriaService.registrar_bloqueo(
            db=db,
            usuario=usuario,
            acceso_id=data.acceso_vpn_id,
            bloqueado=(data.estado == EstadoBloqueoEnum.BLOQUEADO),
            motivo=data.motivo,
            ip_origen=ip_origen
        )
        
        return bloqueo
    
    @staticmethod
    def obtener_historial(
        db: Session,
        acceso_id: int
    ) -> List[BloqueoVPN]:
        """Obtener historial de bloqueos de un acceso"""
        return db.query(BloqueoVPN).filter(
            BloqueoVPN.acceso_vpn_id == acceso_id
        ).order_by(BloqueoVPN.fecha_cambio.desc()).all()
