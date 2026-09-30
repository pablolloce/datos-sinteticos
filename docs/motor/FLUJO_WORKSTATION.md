# Guardar desde la Workstation: qué se escribe en la BBDD

Análisis de `CustomWorkstationWorkflow` v22 (11/03/2026) y de los 103 workflows que cuelgan de
él, a partir de las extracciones de `fileloading` (01–07). Objetivo: saber qué filas deja en
`KYTL_GC` un guardado desde una ventana, para replicarlo en `PKG_SINT` (D-031).

> **Limitación:** muchos scripts y SQL están guardados en `FT_WF_WFNP.LARGE_BINARY_VAL_BLOB`
> (179 parámetros en este árbol) y no estaban en las extracciones. Lo marcado **[BLOB]** está
> deducido de versiones antiguas, del resto del workflow o no se conoce. Consulta para
> extraerlos: `fileloading/extracciones/extracciones_workstation.sql` (W1–W6) y decodificador
> `fileloading/herramientas/decodificar_extracciones.py`.

## 1. Secuencia

```
Guardar en la ventana ─► evento WORKSTATION (OnWorkstationMessage) ─► CustomWorkstationWorkflow v22
  1. Create Transaction (FT_T_TRID) · Create Message
  2. Basic Message Processing (evento ProcessFeedMessage) ─► motor TPS-UI
       message set STREETREF + reglas Java rdrRules.jar  ─► INSERT/UPDATE del mensaje   ◄── fase 1
  3. Severidad 40/50 ─► fin (TRID AUTO-CLOSE). Resto:
  4. Checks (valido = el guardado cambia algo más que ratings locales)
       valido=false ─► RDR_CalculateREU ─► fin
       valido=true  ─► RDR_DatosRegu ─► RDR_AutoCodTesBDI ─► RDR_AuditMex ─► RDR_CallDifusion
                       ─► RDR_PublishChanges ─► RDR_PUBLISH_CG ─► fin                   ◄── fase 2
  5. UPDATE FT_T_TRID SET TRN_USR_STAT_TYP='AUTO-CLOSE'
```

Los pasos 4 son eventos (`RaiseEvent`): lanzan instancias nuevas de otros workflows,
probablemente asíncronas. Reciben el mensaje en `inputMessage`/`message`. La asignación
valido→rama se ha deducido de la adyacencia de OIDs y de los mensajes de log; no está probada.

## 2. Escrituras de negocio de la fase 2

| Workflow (evento) | Condición | Escritura | Replicable hoy |
|---|---|---|---|
| **Checks** | — | Ninguna (lee `FT_T_PAR1` `RTNGS_LOCALES`, `FT_T_RTNG`, `FT_T_FIRT`) | Sólo decide la rama; falta [BLOB] |
| **CheckDatosRegulatorios** (`RDR_DatosRegu`) | Entidad `Counterparty` (XSLT `ManageSMSUI.xslt`) | INSERT de datos regulatorios por JDBC (probablemente `FT_T_FRA1`), para la entidad y en cascada para su LOCAL y GLOBAL según `FT_T_FIRL` | No: tabla y columnas en [BLOB] |
| **RDR_CalculateREU** → `Sub_CalculateREU` | `FIRL.REL_TYP='OPERATIVE'` (y siempre cuando valido=false) | `FT_T_FIRT` REU (INSERT/UPDATE: `EXT_RTN`/`EXT_RTNL`, PENDING, NR/INACTIVE), `FT_T_FRRL` `REUINHER` (INSERT/UPDATE), herencia a hijos; `LAST_CHG_USR_ID` = usuario del mensaje o `BBVA:CUSTOMER` | Casi: SQL completas; falta el cálculo (2º mejor rating) [BLOB] y la selección de sets |
| **AutoCodTesBDI** → `SendBDIRequest` | `MODLID='FINSX'` y cambio de `BDLOCAL` | Ninguna: envía una trama a la cola MQ del BDI | Nada que replicar |
| **AuditMex** → `AuditoriaSSI` | Alta de CPARTY/SSI/SCI sólo de la entidad 1145 (México), o SSI de un branch de 0182 | INSERT `FT_T_ALG1` (`PROCESO='RDR_AuditMex'`, `MENSAJE='tipo|canónico|usuario|fecha'`, una fila por canónico) | Casi: SQL de v1/v2; la v6 [BLOB] añade la fecha por trimestre |
| **Sub_CallDifusion** (`RDR_CallDifusion`) | CPARTY / SSI (modelos SSIS*) / CONTACT (RDRCNTC2, CNTCCOPY) | Ver 2.1 | Parcial |
| **Sub_PublishChanges** (`RDR_PublishChanges`) | Según entidad/modelo | Ver 2.2 | Parcial |
| **RDR_PUBLISH_CG** | Filas `FT_T_RLT1` `CuentaGestionada` `PENDIENTE` del último minuto (las crea la regla `CuentasGestionadas`) | `FT_T_RLT1` → `GS_VALUE='OK'`; `Sub_PublishLocalGlobal` (cachés, FRID shortname) | Parcial |

