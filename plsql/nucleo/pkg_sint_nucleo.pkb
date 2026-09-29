CREATE OR REPLACE PACKAGE BODY pkg_sint_nucleo
AS
/*******************************************************************************
 * Cuerpo de PKG_SINT_NUCLEO. Ver cabecera en la especificación (.pks).
 ******************************************************************************/

   ----------------------------------------------------------------------------
   -- Tablas gestionadas por el generador
   ----------------------------------------------------------------------------
   -- Lista en ORDEN DE INSERCIÓN (padres primero). La purga la recorre en orden
   -- inverso (hijas primero) para no violar claves ajenas.
   -- >>> Cada entidad nueva debe añadir aquí sus tablas en la posición correcta. <<<
   TYPE t_lista_tablas IS TABLE OF VARCHAR2(128);

   g_tablas_gestionadas CONSTANT t_lista_tablas := t_lista_tablas(
      -- Unidad FINS: Contrapartida Global (PKG_SINT_FINS)
      'FT_T_FINS',              -- Institución financiera (raíz)
      'FT_T_FIST',              -- Estadísticos de la institución
      'FT_T_FIGU',              -- Participación geográfica
      'FINANCIAL_LEGAL_NAMES',  -- Nombres legales (tabla custom, D-010)
      'FT_T_FINR',              -- Rol de la institución
      'FT_T_FIRL',              -- Relación entre roles
      'FT_T_ENFR',              -- Rol respecto a entidad organizativa
      'FT_T_FRCL'               -- Clasificación del rol
   );

   g_trazas_activas  BOOLEAN := TRUE;

   -- ORA-02292: existen registros hijos que referencian la fila a borrar.
   e_hijos_existentes EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_hijos_existentes, -2292);

   ----------------------------------------------------------------------------
   -- Utilidades
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

   FUNCTION fecha_xml (p_texto IN VARCHAR2) RETURN DATE DETERMINISTIC
   IS
   BEGIN
      RETURN TO_DATE(p_texto, gc_formato_fecha_xml, gc_nls_fecha_xml);
   END fecha_xml;

   FUNCTION nuevo_oid RETURN VARCHAR2
   IS
   BEGIN
      -- NEW_OID es la función de GoldenSource que genera claves internas únicas
      -- (CHAR(10)). Se encapsula aquí para poder cambiar su invocación en un único sitio.
      RETURN new_oid;
   END nuevo_oid;

   PROCEDURE validar_cantidad (p_cantidad IN PLS_INTEGER)
   IS
   BEGIN
      IF p_cantidad IS NULL OR p_cantidad NOT BETWEEN 1 AND gc_max_entidades THEN
         RAISE_APPLICATION_ERROR(ge_parametro_invalido,
            'Cantidad de entidades fuera de rango (1..' || gc_max_entidades || '): ' || p_cantidad);
      END IF;
   END validar_cantidad;

   /* Nombre de tabla validado para SQL dinámico (protección frente a inyección). */
   FUNCTION tabla_segura (p_tabla IN VARCHAR2) RETURN VARCHAR2
   IS
   BEGIN
      RETURN DBMS_ASSERT.sql_object_name(DBMS_ASSERT.simple_sql_name(p_tabla));
   END tabla_segura;

   PROCEDURE error_referencia (p_texto IN VARCHAR2)
   IS
   BEGIN
      RAISE_APPLICATION_ERROR(ge_referencia_no_existe, 'Dato de referencia no encontrado: ' || p_texto);
   END error_referencia;

   ----------------------------------------------------------------------------
   -- Datos de referencia
   -- Nota: las variables locales se declaran con %TYPE de la columna. Si la columna
   -- es CHAR, Oracle compara con semántica "blank-padded" y 'TPFINF' encuentra
   -- 'TPFINF    '. Con un VARCHAR2 la comparación NO rellena y no encontraría la fila.
   ----------------------------------------------------------------------------

   FUNCTION oid_unidad_geografica (p_gu_id  IN VARCHAR2,
                                   p_gu_typ IN VARCHAR2,
                                   p_gu_cnt IN NUMBER) RETURN VARCHAR2
   IS
      l_gu_id    ft_t_gunt.gu_id%TYPE  := p_gu_id;
      l_gu_typ   ft_t_gunt.gu_typ%TYPE := p_gu_typ;
      l_gunt_oid ft_t_gunt.gunt_oid%TYPE;
   BEGIN
      SELECT gunt_oid
        INTO l_gunt_oid
        FROM ft_t_gunt
       WHERE gu_id   = l_gu_id
         AND gu_typ  = l_gu_typ
         AND gu_cnt  = p_gu_cnt
         AND end_tms IS NULL;
      RETURN l_gunt_oid;
   EXCEPTION
      WHEN NO_DATA_FOUND OR TOO_MANY_ROWS THEN
         error_referencia('FT_T_GUNT (' || p_gu_id || ', ' || p_gu_typ || ', ' || p_gu_cnt || ') - '
                          || SQLERRM);
   END oid_unidad_geografica;

   FUNCTION oid_clasificacion (p_indus_cl_set_id IN VARCHAR2,
                               p_cl_value        IN VARCHAR2) RETURN VARCHAR2
   IS
      l_set_id   ft_t_incl.indus_cl_set_id%TYPE := p_indus_cl_set_id;
      l_clsf_oid ft_t_incl.clsf_oid%TYPE;
   BEGIN
      SELECT clsf_oid
        INTO l_clsf_oid
        FROM ft_t_incl
       WHERE indus_cl_set_id = l_set_id
         AND cl_value        = p_cl_value
         AND end_tms IS NULL;
      RETURN l_clsf_oid;
   EXCEPTION
      WHEN NO_DATA_FOUND OR TOO_MANY_ROWS THEN
         error_referencia('FT_T_INCL (' || p_indus_cl_set_id || ', ' || p_cl_value || ') - ' || SQLERRM);
   END oid_clasificacion;

   PROCEDURE validar_estadistico (p_stat_def_id IN VARCHAR2)
   IS
      l_id     ft_t_stdf.stat_def_id%TYPE := p_stat_def_id;
      l_existe PLS_INTEGER;
   BEGIN
      SELECT COUNT(*) INTO l_existe FROM ft_t_stdf WHERE stat_def_id = l_id AND end_tms IS NULL;
      IF l_existe = 0 THEN
         error_referencia('FT_T_STDF (' || p_stat_def_id || ')');
      END IF;
   END validar_estadistico;

   PROCEDURE validar_organizacion (p_org_id IN VARCHAR2)
   IS
      l_id     ft_t_entr.org_id%TYPE := p_org_id;
      l_existe PLS_INTEGER;
   BEGIN
      SELECT COUNT(*) INTO l_existe FROM ft_t_entr WHERE org_id = l_id AND end_tms IS NULL;
      IF l_existe = 0 THEN
         error_referencia('FT_T_ENTR (' || p_org_id || ')');
      END IF;
   END validar_organizacion;

   ----------------------------------------------------------------------------
   -- Resumen y purga
   ----------------------------------------------------------------------------

   PROCEDURE resumen
   IS
      l_filas PLS_INTEGER;
   BEGIN
      traza('Resumen de filas sintéticas (' || gc_usuario_sintetico || ')');
      FOR i IN 1 .. g_tablas_gestionadas.COUNT LOOP
         EXECUTE IMMEDIATE
            'SELECT COUNT(*) FROM ' || tabla_segura(g_tablas_gestionadas(i)) ||
            ' WHERE last_chg_usr_id = :usr'
            INTO l_filas
            USING gc_usuario_sintetico;
         traza('   ' || RPAD(g_tablas_gestionadas(i), 24) || LPAD(l_filas, 10));
      END LOOP;
   END resumen;

   PROCEDURE purgar (p_commit IN BOOLEAN DEFAULT FALSE)
   IS
      l_total PLS_INTEGER := 0;
      l_filas PLS_INTEGER;
      l_tabla VARCHAR2(128);
   BEGIN
      traza('Inicio purga de datos sintéticos (' || gc_usuario_sintetico || ')');
      SAVEPOINT sp_purga;

      -- Orden inverso al de inserción: primero las tablas hijas.
      FOR i IN REVERSE 1 .. g_tablas_gestionadas.COUNT LOOP
         l_tabla := g_tablas_gestionadas(i);
         EXECUTE IMMEDIATE
            'DELETE FROM ' || tabla_segura(l_tabla) || ' WHERE last_chg_usr_id = :usr'
            USING gc_usuario_sintetico;
         l_filas := SQL%ROWCOUNT;
         l_total := l_total + l_filas;
         traza('   ' || RPAD(l_tabla, 24) || LPAD(l_filas, 10) || ' filas borradas');
      END LOOP;

      IF p_commit THEN
         COMMIT;
      END IF;
      traza('Fin purga: ' || l_total || ' filas' ||
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
   END purgar;

END pkg_sint_nucleo;
/
