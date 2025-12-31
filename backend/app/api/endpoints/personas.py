"""
Servicio de gestión de Personas - MEJORADO
Incluye búsqueda por DPI y edición de datos
"""
from sqlalchemy.orm import Session
from sqlalchemy import or_, func
from fastapi import HTTPException, status
from typing import List, Optional, Tuple
from app.models import Persona, SolicitudVPN
from app.schemas import PersonaCreate, PersonaUpdate
from app.utils.auditoria import AuditoriaService


class PersonaService:
    """Servicio para gestión de personas (solicitantes VPN)"""
    
    @staticmethod
    def buscar_por_dpi(db: Session, dpi: str) -> Optional[dict]:
        """
        Buscar persona por DPI y retornar datos completos
        
        Returns:
            Diccionario con datos de la persona y su historial, o None si no existe
        """
        persona = db.query(Persona).filter(Persona.dpi == dpi).first()
        
        if not persona:
            return None
        
        # Contar solicitudes
        total_solicitudes = db.query(SolicitudVPN).filter(
            SolicitudVPN.persona_id == persona.id
        ).count()
        
        solicitudes_activas = db.query(SolicitudVPN).filter(
            SolicitudVPN.persona_id == persona.id,
            SolicitudVPN.estado == 'APROBADA'
        ).count()
        
        return {
            "id": persona.id,
            "dpi": persona.dpi,
            "nombres": persona.nombres,
            "apellidos": persona.apellidos,
            "institucion": persona.institucion,
            "cargo": persona.cargo,
            "telefono": persona.telefono,
            "email": persona.email,
            "observaciones": persona.observaciones,
            "activo": persona.activo,
            "fecha_creacion": persona.fecha_creacion,
            "total_solicitudes": total_solicitudes,
            "solicitudes_activas": solicitudes_activas,
            "existe": True  # Flag para indicar que ya existe
        }
    
    @staticmethod
    def crear_o_actualizar(
        db: Session,
        dpi: str,
        data: PersonaCreate,
        usuario_id: int,
        ip_origen: str
    ) -> Persona:
        """
        Crear persona nueva o actualizar si ya existe
        
        Si la persona existe, actualiza solo los campos editables:
        - email
        - cargo
        - telefono
        - institucion (procedencia/destino)
        - observaciones
        """
        persona_existente = db.query(Persona).filter(Persona.dpi == dpi).first()
        
        if persona_existente:
            # Actualizar solo campos editables
            cambios = {}
            
            if data.email and data.email != persona_existente.email:
                cambios['email'] = {'anterior': persona_existente.email, 'nuevo': data.email}
                persona_existente.email = data.email
            
            if data.cargo and data.cargo != persona_existente.cargo:
                cambios['cargo'] = {'anterior': persona_existente.cargo, 'nuevo': data.cargo}
                persona_existente.cargo = data.cargo
            
            if data.telefono and data.telefono != persona_existente.telefono:
                cambios['telefono'] = {'anterior': persona_existente.telefono, 'nuevo': data.telefono}
                persona_existente.telefono = data.telefono
            
            if data.institucion and data.institucion != persona_existente.institucion:
                cambios['institucion'] = {'anterior': persona_existente.institucion, 'nuevo': data.institucion}
                persona_existente.institucion = data.institucion
            
            if data.observaciones and data.observaciones != persona_existente.observaciones:
                cambios['observaciones'] = {'anterior': persona_existente.observaciones, 'nuevo': data.observaciones}
                persona_existente.observaciones = data.observaciones
            
            if cambios:
                db.commit()
                db.refresh(persona_existente)
                
                # Auditoría
                from app.models import UsuarioSistema
                usuario = db.query(UsuarioSistema).filter(UsuarioSistema.id == usuario_id).first()
                AuditoriaService.registrar_actualizar(
                    db=db,
                    usuario=usuario,
                    entidad="PERSONA",
                    entidad_id=persona_existente.id,
                    cambios=cambios,
                    ip_origen=ip_origen
                )
            
            return persona_existente
        else:
            # Crear nueva persona
            persona = Persona(**data.model_dump())
            db.add(persona)
            db.commit()
            db.refresh(persona)
            
            # Auditoría
            from app.models import UsuarioSistema
            usuario = db.query(UsuarioSistema).filter(UsuarioSistema.id == usuario_id).first()
            AuditoriaService.registrar_crear(
                db=db,
                usuario=usuario,
                entidad="PERSONA",
                entidad_id=persona.id,
                detalle={
                    "dpi": persona.dpi,
                    "nombre_completo": f"{persona.nombres} {persona.apellidos}"
                },
                ip_origen=ip_origen
            )
            
            return persona
    
    @staticmethod
    def crear(
        db: Session,
        data: PersonaCreate,
        usuario_id: int,
        ip_origen: str
    ) -> Persona:
        """
        Crear nueva persona
        
        Raises:
            HTTPException: Si el DPI ya existe
        """
        # Verificar que el DPI no exista
        existe = db.query(Persona).filter(Persona.dpi == data.dpi).first()
        if existe:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Ya existe una persona con DPI {data.dpi}"
            )
        
        # Crear persona
        persona = Persona(**data.model_dump())
        db.add(persona)
        db.commit()
        db.refresh(persona)
        
        # Auditoría
        from app.models import UsuarioSistema
        usuario = db.query(UsuarioSistema).filter(UsuarioSistema.id == usuario_id).first()
        AuditoriaService.registrar_crear(
            db=db,
            usuario=usuario,
            entidad="PERSONA",
            entidad_id=persona.id,
            detalle={
                "dpi": persona.dpi,
                "nombre_completo": f"{persona.nombres} {persona.apellidos}"
            },
            ip_origen=ip_origen
        )
        
        return persona
    
    @staticmethod
    def obtener_por_id(db: Session, persona_id: int) -> Optional[Persona]:
        """Obtener persona por ID"""
        return db.query(Persona).filter(Persona.id == persona_id).first()
    
    @staticmethod
    def obtener_por_dpi(db: Session, dpi: str) -> Optional[Persona]:
        """Obtener persona por DPI"""
        return db.query(Persona).filter(Persona.dpi == dpi).first()
    
    @staticmethod
    def listar(
        db: Session,
        skip: int = 0,
        limit: int = 50,
        activo: Optional[bool] = None,
        busqueda: Optional[str] = None
    ) -> Tuple[List[Persona], int]:
        """
        Listar personas con filtros y paginación
        
        Returns:
            Tupla (lista_personas, total_registros)
        """
        query = db.query(Persona)
        
        # Filtro de activos
        if activo is not None:
            query = query.filter(Persona.activo == activo)
        
        # Búsqueda por DPI, nombres o apellidos
        if busqueda:
            search_term = f"%{busqueda}%"
            query = query.filter(
                or_(
                    Persona.dpi.ilike(search_term),
                    Persona.nombres.ilike(search_term),
                    Persona.apellidos.ilike(search_term)
                )
            )
        
        # Total
        total = query.count()
        
        # Paginación
        personas = query.order_by(Persona.fecha_creacion.desc()).offset(skip).limit(limit).all()
        
        return personas, total

    @staticmethod
    def actualizar(
        db: Session,
        persona_id: int,
        data: PersonaUpdate,
        usuario_id: int,
        ip_origen: str
    ) -> Persona:
        """
        Actualizar persona
        
        Raises:
            HTTPException: Si la persona no existe
        """
        persona = PersonaService.obtener_por_id(db, persona_id)
        if not persona:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Persona no encontrada"
            )
        
        # Registrar cambios para auditoría
        cambios = {}
        for field, value in data.model_dump(exclude_unset=True).items():
            old_value = getattr(persona, field)
            if old_value != value:
                cambios[field] = {"anterior": old_value, "nuevo": value}
                setattr(persona, field, value)
        
        if cambios:
            db.commit()
            db.refresh(persona)
            
            # Auditoría
            from app.models import UsuarioSistema
            usuario = db.query(UsuarioSistema).filter(UsuarioSistema.id == usuario_id).first()
            AuditoriaService.registrar_actualizar(
                db=db,
                usuario=usuario,
                entidad="PERSONA",
                entidad_id=persona.id,
                cambios=cambios,
                ip_origen=ip_origen
            )
        
        return persona
    
