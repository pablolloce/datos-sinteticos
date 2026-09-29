#!/usr/bin/env python3
"""
analizar_mensaje.py
===================

Analiza un mensaje XML STREET_REF (GoldenSource) de la carpeta
``mensajes_entrada/`` y genera un informe de mapeo en Markdown:

    Segmento XML  ->  Tabla FT_T_XXXX  ->  Elemento XML -> Columna BBDD

El informe se usa como base para escribir el PL/SQL de cada entidad y
para detectar huecos (segmentos sin definición en XELM, elementos del
mensaje que no tienen columna, etc.).

Fuentes:
    esquema/XSEG.csv  -> SEGMENT_ID, SEGMENT_NME (nombre en el XML),
                         SEGMENT_DESC (sufijo de tabla: FT_T_<SEGMENT_DESC>)
    esquema/XELM.csv  -> SEGMENT_ID, TBL_ID, ELEMENT_XML_TAG, COL_NME

Uso:
    python3 herramientas/analizar_mensaje.py mensajes_entrada/<fichero>.xml
    python3 herramientas/analizar_mensaje.py mensajes_entrada/<fichero>.xml -o docs/mapeos/<fichero>.md
    python3 herramientas/analizar_mensaje.py --segmento FinancialInstitution
"""

from __future__ import annotations

import argparse
import csv
import sys
import xml.etree.ElementTree as ET
from collections import OrderedDict
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
XSEG_CSV = RAIZ / "esquema" / "XSEG.csv"
XELM_CSV = RAIZ / "esquema" / "XELM.csv"

# Acciones de segmento conocidas y su tratamiento en el generador (ver DECISIONES.md)
TRATAMIENTO_ACCION = {
    "INSERT": "INSERT",
    "REFERENCE": "Sin insert (referencia a entidad ya creada en el mismo mensaje)",
    "OPTIMISTICUPDATE": "INSERT si no existe (pendiente de confirmar, ver DECISIONES.md)",
}


def cargar_xseg() -> dict[str, dict]:
    """SEGMENT_NME -> fila de XSEG (sólo segmentos vigentes, END_TMS vacío)."""
    segmentos: dict[str, dict] = {}
    with XSEG_CSV.open(encoding="utf-8") as f:
        for fila in csv.DictReader(f):
            if fila["END_TMS"].strip():
                continue
            segmentos[fila["SEGMENT_NME"].strip()] = fila
    return segmentos


def cargar_xelm() -> dict[str, "OrderedDict[str, dict]"]:
    """SEGMENT_ID -> {ELEMENT_XML_TAG -> fila XELM}."""
    elementos: dict[str, OrderedDict] = {}
    with XELM_CSV.open(encoding="utf-8") as f:
        for fila in csv.DictReader(f):
            elementos.setdefault(fila["SEGMENT_ID"].strip(), OrderedDict())[
                fila["ELEMENT_XML_TAG"].strip()
            ] = fila
    return elementos


def leer_xml(ruta: Path) -> ET.Element:
    """Lee el XML ignorando la cabecera de texto que añade el frontal
    (líneas previas a '<?xml') y la declaración DOCTYPE."""
    texto = ruta.read_text(encoding="utf-8")
    inicio = texto.find("<STREET_REF")
    if inicio < 0:
        raise ValueError(f"{ruta}: no se encuentra el elemento raíz <STREET_REF>")
    return ET.fromstring(texto[inicio:])


def informe_segmento(nombre: str, xseg: dict, xelm: dict) -> str:
    fila = xseg.get(nombre)
    if not fila:
        return f"Segmento `{nombre}` no encontrado en XSEG.\n"
    seg_id = fila["SEGMENT_ID"].strip()
    tabla = f"FT_T_{fila['SEGMENT_DESC'].strip()}"
    lineas = [f"## {nombre} -> {tabla} (SEGMENT_ID {seg_id})", "",
              "| Elemento XML | Columna | Descripción |", "|---|---|---|"]
    for tag, e in xelm.get(seg_id, {}).items():
        lineas.append(f"| {tag} | {e['COL_NME'].strip()} | {e['ELEMENT_NME'].strip()} |")
    if seg_id not in xelm:
        lineas.append("| _(sin elementos en XELM)_ | | |")
    return "\n".join(lineas) + "\n"


