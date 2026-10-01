"""
reglas_replicadas.py
====================

Réplica en el generador de las reglas del motor de GoldenSource (D-031). Se aplican al
mensaje ANTES de traducirlo a INSERT, en el orden del message set STREETREF
(``esquema/motor/message_set.json``):

    1. reglas del segmento ``Initial`` (una vez por mensaje);
    2. por cada segmento del mensaje, en su orden: sus reglas de fase B y después A;
    3. reglas de fase F de todos los segmentos;
    4. reglas del segmento ``Final``.

(El orden B/A/F/Initial/Final está deducido del message set: ver docs/motor/MOTOR_GOLDENSOURCE.md.)

Cada regla replicada es una función ``(mensaje, segmento) -> None`` que reproduce el código
de la regla original y anota sus cambios con ``mensaje.anotar``. Una regla que se invoca por
segmento recibe el segmento que la dispara; las reglas Java de GoldenSource recorren el
mensaje entero, así que sus réplicas deben ser idempotentes.

Estados de una regla que afecta al mensaje (``estado_regla``):
  REPLICADA          se aplica aquí (sólo la parte que depende del mensaje; ver 'parcial').
  SIN_EFECTO         la regla original no hace nada (p. ej. GenerateSSISId).
  PENDIENTE_BBDD     necesita consultar/escribir la BBDD: irá al núcleo PL/SQL.
  PENDIENTE_HUELLA   nativa sin código: se replicará cuando una huella confirme su efecto (D-030).
  PENDIENTE          Java con código conocido, aún sin replicar.
"""

from __future__ import annotations

import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

sys.path.insert(0, str(Path(__file__).resolve().parent))

from fuentes_motor import FASES, cargar_message_set, cargar_reglas_java  # noqa: E402
from mensaje_motor import MensajeMotor, Segmento  # noqa: E402

# Valor que el generador sustituye por GET_IDENTIFIER_ID(<tabla>, ...) en ejecución, uno por
# entidad (D-041). El mismo marcador en varias columnas da el mismo valor.
MARCADOR_SECUENCIA = "{{{{SECUENCIA:{tabla}:{clave}}}}}"
# Valor que el generador sustituye por una clave nueva (NEW_OID) por entidad (D-041).
MARCADOR_OID = "{{{{OID:{clave}}}}}"


@dataclass
class Replica:
    funcion: Callable[[MensajeMotor, Segmento | None], None] | None
    estado: str
    fuente: str              # clase/línea del código original o motivo
    parcial: str = ""        # qué parte NO se replica (y por qué)


def _vacio(v: str | None) -> bool:
    return v is None or v == ""


# ----------------------------------------------------------------------------------------------
# Reglas Java de rdrRules.jar (código descompilado en fileloading; ver analisis/rdrRules.md)
# ----------------------------------------------------------------------------------------------
def validate_country_region(m: MensajeMotor, _seg) -> None:
    """ValidateCountryRegion: si el país de residencia (FIGU STSMNTCT) no es CA, las regiones
    (FIGU STSMNTCR) del mensaje se ponen en IGNORE. Recorre el mensaje en orden: el país tiene
    que aparecer antes que las regiones (el estado se conserva entre segmentos)."""
    if m.modelo_id not in ("RDRFINSG", "FINSX"):
        return
    validar_regiones, gu_pais = False, None
    for s in m.de_tipo("FinancialInstitutionGeoUnitPrt"):
        proposito, gu_id = s.campo(".FINS_GU_PURP_TYP"), s.campo(".GU_ID")
        # Sin FINS_GU_PURP_TYP el original lo busca en BBDD por FIGU_OID (sólo en modificaciones).
        if proposito == "STSMNTCT" and gu_id is not None:
            gu_pais = gu_id
            if gu_id != "CA":
                validar_regiones = True
        if proposito != "STSMNTCR":
            continue
        # Sin país en el mensaje el original lo busca en BBDD (entidad existente); en un alta no hay.
        if gu_pais is not None and gu_pais != "CA":
            validar_regiones = True
        if validar_regiones and s.accion != "IGNORE":
            s.accion = "IGNORE"
            m.anotar("ValidateCountryRegion", s, f"región {s.campo('.GU_ID')} -> IGNORE (país {gu_pais} distinto de CA)")


