#!/usr/bin/env python3
"""
reglas_aplicables.py
====================

Dado un mensaje STREET_REF de ``mensajes_entrada/``, lista las reglas del motor de
GoldenSource (message set ``StreetRefMsgSet``) que se ejecutarían al procesarlo, en el
orden del motor, y qué se sabe de cada una:

  - Reglas Java de rdrRules.jar (``CGSCInvokeJavaRule``): código conocido. Se filtran por
    el modelo (``MODEL/MODLID``), los segmentos y las acciones que aparecen en su código.
    El filtro es heurístico: indica candidatas; la condición exacta está en el código y en
    ``docs/motor/REGLAS_JAVA_RDR.md``.
  - Reglas nativas C++ (``CFTI*`` / ``CGSC*``): sin código. Se muestra el comportamiento
    inferido y su impacto; se confirma con la captura de huella (``docs/motor/README.md``).

El generador actual (D-014/D-017) traduce el mensaje LITERALMENTE: todo lo que estas
reglas añaden o cambian NO aparece hoy en la BBDD sintética. Este informe es la lista de
diferencias potenciales entre la BBDD sintética y lo que crearía GoldenSource.

Uso:
    python3 herramientas/motor/reglas_aplicables.py mensajes_entrada/<Mensaje>.xml [-o docs/motor/reglas/<Mensaje>.md]

Usa la configuración sincronizada en ``esquema/motor/`` (sincronizar_fileloading.py).
"""

from __future__ import annotations

import argparse
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from fuentes_motor import (FASES, SEVERIDADES, cargar_message_set, cargar_notificaciones,  # noqa: E402
                           cargar_reglas_java, cargar_reglas_nativas)
from analizar_mensaje import leer_xml  # noqa: E402


def valor_cabecera(raiz, ruta: str) -> str:
    nodo = raiz.find(f"HEADER/{ruta}")
    return nodo.get("VALUE", "") if nodo is not None else ""


def evaluar_java(clase: str, meta: dict | None, modelo: str, segmentos: set[str],
                 acciones: set[str]) -> tuple[str, str]:
    """Devuelve (veredicto, motivo). Veredictos: CANDIDATA, DESCARTADA, DESCONOCIDA."""
    if meta is None:
        return "DESCONOCIDA", f"la clase `{clase}` no está en rdrRules.jar"
    if meta["modelos"] and modelo not in meta["modelos"]:
        return "DESCARTADA", f"sólo actúa con modelos {', '.join(meta['modelos'])}"
    comunes = segmentos & set(meta["segmentos"])
    if meta["segmentos"] and not comunes:
        return "DESCARTADA", "ningún segmento del mensaje coincide con los que trata"
    motivo = []
    if meta["modelos"]:
        motivo.append(f"modelo {modelo}")
    if comunes:
        motivo.append("segmentos " + ", ".join(sorted(comunes)))
    # Las acciones del código se muestran pero no descartan: una regla puede comprobar una
    # acción o fijarla (p. ej. poner IGNORE), y el literal no distingue ambos casos.
    if meta["acciones"]:
        motivo.append("acciones en el código: " + ", ".join(meta["acciones"]))
    return "CANDIDATA", "; ".join(motivo) or "sin filtro de modelo/segmento en el código"


