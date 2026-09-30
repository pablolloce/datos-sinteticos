# Reglas del motor para `Ejemplo_Alta_Contrapartida_Global.xml`

> Generado con `herramientas/motor/reglas_aplicables.py`. No editar a mano.

- Modelo (`MODEL/MODLID`): **RDRFINSG** · Clasificación: WEBMSG · Entidad principal: FINS
- Motor: TPS-UI (mensaje de Workstation); message set STREETREF.

## 1. Inicio del mensaje (segmento `Initial`)

Se ejecutan una vez por mensaje, antes de procesar los segmentos, en este orden.

### Reglas nativas

| # | Fase | Regla nativa | Parámetros | Comportamiento inferido | Confianza | Impacto |
|---|---|---|---|---|---|---|
| 1 | B | `CGSCRealignALIDAfterMerge` |  | Realinea FT_T_ALID tras fusión de entidades. | MEDIA | BAJO |
| 2 | B | `CGSCIssuerDerivation` | INITIAL / CUSIP-3,CINS-3 / CUSIP,CINS / MarkitREDEntity,SPGISFEntityIdentifiers / ISIDPLUS,CRSSWALK | Deriva el emisor de la emisión a partir de CUSIP/CINS y otros proveedores. | MEDIA | BAJO fuera de cargas de proveedor |
| 3 | B | `CGSCModelForcedReevaluation` |  | Fuerza la reevaluación del modelo (MODLID) del mensaje. | BAJA | MEDIO |
| 7 | B | `CFTIUniqueCheckAndIDLookup` |  | Identificación de la entidad por sus identificadores (unicidad + búsqueda),  decide si el mensaje es alta o modificación., ALTA | ALTO en cargas de proveedor |  BAJO en altas del frontal |
| 8 | B | `CGSCCheckForIdenitifersInMessage` | InteractiveDataDescriptive / ISIN,CUSIP | Exige identificadores (ISIN,CUSIP) en mensajes de InteractiveData. | ALTA | NINGUNO fuera de ese proveedor |
| 9 | B | `CFTIConstrIssueActionID` | NULLVALUEMATCH=Y / PROPRIETARY_IDENTIFIERS=CEDELULLXXX-CRPACTID=NM;CITIHKHXXXX-CRPACTID=NM;DEUTHKHHXXX-CRPACTID=NM;DEUTKRSEXXX-CRPACTID=NM;DEUTTWTPXXX-CRPACTID=NM;IRVTBEBBXXX-CRPACTID=NM;MOCAUI-CRPACTID=NM;NSCVE-CRPACTID=NM;NSCVN-CRPACTID=NM;PARBFRPPXXX-CRPACTID=NM;PARBGB2LXXX-CRPACTID=NM;BCMRMXMMSEC-CRPACTID=NM;IBRCESMMXXX-CRPACTID=NM;SOGEFRPPGSS-CRPACTID=NM;ADPGUS33XXX-CRPACTID=NM | Construye el identificador de evento corporativo (Issue Action ID),  NULLVALUEMATCH e identificadores propietarios por BIC. | MEDIA | ALTO en eventos corporativos |
| 10 | B | `CFTIModelDefault` |  | Aplica valores por defecto del modelo (MODLID) a los campos no informados. | MEDIA | ALTO: valores por defecto definidos en tablas de modelo |
| 11 | B | `CGSCCheckPrimaryMktIdentifier` | TELEKURS,BB,REUTERS / INITIAL / EQSHR,OPTIONS,COMMON,CVTPFD,FUND,FUTURES,INDEXOP,PFD,RECEIPTS,RIGHTS,UNIT,UNITTRST,WARRANTS,HYBRID,MISC | Controla el identificador primario de mercado (TELEKURS,BB,REUTERS) para los tipos de emisión listados. | MEDIA | BAJO |
| 12 | B | `CGSCEquateListing` | EQSHR,OPTIONS,COMMON,CVTPFD,FUND,FUTURES,INDEXOP,PFD,RECEIPTS,RIGHTS,UNIT,UNITTRST,WARRANTS,MISC,HYBRID,STRATRAD,BOND,CASHSEC,COML PPR,FIXDBOND,GOVTBOND,IRG,LOAN,MONEYMAR,REPO,TBILL,TBOND,TNOTE,VAR BOND,ZERO CPN,CALL OPT,PUT OPT,COMODITY,CVTBOND,INDEX,REALESTA,LTDPART,ETF,ETN,ETP / BBCMPSEC,BBUNIQUE,BBCPTICK,LISTSYMB,PREFSYMB,TELEKURS,TICKER,RIC,TRDGSYMB,CPBBUNIQ,CPTICKER,EQFUNDTK,BBGLOBAL / Y / SEDOL,CPSEDOL | Equipara listados por identificadores de mercado. | MEDIA | BAJO |

