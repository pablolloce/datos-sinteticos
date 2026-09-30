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
from flujo_workstation import _comprobar_global, aplicar_flujo  # noqa: E402


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


def cabecera_fins(xml: str) -> str:
    return xml.replace("<HEADER>", '<HEADER><MAIN_ENTITY_TBL_TYP VALUE="FINS"/>')


FIRL = "FINRFinsFinsRoleRelationship"
GLOBAL = {"INSTMNEM": "X", "RELTYP": "GLOBAL"}
FASE2 = [
    ("CheckDatosRegulatorios: FIGU con país -> CALCULO true",
     mensaje("RDRFINSG", (FIGU, "INSERT", {"GUID": "AF"})),
     lambda m: _comprobar_global(m)[0] is True),
    ("CheckDatosRegulatorios: sin datos regulatorios -> CALCULO false",
     mensaje("RDRFINSG", ("FinancialInstitutionStatistic", "INSERT", {"STATDEFID": "UKFIRM"})),
     lambda m: _comprobar_global(m)[0] is False),
    ("CheckDatosRegulatorios: FinsRoleClassification con CLSFOID -> depende de FT_T_INCL",
     mensaje("RDRFINSG", ("FinsRoleClassification", "INSERT", {"CLSFOID": "=0000001"})),
     lambda m: _comprobar_global(m)[0] is None),
    ("Fase 2: contrapartida LOCAL -> pendiente",
     cabecera_fins(mensaje("RDRFINSG", ("FinancialInstitution", "INSERT", {"INSTMNEM": "X"}),
                           (FIRL, "INSERT", {"INSTMNEM": "X", "RELTYP": "LOCAL"}))),
     lambda m: any(e[0] == "CheckDatosRegulatorios" and e[1] == "PENDIENTE" for e in aplicar_flujo(m))),
    ("Fase 2: sólo ratings -> pendiente (Checks)",
     cabecera_fins(mensaje("RDRFINSG", ("FinancialInstitution", "UPDATE", {"INSTMNEM": "X"}))),
     lambda m: aplicar_flujo(m)[0][:2] == ("Checks", "PENDIENTE")),
    ("Fase 2: entidad no Counterparty -> pendiente",
     mensaje("SSIS", ("StandardSettlementInstructions", "INSERT", {"SSIOID": "X"})),
     lambda m: aplicar_flujo(m)[0][1] == "PENDIENTE"),
]


def main() -> int:
    modelo = cargar_modelo()
    fallos = 0
    for nombre, xml, comprobar in CASOS + FASE2:
        m = MensajeMotor(ET.fromstring(xml), modelo)
        if (nombre, xml, comprobar) in CASOS:
            aplicar_motor(m)
        ok = comprobar(m)
        fallos += not ok
        print(f"{'OK   ' if ok else 'FALLO'} {nombre}")
    print(f"{len(CASOS) + len(FASE2) - fallos}/{len(CASOS) + len(FASE2)} casos correctos")
    return 1 if fallos else 0


if __name__ == "__main__":
    raise SystemExit(main())
