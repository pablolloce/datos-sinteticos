"""
flujo_workstation.py
====================

Fase 2 del guardado desde la Workstation (D-034): lo que escriben en la BBDD los workflows
que ``CustomWorkstationWorkflow`` lanza DESPUÉS del motor (ver docs/motor/FLUJO_WORKSTATION.md).

Cada escritura replicada se añade al mensaje como un segmento STREET_REF más (atributo
``ORIGEN`` = workflow que la hace), de modo que el generador la traduce igual que el resto:
claves nuevas, marca sintética (D-001), fechas técnicas y registro para el borrado.

Replicado (código decodificado en fileloading/extracciones/decodificado/parametros/):
  - Checks v2 "Type FinancialInstitution": decide la rama (valido).
  - CheckDatosRegulatorios v15, camino GLOBAL ("Comprobar" 01AgTWA1S42r403O e "Insercion JAVA"
    01AgTWA1S42r4027): fila de control CONTROLDR en FT_T_RLT1 (REGISTER_LOG_TABLE).
Para una contrapartida GLOBAL nueva, el resto de workflows no escribe datos de negocio ni de
control (no tiene LOCAL/OPERATIVE hijas); sólo filas de infraestructura (FT_T_JBLG/FT_T_TRID
de CreateShortname), que no se replican.
Todo lo demás se avisa como PENDIENTE (no se inventa, CLAUDE.md).
"""

from __future__ import annotations

import sys
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from mensaje_motor import Cambio, MensajeMotor  # noqa: E402

# ManageSMSUI.xslt: MAIN_ENTITY_TBL_TYP -> tipo de entidad de los workflows posteriores.
ENTIDAD_WORKFLOW = {"FINS": "Counterparty", "SSIS": "StandardSettlementInstructions", "CNTC": "Contact"}

# Conjuntos de clasificación que CheckDatosRegulatorios lee en "CLSFOIDs" (FT_T_INCL).
SETS_CLSFOID = ("INDICYN", "EMIRCAT", "FINALEM", "MANUALSFTR", "RR_IRS", "SEC_EQD", "FINALSFTR",
                "USPERSON", "MANPARTY", "CORPREL", "CNAE")


def _valor(seg: ET.Element, tag: str) -> str | None:
    cuerpo = seg.find(seg.get("TYPE"))
    el = (cuerpo if cuerpo is not None else seg).find(tag)
    return el.get("VALUE") if el is not None else None


def _valido(m: MensajeMotor) -> bool | None:
    """Checks v2 "Type FinancialInstitution": True si algún segmento no es FinancialInstitution
    ni FinancialInstitutionRating. None = sólo ratings: decide por BBDD (RTNGS_LOCALES)."""
    for s in m.raiz.findall("SEGMENT"):
        if s.get("TYPE") not in ("FinancialInstitution", "FinancialInstitutionRating"):
            return True
    return None