_LISTA_DIFUSION_FIST = {
    "ATOTAL", "CRNEGO", "EFFDATE", "EXERDATE", "EXPDATE", "RRPP", "PRINSTR", "PRINMURX", "GRUPACTV", "HOMETOWN",
    "PASSPORT", "PROVNCIM", "CERTRESI", "BANCDEPO", "SETTSWIF", "PRNALGO", "CROSSMAR", "SALAINIC", "GRUPBBVA",
    "EDELEG", "OBSERV", "EMITMT", "CORRESPO", "NAME83J", "ACCT83J", "ACCNT_SC", "CONTRP", "BRANCHSC", "DTCCCALA"}


def set_difusion(m: MensajeMotor, _seg) -> None:
    """setDifusion (parte de altas): marca DATA_SRC_ID='DIFUSION' para la difusión a MGC."""
    if m.modelo_id.upper() not in ("FINSX", "FINSL", "RDRFINSG", "FINSO", "FINSTP"):
        return
    for s in m.segmentos:
        if s.tipo == "FinancialInstitutionIdentifier" and s.accion == "INSERT":
            ctxt = s.campo(".FINS_ID_CTXT_TYP")
            if ctxt is not None and ctxt.strip().upper() == "MGCGLOID" and s.campo(".DATA_SRC_ID") != "DIFUSION":
                s.fijar(".DATA_SRC_ID", "DIFUSION")
                m.anotar("setDifusion", s, "FIID MGCGLOID: DATA_SRC_ID -> DIFUSION")
        elif s.tipo == "FinancialInstitutionStatistic" and s.accion not in ("UPDATE", "DELETE"):
            stdf = s.campo(".STAT_DEF_ID")
            if stdf is not None and stdf.strip() in _LISTA_DIFUSION_FIST and s.campo(".DATA_SRC_ID") != "DIFUSION":
                s.fijar(".DATA_SRC_ID", "DIFUSION")
                m.anotar("setDifusion", s, f"FIST {stdf.strip()}: DATA_SRC_ID -> DIFUSION")
        elif s.tipo == "FINREnterpriseFinancialInstitutionRole" and s.accion == "INSERT":
            if s.campo(".ENFR_RL_TYP") == "OPE_BRANCH" and s.campo(".DATA_SRC_ID") != "DIFUSION":
                s.fijar(".DATA_SRC_ID", "DIFUSION")
                m.anotar("setDifusion", s, "ENFR OPE_BRANCH: DATA_SRC_ID -> DIFUSION")
        elif s.tipo == "FINRSubdivisionFinancialInstitutionRole" and s.accion == "INSERT":
            # El original pone LAST_CHG_USR_ID='DIFUSION'; el generador mantiene la marca sintética (D-001).
            m.anotar("setDifusion", s, "LAST_CHG_USR_ID='DIFUSION' no se aplica: prevalece la marca sintética (D-001)")


def generate_lagr_laan(m: MensajeMotor, _seg) -> None:
    """generateLagrLaan: pone en IGNORE los atributos vacíos de un Legal Agreement."""
    if m.modelo_id.upper() not in ("LAGR", "LAGR_BSI"):
        return
    for s in m.segmentos:
        if s.accion != "INSERT":
            continue
        motivo = None
        if s.tipo.upper() == "LEGAGRMTATTRIB":
            if _vacio(s.campo(".FLD_VAL")):
                if s.campo(".STAT_DEF_ID") == "SCOPESD":
                    motivo = "SCOPESD sin FLD_VAL"
            elif _vacio(s.campo(".CL_VALUE")) and s.campo(".INDUS_CL_SET_ID") == "COVERFX":
                motivo = "COVERFX sin CL_VALUE"
        elif s.tipo.upper() == "FLAR-LPS1":
            stdf = s.campo(".STAT_DEF_ID")
            if _vacio(s.campo(".STAT_CHAR_VAL_TXT")) and stdf in ("SPECTRAN", "CROSSMD", "INSOLAPP", "INSOLSIT", "SPECEAPP"):
                motivo = f"{stdf} sin STAT_CHAR_VAL_TXT"
            elif _vacio(s.campo(".INSTR_ID")) and stdf in ("TERCURR", "TERCURR2", "TERCURR3"):
                motivo = f"{stdf} sin INSTR_ID"
        if motivo:
            s.accion = "IGNORE"
            m.anotar("generateLagrLaan", s, f"{motivo} -> IGNORE")


