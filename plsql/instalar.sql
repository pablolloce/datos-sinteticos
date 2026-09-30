--------------------------------------------------------------------------------
-- instalar.sql            *** ÚNICO COMANDO DE INSTALACIÓN / ACTUALIZACIÓN ***
--
-- Desinstala lo anterior e instala la versión nueva del generador en KYTL_GC.
-- NO crea ni borra datos sintéticos (eso lo hacen crear_bbdd / eliminar_bbdd).
--
--   1. Borra los paquetes de versiones anteriores del generador, si existen
--      (PKG_SINT_NUCLEO, PKG_SINT_FINS, PKG_SINT_ENTIDADES, SINT_E_*...).
--   2. Crea la tabla SINT_REGISTRO si no existe (registro de claves creadas; se
--      conserva entre instalaciones para poder borrar lo que ya se hubiera creado).
--   3. Compila el paquete PKG_SINT (sustituye a la versión anterior).
--   4. Se detiene con error si PKG_SINT queda inválido.
--
-- SQL Developer (conectado como KYTL_GC): abrir este fichero desde plsql/ y pulsar F5.
-- SQL*Plus/SQLcl: situarse en plsql/ y ejecutar @instalar.sql
--------------------------------------------------------------------------------
SET DEFINE OFF
SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT == 1. Desinstalando paquetes de versiones anteriores
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

PROMPT == 2. Tabla de registro de claves SINT_REGISTRO
DECLARE
   l_existe PLS_INTEGER;
BEGIN
   SELECT COUNT(*) INTO l_existe FROM user_tables WHERE table_name = 'SINT_REGISTRO';
   IF l_existe = 0 THEN
      -- Tabla organizada por índice (IOT): la PK (tabla, clave) es la propia tabla.
      EXECUTE IMMEDIATE q'[
         CREATE TABLE sint_registro (
            tabla       VARCHAR2(128) NOT NULL,
            clave       VARCHAR2(100) NOT NULL,
            columna_pk  VARCHAR2(128) NOT NULL,
            entidad     VARCHAR2(30),
            creado_tms  DATE DEFAULT SYSDATE NOT NULL,
            CONSTRAINT sint_registro_pk PRIMARY KEY (tabla, clave)
         ) ORGANIZATION INDEX]';
      EXECUTE IMMEDIATE q'[COMMENT ON TABLE sint_registro IS
         'Generador de datos sintéticos (PKG_SINT): clave de cada fila sintética creada, para borrarla por PK']';
      DBMS_OUTPUT.put_line('Creada tabla SINT_REGISTRO');
   ELSE
      DBMS_OUTPUT.put_line('SINT_REGISTRO ya existe: se conserva');
   END IF;
END;
/

PROMPT == 3. Compilando PKG_SINT
@@generado/pkg_sint.pks
@@generado/pkg_sint.pkb

PROMPT == 4. Comprobación
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
