CREATE OR REPLACE PACKAGE BODY sint_e_contrapartida_global
AS
/*******************************************************************************
 * GENERADO AUTOMÁTICAMENTE por herramientas/generar_plsql.py — NO EDITAR A MANO.
 * Para cambiarlo: modificar el mensaje XML o mensajes_entrada/catalogo.json y regenerar.
 * Entidad CONTRAPARTIDA_GLOBAL — mensaje mensajes_entrada/Ejemplo_Alta_Contrapartida_Global.xml
 ******************************************************************************/

   -- Claves internas de UNA entidad: una por cada OID del mensaje que se inserta
   -- y por cada PK que el mensaje no informa. Se generan todas antes de insertar.
   TYPE t_claves IS RECORD (
      k_inst_mnem         ft_t_fins.inst_mnem%TYPE,                        -- FT_T_FINS.INST_MNEM (mensaje: f-uBI7(qW1)
      k_stat_id           ft_t_fist.stat_id%TYPE,                          -- FT_T_FIST.STAT_ID (no viene en el mensaje)
      k_figu_oid          ft_t_figu.figu_oid%TYPE,                         -- FT_T_FIGU.FIGU_OID (no viene en el mensaje)
      k_stat_id_2         ft_t_fist.stat_id%TYPE,                          -- FT_T_FIST.STAT_ID (no viene en el mensaje)
      k_flg_oid           financial_legal_names.flg_oid%TYPE,              -- FINANCIAL_LEGAL_NAMES.FLG_OID (mensaje: f-uFI7(qW1)
      k_finr_oid          ft_t_finr.finr_oid%TYPE,                         -- FT_T_FINR.FINR_OID (mensaje: f-uCI7(qW1)
      k_firl_oid          ft_t_firl.firl_oid%TYPE,                         -- FT_T_FIRL.FIRL_OID (no viene en el mensaje)
      k_enfr_oid          ft_t_enfr.enfr_oid%TYPE,                         -- FT_T_ENFR.ENFR_OID (mensaje: f-uDI7(qW1)
      k_enfr_oid_2        ft_t_enfr.enfr_oid%TYPE,                         -- FT_T_ENFR.ENFR_OID (mensaje: f-uEI7(qW1)
      k_finr_clsf_oid     ft_t_frcl.finr_clsf_oid%TYPE                     -- FT_T_FRCL.FINR_CLSF_OID (no viene en el mensaje)
   );
   TYPE t_lista_claves IS TABLE OF t_claves INDEX BY PLS_INTEGER;

   PROCEDURE generar (
      p_cantidad IN PLS_INTEGER DEFAULT 1)
   IS
      c_usuario CONSTANT VARCHAR2(30) := pkg_sint_nucleo.gc_usuario_sintetico;
      l_ahora   CONSTANT DATE         := SYSDATE;   -- START_TMS y LAST_CHG_TMS (D-007)
      l_existe  PLS_INTEGER;
      l_k       t_lista_claves;
   BEGIN
      pkg_sint_nucleo.validar_cantidad(p_cantidad);

      -------------------------------------------------------------------------
      -- 1. Datos maestros referenciados: deben existir (D-019)
      -------------------------------------------------------------------------
      -- FT_T_STDF (STAT_DEF_ID = UKFIRM) <- FT_T_FIST.STAT_DEF_ID
      SELECT COUNT(*) INTO l_existe FROM ft_t_stdf
       WHERE stat_def_id = 'UKFIRM';
      pkg_sint_nucleo.exigir_referencia(l_existe, 'FT_T_STDF: ' || 'STAT_DEF_ID = UKFIRM');

      -- FT_T_GUNT (GUNT_OID = GUNT3B2===) <- FT_T_FIGU.GUNT_OID
      SELECT COUNT(*) INTO l_existe FROM ft_t_gunt
       WHERE gunt_oid = 'GUNT3B2===';
      pkg_sint_nucleo.exigir_referencia(l_existe, 'FT_T_GUNT: ' || 'GUNT_OID = GUNT3B2===');

      -- FT_T_STDF (STAT_DEF_ID = MIFIFIRM) <- FT_T_FIST.STAT_DEF_ID
      SELECT COUNT(*) INTO l_existe FROM ft_t_stdf
       WHERE stat_def_id = 'MIFIFIRM';
      pkg_sint_nucleo.exigir_referencia(l_existe, 'FT_T_STDF: ' || 'STAT_DEF_ID = MIFIFIRM');

      -- FT_T_ENTR (ORG_ID = 0182) <- FT_T_ENFR.ORG_ID
      SELECT COUNT(*) INTO l_existe FROM ft_t_entr
       WHERE org_id = '0182';
      pkg_sint_nucleo.exigir_referencia(l_existe, 'FT_T_ENTR: ' || 'ORG_ID = 0182');

      -- FT_T_ENTR (ORG_ID = A18) <- FT_T_ENFR.ORG_ID
      SELECT COUNT(*) INTO l_existe FROM ft_t_entr
       WHERE org_id = 'A18';
      pkg_sint_nucleo.exigir_referencia(l_existe, 'FT_T_ENTR: ' || 'ORG_ID = A18');

      -- FT_T_INCL (CLSF_OID = =002DCDB88) <- FT_T_FRCL.CLSF_OID
      SELECT COUNT(*) INTO l_existe FROM ft_t_incl
       WHERE clsf_oid = '=002DCDB88';
      pkg_sint_nucleo.exigir_referencia(l_existe, 'FT_T_INCL: ' || 'CLSF_OID = =002DCDB88');

      -------------------------------------------------------------------------
      -- 2. Claves internas nuevas para cada entidad
      -------------------------------------------------------------------------
      FOR i IN 1 .. p_cantidad LOOP
         l_k(i).k_inst_mnem         := pkg_sint_nucleo.nuevo_oid;
         l_k(i).k_stat_id           := pkg_sint_nucleo.nuevo_oid;
         l_k(i).k_figu_oid          := pkg_sint_nucleo.nuevo_oid;
         l_k(i).k_stat_id_2         := pkg_sint_nucleo.nuevo_oid;
         l_k(i).k_flg_oid           := pkg_sint_nucleo.nuevo_oid;
         l_k(i).k_finr_oid          := pkg_sint_nucleo.nuevo_oid;
         l_k(i).k_firl_oid          := pkg_sint_nucleo.nuevo_oid;
         l_k(i).k_enfr_oid          := pkg_sint_nucleo.nuevo_oid;
         l_k(i).k_enfr_oid_2        := pkg_sint_nucleo.nuevo_oid;
         l_k(i).k_finr_clsf_oid     := pkg_sint_nucleo.nuevo_oid;
      END LOOP;

      SAVEPOINT sp_contrapartida_global;

      -------------------------------------------------------------------------
      -- 3. Inserciones: un FORALL por segmento del mensaje, en su orden
      -------------------------------------------------------------------------
      -- Segmento #1 FinancialInstitution (INSERT) -> FT_T_FINS
      FORALL i IN 1 .. l_k.COUNT
         INSERT INTO ft_t_fins (
             inst_mnem,
             start_tms,
             last_chg_tms,
             last_chg_usr_id,
             inst_nme,
             inst_desc,
             inst_founding_dte,
             data_stat_typ,
             data_src_id,
             inst_legal_nme)
         VALUES (
             l_k(i).k_inst_mnem,                        -- INST_MNEM         <- INSTMNEM = f-uBI7(qW1 (clave nueva)
             l_ahora,                                   -- START_TMS         <- STARTTMS (momento de la llamada)
             l_ahora,                                   -- LAST_CHG_TMS      <- LASTCHGTMS (momento de la llamada)
             c_usuario,                                 -- LAST_CHG_USR_ID   <- LASTCHGUSRID (marca sintética)
             'PROBANDO',                                -- INST_NME          <- INSTNME
             'PROBANDO',                                -- INST_DESC         <- INSTDESC
             TO_DATE('2026-09-29 00:00:00', 'YYYY-MM-DD HH24:MI:SS'), -- INST_FOUNDING_DTE <- INSTFOUNDINGDTE
             'ACTIVE',                                  -- DATA_STAT_TYP     <- DATASTATTYP
             'RDR',                                     -- DATA_SRC_ID       <- DATASRCID
             'PROBANDO'                                 -- INST_LEGAL_NME    <- INSTLEGALNME
         );

      -- Segmento #2 FinancialInstitutionStatistic (INSERT) -> FT_T_FIST
      FORALL i IN 1 .. l_k.COUNT
         INSERT INTO ft_t_fist (
             stat_id,
             stat_def_id,
             inst_mnem,
             start_tms,
             last_chg_tms,
             last_chg_usr_id,
             stat_char_val_txt,
             data_stat_typ,
             data_src_id)
         VALUES (
             l_k(i).k_stat_id,                          -- STAT_ID           <- clave nueva (NEW_OID)
             'UKFIRM',                                  -- STAT_DEF_ID       <- STATDEFID
             l_k(i).k_inst_mnem,                        -- INST_MNEM         <- INSTMNEM = f-uBI7(qW1 (clave nueva)
             l_ahora,                                   -- START_TMS         <- STARTTMS (momento de la llamada)
             l_ahora,                                   -- LAST_CHG_TMS      <- LASTCHGTMS (momento de la llamada)
             c_usuario,                                 -- LAST_CHG_USR_ID   <- LASTCHGUSRID (marca sintética)
             'Y',                                       -- STAT_CHAR_VAL_TXT <- STATCHARVALTXT
             'ACTIVE',                                  -- DATA_STAT_TYP     <- DATASTATTYP
             'RDR'                                      -- DATA_SRC_ID       <- DATASRCID
         );

      -- Segmento #3 FinancialInstitutionGeoUnitPrt (INSERT) -> FT_T_FIGU
      FORALL i IN 1 .. l_k.COUNT
         INSERT INTO ft_t_figu (
             figu_oid,
             inst_mnem,
             gu_id,
             gu_typ,
             gu_cnt,
             fins_gu_purp_typ,
             start_tms,
             last_chg_tms,
             last_chg_usr_id,
             data_stat_typ,
             data_src_id,
             gunt_oid)
         VALUES (
             l_k(i).k_figu_oid,                         -- FIGU_OID          <- clave nueva (NEW_OID)
             l_k(i).k_inst_mnem,                        -- INST_MNEM         <- INSTMNEM = f-uBI7(qW1 (clave nueva)
             'AF',                                      -- GU_ID             <- GUID
             'COUNTRY',                                 -- GU_TYP            <- GUTYP
             1,                                         -- GU_CNT            <- GUCNT
             'STSMNTCT',                                -- FINS_GU_PURP_TYP  <- FINSGUPURPTYP
             l_ahora,                                   -- START_TMS         <- STARTTMS (momento de la llamada)
             l_ahora,                                   -- LAST_CHG_TMS      <- LASTCHGTMS (momento de la llamada)
             c_usuario,                                 -- LAST_CHG_USR_ID   <- LASTCHGUSRID (marca sintética)
             'ACTIVE',                                  -- DATA_STAT_TYP     <- DATASTATTYP
             'RDR',                                     -- DATA_SRC_ID       <- DATASRCID
             'GUNT3B2==='                               -- GUNT_OID          <- GUNTOID
         );

      -- Segmento #4 FinancialInstitutionStatistic (INSERT) -> FT_T_FIST
      FORALL i IN 1 .. l_k.COUNT
         INSERT INTO ft_t_fist (
             stat_id,
             stat_def_id,
             inst_mnem,
             start_tms,
             last_chg_tms,
             last_chg_usr_id,
             stat_char_val_txt,
             data_stat_typ,
             data_src_id)
         VALUES (
             l_k(i).k_stat_id_2,                        -- STAT_ID           <- clave nueva (NEW_OID)
             'MIFIFIRM',                                -- STAT_DEF_ID       <- STATDEFID
             l_k(i).k_inst_mnem,                        -- INST_MNEM         <- INSTMNEM = f-uBI7(qW1 (clave nueva)
             l_ahora,                                   -- START_TMS         <- STARTTMS (momento de la llamada)
             l_ahora,                                   -- LAST_CHG_TMS      <- LASTCHGTMS (momento de la llamada)
             c_usuario,                                 -- LAST_CHG_USR_ID   <- LASTCHGUSRID (marca sintética)
             'Y',                                       -- STAT_CHAR_VAL_TXT <- STATCHARVALTXT
             'ACTIVE',                                  -- DATA_STAT_TYP     <- DATASTATTYP
             'RDR'                                      -- DATA_SRC_ID       <- DATASRCID
         );

      -- Segmento #6 FINSFinancialLegalNames (OPTIMISTICUPDATE) -> FINANCIAL_LEGAL_NAMES
      FORALL i IN 1 .. l_k.COUNT
         INSERT INTO financial_legal_names (
             flg_oid,
             flg_legal_nme,
             inst_mnem,
             start_tms,
             last_chg_tms,
             last_chg_usr_id,
             data_src_id,
             data_stat_typ)
         VALUES (
             l_k(i).k_flg_oid,                          -- FLG_OID           <- FLGOID = f-uFI7(qW1 (clave nueva)
             'PROBANDO',                                -- FLG_LEGAL_NME     <- FLGLEGALNME
             l_k(i).k_inst_mnem,                        -- INST_MNEM         <- INSTMNEM = f-uBI7(qW1 (clave nueva)
             l_ahora,                                   -- START_TMS         <- STARTTMS (momento de la llamada)
             l_ahora,                                   -- LAST_CHG_TMS      <- LASTCHGTMS (momento de la llamada)
             c_usuario,                                 -- LAST_CHG_USR_ID   <- LASTCHGUSRID (marca sintética)
             'ABACO',                                   -- DATA_SRC_ID       <- DATASRCID
             'ACTIVE'                                   -- DATA_STAT_TYP     <- DATASTATTYP
         );

      -- Segmento #8 FINSFinancialInstitutionRole (INSERT) -> FT_T_FINR
      FORALL i IN 1 .. l_k.COUNT
         INSERT INTO ft_t_finr (
             inst_mnem,
             finsrl_typ,
             last_chg_tms,
             last_chg_usr_id,
             start_tms,
             pref_id_ctxt_typ,
             data_stat_typ,
             data_src_id,
             finsrl_sub_typ,
             finr_oid)
         VALUES (
             l_k(i).k_inst_mnem,                        -- INST_MNEM         <- INSTMNEM = f-uBI7(qW1 (clave nueva)
             'INDVDUAL',                                -- FINSRL_TYP        <- FINSRLTYP
             l_ahora,                                   -- LAST_CHG_TMS      <- LASTCHGTMS (momento de la llamada)
             c_usuario,                                 -- LAST_CHG_USR_ID   <- LASTCHGUSRID (marca sintética)
             l_ahora,                                   -- START_TMS         <- STARTTMS (momento de la llamada)
             'Y',                                       -- PREF_ID_CTXT_TYP  <- PREFIDCTXTTYP
             'ACTIVE',                                  -- DATA_STAT_TYP     <- DATASTATTYP
             'RDR',                                     -- DATA_SRC_ID       <- DATASRCID
             'BUSINESS',                                -- FINSRL_SUB_TYP    <- FINSRLSUBTYP
             l_k(i).k_finr_oid                          -- FINR_OID          <- FINROID = f-uCI7(qW1 (clave nueva)
         );

      -- Segmento #9 FINRFinsFinsRoleRelationship (INSERT) -> FT_T_FIRL
      FORALL i IN 1 .. l_k.COUNT
         INSERT INTO ft_t_firl (
             firl_oid,
             prnt_inst_mnem,
             inst_mnem,
             finsrl_typ,
             rel_typ,
             start_tms,
             last_chg_tms,
             last_chg_usr_id,
             data_stat_typ,
             data_src_id,
             finr_oid)
         VALUES (
             l_k(i).k_firl_oid,                         -- FIRL_OID          <- clave nueva (NEW_OID)
             l_k(i).k_inst_mnem,                        -- PRNT_INST_MNEM    <- PRNTINSTMNEM = f-uBI7(qW1 (clave nueva)
             l_k(i).k_inst_mnem,                        -- INST_MNEM         <- INSTMNEM = f-uBI7(qW1 (clave nueva)
             'INDVDUAL',                                -- FINSRL_TYP        <- FINSRLTYP
             'GLOBAL',                                  -- REL_TYP           <- RELTYP
             l_ahora,                                   -- START_TMS         <- STARTTMS (momento de la llamada)
             l_ahora,                                   -- LAST_CHG_TMS      <- LASTCHGTMS (momento de la llamada)
             c_usuario,                                 -- LAST_CHG_USR_ID   <- LASTCHGUSRID (marca sintética)
             'ACTIVE',                                  -- DATA_STAT_TYP     <- DATASTATTYP
             'RDR',                                     -- DATA_SRC_ID       <- DATASRCID
             l_k(i).k_finr_oid                          -- FINR_OID          <- FINROID = f-uCI7(qW1 (clave nueva)
         );

      -- Segmento #10 FINREnterpriseFinancialInstitutionRole (INSERT) -> FT_T_ENFR
      FORALL i IN 1 .. l_k.COUNT
         INSERT INTO ft_t_enfr (
             enfr_oid,
             org_id,
             finr_inst_mnem,
             finsrl_typ,
             enfr_rl_typ,
             start_tms,
             last_chg_tms,
             last_chg_usr_id,
             data_stat_typ,
             data_src_id,
             finr_oid)
         VALUES (
             l_k(i).k_enfr_oid,                         -- ENFR_OID          <- ENFROID = f-uDI7(qW1 (clave nueva)
             '0182',                                    -- ORG_ID            <- ORGID
             l_k(i).k_inst_mnem,                        -- FINR_INST_MNEM    <- FINRINSTMNEM = f-uBI7(qW1 (clave nueva)
             'INDVDUAL',                                -- FINSRL_TYP        <- FINSRLTYP
             'ENT_OWN',                                 -- ENFR_RL_TYP       <- ENFRRLTYP
             l_ahora,                                   -- START_TMS         <- STARTTMS (momento de la llamada)
             l_ahora,                                   -- LAST_CHG_TMS      <- LASTCHGTMS (momento de la llamada)
             c_usuario,                                 -- LAST_CHG_USR_ID   <- LASTCHGUSRID (marca sintética)
             'ACTIVE',                                  -- DATA_STAT_TYP     <- DATASTATTYP
             'RDR',                                     -- DATA_SRC_ID       <- DATASRCID
             l_k(i).k_finr_oid                          -- FINR_OID          <- FINROID = f-uCI7(qW1 (clave nueva)
         );

      -- Segmento #11 FINREnterpriseFinancialInstitutionRole (INSERT) -> FT_T_ENFR
      FORALL i IN 1 .. l_k.COUNT
         INSERT INTO ft_t_enfr (
             enfr_oid,
             org_id,
             finr_inst_mnem,
             finsrl_typ,
             enfr_rl_typ,
             start_tms,
             last_chg_tms,
             last_chg_usr_id,
             data_stat_typ,
             data_src_id,
             finr_oid)
         VALUES (
             l_k(i).k_enfr_oid_2,                       -- ENFR_OID          <- ENFROID = f-uEI7(qW1 (clave nueva)
             'A18',                                     -- ORG_ID            <- ORGID
             l_k(i).k_inst_mnem,                        -- FINR_INST_MNEM    <- FINRINSTMNEM = f-uBI7(qW1 (clave nueva)
             'INDVDUAL',                                -- FINSRL_TYP        <- FINSRLTYP
             'BRANCH_OWN',                              -- ENFR_RL_TYP       <- ENFRRLTYP
             l_ahora,                                   -- START_TMS         <- STARTTMS (momento de la llamada)
             l_ahora,                                   -- LAST_CHG_TMS      <- LASTCHGTMS (momento de la llamada)
             c_usuario,                                 -- LAST_CHG_USR_ID   <- LASTCHGUSRID (marca sintética)
             'ACTIVE',                                  -- DATA_STAT_TYP     <- DATASTATTYP
             'RDR',                                     -- DATA_SRC_ID       <- DATASRCID
             l_k(i).k_finr_oid                          -- FINR_OID          <- FINROID = f-uCI7(qW1 (clave nueva)
         );

      -- Segmento #12 FinsRoleClassification (INSERT) -> FT_T_FRCL
      FORALL i IN 1 .. l_k.COUNT
         INSERT INTO ft_t_frcl (
             finr_clsf_oid,
             inst_mnem,
             finsrl_typ,
             indus_cl_set_id,
             clsf_oid,
             cl_value,
             start_tms,
             last_chg_tms,
             last_chg_usr_id,
             data_stat_typ,
             data_src_id,
             finr_oid)
         VALUES (
             l_k(i).k_finr_clsf_oid,                    -- FINR_CLSF_OID     <- clave nueva (NEW_OID)
             l_k(i).k_inst_mnem,                        -- INST_MNEM         <- INSTMNEM = f-uBI7(qW1 (clave nueva)
             'INDVDUAL',                                -- FINSRL_TYP        <- FINSRLTYP
             'TPFINF',                                  -- INDUS_CL_SET_ID   <- INDUSCLSETID
             '=002DCDB88',                              -- CLSF_OID          <- CLSFOID
             'FINANCIAL',                               -- CL_VALUE          <- CLVALUE
             l_ahora,                                   -- START_TMS         <- STARTTMS (momento de la llamada)
             l_ahora,                                   -- LAST_CHG_TMS      <- LASTCHGTMS (momento de la llamada)
             c_usuario,                                 -- LAST_CHG_USR_ID   <- LASTCHGUSRID (marca sintética)
             'ACTIVE',                                  -- DATA_STAT_TYP     <- DATASTATTYP
             'RDR',                                     -- DATA_SRC_ID       <- DATASRCID
             l_k(i).k_finr_oid                          -- FINR_OID          <- FINROID = f-uCI7(qW1 (clave nueva)
         );

      pkg_sint_nucleo.traza('CONTRAPARTIDA_GLOBAL: ' || p_cantidad || ' entidad(es), '
                            || p_cantidad * gc_filas_por_entidad || ' filas');
   EXCEPTION
      WHEN OTHERS THEN
         pkg_sint_nucleo.traza('CONTRAPARTIDA_GLOBAL: ERROR ' || SQLERRM);
         BEGIN
            ROLLBACK TO SAVEPOINT sp_contrapartida_global;
         EXCEPTION
            WHEN OTHERS THEN NULL;  -- error anterior al SAVEPOINT: no hay nada que deshacer
         END;
         RAISE;
   END generar;

END sint_e_contrapartida_global;
/
