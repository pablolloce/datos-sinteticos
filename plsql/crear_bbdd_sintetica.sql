--------------------------------------------------------------------------------
-- crear_bbdd_sintetica.sql      *** SÓLO EJECUTA LOS INSERTS (rápido) ***
--
-- Inserta toda la BBDD sintética y hace COMMIT. No instala nada ni borra nada.
-- Si ya existe una BBDD sintética, falla sin tocar nada (ejecutar antes eliminar).
--
-- SQL Developer (conectado como KYTL_GC): pulsar F5, o ejecutar directamente:
--    EXEC pkg_sint.crear_bbdd;
--------------------------------------------------------------------------------
SET SERVEROUTPUT ON SIZE UNLIMITED
EXEC pkg_sint.crear_bbdd;
