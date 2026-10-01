#!/usr/bin/env python3
"""
comparar_huella.py
==================

Compara un mensaje STREET_REF con la "huella" que dejó GoldenSource al procesarlo
(capturada con ``plsql/motor/capturar_huella.sql`` y exportada a CSV) y muestra qué
hizo el motor además de lo que decía el mensaje:

  1. Filas creadas o modificadas que NO vienen de ningún segmento del mensaje
     (p. ej. el FT_T_FIID FINSID de CFTIInternalIdentifierCreator), con las reglas
     candidatas a haberlas creado.
  2. Por cada fila del mensaje: columnas que el motor cambió o rellenó.
  3. Segmentos del mensaje que no dejaron fila (IGNORE, rechazo, REFERENCE...).
  4. Notificaciones de la transacción (FT_T_NTEL) con su texto y severidad.

Es la forma de conocer el comportamiento real de las reglas nativas (CFTI*/CGSC*),
cuyo código no está disponible. Cada diferencia confirmada se registra en
``docs/motor/REGLAS_OBSERVADAS.md`` (ver docs/motor/README.md).

Uso:
    python3 herramientas/motor/comparar_huella.py mensajes_entrada/<Mensaje>.xml huellas/<Mensaje>.csv \
            [--inst-mnem <INST_MNEM de la entidad dada de alta>] [-o docs/motor/huellas/<Mensaje>.md]

El CSV debe tener las columnas TABLA y FILAS_XML (exportación de la última consulta
de capturar_huella.sql).
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from analizar_mensaje import cargar_modelo, leer_xml, resolver_columna  # noqa: E402
from fuentes_motor import (SEVERIDADES, cargar_message_set, cargar_notificaciones,  # noqa: E402
                           cargar_reglas_java, cargar_reglas_nativas)
from reglas_aplicables import evaluar_java, valor_cabecera  # noqa: E402

# Columnas que siempre cambian entre el mensaje y la BBDD: no son "efecto de regla".
TECNICAS = {"LAST_CHG_TMS", "LAST_CHG_USR_ID", "START_TMS"}
# Acciones que dejan fila en BBDD.
ACCIONES_CON_FILA = {"INSERT", "UPDATE", "OPTIMISTICUPDATE", "OPTIMISTICINSERT", "UNKNOWN", "INSERTIFUPDATE"}


def normalizar(valor: str | None) -> str:
    """Normaliza para comparar: sin blancos de relleno, fechas a AAAA-MM-DD HH24:MI:SS, números sin '.0'."""
    if valor is None:
        return ""
    v = valor.strip()
    for formato in ("%m-%d-%Y %I:%M:%S %p", "%Y-%m-%d %H:%M:%S"):
        try:
            return datetime.strptime(v, formato).strftime("%Y-%m-%d %H:%M:%S")
        except ValueError:
            pass
    if re.fullmatch(r"-?\d+\.0+", v):
        v = v.split(".")[0]
    return v


def filas_mensaje(raiz, modelo) -> list[dict]:
    """Filas que el mensaje pide escribir: [{segmento, accion, tabla, valores{col: valor}}]."""
    filas = []
    for n, seg in enumerate(raiz.findall("SEGMENT"), start=1):
        tipo, accion = seg.get("TYPE"), seg.get("ACTION")
        info = modelo["segmentos"].get(tipo)
        tabla = info["tabla"] if info else None
        cuerpo = seg.find(tipo)
        cuerpo = cuerpo if cuerpo is not None else seg
        valores = {}
        if tabla and tabla in modelo["tablas"]:
            columnas = {c[0]: c for c in modelo["tablas"][tabla]["columnas"]}
            for el in cuerpo:
                col, _ = resolver_columna(el.tag, info["xelm"], columnas)
                if col and col in columnas and el.get("VALUE") is not None:
                    valores[col] = normalizar(el.get("VALUE"))
        filas.append({"n": n, "segmento": tipo, "accion": accion, "tabla": tabla, "valores": valores})
    return filas


def _bloques_csv(ruta: Path) -> list[tuple[str, str]]:
    """[(tabla, xml)] del CSV. Admite el CSV estándar (XML entre comillas) y el que exporta
    SQL Developer sin comillas, con el XML partido en varias líneas: una línea que empieza por
    '<TABLA>,' (o '#<TABLA>,') abre un bloque y las siguientes son su XML."""
    texto = ruta.read_text(encoding="utf-8-sig", errors="replace")
    try:
        filas = list(csv.DictReader(texto.splitlines(keepends=True)))
        campos = {c.upper(): c for c in (filas[0].keys() if filas else [])}
        bloques = [(r[campos["TABLA"]].strip(), (r[campos["FILAS_XML"]] or "").strip()) for r in filas]
        for _, xml in bloques:
            if xml:
                ET.fromstring(xml[xml.find("<ROWSET"):])
        return bloques
    except (KeyError, ET.ParseError, csv.Error):
        pass
    bloques: list[list] = []
    for linea in texto.splitlines():
        m = re.match(r'^"?(#?[A-Z][A-Z0-9_$#]*)"?,"?(.*)$', linea)
        if m and m.group(1) != "TABLA" and (not m.group(2) or m.group(2).startswith("<?xml")):
            bloques.append([m.group(1), [m.group(2)]])
        elif bloques:
            bloques[-1][1].append(linea)
    return [(t, "\n".join(ls).strip().strip('"').replace('""', '"')) for t, ls in bloques]


def leer_huella(ruta: Path) -> tuple[dict[str, list[dict]], dict[str, list[dict]]]:
    """Devuelve (tablas de negocio, bloques técnicos '#...'): tabla -> [fila{col: valor}]."""
    csv.field_size_limit(10**9)
    negocio: dict[str, list[dict]] = {}
    tecnico: dict[str, list[dict]] = {}
    for tabla, xml in _bloques_csv(ruta):
        filas = []
        if xml and "<ROWSET" in xml:
            for row in ET.fromstring(xml[xml.find("<ROWSET"):]).findall("ROW"):
                filas.append({c.tag: normalizar(c.text) for c in row})
        (tecnico if tabla.startswith("#") else negocio).setdefault(tabla.lstrip("#"), []).extend(filas)
    return negocio, tecnico


def emparejar(esperadas: list[dict], capturadas: list[dict]) -> list[tuple[dict | None, dict | None]]:
    """Empareja filas del mensaje con filas capturadas por nº de columnas iguales (voraz)."""
    pares, libres = [], list(range(len(capturadas)))
    for e in esperadas:
        mejor, puntos = None, 0
        for i in libres:
            p = sum(1 for c, v in e["valores"].items()
                    if c not in TECNICAS and v and capturadas[i].get(c, "") == v)
            if p > puntos:
                mejor, puntos = i, p
        if mejor is not None:
            libres.remove(mejor)
            pares.append((e, capturadas[mejor]))
        else:
            pares.append((e, None))
    pares += [(None, capturadas[i]) for i in libres]
    return pares


def reglas_candidatas(tabla: str, segmentos_msg: set[str], ms, nativas, java, modelo_msg: str) -> list[str]:
    """Reglas que pueden haber escrito en la tabla: nativas de los segmentos del mensaje que la
    mencionan en su descripción, y Java candidatas para el modelo del mensaje que la usan y
    modifican el mensaje o hacen DML directo."""
    tbl_id = tabla.replace("FT_T_", "")
    salida = []
    for seg in ["Initial", "Final", *sorted(segmentos_msg)]:
        for r in ms.reglas.get(seg, []):
            if r.clase_java:
                nombre = r.clase_java.rsplit(".", 1)[-1].strip()
                meta = java.get(nombre)
                if not meta or evaluar_java(nombre, meta, modelo_msg, segmentos_msg, set())[0] != "CANDIDATA":
                    continue
                if not (meta["dml_directo"] or meta["modifica_mensaje"]):
                    continue
                if tabla in meta["tablas"] or tbl_id in meta["descripcion"]:
                    salida.append(f"`{nombre}` (Java, {seg})")
            else:
                desc = nativas.get(r.nombre, {}).get("descripcion_inferida", "")
                if re.search(rf"\b{tbl_id}\b", desc) or tabla in desc:
                    salida.append(f"`{r.nombre}` (nativa, {seg})")
    return list(dict.fromkeys(salida))


def filtrar_entidad(negocio: dict, tecnico: dict, inst_mnem: str) -> tuple[dict, dict]:
    """Sólo las filas de una entidad (D-040: la huella recoge todo lo escrito en la ventana):
    las que tienen algún valor igual a su INST_MNEM (INST_MNEM, MAIN_ENTITY_ID de
    REGISTER_LOG_TABLE...) y las transacciones del motor que la nombran."""
    negocio = {t: [f for f in fs if inst_mnem in f.values()] for t, fs in negocio.items()}
    trn = {f.get("TRN_ID") for f in tecnico.get("FT_T_MSGP", []) if f.get("XREF_TBL_ROW_OID") == inst_mnem}
    trn |= {f.get("TRN_ID") for f in tecnico.get("FT_T_TRID", [])
            if inst_mnem in (f.get("MAIN_ENTITY_ID_CTXT_TYP") or "") or f.get("MAIN_ENTITY_ID") == inst_mnem}
    tecnico = {t: [f for f in fs if f.get("TRN_ID") in trn] for t, fs in tecnico.items()}
    return ({t: fs for t, fs in negocio.items() if fs}, tecnico)


def informe(ruta_msg: Path, ruta_huella: Path, inst_mnem: str | None = None) -> str:
    modelo = cargar_modelo()
    raiz = leer_xml(ruta_msg)
    esperadas = filas_mensaje(raiz, modelo)
    negocio, tecnico = leer_huella(ruta_huella)
    if inst_mnem:
        negocio, tecnico = filtrar_entidad(negocio, tecnico, inst_mnem)
    ms, nativas, java, notif = cargar_message_set(), cargar_reglas_nativas(), cargar_reglas_java(), cargar_notificaciones()
    segmentos_msg = {e["segmento"] for e in esperadas}
    modelo_msg = valor_cabecera(raiz, "MODEL/MODLID")

    out = [f"# Huella del motor para `{ruta_msg.name}`", "",
           f"> Generado con `herramientas/motor/comparar_huella.py` a partir de `{ruta_huella.name}`.", ""]

    por_tabla: dict[str, list[dict]] = {}
    for e in esperadas:
        if e["tabla"] and e["accion"] in ACCIONES_CON_FILA:
            por_tabla.setdefault(e["tabla"], []).append(e)

    tablas = sorted(set(por_tabla) | set(negocio))
    out += ["## 1. Resumen por tabla", "", "| Tabla | Filas en el mensaje | Filas en la huella | Diferencia |",
            "|---|---|---|---|"]
    for t in tablas:
        a, b = len(por_tabla.get(t, [])), len(negocio.get(t, []))
        out.append(f"| {t} | {a} | {b} | {'' if a == b else f'**{b - a:+d}**'} |")
    out.append("")

    extra, cambios, perdidas = [], [], []
    for t in tablas:
        for e, c in emparejar(por_tabla.get(t, []), negocio.get(t, [])):
            if e is None:
                extra.append((t, c))
            elif c is None:
                perdidas.append(e)
            else:
                difs = []
                for col in sorted(set(e["valores"]) | set(c)):
                    if col in TECNICAS:
                        continue
                    ve, vc = e["valores"].get(col, ""), c.get(col, "")
                    if ve != vc:
                        difs.append(f"`{col}`: mensaje `{ve or '∅'}` → BBDD `{vc or '∅'}`")
                if difs:
                    cambios.append((e, difs))

    out += ["## 2. Filas que no vienen del mensaje (creadas o tocadas por el motor)", ""]
    if not extra:
        out += ["Ninguna.", ""]
    for t, c in extra:
        cand = reglas_candidatas(t, segmentos_msg, ms, nativas, java, modelo_msg)
        valores = ", ".join(f"{k}=`{v}`" for k, v in c.items() if k not in TECNICAS | {"END_TMS"})
        out += [f"- **{t}** — usuario `{c.get('LAST_CHG_USR_ID', '')}`: {valores}",
                f"  - Reglas candidatas: {', '.join(cand) if cand else 'ninguna identificada (revisar reglas de Initial/Final y del segmento padre)'}"]
    out.append("")

    out += ["## 3. Columnas que el motor cambió o rellenó en las filas del mensaje", ""]
    if not cambios:
        out += ["Ninguna.", ""]
    for e, difs in cambios:
        out += [f"- Segmento {e['n']} `{e['segmento']}` ({e['accion']}) → {e['tabla']}"] + [f"  - {d}" for d in difs]
    out.append("")

    out += ["## 4. Segmentos del mensaje sin fila en la huella", ""]
    sin_fila = perdidas + [e for e in esperadas if e["accion"] not in ACCIONES_CON_FILA or not e["tabla"]]
    if not sin_fila:
        out += ["Ninguno.", ""]
    for e in sorted(sin_fila, key=lambda x: x["n"]):
        motivo = ("acción " + e["accion"]) if e["accion"] not in ACCIONES_CON_FILA else (
            "segmento sin tabla" if not e["tabla"] else "la fila no aparece: ¿IGNORE por una regla, rechazo, o fuera de la ventana?")
        out.append(f"- Segmento {e['n']} `{e['segmento']}` ({e['accion']}): {motivo}")
    out.append("")

    ntel = tecnico.get("FT_T_NTEL", [])
    out += ["## 5. Notificaciones de la transacción (FT_T_NTEL)", ""]
    if not ntel:
        out += ["Ninguna (o no se capturó la transacción).", ""]
    else:
        out += ["| Aplicación/Parte/Id | Severidad | Texto | Parámetros |", "|---|---|---|---|"]
        for n in ntel:
            clave = (n.get("APPL_ID", ""), n.get("PART_ID", ""), n.get("NOTFCN_ID", ""))
            d = notif.get(clave, {})
            sev = d.get("severidad", "")
            out.append(f"| {'/'.join(clave)} | {sev} {SEVERIDADES.get(sev, '')} | {d.get('texto', '')} | "
                       f"{n.get('PARM_VAL_TXT', '')} |")
        out.append("")
    trid = tecnico.get("FT_T_TRID", [])
    if trid:
        out += ["## 6. Transacciones del motor en la ventana", "", "| TRN_ID | Tipo de mensaje | Severidad | Estado |",
                "|---|---|---|---|"]
        out += [f"| {t.get('TRN_ID', '')} | {t.get('INPUT_MSG_TYP', '')} | {t.get('CRRNT_SEVERITY_CDE', '')} | "
                f"{t.get('CRRNT_TRN_STAT_TYP', '')} |" for t in trid]
        out.append("")
    return "\n".join(out)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("mensaje", type=Path)
    ap.add_argument("huella", type=Path)
    ap.add_argument("-o", "--salida", type=Path)
    ap.add_argument("--inst-mnem", help="sólo las filas de esta entidad (la huella puede traer varias altas)")
    a = ap.parse_args()
    texto = informe(a.mensaje, a.huella, a.inst_mnem)
    if a.salida:
        a.salida.parent.mkdir(parents=True, exist_ok=True)
        a.salida.write_text(texto, encoding="utf-8")
        print(f"Informe escrito en {a.salida}")
    else:
        print(texto)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