def flg_uniqueness(m: MensajeMotor, _seg) -> None:
    """FLG_Uniqueness (parte de altas de FIGU): país MEX -> MX cuando el mensaje no trae GUNT_OID."""
    if m.modelo_id.upper() not in ("RDRFINSG", "FINSL", "FINSO"):
        return
    for s in m.de_tipo("FinancialInstitutionGeoUnitPrt"):
        if s.accion != "INSERT" or s.campo(".GUNT_OID") is not None:
            continue
        if (s.campo(".GU_ID") or "").upper() == "MEX":
            s.fijar(".GU_ID", "MX")
            m.anotar("FLG_Uniqueness", s, "GU_ID MEX -> MX")
        # El original busca después GUNT_OID en FT_T_GUNT por GU_ID/GU_TYP/GU_CNT: pendiente (BBDD).
        m.anotar("FLG_Uniqueness", s, "PENDIENTE_BBDD: GUNT_OID no viene en el mensaje y el original lo busca en FT_T_GUNT")


# ----------------------------------------------------------------------------------------------
# Reglas nativas (CFTI*/CGSC*) confirmadas por una huella (D-030; docs/motor/REGLAS_OBSERVADAS.md)
# ----------------------------------------------------------------------------------------------
def _anadir_segmento(m: MensajeMotor, tipo: str, origen: str, valores: dict[str, str]) -> Segmento:
    """Añade al final del mensaje un segmento INSERT (valores por etiqueta XELM) y lo devuelve."""
    nodo = ET.SubElement(m.raiz, "SEGMENT", {"TYPE": tipo, "ACTION": "INSERT", "ORIGEN": origen})
    cuerpo = ET.SubElement(nodo, tipo)
    for tag, valor in valores.items():
        ET.SubElement(cuerpo, tag, {"VALUE": valor})
    seg = Segmento(len(m.segmentos) + 1, nodo, m.modelo)
    m.segmentos.append(seg)
    return seg


def _identificadores(m: MensajeMotor, inst_mnem: str | None) -> list[Segmento]:
    return [s for s in m.de_tipo("FinancialInstitutionIdentifier")
            if s.accion not in ("IGNORE", "REFERENCE", "DELETE") and s.campo(".INST_MNEM") == inst_mnem]


def internal_identifier_creator(m: MensajeMotor, seg: Segmento | None, params: list[str]) -> None:
    """CFTIInternalIdentifierCreator (FinancialInstitution, fase F, param FINSID). Huella
    2026-10-01 (alta de Contrapartida Global desde la Workstation): en el alta crea una fila
    FT_T_FIID con FINS_ID_CTXT_TYP = FINSID y FINS_ID = siguiente valor de GET_IDENTIFIER_ID
    (secuencia INTERNAL_FINS_ID_SEQ), DATA_STAT_TYP ACTIVE, GLOBAL_UNIQ_IND N, sin DATA_SRC_ID;
    START_TMS = LAST_CHG_TMS = momento del guardado."""
    contexto = (params[0] if params else "FINSID").strip()
    if seg is None or seg.accion != "INSERT" or seg.nodo.get("NotNewEntity") == "Y":
        return
    inst_mnem = seg.campo(".INST_MNEM")
    if inst_mnem is None:
        return
    if any(s.campo(".FINS_ID_CTXT_TYP") == contexto for s in _identificadores(m, inst_mnem)):
        return                                                    # ya lo trae: idempotente
    nuevo = _anadir_segmento(m, "FinancialInstitutionIdentifier", "CFTIInternalIdentifierCreator", {
        "INSTMNEM": inst_mnem,
        "FINSIDCTXTTYP": contexto,
        "FINSID": MARCADOR_SECUENCIA.format(tabla="FINS", clave=inst_mnem),
        "DATASTATTYP": "ACTIVE",
        "GLOBALUNIQIND": "N",
    })
    m.anotar("CFTIInternalIdentifierCreator", nuevo,
             f"FT_T_FIID {contexto} nuevo (GET_IDENTIFIER_ID) para la entidad del segmento #{seg.numero}")


