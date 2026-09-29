CREATE OR REPLACE PACKAGE BODY pkg_sint
AS
/*******************************************************************************
 * GENERADO AUTOMÁTICAMENTE por herramientas/generar_plsql.py — NO EDITAR A MANO.
 * Para cambiarlo: modificar el mensaje XML o mensajes_entrada/catalogo.json y regenerar.
 ******************************************************************************/

   -- Tablas gestionadas en orden de primera inserción (resumen y verificación).
   g_tablas CONSTANT pkg_sint_nucleo.t_lista_tablas := pkg_sint_nucleo.t_lista_tablas(
      'FT_T_FINS',
      'FT_T_FIST',
      'FT_T_FIGU',
      'FINANCIAL_LEGAL_NAMES',
      'FT_T_FINR',
      'FT_T_FIRL',
      'FT_T_ENFR',
      'FT_T_FRCL');

   -- Filas sintéticas esperadas tras crear_bbdd, en el mismo orden que g_tablas.
   g_filas_esperadas CONSTANT pkg_sint_nucleo.t_lista_numeros := pkg_sint_nucleo.t_lista_numeros(
      1,
      2,
      1,
      1,
      1,
      1,
      2,
      1);

   -- Orden de borrado: hijas antes que padres (calculado a partir de las FKs).
   g_tablas_purga CONSTANT pkg_sint_nucleo.t_lista_tablas := pkg_sint_nucleo.t_lista_tablas(
      'FT_T_FRCL',
      'FT_T_ENFR',
      'FT_T_FIRL',
      'FT_T_FINR',
      'FINANCIAL_LEGAL_NAMES',
      'FT_T_FIGU',
      'FT_T_FIST',
      'FT_T_FINS');

   PROCEDURE resumen
   IS
   BEGIN
      pkg_sint_nucleo.resumen(g_tablas);
   END resumen;

   PROCEDURE verificar
   IS
      l_errores VARCHAR2(4000);
      l_filas   PLS_INTEGER;
   BEGIN
      FOR i IN 1 .. g_tablas.COUNT LOOP
         l_filas := pkg_sint_nucleo.contar(g_tablas(i));
         IF l_filas <> g_filas_esperadas(i) THEN
            l_errores := SUBSTR(l_errores || ' ' || g_tablas(i) || '=' || l_filas
                                || ' (esperadas ' || g_filas_esperadas(i) || ')', 1, 4000);
         END IF;
      END LOOP;
      IF l_errores IS NOT NULL THEN
         RAISE_APPLICATION_ERROR(pkg_sint_nucleo.ge_verificacion_fallida,
                                 'Filas sintéticas inesperadas:' || l_errores);
      END IF;
      pkg_sint_nucleo.traza('Verificación correcta: todas las tablas tienen las filas esperadas');
   END verificar;

   PROCEDURE eliminar_bbdd (p_commit IN BOOLEAN DEFAULT TRUE)
   IS
   BEGIN
      pkg_sint_nucleo.purgar(g_tablas_purga, p_commit);
   END eliminar_bbdd;

   PROCEDURE crear_bbdd (p_limpiar_antes IN BOOLEAN DEFAULT TRUE,
                         p_commit        IN BOOLEAN DEFAULT TRUE)
   IS
   BEGIN
      pkg_sint_nucleo.traza('=== Creación de la BBDD sintética ===');
      SAVEPOINT sp_crear_bbdd;

      IF p_limpiar_antes THEN
         pkg_sint_nucleo.purgar(g_tablas_purga, p_commit => FALSE);
      END IF;

      -------------------------------------------------------------------------
      -- 1. Entidades de los mensajes (una entidad idéntica a cada mensaje)
      -------------------------------------------------------------------------
      sint_e_contrapartida_global.generar;   -- mensajes_entrada/Ejemplo_Alta_Contrapartida_Global.xml

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
      pkg_sint_nucleo.traza('=== BBDD sintética creada' ||
                            CASE WHEN p_commit THEN ' (COMMIT)' ELSE ' (pendiente de COMMIT)' END || ' ===');
   EXCEPTION
      WHEN OTHERS THEN
         ROLLBACK TO SAVEPOINT sp_crear_bbdd;
         pkg_sint_nucleo.traza('ERROR: creación deshecha. ' || SQLERRM);
         RAISE;
   END crear_bbdd;

END pkg_sint;
/
