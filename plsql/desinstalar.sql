--------------------------------------------------------------------------------
-- desinstalar.sql
-- Deja el esquema como antes del generador: borra los datos sintéticos
-- registrados, el paquete PKG_SINT y la tabla SINT_REGISTRO.
--
-- SQL Developer (conectado como KYTL_GC): abrir desde plsql/ y pulsar F5.
--------------------------------------------------------------------------------
SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

PROMPT == Borrando datos sintéticos
EXEC pkg_sint.eliminar_bbdd;

PROMPT == Borrando PKG_SINT y SINT_REGISTRO
DROP PACKAGE pkg_sint;
DROP TABLE sint_registro PURGE;
