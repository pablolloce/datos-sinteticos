--------------------------------------------------------------------------------
-- instalar.sql            *** ÚNICO COMANDO DE INSTALACIÓN / ACTUALIZACIÓN ***
--
-- Desinstala lo anterior e instala la versión nueva del generador en KYTL_GC.
-- NO crea ni borra datos sintéticos (eso lo hacen crear_bbdd / eliminar_bbdd).
--
--   1. Borra los paquetes de versiones anteriores del generador, si existen
--      (PKG_SINT_NUCLEO, PKG_SINT_FINS, PKG_SINT_ENTIDADES, SINT_E_*...).
--      y los índices temporales SINT_TMP_* de un borrado interrumpido (D-028).
--   2. Crea la tabla SINT_REGISTRO si no existe (registro de claves creadas; se
--      conserva entre instalaciones para poder borrar lo que ya se hubiera creado).
--   2b. Crea la tabla SINT_ENTIDAD si no existe (una fila por entidad sintética con su
--      clave principal: INST_MNEM, INSTR_ID...; D-042) y la rellena con las ya creadas.
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

PROMPT == 1b. Índices temporales SINT_TMP_* que hubieran quedado de un borrado interrumpido
DECLARE
   l_jobs PLS_INTEGER;
BEGIN
   SELECT COUNT(*) INTO l_jobs FROM user_scheduler_running_jobs WHERE job_name LIKE 'SINT\_ELIM\_%' ESCAPE '\';
   IF l_jobs = 0 THEN                         -- si hay un borrado en curso, sus índices se respetan
      FOR r IN (SELECT index_name FROM user_indexes WHERE index_name LIKE 'SINT\_TMP\_%' ESCAPE '\') LOOP
         EXECUTE IMMEDIATE 'DROP INDEX ' || DBMS_ASSERT.enquote_name(r.index_name);
         DBMS_OUTPUT.put_line('Borrado índice temporal: ' || r.index_name);
      END LOOP;
   END IF;
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
            estado      VARCHAR2(10) DEFAULT 'ACTIVO' NOT NULL,
            creado_tms  DATE DEFAULT SYSDATE NOT NULL,
            CONSTRAINT sint_registro_pk PRIMARY KEY (tabla, clave)
         ) ORGANIZATION INDEX]';
      EXECUTE IMMEDIATE q'[COMMENT ON TABLE sint_registro IS
         'Generador de datos sintéticos (PKG_SINT): clave de cada fila sintética creada, para borrarla por PK']';
      DBMS_OUTPUT.put_line('Creada tabla SINT_REGISTRO');
   ELSE
      DBMS_OUTPUT.put_line('SINT_REGISTRO ya existe: se conserva');
      -- Versiones anteriores no tenían ESTADO (ACTIVO / BORRANDO, D-027)
      SELECT COUNT(*) INTO l_existe FROM user_tab_columns
       WHERE table_name = 'SINT_REGISTRO' AND column_name = 'ESTADO';
      IF l_existe = 0 THEN
         EXECUTE IMMEDIATE q'[ALTER TABLE sint_registro ADD (estado VARCHAR2(10) DEFAULT 'ACTIVO' NOT NULL)]';
         DBMS_OUTPUT.put_line('Añadida columna SINT_REGISTRO.ESTADO');
      END IF;
   END IF;
END;
/

PROMPT == 2b. Tabla de entidades sintéticas SINT_ENTIDAD (una fila por entidad, D-042)
DECLARE
   l_existe PLS_INTEGER;
BEGIN
   SELECT COUNT(*) INTO l_existe FROM user_tables WHERE table_name = 'SINT_ENTIDAD';
   IF l_existe = 0 THEN
      EXECUTE IMMEDIATE q'[
         CREATE TABLE sint_entidad (
            tabla_principal VARCHAR2(128) NOT NULL,
            clave           VARCHAR2(100) NOT NULL,
            columna_clave   VARCHAR2(128) NOT NULL,
            entidad         VARCHAR2(30)  NOT NULL,
            unidad          VARCHAR2(20),
            estado          VARCHAR2(10) DEFAULT 'ACTIVO' NOT NULL,
            creado_tms      DATE DEFAULT SYSDATE NOT NULL,
            CONSTRAINT sint_entidad_pk PRIMARY KEY (tabla_principal, clave)
         ) ORGANIZATION INDEX]';
      EXECUTE IMMEDIATE q'[COMMENT ON TABLE sint_entidad IS
         'Generador de datos sintéticos (PKG_SINT): una fila por entidad sintética con su clave principal (INST_MNEM, INSTR_ID...)']';
      DBMS_OUTPUT.put_line('Creada tabla SINT_ENTIDAD');
      -- Entidades creadas con una versión anterior: su fila principal ya está en SINT_REGISTRO
      -- (tabla principal de la unidad FINS = FT_T_FINS, clave INST_MNEM).
      EXECUTE IMMEDIATE q'[
         INSERT INTO sint_entidad (tabla_principal, clave, columna_clave, entidad, unidad, estado, creado_tms)
         SELECT tabla, clave, columna_pk, NVL(entidad, '?'), SUBSTR(tabla, 6), estado, creado_tms
           FROM sint_registro WHERE tabla = 'FT_T_FINS']';
      IF SQL%ROWCOUNT > 0 THEN
         DBMS_OUTPUT.put_line('Registradas ' || SQL%ROWCOUNT || ' entidades ya existentes en SINT_ENTIDAD');
      END IF;
      COMMIT;
   ELSE
      DBMS_OUTPUT.put_line('SINT_ENTIDAD ya existe: se conserva');
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
