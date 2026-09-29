--------------------------------------------------------------------------------
-- instalar.sql
-- GENERADO AUTOMÁTICAMENTE por herramientas/generar_plsql.py — NO EDITAR A MANO.
-- Todas las rutas cuelgan de plsql/: SQL*Plus y SQL Developer las resuelven igual
-- (un @@ con subcarpetas dentro de un script anidado NO es portable, D-020).
--
-- Instala (o reinstala) el código del generador en el esquema KYTL_GC:
--   1. Núcleo PKG_SINT_NUCLEO (escrito a mano, plsql/nucleo/).
--   2. Un paquete por entidad (SINT_E_*) y la fachada PKG_SINT (plsql/generado/).
-- No crea datos. Se detiene con error si algún objeto queda inválido.
--
-- SQL Developer: abrir este fichero desde plsql/ y ejecutarlo con F5.
-- SQL*Plus/SQLcl: situarse en plsql/ y ejecutar @instalar.sql
--------------------------------------------------------------------------------
SET DEFINE OFF
SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT == Núcleo: PKG_SINT_NUCLEO
@@nucleo/pkg_sint_nucleo.pks
@@nucleo/pkg_sint_nucleo.pkb

PROMPT == Entidades (1)
PROMPT == SINT_E_CONTRAPARTIDA_GLOBAL (mensajes_entrada/Ejemplo_Alta_Contrapartida_Global.xml)
@@generado/entidades/fins/sint_e_contrapartida_global.pks
@@generado/entidades/fins/sint_e_contrapartida_global.pkb

PROMPT == Fachada PKG_SINT
@@generado/pkg_sint.pks
@@generado/pkg_sint.pkb

PROMPT == Comprobación de objetos inválidos
BEGIN
   FOR r IN (SELECT name, type, line, position, text
               FROM user_errors
              WHERE name LIKE 'PKG_SINT%' OR name LIKE 'SINT\_E\_%' ESCAPE '\'
              ORDER BY name, type, sequence)
   LOOP
      DBMS_OUTPUT.put_line(r.type || ' ' || r.name || ' (' || r.line || ',' || r.position || '): ' || r.text);
      RAISE_APPLICATION_ERROR(-20000, 'Instalación con errores de compilación (ver arriba)');
   END LOOP;
   FOR r IN (SELECT object_type, object_name
               FROM user_objects
              WHERE (object_name LIKE 'PKG_SINT%' OR object_name LIKE 'SINT\_E\_%' ESCAPE '\')
                AND status <> 'VALID')
   LOOP
      RAISE_APPLICATION_ERROR(-20000, 'Objeto inválido: ' || r.object_type || ' ' || r.object_name);
   END LOOP;
   DBMS_OUTPUT.put_line('Instalación correcta: todos los objetos son válidos.');
END;
/
