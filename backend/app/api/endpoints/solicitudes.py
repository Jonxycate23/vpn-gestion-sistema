"""
Endpoints de Solicitudes VPN - VERSIÓN COMPLETA CON PDF + ACCESO AUTOMÁTICO
📍 Ubicación: backend/app/api/endpoints/solicitudes.py
REEMPLAZA COMPLETAMENTE EL ARCHIVO ACTUAL
"""
from fastapi import APIRouter, Depends, status, Request, Query, HTTPException
from sqlalchemy.orm import Session
from typing import Optional
from datetime import date, timedelta
from app.core.database import get_db
from app.schemas import (
    SolicitudCreate,
    SolicitudAprobar,
    SolicitudRechazar,
    PersonaCreate,
    ResponseBase
)
from app.services.solicitudes import SolicitudService
from app.services.personas import PersonaService
from app.api.dependencies.auth import get_current_active_user, get_client_ip
from app.models import (
    UsuarioSistema, 
    SolicitudVPN, 
    CartaResponsabilidad,
    Persona,
    AccesoVPN
)
from app.utils.auditoria import AuditoriaService

# Para generar PDF
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY
import os

router = APIRouter()


# ========================================
# BÚSQUEDA POR DPI
# ========================================

@router.get("/buscar-dpi/{dpi}", response_model=dict)
async def buscar_persona_por_dpi(
    dpi: str,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Buscar persona por DPI"""
    persona = PersonaService.obtener_por_dpi(db=db, dpi=dpi)
    
    if persona is None:
        return {"existe": False}
    
    total_solicitudes = db.query(SolicitudVPN).filter(
        SolicitudVPN.persona_id == persona.id
    ).count()
    
    return {
        "existe": True,
        "id": persona.id,
        "dpi": persona.dpi,
        "nip": getattr(persona, 'nip', None),
        "nombres": persona.nombres,
        "apellidos": persona.apellidos,
        "institucion": persona.institucion,
        "cargo": persona.cargo,
        "telefono": persona.telefono,
        "email": persona.email,
        "total_solicitudes": total_solicitudes
    }


# ========================================
# CREAR/ACTUALIZAR PERSONA
# ========================================

@router.post("/persona", response_model=dict, status_code=status.HTTP_200_OK)
async def crear_o_actualizar_persona(
    data: PersonaCreate,
    request: Request,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Crear nueva persona o actualizar si ya existe"""
    ip_origen = get_client_ip(request)
    persona_existente = PersonaService.obtener_por_dpi(db=db, dpi=data.dpi)
    
    if persona_existente:
        if hasattr(persona_existente, 'nip') and hasattr(data, 'nip'):
            persona_existente.nip = data.nip
        persona_existente.email = data.email
        persona_existente.cargo = data.cargo
        persona_existente.telefono = data.telefono
        persona_existente.institucion = data.institucion
        
        db.commit()
        db.refresh(persona_existente)
        
        return {
            "success": True,
            "message": "Datos actualizados exitosamente",
            "persona_id": persona_existente.id
        }
    else:
        persona = PersonaService.crear(
            db=db,
            data=data,
            usuario_id=current_user.id,
            ip_origen=ip_origen
        )
        
        return {
            "success": True,
            "message": "Persona creada exitosamente",
            "persona_id": persona.id
        }


# ========================================
# CREAR SOLICITUD
# ========================================

@router.post("/", response_model=dict, status_code=status.HTTP_201_CREATED)
async def crear_solicitud(
    data: dict,  # Cambiado a dict para recibir campos adicionales
    request: Request,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Crear nueva solicitud VPN con campos adicionales"""
    ip_origen = get_client_ip(request)
    
    # Verificar que la persona exista
    persona = db.query(Persona).filter(Persona.id == data['persona_id']).first()
    if not persona:
        raise HTTPException(status_code=404, detail="Persona no encontrada")
    
    # Crear solicitud con TODOS los campos
    solicitud = SolicitudVPN(
        persona_id=data['persona_id'],
        numero_oficio=data.get('numero_oficio'),
        numero_providencia=data.get('numero_providencia'),
        fecha_recepcion=date.fromisoformat(data['fecha_recepcion']) if data.get('fecha_recepcion') else None,
        fecha_solicitud=date.fromisoformat(data['fecha_solicitud']),
        tipo_solicitud=data['tipo_solicitud'],
        justificacion=data['justificacion'],
        estado='APROBADA',  # Crear ya aprobada
        usuario_registro_id=current_user.id
    )
    
    db.add(solicitud)
    db.commit()
    db.refresh(solicitud)
    
    # Auditoría
    AuditoriaService.registrar_crear(
        db=db,
        usuario=current_user,
        entidad="SOLICITUD",
        entidad_id=solicitud.id,
        detalle={
            "persona_dpi": persona.dpi,
            "tipo": data['tipo_solicitud'],
            "estado": solicitud.estado,
            "numero_oficio": data.get('numero_oficio'),
            "numero_providencia": data.get('numero_providencia')
        },
        ip_origen=ip_origen
    )
    
    return {
        "success": True,
        "message": "Solicitud creada exitosamente",
        "solicitud_id": solicitud.id
    }


# ========================================
# LISTAR SOLICITUDES
# ========================================

@router.get("/", response_model=dict)
async def listar_solicitudes(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=200),
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Listar solicitudes con carta_generada"""
    solicitudes, total = SolicitudService.listar(db=db, skip=skip, limit=limit)
    
    result = []
    for sol in solicitudes:
        carta = db.query(CartaResponsabilidad).filter(
            CartaResponsabilidad.solicitud_id == sol.id
        ).first()
        
        result.append({
            "id": sol.id,
            "persona_id": sol.persona_id,
            "numero_oficio": sol.numero_oficio,
            "numero_providencia": sol.numero_providencia,
            "fecha_recepcion": sol.fecha_recepcion,
            "fecha_solicitud": sol.fecha_solicitud,
            "tipo_solicitud": sol.tipo_solicitud,
            "justificacion": sol.justificacion,
            "estado": sol.estado,
            "comentarios_admin": sol.comentarios_admin,
            "persona_nombres": sol.persona.nombres,
            "persona_apellidos": sol.persona.apellidos,
            "persona_dpi": sol.persona.dpi,
            "carta_generada": carta is not None,
            "acceso_id": sol.acceso.id if sol.acceso else None
        })
    
    return {
        "total": total,
        "solicitudes": result
    }


# ========================================
# DETALLE DE SOLICITUD
# ========================================

@router.get("/{solicitud_id}", response_model=dict)
async def obtener_solicitud(
    solicitud_id: int,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Obtener solicitud por ID"""
    solicitud = SolicitudService.obtener_por_id(db=db, solicitud_id=solicitud_id)
    if not solicitud:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
    
    return {
        "id": solicitud.id,
        "persona_id": solicitud.persona_id,
        "numero_oficio": solicitud.numero_oficio,
        "numero_providencia": solicitud.numero_providencia,
        "fecha_recepcion": solicitud.fecha_recepcion,
        "tipo_solicitud": solicitud.tipo_solicitud,
        "justificacion": solicitud.justificacion,
        "estado": solicitud.estado,
        "comentarios_admin": solicitud.comentarios_admin,
        "persona": {
            "id": solicitud.persona.id,
            "dpi": solicitud.persona.dpi,
            "nip": getattr(solicitud.persona, 'nip', None),
            "nombres": solicitud.persona.nombres,
            "apellidos": solicitud.persona.apellidos,
            "institucion": solicitud.persona.institucion,
            "cargo": solicitud.persona.cargo,
            "email": solicitud.persona.email,
            "telefono": solicitud.persona.telefono
        },
        "acceso": {
            "id": solicitud.acceso.id,
            "fecha_fin": solicitud.acceso.fecha_fin
        } if solicitud.acceso else None
    }


# ========================================
# GENERAR CARTA DE RESPONSABILIDAD PDF + CREAR ACCESO
# ========================================

def generar_carta_pdf(solicitud: SolicitudVPN, carta: CartaResponsabilidad, db: Session):
    """Genera PDF de carta de responsabilidad con formato oficial PNC"""
    
    # Directorio de salida
    output_dir = "/var/vpn_archivos/cartas"
    os.makedirs(output_dir, exist_ok=True)
    
    # Nombre del archivo
    persona = solicitud.persona
    filename = f"CARTA_{carta.id}_{persona.dpi}.pdf"
    filepath = os.path.join(output_dir, filename)
    
    # Crear PDF en A4
    doc = SimpleDocTemplate(filepath, pagesize=A4,
                           topMargin=1.5*cm, bottomMargin=1.5*cm,
                           leftMargin=2*cm, rightMargin=2*cm)
    story = []
    styles = getSampleStyleSheet()
    
    # Estilo de título centrado
    title_style = ParagraphStyle(
        'CustomTitle',
        parent=styles['Heading1'],
        fontSize=12,
        textColor=colors.black,
        spaceAfter=20,
        alignment=TA_CENTER,
        fontName='Helvetica-Bold',
        leading=14
    )
    
    # Estilo normal justificado
    normal_justified = ParagraphStyle(
        'NormalJustified',
        parent=styles['Normal'],
        fontSize=9,
        alignment=TA_JUSTIFY,
        leading=12
    )
    
    # TÍTULO
    story.append(Paragraph(
        "<b>CARTA DE RESPONSABILIDAD DE USO Y ACCESO POR VPN<br/>A LA RED INSTITUCIONAL DE LA POLICÍA NACIONAL CIVIL</b>",
        title_style
    ))
    
    # Documento No
    story.append(Paragraph(f"<b>Documento No: {carta.id}-2025</b>", title_style))
    story.append(Spacer(1, 0.3*cm))
    
    # Texto introductorio
    intro = """
    En las instalaciones que ocupa el Departamento de Operaciones de Seguridad Informática de la 
    Subdirección General de Tecnologías de la Información y la Comunicación, se suscribe la presente 
    CARTA DE RESPONSABILIDAD con la que <b>EL USUARIO</b> acepta formalmente las condiciones de uso y acceso 
    por medio del servicio de VPN, por medio de un "usuario" y "contraseña" con los cuales se le otorga 
    la facultad de acceder al sistema de Escritorio Policial y Sistema Solvencias de la Policía Nacional Civil.
    """
    story.append(Paragraph(intro, normal_justified))
    story.append(Spacer(1, 0.4*cm))
    
    # Obligaciones (1-7) - Texto resumido
    obligaciones = [
        "EL USUARIO y CONTRASEÑA asignados son datos intransferibles, confidenciales y personales.",
        "EL USUARIO tiene prohibido compartir información confidencial.",
        "El USUARIO se compromete a utilizar el servicio VPN únicamente para fines laborales.",
        "EL USUARIO debe reportar inmediatamente cualquier incidente de seguridad.",
        "El acceso tiene vigencia de 12 meses y debe renovarse oportunamente.",
        "EL USUARIO acepta cumplir todos los lineamientos de seguridad.",
        "La Subdirección se reserva el derecho de bloquear usuarios por uso inapropiado."
    ]
    
    for i, ob in enumerate(obligaciones, 1):
        story.append(Paragraph(f"<b>{i}.</b> {ob}", normal_justified))
        story.append(Spacer(1, 0.2*cm))
    
    story.append(Spacer(1, 0.4*cm))
    
    # Datos del usuario
    fecha_expiracion = date.today() + timedelta(days=365)
    
    datos_usuario = [
        ['Responsable:', f"{persona.nombres} {persona.apellidos}", 'Usuario:', persona.email or 'N/A'],
        ['DPI:', persona.dpi, 'Teléfono:', persona.telefono or 'N/A'],
        ['Destino:', persona.institucion or 'N/A', 'Fecha Expiración:', fecha_expiracion.strftime("%d/%m/%Y")]
    ]
    
    t = Table(datos_usuario, colWidths=[3*cm, 5*cm, 3*cm, 5*cm])
    t.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTNAME', (2, 0), (2, -1), 'Helvetica-Bold'),
        ('GRID', (0, 0), (-1, -1), 1, colors.black),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
    ]))
    story.append(t)
    story.append(Spacer(1, 0.8*cm))
    
    # Fecha y firmas
    fecha_hoy = date.today()
    story.append(Paragraph(f"<b>Guatemala, {fecha_hoy.strftime('%d/%m/%Y')}</b>", normal_justified))
    story.append(Spacer(1, 1.5*cm))
    
    # Firmas
    firmas = [
        ['f. _________________________', 'f. _________________________'],
        ['Firmo y recibo conforme', 'Firmo y entrego DOSI/SGTIC']
    ]
    
    t_firmas = Table(firmas, colWidths=[8*cm, 8*cm])
    t_firmas.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
    ]))
    story.append(t_firmas)
    
    # Construir PDF
    doc.build(story)
    
    return filepath


@router.post("/{solicitud_id}/crear-carta", response_model=dict)
async def crear_carta_responsabilidad(
    solicitud_id: int,
    request: Request,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Crear carta de responsabilidad, PDF y acceso VPN automáticamente"""
    ip_origen = get_client_ip(request)
    
    # Verificar solicitud
    solicitud = db.query(SolicitudVPN).filter(SolicitudVPN.id == solicitud_id).first()
    if not solicitud:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
    
    if solicitud.estado != 'APROBADA':
        raise HTTPException(status_code=400, detail="Solo solicitudes APROBADAS")
    
    # Verificar que no exista carta
    carta_existente = db.query(CartaResponsabilidad).filter(
        CartaResponsabilidad.solicitud_id == solicitud_id
    ).first()
    
    if carta_existente:
        raise HTTPException(status_code=400, detail="Ya existe carta")
    
    # Crear carta
    carta = CartaResponsabilidad(
        solicitud_id=solicitud_id,
        tipo='RESPONSABILIDAD',
        fecha_generacion=date.today(),
        generada_por_usuario_id=current_user.id
    )
    db.add(carta)
    db.flush()  # Para obtener el ID
    
    # Generar PDF
    try:
        pdf_path = generar_carta_pdf(solicitud, carta, db)
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error generando PDF: {str(e)}")
    
    # ✅ CREAR ACCESO VPN AUTOMÁTICAMENTE
    fecha_inicio = date.today()
    fecha_fin = fecha_inicio + timedelta(days=365)
    
    acceso = AccesoVPN(
        solicitud_id=solicitud_id,
        fecha_inicio=fecha_inicio,
        fecha_fin=fecha_fin,
        dias_gracia=0,
        fecha_fin_con_gracia=fecha_fin,
        estado_vigencia='ACTIVO',
        usuario_creacion_id=current_user.id
    )
    db.add(acceso)
    db.commit()
    db.refresh(carta)
    db.refresh(acceso)
    
    # Auditoría
    AuditoriaService.registrar_crear(
        db=db,
        usuario=current_user,
        entidad="CARTA",
        entidad_id=carta.id,
        detalle={
            "solicitud_id": solicitud_id,
            "acceso_id": acceso.id,
            "pdf_generado": True,
            "pdf_path": pdf_path
        },
        ip_origen=ip_origen
    )
    
    return {
        "success": True,
        "message": "Carta creada, PDF generado y acceso VPN activado",
        "carta_id": carta.id,
        "acceso_id": acceso.id,
        "pdf_path": pdf_path
    }


# ========================================
# MARCAR COMO NO SE PRESENTÓ
# ========================================

@router.post("/{solicitud_id}/no-presentado", response_model=dict)
async def marcar_no_presentado(
    solicitud_id: int,
    request: Request,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Marcar como 'No se presentó'"""
    ip_origen = get_client_ip(request)
    
    try:
        body = await request.json()
        motivo = body.get('motivo', 'No se presentó')
    except:
        motivo = 'No se presentó'
    
    solicitud = db.query(SolicitudVPN).filter(SolicitudVPN.id == solicitud_id).first()
    if not solicitud:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
    
    solicitud.estado = 'CANCELADA'
    solicitud.comentarios_admin = f"NO_PRESENTADO: {motivo}"
    
    db.commit()
    
    return {
        "success": True,
        "message": "Marcado como 'No se presentó'"
    }


# ========================================
# REACTIVAR SOLICITUD
# ========================================

@router.post("/{solicitud_id}/reactivar", response_model=dict)
async def reactivar_solicitud(
    solicitud_id: int,
    request: Request,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Reactivar solicitud cancelada"""
    ip_origen = get_client_ip(request)
    
    solicitud = db.query(SolicitudVPN).filter(SolicitudVPN.id == solicitud_id).first()
    if not solicitud:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
    
    if solicitud.estado != 'CANCELADA':
        raise HTTPException(status_code=400, detail="Solo solicitudes CANCELADAS")
    
    solicitud.estado = 'APROBADA'
    solicitud.comentarios_admin = f"REACTIVADA: {solicitud.comentarios_admin}"
    
    db.commit()
    
    return {
        "success": True,
        "message": "Solicitud reactivada"
    }


# ========================================
# EDITAR SOLICITUD
# ========================================

@router.put("/{solicitud_id}", response_model=dict)
async def editar_solicitud(
    solicitud_id: int,
    data: dict,
    request: Request,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Editar solicitud"""
    solicitud = db.query(SolicitudVPN).filter(SolicitudVPN.id == solicitud_id).first()
    if not solicitud:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
    
    # Verificar que no tenga carta
    carta = db.query(CartaResponsabilidad).filter(
        CartaResponsabilidad.solicitud_id == solicitud_id
    ).first()
    
    if carta:
        raise HTTPException(status_code=400, detail="No se puede editar: ya tiene carta")
    
    if "tipo_solicitud" in data:
        solicitud.tipo_solicitud = data["tipo_solicitud"]
    
    if "justificacion" in data:
        solicitud.justificacion = data["justificacion"]
    
    db.commit()
    
    return {
        "success": True,
        "message": "Solicitud actualizada"
    }


# ========================================
# ELIMINAR SOLICITUD
# ========================================

@router.delete("/{solicitud_id}", response_model=dict)
async def eliminar_solicitud(
    solicitud_id: int,
    request: Request,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Eliminar solicitud"""
    solicitud = db.query(SolicitudVPN).filter(SolicitudVPN.id == solicitud_id).first()
    if not solicitud:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
    
    # Verificar que no tenga carta
    carta = db.query(CartaResponsabilidad).filter(
        CartaResponsabilidad.solicitud_id == solicitud_id
    ).first()
    
    if carta:
        raise HTTPException(status_code=400, detail="No se puede eliminar: ya tiene carta")
    
    if solicitud.acceso:
        raise HTTPException(status_code=400, detail="No se puede eliminar: ya tiene acceso VPN")
    
    db.delete(solicitud)
    db.commit()
    
    return {
        "success": True,
        "message": "Solicitud eliminada"
    }