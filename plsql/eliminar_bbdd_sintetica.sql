--------------------------------------------------------------------------------
-- eliminar_bbdd_sintetica.sql   *** SÓLO BORRA LO INSERTADO (rápido) ***
--
-- Borra, por clave primaria, todas las filas creadas por crear_bbdd (registradas en
-- SINT_REGISTRO) y hace COMMIT. No recorre las tablas ni desinstala nada.
--
-- SQL Developer (conectado como KYTL_GC): pulsar F5, o ejecutar directamente:
--    EXEC pkg_sint.eliminar_bbdd;
--------------------------------------------------------------------------------
SET SERVEROUTPUT ON SIZE UNLIMITED
EXEC pkg_sint.eliminar_bbdd;
