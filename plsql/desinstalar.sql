--------------------------------------------------------------------------------
-- desinstalar.sql
-- Borra todos los datos sintéticos y después el paquete PKG_SINT.
--
-- SQL Developer (conectado como KYTL_GC): abrir desde plsql/ y pulsar F5.
--------------------------------------------------------------------------------
SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

PROMPT == Borrando datos sintéticos
EXEC pkg_sint.eliminar_bbdd;

PROMPT == Borrando PKG_SINT
DROP PACKAGE pkg_sint;
