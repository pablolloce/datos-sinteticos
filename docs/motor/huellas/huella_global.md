# Huella del motor para `Ejemplo_Alta_Contrapartida_Global.xml`

> Generado con `herramientas/motor/comparar_huella.py` a partir de `huella_global.csv`.

## 1. Resumen por tabla

| Tabla | Filas en el mensaje | Filas en la huella | Diferencia |
|---|---|---|---|
| FINANCIAL_LEGAL_NAMES | 1 | 1 |  |
| FT_T_ENFR | 2 | 2 |  |
| FT_T_FIGU | 1 | 1 |  |
| FT_T_FIID | 0 | 4 | **+4** |
| FT_T_FINR | 1 | 1 |  |
| FT_T_FINS | 1 | 1 |  |
| FT_T_FIRL | 1 | 1 |  |
| FT_T_FIST | 2 | 3 | **+1** |
| FT_T_FRCL | 1 | 1 |  |
| REGISTER_LOG_TABLE | 0 | 1 | **+1** |

## 2. Filas que no vienen del mensaje (creadas o tocadas por el motor)

- **FT_T_FIID** — usuario `T045519`: FIID_OID=`o>t1m(gtW1`, INST_MNEM=`/IsJM7gtW1`, FINS_ID_CTXT_TYP=`FINSID`, FINS_ID=`636020`, DATA_STAT_TYP=`ACTIVE`, GLOBAL_UNIQ_IND=`N`
  - Reglas candidatas: `setDifusion` (Java, Initial), `CFTIInternalIdentifierCreator` (nativa, FinancialInstitution)
- **FT_T_FIID** — usuario `T045519`: FIID_OID=`/IsdM7gtW1`, INST_MNEM=`/IsJM7gtW1`, FINS_ID_CTXT_TYP=`PRELEIID`, FINS_ID=`323233`, DATA_STAT_TYP=`ACTIVE`, DATA_SRC_ID=`RDR`, INST_USAGE_TYP=`/IseM7gtW1`, GLOBAL_UNIQ_IND=`N`
  - Reglas candidatas: `setDifusion` (Java, Initial), `CFTIInternalIdentifierCreator` (nativa, FinancialInstitution)
- **FT_T_FIID** — usuario `T045519`: FIID_OID=`/IsfM7gtW1`, INST_MNEM=`/IsJM7gtW1`, FINS_ID_CTXT_TYP=`CSBCODE`, FINS_ID=`3333`, DATA_STAT_TYP=`ACTIVE`, DATA_SRC_ID=`RDR`, INST_USAGE_TYP=`/IsgM7gtW1`, GLOBAL_UNIQ_IND=`N`
  - Reglas candidatas: `setDifusion` (Java, Initial), `CFTIInternalIdentifierCreator` (nativa, FinancialInstitution)
- **FT_T_FIID** — usuario `T045519`: FIID_OID=`/IshM7gtW1`, INST_MNEM=`/IsJM7gtW1`, FINS_ID_CTXT_TYP=`MARKITID`, FINS_ID=`4343443`, DATA_STAT_TYP=`ACTIVE`, DATA_SRC_ID=`RDR`, INST_USAGE_TYP=`/IsiM7gtW1`, GLOBAL_UNIQ_IND=`N`
  - Reglas candidatas: `setDifusion` (Java, Initial), `CFTIInternalIdentifierCreator` (nativa, FinancialInstitution)
- **FT_T_FIST** — usuario `T045519`: STAT_ID=`o>t4m(gtW1`, STAT_DEF_ID=`NFCSECCA`, INST_MNEM=`/IsJM7gtW1`, STAT_CHAR_VAL_TXT=`N`, DATA_STAT_TYP=`ACTIVE`, DATA_SRC_ID=`RDR`
  - Reglas candidatas: `setDifusion` (Java, Initial), `FLG_Uniqueness` (Java, FINSFinancialLegalNames)
- **REGISTER_LOG_TABLE** — usuario `CONTROLDR`: RLT_OID=`=105D74B8E`, RECORD_SEQ_NUM=`1`, MESSAGE_RLT=`Control del calculo de datos regulatorios`, RLT_PURP_TYP=`CONTROLDR`, DATA_SRC_APP=`CALCULODR`, SRC_FIELD=`CALCULO`, SRC_VALUE=`true`, GS_FIELD=`REL_TYP`, GS_VALUE=`GLOBAL`, MAIN_ENTITY_NME=`FT_T_FIID.INST_MNEM`, MAIN_ENTITY_ID=`/IsJM7gtW1`
  - Reglas candidatas: ninguna identificada (revisar reglas de Initial/Final y del segmento padre)

## 3. Columnas que el motor cambió o rellenó en las filas del mensaje

- Segmento 6 `FINSFinancialLegalNames` (OPTIMISTICUPDATE) → FINANCIAL_LEGAL_NAMES
  - `FLG_LEGAL_NME`: mensaje `PROBANDO` → BBDD `TSSTTST`
  - `FLG_OID`: mensaje `f-uFI7(qW1` → BBDD `/IsNM7gtW1`
  - `INST_MNEM`: mensaje `f-uBI7(qW1` → BBDD `/IsJM7gtW1`
