#!/usr/bin/env python3
"""
probar_reglas.py
================

Pruebas de las reglas del motor replicadas (``reglas_replicadas.py``): cada caso es un
mensaje mínimo y el resultado esperado según el código original de la regla. Ejecutar
antes de subir cambios en las réplicas:

    python3 herramientas/motor/probar_reglas.py
"""

from __future__ import annotations

import sys
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from analizar_mensaje import cargar_modelo  # noqa: E402
from mensaje_motor import MensajeMotor  # noqa: E402
from reglas_replicadas import aplicar_motor  # noqa: E402


def mensaje(modelo_id: str, *segmentos: tuple[str, str, dict]) -> str:
    cuerpo = "".join(
        f'<SEGMENT TYPE="{t}" ACTION="{a}"><{t}>' + "".join(f'<{k} VALUE="{v}"/>' for k, v in c.items()) + f"</{t}></SEGMENT>"
        for t, a, c in segmentos)
    return f'<STREET_REF><HEADER><MODEL><MODLID VALUE="{modelo_id}"/></MODEL></HEADER>{cuerpo}</STREET_REF>'


FIGU = "FinancialInstitutionGeoUnitPrt"
CASOS = [
    ("ValidateCountryRegion: región de país distinto de CA -> IGNORE",
     mensaje("RDRFINSG", (FIGU, "INSERT", {"FINSGUPURPTYP": "STSMNTCT", "GUID": "US"}),
             (FIGU, "INSERT", {"FINSGUPURPTYP": "STSMNTCR", "GUID": "NY"})),
     lambda m: m.segmentos[1].accion == "IGNORE"),
    ("ValidateCountryRegion: región de CA se conserva",
     mensaje("RDRFINSG", (FIGU, "INSERT", {"FINSGUPURPTYP": "STSMNTCT", "GUID": "CA"}),
             (FIGU, "INSERT", {"FINSGUPURPTYP": "STSMNTCR", "GUID": "ON"})),
     lambda m: m.segmentos[1].accion == "INSERT"),
    ("ValidateCountryRegion: otro modelo no se toca",
     mensaje("FINSO", (FIGU, "INSERT", {"FINSGUPURPTYP": "STSMNTCT", "GUID": "US"}),
             (FIGU, "INSERT", {"FINSGUPURPTYP": "STSMNTCR", "GUID": "NY"})),
     lambda m: m.segmentos[1].accion == "INSERT"),
    ("setDifusion: FIST de la lista -> DATA_SRC_ID DIFUSION",
     mensaje("RDRFINSG", ("FinancialInstitutionStatistic", "INSERT", {"STATDEFID": "RRPP", "DATASRCID": "RDR"})),
     lambda m: m.segmentos[0].campo(".DATA_SRC_ID") == "DIFUSION"),
    ("setDifusion: FIST fuera de la lista se conserva",
     mensaje("RDRFINSG", ("FinancialInstitutionStatistic", "INSERT", {"STATDEFID": "UKFIRM", "DATASRCID": "RDR"})),
     lambda m: m.segmentos[0].campo(".DATA_SRC_ID") == "RDR"),
    ("setDifusion: ENFR OPE_BRANCH -> DATA_SRC_ID DIFUSION",
     mensaje("FINSX", ("FINREnterpriseFinancialInstitutionRole", "INSERT", {"ENFRRLTYP": "OPE_BRANCH", "DATASRCID": "RDR"})),
     lambda m: m.segmentos[0].campo(".DATA_SRC_ID") == "DIFUSION"),
    ("generateLagrLaan: FLAR-LPS1 SPECTRAN sin texto -> IGNORE",
     mensaje("LAGR", ("FLAR-LPS1", "INSERT", {"STATDEFID": "SPECTRAN"})),
     lambda m: m.segmentos[0].accion == "IGNORE"),
    ("generateLagrLaan: FLAR-LPS1 con texto se conserva",
     mensaje("LAGR", ("FLAR-LPS1", "INSERT", {"STATDEFID": "SPECTRAN", "STATCHARVALTXT": "X"})),
     lambda m: m.segmentos[0].accion == "INSERT"),
]


def main() -> int:
    modelo = cargar_modelo()
    fallos = 0
    for nombre, xml, comprobar in CASOS:
        m = MensajeMotor(ET.fromstring(xml), modelo)
        aplicar_motor(m)
        ok = comprobar(m)
        fallos += not ok
        print(f"{'OK   ' if ok else 'FALLO'} {nombre}")
    print(f"{len(CASOS) - fallos}/{len(CASOS)} casos correctos")
    return 1 if fallos else 0


if __name__ == "__main__":
    raise SystemExit(main())
