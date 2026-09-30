"""
fuentes_motor.py
================

Acceso a la configuración del motor de GoldenSource sincronizada en ``esquema/motor/``
(``herramientas/motor/sincronizar_fileloading.py`` la genera a partir del repositorio
pablolloce/fileloading, D-029):

    message_set.json     reglas por segmento del message set STREETREF
    reglas_java.json     metadatos de las reglas Java de rdrRules.jar
    reglas_nativas.json  comportamiento inferido de las reglas C++ (CFTI*/CGSC*)
    notificaciones.json  catálogo de notificaciones
"""

from __future__ import annotations

import json
import sys
from dataclasses import dataclass, field
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
MOTOR = RAIZ / "esquema" / "motor"


def _json(nombre: str):
    ruta = MOTOR / nombre
    if not ruta.exists():
        sys.exit(f"No existe {ruta.relative_to(RAIZ)}. Ejecuta antes: "
                 "python3 herramientas/motor/sincronizar_fileloading.py")
    return json.loads(ruta.read_text(encoding="utf-8"))


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


def cargar_message_set() -> MessageSet:
    datos = _json("message_set.json")
    ms = MessageSet(datos["message_set"])
    for bloque in datos["bloques"]:
        tipo = bloque["segmento"]
        if tipo in ms.reglas:
            ms.segmentos_duplicados.append(tipo)
        lista = ms.reglas.setdefault(tipo, [])
        for r in bloque["reglas"]:
            lista.append(Regla(r["regla"], r["fase"], r["parametros"], tipo, len(lista) + 1))
    return ms


def cargar_reglas_java() -> dict:
    return _json("reglas_java.json")["reglas"]


def cargar_reglas_nativas() -> dict[str, dict]:
    """REGLA -> {descripcion_inferida, confianza, impacto_en_datos_sinteticos}."""
    return _json("reglas_nativas.json")


def cargar_notificaciones() -> dict[tuple[str, str, str], dict]:
    """(APPL_ID, PART_ID, NOTFCN_ID) -> {severidad, texto}."""
    return {(n["aplicacion"], n["parte"], n["id"]): {"severidad": n["severidad"], "texto": n["texto"]}
            for n in _json("notificaciones.json")}


SEVERIDADES = {"10": "SUCCESS", "20": "INFO", "30": "WARNING", "40": "ERROR", "50": "FATAL"}
