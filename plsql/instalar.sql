--------------------------------------------------------------------------------
-- instalar.sql
-- Instala (o reinstala) el generador de datos sintéticos.
-- Uso (SQL*Plus / SQLcl, desde la carpeta plsql/):
--    SQL> @instalar.sql
--------------------------------------------------------------------------------
SET DEFINE OFF
SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT == Compilando especificación de PKG_DATOS_SINTETICOS
@@paquete/pkg_datos_sinteticos.pks
SHOW ERRORS PACKAGE pkg_datos_sinteticos

PROMPT == Compilando cuerpo de PKG_DATOS_SINTETICOS
@@paquete/pkg_datos_sinteticos.pkb
SHOW ERRORS PACKAGE BODY pkg_datos_sinteticos

PROMPT == Instalación terminada
