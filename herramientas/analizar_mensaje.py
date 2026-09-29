#!/usr/bin/env python3
"""
analizar_mensaje.py
===================

Analiza un mensaje XML STREET_REF (GoldenSource) de ``mensajes_entrada/`` y genera
un informe de mapeo en Markdown:

    Segmento XML -> Tabla física -> Elemento XML -> Columna (tipo, nulabilidad)

Además señala lo que el PL/SQL tendrá que resolver:
  - columnas NOT NULL que el mensaje no informa (normalmente OIDs a generar con NEW_OID),
  - elementos del mensaje sin columna física,
  - claves ajenas (FK) de cada tabla y su estado.

Fuente: ``esquema/modelo/modelo.json`` (generado con ``herramientas/construir_modelo.py``).

Uso:
    python3 herramientas/analizar_mensaje.py mensajes_entrada/<fichero>.xml [-o docs/mapeos/<fichero>.md]
    python3 herramientas/analizar_mensaje.py --segmento FinancialInstitution
    python3 herramientas/analizar_mensaje.py --tabla FT_T_FINS
"""

from __future__ import annotations

import argparse
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
MODELO = RAIZ / "esquema" / "modelo" / "modelo.json"

# Columnas que fija siempre el generador (D-001, D-007).
COLUMNAS_TECNICAS = {"LAST_CHG_USR_ID", "LAST_CHG_TMS", "START_TMS"}

# Acciones de segmento y su tratamiento en el generador (D-005).
TRATAMIENTO_ACCION = {
    "INSERT": "INSERT",
    "REFERENCE": "Sin insert (referencia a entidad existente)",
    "OPTIMISTICUPDATE": "INSERT (entidad nueva)",
    "OPTIMISTICINSERT": "INSERT (entidad nueva)",
    "UNKNOWN": "INSERT (entidad nueva)",
    "IGNORE": "Se ignora",
}


def cargar_modelo() -> dict:
    if not MODELO.exists():
        sys.exit(f"No existe {MODELO}. Ejecuta antes: python3 herramientas/construir_modelo.py")
    return json.loads(MODELO.read_text(encoding="utf-8"))


def leer_xml(ruta: Path) -> ET.Element:
    """Lee el XML ignorando la cabecera de texto que añade el frontal y el DOCTYPE."""
    texto = ruta.read_text(encoding="utf-8")
    inicio = texto.find("<STREET_REF")
    if inicio < 0:
        raise ValueError(f"{ruta}: no se encuentra el elemento raíz <STREET_REF>")
    return ET.fromstring(texto[inicio:])


def tipo_columna(c: list) -> str:
    nombre, tipo, longitud, precision, escala, _nulo, _defecto = c
    if tipo in ("CHAR", "VARCHAR2"):
        return f"{tipo}({longitud})"
    if tipo == "NUMBER" and precision is not None:
        return f"NUMBER({precision}{',' + str(escala) if escala else ''})"
    return tipo


def resolver_columna(tag: str, xelm: dict, columnas: dict) -> tuple[str | None, str]:
    """Devuelve (columna, origen). Origen: 'XELM', 'nombre' (tag == columna sin '_') o ''."""
    col = xelm.get(tag)
    if col and col in columnas:
        return col, "XELM"
    for nombre in columnas:
        if nombre.replace("_", "") == tag:
            return nombre, "nombre"
    return (col, "XELM (no existe en la tabla)") if col else (None, "")


def informe_tabla(nombre: str, modelo: dict) -> str:
    t = modelo["tablas"].get(nombre)
    if not t:
        return f"Tabla `{nombre}` no encontrada en el modelo.\n"
    lineas = [f"## {nombre}", "", f"PK: {', '.join(t['pk']) or '-'}", "",
              "| Columna | Tipo | Nulo | Defecto |", "|---|---|---|---|"]
    for c in t["columnas"]:
        lineas.append(f"| {c[0]} | {tipo_columna(c)} | {c[5]} | {c[6] or ''} |")
    if t["fk"]:
        lineas += ["", "| FK | Columnas | Referencia | Estado |", "|---|---|---|---|"]
        for fk in t["fk"]:
            lineas.append(f"| {fk['nombre']} | {', '.join(fk['columnas'])} | "
                          f"{fk['tabla_ref']}({', '.join(fk['columnas_ref'])}) | {fk['estado']} |")
    return "\n".join(lineas) + "\n"


def informe_segmento(nombre: str, modelo: dict) -> str:
    s = modelo["segmentos"].get(nombre)
    if not s:
        return f"Segmento `{nombre}` no encontrado en XSEG.\n"
    lineas = [f"# {nombre} (SEGMENT_ID {s['id']}, TBL_ID {s['tbl_id']})", "",
              f"Tabla física: `{s['tabla']}` (origen: {s['origen_tabla']})"]
    if s["xelm_heredado_de"]:
        lineas.append(f"XELM heredado del segmento {s['xelm_heredado_de']} (mismo TBL_ID).")
    lineas += ["", "| Elemento XML | Columna |", "|---|---|"]
    lineas += [f"| {k} | {v} |" for k, v in sorted(s["xelm"].items())]
    texto = "\n".join(lineas) + "\n\n"
    return texto + (informe_tabla(s["tabla"], modelo) if s["tabla"] else "")


