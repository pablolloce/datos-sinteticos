   /* ==========================================================================
    * NÚCLEO — PARTE PRIVADA (fragmento escrito a mano)
    * Fuente: plsql/fuente/nucleo_cuerpo.sql. El generador lo inserta al principio
    * del cuerpo de PKG_SINT. No se ejecuta por separado.
    *
    * Utilidades que usan los procedimientos de entidad y la API:
    *   - traza, nuevo_oid, validar_cantidad, exigir_referencia
    *   - registro de claves SINT_REGISTRO (D-024): hay_registro, resumen_registro,
    *     verificar_registro -> operaciones RÁPIDAS (por índice)
    *   - eliminación en segundo plano (D-027): marcar_para_borrar (inmediato),
    *     lanzar_job_borrado, borrar_pendientes (lo ejecuta el job), informe_borrado
    *   - índices auxiliares temporales para el borrado (D-028): crear_indices_temporales,
    *     borrar_indices_temporales
    *   - purgar_por_usuario: borrado LENTO por LAST_CHG_USR_ID (sólo para restos)
    * ======================================================================== */

   TYPE t_lista_tablas  IS TABLE OF VARCHAR2(128);
   TYPE t_lista_numeros IS TABLE OF PLS_INTEGER;
   TYPE t_lista_claves  IS TABLE OF sint_registro.clave%TYPE;

   g_trazas_activas BOOLEAN := TRUE;

   -- Estados de una clave en SINT_REGISTRO (D-027).
   gc_activo   CONSTANT VARCHAR2(10) := 'ACTIVO';     -- fila creada y vigente
   gc_borrando CONSTANT VARCHAR2(10) := 'BORRANDO';   -- eliminación pedida; la borra el job

   -- Borrado en segundo plano (D-027).
   gc_prefijo_job    CONSTANT VARCHAR2(20) := 'SINT_ELIM_';   -- nombre de los jobs
   gc_bloque_borrado CONSTANT PLS_INTEGER  := 20;             -- claves por COMMIT

   -- Índices auxiliares temporales para el borrado (D-028).
   gc_prefijo_indice   CONSTANT VARCHAR2(20) := 'SINT_TMP_';  -- nombre de los índices
   gc_min_filas_padre  CONSTANT PLS_INTEGER  := 2;      -- con 1 fila padre, recorrer la hija es más barato
   gc_min_filas_hija   CONSTANT PLS_INTEGER  := 10000;  -- hijas más pequeñas: recorrerlas es instantáneo

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

   /* Validación del motor de GoldenSource replicada (D-035): si p_encontradas > 0, el
      motor rechazaría el mensaje con la notificación indicada; no se crea nada. */
   PROCEDURE rechazar_si_existe (p_encontradas IN PLS_INTEGER,
                                 p_regla       IN VARCHAR2,
                                 p_mensaje     IN VARCHAR2)
   IS
   BEGIN
      IF NVL(p_encontradas, 0) > 0 THEN
         RAISE_APPLICATION_ERROR(ge_rechazo_motor,
            'GoldenSource rechazaría el mensaje (' || p_regla || '): ' || p_mensaje);
      END IF;
   END rechazar_si_existe;

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

   /* TRUE si hay claves ACTIVAS registradas (la BBDD sintética está creada). Las claves
      en estado BORRANDO (borrado en segundo plano en curso) no cuentan. */
   FUNCTION hay_registro RETURN BOOLEAN
   IS
      l_n PLS_INTEGER;
   BEGIN
      SELECT COUNT(*) INTO l_n FROM sint_registro WHERE estado = gc_activo AND ROWNUM = 1;
      RETURN l_n > 0;
   END hay_registro;

   /* Segundos transcurridos desde p_desde (centésimas de DBMS_UTILITY.get_time). */
   FUNCTION segundos (p_desde IN PLS_INTEGER) RETURN VARCHAR2
   IS
   BEGIN
      RETURN TO_CHAR((DBMS_UTILITY.get_time - p_desde) / 100, 'FM999990D00') || ' s';
   END segundos;

   /* Tablas con claves en estado BORRANDO: primero las de p_orden (hijas antes que
      padres) y después las que sólo estén en el registro (entidades retiradas del catálogo). */
   FUNCTION tablas_pendientes (p_orden IN t_lista_tablas) RETURN t_lista_tablas
   IS
      l_tablas t_lista_tablas := t_lista_tablas();
      l_n      PLS_INTEGER;
      l_esta   BOOLEAN;
   BEGIN
      FOR i IN 1 .. p_orden.COUNT LOOP
         SELECT COUNT(*) INTO l_n FROM sint_registro
          WHERE tabla = p_orden(i) AND estado = gc_borrando AND ROWNUM = 1;
         IF l_n > 0 THEN
            l_tablas.EXTEND;
            l_tablas(l_tablas.LAST) := p_orden(i);
         END IF;
      END LOOP;
      FOR r IN (SELECT DISTINCT tabla FROM sint_registro WHERE estado = gc_borrando ORDER BY tabla) LOOP
         l_esta := FALSE;
         FOR i IN 1 .. l_tablas.COUNT LOOP
            l_esta := l_esta OR l_tablas(i) = r.tabla;
         END LOOP;
         IF NOT l_esta THEN
            l_tablas.EXTEND;
            l_tablas(l_tablas.LAST) := r.tabla;
         END IF;
      END LOOP;
      RETURN l_tablas;
   END tablas_pendientes;

   /* Paso 1 de la eliminación (inmediato): pasa todas las claves ACTIVAS a BORRANDO.
      Devuelve cuántas. A partir de aquí crear_bbdd puede volver a ejecutarse. */
   FUNCTION marcar_para_borrar RETURN PLS_INTEGER
   IS
      l_n PLS_INTEGER;
   BEGIN
      UPDATE sint_registro SET estado = gc_borrando WHERE estado = gc_activo;
      l_n := SQL%ROWCOUNT;
      COMMIT;
      RETURN l_n;
   END marcar_para_borrar;

   /* ÍNDICES AUXILIARES TEMPORALES (D-028)
      Al borrar una fila padre, Oracle comprueba cada FK activa de otras tablas hacia ella;
      si la columna de la hija no tiene índice, recorre la hija entera POR CADA FILA (D-026).
      Antes de borrar se crea, para cada FK así, un índice INVISIBLE (no cambia los planes de
      la aplicación) y ONLINE (no bloquea sus escrituras): cuesta una lectura de la hija por
      borrado, en lugar de una por fila padre. Al terminar se borran todos.
      Devuelve el nº de índices creados. */
   FUNCTION crear_indices_temporales (p_tablas IN t_lista_tablas) RETURN PLS_INTEGER
   IS
      l_pendientes PLS_INTEGER;
      l_nombre     VARCHAR2(128);
      l_existe     PLS_INTEGER;
      l_creados    PLS_INTEGER := 0;
      l_inicio     PLS_INTEGER;
      l_sql        VARCHAR2(1000);
      e_sin_online EXCEPTION;                       -- ORA-00439: ONLINE sólo en Enterprise
      PRAGMA EXCEPTION_INIT(e_sin_online, -439);
   BEGIN
      FOR i IN 1 .. p_tablas.COUNT LOOP
         SELECT COUNT(*) INTO l_pendientes FROM sint_registro
          WHERE tabla = p_tablas(i) AND estado = gc_borrando;
         CONTINUE WHEN l_pendientes < gc_min_filas_padre;

         -- FKs activas hacia esta tabla cuyas columnas no encabezan ningún índice de la hija
         FOR r IN (SELECT c.table_name AS hija, c.constraint_name AS fk,
                          (SELECT LISTAGG(cc.column_name, ', ') WITHIN GROUP (ORDER BY cc.position)
                             FROM user_cons_columns cc WHERE cc.constraint_name = c.constraint_name) AS columnas,
                          (SELECT t.num_rows FROM user_tables t WHERE t.table_name = c.table_name) AS filas
                     FROM user_constraints c
                     JOIN user_constraints p ON p.owner = c.r_owner AND p.constraint_name = c.r_constraint_name
                    WHERE c.constraint_type = 'R'
                      AND c.status = 'ENABLED'
                      AND p.table_name = p_tablas(i)
                      AND NOT EXISTS (
                          SELECT 1 FROM user_indexes x
                           WHERE x.table_name = c.table_name
                             AND NOT EXISTS (
                                 SELECT 1 FROM user_cons_columns cc
                                  WHERE cc.constraint_name = c.constraint_name
                                    AND NOT EXISTS (
                                        SELECT 1 FROM user_ind_columns ic
                                         WHERE ic.index_name = x.index_name
                                           AND ic.column_name = cc.column_name
                                           AND ic.column_position = cc.position)))
                    ORDER BY c.table_name, c.constraint_name)
         LOOP
            CONTINUE WHEN NVL(r.filas, gc_min_filas_hija) < gc_min_filas_hija;   -- sin estadísticas: se indexa

            -- Nombre determinista por FK: si ya existe (otro job, resto anterior), se reutiliza.
            l_nombre := gc_prefijo_indice || TO_CHAR(DBMS_UTILITY.get_hash_value(r.hija || '.' || r.fk, 1, 1073741823));
            SELECT COUNT(*) INTO l_existe FROM user_indexes WHERE index_name = l_nombre;
            CONTINUE WHEN l_existe > 0;

            l_inicio := DBMS_UTILITY.get_time;
            l_sql := 'CREATE INDEX ' || nombre_seguro(l_nombre) || ' ON ' ||
                     DBMS_ASSERT.sql_object_name(nombre_seguro(r.hija)) || ' (' || r.columnas || ') INVISIBLE';
            BEGIN
               EXECUTE IMMEDIATE l_sql || ' ONLINE';
            EXCEPTION
               WHEN e_sin_online THEN
                  EXECUTE IMMEDIATE l_sql;          -- sin ONLINE: bloquea escrituras en la hija mientras se crea
            END;
            l_creados := l_creados + 1;
            traza('   índice temporal ' || RPAD(l_nombre, 22) || ' ' || RPAD(r.hija || '(' || r.columnas || ')', 45) ||
                  LPAD(NVL(TO_CHAR(r.filas), '?'), 12) || ' filas  ' || segundos(l_inicio));
         END LOOP;
      END LOOP;
      RETURN l_creados;
   END crear_indices_temporales;

   /* Borra TODOS los índices auxiliares temporales (SINT_TMP_*). Devuelve cuántos. */
   FUNCTION borrar_indices_temporales RETURN PLS_INTEGER
   IS
      l_n PLS_INTEGER := 0;
   BEGIN
      FOR r IN (SELECT index_name FROM user_indexes
                 WHERE index_name LIKE gc_prefijo_indice || '%') LOOP
         EXECUTE IMMEDIATE 'DROP INDEX ' || nombre_seguro(r.index_name);
         l_n := l_n + 1;
      END LOOP;
      RETURN l_n;
   END borrar_indices_temporales;

   /* Paso 2 de la eliminación (lo ejecuta el job): borra FÍSICAMENTE las filas en estado
      BORRANDO:
        1. crea los índices auxiliares temporales (D-028);
        2. borra por PK, tabla a tabla en orden hijas -> padres, en bloques de
           gc_bloque_borrado claves con COMMIT por bloque (progreso visible y reanudable);
        3. borra los índices temporales, también si algo falla.
      Repite mientras queden filas pendientes (recoge lo marcado durante la ejecución). */
   PROCEDURE borrar_pendientes (p_orden IN t_lista_tablas)
   IS
      CURSOR c_claves (p_tabla IN VARCHAR2) IS
         SELECT clave FROM sint_registro WHERE tabla = p_tabla AND estado = gc_borrando;
      l_tablas  t_lista_tablas;
      l_tabla   VARCHAR2(128);
      l_columna sint_registro.columna_pk%TYPE;
      l_claves  t_lista_claves;
      l_filas   PLS_INTEGER;
      l_tabla_n PLS_INTEGER;
      l_total   PLS_INTEGER := 0;
      l_indices PLS_INTEGER;
      l_inicio  PLS_INTEGER;
      l_global  PLS_INTEGER := DBMS_UTILITY.get_time;

      PROCEDURE quitar_indices IS
      BEGIN
         l_inicio  := DBMS_UTILITY.get_time;
         l_indices := borrar_indices_temporales;
         IF l_indices > 0 THEN
            traza('Borrados ' || l_indices || ' índices temporales en ' || segundos(l_inicio));
         END IF;
      END quitar_indices;
   BEGIN
      traza('Borrado físico de las claves en estado BORRANDO');
      LOOP
         l_tablas := tablas_pendientes(p_orden);
         EXIT WHEN l_tablas.COUNT = 0;

         -- 1. Índices auxiliares temporales
         l_inicio  := DBMS_UTILITY.get_time;
         l_indices := crear_indices_temporales(l_tablas);
         IF l_indices > 0 THEN
            traza('Creados ' || l_indices || ' índices temporales en ' || segundos(l_inicio));
         END IF;

         -- 2. Borrado por PK, hijas -> padres
         FOR i IN 1 .. l_tablas.COUNT LOOP
            l_tabla   := l_tablas(i);
            l_tabla_n := 0;
            l_inicio  := DBMS_UTILITY.get_time;
            SELECT MAX(columna_pk) INTO l_columna FROM sint_registro WHERE tabla = l_tabla;

            OPEN c_claves(l_tabla);
            LOOP
               FETCH c_claves BULK COLLECT INTO l_claves LIMIT gc_bloque_borrado;
               EXIT WHEN l_claves.COUNT = 0;

               -- Un DELETE por clave, enviado en bloque (FORALL): acceso por el índice de la PK.
               FORALL j IN 1 .. l_claves.COUNT
                  EXECUTE IMMEDIATE
                     'DELETE FROM ' || DBMS_ASSERT.sql_object_name(nombre_seguro(l_tabla)) ||
                     ' WHERE ' || nombre_seguro(l_columna) || ' = :clave'
                     USING l_claves(j);
               l_filas := SQL%ROWCOUNT;

               FORALL j IN 1 .. l_claves.COUNT
                  DELETE FROM sint_registro WHERE tabla = l_tabla AND clave = l_claves(j);
               COMMIT;                                     -- bloque terminado

               l_tabla_n := l_tabla_n + l_filas;
               l_total   := l_total + l_filas;
            END LOOP;
            CLOSE c_claves;
            traza('   ' || RPAD(l_tabla, 30) || LPAD(l_tabla_n, 10) || ' filas borradas en ' || segundos(l_inicio));
         END LOOP;
      END LOOP;

      -- 3. Índices temporales fuera: el esquema queda como estaba
      quitar_indices;
      traza('Borradas ' || l_total || ' filas sintéticas en ' || segundos(l_global) || ' (COMMIT)');
   EXCEPTION
      WHEN e_hijos_existentes THEN
         -- Registros NO sintéticos (p. ej. creados por las pruebas) cuelgan de un registro
         -- sintético mediante una FK activa. Se deshace el bloque en curso; los bloques ya
         -- confirmados quedan borrados y el resto sigue en BORRANDO.
         ROLLBACK;
         IF c_claves%ISOPEN THEN CLOSE c_claves; END IF;
         BEGIN quitar_indices; EXCEPTION WHEN OTHERS THEN NULL; END;
         RAISE_APPLICATION_ERROR(ge_purga_bloqueada,
            'Borrado detenido: hay registros hijos no sintéticos que referencian filas de ' ||
            l_tabla || '. Ver P-008. ' || SQLERRM);
      WHEN OTHERS THEN
         ROLLBACK;
         IF c_claves%ISOPEN THEN CLOSE c_claves; END IF;
         BEGIN quitar_indices; EXCEPTION WHEN OTHERS THEN NULL; END;
         RAISE;
   END borrar_pendientes;

   /* Lanza un job de DBMS_SCHEDULER que ejecuta pkg_sint.ejecutar_borrado_pendiente. */
   FUNCTION lanzar_job_borrado RETURN VARCHAR2
   IS
      l_job     VARCHAR2(128) := gc_prefijo_job || TO_CHAR(SYSTIMESTAMP, 'YYYYMMDD_HH24MISSFF3');
      l_en_curso VARCHAR2(128);
   BEGIN
      -- Un solo job a la vez (los índices temporales son compartidos): si ya hay uno en
      -- curso, él recoge lo recién marcado (repite mientras queden filas pendientes).
      SELECT MAX(job_name) INTO l_en_curso FROM user_scheduler_running_jobs
       WHERE job_name LIKE gc_prefijo_job || '%';
      IF l_en_curso IS NOT NULL THEN
         RETURN l_en_curso || ' (ya en curso)';
      END IF;
      DBMS_SCHEDULER.create_job(
         job_name   => l_job,
         job_type   => 'PLSQL_BLOCK',
         job_action => 'BEGIN pkg_sint.ejecutar_borrado_pendiente; END;',
         enabled    => TRUE,
         auto_drop  => TRUE,
         comments   => 'Generador de datos sintéticos: borrado físico en segundo plano');
      RETURN l_job;
   END lanzar_job_borrado;

   /* Imprime, línea a línea, la salida completa de un job (BLOB en el juego de caracteres
      de la BBDD). Se convierte a CLOB entero para no partir caracteres multibyte. */
   PROCEDURE imprimir_salida (p_salida IN BLOB)
   IS
      l_texto   CLOB;
      l_destino INTEGER := 1;
      l_origen  INTEGER := 1;
      l_ctx     INTEGER := DBMS_LOB.default_lang_ctx;
      l_aviso   INTEGER;
      l_pos     INTEGER := 1;
      l_fin     INTEGER;
      l_largo   INTEGER;
   BEGIN
      DBMS_LOB.createtemporary(l_texto, TRUE);
      DBMS_LOB.converttoclob(l_texto, p_salida, DBMS_LOB.lobmaxsize, l_destino, l_origen,
                             DBMS_LOB.default_csid, l_ctx, l_aviso);
      l_largo := DBMS_LOB.getlength(l_texto);
      WHILE l_pos <= l_largo LOOP
         l_fin := DBMS_LOB.instr(l_texto, CHR(10), l_pos);
         IF l_fin = 0 THEN
            l_fin := l_largo + 1;
         END IF;
         DBMS_OUTPUT.put_line(DBMS_LOB.substr(l_texto, LEAST(l_fin - l_pos, 32000), l_pos));
         l_pos := l_fin + 1;
      END LOOP;
      DBMS_LOB.freetemporary(l_texto);
   END imprimir_salida;

   /* Estado del borrado en segundo plano: claves pendientes, jobs en curso y últimas
      ejecuciones (con su error, si lo hubo). */
   PROCEDURE informe_borrado
   IS
      l_pendientes PLS_INTEGER;
   BEGIN
      SELECT COUNT(*) INTO l_pendientes FROM sint_registro WHERE estado = gc_borrando;
      traza('Filas pendientes de borrado físico: ' || l_pendientes);
      FOR r IN (SELECT tabla, COUNT(*) AS filas FROM sint_registro
                 WHERE estado = gc_borrando GROUP BY tabla ORDER BY tabla) LOOP
         traza('   ' || RPAD(r.tabla, 30) || LPAD(r.filas, 10));
      END LOOP;

      FOR r IN (SELECT job_name, elapsed_time FROM user_scheduler_running_jobs
                 WHERE job_name LIKE gc_prefijo_job || '%' ORDER BY job_name) LOOP
         traza('Job EN CURSO: ' || r.job_name || ' (lleva ' || r.elapsed_time || ')');
      END LOOP;

      traza('Últimas ejecuciones:');
      FOR r IN (SELECT * FROM (
                   SELECT job_name, status, actual_start_date, run_duration, additional_info
                     FROM user_scheduler_job_run_details
                    WHERE job_name LIKE gc_prefijo_job || '%'
                    ORDER BY log_date DESC)
                 WHERE ROWNUM <= 5) LOOP
         traza('   ' || r.job_name || '  ' || RPAD(r.status, 10) ||
               TO_CHAR(r.actual_start_date, 'DD/MM HH24:MI:SS') || '  duración ' || r.run_duration ||
               CASE WHEN r.status <> 'SUCCEEDED' THEN '  ' || SUBSTR(r.additional_info, 1, 300) END);
      END LOOP;

      -- Salida (trazas) de la última ejecución: tiempos de índices y de cada tabla.
      -- OUTPUT sólo guarda 4.000 caracteres; la salida completa está en BINARY_OUTPUT.
      FOR r IN (SELECT * FROM (
                   SELECT job_name, binary_output, output FROM user_scheduler_job_run_details
                    WHERE job_name LIKE gc_prefijo_job || '%'
                      AND (binary_output IS NOT NULL OR output IS NOT NULL)
                    ORDER BY log_date DESC)
                 WHERE ROWNUM = 1) LOOP
         traza('Salida de ' || r.job_name || ':');
         IF r.binary_output IS NOT NULL AND DBMS_LOB.getlength(r.binary_output) > 0 THEN
            imprimir_salida(r.binary_output);
         ELSE
            DBMS_OUTPUT.put_line(r.output);
         END IF;
      END LOOP;

      FOR r IN (SELECT index_name, table_name FROM user_indexes
                 WHERE index_name LIKE gc_prefijo_indice || '%' ORDER BY table_name) LOOP
         traza('Índice temporal existente: ' || r.index_name || ' en ' || r.table_name);
      END LOOP;

      IF l_pendientes > 0 THEN
         SELECT COUNT(*) INTO l_pendientes FROM user_scheduler_running_jobs
          WHERE job_name LIKE gc_prefijo_job || '%';
         IF l_pendientes = 0 THEN
            traza('ATENCIÓN: hay filas pendientes y ningún job en curso. Relanzar con EXEC pkg_sint.eliminar_bbdd;');
         END IF;
      END IF;
   END informe_borrado;

   /* Filas sintéticas registradas por tabla y estado (sólo lee SINT_REGISTRO). */
   PROCEDURE resumen_registro
   IS
      l_total PLS_INTEGER := 0;
   BEGIN
      traza('Filas sintéticas registradas (ACTIVO = creadas; BORRANDO = borrado en curso):');
      FOR r IN (SELECT tabla, estado, COUNT(*) AS filas FROM sint_registro
                 GROUP BY tabla, estado ORDER BY estado, tabla) LOOP
         traza('   ' || RPAD(r.tabla, 30) || RPAD(r.estado, 10) || LPAD(r.filas, 10));
         l_total := l_total + r.filas;
      END LOOP;
      traza('   ' || RPAD('TOTAL', 40) || LPAD(l_total, 10));
   END resumen_registro;

   /* Comprueba, para cada tabla de p_tablas, que las claves ACTIVAS registradas son las
      esperadas y que todas existen en la tabla (búsqueda por PK). */
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
           FROM sint_registro WHERE tabla = p_tablas(i) AND estado = gc_activo;
         l_existentes := 0;
         IF l_registradas > 0 THEN
            -- Recorre el registro (pequeño) y busca cada clave por el índice de la PK.
            EXECUTE IMMEDIATE
               'SELECT COUNT(*) FROM sint_registro r WHERE r.tabla = :t AND r.estado = :e' ||
               ' AND EXISTS (SELECT 1 FROM ' ||
               DBMS_ASSERT.sql_object_name(nombre_seguro(p_tablas(i))) || ' x WHERE x.' ||
               nombre_seguro(l_columna) || ' = r.clave)'
               INTO l_existentes USING p_tablas(i), gc_activo;
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
