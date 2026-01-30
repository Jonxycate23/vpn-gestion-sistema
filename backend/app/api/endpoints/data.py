from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from fastapi.responses import StreamingResponse
from app.utils.import_logic import ImportadorVPN
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.models import SolicitudVPN, Persona, AccesoVPN, CartaResponsabilidad
import pandas as pd
import io
from datetime import datetime

router = APIRouter()

@router.post("/import/excel")
async def importar_excel(file: UploadFile = File(...)):
    """
    Importa datos desde un archivo Excel.
    """
    if not file.filename.endswith(('.xls', '.xlsx')):
        raise HTTPException(status_code=400, detail="El archivo debe ser Excel (.xls, .xlsx)")
    
    try:
        content = await file.read()
        importador = ImportadorVPN(content)
        resultado = importador.procesar()
        
        return {
            "mensaje": "Importación completada",
            "estadisticas": resultado
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error durante la importación: {str(e)}")

@router.get("/export/excel")
async def exportar_excel(db: Session = Depends(get_db)):
    """
    Exporta todos los datos del sistema a un archivo Excel.
    """
    try:
        # Consulta optimizada
        query = db.query(
            SolicitudVPN.id,
            SolicitudVPN.numero_oficio,
            SolicitudVPN.numero_providencia,
            SolicitudVPN.fecha_recepcion,
            SolicitudVPN.estado.label('estado_solicitud'),
            Persona.nip,
            Persona.nombres,
            Persona.apellidos,
            Persona.dpi,
            Persona.institucion,
            Persona.cargo,
            AccesoVPN.estado_vigencia,
            AccesoVPN.fecha_fin_con_gracia,
            CartaResponsabilidad.numero_carta,
            CartaResponsabilidad.anio_carta
        ).join(Persona, SolicitudVPN.persona_id == Persona.id)\
         .outerjoin(AccesoVPN, AccesoVPN.solicitud_id == SolicitudVPN.id)\
         .outerjoin(CartaResponsabilidad, CartaResponsabilidad.solicitud_id == SolicitudVPN.id)
        
        resultados = query.all()
        
        # Convertir a lista de diccionarios
        data = []
        for row in resultados:
            carta = f"{row.numero_carta}-{row.anio_carta}" if row.numero_carta else "N/A"
            data.append({
                "ID": row.id,
                "NIP": row.nip,
                "Nombres": row.nombres,
                "Apellidos": row.apellidos,
                "DPI": row.dpi,
                "Cargo": row.cargo,
                "Institución": row.institucion,
                "Oficio": row.numero_oficio,
                "Providencia": row.numero_providencia,
                "Fecha Recepción": row.fecha_recepcion,
                "Estado Solicitud": row.estado_solicitud,
                "Vigencia VPN": row.estado_vigencia or "SIN ACCESO",
                "Fecha Vencimiento": row.fecha_fin_con_gracia,
                "Carta": carta
            })
            
        df = pd.DataFrame(data)
        
        # Generar Excel en memoria
        output = io.BytesIO()
        with pd.ExcelWriter(output, engine='openpyxl') as writer:
            df.to_excel(writer, index=False, sheet_name='Datos VPN')
        
        output.seek(0)
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"reporte_vpn_completo_{timestamp}.xlsx"
        
        headers = {
            'Content-Disposition': f'attachment; filename="{filename}"'
        }
        
        return StreamingResponse(
            output, 
            headers=headers, 
            media_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error generando reporte: {str(e)}")
