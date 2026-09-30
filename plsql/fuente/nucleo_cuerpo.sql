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

   -- <<DATOS_GENERADOS>>
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
      l_total PLS_INTEGER := 0;
      l_filas PLS_INTEGER;
      l_tabla VARCHAR2(128);
   BEGIN
      traza('Borrando datos sintéticos registrados en SINT_REGISTRO');
      SAVEPOINT sp_borrar;

      FOR i IN 1 .. p_orden.COUNT LOOP
         l_tabla := p_orden(i);
         l_filas := borrar_tabla_registrada(l_tabla);
         l_total := l_total + l_filas;
         IF l_filas > 0 THEN
            traza('   ' || RPAD(l_tabla, 30) || LPAD(l_filas, 10) || ' filas borradas');
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
      traza('Borradas ' || l_total || ' filas sintéticas' ||
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
