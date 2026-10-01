--------------------------------------------------------------------------------
-- diagnostico_finsid.sql
-- SÓLO LECTURA. Averigua cómo crea GoldenSource el identificador interno FINSID
-- (fila FT_T_FIID con FINS_ID_CTXT_TYP = 'FINSID', regla nativa
-- CFTIInternalIdentifierCreator, que según el usuario usa el procedimiento
-- GET_IDENTIFIER_ID) y qué filas crea de verdad la Workstation al dar de
-- alta una contrapartida, comparándolas con una contrapartida sintética.
-- No depende de una ventana de tiempo (a diferencia de capturar_huella.sql).
--
-- SQL Developer (conectado como KYTL_GC): abrir y pulsar F5. Copiar TODA la salida
-- (Salida de script + DBMS_OUTPUT) y pasársela a Claude.
--
-- Parámetros (opcionales):
--   ws_mnem   INST_MNEM de una contrapartida GLOBAL dada de alta desde la Workstation.
--             Vacío = la más reciente que tenga FINSID y no sea sintética.
--   sint_mnem INST_MNEM de una contrapartida sintética (TESTING:RDR).
--             Vacío = la más reciente.
--------------------------------------------------------------------------------
SET DEFINE ON
SET VERIFY OFF
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 300
SET PAGESIZE 200
DEFINE ws_mnem   = ''
DEFINE sint_mnem = ''

PROMPT
PROMPT == 1. Las 10 últimas filas FINSID (formato del valor y columnas que rellena GoldenSource)
SELECT * FROM (
   SELECT f.fins_id, f.inst_mnem, f.fiid_oid, f.start_tms, f.last_chg_tms, f.last_chg_usr_id,
          f.data_src_id, f.data_stat_typ, f.global_uniq_ind, f.inst_usage_typ,
          f.inst_symbol_stat_typ, f.srce_inst_mnem, f.merge_uniq_oid,
          fi.start_tms AS fins_start_tms, fi.pref_fins_id_ctxt_typ, fi.pref_fins_id,
          fi.last_chg_usr_id AS fins_usr
     FROM ft_t_fiid f
     JOIN ft_t_fins fi ON fi.inst_mnem = f.inst_mnem
    WHERE f.fins_id_ctxt_typ = 'FINSID'
    ORDER BY f.start_tms DESC)
 WHERE ROWNUM <= 10;

PROMPT == 2. Formato de FINSID: total, numéricos, rango y si hay uno por contrapartida
SELECT COUNT(*)                                                         AS total,
       COUNT(CASE WHEN REGEXP_LIKE(fins_id, '^[0-9]+$') THEN 1 END)     AS numericos,
       MIN(CASE WHEN REGEXP_LIKE(fins_id, '^[0-9]+$') THEN TO_NUMBER(fins_id) END) AS minimo,
       MAX(CASE WHEN REGEXP_LIKE(fins_id, '^[0-9]+$') THEN TO_NUMBER(fins_id) END) AS maximo,
       MIN(LENGTH(fins_id)) AS long_min, MAX(LENGTH(fins_id)) AS long_max,
       COUNT(DISTINCT inst_mnem)                                        AS contrapartidas,
       COUNT(DISTINCT fins_id)                                          AS valores_distintos
  FROM ft_t_fiid
 WHERE fins_id_ctxt_typ = 'FINSID';

PROMPT == 3. Los 15 FINSID numéricos más altos (¿consecutivos? ¿huecos?)
SELECT * FROM (
   SELECT TO_NUMBER(fins_id) AS fins_id, inst_mnem, start_tms, last_chg_usr_id, data_stat_typ
     FROM ft_t_fiid
    WHERE fins_id_ctxt_typ = 'FINSID' AND REGEXP_LIKE(fins_id, '^[0-9]+$')
    ORDER BY TO_NUMBER(fins_id) DESC)
 WHERE ROWNUM <= 15;

