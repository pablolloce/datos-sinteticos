# Mapeo del mensaje `Ejemplo_Alta_Contrapartida_Global.xml`

> Generado con `herramientas/analizar_mensaje.py`. No editar a mano:
> regenerar si cambia el mensaje o el modelo.

## Cabecera

| Campo | Valor |
|---|---|
| MAIN_ENTITY_TBL_TYP | FINS |
| MAIN_ENTITY_NME | PROBANDO |
| MODEL/MODLID | RDRFINSG |
| MSGCLASSIFICATION | WEBMSG |

## Resumen de segmentos (en orden de aparición)

| # | Segmento | Acción | Tabla | Tratamiento |
|---|---|---|---|---|
| 1 | FinancialInstitution | INSERT | FT_T_FINS | INSERT |
| 2 | FinancialInstitutionStatistic | INSERT | FT_T_FIST | INSERT |
| 3 | FinancialInstitutionGeoUnitPrt | INSERT | FT_T_FIGU | INSERT |
| 4 | FinancialInstitutionStatistic | INSERT | FT_T_FIST | INSERT |
| 5 | FinancialInstitution | REFERENCE | FT_T_FINS | Sin insert (referencia a entidad existente) |
| 6 | FINSFinancialLegalNames | OPTIMISTICUPDATE | FINANCIAL_LEGAL_NAMES | INSERT (entidad nueva) |
| 7 | FinancialInstitution | REFERENCE | FT_T_FINS | Sin insert (referencia a entidad existente) |
| 8 | FINSFinancialInstitutionRole | INSERT | FT_T_FINR | INSERT |
| 9 | FINRFinsFinsRoleRelationship | INSERT | FT_T_FIRL | INSERT |
| 10 | FINREnterpriseFinancialInstitutionRole | INSERT | FT_T_ENFR | INSERT |
| 11 | FINREnterpriseFinancialInstitutionRole | INSERT | FT_T_ENFR | INSERT |
| 12 | FinsRoleClassification | INSERT | FT_T_FRCL | INSERT |
| 13 | FinancialInstitution | REFERENCE | FT_T_FINS | Sin insert (referencia a entidad existente) |

## Tablas a insertar (orden de aparición)

FT_T_FINS, FT_T_FIST, FT_T_FIGU, FINANCIAL_LEGAL_NAMES, FT_T_FINR, FT_T_FIRL, FT_T_ENFR, FT_T_FRCL

## Avisos

- Ninguno.

## Detalle por segmento

### #1 FinancialInstitution -> FT_T_FINS (INSERT)

PK: `INST_MNEM`

| Elemento XML | Valor | Columna | Tipo | Nulo | Mapeo |
|---|---|---|---|---|---|
| DATASRCID | `RDR` | DATA_SRC_ID | VARCHAR2(40) | Y | XELM |
| DATASTATTYP | `ACTIVE` | DATA_STAT_TYP | VARCHAR2(20) | Y | XELM |
| INSTDESC | `PROBANDO` | INST_DESC | VARCHAR2(4000) | Y | XELM |
| INSTFOUNDINGDTE | `09-29-2026 12:00:00 AM` | INST_FOUNDING_DTE | DATE | Y | XELM |
| INSTLEGALNME | `PROBANDO` | INST_LEGAL_NME | VARCHAR2(500) | Y | XELM |
| INSTMNEM | `f-uBI7(qW1` | INST_MNEM | CHAR(10) | N | XELM |
| INSTNME | `PROBANDO` | INST_NME | VARCHAR2(500) | N | XELM |
| LASTCHGTMS | `09-29-2026 05:49:55 PM` | LAST_CHG_TMS | DATE | N | XELM |
| LASTCHGUSRID | `T045519` | LAST_CHG_USR_ID | VARCHAR2(256) | N | XELM |
| STARTTMS | `09-29-2026 05:49:20 PM` | START_TMS | DATE | N | XELM |

### #2 FinancialInstitutionStatistic -> FT_T_FIST (INSERT)

PK: `STAT_ID`

