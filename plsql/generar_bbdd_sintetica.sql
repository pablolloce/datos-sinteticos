--------------------------------------------------------------------------------
-- generar_bbdd_sintetica.sql
-- Construye la BBDD sintética completa: llama a cada generador con las
-- cantidades acordadas. Es el script que se ejecuta "a voluntad".
--
-- Uso (conectado como KYTL_GC, desde plsql/):
--    SQL> @generar_bbdd_sintetica.sql
--
-- Todo va en UNA transacción: si falla cualquier generador no queda nada a medias.
-- Para rehacer desde cero: @revertir_bbdd_sintetica.sql y volver a lanzar este.
--------------------------------------------------------------------------------
SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

BEGIN
   pkg_sint_nucleo.traza('=== Generación de la BBDD sintética ===');

   -- Unidad FINS -------------------------------------------------------------
   pkg_sint_fins.generar_contrapartida_global(p_cantidad => 10);

   -- (añadir aquí las nuevas entidades) ---------------------------------------

   COMMIT;
   pkg_sint_nucleo.resumen;
END;
/
