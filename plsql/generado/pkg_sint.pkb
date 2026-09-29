CREATE OR REPLACE PACKAGE BODY pkg_sint
AS
/*******************************************************************************
 * GENERADO AUTOMÁTICAMENTE por herramientas/generar_plsql.py — NO EDITAR A MANO.
 * Para cambiarlo: modificar el mensaje XML o mensajes_entrada/catalogo.json y regenerar.
 * El núcleo se escribe a mano en plsql/fuente/ y se inserta aquí al generar.
 *
 * PKG_SINT — GENERADOR DE LA BBDD SINTÉTICA (único paquete, D-023)
 *
 *    EXEC pkg_sint.crear_bbdd;      -- borra lo sintético previo, crea todo, verifica y COMMIT
 *    EXEC pkg_sint.eliminar_bbdd;   -- borra todos los registros 'TESTING:RDR' y COMMIT
 *    EXEC pkg_sint.resumen;         -- filas sintéticas por tabla
 *
 * Organización:
 *    1. NÚCLEO      utilidades comunes (plsql/fuente/)
 *    2. ENTIDADES   un procedimiento crear_<entidad> por mensaje, agrupados por unidad
 *    3. API         crear_bbdd, eliminar_bbdd, resumen, verificar
 *
 * Entidades: 1 · Variaciones: 0 · Tablas gestionadas: 8
 *   Unidad Procedimiento                  Filas  Mensaje
 *   FINS   crear_contrapartida_global       10 filas  mensajes_entrada/Ejemplo_Alta_Contrapartida_Global.xml
 ******************************************************************************/

   -- #########################################################################
   -- 1. NÚCLEO
   -- #########################################################################

   /* ==========================================================================
    * NÚCLEO — PARTE PRIVADA (fragmento escrito a mano)
    * Fuente: plsql/fuente/nucleo_cuerpo.sql. El generador lo inserta al principio
    * del cuerpo de PKG_SINT. No se ejecuta por separado.
    *
    * Utilidades que usan los procedimientos de entidad y la API:
    *   traza, nuevo_oid, validar_cantidad, exigir_referencia,
    *   contar, resumen_tablas, purgar_tablas.
    * ======================================================================== */

   TYPE t_lista_tablas  IS TABLE OF VARCHAR2(128);
   TYPE t_lista_numeros IS TABLE OF PLS_INTEGER;

   g_trazas_activas BOOLEAN := TRUE;

   -- ORA-02292: existen registros hijos que referencian la fila a borrar.
   e_hijos_existentes EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_hijos_existentes, -2292);

   -- ---- Datos generados (API) -------------------------------------------------
   -- Tablas gestionadas en orden de primera inserción (resumen y verificación).
   g_tablas CONSTANT t_lista_tablas := t_lista_tablas(
      'FT_T_FINS',
      'FT_T_FIST',
      'FT_T_FIGU',
      'FINANCIAL_LEGAL_NAMES',
      'FT_T_FINR',
      'FT_T_FIRL',
      'FT_T_ENFR',
      'FT_T_FRCL');

   -- Filas sintéticas esperadas tras crear_bbdd, en el mismo orden que g_tablas.
   g_filas_esperadas CONSTANT t_lista_numeros := t_lista_numeros(
      1,
      2,
      1,
      1,
      1,
      1,
      2,
      1);

   -- Orden de borrado: hijas antes que padres (calculado a partir de las FKs).
   g_tablas_purga CONSTANT t_lista_tablas := t_lista_tablas(
      'FT_T_FRCL',
      'FT_T_ENFR',
      'FT_T_FIRL',
      'FT_T_FINR',
      'FINANCIAL_LEGAL_NAMES',
      'FT_T_FIGU',
      'FT_T_FIST',
      'FT_T_FINS');
   -- ---------------------------------------------------------------------------
   -- (El generador sustituye la línea anterior por las listas de tablas gestionadas,
   --  el orden de purga y los conteos esperados: en PL/SQL las declaraciones deben ir
   --  antes que cualquier procedimiento del cuerpo.)

   ----------------------------------------------------------------------------
   -- Trazas
   ----------------------------------------------------------------------------

   PROCEDURE set_trazas (p_activas IN BOOLEAN)
   IS
   BEGIN
      g_trazas_activas := NVL(p_activas, TRUE);
   END set_trazas;

   PROCEDURE traza (p_texto IN VARCHAR2)
   IS
   BEGIN
      IF g_trazas_activas THEN
         DBMS_OUTPUT.put_line(TO_CHAR(SYSTIMESTAMP, 'HH24:MI:SS.FF3') || ' | ' || p_texto);
      END IF;
   END traza;

   ----------------------------------------------------------------------------
   -- Claves y validaciones
   ----------------------------------------------------------------------------

   /* OID nuevo de GoldenSource (D-008). Único punto de llamada a NEW_OID. */
   FUNCTION nuevo_oid RETURN VARCHAR2
   IS
   BEGIN
      RETURN new_oid;
   END nuevo_oid;

   /* ge_parametro_invalido si p_cantidad no está en 1..gc_max_entidades. */
   PROCEDURE validar_cantidad (p_cantidad IN PLS_INTEGER)
   IS
   BEGIN
      IF p_cantidad IS NULL OR p_cantidad NOT BETWEEN 1 AND gc_max_entidades THEN
         RAISE_APPLICATION_ERROR(ge_parametro_invalido,
            'Cantidad de entidades fuera de rango (1..' || gc_max_entidades || '): ' || p_cantidad);
      END IF;
   END validar_cantidad;

   /* ge_referencia_no_existe si el dato maestro no se ha encontrado (D-019). */
   PROCEDURE exigir_referencia (p_encontradas IN PLS_INTEGER,
                                p_descripcion IN VARCHAR2)
   IS
   BEGIN
      IF NVL(p_encontradas, 0) = 0 THEN
         RAISE_APPLICATION_ERROR(ge_referencia_no_existe,
            'Dato de referencia no encontrado: ' || p_descripcion);
      END IF;
   END exigir_referencia;

   ----------------------------------------------------------------------------
   -- Conteo, resumen y purga sobre listas de tablas
   ----------------------------------------------------------------------------

   /* Nombre de tabla validado para SQL dinámico (protección frente a inyección). */
   FUNCTION tabla_segura (p_tabla IN VARCHAR2) RETURN VARCHAR2
   IS
   BEGIN
      RETURN DBMS_ASSERT.sql_object_name(DBMS_ASSERT.simple_sql_name(p_tabla));
   END tabla_segura;

   /* Nº de filas sintéticas de una tabla. */
   FUNCTION contar (p_tabla IN VARCHAR2) RETURN PLS_INTEGER
   IS
      l_filas PLS_INTEGER;
   BEGIN
      EXECUTE IMMEDIATE
         'SELECT COUNT(*) FROM ' || tabla_segura(p_tabla) || ' WHERE last_chg_usr_id = :usr'
         INTO l_filas
         USING gc_usuario_sintetico;
      RETURN l_filas;
   END contar;

   /* Filas sintéticas de cada tabla de la lista, por DBMS_OUTPUT. */
   PROCEDURE resumen_tablas (p_tablas IN t_lista_tablas)
   IS
      l_total PLS_INTEGER := 0;
      l_filas PLS_INTEGER;
   BEGIN
      traza('Filas sintéticas (' || gc_usuario_sintetico || ') por tabla:');
      FOR i IN 1 .. p_tablas.COUNT LOOP
         l_filas := contar(p_tablas(i));
         l_total := l_total + l_filas;
         traza('   ' || RPAD(p_tablas(i), 30) || LPAD(l_filas, 10));
      END LOOP;
      traza('   ' || RPAD('TOTAL', 30) || LPAD(l_total, 10));
   END resumen_tablas;

   /* Borra TODAS las filas sintéticas de las tablas de la lista, en el orden dado
      (hijas antes que padres). Atómica: si falla, no borra nada (D-006). */
   PROCEDURE purgar_tablas (p_tablas IN t_lista_tablas,
                            p_commit IN BOOLEAN)
   IS
      l_total PLS_INTEGER := 0;
      l_filas PLS_INTEGER;
      l_tabla VARCHAR2(128);
   BEGIN
      traza('Borrando datos sintéticos (' || gc_usuario_sintetico || ')');
      SAVEPOINT sp_purga;

      FOR i IN 1 .. p_tablas.COUNT LOOP
         l_tabla := p_tablas(i);
         EXECUTE IMMEDIATE
            'DELETE FROM ' || tabla_segura(l_tabla) || ' WHERE last_chg_usr_id = :usr'
            USING gc_usuario_sintetico;
         l_filas := SQL%ROWCOUNT;
         l_total := l_total + l_filas;
         IF l_filas > 0 THEN
            traza('   ' || RPAD(l_tabla, 30) || LPAD(l_filas, 10) || ' filas borradas');
         END IF;
      END LOOP;

      IF p_commit THEN
         COMMIT;
      END IF;
      traza('Borradas ' || l_total || ' filas sintéticas' ||
            CASE WHEN p_commit THEN ' (COMMIT)' ELSE ' (pendiente de COMMIT)' END);
   EXCEPTION
      WHEN e_hijos_existentes THEN
         -- Registros NO sintéticos (p. ej. creados por las pruebas) cuelgan de un
         -- registro sintético mediante una FK activa. Se deshace la purga entera.
         ROLLBACK TO SAVEPOINT sp_purga;
         RAISE_APPLICATION_ERROR(ge_purga_bloqueada,
            'Purga deshecha: hay registros hijos no sintéticos que referencian filas de ' ||
            l_tabla || '. Ver P-008. ' || SQLERRM);
      WHEN OTHERS THEN
         ROLLBACK TO SAVEPOINT sp_purga;
         RAISE;
   END purgar_tablas;

   -- #########################################################################
   -- ENTIDADES — UNIDAD FINS
   -- #########################################################################

   -- ==========================================================================
   -- CONTRAPARTIDA_GLOBAL — mensaje mensajes_entrada/Ejemplo_Alta_Contrapartida_Global.xml
   -- ==========================================================================
   PROCEDURE crear_contrapartida_global (
      p_cantidad IN PLS_INTEGER DEFAULT 1)
   IS
      c_usuario           CONSTANT VARCHAR2(30) := gc_usuario_sintetico;
      c_filas_por_entidad CONSTANT PLS_INTEGER  := 10;
      l_ahora             CONSTANT DATE         := SYSDATE;   -- START_TMS y LAST_CHG_TMS (D-007)

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

      l_existe  PLS_INTEGER;
      l_k       t_lista_claves;
   BEGIN
      validar_cantidad(p_cantidad);

      -------------------------------------------------------------------------
      -- 1. Datos maestros referenciados: deben existir (D-019)
      -------------------------------------------------------------------------
      -- FT_T_STDF (STAT_DEF_ID = UKFIRM) <- FT_T_FIST.STAT_DEF_ID
      SELECT COUNT(*) INTO l_existe FROM ft_t_stdf
       WHERE stat_def_id = 'UKFIRM';
      exigir_referencia(l_existe, 'FT_T_STDF: ' || 'STAT_DEF_ID = UKFIRM');

      -- FT_T_GUNT (GUNT_OID = GUNT3B2===) <- FT_T_FIGU.GUNT_OID
      SELECT COUNT(*) INTO l_existe FROM ft_t_gunt
       WHERE gunt_oid = 'GUNT3B2===';
      exigir_referencia(l_existe, 'FT_T_GUNT: ' || 'GUNT_OID = GUNT3B2===');

      -- FT_T_STDF (STAT_DEF_ID = MIFIFIRM) <- FT_T_FIST.STAT_DEF_ID
      SELECT COUNT(*) INTO l_existe FROM ft_t_stdf
       WHERE stat_def_id = 'MIFIFIRM';
      exigir_referencia(l_existe, 'FT_T_STDF: ' || 'STAT_DEF_ID = MIFIFIRM');

      -- FT_T_ENTR (ORG_ID = 0182) <- FT_T_ENFR.ORG_ID
      SELECT COUNT(*) INTO l_existe FROM ft_t_entr
       WHERE org_id = '0182';
      exigir_referencia(l_existe, 'FT_T_ENTR: ' || 'ORG_ID = 0182');

      -- FT_T_ENTR (ORG_ID = A18) <- FT_T_ENFR.ORG_ID
      SELECT COUNT(*) INTO l_existe FROM ft_t_entr
       WHERE org_id = 'A18';
      exigir_referencia(l_existe, 'FT_T_ENTR: ' || 'ORG_ID = A18');

      -- FT_T_INCL (CLSF_OID = =002DCDB88) <- FT_T_FRCL.CLSF_OID
      SELECT COUNT(*) INTO l_existe FROM ft_t_incl
       WHERE clsf_oid = '=002DCDB88';
      exigir_referencia(l_existe, 'FT_T_INCL: ' || 'CLSF_OID = =002DCDB88');

      -------------------------------------------------------------------------
      -- 2. Claves internas nuevas para cada entidad
      -------------------------------------------------------------------------
      FOR i IN 1 .. p_cantidad LOOP
         l_k(i).k_inst_mnem         := nuevo_oid;
         l_k(i).k_stat_id           := nuevo_oid;
         l_k(i).k_figu_oid          := nuevo_oid;
         l_k(i).k_stat_id_2         := nuevo_oid;
         l_k(i).k_flg_oid           := nuevo_oid;
         l_k(i).k_finr_oid          := nuevo_oid;
         l_k(i).k_firl_oid          := nuevo_oid;
         l_k(i).k_enfr_oid          := nuevo_oid;
         l_k(i).k_enfr_oid_2        := nuevo_oid;
         l_k(i).k_finr_clsf_oid     := nuevo_oid;
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

      traza('CONTRAPARTIDA_GLOBAL: ' || p_cantidad || ' entidad(es), '
                            || p_cantidad * c_filas_por_entidad || ' filas');
   EXCEPTION
      WHEN OTHERS THEN
         traza('CONTRAPARTIDA_GLOBAL: ERROR ' || SQLERRM);
         BEGIN
            ROLLBACK TO SAVEPOINT sp_contrapartida_global;
         EXCEPTION
            WHEN OTHERS THEN NULL;  -- error anterior al SAVEPOINT: no hay nada que deshacer
         END;
         RAISE;
   END crear_contrapartida_global;

   -- #########################################################################
   -- 3. API
   -- #########################################################################

   PROCEDURE resumen
   IS
   BEGIN
      resumen_tablas(g_tablas);
   END resumen;

   PROCEDURE verificar
   IS
      l_errores VARCHAR2(4000);
      l_filas   PLS_INTEGER;
   BEGIN
      FOR i IN 1 .. g_tablas.COUNT LOOP
         l_filas := contar(g_tablas(i));
         IF l_filas <> g_filas_esperadas(i) THEN
            l_errores := SUBSTR(l_errores || ' ' || g_tablas(i) || '=' || l_filas
                                || ' (esperadas ' || g_filas_esperadas(i) || ')', 1, 4000);
         END IF;
      END LOOP;
      IF l_errores IS NOT NULL THEN
         RAISE_APPLICATION_ERROR(ge_verificacion_fallida, 'Filas sintéticas inesperadas:' || l_errores);
      END IF;
      traza('Verificación correcta: todas las tablas tienen las filas esperadas');
   END verificar;

   PROCEDURE eliminar_bbdd (p_commit IN BOOLEAN DEFAULT TRUE)
   IS
   BEGIN
      purgar_tablas(g_tablas_purga, p_commit);
   END eliminar_bbdd;

   PROCEDURE crear_bbdd (p_limpiar_antes IN BOOLEAN DEFAULT TRUE,
                         p_commit        IN BOOLEAN DEFAULT TRUE)
   IS
   BEGIN
      traza('=== Creación de la BBDD sintética ===');
      SAVEPOINT sp_crear_bbdd;

      IF p_limpiar_antes THEN
         purgar_tablas(g_tablas_purga, p_commit => FALSE);
      END IF;

      -------------------------------------------------------------------------
      -- 1. Entidades de los mensajes (una entidad idéntica a cada mensaje)
      -------------------------------------------------------------------------
      crear_contrapartida_global;   -- FINS: mensajes_entrada/Ejemplo_Alta_Contrapartida_Global.xml

      -------------------------------------------------------------------------
      -- 2. Variaciones solicitadas por chat (mensajes_entrada/catalogo.json)
      -------------------------------------------------------------------------
      NULL;  -- ninguna

      IF p_limpiar_antes THEN
         verificar;
      END IF;
      IF p_commit THEN
         COMMIT;
      END IF;
      resumen;
      traza('=== BBDD sintética creada' ||
            CASE WHEN p_commit THEN ' (COMMIT)' ELSE ' (pendiente de COMMIT)' END || ' ===');
   EXCEPTION
      WHEN OTHERS THEN
         ROLLBACK TO SAVEPOINT sp_crear_bbdd;
         traza('ERROR: creación deshecha. ' || SQLERRM);
         RAISE;
   END crear_bbdd;

END pkg_sint;
/
