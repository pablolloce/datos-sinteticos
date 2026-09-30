#!/usr/bin/env python3
"""
sincronizar_fileloading.py
==========================

Único punto de contacto con el repositorio **pablolloce/fileloading** (D-029). Lee de él la
configuración del motor de GoldenSource y escribe en ``esquema/motor/`` los ficheros
derivados que usan el generador y las herramientas de ``herramientas/motor/``:

    esquema/motor/message_set.json    reglas por segmento del message set STREETREF (orden, fase, parámetros)
    esquema/motor/reglas_java.json    metadatos de las reglas Java de rdrRules.jar
    esquema/motor/reglas_nativas.json comportamiento inferido de las reglas nativas CFTI*/CGSC*
    esquema/motor/notificaciones.json catálogo de notificaciones (severidad y texto)
    esquema/motor/origen.json         commit de fileloading del que salen

Ejecutar cada vez que cambie algo en fileloading (nuevas extracciones o análisis) y subir
el resultado. Ruta de fileloading: ``FILELOADING_REPO`` o ``../fileloading``.

Uso:
    python3 herramientas/motor/sincronizar_fileloading.py
"""

from __future__ import annotations

import csv
import json
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
DESTINO = RAIZ / "esquema" / "motor"


def repo_fileloading() -> Path:
    ruta = Path(os.environ.get("FILELOADING_REPO", RAIZ.parent / "fileloading")).resolve()
    if not (ruta / "extracciones" / "StreetRefMsgSet.xml").exists():
        sys.exit(f"No encuentro el repositorio fileloading en {ruta}.\n"
                 "Clónalo junto a este repositorio o indica su ruta con FILELOADING_REPO=/ruta.")
    return ruta


def message_set(fl: Path, fichero: str) -> dict:
    texto = re.sub(r"<!DOCTYPE[^>]*>", "", (fl / "extracciones" / fichero).read_text(encoding="utf-8"))
    raiz = ET.fromstring(texto)
    bloques = []   # se conserva el orden y las definiciones repetidas de un mismo segmento
    for seg in raiz.findall("SEGMENT"):
        bloques.append({
            "segmento": seg.get("TYPE"),
            "reglas": [{"regla": r.get("RULE_NME"), "fase": r.get("ORDER_TYP"),
                        "parametros": [p.text or "" for p in r.findall("PARAM")]}
                       for r in seg.findall("RULE")],
        })
    return {"message_set": raiz.get("SET"), "fichero": fichero, "bloques": bloques}


def notificaciones(fl: Path) -> list:
    csv.field_size_limit(10**9)
    base = fl / "extracciones"
    textos = {}
    with (base / "13-texto-notificaciones.csv").open(encoding="utf-8", errors="replace") as f:
        for r in csv.DictReader(f):
            if r["NLS_CDE"].strip() in ("ENGLISH", ""):
                clave = (r["APPL_ID"].strip(), r["PART_ID"].strip(), r["NOTFCN_ID"].strip())
                textos[clave] = r["NOTFCN_LONG_TXT"].strip() or r["NOTFCN_SHORT_TXT"].strip()
    salida = []
    with (base / "13-catalogo-notificaciones.csv").open(encoding="utf-8", errors="replace") as f:
        for r in csv.DictReader(f):
            clave = (r["APPL_ID"].strip(), r["PART_ID"].strip(), r["NOTFCN_ID"].strip())
            salida.append({"aplicacion": clave[0], "parte": clave[1], "id": clave[2],
                           "severidad": r["DFLT_SEVERITY_CDE"].strip(), "texto": textos.get(clave, "")})
    return salida


def escribir(nombre: str, datos) -> None:
    ruta = DESTINO / nombre
    ruta.write_text(json.dumps(datos, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"  {ruta.relative_to(RAIZ)}")


def main() -> int:
    fl = repo_fileloading()
    DESTINO.mkdir(parents=True, exist_ok=True)
    commit = subprocess.run(["git", "-C", str(fl), "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
    print(f"Sincronizando desde {fl} ({commit[:10] or 'sin git'}):")
    escribir("message_set.json", message_set(fl, "StreetRefMsgSet.xml"))
    escribir("reglas_java.json", json.loads((fl / "analisis" / "reglas_java.json").read_text(encoding="utf-8")))
    with (fl / "analisis" / "reglas_nativas.csv").open(encoding="utf-8") as f:
        escribir("reglas_nativas.json", {r["REGLA"]: {k.lower(): v for k, v in r.items() if k != "REGLA"}
                                         for r in csv.DictReader(f, delimiter=";")})
    escribir("notificaciones.json", notificaciones(fl))
    escribir("origen.json", {"repositorio": "pablolloce/fileloading", "commit": commit})
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