### Reglas Java

| # | Fase | Regla Java | Veredicto | Motivo | Qué hace | Efecto |
|---|---|---|---|---|---|---|
| 4 | B | `CreateCopyISSUMex` | **DESCARTADA** | sólo actúa con modelos ISSUCOPY | ISSUCOPY: clona emisión con nuevo RDR_ID (NEW_RDR_ISSUE_ID). | modifica el mensaje; DML directo en BBDD |
| 5 | B | `IssueMexico` | **DESCARTADA** | sólo actúa con modelos ISSU_MEX, RDR_ISSU | Emisión mexicana duplicada 9038, ISIN 9040, MUREXID 9041, ISIN!=MEX_ISIN 9042. | modifica el mensaje; DML directo en BBDD; notif. 9038, 9040, 9041, 9042 |
| 6 | B | `IssuesDuplis` | **DESCARTADA** | sólo actúa con modelos ISID, ISSUCOPY, ISSU_MEX, RDR_ISSU | Mismas comprobaciones que IssueMexico (9038, 9040, 9041): notificaciones duplicadas. | notif. 9038, 9040, 9041 |
| 13 | B | `setDifusion` | **CANDIDATA** | modelo RDRFINSG; segmentos FINREnterpriseFinancialInstitutionRole, FinancialInstitutionStatistic, FinsRoleClassification; acciones en el código: DELETE, IGNORE, INSERT, UPDATE | Marca DIFUSION/REACTIVE en LAST_CHG_USR_ID o DATA_SRC_ID (FIID, FIST de una lista, ENFR OPE_BRANCH, FINR subdiv...); DELETE FIID -> UPDATE INACTIVE; DELETE LEI -> IGNORE. | modifica el mensaje; DML directo en BBDD |
| 14 | B | `SwiftCTPTA` | **DESCARTADA** | sólo actúa con modelos FINSX | Asegura que SWIFTLIQ/SWIFTCON viajan con DIFUSION. | modifica el mensaje |
| 15 | B | `CCValidationSSIS` | **DESCARTADA** | sólo actúa con modelos SSIS, SSISCOPY | SSIS/SSISCOPY: dígito de control CCC española -> 9006; BENEF añade STT_OFFC. | modifica el mensaje; notif. 9006 |
| 16 | B | `DeleteNew` | **DESCARTADA** | sólo actúa con modelos SSIS, SSISCOPY, SSISDENE, SSISDERE | SSISDENE delete-new / SSISCOPY copia / SSIS asigna SSI_ID (SSIS_ID_SEQ); 9001, 9007. | modifica el mensaje; notif. 9001, 9007 |
| 17 | B | `FinancialInstitutionRatingOIDs` | **DESCARTADA** | sólo actúa con modelos FINSO, FINSX | Deduplica ratings; vacíos -> END_TMS. | modifica el mensaje |
| 18 | B | `ValidateNFIESP` | **DESCARTADA** | sólo actúa con modelos SSIS | Validación NFI España -> 10000. | notif. 10000 |
| 19 | B | `CreateCopyCNTC` | **DESCARTADA** | sólo actúa con modelos CNTCCOPY | CNTCCOPY: clona un contacto (CNTC, CAI1 max+1, CNTA, COT1, CCRF, MADR, EADR, ADTP). | modifica el mensaje |
| 20 | B | `addOfficeAtt` | **DESCARTADA** | sólo actúa con modelos FINSO, FINSTP, FINSX | Alta de oficina: añade ACC_TYPE, BDE_CODE, RESIDENT, ACTVECOM (rdrUtils.getOffAtt). | modifica el mensaje |
| 21 | B | `InactivateReactivateBDI` | **DESCARTADA** | sólo actúa con modelos FINSO, FINSX | Cambio BDLOCAL I<->N/X/O: inactiva/reactiva datos BDI y PREF_FINS_ID. | modifica el mensaje; DML directo en BBDD |
| 22 | B | `Uniqueness` | **CANDIDATA** | modelo RDRFINSG; segmentos FINSFinancialInstitutionRole; acciones en el código: INSERT, OPTIMISTICUPDATE, UPDATE | Unicidad de FRID/FIID/alias/cuentas/ISID (9001, 9002, 9003). | notif. 9001, 9002, 9003 |
| 23 | B | `CorporateEvents` | **DESCARTADA** | sólo actúa con modelos RDR_CORP | RDR_CORP: reordena/deduplica hijos IADC CEMX; auditoría en relation_issue. | modifica el mensaje; DML directo en BBDD |
| 24 | B | `CheckUpdateStatusASTYPUEMIR` | **CANDIDATA** | modelo RDRFINSG; segmentos FinancialInstitution; acciones en el código: UPDATE | EMIR: activa/inactiva ASTYPUEMIR según MANPARTY=06 (UPDATE FINS_REGULATION_ATTR). | DML directo en BBDD |
| 25 | B | `UniquenessSCIS` | **DESCARTADA** | sólo actúa con modelos SCIS | SCI duplicada FINR x desc x branch x product (9004). En INSERT ineficaz (TRADE_TYP null). |  |
| 26 | B | `AckNackReceived` | **DESCARTADA** | sólo actúa con modelos FINSO, FINSTP | Control ACK/NACK de MGC en FT_T_UTD1; difusión pendiente <1 min -> 9008. | modifica el mensaje; notif. 9008 |
| 27 | B | `BorradoClientela` | **DESCARTADA** | sólo actúa con modelos FINS_H | FINS_H: cambio de jerarquía de CPARTY -> RegisterLogTable (RLT1) PENDING. | modifica el mensaje |
| 28 | B | `UpdateUserInactiveDate` | **DESCARTADA** | sólo actúa con modelos FINSX | FinancialEndOp: APP_END_TMS = USR_END_TMS - 18 meses. | modifica el mensaje |
| 29 | B | `CargaFechasCtpdas` | **DESCARTADA** | ningún segmento del mensaje coincide con los que trata | FinancialEndOp: USR_END_TMS = APP_END_TMS +1 mes / +18 meses / igual (STAR). | modifica el mensaje |
| 30 | B | `InactiveFundMIFID` | **DESCARTADA** | sólo actúa con modelos FINSX | CPARTY HEREDAR INACTIVE -> CL_VALUE=0. En la práctica NO actúa (campo '.DATA_STAT_TYP ' con espacio). | modifica el mensaje |
| 31 | B | `InactiveIssuerIds` | **DESCARTADA** | sólo actúa con modelos FINSO, FINSTP, FINSX | Rol ISSUER inactivo -> inactiva FRID/ENFR; coherencia MUREXID (9030, 9031). | DML directo en BBDD; notif. 9030, 9031 |
| 32 | B | `InactiveClearing` | **DESCARTADA** | sólo actúa con modelos FINSX | Rol CLRNGBRK/CLRNGHS INACTIVE -> inactiva FRID y ENFR. | DML directo en BBDD |
| 33 | B | `InactiveInternalParticipant` | **DESCARTADA** | sólo actúa con modelos FINSO, FINSX | INTPARTI en acuerdo NAFMII activo no se puede inactivar -> 9032. |  |
| 34 | B | `SinglePortfolio` | **DESCARTADA** | sólo actúa con modelos RDR_ACGR, RDR_PORT | Portfolio en un solo trading book (9033) y book=oficina (9034, 9035). | notif. 9033, 9034, 9035 |
| 35 | B | `CuentasGestionadas` | **DESCARTADA** | sólo actúa con modelos FINSO, FINSX | Mandated accounts: mueve FRRL MANDTACC y encola RLT1; cambio de LEI -> 9036. | modifica el mensaje; DML directo en BBDD |
| 36 | B | `RuleCalypso` | **DESCARTADA** | sólo actúa con modelos LAGRCOPY | Recalcula listas de Calypso IDs en LAID y COI1; activa/inactiva EXI1. | DML directo en BBDD |
| 37 | B | `CheckCLANCpty` | **DESCARTADA** | sólo actúa con modelos FINSO, FINSX | Inactivar FIID DELTAID -> inactiva FRID CLIPID de CPARTY (UPDATE directo). | DML directo en BBDD |
| 38 | B | `DuplicidadesSDIs` | **DESCARTADA** | sólo actúa con modelos SSIS, SSISCOPY, SSISDENE | SSI duplicada por contraparte, tipo, dirección, productos... (9009/9013). | notif. 9009, 9013 |
| 39 | B | `DuplicidadesSCIs` | **DESCARTADA** | sólo actúa con modelos SCIS, SCIS1, SCISDENE | SCI duplicada (9009/9013). | notif. 9009, 9013 |
| 40 | B | `LAGRduplis` | **DESCARTADA** | sólo actúa con modelos LAGRCOPY | Acuerdo duplicado (9012). | notif. 9012 |
| 41 | B | `DuplicarAnexe_LA` | **DESCARTADA** | sólo actúa con modelos LAGRCOPY | LAGR org 0182: valida scope estándar (9014, 9025, 9026) y genera LAAP/Collateral. | modifica el mensaje; notif. 9014, 9025, 9026 |
| 42 | B | `UpdateInactive` | **DESCARTADA** | sólo actúa con modelos FINSO, FINSX, ISSU_BSK, LAGR, LAGRBANC | Convierte DELETE en inactivación lógica (LAGR, FINSX, FINSO, ISSU_BSK). | modifica el mensaje; DML directo en BBDD |
| 43 | B | `ThrdPartyCalypsoFilter` | **DESCARTADA** | ningún segmento del mensaje coincide con los que trata | Calypso Filter activo -> DATA_SRC_ID=SSISATT en clasificaciones. | modifica el mensaje |
| 44 | B | `DuplicidadesContactos` | **DESCARTADA** | sólo actúa con modelos RDRCNTC2 | Duplicidad de contacto 9015, formato email/fax 9016, INSTIT usado en SCIs 9017. |  |
| 45 | B | `generateLagrLaan` | **DESCARTADA** | sólo actúa con modelos LAGR, LAGR_BSI | Pone en IGNORE atributos vacíos de LAGR (SCOPESD, COVERFX, SPECTRAN...). | modifica el mensaje |
| 46 | B | `RDRInactivations` | **DESCARTADA** | ningún segmento del mensaje coincide con los que trata | Acuerdo INACTIVE -> inactiva LAID 'Onboarding Digital' (ORG_ID 1145). | DML directo en BBDD |
| 47 | B | `LegalOpinion` | **DESCARTADA** | sólo actúa con modelos LAGRCOPY | Calcula LOEFFECT/PRODUCTS; UPDATE directo LAT1, LAX1, FND1. | modifica el mensaje; DML directo en BBDD |
| 48 | B | `CreateCopyLAGR` | **DESCARTADA** | sólo actúa con modelos LAGRCOPY | LAGRCOPY: clona acuerdo completo con OIDs nuevos y LAAN_ID_SEQ; duplicado -> 9037. | modifica el mensaje; DML directo en BBDD; notif. 9037 |
| 49 | B | `RulesCPTY` | **DESCARTADA** | sólo actúa con modelos FINSO, FINSX | STARID existente 9046; genera FRID ALIASID espejo de cada STARID. | modifica el mensaje; DML directo en BBDD; notif. 9046 |
| 50 | B | `RulesLAGR` | **DESCARTADA** | sólo actúa con modelos LAGR, LAGR_BSI | Carbon Market (9043), Calypso duplicado entre fondos (9050), coverage y versión. | modifica el mensaje; DML directo en BBDD; notif. 9043, 9050 |
| 51 | B | `LegalOpinionCreateCopy` | **DESCARTADA** | sólo actúa con modelos LAGRCOPY | Igual que LegalOpinion para LAGRCOPY. | modifica el mensaje |
| 52 | B | `LAGRdates` | **DESCARTADA** | ningún segmento del mensaje coincide con los que trata | Fechas STTLMNTCCY del acuerdo (9027, 9028, 9029). |  |
| 53 | B | `getRefSectorAllocation` | **DESCARTADA** | sólo actúa con modelos FINSO, FINSX | Sector/subsector Refinitiv (FT_T_SAA2) -> 9024. | modifica el mensaje |
| 54 | B | `ValidateCountryRegion` | **CANDIDATA** | modelo RDRFINSG; segmentos FinancialInstitutionGeoUnitPrt; acciones en el código: IGNORE | FIGU STSMNTCT distinto de CA: STSMNTCR -> IGNORE y se inactivan las de BD. | modifica el mensaje; DML directo en BBDD |
| 55 | B | `ValidateCNPJ` | **DESCARTADA** | sólo actúa con modelos FINSL, FINSO, FINSTP, FINSX | Sede/branch en Brasil (BR1) sin CNPJ -> 9047. | notif. 9047 |