| Elemento XML | Valor | Columna | Tipo | Nulo | Mapeo |
|---|---|---|---|---|---|
| DATASRCID | `RDR` | DATA_SRC_ID | VARCHAR2(40) | Y | XELM |
| DATASTATTYP | `ACTIVE` | DATA_STAT_TYP | VARCHAR2(20) | Y | XELM |
| INSTMNEM | `f-uBI7(qW1` | INST_MNEM | CHAR(10) | N | XELM |
| LASTCHGTMS | `09-29-2026 05:49:23 PM` | LAST_CHG_TMS | DATE | N | XELM |
| LASTCHGUSRID | `T045519` | LAST_CHG_USR_ID | VARCHAR2(256) | N | XELM |
| STARTTMS | `09-29-2026 05:49:23 PM` | START_TMS | DATE | N | XELM |
| STATCHARVALTXT | `Y` | STAT_CHAR_VAL_TXT | VARCHAR2(1024) | Y | XELM |
| STATDEFID | `UKFIRM` | STAT_DEF_ID | CHAR(8) | N | XELM |

**NOT NULL no informadas en el mensaje** (generar/resolver en PL/SQL): STAT_ID

FKs sobre columnas informadas: STAT_DEF_ID → FT_T_STDF (ENABLED)

### #3 FinancialInstitutionGeoUnitPrt -> FT_T_FIGU (INSERT)

PK: `FIGU_OID`

| Elemento XML | Valor | Columna | Tipo | Nulo | Mapeo |
|---|---|---|---|---|---|
| DATASRCID | `RDR` | DATA_SRC_ID | VARCHAR2(40) | Y | XELM |
| DATASTATTYP | `ACTIVE` | DATA_STAT_TYP | VARCHAR2(20) | Y | XELM |
| FINSGUPURPTYP | `STSMNTCT` | FINS_GU_PURP_TYP | CHAR(8) | N | XELM |
| GUCNT | `1` | GU_CNT | NUMBER(10) | Y | XELM |
| GUID | `AF` | GU_ID | VARCHAR2(10) | Y | XELM |
| GUNTOID | `GUNT3B2===` | GUNT_OID | CHAR(10) | N | nombre |
| GUTYP | `COUNTRY` | GU_TYP | VARCHAR2(8) | Y | XELM |
| INSTMNEM | `f-uBI7(qW1` | INST_MNEM | CHAR(10) | N | XELM |
| LASTCHGTMS | `09-29-2026 05:49:52 PM` | LAST_CHG_TMS | DATE | N | XELM |
| LASTCHGUSRID | `T045519` | LAST_CHG_USR_ID | VARCHAR2(256) | N | XELM |
| STARTTMS | `09-29-2026 05:49:52 PM` | START_TMS | DATE | N | XELM |

**NOT NULL no informadas en el mensaje** (generar/resolver en PL/SQL): FIGU_OID

FKs sobre columnas informadas: GUNT_OID → FT_T_GUNT (DISABLED)

### #4 FinancialInstitutionStatistic -> FT_T_FIST (INSERT)

PK: `STAT_ID`

| Elemento XML | Valor | Columna | Tipo | Nulo | Mapeo |
|---|---|---|---|---|---|
| DATASRCID | `RDR` | DATA_SRC_ID | VARCHAR2(40) | Y | XELM |
| DATASTATTYP | `ACTIVE` | DATA_STAT_TYP | VARCHAR2(20) | Y | XELM |
| INSTMNEM | `f-uBI7(qW1` | INST_MNEM | CHAR(10) | N | XELM |
| LASTCHGTMS | `09-29-2026 05:49:23 PM` | LAST_CHG_TMS | DATE | N | XELM |
| LASTCHGUSRID | `T045519` | LAST_CHG_USR_ID | VARCHAR2(256) | N | XELM |
| STARTTMS | `09-29-2026 05:49:23 PM` | START_TMS | DATE | N | XELM |
| STATCHARVALTXT | `Y` | STAT_CHAR_VAL_TXT | VARCHAR2(1024) | Y | XELM |
| STATDEFID | `MIFIFIRM` | STAT_DEF_ID | CHAR(8) | N | XELM |

**NOT NULL no informadas en el mensaje** (generar/resolver en PL/SQL): STAT_ID

FKs sobre columnas informadas: STAT_DEF_ID → FT_T_STDF (ENABLED)

### #6 FINSFinancialLegalNames -> FINANCIAL_LEGAL_NAMES (OPTIMISTICUPDATE)

PK: `FLG_OID` · XELM heredado del segmento 3001690

