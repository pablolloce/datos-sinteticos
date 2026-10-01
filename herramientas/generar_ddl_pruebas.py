#!/usr/bin/env python3
"""
generar_ddl_pruebas.py
======================

Genera un script SQL con la estructura (CREATE TABLE + PK + FK activas) de las tablas
indicadas, a partir de ``esquema/modelo/modelo.json``. Sirve para montar una BBDD
Oracle LOCAL de pruebas (p. ej. contenedor ``gvenzl/oracle-free``) donde compilar y
ejecutar el generador sin tocar la BBDD real.

NO se ejecuta nunca contra KYTL_GC real: sólo contra un entorno desechable.

Incluye además:
  - stubs de la función NEW_OID y del procedimiento GET_IDENTIFIER_ID (en la BBDD real
    existen los de GoldenSource),
  - opcionalmente, datos de referencia mínimos (``--referencias``) para los lookups.

Uso:
    python3 herramientas/generar_ddl_pruebas.py FT_T_FINS FT_T_FINR ... > entorno_local.sql
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
MODELO = RAIZ / "esquema" / "modelo" / "modelo.json"

STUB_NEW_OID = """
-- Stub local de NEW_OID: 10 caracteres únicos (en KYTL_GC existe la función real).
CREATE SEQUENCE sq_stub_new_oid;
CREATE OR REPLACE FUNCTION new_oid RETURN VARCHAR2 IS
BEGIN
   RETURN 'SY' || LPAD(TO_CHAR(sq_stub_new_oid.NEXTVAL), 8, '0');
END;
/

-- Stub local de GET_IDENTIFIER_ID (D-041): en KYTL_GC es el procedimiento real, con las
-- secuencias INTERNAL_ISS_ID_SEQ (tableId = 'ISID') e INTERNAL_FINS_ID_SEQ (el resto).
CREATE SEQUENCE internal_fins_id_seq START WITH 900000;
CREATE SEQUENCE internal_iss_id_seq;
CREATE OR REPLACE PROCEDURE get_identifier_id (tableId IN VARCHAR2, seqId OUT VARCHAR2) AS
BEGIN
   IF tableId = 'ISID' THEN
      SELECT internal_iss_id_seq.NEXTVAL INTO seqId FROM dual;
   ELSE
      SELECT internal_fins_id_seq.NEXTVAL INTO seqId FROM dual;
   END IF;
END get_identifier_id;
/
"""


def tipo(c: list) -> str:
    _n, t, longitud, precision, escala, _nulo, _def = c
    if t in ("CHAR", "VARCHAR2", "NCHAR", "NVARCHAR2", "RAW"):
        return f"{t}({longitud})"
    if t == "NUMBER":
        if precision is None:
            return "NUMBER"
        return f"NUMBER({precision},{escala or 0})"
    return t


def ddl_tabla(nombre: str, t: dict, tablas_incluidas: set) -> str:
    cols = ",\n".join(f"   {c[0]:<30} {tipo(c)}{'' if c[5] == 'Y' else ' NOT NULL'}" for c in t["columnas"])
    partes = [f"CREATE TABLE {nombre} (\n{cols}"]
    if t["pk"]:
        partes.append(f",\n   CONSTRAINT {nombre[:120]}_PK PRIMARY KEY ({', '.join(t['pk'])})")
    sql = "".join(partes) + "\n);\n"
    for fk in t["fk"]:
        if fk["estado"] == "ENABLED" and fk["tabla_ref"] in tablas_incluidas:
            sql += (f"ALTER TABLE {nombre} ADD CONSTRAINT {fk['nombre']} FOREIGN KEY "
                    f"({', '.join(fk['columnas'])}) REFERENCES {fk['tabla_ref']} "
                    f"({', '.join(fk['columnas_ref'])});\n")
    return sql


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("tablas", nargs="+", help="Tablas físicas a crear (en orden de dependencias)")
    args = p.parse_args()

    modelo = json.loads(MODELO.read_text(encoding="utf-8"))
    incluidas = {t.upper() for t in args.tablas}
    print("-- Generado con herramientas/generar_ddl_pruebas.py. SOLO PARA ENTORNO LOCAL DE PRUEBAS.")
    print("WHENEVER SQLERROR EXIT SQL.SQLCODE")
    for nombre in args.tablas:
        nombre = nombre.upper()
        t = modelo["tablas"].get(nombre)
        if not t:
            print(f"Tabla {nombre} no encontrada en el modelo", file=sys.stderr)
            return 1
        print(ddl_tabla(nombre, t, incluidas))
    print(STUB_NEW_OID)
    return 0


if __name__ == "__main__":
    sys.exit(main())
