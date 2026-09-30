"""
fuentes_motor.py
================

Acceso de solo lectura a la información del motor de GoldenSource que vive en el
repositorio **pablolloce/fileloading** (no se copia aquí; ver docs/motor/README.md):

    <fileloading>/extracciones/StreetRefMsgSet.xml   message set: reglas por segmento
    <fileloading>/extracciones/13-*.csv               catálogo y textos de notificaciones
    <fileloading>/analisis/reglas_java.json           metadatos de las reglas Java (rdrRules.jar)
    <fileloading>/analisis/reglas_nativas.csv         comportamiento inferido de las reglas C++ (CFTI*/CGSC*)

Ruta del clon de fileloading: variable de entorno ``FILELOADING_REPO`` o, por defecto,
la carpeta hermana ``../fileloading``.
"""

from __future__ import annotations

import csv
import json
import os
import re
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]


def repo_fileloading() -> Path:
    ruta = Path(os.environ.get("FILELOADING_REPO", RAIZ.parent / "fileloading")).resolve()
    if not (ruta / "extracciones" / "StreetRefMsgSet.xml").exists():
        sys.exit(f"No encuentro el repositorio fileloading en {ruta}.\n"
                 "Clónalo junto a este repositorio o indica su ruta con FILELOADING_REPO=/ruta.")
    return ruta


# Fases de ejecución de una regla (atributo ORDER_TYP del message set).
# B y A están confirmadas por el uso; F y D se deducen de las reglas que las usan.
FASES = {
    "B": "Antes de procesar el segmento",
    "A": "Después de procesar el segmento",
    "F": "Al final (tras persistir el segmento)",
    "D": "Al borrar (acción DELETE)",
}

# Segmentos especiales del message set que no son tablas.
SEGMENTOS_MENSAJE = ("Initial", "Final")


@dataclass
class Regla:
    nombre: str          # RULE_NME
    fase: str            # ORDER_TYP
    parametros: list[str]
    segmento: str        # SEGMENT TYPE del message set
    orden: int           # posición dentro del segmento

    @property
    def clase_java(self) -> str | None:
        if self.nombre == "CGSCInvokeJavaRule" and self.parametros:
            return self.parametros[0].strip()
        return None


@dataclass
class MessageSet:
    nombre: str
    reglas: dict[str, list[Regla]] = field(default_factory=dict)   # segmento -> reglas
    segmentos_duplicados: list[str] = field(default_factory=list)


def cargar_message_set(fichero: str = "StreetRefMsgSet.xml") -> MessageSet:
    texto = (repo_fileloading() / "extracciones" / fichero).read_text(encoding="utf-8")
    texto = re.sub(r"<!DOCTYPE[^>]*>", "", texto)
    raiz = ET.fromstring(texto)
    ms = MessageSet(raiz.get("SET", fichero))
    for seg in raiz.findall("SEGMENT"):
        tipo = seg.get("TYPE")
        if tipo in ms.reglas:
            ms.segmentos_duplicados.append(tipo)
        lista = ms.reglas.setdefault(tipo, [])
        for regla in seg.findall("RULE"):
            lista.append(Regla(regla.get("RULE_NME"), regla.get("ORDER_TYP"),
                               [p.text or "" for p in regla.findall("PARAM")], tipo, len(lista) + 1))
    return ms


def cargar_reglas_java() -> dict:
    ruta = repo_fileloading() / "analisis" / "reglas_java.json"
    return json.loads(ruta.read_text(encoding="utf-8"))["reglas"]


def cargar_reglas_nativas() -> dict[str, dict]:
    ruta = repo_fileloading() / "analisis" / "reglas_nativas.csv"
    with ruta.open(encoding="utf-8") as f:
        return {r["REGLA"]: r for r in csv.DictReader(f, delimiter=";")}


def cargar_notificaciones() -> dict[tuple[str, str, str], dict]:
    """(APPL_ID, PART_ID, NOTFCN_ID) -> {severidad, texto}."""
    base = repo_fileloading() / "extracciones"
    csv.field_size_limit(10**9)
    textos = {}
    with (base / "13-texto-notificaciones.csv").open(encoding="utf-8", errors="replace") as f:
        for r in csv.DictReader(f):
            if r["NLS_CDE"].strip() in ("ENGLISH", ""):
                clave = (r["APPL_ID"].strip(), r["PART_ID"].strip(), r["NOTFCN_ID"].strip())
                textos[clave] = r["NOTFCN_LONG_TXT"].strip() or r["NOTFCN_SHORT_TXT"].strip()
    salida = {}
    with (base / "13-catalogo-notificaciones.csv").open(encoding="utf-8", errors="replace") as f:
        for r in csv.DictReader(f):
            clave = (r["APPL_ID"].strip(), r["PART_ID"].strip(), r["NOTFCN_ID"].strip())
            salida[clave] = {"severidad": r["DFLT_SEVERITY_CDE"].strip(), "texto": textos.get(clave, "")}
    return salida


SEVERIDADES = {"10": "SUCCESS", "20": "INFO", "30": "WARNING", "40": "ERROR", "50": "FATAL"}
