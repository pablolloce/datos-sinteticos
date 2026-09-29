--------------------------------------------------------------------------------
-- desinstalar.sql
-- GENERADO AUTOMÁTICAMENTE por herramientas/generar_plsql.py — NO EDITAR A MANO.
-- Todas las rutas cuelgan de plsql/: SQL*Plus y SQL Developer las resuelven igual
-- (un @@ con subcarpetas dentro de un script anidado NO es portable, D-020).
--
-- Borra los datos sintéticos y después todos los paquetes del generador.
-- SQL Developer (conectado como KYTL_GC): abrir desde plsql/ y pulsar F5.
--------------------------------------------------------------------------------
SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

PROMPT == Borrando datos sintéticos
EXEC pkg_sint.eliminar_bbdd;

PROMPT == Borrando paquetes
DROP PACKAGE pkg_sint;
DROP PACKAGE sint_e_contrapartida_global;
DROP PACKAGE pkg_sint_nucleo;
