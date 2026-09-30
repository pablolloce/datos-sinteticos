#!/usr/bin/env python3
"""
construir_modelo.py
===================

Convierte las extracciones originales de BBDD (``esquema/old/*.csv``) en un único
fichero compacto ``esquema/modelo/modelo.json`` que usan el resto de herramientas.

Qué contiene ``modelo.json``:

- ``segmentos``: SEGMENT_NME -> {id, tbl_id, tabla, origen_tabla, xelm}
    * ``tabla``: tabla física resuelta (ver "Resolución de tabla" más abajo).
    * ``xelm``: {ELEMENT_XML_TAG: COL_NME} del propio segmento o, si no tiene filas
      en XELM, de otro segmento vigente con el mismo TBL_ID (``xelm_heredado_de``).
- ``tablas``: TABLE_NAME -> {columnas, pk, uk, fk} (sólo tablas del esquema KYTL_GC).

Resolución de tabla física de un segmento (TBL_ID = XSEG.SEGMENT_DESC):
    1. ``esquema/modelo/tablas_manual.csv`` (confirmado a mano)       -> origen "manual"
    2. Existe ``FT_T_<TBL_ID>``                                       -> origen "directa"
    3. Una única tabla contiene todas las columnas XELM del segmento  -> origen "inferida"
    4. Si no                                                         -> tabla = null

Uso:
    python3 herramientas/construir_modelo.py
"""

from __future__ import annotations

import csv
import json
import sys
from collections import defaultdict
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
ORIGEN = RAIZ / "esquema" / "old"
DESTINO = RAIZ / "esquema" / "modelo" / "modelo.json"
MANUAL = RAIZ / "esquema" / "modelo" / "tablas_manual.csv"

# Columnas técnicas presentes en casi todas las tablas: no sirven para inferir la tabla.
COLUMNAS_COMUNES = {"START_TMS", "END_TMS", "LAST_CHG_TMS", "LAST_CHG_USR_ID",
                    "DATA_SRC_ID", "DATA_STAT_TYP"}

csv.field_size_limit(sys.maxsize)


def leer(nombre: str):
    """Filas de esquema/old/<nombre> y, si existe, de su complemento *_ADICIONALES.csv
    (tablas accedidas por sinónimo, esquema/extraer_tablas_adicionales.sql)."""
    ficheros = [ORIGEN / nombre, ORIGEN / nombre.replace("_KYTL_GC.csv", "_ADICIONALES.csv")]
    for ruta in dict.fromkeys(ficheros):
        if ruta.exists():
            with ruta.open(encoding="utf-8-sig", newline="") as f:
                for fila in csv.DictReader(f):
                    yield {k.strip().upper(): (v or "") for k, v in fila.items() if k is not None}


def cargar_tablas() -> dict:
    tablas: dict = defaultdict(lambda: {"columnas": [], "pk": [], "uk": [], "fk": []})
    for r in leer("ALL_TAB_COLUMNS_KYTL_GC.csv"):
        tablas[r["TABLE_NAME"]]["columnas"].append([
            int(r["COLUMN_ID"] or 0), r["COLUMN_NAME"], r["DATA_TYPE"],
            int(r["DATA_LENGTH"] or 0),
            int(r["DATA_PRECISION"]) if r["DATA_PRECISION"] else None,
            int(r["DATA_SCALE"]) if r["DATA_SCALE"] else None,
            r["NULLABLE"], (r["DATA_DEFAULT"] or "").strip() or None,
        ])
    for t in tablas.values():
        t["columnas"] = [c[1:] for c in sorted(t["columnas"])]

    columnas_cons: dict = defaultdict(list)
    for r in leer("ALL_CONS_COLUMNS_KYTL_GC.csv"):
        columnas_cons[r["CONSTRAINT_NAME"]].append((int(r["POSITION"] or 0), r["COLUMN_NAME"]))
    cols = {k: [c for _, c in sorted(v)] for k, v in columnas_cons.items()}

    constraints = {r["CONSTRAINT_NAME"]: r for r in leer("ALL_CONSTRAINTS_KYTL_GC.csv")}
    for nombre, r in constraints.items():
        tabla, tipo = r["TABLE_NAME"], r["CONSTRAINT_TYPE"]
        if tabla not in tablas:
            continue
        if tipo == "P":
            tablas[tabla]["pk"] = cols.get(nombre, [])
        elif tipo == "U":
            tablas[tabla]["uk"].append({"nombre": nombre, "columnas": cols.get(nombre, []),
                                        "estado": r["STATUS"]})
        elif tipo == "R":
            ref = constraints.get(r["R_CONSTRAINT_NAME"], {})
            tablas[tabla]["fk"].append({
                "nombre": nombre, "columnas": cols.get(nombre, []),
                "tabla_ref": ref.get("TABLE_NAME"), "columnas_ref": cols.get(r["R_CONSTRAINT_NAME"], []),
                "estado": r["STATUS"],
            })
    return dict(tablas)


