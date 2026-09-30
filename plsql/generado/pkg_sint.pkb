CREATE OR REPLACE PACKAGE BODY pkg_sint
AS
/*******************************************************************************
 * GENERADO AUTOMÁTICAMENTE por herramientas/generar_plsql.py — NO EDITAR A MANO.
 * Para cambiarlo: modificar el mensaje XML o mensajes_entrada/catalogo.json y regenerar.
 * El núcleo se escribe a mano en plsql/fuente/ y se inserta aquí al generar.
 *
 * PKG_SINT — GENERADOR DE LA BBDD SINTÉTICA (único paquete, D-023)
 *
 *    EXEC pkg_sint.crear_bbdd;      -- SÓLO inserta toda la BBDD sintética y COMMIT (rápido)
 *    EXEC pkg_sint.eliminar_bbdd;   -- SÓLO borra lo insertado, por clave, y COMMIT (rápido)
 *    EXEC pkg_sint.resumen;         -- filas sintéticas registradas por tabla
 *    EXEC pkg_sint.limpiar_restos;  -- (ocasional, LENTO) borra por LAST_CHG_USR_ID lo no registrado
 *
 * Cada fila creada se anota en la tabla SINT_REGISTRO (tabla, columna PK, clave), de modo
 * que borrar y verificar van por clave primaria y no recorren tablas de millones de filas.
 *
 * Organización:
 *    1. NÚCLEO      utilidades comunes (plsql/fuente/)
 *    2. ENTIDADES   un procedimiento crear_<entidad> por mensaje, agrupados por unidad
 *    3. API         crear_bbdd, eliminar_bbdd, resumen, verificar, limpiar_restos
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
    *   - traza, nuevo_oid, validar_cantidad, exigir_referencia
    *   - registro de claves SINT_REGISTRO (D-024): hay_registro, borrar_registrados,
    *     resumen_registro, verificar_registro  -> operaciones RÁPIDAS (por índice)
    *   - purgar_por_usuario: borrado LENTO por LAST_CHG_USR_ID (sólo para restos)
    * ======================================================================== */

   TYPE t_lista_tablas  IS TABLE OF VARCHAR2(128);
   TYPE t_lista_numeros IS TABLE OF PLS_INTEGER;
   TYPE t_lista_claves  IS TABLE OF sint_registro.clave%TYPE;

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
   --  el orden de borrado y los conteos esperados: en PL/SQL las declaraciones deben
   --  ir antes que cualquier procedimiento del cuerpo.)

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

   /* Identificador validado para SQL dinámico (protección frente a inyección). */
   FUNCTION nombre_seguro (p_nombre IN VARCHAR2) RETURN VARCHAR2
   IS
   BEGIN
      RETURN DBMS_ASSERT.simple_sql_name(p_nombre);
   END nombre_seguro;

   ----------------------------------------------------------------------------
   -- Registro de claves SINT_REGISTRO (D-024)
   -- Cada fila sintética creada deja en SINT_REGISTRO su tabla, la columna de su
   -- PK y el valor de la clave. Borrar, contar y verificar van por clave primaria
   -- (índice) y NUNCA recorren las tablas de GoldenSource (millones de filas).
   ----------------------------------------------------------------------------

   /* TRUE si hay claves registradas (la BBDD sintética está creada). */
   FUNCTION hay_registro RETURN BOOLEAN
   IS
      l_n PLS_INTEGER;
   BEGIN
      SELECT COUNT(*) INTO l_n FROM sint_registro WHERE ROWNUM = 1;
      RETURN l_n > 0;
   END hay_registro;

   /* Borra por PK las filas registradas de UNA tabla y quita sus claves del
      registro. Devuelve el nº de filas borradas. */
   FUNCTION borrar_tabla_registrada (p_tabla IN VARCHAR2) RETURN PLS_INTEGER
   IS
      l_columna sint_registro.columna_pk%TYPE;
      l_claves  t_lista_claves;
      l_filas   PLS_INTEGER := 0;
   BEGIN
      SELECT MAX(columna_pk) INTO l_columna FROM sint_registro WHERE tabla = p_tabla;
      IF l_columna IS NULL THEN
         RETURN 0;                                  -- nada registrado en esta tabla
      END IF;
      SELECT clave BULK COLLECT INTO l_claves FROM sint_registro WHERE tabla = p_tabla;

      -- Un DELETE por clave, enviado en bloque (FORALL): acceso por el índice de la PK.
      FORALL i IN 1 .. l_claves.COUNT
         EXECUTE IMMEDIATE
            'DELETE FROM ' || DBMS_ASSERT.sql_object_name(nombre_seguro(p_tabla)) ||
            ' WHERE ' || nombre_seguro(l_columna) || ' = :clave'
            USING l_claves(i);
      l_filas := SQL%ROWCOUNT;

      DELETE FROM sint_registro WHERE tabla = p_tabla;
      RETURN l_filas;
   END borrar_tabla_registrada;

   /* Borra todas las filas registradas: primero las tablas de p_orden (hijas antes
      que padres) y después las que queden en el registro (p. ej. de entidades que
      ya no están en el catálogo). Atómico: si falla, no borra nada (D-006). */
   PROCEDURE borrar_registrados (p_orden  IN t_lista_tablas,
                                 p_commit IN BOOLEAN)
   IS
      l_total  PLS_INTEGER := 0;
      l_filas  PLS_INTEGER;
      l_tabla  VARCHAR2(128);
      l_inicio PLS_INTEGER;                 -- centésimas de segundo (DBMS_UTILITY.get_time)
      l_global PLS_INTEGER := DBMS_UTILITY.get_time;

      FUNCTION segundos (p_desde IN PLS_INTEGER) RETURN VARCHAR2 IS
      BEGIN
         RETURN TO_CHAR((DBMS_UTILITY.get_time - p_desde) / 100, 'FM99990D00') || ' s';
      END segundos;
   BEGIN
      traza('Borrando datos sintéticos registrados en SINT_REGISTRO');
      SAVEPOINT sp_borrar;

      -- Se mide cada tabla: si alguna tarda, es que otras tablas tienen FKs activas SIN
      -- índice hacia ella y Oracle las recorre por cada fila borrada (D-026).
      FOR i IN 1 .. p_orden.COUNT LOOP
         l_tabla  := p_orden(i);
         l_inicio := DBMS_UTILITY.get_time;
         l_filas  := borrar_tabla_registrada(l_tabla);
         l_total  := l_total + l_filas;
         IF l_filas > 0 THEN
            traza('   ' || RPAD(l_tabla, 30) || LPAD(l_filas, 10) || ' filas borradas en ' || segundos(l_inicio));
         END IF;
      END LOOP;

      FOR r IN (SELECT DISTINCT tabla FROM sint_registro) LOOP   -- tablas fuera del catálogo actual
         l_tabla := r.tabla;
         l_filas := borrar_tabla_registrada(l_tabla);
         l_total := l_total + l_filas;
         traza('   ' || RPAD(l_tabla, 30) || LPAD(l_filas, 10) || ' filas borradas (fuera del catálogo)');
      END LOOP;

      IF p_commit THEN
         COMMIT;
      END IF;
      traza('Borradas ' || l_total || ' filas sintéticas en ' || segundos(l_global) ||
            CASE WHEN p_commit THEN ' (COMMIT)' ELSE ' (pendiente de COMMIT)' END);
   EXCEPTION
      WHEN e_hijos_existentes THEN
         -- Registros NO sintéticos (p. ej. creados por las pruebas) cuelgan de un
         -- registro sintético mediante una FK activa. Se deshace el borrado entero.
         ROLLBACK TO SAVEPOINT sp_borrar;
         RAISE_APPLICATION_ERROR(ge_purga_bloqueada,
            'Borrado deshecho: hay registros hijos no sintéticos que referencian filas de ' ||
            l_tabla || '. Ver P-008. ' || SQLERRM);
      WHEN OTHERS THEN
         ROLLBACK TO SAVEPOINT sp_borrar;
         RAISE;
   END borrar_registrados;

   /* Filas sintéticas registradas por tabla (sólo lee SINT_REGISTRO). */
   PROCEDURE resumen_registro
   IS
      l_total PLS_INTEGER := 0;
   BEGIN
      traza('Filas sintéticas registradas por tabla:');
      FOR r IN (SELECT tabla, COUNT(*) AS filas FROM sint_registro GROUP BY tabla ORDER BY tabla) LOOP
         traza('   ' || RPAD(r.tabla, 30) || LPAD(r.filas, 10));
         l_total := l_total + r.filas;
      END LOOP;
      traza('   ' || RPAD('TOTAL', 30) || LPAD(l_total, 10));
   END resumen_registro;

   /* Comprueba, para cada tabla de p_tablas, que el registro tiene las filas
      esperadas y que todas existen realmente en la tabla (búsqueda por PK). */
   PROCEDURE verificar_registro (p_tablas    IN t_lista_tablas,
                                 p_esperadas IN t_lista_numeros)
   IS
      l_errores     VARCHAR2(4000);
      l_registradas PLS_INTEGER;
      l_existentes  PLS_INTEGER;
      l_columna     sint_registro.columna_pk%TYPE;
   BEGIN
      FOR i IN 1 .. p_tablas.COUNT LOOP
         SELECT COUNT(*), MAX(columna_pk) INTO l_registradas, l_columna
           FROM sint_registro WHERE tabla = p_tablas(i);
         l_existentes := 0;
         IF l_registradas > 0 THEN
            -- Recorre el registro (pequeño) y busca cada clave por el índice de la PK.
            EXECUTE IMMEDIATE
               'SELECT COUNT(*) FROM sint_registro r WHERE r.tabla = :t AND EXISTS (SELECT 1 FROM ' ||
               DBMS_ASSERT.sql_object_name(nombre_seguro(p_tablas(i))) || ' x WHERE x.' ||
               nombre_seguro(l_columna) || ' = r.clave)'
               INTO l_existentes USING p_tablas(i);
         END IF;
         IF l_registradas <> p_esperadas(i) OR l_existentes <> l_registradas THEN
            l_errores := SUBSTR(l_errores || ' ' || p_tablas(i) || ': registradas=' || l_registradas ||
                                ', existentes=' || l_existentes || ', esperadas=' || p_esperadas(i) || ';', 1, 4000);
         END IF;
      END LOOP;
      IF l_errores IS NOT NULL THEN
         RAISE_APPLICATION_ERROR(ge_verificacion_fallida, 'Verificación fallida:' || l_errores);
      END IF;
      traza('Verificación correcta: todas las filas registradas existen y cuadran con lo esperado');
   END verificar_registro;

   ----------------------------------------------------------------------------
   -- Borrado LENTO por LAST_CHG_USR_ID (sólo para restos sin registrar)
   ----------------------------------------------------------------------------

   /* Borra TODAS las filas con LAST_CHG_USR_ID = gc_usuario_sintetico de las tablas
      de la lista (hijas antes que padres) y vacía el registro. Recorre las tablas
      completas: sólo para restos de versiones anteriores o datos no registrados. */
   PROCEDURE purgar_por_usuario (p_tablas IN t_lista_tablas,
                                 p_commit IN BOOLEAN)
   IS
      l_total PLS_INTEGER := 0;
      l_filas PLS_INTEGER;
      l_tabla VARCHAR2(128);
   BEGIN
      traza('Borrado COMPLETO por LAST_CHG_USR_ID = ' || gc_usuario_sintetico || ' (lento)');
      SAVEPOINT sp_purga;

      FOR i IN 1 .. p_tablas.COUNT LOOP
         l_tabla := p_tablas(i);
         EXECUTE IMMEDIATE
            'DELETE FROM ' || DBMS_ASSERT.sql_object_name(nombre_seguro(l_tabla)) ||
            ' WHERE last_chg_usr_id = :usr'
            USING gc_usuario_sintetico;
         l_filas := SQL%ROWCOUNT;
         l_total := l_total + l_filas;
         traza('   ' || RPAD(l_tabla, 30) || LPAD(l_filas, 10) || ' filas borradas');
      END LOOP;
      DELETE FROM sint_registro;

      IF p_commit THEN
         COMMIT;
      END IF;
      traza('Borradas ' || l_total || ' filas sintéticas' ||
            CASE WHEN p_commit THEN ' (COMMIT)' ELSE ' (pendiente de COMMIT)' END);
   EXCEPTION
      WHEN e_hijos_existentes THEN
         ROLLBACK TO SAVEPOINT sp_purga;
         RAISE_APPLICATION_ERROR(ge_purga_bloqueada,
            'Borrado deshecho: hay registros hijos no sintéticos que referencian filas de ' ||
            l_tabla || '. Ver P-008. ' || SQLERRM);
      WHEN OTHERS THEN
         ROLLBACK TO SAVEPOINT sp_purga;
         RAISE;
   END purgar_por_usuario;

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
      c_entidad           CONSTANT VARCHAR2(30) := 'CONTRAPARTIDA_GLOBAL';
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
      FORALL i IN 1 .. l_k.COUNT   -- clave en SINT_REGISTRO para el borrado rápido (D-024)
         INSERT INTO sint_registro (tabla, columna_pk, clave, entidad)
         VALUES ('FT_T_FINS', 'INST_MNEM', l_k(i).k_inst_mnem, c_entidad);

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
      FORALL i IN 1 .. l_k.COUNT   -- clave en SINT_REGISTRO para el borrado rápido (D-024)
         INSERT INTO sint_registro (tabla, columna_pk, clave, entidad)
         VALUES ('FT_T_FIST', 'STAT_ID', l_k(i).k_stat_id, c_entidad);

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
      FORALL i IN 1 .. l_k.COUNT   -- clave en SINT_REGISTRO para el borrado rápido (D-024)
         INSERT INTO sint_registro (tabla, columna_pk, clave, entidad)
         VALUES ('FT_T_FIGU', 'FIGU_OID', l_k(i).k_figu_oid, c_entidad);

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
      FORALL i IN 1 .. l_k.COUNT   -- clave en SINT_REGISTRO para el borrado rápido (D-024)
         INSERT INTO sint_registro (tabla, columna_pk, clave, entidad)
         VALUES ('FT_T_FIST', 'STAT_ID', l_k(i).k_stat_id_2, c_entidad);

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
      FORALL i IN 1 .. l_k.COUNT   -- clave en SINT_REGISTRO para el borrado rápido (D-024)
         INSERT INTO sint_registro (tabla, columna_pk, clave, entidad)
         VALUES ('FINANCIAL_LEGAL_NAMES', 'FLG_OID', l_k(i).k_flg_oid, c_entidad);

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
      FORALL i IN 1 .. l_k.COUNT   -- clave en SINT_REGISTRO para el borrado rápido (D-024)
         INSERT INTO sint_registro (tabla, columna_pk, clave, entidad)
         VALUES ('FT_T_FINR', 'FINR_OID', l_k(i).k_finr_oid, c_entidad);

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
      FORALL i IN 1 .. l_k.COUNT   -- clave en SINT_REGISTRO para el borrado rápido (D-024)
         INSERT INTO sint_registro (tabla, columna_pk, clave, entidad)
         VALUES ('FT_T_FIRL', 'FIRL_OID', l_k(i).k_firl_oid, c_entidad);

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
      FORALL i IN 1 .. l_k.COUNT   -- clave en SINT_REGISTRO para el borrado rápido (D-024)
         INSERT INTO sint_registro (tabla, columna_pk, clave, entidad)
         VALUES ('FT_T_ENFR', 'ENFR_OID', l_k(i).k_enfr_oid, c_entidad);

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
      FORALL i IN 1 .. l_k.COUNT   -- clave en SINT_REGISTRO para el borrado rápido (D-024)
         INSERT INTO sint_registro (tabla, columna_pk, clave, entidad)
         VALUES ('FT_T_ENFR', 'ENFR_OID', l_k(i).k_enfr_oid_2, c_entidad);

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
      FORALL i IN 1 .. l_k.COUNT   -- clave en SINT_REGISTRO para el borrado rápido (D-024)
         INSERT INTO sint_registro (tabla, columna_pk, clave, entidad)
         VALUES ('FT_T_FRCL', 'FINR_CLSF_OID', l_k(i).k_finr_clsf_oid, c_entidad);

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
      resumen_registro;
   END resumen;

   PROCEDURE verificar
   IS
   BEGIN
      verificar_registro(g_tablas, g_filas_esperadas);
   END verificar;

   PROCEDURE eliminar_bbdd (p_commit IN BOOLEAN DEFAULT TRUE)
   IS
   BEGIN
      borrar_registrados(g_tablas_purga, p_commit);
   END eliminar_bbdd;

   PROCEDURE limpiar_restos (p_commit IN BOOLEAN DEFAULT TRUE)
   IS
   BEGIN
      purgar_por_usuario(g_tablas_purga, p_commit);
   END limpiar_restos;

   PROCEDURE crear_bbdd (p_commit IN BOOLEAN DEFAULT TRUE)
   IS
   BEGIN
      traza('=== Creación de la BBDD sintética ===');
      IF hay_registro THEN
         RAISE_APPLICATION_ERROR(ge_bbdd_ya_creada,
            'Ya existe una BBDD sintética registrada: ejecute antes EXEC pkg_sint.eliminar_bbdd;');
      END IF;
      SAVEPOINT sp_crear_bbdd;

      -------------------------------------------------------------------------
      -- 1. Entidades de los mensajes (una entidad idéntica a cada mensaje)
      -------------------------------------------------------------------------
      crear_contrapartida_global;   -- FINS: mensajes_entrada/Ejemplo_Alta_Contrapartida_Global.xml

      -------------------------------------------------------------------------
      -- 2. Variaciones solicitadas por chat (mensajes_entrada/catalogo.json)
      -------------------------------------------------------------------------
      NULL;  -- ninguna

      verificar;          -- por clave primaria: sólo lee las filas recién creadas
      IF p_commit THEN
         COMMIT;
      END IF;
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
