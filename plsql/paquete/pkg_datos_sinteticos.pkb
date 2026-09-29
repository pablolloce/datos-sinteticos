CREATE OR REPLACE PACKAGE BODY pkg_datos_sinteticos
AS
/*******************************************************************************
 * Cuerpo de PKG_DATOS_SINTETICOS. Ver cabecera en la especificación (.pks).
 ******************************************************************************/

   ----------------------------------------------------------------------------
   -- Tipos y estado privado
   ----------------------------------------------------------------------------

   TYPE t_lista_tablas IS TABLE OF VARCHAR2(30);

   -- Tablas gestionadas por el generador, en ORDEN DE INSERCIÓN (padres primero).
   -- La purga las recorre en orden inverso (hijas primero) para no violar FKs.
   -- >>> Cada entidad nueva debe añadir aquí sus tablas en la posición correcta. <<<
   g_tablas_gestionadas  t_lista_tablas := t_lista_tablas();

   g_trazas_activas      BOOLEAN := TRUE;

   ----------------------------------------------------------------------------
   -- Trazas
   ----------------------------------------------------------------------------

   PROCEDURE traza (p_texto IN VARCHAR2)
   IS
   BEGIN
      IF g_trazas_activas THEN
         DBMS_OUTPUT.put_line(TO_CHAR(SYSTIMESTAMP, 'HH24:MI:SS.FF3') || ' | ' || p_texto);
      END IF;
   END traza;

   PROCEDURE set_trazas (p_activas IN BOOLEAN)
   IS
   BEGIN
      g_trazas_activas := NVL(p_activas, TRUE);
   END set_trazas;

   ----------------------------------------------------------------------------
   -- Utilidades
   ----------------------------------------------------------------------------

   FUNCTION fecha_xml (p_texto IN VARCHAR2) RETURN DATE DETERMINISTIC
   IS
   BEGIN
      RETURN TO_DATE(p_texto, gc_formato_fecha_xml, gc_nls_fecha_xml);
   END fecha_xml;

   /* Devuelve el nombre de tabla validado (existe y es un identificador simple).
      Protege el SQL dinámico de la purga frente a inyección (DBMS_ASSERT). */
   FUNCTION tabla_segura (p_tabla IN VARCHAR2) RETURN VARCHAR2
   IS
   BEGIN
      RETURN DBMS_ASSERT.sql_object_name(DBMS_ASSERT.simple_sql_name(p_tabla));
   END tabla_segura;

   ----------------------------------------------------------------------------
   -- Consulta y purga
   ----------------------------------------------------------------------------

   PROCEDURE resumen
   IS
      l_filas  PLS_INTEGER;
   BEGIN
      traza('Resumen de filas sintéticas (' || gc_usuario_sintetico || ')');
      FOR i IN 1 .. g_tablas_gestionadas.COUNT LOOP
         EXECUTE IMMEDIATE
            'SELECT COUNT(*) FROM ' || tabla_segura(g_tablas_gestionadas(i)) ||
            ' WHERE last_chg_usr_id = :usr'
            INTO l_filas
            USING gc_usuario_sintetico;
         traza(RPAD(g_tablas_gestionadas(i), 12) || LPAD(l_filas, 10));
      END LOOP;
      IF g_tablas_gestionadas.COUNT = 0 THEN
         traza('No hay tablas gestionadas todavía.');
      END IF;
   END resumen;

   PROCEDURE purgar (p_commit IN BOOLEAN DEFAULT FALSE)
   IS
      l_total  PLS_INTEGER := 0;
      l_filas  PLS_INTEGER;
   BEGIN
      traza('Inicio purga de datos sintéticos (' || gc_usuario_sintetico || ')');

      -- Orden inverso al de inserción: primero las tablas hijas.
      FOR i IN REVERSE 1 .. g_tablas_gestionadas.COUNT LOOP
         EXECUTE IMMEDIATE
            'DELETE FROM ' || tabla_segura(g_tablas_gestionadas(i)) ||
            ' WHERE last_chg_usr_id = :usr'
            USING gc_usuario_sintetico;
         l_filas := SQL%ROWCOUNT;
         traza(RPAD(g_tablas_gestionadas(i), 12) || LPAD(l_filas, 10) || ' filas borradas');
         l_total := l_total + l_filas;
      END LOOP;

      IF p_commit THEN
         COMMIT;
      END IF;
      traza('Fin purga: ' || l_total || ' filas' || CASE WHEN p_commit THEN ' (COMMIT)' ELSE ' (sin COMMIT)' END);
   END purgar;

END pkg_datos_sinteticos;
/
