# Mapeo del mensaje `Ejemplo_Alta_Contrapartida_Global.xml`

> Generado con `herramientas/analizar_mensaje.py`. No editar a mano:
> regenerar si cambia el mensaje o los esquemas.

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
| 5 | FinancialInstitution | REFERENCE | FT_T_FINS | Sin insert (referencia a entidad ya creada en el mismo mensaje) |
| 6 | FINSFinancialLegalNames | OPTIMISTICUPDATE | FT_T_FLG1 | INSERT si no existe (pendiente de confirmar, ver DECISIONES.md) |
| 7 | FinancialInstitution | REFERENCE | FT_T_FINS | Sin insert (referencia a entidad ya creada en el mismo mensaje) |
| 8 | FINSFinancialInstitutionRole | INSERT | FT_T_FINR | INSERT |
| 9 | FINRFinsFinsRoleRelationship | INSERT | FT_T_FIRL | INSERT |
| 10 | FINREnterpriseFinancialInstitutionRole | INSERT | FT_T_ENFR | INSERT |
| 11 | FINREnterpriseFinancialInstitutionRole | INSERT | FT_T_ENFR | INSERT |
| 12 | FinsRoleClassification | INSERT | FT_T_FRCL | INSERT |
| 13 | FinancialInstitution | REFERENCE | FT_T_FINS | Sin insert (referencia a entidad ya creada en el mismo mensaje) |

## Avisos

- Segmento #3 `FinancialInstitutionGeoUnitPrt`: elemento `GUNTOID` sin columna en XELM.
- Segmento #6 `FINSFinancialLegalNames` (FT_T_FLG1, SEGMENT_ID 99991901): sin elementos en XELM; no se pueden mapear columnas.
- Segmento #8 `FINSFinancialInstitutionRole`: elemento `FINROID` sin columna en XELM.
- Segmento #9 `FINRFinsFinsRoleRelationship`: elemento `FINROID` sin columna en XELM.
- Segmento #10 `FINREnterpriseFinancialInstitutionRole`: elemento `FINROID` sin columna en XELM.
- Segmento #11 `FINREnterpriseFinancialInstitutionRole`: elemento `FINROID` sin columna en XELM.
- Segmento #12 `FinsRoleClassification`: elemento `FINROID` sin columna en XELM.

## Detalle por segmento

### #1 FinancialInstitution -> FT_T_FINS (INSERT)

| Elemento XML | Valor | Columna |
|---|---|---|
| DATASRCID | `RDR` | DATA_SRC_ID |
| DATASTATTYP | `ACTIVE` | DATA_STAT_TYP |
| INSTDESC | `PROBANDO` | INST_DESC |
| INSTFOUNDINGDTE | `09-29-2026 12:00:00 AM` | INST_FOUNDING_DTE |
| INSTLEGALNME | `PROBANDO` | INST_LEGAL_NME |
| INSTMNEM | `f-uBI7(qW1` | INST_MNEM |
| INSTNME | `PROBANDO` | INST_NME |
| LASTCHGTMS | `09-29-2026 05:49:55 PM` | LAST_CHG_TMS |
| LASTCHGUSRID | `T045519` | LAST_CHG_USR_ID |
| STARTTMS | `09-29-2026 05:49:20 PM` | START_TMS |

Columnas OID de XELM no presentes en el mensaje (posible clave generada por el motor): OBLIGOR_SUBGRP_CLSF_OID, FILF_OID

### #2 FinancialInstitutionStatistic -> FT_T_FIST (INSERT)

| Elemento XML | Valor | Columna |
|---|---|---|
| DATASRCID | `RDR` | DATA_SRC_ID |
| DATASTATTYP | `ACTIVE` | DATA_STAT_TYP |
| INSTMNEM | `f-uBI7(qW1` | INST_MNEM |
| LASTCHGTMS | `09-29-2026 05:49:23 PM` | LAST_CHG_TMS |
| LASTCHGUSRID | `T045519` | LAST_CHG_USR_ID |
| STARTTMS | `09-29-2026 05:49:23 PM` | START_TMS |
| STATCHARVALTXT | `Y` | STAT_CHAR_VAL_TXT |
| STATDEFID | `UKFIRM` | STAT_DEF_ID |