### 2.1 Sub_CallDifusion

- **CPARTY**:
  - Siempre: evento `RDR_Bajas_Online_OLAP` → `DELETE CACHE_COUNTERPARTIES` (roles/branches dados de baja).
  - Si es OPERATIVE: `Sub_CalculateREU`, `TypeOfDifusion` y `upda_tes_BDI` (sólo MQ).
  - `TypeOfDifusion`:
    - `FT_T_RLT1` `RLT_DIF_STAT` (`NOFIRL`/`OK`/`MPENDING`).
    - `FT_T_EMM1` (mensajes enviados a MGC).
    - `Sub_ComposeSendCopy`, que escribe `FT_T_EMM1` y `FT_T_RLT1`.
  - Lectura de datos de cliente con escrituras regulatorias:
    - `Global Regulatory Information`, sólo entidades propias 0182/1145: `FT_T_FRA1` (EMIR/SFTR/NFC…), `FT_T_FIST` `MIFIFIRM`/`UKFIRM`, `TABLEALERTGENER`.
    - `OperativeRegulatoryInformation`: `FT_T_FRA1` `CORPREL`/`FINENTDF`, `FT_T_FIGU` `COMPCOUN`.
    - `SpreadActvecomValue`: `DELETE FT_T_UTD1 ACTVECOM`, `UPDATE FT_T_FSA1 ACTVECOM`.
- **SSI**: `PublishSSIFromGSToABACO`:
  - `FT_T_EMM1` `PENDING`→`SENT` / `NO SENT`.
  - `Sub_InsertCache` sobre `FT_T_CCA1` [BLOB].
- **CONTACT**: `PublishContactFromGSToABACO`:
  - `FT_T_EMM1`.
  - `Sub_InsertCache` sobre `FT_T_CCA1`.

### 2.2 Sub_PublishChanges

- **LAGRCOPY**: `UPDATE FT_T_LAGR SET LAST_CHG_TMS = <FECHA de FT_T_PAR1 CreateCopyLAGR>` sobre el LAGR del mensaje. **Completa.**
- **Issue** (RDR_ISSU/ISSU_MEX con `IssueStatistic` UPDATE `NAMEMEXI`/`COUPONMX`/`SERIEMEX`): `UPDATE FT_T_ISID` `ID_CONCEPT` → `INACTIVE` (`RDR:NFQ`). **Completa** (sólo en modificaciones).
- **Counterparty**:
  - `CreateShortname`: si no hay FRID `SHTNMEID` activo, `INSERT FT_T_FRID`:
    - `FINSRL_ID_CTXT_TYP='SHTNMEID'`;
    - `FINR_ID = UPPER(FINS_ID) || 10 primeros caracteres del nombre legal sin puntuación ni espacios`;
    - `FINSRL_TYP` = `FIST MAINROL`;
    - `BBVA:CUSTOMER`, `RDR`.
    - Texto de la v4; la v7 está en [BLOB], incluida la comprobación de duplicado.
  - `CreateAliasLATAM`: **no se ejecuta nunca**. La condición compara con `''`, que en Oracle es NULL.
  - `Sub_PublishLocalGlobal` (cachés `FT_T_CAC1`, `CACHE_COUNTERPARTIES`).
- **Configuración genérica** (variable global `CONFIG_ONLINE_PUBLISHING` [BLOB]): `Sub_ProcessAllSegments`:
  - `INSERT FT_T_RLT1` [BLOB].
  - Activación/inactivación de diccionarios (`FT_T_CID1`, `GUID`, `EDMV`, `ISID`, `ACID`, `EIST`).
  - `FT_T_CAC1` (`OnlineCounterparty`).
  - `FT_T_VREQ` (`AlertGestorasModif`, gestoras).
