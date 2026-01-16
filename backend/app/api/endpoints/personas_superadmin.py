"""
Endpoint actualizado para edición de personas - SUPERADMIN puede editar TODO
📍 Ubicación: backend/app/api/endpoints/personas_superadmin.py
✅ SUPERADMIN puede editar nombre, DPI, NIP incluso con carta generada
"""
from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.schemas import ResponseBase
from app.models import Persona, SolicitudVPN, CartaResponsabilidad, UsuarioSistema
from app.api.dependencies.auth import require_superadmin, get_client_ip
from app.utils.auditoria import AuditoriaService
from pydantic import BaseModel, EmailStr
from typing import Optional

router = APIRouter()


# ========================================
# SCHEMAS
# ========================================

class PersonaEditarCompleta(BaseModel):
    """Schema para edición completa (SUPERADMIN)"""
    nip: Optional[str] = None
    dpi: str  # ✅ Ahora editable
    nombres: str  # ✅ Ahora editable
    apellidos: str  # ✅ Ahora editable
    email: Optional[EmailStr] = None
    cargo: Optional[str] = None
    telefono: Optional[str] = None
    institucion: Optional[str] = None


# ========================================
# EDITAR PERSONA COMPLETA (SOLO SUPERADMIN)
# ========================================

@router.put("/editar-completa/{persona_id}", response_model=ResponseBase)
async def editar_persona_completa(
    persona_id: int,
    data: PersonaEditarCompleta,
    request: Request,
    current_user: UsuarioSistema = Depends(require_superadmin),
    db: Session = Depends(get_db)
):
    """
    Editar TODOS los datos de una persona (incluyendo nombre, DPI, NIP)
    
    ⚠️ SOLO SUPERADMIN
    
    Esta acción permite corregir errores en datos incluso
    cuando ya existe carta generada.
    
    ⚠️ IMPORTANTE: Si la persona tiene carta generada, se recomienda:
    1. Eliminar la carta actual
    2. Editar los datos de la persona
    3. Regenerar la carta con el mismo número
    """
    
    # Obtener persona
    persona = db.query(Persona).filter(Persona.id == persona_id).first()
    
    if not persona:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Persona no encontrada"
        )
    
    # Verificar si el nuevo DPI ya existe en otra persona
    if data.dpi != persona.dpi:
        dpi_existe = db.query(Persona).filter(
            Persona.dpi == data.dpi,
            Persona.id != persona_id
        ).first()
        
        if dpi_existe:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"El DPI {data.dpi} ya está registrado para otra persona"
            )
    
    # Verificar si el nuevo NIP ya existe en otra persona
    if data.nip and data.nip != persona.nip:
        nip_existe = db.query(Persona).filter(
            Persona.nip == data.nip,
            Persona.id != persona_id
        ).first()
        
        if nip_existe:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"El NIP {data.nip} ya está registrado para otra persona"
            )
    
    # Verificar si tiene carta generada (para advertencia en auditoría)
    tiene_carta = db.query(CartaResponsabilidad).join(SolicitudVPN).filter(
        SolicitudVPN.persona_id == persona_id,
        CartaResponsabilidad.eliminada == False
    ).first()
    
    # Registrar cambios para auditoría
    cambios = {}
    
    if data.nip != persona.nip:
        cambios['nip'] = {'anterior': persona.nip, 'nuevo': data.nip}
        persona.nip = data.nip
    
    if data.dpi != persona.dpi:
        cambios['dpi'] = {'anterior': persona.dpi, 'nuevo': data.dpi}
        persona.dpi = data.dpi
    
    if data.nombres != persona.nombres:
        cambios['nombres'] = {'anterior': persona.nombres, 'nuevo': data.nombres}
        persona.nombres = data.nombres
    
    if data.apellidos != persona.apellidos:
        cambios['apellidos'] = {'anterior': persona.apellidos, 'nuevo': data.apellidos}
        persona.apellidos = data.apellidos
    
    if data.email != persona.email:
        cambios['email'] = {'anterior': persona.email, 'nuevo': data.email}
        persona.email = data.email
    
    if data.cargo != persona.cargo:
        cambios['cargo'] = {'anterior': persona.cargo, 'nuevo': data.cargo}
        persona.cargo = data.cargo
    
    if data.telefono != persona.telefono:
        cambios['telefono'] = {'anterior': persona.telefono, 'nuevo': data.telefono}
        persona.telefono = data.telefono
    
    if data.institucion != persona.institucion:
        cambios['institucion'] = {'anterior': persona.institucion, 'nuevo': data.institucion}
        persona.institucion = data.institucion
    
    if not cambios:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No hay cambios para aplicar"
        )
    
    # Commit cambios
    db.commit()
    db.refresh(persona)
    
    # Auditoría detallada
    ip_origen = get_client_ip(request)
    AuditoriaService.registrar_evento(
        db=db,
        usuario=current_user,
        accion="EDITAR_PERSONA_COMPLETA",
        entidad="PERSONA",
        entidad_id=persona.id,
        detalle={
            "cambios": cambios,
            "tiene_carta_activa": tiene_carta is not None,
            "carta_id": tiene_carta.id if tiene_carta else None,
            "advertencia": "Editados datos de persona con carta generada" if tiene_carta else None
        },
        ip_origen=ip_origen
    )
    
    mensaje = f"Datos actualizados exitosamente"
    
    if tiene_carta:
        mensaje += "\n\n⚠️ ADVERTENCIA: Esta persona tiene carta generada.\nSi cambiaste nombre o DPI, considera eliminar y regenerar la carta."
    
    return ResponseBase(
        success=True,
        message=mensaje
    )


# ========================================
# VERIFICAR SI TIENE CARTA ACTIVA
# ========================================

@router.get("/verificar-carta/{persona_id}", response_model=dict)
async def verificar_carta_activa(
    persona_id: int,
    current_user: UsuarioSistema = Depends(require_superadmin),
    db: Session = Depends(get_db)
):
    """
    Verificar si una persona tiene carta activa
    
    Útil antes de editar datos
    """
    
    persona = db.query(Persona).filter(Persona.id == persona_id).first()
    
    if not persona:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Persona no encontrada"
        )
    
    # Buscar cartas activas
    cartas_activas = db.query(CartaResponsabilidad).join(SolicitudVPN).filter(
        SolicitudVPN.persona_id == persona_id,
        CartaResponsabilidad.eliminada == False
    ).all()
    
    return {
        "persona_id": persona_id,
        "nombres": persona.nombres,
        "apellidos": persona.apellidos,
        "dpi": persona.dpi,
        "nip": persona.nip,
        "tiene_cartas_activas": len(cartas_activas) > 0,
        "total_cartas_activas": len(cartas_activas),
        "cartas": [
            {
                "carta_id": c.id,
                "numero": f"{c.numero_carta}-{c.anio_carta}",
                "fecha_generacion": c.fecha_generacion,
                "solicitud_id": c.solicitud_id
            }
            for c in cartas_activas
        ]
    }   