| Elemento XML | Valor | Columna | Tipo | Nulo | Mapeo |
|---|---|---|---|---|---|
| DATASRCID | `ABACO` | DATA_SRC_ID | VARCHAR2(40) | Y | XELM |
| DATASTATTYP | `ACTIVE` | DATA_STAT_TYP | VARCHAR2(20) | Y | XELM |
| FLGLEGALNME | `PROBANDO` | FLG_LEGAL_NME | VARCHAR2(256) | N | XELM |
| FLGOID | `f-uFI7(qW1` | FLG_OID | CHAR(10) | N | XELM |
| INSTMNEM | `f-uBI7(qW1` | INST_MNEM | CHAR(10) | Y | XELM |
| LASTCHGTMS | `09-29-2026 05:49:52 PM` | LAST_CHG_TMS | DATE | N | XELM |
| LASTCHGUSRID | `T045519` | LAST_CHG_USR_ID | VARCHAR2(40) | N | XELM |
| STARTTMS | `09-29-2026 05:49:52 PM` | START_TMS | DATE | N | XELM |

### #8 FINSFinancialInstitutionRole -> FT_T_FINR (INSERT)

PK: `FINR_OID`

| Elemento XML | Valor | Columna | Tipo | Nulo | Mapeo |
|---|---|---|---|---|---|
| DATASRCID | `RDR` | DATA_SRC_ID | VARCHAR2(40) | Y | XELM |
| DATASTATTYP | `ACTIVE` | DATA_STAT_TYP | VARCHAR2(20) | Y | XELM |
| FINROID | `f-uCI7(qW1` | FINR_OID | CHAR(10) | N | nombre |
| FINSRLSUBTYP | `BUSINESS` | FINSRL_SUB_TYP | VARCHAR2(20) | Y | XELM |
| FINSRLTYP | `INDVDUAL` | FINSRL_TYP | CHAR(8) | N | XELM |
| INSTMNEM | `f-uBI7(qW1` | INST_MNEM | CHAR(10) | N | XELM |
| LASTCHGTMS | `09-29-2026 05:49:55 PM` | LAST_CHG_TMS | DATE | N | XELM |
| LASTCHGUSRID | `T045519` | LAST_CHG_USR_ID | VARCHAR2(256) | N | XELM |
| PREFIDCTXTTYP | `Y` | PREF_ID_CTXT_TYP | VARCHAR2(20) | Y | XELM |
| STARTTMS | `09-29-2026 05:49:23 PM` | START_TMS | DATE | N | XELM |

FKs sobre columnas informadas: INST_MNEM → FT_T_FINS (DISABLED)

### #9 FINRFinsFinsRoleRelationship -> FT_T_FIRL (INSERT)

PK: `FIRL_OID`

| Elemento XML | Valor | Columna | Tipo | Nulo | Mapeo |
|---|---|---|---|---|---|
| DATASRCID | `RDR` | DATA_SRC_ID | VARCHAR2(40) | Y | XELM |
| DATASTATTYP | `ACTIVE` | DATA_STAT_TYP | VARCHAR2(20) | Y | XELM |
| FINROID | `f-uCI7(qW1` | FINR_OID | CHAR(10) | N | nombre |
| FINSRLTYP | `INDVDUAL` | FINSRL_TYP | CHAR(8) | Y | XELM |
| INSTMNEM | `f-uBI7(qW1` | INST_MNEM | CHAR(10) | Y | XELM |
| LASTCHGTMS | `09-29-2026 05:49:55 PM` | LAST_CHG_TMS | DATE | N | XELM |
| LASTCHGUSRID | `T045519` | LAST_CHG_USR_ID | VARCHAR2(256) | N | XELM |
| PRNTINSTMNEM | `f-uBI7(qW1` | PRNT_INST_MNEM | CHAR(10) | N | XELM |
| RELTYP | `GLOBAL` | REL_TYP | VARCHAR2(20) | N | XELM |
| STARTTMS | `09-29-2026 05:49:23 PM` | START_TMS | DATE | N | XELM |

**NOT NULL no informadas en el mensaje** (generar/resolver en PL/SQL): FIRL_OID

FKs sobre columnas informadas: FINR_OID → FT_T_FINR (DISABLED); PRNT_INST_MNEM → FT_T_FINS (DISABLED)

### #10 FINREnterpriseFinancialInstitutionRole -> FT_T_ENFR (INSERT)

PK: `ENFR_OID`

