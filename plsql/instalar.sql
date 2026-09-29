--------------------------------------------------------------------------------
-- instalar.sql
-- Instala (o reinstala) el generador en el esquema KYTL_GC: UN ÚNICO PAQUETE,
-- PKG_SINT (plsql/generado/pkg_sint.pks/.pkb). No crea datos.
--
--   1. Borra los paquetes de versiones anteriores del generador, si existen
--      (PKG_SINT_NUCLEO, PKG_SINT_FINS, SINT_E_*...).
--   2. Compila PKG_SINT.
--   3. Se detiene con error si PKG_SINT queda inválido.
--
-- SQL Developer: abrir este fichero desde plsql/ y ejecutarlo con F5.
-- SQL*Plus/SQLcl: situarse en plsql/ y ejecutar @instalar.sql
--------------------------------------------------------------------------------
SET DEFINE OFF
SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT == Limpieza de paquetes de versiones anteriores
BEGIN
   FOR r IN (SELECT object_name
               FROM user_objects
              WHERE object_type = 'PACKAGE'
                AND (   object_name IN ('PKG_SINT_NUCLEO', 'PKG_SINT_FINS',
                                        'PKG_SINT_ENTIDADES', 'PKG_DATOS_SINTETICOS')
                     OR object_name LIKE 'SINT\_E\_%' ESCAPE '\'))
   LOOP
      EXECUTE IMMEDIATE 'DROP PACKAGE ' || DBMS_ASSERT.enquote_name(r.object_name);
      DBMS_OUTPUT.put_line('Borrado paquete obsoleto: ' || r.object_name);
   END LOOP;
END;
/

PROMPT == PKG_SINT
@@generado/pkg_sint.pks
@@generado/pkg_sint.pkb

PROMPT == Comprobación
BEGIN
   FOR r IN (SELECT type, line, position, text
               FROM user_errors
              WHERE name = 'PKG_SINT'
              ORDER BY type, sequence)
   LOOP
      DBMS_OUTPUT.put_line(r.type || ' (' || r.line || ',' || r.position || '): ' || r.text);
      RAISE_APPLICATION_ERROR(-20000, 'PKG_SINT con errores de compilación (ver arriba)');
   END LOOP;
   FOR r IN (SELECT object_type FROM user_objects
              WHERE object_name = 'PKG_SINT' AND status <> 'VALID')
   LOOP
      RAISE_APPLICATION_ERROR(-20000, 'PKG_SINT inválido: ' || r.object_type);
   END LOOP;
   DBMS_OUTPUT.put_line('Instalación correcta: PKG_SINT es válido.');
END;
/