def _comprobar_global(m: MensajeMotor) -> tuple[bool | None, list, list]:
    """CheckDatosRegulatorios "Comprobar" (camino GLOBAL). Devuelve (calculo, fra1Oid, clsfoids):
    calculo None si depende de FT_T_INCL (CLSFOID de FinsRegAttr/FinsRoleClassification)."""
    fra1, clsfoids = [], []
    marcado = False
    for s in m.raiz.findall("SEGMENT"):
        t = s.get("TYPE")
        if t == "FINSFinancialInstitutionRole" and _valor(s, "FINSRLSUBTYP") is not None:
            marcado = True; break                                       # legalPersonality
        if t == "FinancialInstitutionGeoUnitPrt" and _valor(s, "GUID") is not None:
            marcado = True; break                                       # countryOfOrigin
        if t == "FinsRegAttr":
            if _valor(s, "CLSFOID") is not None:
                clsfoids.append(_valor(s, "CLSFOID"))                   # incl (FT_T_INCL)
            if _valor(s, "DATASTATTYP") is not None and _valor(s, "FRA1OID") is not None:
                fra1.append(_valor(s, "FRA1OID"))
                continue
        if t == "FinancialInstitutionGeoUnitPrt" and _valor(s, "FINSGUPURPTYP") == "RESID_CO":
            marcado = True; break                                       # countryOfResidence
        if t == "FinsRoleClassification":
            if _valor(s, "INDUSCLSETID") == "CNAE":
                marcado = True; break                                   # cNAE
            if _valor(s, "CLSFOID") is not None:
                clsfoids.append(_valor(s, "CLSFOID"))                   # cNAE por CLSFOID (FT_T_INCL)
        if t == "FinancialInstitutionGeoUnitPrt" and _valor(s, "FINSGUPURPTYP") == "COUNGUAR":
            marcado = True; break                                       # countryOfGuarantee
        if t == "FinancialInstitution" and _valor(s, "SUBSIDIARYIND") is not None:
            marcado = True; break                                       # headOfficeRelation
        if t == "FinancialInstitutionIdentifier" and _valor(s, "FINSIDCTXTTYP") == "BDIID":
            marcado = True; break                                       # codigoDeBDI
        if t == "FinsRoleClassification" and _valor(s, "INDUSCLSETID") == "CODINSTI":
            marcado = True; break                                       # institutionalCode
        if t == "FinancialInstitutionStatistic" and _valor(s, "STATDEFID") == "REPCAMAR":
            marcado = True; break                                       # rolClearingHouse
        if t == "FINSFinancialInstitutionRole" and _valor(s, "FINSRLTYP") == "CLRNGHS":
            marcado = True; break                                       # rolClearingHouse
        if t == "FINSFinancialInstitutionGroupPrt" and _valor(s, "PRTPURPTYP") == "FUND":
            marcado = True; break                                       # fund_FundManager
    if marcado:
        return True, fra1, clsfoids
    return (None if clsfoids else False), fra1, clsfoids


def _anadir_segmento(m: MensajeMotor, tipo: str, origen: str, valores: dict[str, str]) -> str | None:
    """Añade al final del mensaje un segmento INSERT con los valores por etiqueta XELM.
    Devuelve el motivo si no se puede (tabla del segmento sin confirmar, D-010)."""
    info = m.modelo["segmentos"].get(tipo) or {}
    if not info.get("tabla") or info.get("origen_tabla") == "inferida":
        return (f"la tabla del segmento {tipo} ({info.get('tabla') or '?'}, TBL_ID {info.get('tbl_id')}) está "
                "deducida por columnas: confirmarla en esquema/modelo/tablas_manual.csv (D-010)")
    seg = ET.SubElement(m.raiz, "SEGMENT", {"TYPE": tipo, "ACTION": "INSERT", "ORIGEN": origen})
    cuerpo = ET.SubElement(seg, tipo)
    for tag, valor in valores.items():
        ET.SubElement(cuerpo, tag, {"VALUE": valor})
    numero = len(m.raiz.findall("SEGMENT"))
    m.cambios.append(Cambio(origen, numero, f"fila añadida por el workflow {origen} (fase 2, D-034)"))
    return None


