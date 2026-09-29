--------------------------------------------------------------------------------
-- eliminar_bbdd_sintetica.sql         *** UNA EJECUCIÓN = SE BORRA TODO LO SINTÉTICO ***
--
-- Borra todos los registros con LAST_CHG_USR_ID = 'TESTING:RDR' de las tablas
-- gestionadas (hijas antes que padres) y hace COMMIT. Todo o nada.
-- El código del generador se mantiene instalado (para quitarlo: desinstalar.sql).
--
-- SQL Developer (conectado como KYTL_GC): abrir este fichero desde plsql/ y pulsar F5.
-- Equivale a:   EXEC pkg_sint.eliminar_bbdd;
--------------------------------------------------------------------------------
SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

EXEC pkg_sint.eliminar_bbdd;
EXEC pkg_sint.resumen;
