--------------------------------------------------------------------------------
-- instalar.sql
-- Instala (o reinstala) el generador de datos sintéticos en el esquema KYTL_GC.
-- Uso (SQL*Plus / SQLcl, conectado como KYTL_GC, desde la carpeta plsql/):
--    SQL> @instalar.sql
-- Orden: primero el núcleo (del que dependen todas las unidades) y después
-- cada paquete de unidad funcional.
--------------------------------------------------------------------------------
SET DEFINE OFF
SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT == Núcleo: PKG_SINT_NUCLEO
@@nucleo/pkg_sint_nucleo.pks
SHOW ERRORS PACKAGE pkg_sint_nucleo
@@nucleo/pkg_sint_nucleo.pkb
SHOW ERRORS PACKAGE BODY pkg_sint_nucleo

PROMPT == Unidad FINS: PKG_SINT_FINS
@@unidades/pkg_sint_fins.pks
SHOW ERRORS PACKAGE pkg_sint_fins
@@unidades/pkg_sint_fins.pkb
SHOW ERRORS PACKAGE BODY pkg_sint_fins

PROMPT == Objetos inválidos del generador (debe salir vacío)
SELECT object_name, object_type, status
  FROM user_objects
 WHERE object_name LIKE 'PKG_SINT%'
   AND status <> 'VALID';

PROMPT == Instalación terminada