| Elemento XML | Valor | Columna | Tipo | Nulo | Mapeo |
|---|---|---|---|---|---|
| DATASRCID | `RDR` | DATA_SRC_ID | VARCHAR2(40) | Y | XELM |
| DATASTATTYP | `ACTIVE` | DATA_STAT_TYP | VARCHAR2(20) | Y | XELM |
| ENFROID | `f-uDI7(qW1` | ENFR_OID | CHAR(10) | N | XELM |
| ENFRRLTYP | `ENT_OWN` | ENFR_RL_TYP | VARCHAR2(20) | Y | XELM |
| FINRINSTMNEM | `f-uBI7(qW1` | FINR_INST_MNEM | CHAR(10) | Y | XELM |
| FINROID | `f-uCI7(qW1` | FINR_OID | CHAR(10) | Y | nombre |
| FINSRLTYP | `INDVDUAL` | FINSRL_TYP | CHAR(8) | Y | XELM |
| LASTCHGTMS | `09-29-2026 05:49:55 PM` | LAST_CHG_TMS | DATE | N | XELM |
| LASTCHGUSRID | `T045519` | LAST_CHG_USR_ID | VARCHAR2(256) | N | XELM |
| ORGID | `0182` | ORG_ID | CHAR(4) | N | XELM |
| STARTTMS | `09-29-2026 05:49:27 PM` | START_TMS | DATE | N | XELM |

FKs sobre columnas informadas: FINR_OID → FT_T_FINR (DISABLED); ORG_ID → FT_T_ENTR (DISABLED)

### #11 FINREnterpriseFinancialInstitutionRole -> FT_T_ENFR (INSERT)

PK: `ENFR_OID`

| Elemento XML | Valor | Columna | Tipo | Nulo | Mapeo |
|---|---|---|---|---|---|
| DATASRCID | `RDR` | DATA_SRC_ID | VARCHAR2(40) | Y | XELM |
| DATASTATTYP | `ACTIVE` | DATA_STAT_TYP | VARCHAR2(20) | Y | XELM |
| ENFROID | `f-uEI7(qW1` | ENFR_OID | CHAR(10) | N | XELM |
| ENFRRLTYP | `BRANCH_OWN` | ENFR_RL_TYP | VARCHAR2(20) | Y | XELM |
| FINRINSTMNEM | `f-uBI7(qW1` | FINR_INST_MNEM | CHAR(10) | Y | XELM |
| FINROID | `f-uCI7(qW1` | FINR_OID | CHAR(10) | Y | nombre |
| FINSRLTYP | `INDVDUAL` | FINSRL_TYP | CHAR(8) | Y | XELM |
| LASTCHGTMS | `09-29-2026 05:49:55 PM` | LAST_CHG_TMS | DATE | N | XELM |
| LASTCHGUSRID | `T045519` | LAST_CHG_USR_ID | VARCHAR2(256) | N | XELM |
| ORGID | `A18` | ORG_ID | CHAR(4) | N | XELM |
| STARTTMS | `09-29-2026 05:49:37 PM` | START_TMS | DATE | N | XELM |

FKs sobre columnas informadas: FINR_OID → FT_T_FINR (DISABLED); ORG_ID → FT_T_ENTR (DISABLED)

### #12 FinsRoleClassification -> FT_T_FRCL (INSERT)

PK: `FINR_CLSF_OID`

| Elemento XML | Valor | Columna | Tipo | Nulo | Mapeo |
|---|---|---|---|---|---|
| CLSFOID | `=002DCDB88` | CLSF_OID | CHAR(10) | N | XELM |
| CLVALUE | `FINANCIAL` | CL_VALUE | VARCHAR2(40) | Y | XELM |
| DATASRCID | `RDR` | DATA_SRC_ID | VARCHAR2(40) | Y | XELM |
| DATASTATTYP | `ACTIVE` | DATA_STAT_TYP | VARCHAR2(20) | Y | XELM |
| FINROID | `f-uCI7(qW1` | FINR_OID | CHAR(10) | N | nombre |
| FINSRLTYP | `INDVDUAL` | FINSRL_TYP | CHAR(8) | Y | XELM |
| INDUSCLSETID | `TPFINF` | INDUS_CL_SET_ID | CHAR(10) | N | XELM |
| INSTMNEM | `f-uBI7(qW1` | INST_MNEM | CHAR(10) | Y | XELM |
| LASTCHGTMS | `09-29-2026 05:49:37 PM` | LAST_CHG_TMS | DATE | N | XELM |
| LASTCHGUSRID | `T045519` | LAST_CHG_USR_ID | VARCHAR2(256) | N | XELM |
| STARTTMS | `09-29-2026 05:49:37 PM` | START_TMS | DATE | N | XELM |

**NOT NULL no informadas en el mensaje** (generar/resolver en PL/SQL): FINR_CLSF_OID

FKs sobre columnas informadas: FINR_OID → FT_T_FINR (DISABLED); CLSF_OID → FT_T_INCL (DISABLED)
