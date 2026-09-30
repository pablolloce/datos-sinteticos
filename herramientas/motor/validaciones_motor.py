"""
validaciones_motor.py
=====================

Validaciones del motor de GoldenSource que **rechazan** el mensaje (notificación con
severidad 40 ERROR / 50 FATAL). Replicarlas evita crear datos sintéticos que GoldenSource
no aceptaría (D-035). Se comprueban en dos momentos:

1. **Al generar** (``validar_generacion``): con lo que sabe el generador (mensajes, catálogo,
   variaciones y cantidades). Si GoldenSource rechazaría algo, ``generar_plsql.py`` falla,
   muestra el mensaje y **no actualiza** ``plsql/generado/``.
2. **Al ejecutar** (``validaciones_bbdd``): contra los datos que ya hay en la BBDD. Cada
   procedimiento ``crear_<entidad>`` comprueba antes de insertar y, si GoldenSource rechazaría
   el mensaje, falla con ``ge_rechazo_motor`` (-20006) sin crear nada.

Validaciones replicadas:
  - FLG_Uniqueness: nombre legal (FLG_LEGAL_NME) único entre los ACTIVOS (notificación 9001).
Pendientes: Uniqueness (identificadores FRID/FIID/alias, 9001/9002/9003).
"""

from __future__ import annotations

import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from fuentes_motor import SEVERIDADES, cargar_notificaciones  # noqa: E402

SEGMENTOS_NOMBRE_LEGAL = ("FinancialLegalNames", "FINSFinancialLegalNames")


def texto_notificacion(parte: str, codigo: int, parametros: dict[str, str]) -> str:
    """Texto de la notificación de GoldenSource con sus parámetros sustituidos."""
    n = cargar_notificaciones().get(("STRDATA", parte, str(codigo)), {})
    texto = n.get("texto") or f"notificación {codigo}"
    for k, v in parametros.items():
        texto = texto.replace(f"/%{k}%/", v)
    sev = n.get("severidad", "")
    return f"STRDATA/{parte}/{codigo} ({SEVERIDADES.get(sev, sev)}): {texto}"


# ----------------------------------------------------------------------------------------------
# FLG_Uniqueness (FLG_Uniqueness.process): el nombre legal no puede estar ya ACTIVO.
# ----------------------------------------------------------------------------------------------
def _filas_nombre_legal(entidad) -> list:
    """Filas de nombre legal que FLG_Uniqueness valida para esta entidad."""
    modelo = (entidad.modelo_id or "").upper()
    filas = []
    for f in entidad.filas:
        if f.segmento not in SEGMENTOS_NOMBRE_LEGAL:
            continue
        if ((modelo in ("RDRFINSG", "FINSX", "FINSTP") and f.accion == "OPTIMISTICUPDATE")
                or (modelo == "ENTRE" and f.segmento == "FINSFinancialLegalNames")):
            col = next((c for c in f.columnas if c.nombre == "FLG_LEGAL_NME"), None)
            if col:
                filas.append((f, col))
    return filas


def _valor(expresion: str, valores_param: dict) -> str:
    """Valor de una expresión del generador: literal '...' o parámetro p_x."""
    if expresion.startswith("'"):
        return expresion[1:-1].replace("''", "'")
    return str(valores_param.get(expresion.upper(), valores_param.get(expresion, expresion)))


@dataclass
class Llamada:
    entidad: object
    cantidad: int
    valores: dict            # parámetro (P_X) -> valor
    origen: str


def validar_generacion(entidades: list, variaciones: list, identificador) -> list[str]:
    """Errores de validación al generar. Vacío = GoldenSource aceptaría todo."""
    por_nombre = {e.nombre: e for e in entidades}
    llamadas = []
    for e in entidades:
        defectos = {p.nombre: _valor(p.defecto, {}) for p in e.parametros}
        llamadas.append(Llamada(e, 1, defectos, f"crear_bbdd → {e.procedimiento} (mensaje {e.mensaje})"))
    for v in variaciones:
        e = por_nombre.get(identificador(v["entidad"]))
        if not e:
            continue    # emitir_paquete ya informa del error
        valores = {p.nombre: _valor(p.defecto, {}) for p in e.parametros}
        valores.update({identificador(k): str(x) for k, x in (v.get("valores") or {}).items()})
        llamadas.append(Llamada(e, int(v.get("cantidad", 1)), valores,
                                f"variación [{v.get('fecha', '')}] '{v.get('peticion', '')}'"))

    errores: list[str] = []
    vistos: dict[str, str] = {}
    for ll in llamadas:
        for f, col in _filas_nombre_legal(ll.entidad):
            nombre = _valor(col.expresion, ll.valores)
            msg = texto_notificacion("JAVARULE", 9001, {"IdTyp": "Legal Name", "Ident": nombre})
            if ll.cantidad > 1:
                errores.append(f"FLG_Uniqueness — {ll.origen}: se piden {ll.cantidad} entidades con el mismo "
                               f"nombre legal '{nombre}'. GoldenSource rechazaría desde la 2ª: {msg}")
            if nombre in vistos:
                errores.append(f"FLG_Uniqueness — {ll.origen}: el nombre legal '{nombre}' ya lo crea "
                               f"{vistos[nombre]}. GoldenSource rechazaría el mensaje: {msg}")
            vistos.setdefault(nombre, ll.origen)
    return errores


def validaciones_bbdd(entidad) -> list[str]:
    """Bloques PL/SQL que comprueban contra la BBDD, antes de insertar, lo que GoldenSource
    rechazaría. Usan l_existe, p_cantidad y rechazar_si_existe del núcleo."""
    bloques = []
    for f, col in _filas_nombre_legal(entidad):
        expr = col.expresion
        texto = texto_notificacion("JAVARULE", 9001, {"IdTyp": "Legal Name", "Ident": "#N#"})
        antes, despues = texto.split("#N#")
        msg = f"'{antes.replace(chr(39), chr(39) * 2)}' || {expr} || '{despues.replace(chr(39), chr(39) * 2)}'"
        bloques.append(f"""      -- FLG_Uniqueness (segmento #{f.numero} {f.segmento}): el nombre legal no puede estar ya ACTIVO.
      -- Varias entidades en una llamada tendrían el mismo nombre: GoldenSource rechazaría desde la 2ª.
      rechazar_si_existe(CASE WHEN p_cantidad > 1 THEN 1 ELSE 0 END, 'FLG_Uniqueness',
                         {msg} || ' (se piden ' || p_cantidad || ' entidades con el mismo nombre legal)');
      SELECT COUNT(*) INTO l_existe FROM {f.tabla.lower()}
       WHERE flg_legal_nme = {expr}
         AND data_stat_typ = 'ACTIVE';
      rechazar_si_existe(l_existe, 'FLG_Uniqueness', {msg});""")
    return bloques
