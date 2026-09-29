--------------------------------------------------------------------------------
-- revertir_bbdd_sintetica.sql
-- Elimina TODOS los registros sintéticos (LAST_CHG_USR_ID = 'TESTING:RDR') de las
-- tablas gestionadas por el generador y confirma.
--
-- Uso (conectado como KYTL_GC, desde plsql/):
--    SQL> @revertir_bbdd_sintetica.sql
--------------------------------------------------------------------------------
SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

BEGIN
   pkg_sint_nucleo.resumen;
   pkg_sint_nucleo.purgar(p_commit => TRUE);
   pkg_sint_nucleo.resumen;
END;
/
