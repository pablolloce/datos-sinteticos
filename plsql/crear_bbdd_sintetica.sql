--------------------------------------------------------------------------------
-- crear_bbdd_sintetica.sql            *** UNA EJECUCIÓN = BBDD SINTÉTICA COMPLETA ***
--
-- 1. Instala/actualiza el código (instalar.sql).
-- 2. EXEC pkg_sint.crear_bbdd: borra lo sintético previo, crea todas las entidades,
--    verifica los conteos y hace COMMIT. Todo o nada.
--
-- SQL Developer (conectado como KYTL_GC): abrir este fichero desde plsql/ y pulsar F5.
-- Si el código ya está instalado basta con:   EXEC pkg_sint.crear_bbdd;
--------------------------------------------------------------------------------
@@instalar.sql

SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

EXEC pkg_sint.crear_bbdd;