## 2. Por segmento del mensaje

Fases: `B` = Antes de procesar el segmento; `A` = Después de procesar el segmento; `F` = Al final (tras persistir el segmento); `D` = Al borrar (acción DELETE).

### `FinancialInstitution` — 4 segmento(s), acción INSERT, REFERENCE

| # | Fase | Regla nativa | Parámetros | Comportamiento inferido | Confianza | Impacto |
|---|---|---|---|---|---|---|
| 1 | B | `CGSCEndDateIdentifiers` |  | Cierra (END_TMS) identificadores sustituidos. | MEDIA | BAJO en altas |
| 2 | F | `CFTIInternalIdentifierCreator` | FINSID | Crea el identificador interno de la institución financiera: fila FT_T_FIID con contexto FINSID (param 1) si la entidad no lo tiene,  se ejecuta en fase F. | ALTA (nombre+parámetro+uso de FINSID en ValidateLAGR) | ALTO: el mensaje del frontal NO trae FIID FINSID y GoldenSource sí lo crea |

### `FinancialInstitutionStatistic` — 2 segmento(s), acción INSERT

| # | Fase | Regla nativa | Parámetros | Comportamiento inferido | Confianza | Impacto |
|---|---|---|---|---|---|---|
| 1 | B | `CFTIConstrSTDFOID` | Y | Resuelve STAT_DEF_ID / definición de estadística. | MEDIA | BAJO |