def informe_mensaje(ruta: Path, modelo: dict) -> str:
    raiz = leer_xml(ruta)
    cabecera = raiz.find("HEADER")
    salida = [f"# Mapeo del mensaje `{ruta.name}`", "",
              "> Generado con `herramientas/analizar_mensaje.py`. No editar a mano:",
              "> regenerar si cambia el mensaje o el modelo.", ""]

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
    tablas_usadas: list[str] = []

    for n, seg in enumerate(raiz.findall("SEGMENT"), start=1):
        tipo, accion = seg.get("TYPE"), seg.get("ACTION") or "UNKNOWN"
        s = modelo["segmentos"].get(tipo)
        tabla = s["tabla"] if s else None
        resumen.append(f"| {n} | {tipo} | {accion} | {tabla or '¿?'} | "
                       f"{TRATAMIENTO_ACCION.get(accion, 'ACCIÓN SIN TRATAMIENTO')} |")
        if not s:
            avisos.append(f"#{n} `{tipo}`: no existe en XSEG.")
            continue
        if not tabla:
            avisos.append(f"#{n} `{tipo}` (TBL_ID {s['tbl_id']}): sin tabla física resuelta; "
                          "añadirla a esquema/modelo/tablas_manual.csv.")
            continue
        if s["origen_tabla"] == "inferida":
            avisos.append(f"#{n} `{tipo}`: tabla `{tabla}` inferida por columnas; confirmarla en tablas_manual.csv.")
        if accion not in TRATAMIENTO_ACCION:
            avisos.append(f"#{n} `{tipo}`: acción `{accion}` sin tratamiento definido.")
        if accion in ("REFERENCE", "IGNORE"):
            continue
        if tabla not in tablas_usadas:
            tablas_usadas.append(tabla)

        t = modelo["tablas"][tabla]
        columnas = {c[0]: c for c in t["columnas"]}
        cuerpo = seg.find(tipo)
        detalle += [f"### #{n} {tipo} -> {tabla} ({accion})", "",
                    f"PK: `{', '.join(t['pk'])}`" + (f" · XELM heredado del segmento {s['xelm_heredado_de']}"
                                                   if s["xelm_heredado_de"] else ""), "",
                    "| Elemento XML | Valor | Columna | Tipo | Nulo | Mapeo |", "|---|---|---|---|---|---|"]
        informadas = set()
        for el in (cuerpo if cuerpo is not None else []):
            col, origen = resolver_columna(el.tag, s["xelm"], columnas)
            c = columnas.get(col) if col else None
            if c:
                informadas.add(col)
            else:
                avisos.append(f"#{n} `{tipo}`: elemento `{el.tag}` sin columna física en {tabla}"
                              " (elemento lógico del motor; no se inserta).")
            detalle.append(f"| {el.tag} | `{el.get('VALUE')}` | {col if c else '—'} | "
                           f"{tipo_columna(c) if c else ''} | {c[5] if c else ''} | {origen} |")
        pendientes = [c for c in columnas if columnas[c][5] == "N" and c not in informadas
                      and c not in COLUMNAS_TECNICAS]
        if pendientes:
            detalle += ["", f"**NOT NULL no informadas en el mensaje** (generar/resolver en PL/SQL): "
                            f"{', '.join(pendientes)}"]
        fks = [f"{', '.join(fk['columnas'])} → {fk['tabla_ref']} ({fk['estado']})" for fk in t["fk"]
               if set(fk["columnas"]) & informadas]
        if fks:
            detalle += ["", "FKs sobre columnas informadas: " + "; ".join(fks)]
        detalle.append("")

    salida += resumen + [""]
    salida += ["## Tablas a insertar (orden de aparición)", "", ", ".join(tablas_usadas) or "-", ""]
    salida += ["## Avisos", ""] + ([f"- {a}" for a in avisos] or ["- Ninguno."]) + [""]
    salida += ["## Detalle por segmento", ""] + detalle
    return "\n".join(salida)


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("mensaje", nargs="?", type=Path, help="Fichero XML de mensajes_entrada/")
    p.add_argument("-o", "--salida", type=Path, help="Fichero Markdown de salida (por defecto, stdout)")
    p.add_argument("--segmento", help="Muestra el mapeo XSEG/XELM y la tabla de un segmento")
    p.add_argument("--tabla", help="Muestra columnas, PK y FKs de una tabla física")
    args = p.parse_args()

    modelo = cargar_modelo()
    if args.tabla:
        texto = informe_tabla(args.tabla.upper(), modelo)
    elif args.segmento:
        texto = informe_segmento(args.segmento, modelo)
    elif args.mensaje:
        texto = informe_mensaje(args.mensaje, modelo)
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
