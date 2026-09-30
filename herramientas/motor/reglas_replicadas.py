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
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

sys.path.insert(0, str(Path(__file__).resolve().parent))

from fuentes_motor import FASES, cargar_message_set, cargar_reglas_java  # noqa: E402
from mensaje_motor import MensajeMotor, Segmento  # noqa: E402


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
            clave = (regla.nombre, regla.segmento, regla.fase)
            if clave in vistas:
                return
            vistas.add(clave)
            eventos.append(Evento(regla.nombre, "NATIVA", regla.segmento, regla.fase, "PENDIENTE_HUELLA",
                                  " / ".join(p.strip() for p in regla.parametros)))

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
    return eventos


__all__ = ["aplicar_motor", "Evento", "REPLICAS", "FASES"]