### `FinancialInstitutionGeoUnitPrt` — 1 segmento(s), acción INSERT

| # | Fase | Regla nativa | Parámetros | Comportamiento inferido | Confianza | Impacto |
|---|---|---|---|---|---|---|
| 1 | B | `CGSCHandleCompositeKey` | GUNT | Resuelve claves compuestas de tablas genéricas (INCL, GUNT, RTVL, ACTP, LGER). | ALTA | MEDIO: rellena OIDs de datos maestros |

### `FINSFinancialLegalNames` — 1 segmento(s), acción OPTIMISTICUPDATE

| # | Fase | Regla Java | Veredicto | Motivo | Qué hace | Efecto |
|---|---|---|---|---|---|---|
| 1 | B | `FLG_Uniqueness` | **CANDIDATA** | modelo RDRFINSG; segmentos FINSFinancialLegalNames, FinancialInstitution, FinancialInstitutionGeoUnitPrt; acciones en el código: INSERT, OPTIMISTICUPDATE, UPDATE | Unicidad FLG_LEGAL_NME (9001); FINSX propaga nombre a FINS; RDRFINSG/FINSL/FINSO: FIGU MEX->MX y GUNT_OID. | modifica el mensaje; notif. 9001 |

### `FinsRoleClassification` — 1 segmento(s), acción INSERT