- Publicaciones ESB/MQ/JMS, ficheros ABACO y correos: sin escritura de negocio.

## 3. Qué replicar y en qué orden

Criterio: primero lo que cambia **entidades de negocio** que las pruebas funcionales verán; las
tablas de control de difusión (`EMM1`, `RLT1`, `CCA1`, `CAC1`, `CACHE_COUNTERPARTIES`, `VREQ`,
`ALG1`) después, y sólo si las pruebas las consultan (P-018).

| Prioridad | Qué | Tablas | Bloqueo |
|---|---|---|---|
| 1 | Fase 1: motor (message set + reglas Java) | las del mensaje + `FT_T_FIID` FINSID… | Huella para las nativas (D-030) |
| 2 | Shortname de contrapartida (`CreateShortname`) | `FT_T_FRID` `SHTNMEID` | W1 (v7 [BLOB]) o huella |
| 3 | REU (`Sub_CalculateREU`) | `FT_T_FIRT`, `FT_T_FRRL` | W1 (cálculo) |
| 4 | Datos regulatorios (`CheckDatosRegulatorios`, `Global/OperativeRegulatoryInformation`) | `FT_T_FRA1`, `FT_T_FIST`, `FT_T_FIGU`, `FT_T_FSA1`, `FT_T_UTD1` | W1 + `ManageSMSUI.xslt` (W4) |
| 5 | Casos por modelo: LAGRCOPY (`FT_T_LAGR`), Issue MEX (`FT_T_ISID`) | — | Ninguno: SQL completas |
| 6 | Auditoría México | `FT_T_ALG1` | W1 (v6) |
| 7 | Control de difusión y cachés | `EMM1`, `RLT1`, `CCA1`, `CAC1`, `CACHE_COUNTERPARTIES`, `VREQ` | P-018 |

La huella de un guardado real (`plsql/motor/capturar_huella.sql`) captura **ambas fases**,
porque recorre todas las tablas en la ventana de tiempo. Así que confirma de una vez qué escribe
el motor y qué escriben los workflows posteriores, siempre que la ventana cubra también los
eventos asíncronos (dejar un margen de un par de minutos).

## 4. Caso Contrapartida Global (`Ejemplo_Alta_Contrapartida_Global.xml`)

Trazado con los scripts decodificados (fase 2 de una contrapartida GLOBAL nueva, modelo `RDRFINSG`):

| Workflow | ¿Escribe? | Motivo |
|---|---|---|
| `Checks` | — | `valido=true`: el mensaje trae segmentos distintos de FinancialInstitution/Rating |
| `CheckDatosRegulatorios` | **Sí**: `FT_T_RLT1` `CONTROLDR`, `SRC_VALUE='true'`, `GS_VALUE='GLOBAL'`, `MAIN_ENTITY_ID`=INST_MNEM | Camino GLOBAL; `CALCULO=true` porque el FIGU trae país (`GUID`) |
| `RDR_CalculateREU` | No | Sólo en la rama `valido=false` y para OPERATIVE |
| `AutoCodTesBDI` | No | Sólo modelo `FINSX` |
| `AuditMex` | No | Exige LOCAL hijas con OPERATIVE de México (1145) |
| `Sub_CallDifusion` | No | GLOBAL con 0 operativas → fin; la baja OLAP no borra nada (FINSID nuevo) |
| `Sub_PublishChanges` → `CreateShortname` | Sólo infraestructura (`FT_T_JBLG`, `FT_T_TRID`) | Sin FIRL OPERATIVE no llega al INSERT de `FT_T_FRID` SHTNMEID |
| `Sub_PublishChanges` → `Sub_PublishLocalGlobal` | No | 0 operativas bajo la GLOBAL → fin |
| `RDR_PUBLISH_CG` | No | No hay filas `CuentaGestionada` (la regla `CuentasGestionadas` no aplica) |
| `CustomWorkstationWorkflow` | `FT_T_TRID` `AUTO-CLOSE` | Transacción del guardado: no se replica (el generador no crea transacciones) |

Condiciones que confirmar con una huella: la FIRL GLOBAL está confirmada cuando se lanzan los
eventos; `CFTIInternalIdentifierCreator` crea el FIID `FINSID` (lo usa `CreateShortname`); los XSLT
`ExtractChangesEntity`, `OLAP_TransformDelete` y `ManageAuditMex` (no extraídos) no cambian lo anterior.
