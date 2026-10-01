# Reglas del motor: comportamiento confirmado

Aquí sólo entra lo **observado** en una captura de huella (`plsql/motor/capturar_huella.sql` +
`herramientas/motor/comparar_huella.py`) o leído en el código de `rdrRules.jar`. Lo inferido
por nombre vive en `fileloading/analisis/reglas_nativas.csv` y no se implementa.

Plantilla:

```
### <RULE_NME> (<segmento>, fase <B|A|F|D>, parámetros)
- Fuente: huella <fichero> (fecha, entorno) | código <Clase.java:línea>
- Mensaje: <Mensaje>.xml
- Efecto observado: tablas/filas/columnas que crea o cambia, con valores.
- Condiciones: cuándo actúa y cuándo no.
- Replicación: cómo se implementa (generador | núcleo PL/SQL) → D-xxx
```

---

Huella de referencia: `huellas/huella_global.csv` (2026-10-01, entorno poco usado, 4 altas de
contrapartida GLOBAL desde la Workstation; informe filtrado a una de ellas en
`docs/motor/huellas/huella_global.md`). Diagnóstico complementario en el entorno habitual:
`plsql/motor/diagnostico_finsid.sql` (2026-10-01).

### CFTIInternalIdentifierCreator (FinancialInstitution, fase F, param `FINSID`)
- Fuente: huella `huella_global.csv` (4 altas) + `diagnostico_finsid.sql` (últimos FINSID y código de
  `GET_IDENTIFIER_ID`).
- Mensaje: `Ejemplo_Alta_Contrapartida_Global.xml` (y altas equivalentes de otros usuarios).
- Efecto observado: en el alta crea una fila `FT_T_FIID` con `FINS_ID_CTXT_TYP = 'FINSID'`,
  `FINS_ID` = `GET_IDENTIFIER_ID('FINS')` (procedimiento de KYTL_GC: `INTERNAL_FINS_ID_SEQ.NEXTVAL`;
  `INTERNAL_ISS_ID_SEQ` si el parámetro es `'ISID'`), `DATA_STAT_TYP = 'ACTIVE'`,
  `GLOBAL_UNIQ_IND = 'N'`, sin `DATA_SRC_ID`, `START_TMS = LAST_CHG_TMS` = momento del guardado,
  `LAST_CHG_USR_ID` = usuario del guardado (o `DIFUSION` si después la difunde otro proceso).
- Condiciones: sólo si la entidad no tiene ya un FIID `FINSID`.
- Replicación: generador → segmento `FinancialInstitutionIdentifier` con el marcador
  `{{SECUENCIA:FINS:<INST_MNEM>}}`, que se traduce a `get_identifier_id('FINS', ...)` una vez por
  entidad (D-041).

### CFTIConstrPrefId (Final, params `FinancialInstitution`, `PREF_FINS_ID_CTXT_TYP`, `PREF_FINS_ID`, lista)
- Fuente: huella `huella_global.csv` + `diagnostico_finsid.sql` (apartado 1).
- Efecto observado: rellena el identificador preferente de `FT_T_FINS`. Con sólo el FINSID interno:
  `PREF_FINS_ID_CTXT_TYP = 'FINSID'`, `PREF_FINS_ID` = el FINSID. Con identificadores tecleados en la
  Workstation elige uno de ellos (CSBCODE frente a PRELEIID/MARKITID; BDIID frente a CODTESID/MGCGLOID),
  que no están en la lista de prioridad del parámetro.
- Replicación: sólo el caso sin identificadores en el mensaje (D-041); con identificadores queda
  PENDIENTE_HUELLA (falta saber la prioridad).

### Núcleo del motor (no es una regla del message set)
- Fuente: huella `huella_global.csv` (las 4 altas).
- Efecto observado: `FT_T_ENFR.INST_MNEM` = `FINR_INST_MNEM` aunque el mensaje no lo traiga;
  `FT_T_FINR.CROSS_REF_ID` = OID nuevo (ninguna otra fila capturada lo referencia).
- Replicación: `efectos_nucleo` en `herramientas/motor/reglas_replicadas.py` (D-041); el OID nuevo
  con el marcador `{{OID:...}}`.

### Observado y no replicado
- Shortname: 3 s después del guardado hay una transacción `FRID` con `MAIN_ENTITY_ID = 'No Existe Legal
  Name'` (`SHT-<INST_MNEM>`) y no se crea nada en el entorno de la huella; en el entorno habitual sí
  existe un FIID `SHORTNAME_MEX` (`<FINSID><3 letras del nombre>`) → P-023.
- Sin relación con el alta (mismo bloque o procesos en curso): `FT_T_COMC`, `FT_T_WSUS`,
  `REGISTER_LOG_TABLE` de `GESTION_ALERTAS` (proceso nocturno), una FINS del día anterior.