| # | Fase | Regla nativa | Parámetros | Comportamiento inferido | Confianza | Impacto |
|---|---|---|---|---|---|---|
| 1 | B | `CGSCHandleCompositeKey` | INCL | Resuelve claves compuestas de tablas genéricas (INCL, GUNT, RTVL, ACTP, LGER). | ALTA | MEDIO: rellena OIDs de datos maestros |

Segmentos del mensaje sin reglas propias en el message set (sólo les afectan las de `Initial` y `Final`): FINSFinancialInstitutionRole (1× INSERT), FINRFinsFinsRoleRelationship (1× INSERT), FINREnterpriseFinancialInstitutionRole (2× INSERT).

## 3. Final del mensaje (segmento `Final`)

| # | Fase | Regla nativa | Parámetros | Comportamiento inferido | Confianza | Impacto |
|---|---|---|---|---|---|---|
| 1 | B | `CFTIValIssueIdentifiers` | INTERNAL_IDENTIFIERS=INTERNAL,COMMON | Valida identificadores de emisión (check digit, contextos internos INTERNAL,COMMON). | ALTA | BAJO |
| 2 | B | `CFTIConstrPrefId` | Issue / PREF_ID_CTXT_TYP / PREF_ISS_ID / ISIN,CUSIP,CINS,SEDOL,MEX_ISIN / Y | Fija el identificador preferente de la entidad (PREF_ISS_ID / PREF_FINS_ID y su contexto) según la prioridad de contextos del parámetro 4 (notif. RULEPRC 390/528). | ALTA | ALTO: actualiza FT_T_ISSU / FT_T_FINS |
| 3 | B | `CFTIConstrPrefId` | FinancialInstitution / PREF_FINS_ID_CTXT_TYP / PREF_FINS_ID / LEI,CUSIP,CINS,DUNS,S&P,BBCMPYID,BCN,GK,RED,RTORGLID,FTCMPYID,BIC / Y | Fija el identificador preferente de la entidad (PREF_ISS_ID / PREF_FINS_ID y su contexto) según la prioridad de contextos del parámetro 4 (notif. RULEPRC 390/528). | ALTA | ALTO: actualiza FT_T_ISSU / FT_T_FINS |
| 4 | B | `CGSCEndDateMIXR` | BBCMPSEC,BBUNIQUE,BBCPTICK,LISTSYMB,PREFSYMB,TELEKURS,TICKER,RIC,TRDGSYMB,CPBBUNIQ,CPTICKER,EQFUNDTK,BBGLOBAL / SEDOL | Cierra referencias cruzadas de mercado sustituidas. | MEDIA | BAJO |
| 5 | B | `CGSCCheckPrimaryMktIdentifier` | TELEKURS,BB,REUTERS / FINAL / EQSHR,OPTIONS,COMMON,CVTPFD,FUND,FUTURES,INDEXOP,PFD,RECEIPTS,RIGHTS,UNIT,UNITTRST,WARRANTS,HYBRID,MISC | Controla el identificador primario de mercado (TELEKURS,BB,REUTERS) para los tipos de emisión listados. | MEDIA | BAJO |
| 6 | B | `CGSCConsolidationStat` |  | Estado de consolidación de la entidad. | BAJA | BAJO |
| 7 | B | `CGSCSwapIssueActionID` |  | Intercambia identificadores de evento corporativo. | BAJA | BAJO |
| 8 | B | `CGSCValidateDPICConfig` |  | Valida la configuración DPIC. | BAJA | BAJO |
| 9 | B | `CGSCEndDateFinsFinsRole` |  | Cierra (END_TMS) relaciones FINS-FINS-rol que dejan de venir. | MEDIA | BAJO en altas |
| 10 | B | `CGSCEndDateMultiEntityHierarchy` | FINS,CUST,FRCP,FINSRL_TYP=CREDHIER / CUST,ACCT,CACR,RL_TYP=CREDHIER | Cierra jerarquías de crédito (CREDHIER) sustituidas. | MEDIA | BAJO |
| 11 | B | `CGSCHandleOrphanEntity` |  | Trata entidades huérfanas (sin padre) al final del mensaje. | BAJA | MEDIO |

