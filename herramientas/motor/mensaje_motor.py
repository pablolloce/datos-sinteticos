"""
mensaje_motor.py
================

Vista de un mensaje STREET_REF tal como lo ven las reglas del motor de GoldenSource:
segmentos con tipo y acción, y campos por **nombre de columna** (``.DATA_SRC_ID``,
``.GU_ID``...), que es como los leen y escriben las reglas Java (``XMLMessage``). Traduce
columna <-> etiqueta XML con XELM (``modelo.json``), igual que el generador.

Los cambios se hacen sobre el árbol XML del mensaje, así que el resto del generador los
recoge sin saber que existen las reglas.
"""

from __future__ import annotations

import xml.etree.ElementTree as ET
from dataclasses import dataclass, field


@dataclass
class Cambio:
    regla: str
    segmento: int            # nº de segmento en el mensaje (1..n); 0 = mensaje entero
    descripcion: str


class Segmento:
    def __init__(self, numero: int, nodo: ET.Element, modelo: dict):
        self.numero = numero
        self.nodo = nodo
        self.tipo = nodo.get("TYPE")
        info = modelo["segmentos"].get(self.tipo) or {}
        self.tabla = info.get("tabla")
        self._xelm = info.get("xelm", {})                     # etiqueta -> columna
        self._tag_de = {c: t for t, c in self._xelm.items()}  # columna -> etiqueta
        cuerpo = nodo.find(self.tipo)
        self.cuerpo = cuerpo if cuerpo is not None else nodo

    # -- acción --------------------------------------------------------------------------
    @property
    def accion(self) -> str:
        return (self.nodo.get("ACTION") or "UNKNOWN").upper()

    @accion.setter
    def accion(self, valor: str) -> None:
        self.nodo.set("ACTION", valor)

    # -- campos por columna ----------------------------------------------------------------
    def _etiqueta(self, columna: str) -> str:
        columna = columna.lstrip(".")
        return self._tag_de.get(columna, columna.replace("_", ""))

    def _elemento(self, columna: str) -> ET.Element | None:
        return self.cuerpo.find(self._etiqueta(columna))

    def campo(self, columna: str) -> str | None:
        """Valor de la columna o None si el mensaje no la trae (como getStringField)."""
        el = self._elemento(columna)
        return el.get("VALUE") if el is not None else None

    def fijar(self, columna: str, valor: str) -> None:
        """setFieldValue / addField: cambia el valor o añade el elemento si no existe."""
        el = self._elemento(columna)
        if el is None:
            el = ET.SubElement(self.cuerpo, self._etiqueta(columna))
        el.set("VALUE", valor)


@dataclass
class MensajeMotor:
    raiz: ET.Element
    modelo: dict
    segmentos: list = field(default_factory=list)
    cambios: list = field(default_factory=list)

    def __post_init__(self):
        self.segmentos = [Segmento(n, s, self.modelo) for n, s in enumerate(self.raiz.findall("SEGMENT"), start=1)]

    def cabecera(self, ruta: str) -> str | None:
        nodo = self.raiz.find(f"HEADER/{ruta}")
        return nodo.get("VALUE") if nodo is not None else None

    @property
    def modelo_id(self) -> str:
        """MODL_ID del mensaje (las reglas Java lo leen de .MODL_ID del segmento 0)."""
        return self.cabecera("MODEL/MODLID") or ""

    def de_tipo(self, *tipos: str) -> list:
        return [s for s in self.segmentos if s.tipo in tipos]

    def anotar(self, regla: str, segmento: Segmento | None, descripcion: str) -> None:
        self.cambios.append(Cambio(regla, segmento.numero if segmento else 0, descripcion))
