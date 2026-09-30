--------------------------------------------------------------------------------
-- eliminar_bbdd_sintetica.sql   *** SÓLO BORRA LO INSERTADO (responde al instante) ***
--
-- Marca como BORRANDO todas las filas creadas por crear_bbdd (SINT_REGISTRO) y lanza un
-- job de Oracle que las borra físicamente en segundo plano, por clave, hijas antes que
-- padres. Progreso: EXEC pkg_sint.estado_borrado;   No desinstala nada.
--
-- SQL Developer (conectado como KYTL_GC): pulsar F5, o ejecutar directamente:
--    EXEC pkg_sint.eliminar_bbdd;
--------------------------------------------------------------------------------
SET SERVEROUTPUT ON SIZE UNLIMITED
EXEC pkg_sint.eliminar_bbdd;