def constr_pref_id(m: MensajeMotor, _seg, params: list[str]) -> None:
    """CFTIConstrPrefId (Final, params FinancialInstitution, PREF_FINS_ID_CTXT_TYP, PREF_FINS_ID,
    lista de prioridad...). Huellas 2026-10-01: si la entidad no tiene más identificador que el
    FINSID interno, el preferente de FT_T_FINS es FINSID / su valor. Con otros identificadores la
    prioridad observada no sigue la lista del parámetro (CSBCODE, BDIID...): no se replica."""
    if not params or params[0].strip() != "FinancialInstitution":
        return
    for s in m.de_tipo("FinancialInstitution"):
        if s.accion != "INSERT" or s.nodo.get("NotNewEntity") == "Y":
            continue
        if s.campo(".PREF_FINS_ID") is not None:
            continue                                              # lo trae el mensaje
        ids = _identificadores(m, s.campo(".INST_MNEM"))
        internos = [i for i in ids if i.nodo.get("ORIGEN") == "CFTIInternalIdentifierCreator"]
        if internos and len(ids) == len(internos):
            s.fijar(".PREF_FINS_ID_CTXT_TYP", internos[0].campo(".FINS_ID_CTXT_TYP"))
            s.fijar(".PREF_FINS_ID", internos[0].campo(".FINS_ID"))
            m.anotar("CFTIConstrPrefId", s, "PREF_FINS_ID_CTXT_TYP/PREF_FINS_ID = FINSID interno")
        elif ids:
            m.anotar("CFTIConstrPrefId", s, "PENDIENTE_HUELLA: el mensaje trae identificadores; la prioridad "
                     "observada (CSBCODE, BDIID...) no sigue la lista del parámetro")


REPLICAS_NATIVAS: dict[str, Replica] = {
    "CFTIInternalIdentifierCreator": Replica(internal_identifier_creator, "REPLICADA",
                                             "huella huellas/huella_global.csv (2026-10-01), D-041"),
    "CFTIConstrPrefId": Replica(constr_pref_id, "REPLICADA", "huellas 2026-10-01, D-041",
                                "prioridad cuando el mensaje trae identificadores propios: pendiente de huella"),
}


def efectos_nucleo(m: MensajeMotor) -> list[str]:
    """Comportamiento del propio motor (no de una regla del message set) observado en las huellas
    de 2026-10-01 (4 altas de contrapartida, D-041):
      - FT_T_ENFR.INST_MNEM = FINR_INST_MNEM cuando el mensaje no lo trae.
      - FT_T_FINR.CROSS_REF_ID = OID nuevo cuando el mensaje no lo trae (ninguna fila lo referencia)."""
    hechos = []
    for s in m.de_tipo("FINREnterpriseFinancialInstitutionRole"):
        if s.accion == "INSERT" and s.campo(".INST_MNEM") is None and s.campo(".FINR_INST_MNEM") is not None:
            s.fijar(".INST_MNEM", s.campo(".FINR_INST_MNEM"))
            m.anotar("Motor (núcleo)", s, "ENFR.INST_MNEM = FINR_INST_MNEM")
            hechos.append(f"#{s.numero} ENFR.INST_MNEM = FINR_INST_MNEM")
    for s in m.de_tipo("FINSFinancialInstitutionRole"):
        if s.accion == "INSERT" and s.campo(".CROSS_REF_ID") is None:
            s.fijar(".CROSS_REF_ID", MARCADOR_OID.format(clave=f"FINR{s.numero}"))
            m.anotar("Motor (núcleo)", s, "FINR.CROSS_REF_ID = OID nuevo")
            hechos.append(f"#{s.numero} FINR.CROSS_REF_ID = OID nuevo")
    return hechos


REPLICAS: dict[str, Replica] = {
    "ValidateCountryRegion": Replica(validate_country_region, "REPLICADA", "ValidateCountryRegion.process",
                                     "no inactiva las regiones ya existentes en BBDD (sólo FINSX con entidad existente)"),
    "setDifusion": Replica(set_difusion, "REPLICADA", "setDifusion.process",
                           "ramas de UPDATE/DELETE (el generador sólo hace altas, D-005)"),
    "generateLagrLaan": Replica(generate_lagr_laan, "REPLICADA", "generateLagrLaan.process"),
    "FLG_Uniqueness": Replica(flg_uniqueness, "REPLICADA", "FLG_Uniqueness.process",
                              "unicidad del nombre legal (9001) y búsqueda de GUNT_OID: PENDIENTE_BBDD"),
    "GenerateSSISId": Replica(None, "SIN_EFECTO", "GenerateSSISId.process sólo escribe en el log"),
    "InactiveFundMIFID": Replica(None, "SIN_EFECTO", "lee '.DATA_STAT_TYP ' (con espacio): nunca actúa"),
    "Uniqueness": Replica(None, "PENDIENTE_BBDD", "validaciones de unicidad contra BBDD (9001/9002/9003)"),
}