def aplicar_flujo(m: MensajeMotor) -> list[tuple[str, str, str]]:
    """Aplica la fase 2 al mensaje (añade segmentos). Devuelve [(workflow, estado, detalle)];
    estado: REPLICADA | SIN_ESCRITURA | PENDIENTE."""
    eventos: list[tuple[str, str, str]] = []
    tipo_entidad = ENTIDAD_WORKFLOW.get(m.cabecera("MAIN_ENTITY_TBL_TYP") or "")

    valido = _valido(m)
    if valido is None:
        return [("Checks", "PENDIENTE", "el mensaje sólo trae FinancialInstitution/Rating: la rama depende de "
                 "FT_T_PAR1 RTNGS_LOCALES (ratings locales → RDR_CalculateREU)")]

    if tipo_entidad != "Counterparty":
        return [("CustomWorkstationWorkflow", "PENDIENTE",
                 f"entidad {tipo_entidad or m.cabecera('MAIN_ENTITY_TBL_TYP')}: workflows posteriores "
                 "(AuditMex, Sub_CallDifusion, Sub_PublishChanges...) sin replicar")]

    # --- CheckDatosRegulatorios (evento RDR_DatosRegu) -------------------------------------
    principal = next((s for s in m.raiz.findall("SEGMENT") if s.get("TYPE") == "FinancialInstitution"
                      and s.get("NotNewEntity") != "Y"), None)
    inst_mnem = _valor(principal, "INSTMNEM") if principal is not None else None
    rel = next((_valor(s, "RELTYP") for s in m.raiz.findall("SEGMENT")
                if s.get("TYPE") in ("FINRFinsFinsRoleRelationship", "FINSFinsFinsRoleRelationship")
                and s.get("ACTION") not in ("IGNORE", "REFERENCE") and _valor(s, "INSTMNEM") == inst_mnem), None)
    if inst_mnem is None or rel is None:
        eventos.append(("CheckDatosRegulatorios", "SIN_ESCRITURA",
                        "sin FIRL de la entidad en el mensaje: el workflow no encuentra REL_TYP y termina"))
    elif rel.strip() != "GLOBAL":
        eventos.append(("CheckDatosRegulatorios", "PENDIENTE", f"camino {rel.strip()} (inserta en cascada) sin replicar"))
    else:
        calculo, fra1, clsfoids = _comprobar_global(m)
        if fra1:
            eventos.append(("CheckDatosRegulatorios", "PENDIENTE",
                            "el mensaje trae FinsRegAttr con FRA1OID: filas manualEMIR/manualSFTR sin replicar"))
        elif calculo is None:
            eventos.append(("CheckDatosRegulatorios", "PENDIENTE",
                            f"CALCULO depende de si los CLSFOID {', '.join(clsfoids)} son de los conjuntos "
                            f"{', '.join(SETS_CLSFOID)} (FT_T_INCL)"))
        else:
            motivo = _anadir_segmento(m, "RegisterLogTable", "CheckDatosRegulatorios", {
                "RECORDSEQNUM": "1",
                "MESSAGERLT": "Control del calculo de datos regulatorios",
                "RLTPURPTYP": "CONTROLDR",
                "DATASRCAPP": "CALCULODR",
                "SRCFIELD": "CALCULO",
                "SRCVALUE": "true" if calculo else "false",
                "GSFIELD": "REL_TYP",
                "GSVALUE": "GLOBAL",
                "MAINENTITYNME": "FT_T_FIID.INST_MNEM",
                "MAINENTITYID": inst_mnem,
                "LASTCHGUSRID": "CONTROLDR",   # el generador pone la marca sintética (D-001)
            })
            detalle = f"FT_T_RLT1 CONTROLDR (CALCULO={'true' if calculo else 'false'}, REL_TYP=GLOBAL)"
            eventos.append(("CheckDatosRegulatorios", "PENDIENTE" if motivo else "REPLICADA",
                            f"{detalle}: {motivo}" if motivo else detalle))

    # --- Resto de workflows para una contrapartida ---------------------------------------
    if rel is not None and rel.strip() == "GLOBAL":
        eventos.append(("AutoCodTesBDI, AuditMex, Sub_CallDifusion, Sub_PublishChanges, RDR_PUBLISH_CG",
                        "SIN_ESCRITURA",
                        "GLOBAL nueva sin LOCAL/OPERATIVE: no escriben datos de negocio ni de control "
                        "(CreateShortname sólo deja FT_T_JBLG/FT_T_TRID, no replicadas)"))
    else:
        eventos.append(("AutoCodTesBDI, AuditMex, Sub_CallDifusion, Sub_PublishChanges, RDR_PUBLISH_CG",
                        "PENDIENTE", "contrapartida no GLOBAL: REU, shortname, difusión y cachés sin replicar"))
    return eventos