| # | Fase | Regla Java | Veredicto | Motivo | Qué hace | Efecto |
|---|---|---|---|---|---|---|
| 12 | B | `RegulationSecurityLabelBaskets` | **DESCARTADA** | sólo actúa con modelos RDR_ISSU | Nuevo MUREXID/SECFICLAB -> reapunta RISS, ISGP, ISGR de cestas. | DML directo en BBDD |
| 13 | B | `DerivativesMainIdValidation` | **DESCARTADA** | sólo actúa con modelos ISSU_MEX | OPTIONS/FUTURES: PREF_ISS_ID = ISIN > BBGLOBAL > QUOTE_PERM_ID (UPDATE directo). | modifica el mensaje; DML directo en BBDD |

## 4. Notificaciones que pueden lanzar las reglas Java candidatas

La severidad decide si el motor rechaza el mensaje (40 ERROR / 50 FATAL) o sólo avisa.

| Código | Severidad | Texto |
|---|---|---|
| 9001 | 40 ERROR | /%IdTyp%/: /%Ident%/ already exist. |
| 9002 | 40 ERROR | /%IdTyp1%/ can not be modified to /%IdTyp2%/. |
| 9003 | 40 ERROR | Legal Name: /%LegalName%/ is already assigned to other entity. |

## 5. Resumen

- Reglas Java candidatas: 5 (CheckUpdateStatusASTYPUEMIR, FLG_Uniqueness, Uniqueness, ValidateCountryRegion, setDifusion).
- Las reglas nativas con impacto ALTO/MEDIO son las que más probablemente hacen que la BBDD sintética difiera de la real; confirmar con `plsql/motor/capturar_huella.sql` + `herramientas/motor/comparar_huella.py`.

## Avisos

- El message set define más de una vez los segmentos: Issue. Aquí se listan las reglas de todas las definiciones; no se sabe cuál aplica el motor.
- `'es.bbva.kytl.rules.CreateCopyLAGR '` (Initial) tiene espacios en el nombre de clase: si el motor no los recorta, la regla no se carga.
- `'es.bbva.kytl.rules.RulesCPTY '` (Initial) tiene espacios en el nombre de clase: si el motor no los recorta, la regla no se carga.
- `'es.bbva.kytl.rules.RulesLAGR '` (Initial) tiene espacios en el nombre de clase: si el motor no los recorta, la regla no se carga.