def informe(ruta: Path) -> str:
    raiz = leer_xml(ruta)
    ms = cargar_message_set()
    java = cargar_reglas_java()
    nativas = cargar_reglas_nativas()
    notif = cargar_notificaciones()

    modelo = valor_cabecera(raiz, "MODEL/MODLID")
    clase_msg = valor_cabecera(raiz, "MSGCLASSIFICATION")
    segmentos_msg = [(s.get("TYPE"), s.get("ACTION")) for s in raiz.findall("SEGMENT")]
    tipos = {t for t, _ in segmentos_msg}
    acciones = {a for _, a in segmentos_msg}
    conteo = Counter(t for t, _ in segmentos_msg)

    out = [f"# Reglas del motor para `{ruta.name}`", "",
           "> Generado con `herramientas/motor/reglas_aplicables.py`. No editar a mano.", "",
           f"- Modelo (`MODEL/MODLID`): **{modelo or '-'}** · Clasificación: {clase_msg or '-'} · "
           f"Entidad principal: {valor_cabecera(raiz, 'MAIN_ENTITY_TBL_TYP') or '-'}",
           f"- Motor: {'TPS-UI (mensaje de Workstation)' if clase_msg == 'WEBMSG' else 'TPS-1 (carga de fichero/cola)'}; "
           "message set STREETREF.", ""]

    avisos = []
    if ms.segmentos_duplicados:
        avisos.append("El message set define más de una vez los segmentos: "
                      + ", ".join(sorted(set(ms.segmentos_duplicados)))
                      + ". Aquí se listan las reglas de todas las definiciones; no se sabe cuál aplica el motor.")
    java_candidatas: list[tuple[str, dict]] = []

    def filas_java(reglas, titulo):
        filas = []
        for r in reglas:
            clase = r.clase_java
            nombre = clase.rsplit(".", 1)[-1].strip() if clase else r.nombre
            if clase and clase != clase.rstrip() or (r.parametros and r.parametros[0] != r.parametros[0].strip()):
                avisos.append(f"`{r.parametros[0]!r}` ({titulo}) tiene espacios en el nombre de clase: "
                              "si el motor no los recorta, la regla no se carga.")
            meta = java.get(nombre)
            veredicto, motivo = evaluar_java(nombre, meta, modelo, tipos, acciones)
            if veredicto == "CANDIDATA":
                java_candidatas.append((nombre, meta))
            desc = meta["descripcion"] if meta else ""
            efecto = []
            if meta:
                if meta["modifica_mensaje"]:
                    efecto.append("modifica el mensaje")
                if meta["dml_directo"]:
                    efecto.append("DML directo en BBDD")
                if meta["notificaciones"]:
                    efecto.append("notif. " + ", ".join(map(str, meta["notificaciones"])))
            filas.append(f"| {r.orden} | {r.fase} | `{nombre}` | **{veredicto}** | {motivo} | "
                         f"{desc} | {'; '.join(efecto)} |")
        return filas

    def filas_nativas(reglas):
        filas = []
        for r in reglas:
            n = nativas.get(r.nombre, {})
            filas.append(f"| {r.orden} | {r.fase} | `{r.nombre}` | {' / '.join(p.strip() for p in r.parametros)} | "
                         f"{n.get('descripcion_inferida', '**SIN CATALOGAR**')} | {n.get('confianza', '-')} | "
                         f"{n.get('impacto_en_datos_sinteticos', '-')} |")
        return filas

    cab_java = ["| # | Fase | Regla Java | Veredicto | Motivo | Qué hace | Efecto |", "|---|---|---|---|---|---|---|"]
    cab_nat = ["| # | Fase | Regla nativa | Parámetros | Comportamiento inferido | Confianza | Impacto |",
               "|---|---|---|---|---|---|---|"]

    # 1. Segmento Initial: se ejecuta una vez por mensaje, antes de los segmentos.
    inicial = ms.reglas.get("Initial", [])
    out += ["## 1. Inicio del mensaje (segmento `Initial`)", "",
            "Se ejecutan una vez por mensaje, antes de procesar los segmentos, en este orden.", ""]
    nat = [r for r in inicial if not r.clase_java]
    jav = [r for r in inicial if r.clase_java]
    if nat:
        out += ["### Reglas nativas", ""] + cab_nat + filas_nativas(nat) + [""]
    if jav:
        out += ["### Reglas Java", ""] + cab_java + filas_java(jav, "Initial") + [""]

    # 2. Por segmento del mensaje.
    out += ["## 2. Por segmento del mensaje", "",
            "Fases: " + "; ".join(f"`{k}` = {v}" for k, v in FASES.items()) + ".", ""]
    sin_reglas = []
    for tipo in dict.fromkeys(t for t, _ in segmentos_msg):
        reglas = ms.reglas.get(tipo, [])
        acc = ", ".join(sorted({a for t, a in segmentos_msg if t == tipo}))
        if not reglas:
            sin_reglas.append(f"{tipo} ({conteo[tipo]}× {acc})")
            continue
        out += [f"### `{tipo}` — {conteo[tipo]} segmento(s), acción {acc}", ""]
        nat = [r for r in reglas if not r.clase_java]
        jav = [r for r in reglas if r.clase_java]
        if nat:
            out += cab_nat + filas_nativas(nat) + [""]
        if jav:
            out += cab_java + filas_java(jav, tipo) + [""]
    if sin_reglas:
        out += ["Segmentos del mensaje sin reglas propias en el message set (sólo les afectan las de "
                "`Initial` y `Final`): " + ", ".join(sin_reglas) + ".", ""]

    # 3. Segmento Final.
    final = ms.reglas.get("Final", [])
    out += ["## 3. Final del mensaje (segmento `Final`)", ""]
    nat = [r for r in final if not r.clase_java]
    jav = [r for r in final if r.clase_java]
    if nat:
        out += cab_nat + filas_nativas(nat) + [""]
    if jav:
        out += cab_java + filas_java(jav, "Final") + [""]

    # 4. Notificaciones que pueden lanzar las reglas Java candidatas.
    codigos = sorted({c for _, m in java_candidatas if m for c in m["notificaciones"]})
    if codigos:
        out += ["## 4. Notificaciones que pueden lanzar las reglas Java candidatas", "",
                "La severidad decide si el motor rechaza el mensaje (40 ERROR / 50 FATAL) o sólo avisa.", "",
                "| Código | Severidad | Texto |", "|---|---|---|"]
        for c in codigos:
            n = notif.get(("STRDATA", "JAVARULE", str(c)), {})
            sev = n.get("severidad", "")
            out.append(f"| {c} | {sev} {SEVERIDADES.get(sev, '(no definida)')} | {n.get('texto', '')} |")
        out.append("")

    # 5. Resumen y avisos.
    out += ["## 5. Resumen", "",
            f"- Reglas Java candidatas: {len(java_candidatas)} "
            f"({', '.join(sorted({n for n, _ in java_candidatas})) or '-'}).",
            "- Las reglas nativas con impacto ALTO/MEDIO son las que más probablemente hacen que la BBDD "
            "sintética difiera de la real; confirmar con `plsql/motor/capturar_huella.sql` + "
            "`herramientas/motor/comparar_huella.py`.", ""]
    if avisos:
        out += ["## Avisos", ""] + [f"- {a}" for a in dict.fromkeys(avisos)] + [""]
    return "\n".join(out)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("mensaje", type=Path)
    ap.add_argument("-o", "--salida", type=Path)
    a = ap.parse_args()
    texto = informe(a.mensaje)
    if a.salida:
        a.salida.parent.mkdir(parents=True, exist_ok=True)
        a.salida.write_text(texto, encoding="utf-8")
        print(f"Informe escrito en {a.salida}")
    else:
        print(texto)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
