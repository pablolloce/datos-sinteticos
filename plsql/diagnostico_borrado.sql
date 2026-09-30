--------------------------------------------------------------------------------
-- diagnostico_borrado.sql
-- GENERADO AUTOMÁTICAMENTE por herramientas/generar_plsql.py — NO EDITAR A MANO.
--
-- ¿Por qué tarda eliminar_bbdd? Al borrar una fila de una tabla padre, Oracle comprueba
-- cada FK ACTIVA que apunta a ella desde otras tablas. Si la columna de la FK en la tabla
-- hija NO tiene índice, Oracle recorre la hija entera POR CADA FILA borrada (y la bloquea).
--
-- Este script lista esas FKs para las tablas del generador, indica si están indexadas y
-- propone el CREATE INDEX que lo resolvería (a validar/ejecutar por el DBA).
--
-- SQL Developer (conectado como KYTL_GC): abrir y pulsar F5. Sólo consulta, no cambia nada.
--------------------------------------------------------------------------------
SET LINESIZE 250 PAGESIZE 200
COLUMN padre       FORMAT A22
COLUMN hija        FORMAT A24
COLUMN fk          FORMAT A28
COLUMN columnas    FORMAT A30
COLUMN indexada    FORMAT A8
COLUMN filas_hija  FORMAT 999,999,999,999
COLUMN propuesta   FORMAT A110

WITH gestionadas AS (
   SELECT column_value AS tabla
     FROM TABLE(sys.odcivarchar2list('FT_T_FINS', 'FT_T_FIST', 'FT_T_FIGU', 'FINANCIAL_LEGAL_NAMES', 'FT_T_FINR', 'FT_T_FIRL', 'FT_T_ENFR', 'FT_T_FRCL', 'REGISTER_LOG_TABLE'))
), fks AS (
   SELECT p.table_name AS padre, c.table_name AS hija, c.constraint_name AS fk
     FROM user_constraints c
     JOIN user_constraints p ON p.owner = c.r_owner AND p.constraint_name = c.r_constraint_name
    WHERE c.constraint_type = 'R'
      AND c.status = 'ENABLED'
      AND p.table_name IN (SELECT tabla FROM gestionadas)
)
SELECT padre, hija, fk, columnas, indexada, filas_hija,
       CASE WHEN indexada = 'NO'
            THEN 'CREATE INDEX ' || SUBSTR('IX_' || fk, 1, 30) || ' ON ' || hija || ' (' || columnas || ') ONLINE;'
       END AS propuesta
  FROM (
SELECT f.padre, f.hija, f.fk,
       (SELECT LISTAGG(cc.column_name, ', ') WITHIN GROUP (ORDER BY cc.position)
          FROM user_cons_columns cc WHERE cc.constraint_name = f.fk) AS columnas,
       CASE WHEN EXISTS (
               -- un índice de la hija cuyas primeras columnas son las de la FK
               SELECT 1 FROM user_indexes i
                WHERE i.table_name = f.hija
                  AND NOT EXISTS (
                      SELECT 1 FROM user_cons_columns cc
                       WHERE cc.constraint_name = f.fk
                         AND NOT EXISTS (
                             SELECT 1 FROM user_ind_columns ic
                              WHERE ic.index_name = i.index_name
                                AND ic.column_name = cc.column_name
                                AND ic.column_position = cc.position)))
            THEN 'SI' ELSE 'NO' END AS indexada,
       (SELECT t.num_rows FROM user_tables t WHERE t.table_name = f.hija) AS filas_hija
  FROM fks f
       )
 ORDER BY indexada, filas_hija DESC NULLS LAST, padre, hija;
