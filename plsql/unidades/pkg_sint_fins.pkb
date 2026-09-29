CREATE OR REPLACE PACKAGE BODY pkg_sint_fins
AS
/*******************************************************************************
 * Cuerpo de PKG_SINT_FINS. Ver cabecera en la especificación (.pks).
 ******************************************************************************/

   ----------------------------------------------------------------------------
   -- Constantes de la Contrapartida Global (valores fijos tomados del mensaje)
   ----------------------------------------------------------------------------
   gc_fuente_nombre_legal CONSTANT VARCHAR2(40) := 'ABACO';      -- DATA_SRC_ID en FINANCIAL_LEGAL_NAMES
   gc_stat_uk_firm        CONSTANT VARCHAR2(8)  := 'UKFIRM';     -- FT_T_FIST.STAT_DEF_ID
   gc_stat_mifid_firm     CONSTANT VARCHAR2(8)  := 'MIFIFIRM';   -- FT_T_FIST.STAT_DEF_ID
   gc_stat_valor_si       CONSTANT VARCHAR2(1)  := 'Y';          -- FT_T_FIST.STAT_CHAR_VAL_TXT
   gc_gu_tipo_pais        CONSTANT VARCHAR2(8)  := 'COUNTRY';    -- FT_T_FIGU.GU_TYP
   gc_gu_cnt_pais         CONSTANT NUMBER       := 1;            -- FT_T_FIGU.GU_CNT
   gc_gu_proposito        CONSTANT VARCHAR2(8)  := 'STSMNTCT';   -- FT_T_FIGU.FINS_GU_PURP_TYP
   gc_rol_tipo            CONSTANT VARCHAR2(8)  := 'INDVDUAL';   -- FINSRL_TYP
   gc_rol_subtipo         CONSTANT VARCHAR2(20) := 'BUSINESS';   -- FT_T_FINR.FINSRL_SUB_TYP
   gc_rol_pref_id_ctxt    CONSTANT VARCHAR2(20) := 'Y';          -- FT_T_FINR.PREF_ID_CTXT_TYP (tal cual en el mensaje)
   gc_relacion_global     CONSTANT VARCHAR2(20) := 'GLOBAL';     -- FT_T_FIRL.REL_TYP
   gc_enfr_entidad        CONSTANT VARCHAR2(20) := 'ENT_OWN';    -- FT_T_ENFR.ENFR_RL_TYP
   gc_enfr_sucursal       CONSTANT VARCHAR2(20) := 'BRANCH_OWN'; -- FT_T_ENFR.ENFR_RL_TYP
   gc_clsf_conjunto       CONSTANT VARCHAR2(10) := 'TPFINF';     -- FT_T_FRCL.INDUS_CL_SET_ID
   gc_clsf_valor          CONSTANT VARCHAR2(40) := 'FINANCIAL';  -- FT_T_FRCL.CL_VALUE

   gc_digitos_secuencia   CONSTANT PLS_INTEGER  := 5;            -- 'SINT CPTY GLOBAL 00001'
   gc_max_long_prefijo    CONSTANT PLS_INTEGER  := 200;          -- FLG_LEGAL_NME es VARCHAR2(256)

   ----------------------------------------------------------------------------
   -- Tipos: claves generadas por entidad
   ----------------------------------------------------------------------------
   -- Se generan TODAS las claves en memoria antes de insertar, de modo que cada
   -- tabla se carga con una única sentencia FORALL (ver docs/OPTIMIZACION_ORACLE.md).
   TYPE t_contrapartida IS RECORD (
      nombre             ft_t_fins.inst_nme%TYPE,
      inst_mnem          ft_t_fins.inst_mnem%TYPE,
      stat_id_uk         ft_t_fist.stat_id%TYPE,
      stat_id_mifid      ft_t_fist.stat_id%TYPE,
      figu_oid           ft_t_figu.figu_oid%TYPE,
      flg_oid            financial_legal_names.flg_oid%TYPE,
      finr_oid           ft_t_finr.finr_oid%TYPE,
      firl_oid           ft_t_firl.firl_oid%TYPE,
      enfr_oid_entidad   ft_t_enfr.enfr_oid%TYPE,
      enfr_oid_sucursal  ft_t_enfr.enfr_oid%TYPE,
      finr_clsf_oid      ft_t_frcl.finr_clsf_oid%TYPE
   );
   TYPE t_contrapartidas IS TABLE OF t_contrapartida INDEX BY PLS_INTEGER;

   ----------------------------------------------------------------------------
   -- GENERAR_CONTRAPARTIDA_GLOBAL
   ----------------------------------------------------------------------------
   PROCEDURE generar_contrapartida_global (
      p_cantidad            IN PLS_INTEGER DEFAULT 1,
      p_prefijo_nombre      IN VARCHAR2    DEFAULT 'SINT CPTY GLOBAL',
      p_numero_inicial      IN PLS_INTEGER DEFAULT 1,
      p_pais                IN VARCHAR2    DEFAULT 'AF',
      p_org_id_entidad      IN VARCHAR2    DEFAULT '0182',
      p_org_id_sucursal     IN VARCHAR2    DEFAULT 'A18',
      p_fecha_constitucion  IN DATE        DEFAULT DATE '2026-09-29',
      p_commit              IN BOOLEAN     DEFAULT FALSE)
   IS
      -- Alias cortos de las constantes del núcleo (legibilidad de los INSERT).
      c_usuario   CONSTANT VARCHAR2(30) := pkg_sint_nucleo.gc_usuario_sintetico;
      c_activo    CONSTANT VARCHAR2(20) := pkg_sint_nucleo.gc_estado_activo;
      c_fuente    CONSTANT VARCHAR2(40) := pkg_sint_nucleo.gc_fuente_rdr;

      l_ahora     CONSTANT DATE := SYSDATE;   -- START_TMS y LAST_CHG_TMS de toda la llamada (D-007)
      l_gunt_oid  ft_t_figu.gunt_oid%TYPE;
      l_clsf_oid  ft_t_frcl.clsf_oid%TYPE;
      l_cptys     t_contrapartidas;
   BEGIN
      pkg_sint_nucleo.traza('Contrapartida Global: generando ' || p_cantidad || ' entidad(es)');

      -------------------------------------------------------------------------
      -- 1. Validación de parámetros
      -------------------------------------------------------------------------
      pkg_sint_nucleo.validar_cantidad(p_cantidad);
      IF p_prefijo_nombre IS NULL OR LENGTH(p_prefijo_nombre) > gc_max_long_prefijo THEN
         RAISE_APPLICATION_ERROR(pkg_sint_nucleo.ge_parametro_invalido,
            'p_prefijo_nombre obligatorio y de como máximo ' || gc_max_long_prefijo || ' caracteres');
      END IF;

      -------------------------------------------------------------------------
      -- 2. Datos de referencia: se resuelven UNA vez por llamada (no por fila).
      --    Si alguno no existe se aborta antes de insertar nada.
      -------------------------------------------------------------------------
      l_gunt_oid := pkg_sint_nucleo.oid_unidad_geografica(p_pais, gc_gu_tipo_pais, gc_gu_cnt_pais);
      l_clsf_oid := pkg_sint_nucleo.oid_clasificacion(gc_clsf_conjunto, gc_clsf_valor);
      pkg_sint_nucleo.validar_estadistico(gc_stat_uk_firm);
      pkg_sint_nucleo.validar_estadistico(gc_stat_mifid_firm);
      pkg_sint_nucleo.validar_organizacion(p_org_id_entidad);
      pkg_sint_nucleo.validar_organizacion(p_org_id_sucursal);

      -------------------------------------------------------------------------
      -- 3. Generación de nombres y claves (OIDs) en memoria
      -------------------------------------------------------------------------
      FOR i IN 1 .. p_cantidad LOOP
         l_cptys(i).nombre            := p_prefijo_nombre || ' ' ||
                                         LPAD(p_numero_inicial + i - 1, gc_digitos_secuencia, '0');
         l_cptys(i).inst_mnem         := pkg_sint_nucleo.nuevo_oid;
         l_cptys(i).stat_id_uk        := pkg_sint_nucleo.nuevo_oid;
         l_cptys(i).stat_id_mifid     := pkg_sint_nucleo.nuevo_oid;
         l_cptys(i).figu_oid          := pkg_sint_nucleo.nuevo_oid;
         l_cptys(i).flg_oid           := pkg_sint_nucleo.nuevo_oid;
         l_cptys(i).finr_oid          := pkg_sint_nucleo.nuevo_oid;
         l_cptys(i).firl_oid          := pkg_sint_nucleo.nuevo_oid;
         l_cptys(i).enfr_oid_entidad  := pkg_sint_nucleo.nuevo_oid;
         l_cptys(i).enfr_oid_sucursal := pkg_sint_nucleo.nuevo_oid;
         l_cptys(i).finr_clsf_oid     := pkg_sint_nucleo.nuevo_oid;
      END LOOP;

      SAVEPOINT sp_contrapartida_global;

      -------------------------------------------------------------------------
      -- 4. Inserciones en bloque (FORALL), en orden padre -> hijas
      -------------------------------------------------------------------------

      -- 4.1 FT_T_FINS: institución financiera (segmento FinancialInstitution)
      FORALL i IN 1 .. l_cptys.COUNT
         INSERT INTO ft_t_fins
            (inst_mnem, inst_nme, inst_desc, inst_legal_nme, inst_founding_dte,
             data_src_id, data_stat_typ, start_tms, last_chg_tms, last_chg_usr_id)
         VALUES
            (l_cptys(i).inst_mnem, l_cptys(i).nombre, l_cptys(i).nombre, l_cptys(i).nombre, p_fecha_constitucion,
             c_fuente, c_activo, l_ahora, l_ahora, c_usuario);

      -- 4.2 FT_T_FIST: estadísticos UKFIRM y MIFIFIRM (segmento FinancialInstitutionStatistic x2)
      FORALL i IN 1 .. l_cptys.COUNT
         INSERT INTO ft_t_fist
            (stat_id, stat_def_id, inst_mnem, stat_char_val_txt,
             data_src_id, data_stat_typ, start_tms, last_chg_tms, last_chg_usr_id)
         VALUES
            (l_cptys(i).stat_id_uk, gc_stat_uk_firm, l_cptys(i).inst_mnem, gc_stat_valor_si,
             c_fuente, c_activo, l_ahora, l_ahora, c_usuario);

      FORALL i IN 1 .. l_cptys.COUNT
         INSERT INTO ft_t_fist
            (stat_id, stat_def_id, inst_mnem, stat_char_val_txt,
             data_src_id, data_stat_typ, start_tms, last_chg_tms, last_chg_usr_id)
         VALUES
            (l_cptys(i).stat_id_mifid, gc_stat_mifid_firm, l_cptys(i).inst_mnem, gc_stat_valor_si,
             c_fuente, c_activo, l_ahora, l_ahora, c_usuario);

      -- 4.3 FT_T_FIGU: participación geográfica (segmento FinancialInstitutionGeoUnitPrt)
      FORALL i IN 1 .. l_cptys.COUNT
         INSERT INTO ft_t_figu
            (figu_oid, inst_mnem, gu_id, gu_typ, gu_cnt, gunt_oid, fins_gu_purp_typ,
             data_src_id, data_stat_typ, start_tms, last_chg_tms, last_chg_usr_id)
         VALUES
            (l_cptys(i).figu_oid, l_cptys(i).inst_mnem, p_pais, gc_gu_tipo_pais, gc_gu_cnt_pais, l_gunt_oid,
             gc_gu_proposito, c_fuente, c_activo, l_ahora, l_ahora, c_usuario);

      -- 4.4 FINANCIAL_LEGAL_NAMES: nombre legal (segmento FINSFinancialLegalNames, OPTIMISTICUPDATE -> INSERT)
      FORALL i IN 1 .. l_cptys.COUNT
         INSERT INTO financial_legal_names
            (flg_oid, flg_legal_nme, inst_mnem,
             data_src_id, data_stat_typ, start_tms, last_chg_tms, last_chg_usr_id)
         VALUES
            (l_cptys(i).flg_oid, l_cptys(i).nombre, l_cptys(i).inst_mnem,
             gc_fuente_nombre_legal, c_activo, l_ahora, l_ahora, c_usuario);

      -- 4.5 FT_T_FINR: rol de la institución (segmento FINSFinancialInstitutionRole)
      FORALL i IN 1 .. l_cptys.COUNT
         INSERT INTO ft_t_finr
            (finr_oid, inst_mnem, finsrl_typ, finsrl_sub_typ, pref_id_ctxt_typ,
             data_src_id, data_stat_typ, start_tms, last_chg_tms, last_chg_usr_id)
         VALUES
            (l_cptys(i).finr_oid, l_cptys(i).inst_mnem, gc_rol_tipo, gc_rol_subtipo, gc_rol_pref_id_ctxt,
             c_fuente, c_activo, l_ahora, l_ahora, c_usuario);

      -- 4.6 FT_T_FIRL: relación GLOBAL; la institución es su propia matriz
      --     (segmento FINRFinsFinsRoleRelationship: INSTMNEM = PRNTINSTMNEM)
      FORALL i IN 1 .. l_cptys.COUNT
         INSERT INTO ft_t_firl
            (firl_oid, finr_oid, inst_mnem, prnt_inst_mnem, finsrl_typ, rel_typ,
             data_src_id, data_stat_typ, start_tms, last_chg_tms, last_chg_usr_id)
         VALUES
            (l_cptys(i).firl_oid, l_cptys(i).finr_oid, l_cptys(i).inst_mnem, l_cptys(i).inst_mnem,
             gc_rol_tipo, gc_relacion_global, c_fuente, c_activo, l_ahora, l_ahora, c_usuario);

      -- 4.7 FT_T_ENFR: roles frente a entidad y sucursal
      --     (segmento FINREnterpriseFinancialInstitutionRole x2; el mensaje no informa INST_MNEM)
      FORALL i IN 1 .. l_cptys.COUNT
         INSERT INTO ft_t_enfr
            (enfr_oid, org_id, finr_oid, finr_inst_mnem, finsrl_typ, enfr_rl_typ,
             data_src_id, data_stat_typ, start_tms, last_chg_tms, last_chg_usr_id)
         VALUES
            (l_cptys(i).enfr_oid_entidad, p_org_id_entidad, l_cptys(i).finr_oid, l_cptys(i).inst_mnem,
             gc_rol_tipo, gc_enfr_entidad, c_fuente, c_activo, l_ahora, l_ahora, c_usuario);

      FORALL i IN 1 .. l_cptys.COUNT
         INSERT INTO ft_t_enfr
            (enfr_oid, org_id, finr_oid, finr_inst_mnem, finsrl_typ, enfr_rl_typ,
             data_src_id, data_stat_typ, start_tms, last_chg_tms, last_chg_usr_id)
         VALUES
            (l_cptys(i).enfr_oid_sucursal, p_org_id_sucursal, l_cptys(i).finr_oid, l_cptys(i).inst_mnem,
             gc_rol_tipo, gc_enfr_sucursal, c_fuente, c_activo, l_ahora, l_ahora, c_usuario);

      -- 4.8 FT_T_FRCL: clasificación del rol (segmento FinsRoleClassification)
      FORALL i IN 1 .. l_cptys.COUNT
         INSERT INTO ft_t_frcl
            (finr_clsf_oid, finr_oid, inst_mnem, finsrl_typ, indus_cl_set_id, clsf_oid, cl_value,
             data_src_id, data_stat_typ, start_tms, last_chg_tms, last_chg_usr_id)
         VALUES
            (l_cptys(i).finr_clsf_oid, l_cptys(i).finr_oid, l_cptys(i).inst_mnem, gc_rol_tipo,
             gc_clsf_conjunto, l_clsf_oid, gc_clsf_valor, c_fuente, c_activo, l_ahora, l_ahora, c_usuario);

      -------------------------------------------------------------------------
      -- 5. Cierre
      -------------------------------------------------------------------------
      IF p_commit THEN
         COMMIT;
      END IF;
      pkg_sint_nucleo.traza('Contrapartida Global: ' || l_cptys.COUNT || ' entidad(es) creada(s) ('
                            || l_cptys(1).nombre || ' .. ' || l_cptys(l_cptys.COUNT).nombre || ')'
                            || CASE WHEN p_commit THEN ' (COMMIT)' ELSE ' (pendiente de COMMIT)' END);
   EXCEPTION
      WHEN OTHERS THEN
         -- Se deshace sólo lo insertado en esta llamada; el resto de la transacción
         -- del llamador queda intacto. Si el error fue anterior al SAVEPOINT no hay nada que deshacer.
         BEGIN
            ROLLBACK TO SAVEPOINT sp_contrapartida_global;
         EXCEPTION
            WHEN OTHERS THEN NULL;  -- ORA-01086: savepoint aún no establecido
         END;
         pkg_sint_nucleo.traza('Contrapartida Global: ERROR ' || SQLERRM);
         RAISE;
   END generar_contrapartida_global;

END pkg_sint_fins;
/