def cargar_manual() -> dict:
    if not MANUAL.exists():
        return {}
    with MANUAL.open(encoding="utf-8") as f:
        return {r["TBL_ID"].strip(): r["TABLA"].strip() for r in csv.DictReader(f)}


def main() -> int:
    tablas = cargar_tablas()
    manual = cargar_manual()

    xelm: dict = defaultdict(dict)
    for r in leer("XELM.csv"):
        xelm[r["SEGMENT_ID"].strip()][r["ELEMENT_XML_TAG"].strip()] = r["COL_NME"].strip()

    segmentos_raw = [r for r in leer("XSEG.csv") if not r["END_TMS"].strip()]
    # Para heredar XELM: primer segmento con filas XELM para cada TBL_ID.
    xelm_por_tbl: dict = {}
    for r in segmentos_raw:
        sid, tbl = r["SEGMENT_ID"].strip(), r["SEGMENT_DESC"].strip()
        if xelm.get(sid) and tbl not in xelm_por_tbl:
            xelm_por_tbl[tbl] = sid

    columnas_por_tabla = {t: {c[0] for c in d["columnas"]} for t, d in tablas.items()}

    def resolver_tabla(tbl: str, columnas_xelm: set) -> tuple:
        if tbl in manual:
            return manual[tbl], "manual"
        if f"FT_T_{tbl}" in tablas:
            return f"FT_T_{tbl}", "directa"
        significativas = columnas_xelm - COLUMNAS_COMUNES
        if significativas:
            candidatas = [t for t, cs in columnas_por_tabla.items()
                          if significativas <= cs and not t.startswith("FT_V_")]
            if len(candidatas) == 1:
                return candidatas[0], "inferida"
        return None, None

    segmentos = {}
    for r in segmentos_raw:
        sid, tbl = r["SEGMENT_ID"].strip(), r["SEGMENT_DESC"].strip()
        propio = xelm.get(sid)
        origen_xelm = sid if propio else xelm_por_tbl.get(tbl)
        mapa = xelm.get(origen_xelm, {}) if origen_xelm else {}
        tabla, origen = resolver_tabla(tbl, set(mapa.values()))
        segmentos[r["SEGMENT_NME"].strip()] = {
            "id": sid, "tbl_id": tbl, "tabla": tabla, "origen_tabla": origen,
            "xelm_heredado_de": None if propio else origen_xelm, "xelm": mapa,
        }

    DESTINO.parent.mkdir(parents=True, exist_ok=True)
    with DESTINO.open("w", encoding="utf-8") as f:
        json.dump({"segmentos": segmentos, "tablas": tablas}, f, ensure_ascii=False,
                  separators=(",", ":"), sort_keys=True)

    sin_tabla = sorted({s["tbl_id"] for s in segmentos.values() if not s["tabla"]})
    inferidas = sorted({(s["tbl_id"], s["tabla"]) for s in segmentos.values()
                        if s["origen_tabla"] == "inferida"})
    print(f"Modelo escrito en {DESTINO.relative_to(RAIZ)}: "
          f"{len(segmentos)} segmentos, {len(tablas)} tablas.")
    print(f"TBL_ID con tabla inferida por columnas ({len(inferidas)}): "
          + ", ".join(f"{a}->{b}" for a, b in inferidas))
    print(f"TBL_ID sin tabla física resuelta ({len(sin_tabla)}): {', '.join(sin_tabla)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