PROMPT == 4a. GET_IDENTIFIER_ID: dónde está y su firma (parámetros, tipos, IN/OUT)
SELECT owner, object_name, object_type, status, last_ddl_time
  FROM all_objects WHERE object_name = 'GET_IDENTIFIER_ID'
    OR (object_type IN ('PACKAGE', 'PACKAGE BODY') AND object_name IN
        (SELECT package_name FROM all_arguments WHERE object_name = 'GET_IDENTIFIER_ID'));
SELECT owner, package_name, object_name, overload, position, argument_name, data_type, in_out, data_length
  FROM all_arguments WHERE object_name = 'GET_IDENTIFIER_ID'
 ORDER BY owner, package_name, overload, position;

PROMPT == 4b. GET_IDENTIFIER_ID: código fuente (si es un paquete, todo el paquete)
SELECT s.owner, s.name, s.type, s.line, s.text
  FROM all_source s
 WHERE s.name = 'GET_IDENTIFIER_ID'
    OR s.name IN (SELECT package_name FROM all_arguments WHERE object_name = 'GET_IDENTIFIER_ID')
 ORDER BY s.owner, s.name, s.type, s.line;

PROMPT == 4c. Secuencias candidatas (por nombre o por valor cercano al FINSID máximo)
WITH m AS (SELECT MAX(CASE WHEN REGEXP_LIKE(fins_id, '^[0-9]+$') THEN TO_NUMBER(fins_id) END) AS maximo
             FROM ft_t_fiid WHERE fins_id_ctxt_typ = 'FINSID')
SELECT s.sequence_owner, s.sequence_name, s.last_number, s.increment_by, s.cache_size,
       s.last_number - m.maximo AS diferencia_con_max_finsid
  FROM all_sequences s CROSS JOIN m
 WHERE s.sequence_name LIKE '%FINS%' OR s.sequence_name LIKE '%FIID%'
    OR s.sequence_name LIKE '%INTERNAL%' OR s.sequence_name LIKE '%IDENT%'
    OR s.last_number BETWEEN m.maximo - 1000 AND m.maximo + 100000
 ORDER BY ABS(s.last_number - m.maximo);

PROMPT == 5. ¿Se registran transacciones del motor? Las 5 últimas de FT_T_TRID
SELECT * FROM (
   SELECT trn_id, created_tms, input_msg_typ, main_entity_id, main_entity_id_ctxt_typ,
          main_entity_tbl_typ, crrnt_trn_stat_typ, crrnt_severity_cde, appl_prod_typ
     FROM ft_t_trid ORDER BY created_tms DESC)
 WHERE ROWNUM <= 5;
SELECT SYSDATE AS sysdate_bbdd, CURRENT_DATE AS fecha_sesion, SESSIONTIMEZONE AS zona_sesion,
       DBTIMEZONE AS zona_bbdd FROM dual;

PROMPT == 6. Filas por tabla con INST_MNEM: contrapartida de la Workstation frente a la sintética.
PROMPT ==    Una lectura por tabla (las que no tienen índice por INST_MNEM se recorren enteras: puede
PROMPT ==    tardar unos minutos; los segundos de cada una anticipan el coste del borrado por entidad).
DECLARE
   -- VARCHAR2 (no %TYPE CHAR): en PL/SQL un CHAR con '' se rellena de espacios y no es NULL.
   l_ws     VARCHAR2(10) := TRIM('&ws_mnem');
   l_sint   VARCHAR2(10) := TRIM('&sint_mnem');
   l_n_ws   NUMBER;
   l_n_si   NUMBER;
   l_ini    NUMBER;
   l_total  NUMBER := DBMS_UTILITY.get_time;
   l_lentas NUMBER := 0;
