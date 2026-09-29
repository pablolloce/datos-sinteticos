CREATE OR REPLACE PACKAGE BODY pkg_sint_nucleo
AS
/*******************************************************************************
 * Cuerpo de PKG_SINT_NUCLEO. Ver cabecera en la especificación (.pks).
 ******************************************************************************/

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
      -- (10 caracteres). Se encapsula aquí para cambiar su invocación en un único sitio.
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

   ----------------------------------------------------------------------------
   -- Datos de referencia
   ----------------------------------------------------------------------------

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
   -- Resumen y purga
   ----------------------------------------------------------------------------

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

   PROCEDURE resumen (p_tablas IN t_lista_tablas)
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
   END resumen;

   PROCEDURE purgar (p_tablas IN t_lista_tablas,
                     p_commit IN BOOLEAN DEFAULT FALSE)
   IS
      l_total PLS_INTEGER := 0;
      l_filas PLS_INTEGER;
      l_tabla VARCHAR2(128);
   BEGIN
      traza('Borrando datos sintéticos (' || gc_usuario_sintetico || ')');
      SAVEPOINT sp_purga;

      -- La lista llega ya ordenada: primero las tablas hijas.
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
   END purgar;

END pkg_sint_nucleo;
/