- Segmento 10 `FINREnterpriseFinancialInstitutionRole` (INSERT) → FT_T_ENFR
  - `ENFR_OID`: mensaje `f-uDI7(qW1` → BBDD `/IsLM7gtW1`
  - `FINR_INST_MNEM`: mensaje `f-uBI7(qW1` → BBDD `/IsJM7gtW1`
  - `FINR_OID`: mensaje `f-uCI7(qW1` → BBDD `/IsKM7gtW1`
  - `INST_MNEM`: mensaje `∅` → BBDD `/IsJM7gtW1`
- Segmento 11 `FINREnterpriseFinancialInstitutionRole` (INSERT) → FT_T_ENFR
  - `ENFR_OID`: mensaje `f-uEI7(qW1` → BBDD `/IsMM7gtW1`
  - `FINR_INST_MNEM`: mensaje `f-uBI7(qW1` → BBDD `/IsJM7gtW1`
  - `FINR_OID`: mensaje `f-uCI7(qW1` → BBDD `/IsKM7gtW1`
  - `INST_MNEM`: mensaje `∅` → BBDD `/IsJM7gtW1`
  - `ORG_ID`: mensaje `A18` → BBDD `A1`
- Segmento 3 `FinancialInstitutionGeoUnitPrt` (INSERT) → FT_T_FIGU
  - `FIGU_OID`: mensaje `∅` → BBDD `o>t3m(gtW1`
  - `GUNT_OID`: mensaje `GUNT3B2===` → BBDD `GUNT436===`
  - `GU_ID`: mensaje `AF` → BBDD `ES`
  - `INST_MNEM`: mensaje `f-uBI7(qW1` → BBDD `/IsJM7gtW1`
- Segmento 8 `FINSFinancialInstitutionRole` (INSERT) → FT_T_FINR
  - `CROSS_REF_ID`: mensaje `∅` → BBDD `o>t6m(gtW1`
  - `FINR_OID`: mensaje `f-uCI7(qW1` → BBDD `/IsKM7gtW1`
  - `INST_MNEM`: mensaje `f-uBI7(qW1` → BBDD `/IsJM7gtW1`
- Segmento 1 `FinancialInstitution` (INSERT) → FT_T_FINS
  - `INST_DESC`: mensaje `PROBANDO` → BBDD `TSSTTST`
  - `INST_FOUNDING_DTE`: mensaje `2026-09-29 00:00:00` → BBDD `2026-10-01 00:00:00`
  - `INST_LEGAL_NME`: mensaje `PROBANDO` → BBDD `TSSTTST`
  - `INST_MNEM`: mensaje `f-uBI7(qW1` → BBDD `/IsJM7gtW1`
  - `INST_NME`: mensaje `PROBANDO` → BBDD `TSSTTST`
  - `PREF_FINS_ID`: mensaje `∅` → BBDD `3333`
  - `PREF_FINS_ID_CTXT_TYP`: mensaje `∅` → BBDD `CSBCODE`
- Segmento 9 `FINRFinsFinsRoleRelationship` (INSERT) → FT_T_FIRL
  - `FINR_OID`: mensaje `f-uCI7(qW1` → BBDD `/IsKM7gtW1`
  - `FIRL_OID`: mensaje `∅` → BBDD `o>t7m(gtW1`
  - `INST_MNEM`: mensaje `f-uBI7(qW1` → BBDD `/IsJM7gtW1`
  - `PRNT_INST_MNEM`: mensaje `f-uBI7(qW1` → BBDD `/IsJM7gtW1`
- Segmento 2 `FinancialInstitutionStatistic` (INSERT) → FT_T_FIST
  - `INST_MNEM`: mensaje `f-uBI7(qW1` → BBDD `/IsJM7gtW1`
  - `STAT_ID`: mensaje `∅` → BBDD `o>t2m(gtW1`
- Segmento 4 `FinancialInstitutionStatistic` (INSERT) → FT_T_FIST
  - `INST_MNEM`: mensaje `f-uBI7(qW1` → BBDD `/IsJM7gtW1`
  - `STAT_ID`: mensaje `∅` → BBDD `o>t5m(gtW1`
- Segmento 12 `FinsRoleClassification` (INSERT) → FT_T_FRCL
  - `FINR_CLSF_OID`: mensaje `∅` → BBDD `o>t8m(gtW1`
  - `FINR_OID`: mensaje `f-uCI7(qW1` → BBDD `/IsKM7gtW1`
  - `INST_MNEM`: mensaje `f-uBI7(qW1` → BBDD `/IsJM7gtW1`

## 4. Segmentos del mensaje sin fila en la huella

- Segmento 5 `FinancialInstitution` (REFERENCE): acción REFERENCE
- Segmento 7 `FinancialInstitution` (REFERENCE): acción REFERENCE
- Segmento 13 `FinancialInstitution` (REFERENCE): acción REFERENCE

## 5. Notificaciones de la transacción (FT_T_NTEL)

Ninguna (o no se capturó la transacción).

## 6. Transacciones del motor en la ventana

| TRN_ID | Tipo de mensaje | Severidad | Estado |
|---|---|---|---|
| 00AihCUXS414i003 | SD | 10 | CLOSED |
| 00AihMyXS414i002 |  | 0 | CLOSED |