def informe_mensaje(ruta: Path, xseg: dict, xelm: dict) -> str:
    raiz = leer_xml(ruta)
    cabecera = raiz.find("HEADER")
    salida = [f"# Mapeo del mensaje `{ruta.name}`", "",
              "> Generado con `herramientas/analizar_mensaje.py`. No editar a mano:",
              "> regenerar si cambia el mensaje o los esquemas.", ""]

    if cabecera is not None:
        salida += ["## Cabecera", "", "| Campo | Valor |", "|---|---|"]
        for campo in ("MAIN_ENTITY_TBL_TYP", "MAIN_ENTITY_NME", "MODEL/MODLID", "MSGCLASSIFICATION"):
            nodo = cabecera.find(campo)
            if nodo is not None:
                salida.append(f"| {campo} | {nodo.get('VALUE')} |")
        salida.append("")

    avisos: list[str] = []
    resumen = ["## Resumen de segmentos (en orden de aparición)", "",
               "| # | Segmento | Acción | Tabla | Tratamiento |", "|---|---|---|---|---|"]
    detalle: list[str] = []

    for n, seg in enumerate(raiz.findall("SEGMENT"), start=1):
        tipo, accion = seg.get("TYPE"), seg.get("ACTION")
        fila = xseg.get(tipo)
        tabla = f"FT_T_{fila['SEGMENT_DESC'].strip()}" if fila else "¿?"
        resumen.append(f"| {n} | {tipo} | {accion} | {tabla} | "
                       f"{TRATAMIENTO_ACCION.get(accion, 'ACCIÓN DESCONOCIDA')} |")
        if not fila:
            avisos.append(f"Segmento #{n} `{tipo}`: no existe en XSEG.")
            continue
        if accion not in TRATAMIENTO_ACCION:
            avisos.append(f"Segmento #{n} `{tipo}`: acción `{accion}` sin tratamiento definido.")
        if accion == "REFERENCE":
            continue

        seg_id = fila["SEGMENT_ID"].strip()
        mapa = xelm.get(seg_id, {})
        if not mapa:
            avisos.append(f"Segmento #{n} `{tipo}` ({tabla}, SEGMENT_ID {seg_id}): "
                          "sin elementos en XELM; no se pueden mapear columnas.")
        cuerpo = seg.find(tipo)
        detalle += [f"### #{n} {tipo} -> {tabla} ({accion})", "",
                    "| Elemento XML | Valor | Columna |", "|---|---|---|"]
        presentes = set()
        for el in (cuerpo if cuerpo is not None else []):
            presentes.add(el.tag)
            col = mapa.get(el.tag, {}).get("COL_NME", "").strip()
            if mapa and not col:
                avisos.append(f"Segmento #{n} `{tipo}`: elemento `{el.tag}` sin columna en XELM.")
            detalle.append(f"| {el.tag} | `{el.get('VALUE')}` | {col or '**¿?**'} |")
        no_informados = [c["COL_NME"].strip() for t, c in mapa.items()
                         if t not in presentes and c["COL_NME"].strip().endswith("_OID")]
        if no_informados:
            detalle.append("")
            detalle.append("Columnas OID de XELM no presentes en el mensaje (posible clave "
                           f"generada por el motor): {', '.join(no_informados)}")
        detalle.append("")

    salida += resumen + [""]
    salida += ["## Avisos", ""] + ([f"- {a}" for a in avisos] or ["- Ninguno."]) + [""]
    salida += ["## Detalle por segmento", ""] + detalle
    return "\n".join(salida)


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("mensaje", nargs="?", type=Path, help="Fichero XML de mensajes_entrada/")
    p.add_argument("-o", "--salida", type=Path, help="Fichero Markdown de salida (por defecto, stdout)")
    p.add_argument("--segmento", help="Muestra el mapeo completo XSEG/XELM de un segmento")
    args = p.parse_args()

    xseg, xelm = cargar_xseg(), cargar_xelm()
    if args.segmento:
        texto = informe_segmento(args.segmento, xseg, xelm)
    elif args.mensaje:
        texto = informe_mensaje(args.mensaje, xseg, xelm)
    else:
        p.print_help()
        return 1

    if args.salida:
        args.salida.parent.mkdir(parents=True, exist_ok=True)
        args.salida.write_text(texto, encoding="utf-8")
        print(f"Informe escrito en {args.salida}")
    else:
        print(texto)
    return 0


if __name__ == "__main__":
    sys.exit(main())
