"""
Endpoints de Solicitudes VPN - VERSIÓN CON AUTO-NUMERACIÓN DE CARTAS
📍 Ubicación: backend/app/api/endpoints/solicitudes.py
✅ Subdirección fija + Nombre usuario sistema + Usuario generado
✅ AUTO-NUMERACIÓN: Genera número de carta automático según el año actual
"""
from fastapi import APIRouter, Depends, status, Request, Query, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from sqlalchemy import func  # ✅ AGREGADO para MAX()
from typing import Optional
from datetime import date, timedelta, datetime
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
from reportlab.lib.pagesizes import legal
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT
import os

router = APIRouter()

# ========================================
# RUTAS DE IMÁGENES
# ========================================
IMAGEN_ENCABEZADO = r"C:\Users\HP\Desktop\VPN-PROJECT\vpn-gestion-sistema\vpn-gestion-sistema\frontend\imagenes\encabezado.png"
IMAGEN_PIE = r"C:\Users\HP\Desktop\VPN-PROJECT\vpn-gestion-sistema\vpn-gestion-sistema\frontend\imagenes\FinPagina.png"


@router.get("/buscar-nip/{nip}", response_model=dict)
async def buscar_persona_por_nip(
    nip: str,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Buscar persona por NIP"""
    persona = db.query(Persona).filter(Persona.nip == nip).first()
    
    if persona is None:
        return {"existe": False}
    
    total_solicitudes = db.query(SolicitudVPN).filter(
        SolicitudVPN.persona_id == persona.id
    ).count()
    
    return {
        "existe": True,
        "id": persona.id,
        "dpi": persona.dpi,
        "nip": persona.nip,
        "nombres": persona.nombres,
        "apellidos": persona.apellidos,
        "institucion": persona.institucion,
        "cargo": persona.cargo,
        "telefono": persona.telefono,
        "email": persona.email,
        "total_solicitudes": total_solicitudes
    }


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
        "nip": persona.nip if hasattr(persona, 'nip') else None,
        "nombres": persona.nombres,
        "apellidos": persona.apellidos,
        "institucion": persona.institucion,
        "cargo": persona.cargo,
        "telefono": persona.telefono,
        "email": persona.email,
        "total_solicitudes": total_solicitudes
    }


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
        if hasattr(persona_existente, 'nip'):
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


@router.post("/", response_model=dict, status_code=status.HTTP_201_CREATED)
async def crear_solicitud(
    data: dict,
    request: Request,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Crear nueva solicitud VPN"""
    ip_origen = get_client_ip(request)
    
    persona = db.query(Persona).filter(Persona.id == data['persona_id']).first()
    if not persona:
        raise HTTPException(status_code=404, detail="Persona no encontrada")
    
    nip_persona = persona.nip
    if data.get('numero_oficio') and nip_persona:
        existe_nip_oficio = db.query(SolicitudVPN).join(Persona).filter(
            Persona.nip == nip_persona,
            SolicitudVPN.numero_oficio == data['numero_oficio']
        ).first()
        
        if existe_nip_oficio:
            raise HTTPException(
                status_code=400, 
                detail=f"❌ YA EXISTE un registro con NIP {nip_persona} y Oficio {data['numero_oficio']} (Solicitud #{existe_nip_oficio.id})"
            )
        
    solicitud = SolicitudVPN(
        persona_id=data['persona_id'],
        numero_oficio=data.get('numero_oficio'),
        numero_providencia=data.get('numero_providencia'),
        fecha_recepcion=date.fromisoformat(data['fecha_recepcion']) if data.get('fecha_recepcion') else None,
        fecha_solicitud=date.fromisoformat(data['fecha_solicitud']),
        tipo_solicitud=data['tipo_solicitud'],
        justificacion=data['justificacion'],
        estado='PENDIENTE',
        usuario_registro_id=current_user.id
    )
    
    db.add(solicitud)
    db.commit()
    db.refresh(solicitud)
    
    AuditoriaService.registrar_crear(
        db=db,
        usuario=current_user,
        entidad="SOLICITUD",
        entidad_id=solicitud.id,
        detalle={
            "persona_nip": persona.nip,
            "persona_dpi": persona.dpi,
            "tipo": data['tipo_solicitud'],
            "estado": solicitud.estado
        },
        ip_origen=ip_origen
    )
    
    return {
        "success": True,
        "message": "Solicitud creada exitosamente",
        "solicitud_id": solicitud.id
    }


@router.get("/", response_model=dict)
async def listar_solicitudes(
    skip: int = Query(0, ge=0),
    limit: int = Query(2000, ge=1, le=3000),
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Listar solicitudes"""
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
            "persona_nip": sol.persona.nip if hasattr(sol.persona, 'nip') else None,
            "carta_generada": carta is not None,
            "carta_id": carta.id if carta else None,
            "carta_fecha_generacion": carta.fecha_generacion if carta else None,
            "acceso_id": sol.acceso.id if sol.acceso else None
        })
    
    return {
        "total": total,
        "solicitudes": result
    }


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
    
    carta = db.query(CartaResponsabilidad).filter(
        CartaResponsabilidad.solicitud_id == solicitud_id
    ).first()
    
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
        "carta_fecha_generacion": carta.fecha_generacion if carta else None,
        "numero_carta": carta.numero_carta if carta else None,
        "anio_carta": carta.anio_carta if carta else None,
        "persona": {
            "id": solicitud.persona.id,
            "dpi": solicitud.persona.dpi,
            "nip": solicitud.persona.nip if hasattr(solicitud.persona, 'nip') else None,
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
# GENERAR PDF CON FORMATO OFICIAL PNC
# ========================================

def generar_carta_pdf_oficial(solicitud: SolicitudVPN, carta: CartaResponsabilidad, usuario_sistema: UsuarioSistema, db: Session):
    """
    Genera PDF con formato OFICIAL PNC
    ✅ Subdirección fija en primera celda
    ✅ Nombre usuario sistema en firma
    """
    
    output_dir = "/var/vpn_archivos/cartas"
    os.makedirs(output_dir, exist_ok=True)
    
    persona = solicitud.persona
    filename = f"CARTA_{carta.id}_{persona.dpi}.pdf"
    filepath = os.path.join(output_dir, filename)
    
    doc = SimpleDocTemplate(
        filepath, 
        pagesize=legal,
        topMargin=0.3*inch, 
        bottomMargin=0.5*inch,
        leftMargin=0.75*inch, 
        rightMargin=0.75*inch
    )
    story = []
    styles = getSampleStyleSheet()
    
    # Encabezado
    if os.path.exists(IMAGEN_ENCABEZADO):
        try:
            img_encabezado = Image(IMAGEN_ENCABEZADO, width=8*inch, height=1.5*inch)
            story.append(img_encabezado)
            story.append(Spacer(1, 0.15*inch))
        except Exception as e:
            print(f"Error cargando encabezado: {e}")
    
    # Título
    titulo_style = ParagraphStyle(
        'Titulo',
        parent=styles['Normal'],
        fontSize=10,
        fontName='Helvetica-Bold',
        alignment=TA_CENTER,
        spaceAfter=6,
        leading=12
    )
    
    story.append(Paragraph("CARTA DE RESPONSABILIDAD DE USO Y ACCESO POR VPN A LA RED INSTITUCIONAL DE LA POLICÍA NACIONAL CIVIL", titulo_style))
    story.append(Spacer(1, 0.1*inch))
    
    # Documento No
    doc_no_style = ParagraphStyle(
        'DocNo', 
        parent=styles['Normal'], 
        fontSize=10, 
        alignment=TA_CENTER, 
        fontName='Helvetica-Bold',
        spaceAfter=10
    )
    story.append(Paragraph(f"Documento No: {carta.numero_carta}-{carta.anio_carta}", doc_no_style))
    story.append(Spacer(1, 0.12*inch))
    
    # Texto completo
    body_style = ParagraphStyle(
        'Body', 
        parent=styles['Normal'], 
        fontSize=8.5, 
        alignment=TA_JUSTIFY, 
        leading=10
    )
    
    texto_intro = """En las instalaciones que ocupa el Departamento de Operaciones de Seguridad Informática de la 
    Subdirección General de Tecnologías de la Información y la Comunicación, se suscribe la presente 
    CARTA DE RESPONSABILIDAD con la que EL USUARIO acepta formalmente las condiciones de uso 
    y acceso por medio del servicio de VPN, por medio de un "usuario" y "contraseña" con los cuales se le 
    otorga la facultad de acceder al sistema de Escritorio Policial y Sistema Solvencias de la Policía Nacional 
    Civil, de conformidad con lo antes expuesto, declara su compromiso de cumplir con lo siguiente:"""
    
    story.append(Paragraph(texto_intro, body_style))
    story.append(Spacer(1, 0.12*inch))
    
    # Obligaciones completas
    obligaciones = [
        "EL USUARIO y CONTRASEÑA asignados son datos intransferibles, confidenciales y personales; el titular es responsable directo de su uso.",
        "EL USUARIO tiene prohibido utilizar cualquier medio digital, impreso y otros para dar a conocer información de carácter confidencial contenido en los accesos obtenidos.",
        "El USUARIO se compromete a utilizar el servicio de VPN únicamente para fines expresamente laborales, la Subdirección General de Tecnologías de la Información y la Comunicación, se reserva el derecho de registrar y monitorear todas las actividades realizadas, mediante la utilización de mecanismos de auditoría y bitácoras. Los registros se considerarán pruebas fehacientes del uso en cualquier situación administrativa; y, se procederá inmediatamente al bloqueo inmediato del acceso.",
        "EL USUARIO tiene la obligación de reportar inmediatamente al Departamento de Operaciones de Seguridad Informática de la Subdirección General de Tecnologías de la Información y la Comunicación en caso de pérdida o sustracción del acceso, cuando sea cambiado de destino o haya terminado su relación laboral con la institución policial.",
        "EL USUARIO se compromete a renovar el acceso en el tiempo estipulado en el presente numeral, para esto gestionará en la unidad a la que pertenece para que envíen la solicitud respectiva. La vigencia del acceso es de 12 meses, siendo el sexto mes de recepción de solicitudes para renovación. La Subdirección General de Tecnologías de la Información y la Comunicación se reserva el derecho de bloquear los usuarios que no aparezcan en los oficios de solicitud recibidos, la presente disposición se encuentra sujeta a cambios sin previo aviso.",
        'EL USUARIO acepta haber leído y comprendido los lineamientos de seguridad descritos en este documento y se compromete a cumplirlos en su totalidad, sin menoscabo de las obligaciones y prohibiciones establecidas en los artículos 274 "A", 274 "B", 274 "C", 274 "D", 274 "E", 274 "F", ordinal 30 del artículo 369, y 422 del Código Penal, literal F del artículo 34 establecido en el Decreto Numero 11-97 del Congreso de la República, Ley de la Policía Nacional Civil. En el entendido de que el incumplimiento a cualquiera de estos será causa de la aplicación de las sanciones correspondientes.',
        "La Subdirección General de Tecnologías de la Información y la Comunicación, se reserva el derecho y la facultad para bloquear usuarios, cuando se considere o compruebe el uso inapropiado de los accesos."
    ]
    
    for i, ob in enumerate(obligaciones, 1):
        story.append(Paragraph(f"<b>{i}.</b> {ob}", body_style))
        story.append(Spacer(1, 0.06*inch))
    
    story.append(Spacer(1, 0.12*inch))
    
    # ===== TABLA DE DATOS =====
    fecha_expiracion = carta.fecha_generacion + timedelta(days=365)
    
    # ✅ Generar username
    nombres_split = persona.nombres.lower().split()
    apellidos_split = persona.apellidos.lower().split()
    username = f"{nombres_split[0]}.{apellidos_split[0]}" if nombres_split and apellidos_split else "usuario"
    
    # ✅ CONSTRUIR TABLA
    tabla_datos = [
        # Fila 1
        ['Responsable:', f"{persona.nombres} {persona.apellidos}", 'Usuario:', username],
        # Fila 2
        ['DPI:', persona.dpi, 'Correo:', persona.email or ''],
        # Fila 3
        ['NIP:', persona.nip or 'N/A', 'Teléfono:', persona.telefono or ''],
        # Fila 4: ✅ SUBDIRECCIÓN FIJA (SIEMPRE LA MISMA)
        ['Subdirección General de Investigación Criminal SGIC', '', 'Fecha de Expiración:', fecha_expiracion.strftime("%d/%m/%Y")],
        # Fila 5: ✅ DIPANDA (institución de la persona)
        [persona.institucion, '', 'Privilegios de red:'],
        # Fila 6: Vacío
        ['', '', 'Escritorio Policial:', '172.21.68.154']
    ]
    
    t = Table(tabla_datos, colWidths=[1.5*inch, 2*inch, 1.5*inch, 2*inch])
    t.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 0), (-1, -1), 8.5),
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTNAME', (2, 0), (2, -1), 'Helvetica-Bold'),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.black),
        # Celdas que ocupan 2 espacios
        ('SPAN', (0, 3), (1, 3)),  # Fila 4: Subdirección
        ('SPAN', (0, 4), (1, 4)),  # Fila 5: Institución
        ('SPAN', (0, 5), (1, 5)),  # Fila 6: Vacío
    ]))
    story.append(t)
    story.append(Spacer(1, 0.12*inch))
    
    # Finalidad
    story.append(Paragraph(
        "<b>Finalidad:</b> Proveer un túnel VPN para permitir el acceso al sistema de Escritorio Policial y Solvencias, de la Policía Nacional Civil.", 
        body_style
    ))
    story.append(Spacer(1, 0.15*inch))
    
    # Fecha de generación
    meses = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre']
    dias_semana = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo']
    
    if isinstance(carta.fecha_generacion, date) and not isinstance(carta.fecha_generacion, datetime):
        fecha_gen = datetime.combine(carta.fecha_generacion, datetime.min.time())
    else:
        fecha_gen = carta.fecha_generacion
    
    fecha_texto = f"Ciudad de Guatemala, {dias_semana[fecha_gen.weekday()]}, {fecha_gen.day} de {meses[fecha_gen.month-1]} de {fecha_gen.year}"
    
    story.append(Paragraph(fecha_texto, body_style))
    story.append(Spacer(1, 0.40*inch))
    
    # ✅ FIRMAS CON NOMBRE USUARIO SISTEMA
    firmas = [
        ['f. _________________________', 'f. _________________________'],
        ['Firmo y recibo conforme', 'Firmo y entrego DOSI/SGTIC'],
        [f'{persona.nombres} {persona.apellidos}', usuario_sistema.nombre_completo]  # ✅ NOMBRE USUARIO LOGUEADO
    ]
    
    t_firmas = Table(firmas, colWidths=[3.5*inch, 3.5*inch])
    t_firmas.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 0), (-1, -1), 8.5),
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
    ]))
    story.append(t_firmas)
    
    # Pie de página
    if os.path.exists(IMAGEN_PIE):
        try:
            story.append(Spacer(1, 0.35*inch))
            img_pie = Image(IMAGEN_PIE, width=7*inch, height=1.2*inch)
            story.append(img_pie)
        except Exception as e:
            print(f"Error cargando pie: {e}")
    
    # Construir PDF
    try:
        doc.build(story)
        return filepath
    except Exception as e:
        raise Exception(f"Error construyendo PDF: {str(e)}")


@router.post("/{solicitud_id}/crear-carta", response_model=dict)
async def crear_carta_responsabilidad(
    solicitud_id: int,
    request: Request,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Crear carta, generar PDF y crear acceso VPN
    ✅ AUTO-NUMERACIÓN: Genera número de carta automático
    """
    ip_origen = get_client_ip(request)
    
    solicitud = db.query(SolicitudVPN).filter(SolicitudVPN.id == solicitud_id).first()
    if not solicitud:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
    
    if solicitud.estado != 'PENDIENTE':
        raise HTTPException(status_code=400, detail="Solo solicitudes PENDIENTES")
    
    carta_existente = db.query(CartaResponsabilidad).filter(
        CartaResponsabilidad.solicitud_id == solicitud_id
    ).first()
    
    if carta_existente:
        raise HTTPException(status_code=400, detail="Ya existe carta")
    
    # ========================================
    # ✅ AUTO-NUMERACIÓN DE CARTAS
    # ========================================
    anio_actual = date.today().year
    
    # Buscar el máximo numero_carta del año actual (excluyendo NULLs)
    resultado = db.query(
        func.max(CartaResponsabilidad.numero_carta)
    ).filter(
        CartaResponsabilidad.anio_carta == anio_actual,
        CartaResponsabilidad.numero_carta.isnot(None)  # ✅ EXCLUIR NULLs
    ).scalar()
    
    # Si existe, incrementar en 1; si no, empezar en 1
    proximo_numero = (resultado + 1) if resultado is not None else 1
    
    print(f"📊 AUTO-NUMERACIÓN:")
    print(f"   Año actual: {anio_actual}")
    print(f"   Último número encontrado: {resultado if resultado is not None else 'N/A'}")
    print(f"   Próximo número a asignar: {proximo_numero}")
    print(f"   Carta generada: {proximo_numero}-{anio_actual}")
    
    # Crear carta con número automático
    carta = CartaResponsabilidad(
        solicitud_id=solicitud_id,
        tipo='RESPONSABILIDAD',
        fecha_generacion=date.today(),
        generada_por_usuario_id=current_user.id,
        numero_carta=proximo_numero,  # ✅ NÚMERO AUTOMÁTICO
        anio_carta=anio_actual         # ✅ AÑO ACTUAL
    )
    db.add(carta)
    db.flush()
    
    # Generar PDF
    try:
        pdf_path = generar_carta_pdf_oficial(solicitud, carta, current_user, db)
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error generando PDF: {str(e)}")
    
    # Crear acceso VPN
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
    solicitud.estado = 'APROBADA'
    db.commit()
    db.refresh(carta)
    db.refresh(acceso)
    
    AuditoriaService.registrar_crear(
        db=db,
        usuario=current_user,
        entidad="CARTA",
        entidad_id=carta.id,
        detalle={
            "solicitud_id": solicitud_id,
            "acceso_id": acceso.id,
            "pdf_generado": True,
            "pdf_path": pdf_path,
            "numero_carta": proximo_numero,  # ✅ REGISTRAR EN AUDITORÍA
            "anio_carta": anio_actual
        },
        ip_origen=ip_origen
    )
    
    return {
        "success": True,
        "message": f"Carta {proximo_numero}-{anio_actual} creada, PDF generado y acceso VPN activado",
        "carta_id": carta.id,
        "numero_carta": proximo_numero,  # ✅ DEVOLVER AL FRONTEND
        "anio_carta": anio_actual,
        "acceso_id": acceso.id,
        "pdf_path": pdf_path
    }


@router.get("/{solicitud_id}/descargar-carta")
async def descargar_carta_pdf(
    solicitud_id: int,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Descargar PDF de la carta"""
    solicitud = db.query(SolicitudVPN).filter(SolicitudVPN.id == solicitud_id).first()
    if not solicitud:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
    
    carta = db.query(CartaResponsabilidad).filter(
        CartaResponsabilidad.solicitud_id == solicitud_id
    ).first()
    
    if not carta:
        raise HTTPException(status_code=404, detail="No existe carta")
    
    persona = solicitud.persona
    filename = f"CARTA_{carta.id}_{persona.dpi}.pdf"
    filepath = os.path.join("/var/vpn_archivos/cartas", filename)
    
    if not os.path.exists(filepath):
        raise HTTPException(status_code=404, detail=f"Archivo PDF no encontrado: {filepath}")
    
    return FileResponse(
        path=filepath,
        filename=filename,
        media_type='application/pdf'
    )


# ========================================
# RESTO DE ENDPOINTS
# ========================================

@router.post("/{solicitud_id}/no-presentado", response_model=dict)
async def marcar_no_presentado(
    solicitud_id: int,
    request: Request,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Marcar como 'No se presentó'"""
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
    
    return {"success": True, "message": "Marcado como 'No se presentó'"}


@router.post("/{solicitud_id}/reactivar", response_model=dict)
async def reactivar_solicitud(
    solicitud_id: int,
    request: Request,
    current_user: UsuarioSistema = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Reactivar solicitud"""
    solicitud = db.query(SolicitudVPN).filter(SolicitudVPN.id == solicitud_id).first()
    if not solicitud:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
    
    if solicitud.estado != 'CANCELADA':
        raise HTTPException(status_code=400, detail="Solo solicitudes CANCELADAS")
    
    solicitud.estado = 'APROBADA'
    solicitud.comentarios_admin = f"REACTIVADA: {solicitud.comentarios_admin}"
    
    db.commit()
    
    return {"success": True, "message": "Solicitud reactivada"}


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
    
    carta = db.query(CartaResponsabilidad).filter(
        CartaResponsabilidad.solicitud_id == solicitud_id
    ).first()
    
    if carta:
        raise HTTPException(status_code=400, detail="No se puede editar: ya tiene carta generada")
    
    if "numero_oficio" in data:
        solicitud.numero_oficio = data["numero_oficio"]
    
    if "numero_providencia" in data:
        solicitud.numero_providencia = data["numero_providencia"]
    
    if "fecha_recepcion" in data:
        if data["fecha_recepcion"]:
            solicitud.fecha_recepcion = date.fromisoformat(data["fecha_recepcion"])
        else:
            solicitud.fecha_recepcion = None
    
    if "tipo_solicitud" in data:
        solicitud.tipo_solicitud = data["tipo_solicitud"]
    
    if "justificacion" in data:
        solicitud.justificacion = data["justificacion"]
    
    db.commit()
    db.refresh(solicitud)
    
    try:
        AuditoriaService.registrar_crear(
            db=db,
            usuario=current_user,
            entidad="SOLICITUD_EDICION",
            entidad_id=solicitud_id,
            detalle={
                "accion": "EDITAR",
                "campos_modificados": list(data.keys())
            },
            ip_origen=get_client_ip(request)
        )
    except Exception as e:
        print(f"⚠️ Error en auditoría (no crítico): {e}")
    
    return {
        "success": True, 
        "message": "Solicitud actualizada exitosamente",
        "solicitud": {
            "id": solicitud.id,
            "numero_oficio": solicitud.numero_oficio,
            "numero_providencia": solicitud.numero_providencia,
            "fecha_recepcion": solicitud.fecha_recepcion,
            "tipo_solicitud": solicitud.tipo_solicitud,
            "justificacion": solicitud.justificacion
        }
    }


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
    
    carta = db.query(CartaResponsabilidad).filter(
        CartaResponsabilidad.solicitud_id == solicitud_id
    ).first()
    
    if carta:
        raise HTTPException(status_code=400, detail="No se puede editar: ya tiene carta")
    
    if solicitud.acceso:
        raise HTTPException(status_code=400, detail="No se puede eliminar: ya tiene acceso VPN")
    
    db.delete(solicitud)
    db.commit()
    
    return {"success": True, "message": "Solicitud eliminada"}