BEGIN
   IF l_ws IS NULL THEN
      SELECT MAX(inst_mnem) KEEP (DENSE_RANK LAST ORDER BY start_tms) INTO l_ws
        FROM ft_t_fiid
       WHERE fins_id_ctxt_typ = 'FINSID' AND last_chg_usr_id <> 'TESTING:RDR';
   END IF;
   IF l_sint IS NULL THEN
      SELECT MAX(inst_mnem) KEEP (DENSE_RANK LAST ORDER BY start_tms) INTO l_sint
        FROM ft_t_fins WHERE last_chg_usr_id = 'TESTING:RDR';
   END IF;
   DBMS_OUTPUT.put_line('Workstation: ' || NVL(l_ws, '(ninguna)') ||
                        '   Sintética: ' || NVL(l_sint, '(ninguna)'));
   DBMS_OUTPUT.put_line(RPAD('TABLA', 32) || LPAD('WORKSTATION', 12) || LPAD('SINTETICA', 12) ||
                        LPAD('SEGUNDOS', 10) || '  INDICE');
   FOR t IN (SELECT c.table_name,
                    (SELECT COUNT(*) FROM user_ind_columns i
                      WHERE i.table_name = c.table_name AND i.column_name = 'INST_MNEM'
                        AND i.column_position = 1) AS indexada
               FROM user_tab_columns c JOIN user_tables u ON u.table_name = c.table_name
              WHERE c.column_name = 'INST_MNEM'
                AND c.table_name NOT LIKE 'SINT%' AND c.table_name NOT LIKE 'BIN$%'
              ORDER BY c.table_name) LOOP
      l_ini := DBMS_UTILITY.get_time;
      DBMS_APPLICATION_INFO.set_module('diagnostico_finsid', t.table_name);
      BEGIN
         EXECUTE IMMEDIATE 'SELECT COUNT(CASE WHEN inst_mnem = :a THEN 1 END), ' ||
                           'COUNT(CASE WHEN inst_mnem = :b THEN 1 END) FROM "' || t.table_name ||
                           '" WHERE inst_mnem IN (:c, :d)'
            INTO l_n_ws, l_n_si USING l_ws, l_sint, l_ws, l_sint;
         IF DBMS_UTILITY.get_time - l_ini > 100 THEN
            l_lentas := l_lentas + 1;
         END IF;
         IF l_n_ws + l_n_si > 0 OR DBMS_UTILITY.get_time - l_ini > 100 THEN
            DBMS_OUTPUT.put_line(RPAD(t.table_name, 32) || LPAD(l_n_ws, 12) || LPAD(l_n_si, 12) ||
                                 LPAD(TO_CHAR((DBMS_UTILITY.get_time - l_ini) / 100, 'FM9990D0'), 10) ||
                                 CASE WHEN t.indexada > 0 THEN '  sí' ELSE '  NO' END ||
                                 CASE WHEN l_n_ws <> l_n_si THEN '   <== distinto' END);
         END IF;
      EXCEPTION
         WHEN OTHERS THEN
            DBMS_OUTPUT.put_line(RPAD(t.table_name, 32) || ' no se ha podido leer: ' || SQLERRM);
      END;
   END LOOP;
   DBMS_APPLICATION_INFO.set_module(NULL, NULL);
   DBMS_OUTPUT.put_line('Total ' || ROUND((DBMS_UTILITY.get_time - l_total) / 100) || ' s; ' ||
                        l_lentas || ' tablas de más de 1 s (sin filas, sólo se listan éstas).');
END;
/

PROMPT == 7. Identificadores (FT_T_FIID) de la contrapartida de la Workstation, todos los contextos
SELECT f.* FROM ft_t_fiid f
 WHERE f.inst_mnem = NVL('&ws_mnem',
          (SELECT MAX(inst_mnem) KEEP (DENSE_RANK LAST ORDER BY start_tms) FROM ft_t_fiid
            WHERE fins_id_ctxt_typ = 'FINSID' AND last_chg_usr_id <> 'TESTING:RDR'))
 ORDER BY f.fins_id_ctxt_typ;