# ----------------------------------------------------------------------------------------------
# Aplicación en el orden del motor
# ----------------------------------------------------------------------------------------------
@dataclass
class Evento:
    regla: str
    tipo: str                # JAVA | NATIVA
    segmento: str            # segmento del message set que la dispara
    fase: str
    estado: str
    detalle: str


def _es_candidata_java(nombre: str, meta: dict | None, m: MensajeMotor) -> bool:
    """Misma heurística que reglas_aplicables.py: modelo y segmentos que aparecen en el código."""
    if meta is None:
        return False
    if meta["modelos"] and m.modelo_id not in meta["modelos"]:
        return False
    tipos = {s.tipo for s in m.segmentos}
    return not meta["segmentos"] or bool(tipos & set(meta["segmentos"]))


def aplicar_motor(mensaje: MensajeMotor) -> list[Evento]:
    """Aplica las reglas replicadas al mensaje (lo modifica) y devuelve qué se hizo y qué falta."""
    ms, java = cargar_message_set(), cargar_reglas_java()
    eventos: list[Evento] = []
    vistas: set = set()

    def ejecutar(regla, segmento: Segmento | None):
        clase = regla.clase_java
        if clase:
            nombre = clase.rsplit(".", 1)[-1].strip()
            replica = REPLICAS.get(nombre)
            antes = len(mensaje.cambios)
            if replica and replica.funcion:
                # La réplica decide por sí misma si aplica (como el código original).
                replica.funcion(mensaje, segmento)
            if len(mensaje.cambios) == antes and not _es_candidata_java(nombre, java.get(nombre), mensaje):
                return
            clave = (nombre, regla.segmento, regla.fase)
            if clave in vistas:
                return
            vistas.add(clave)
            nuevos = [c.descripcion for c in mensaje.cambios[antes:]]
            if replica:
                estado = replica.estado
                detalle = "; ".join(nuevos) or ("sin cambios en este mensaje" if replica.funcion else replica.fuente)
                if replica.parcial:
                    detalle += f" (no replicado: {replica.parcial})"
            else:
                estado = "PENDIENTE"
                detalle = java.get(nombre, {}).get("descripcion", "")
            aviso = " [el message set la nombra con espacios]" if clase != clase.strip() else ""
            eventos.append(Evento(nombre, "JAVA", regla.segmento, regla.fase, estado, detalle + aviso))
        else:
            replica = REPLICAS_NATIVAS.get(regla.nombre)
            antes = len(mensaje.cambios)
            if replica:
                replica.funcion(mensaje, segmento, [p.strip() for p in regla.parametros])
            clave = (regla.nombre, regla.segmento, regla.fase, tuple(regla.parametros))
            if clave in vistas:
                return
            vistas.add(clave)
            parametros = " / ".join(p.strip() for p in regla.parametros)
            if replica:
                nuevos = [c.descripcion for c in mensaje.cambios[antes:]]
                detalle = "; ".join(nuevos) or f"sin cambios en este mensaje ({parametros})"
                if replica.parcial:
                    detalle += f" (no replicado: {replica.parcial})"
                eventos.append(Evento(regla.nombre, "NATIVA", regla.segmento, regla.fase, replica.estado, detalle))
            else:
                eventos.append(Evento(regla.nombre, "NATIVA", regla.segmento, regla.fase, "PENDIENTE_HUELLA",
                                      parametros))

    for r in ms.reglas.get("Initial", []):
        ejecutar(r, None)
    for s in list(mensaje.segmentos):
        for fase in ("B", "A"):
            for r in ms.reglas.get(s.tipo, []):
                if r.fase == fase:
                    ejecutar(r, s)
    for s in list(mensaje.segmentos):
        for r in ms.reglas.get(s.tipo, []):
            if r.fase == "F" or (r.fase == "D" and s.accion == "DELETE"):
                ejecutar(r, s)
    for r in ms.reglas.get("Final", []):
        ejecutar(r, None)
    hechos = efectos_nucleo(mensaje)
    if hechos:
        eventos.append(Evento("Motor (núcleo)", "NUCLEO", "-", "-", "REPLICADA",
                              "; ".join(hechos) + " (huellas 2026-10-01, D-041)"))
    return eventos


__all__ = ["aplicar_motor", "Evento", "REPLICAS", "REPLICAS_NATIVAS", "MARCADOR_SECUENCIA", "MARCADOR_OID",
           "efectos_nucleo", "FASES"]