### #3 FinancialInstitutionGeoUnitPrt -> FT_T_FIGU (INSERT)

| Elemento XML | Valor | Columna |
|---|---|---|
| DATASRCID | `RDR` | DATA_SRC_ID |
| DATASTATTYP | `ACTIVE` | DATA_STAT_TYP |
| FINSGUPURPTYP | `STSMNTCT` | FINS_GU_PURP_TYP |
| GUCNT | `1` | GU_CNT |
| GUID | `AF` | GU_ID |
| GUNTOID | `GUNT3B2===` | **¿?** |
| GUTYP | `COUNTRY` | GU_TYP |
| INSTMNEM | `f-uBI7(qW1` | INST_MNEM |
| LASTCHGTMS | `09-29-2026 05:49:52 PM` | LAST_CHG_TMS |
| LASTCHGUSRID | `T045519` | LAST_CHG_USR_ID |
| STARTTMS | `09-29-2026 05:49:52 PM` | START_TMS |

Columnas OID de XELM no presentes en el mensaje (posible clave generada por el motor): FIGU_OID

### #4 FinancialInstitutionStatistic -> FT_T_FIST (INSERT)

| Elemento XML | Valor | Columna |
|---|---|---|
| DATASRCID | `RDR` | DATA_SRC_ID |
| DATASTATTYP | `ACTIVE` | DATA_STAT_TYP |
| INSTMNEM | `f-uBI7(qW1` | INST_MNEM |
| LASTCHGTMS | `09-29-2026 05:49:23 PM` | LAST_CHG_TMS |
| LASTCHGUSRID | `T045519` | LAST_CHG_USR_ID |
| STARTTMS | `09-29-2026 05:49:23 PM` | START_TMS |
| STATCHARVALTXT | `Y` | STAT_CHAR_VAL_TXT |
| STATDEFID | `MIFIFIRM` | STAT_DEF_ID |

### #6 FINSFinancialLegalNames -> FT_T_FLG1 (OPTIMISTICUPDATE)

| Elemento XML | Valor | Columna |
|---|---|---|
| DATASRCID | `ABACO` | **¿?** |
| DATASTATTYP | `ACTIVE` | **¿?** |
| FLGLEGALNME | `PROBANDO` | **¿?** |
| FLGOID | `f-uFI7(qW1` | **¿?** |
| INSTMNEM | `f-uBI7(qW1` | **¿?** |
| LASTCHGTMS | `09-29-2026 05:49:52 PM` | **¿?** |
| LASTCHGUSRID | `T045519` | **¿?** |
| STARTTMS | `09-29-2026 05:49:52 PM` | **¿?** |

### #8 FINSFinancialInstitutionRole -> FT_T_FINR (INSERT)

| Elemento XML | Valor | Columna |
|---|---|---|
| DATASRCID | `RDR` | DATA_SRC_ID |
| DATASTATTYP | `ACTIVE` | DATA_STAT_TYP |
| FINROID | `f-uCI7(qW1` | **¿?** |
| FINSRLSUBTYP | `BUSINESS` | FINSRL_SUB_TYP |
| FINSRLTYP | `INDVDUAL` | FINSRL_TYP |
| INSTMNEM | `f-uBI7(qW1` | INST_MNEM |
| LASTCHGTMS | `09-29-2026 05:49:55 PM` | LAST_CHG_TMS |
| LASTCHGUSRID | `T045519` | LAST_CHG_USR_ID |
| PREFIDCTXTTYP | `Y` | PREF_ID_CTXT_TYP |
| STARTTMS | `09-29-2026 05:49:23 PM` | START_TMS |

Columnas OID de XELM no presentes en el mensaje (posible clave generada por el motor): CONTCT_OID

### #9 FINRFinsFinsRoleRelationship -> FT_T_FIRL (INSERT)

| Elemento XML | Valor | Columna |
|---|---|---|
| DATASRCID | `RDR` | DATA_SRC_ID |
| DATASTATTYP | `ACTIVE` | DATA_STAT_TYP |
| FINROID | `f-uCI7(qW1` | **¿?** |
| FINSRLTYP | `INDVDUAL` | FINSRL_TYP |
| INSTMNEM | `f-uBI7(qW1` | INST_MNEM |
| LASTCHGTMS | `09-29-2026 05:49:55 PM` | LAST_CHG_TMS |
| LASTCHGUSRID | `T045519` | LAST_CHG_USR_ID |
| PRNTINSTMNEM | `f-uBI7(qW1` | PRNT_INST_MNEM |
| RELTYP | `GLOBAL` | REL_TYP |
| STARTTMS | `09-29-2026 05:49:23 PM` | START_TMS |

Columnas OID de XELM no presentes en el mensaje (posible clave generada por el motor): FIRL_OID

### #10 FINREnterpriseFinancialInstitutionRole -> FT_T_ENFR (INSERT)

| Elemento XML | Valor | Columna |
|---|---|---|
| DATASRCID | `RDR` | DATA_SRC_ID |
| DATASTATTYP | `ACTIVE` | DATA_STAT_TYP |
| ENFROID | `f-uDI7(qW1` | ENFR_OID |
| ENFRRLTYP | `ENT_OWN` | ENFR_RL_TYP |
| FINRINSTMNEM | `f-uBI7(qW1` | FINR_INST_MNEM |
| FINROID | `f-uCI7(qW1` | **¿?** |
| FINSRLTYP | `INDVDUAL` | FINSRL_TYP |
| LASTCHGTMS | `09-29-2026 05:49:55 PM` | LAST_CHG_TMS |
| LASTCHGUSRID | `T045519` | LAST_CHG_USR_ID |
| ORGID | `0182` | ORG_ID |
| STARTTMS | `09-29-2026 05:49:27 PM` | START_TMS |

Columnas OID de XELM no presentes en el mensaje (posible clave generada por el motor): MKT_OID

### #11 FINREnterpriseFinancialInstitutionRole -> FT_T_ENFR (INSERT)

| Elemento XML | Valor | Columna |
|---|---|---|
| DATASRCID | `RDR` | DATA_SRC_ID |
| DATASTATTYP | `ACTIVE` | DATA_STAT_TYP |
| ENFROID | `f-uEI7(qW1` | ENFR_OID |
| ENFRRLTYP | `BRANCH_OWN` | ENFR_RL_TYP |
| FINRINSTMNEM | `f-uBI7(qW1` | FINR_INST_MNEM |
| FINROID | `f-uCI7(qW1` | **¿?** |
| FINSRLTYP | `INDVDUAL` | FINSRL_TYP |
| LASTCHGTMS | `09-29-2026 05:49:55 PM` | LAST_CHG_TMS |
| LASTCHGUSRID | `T045519` | LAST_CHG_USR_ID |
| ORGID | `A18` | ORG_ID |
| STARTTMS | `09-29-2026 05:49:37 PM` | START_TMS |

Columnas OID de XELM no presentes en el mensaje (posible clave generada por el motor): MKT_OID

### #12 FinsRoleClassification -> FT_T_FRCL (INSERT)

| Elemento XML | Valor | Columna |
|---|---|---|
| CLSFOID | `=002DCDB88` | CLSF_OID |
| CLVALUE | `FINANCIAL` | CL_VALUE |
| DATASRCID | `RDR` | DATA_SRC_ID |
| DATASTATTYP | `ACTIVE` | DATA_STAT_TYP |
| FINROID | `f-uCI7(qW1` | **¿?** |
| FINSRLTYP | `INDVDUAL` | FINSRL_TYP |
| INDUSCLSETID | `TPFINF` | INDUS_CL_SET_ID |
| INSTMNEM | `f-uBI7(qW1` | INST_MNEM |
| LASTCHGTMS | `09-29-2026 05:49:37 PM` | LAST_CHG_TMS |
| LASTCHGUSRID | `T045519` | LAST_CHG_USR_ID |
| STARTTMS | `09-29-2026 05:49:37 PM` | START_TMS |

Columnas OID de XELM no presentes en el mensaje (posible clave generada por el motor): EINC_OID, FINR_CLSF_OID
