--------------------------------------------------------------------------------
-- extraer_tablas_adicionales.sql      *** SÓLO CONSULTA ***
--
-- Estructura de las tablas que escriben las reglas del motor y los workflows
-- posteriores al guardado (D-031, D-036) y que no están en esquema/old/*_KYTL_GC.csv:
-- casi todas son tablas custom (FT_T_*1) a las que KYTL_GC accede por SINÓNIMO.
--
-- Cada tabla se devuelve con el nombre que usa la aplicación (el del sinónimo, o el
-- propio si es una tabla de KYTL_GC). Exportar cada consulta a CSV (UTF-8, ',',
-- con cabecera) en esquema/old/ con el nombre indicado y ejecutar
--   python3 herramientas/construir_modelo.py
--
-- SQL Developer, conectado como KYTL_GC: F5.
--------------------------------------------------------------------------------

-- A. Resolución de nombres -> esquema/old/SINONIMOS_ADICIONALES.csv
WITH nombres (nombre) AS (
  SELECT column_value FROM TABLE(sys.odcivarchar2list(
  'FT_T_ALG1',
  'FT_T_ALM1',
  'FT_T_ALR1',
  'FT_T_ATB1',
  'FT_T_BCP1',
  'FT_T_CAC1',
  'FT_T_CAI1',
  'FT_T_CCA1',
  'FT_T_CCT1',
  'FT_T_COA1',
  'FT_T_COI1',
  'FT_T_COT1',
  'FT_T_EMM1',
  'FT_T_EXI1',
  'FT_T_FLG1',
  'FT_T_FND1',
  'FT_T_FRA1',
  'FT_T_FSA1',
  'FT_T_LAL1',
  'FT_T_LAT1',
  'FT_T_LAX1',
  'FT_T_LLD1',
  'FT_T_LPS1',
  'FT_T_LPX1',
  'FT_T_LRT1',
  'FT_T_PAR1',
  'FT_T_REG1',
  'FT_T_REI1',
  'FT_T_RLT1',
  'FT_T_RRM1',
  'FT_T_SAA1',
  'FT_T_SAA2',
  'FT_T_SAI1',
  'FT_T_SAP1',
  'FT_T_SAT1',
  'FT_T_SCA1',
  'FT_T_TBC1',
  'FT_T_UTD1'))
)
SELECT n.nombre,
       NVL(s.table_owner, t.owner)  AS owner_real,
       NVL(s.table_name, t.table_name) AS tabla_real,
       CASE WHEN s.synonym_name IS NOT NULL THEN 'SINONIMO ' || s.owner
            WHEN t.table_name IS NOT NULL THEN 'TABLA'
            ELSE 'NO ENCONTRADA' END AS tipo
FROM   nombres n
LEFT JOIN all_synonyms s ON s.synonym_name = n.nombre AND s.owner IN ('KYTL_GC', 'PUBLIC')
LEFT JOIN all_tables   t ON t.table_name = n.nombre AND t.owner = 'KYTL_GC'
ORDER  BY n.nombre;

-- B. Columnas -> esquema/old/ALL_TAB_COLUMNS_ADICIONALES.csv
WITH nombres (nombre) AS (
  SELECT column_value FROM TABLE(sys.odcivarchar2list(
  'FT_T_ALG1',
  'FT_T_ALM1',
  'FT_T_ALR1',
  'FT_T_ATB1',
  'FT_T_BCP1',
  'FT_T_CAC1',
  'FT_T_CAI1',
  'FT_T_CCA1',
  'FT_T_CCT1',
  'FT_T_COA1',
  'FT_T_COI1',
  'FT_T_COT1',
  'FT_T_EMM1',
  'FT_T_EXI1',
  'FT_T_FLG1',
  'FT_T_FND1',
  'FT_T_FRA1',
  'FT_T_FSA1',
  'FT_T_LAL1',
  'FT_T_LAT1',
  'FT_T_LAX1',
  'FT_T_LLD1',
  'FT_T_LPS1',
  'FT_T_LPX1',
  'FT_T_LRT1',
  'FT_T_PAR1',
  'FT_T_REG1',
  'FT_T_REI1',
  'FT_T_RLT1',
  'FT_T_RRM1',
  'FT_T_SAA1',
  'FT_T_SAA2',
  'FT_T_SAI1',
  'FT_T_SAP1',
  'FT_T_SAT1',
  'FT_T_SCA1',
  'FT_T_TBC1',
  'FT_T_UTD1'))
), objetos AS (
  SELECT n.nombre, NVL(s.table_owner, 'KYTL_GC') AS owner_real, NVL(s.table_name, n.nombre) AS tabla_real
  FROM   nombres n
  LEFT JOIN all_synonyms s ON s.synonym_name = n.nombre AND s.owner IN ('KYTL_GC', 'PUBLIC')
)
SELECT c.owner, o.nombre AS table_name, c.column_name, c.data_type, c.data_length, c.data_precision,
       c.data_scale, c.nullable, c.column_id, c.data_default
FROM   objetos o
JOIN   all_tab_columns c ON c.owner = o.owner_real AND c.table_name = o.tabla_real
ORDER  BY o.nombre, c.column_id;

-- C. Restricciones (PK, UK, FK) -> esquema/old/ALL_CONSTRAINTS_ADICIONALES.csv
WITH nombres (nombre) AS (
  SELECT column_value FROM TABLE(sys.odcivarchar2list(
  'FT_T_ALG1',
  'FT_T_ALM1',
  'FT_T_ALR1',
  'FT_T_ATB1',
  'FT_T_BCP1',
  'FT_T_CAC1',
  'FT_T_CAI1',
  'FT_T_CCA1',
  'FT_T_CCT1',
  'FT_T_COA1',
  'FT_T_COI1',
  'FT_T_COT1',
  'FT_T_EMM1',
  'FT_T_EXI1',
  'FT_T_FLG1',
  'FT_T_FND1',
  'FT_T_FRA1',
  'FT_T_FSA1',
  'FT_T_LAL1',
  'FT_T_LAT1',
  'FT_T_LAX1',
  'FT_T_LLD1',
  'FT_T_LPS1',
  'FT_T_LPX1',
  'FT_T_LRT1',
  'FT_T_PAR1',
  'FT_T_REG1',
  'FT_T_REI1',
  'FT_T_RLT1',
  'FT_T_RRM1',
  'FT_T_SAA1',
  'FT_T_SAA2',
  'FT_T_SAI1',
  'FT_T_SAP1',
  'FT_T_SAT1',
  'FT_T_SCA1',
  'FT_T_TBC1',
  'FT_T_UTD1'))
), objetos AS (
  SELECT n.nombre, NVL(s.table_owner, 'KYTL_GC') AS owner_real, NVL(s.table_name, n.nombre) AS tabla_real
  FROM   nombres n
  LEFT JOIN all_synonyms s ON s.synonym_name = n.nombre AND s.owner IN ('KYTL_GC', 'PUBLIC')
)
SELECT k.owner, k.constraint_name, k.constraint_type, o.nombre AS table_name,
       k.r_owner, k.r_constraint_name, k.status
FROM   objetos o
JOIN   all_constraints k ON k.owner = o.owner_real AND k.table_name = o.tabla_real
WHERE  k.constraint_type IN ('P', 'U', 'R')
ORDER  BY o.nombre, k.constraint_name;

-- D. Columnas de las restricciones -> esquema/old/ALL_CONS_COLUMNS_ADICIONALES.csv
WITH nombres (nombre) AS (
  SELECT column_value FROM TABLE(sys.odcivarchar2list(
  'FT_T_ALG1',
  'FT_T_ALM1',
  'FT_T_ALR1',
  'FT_T_ATB1',
  'FT_T_BCP1',
  'FT_T_CAC1',
  'FT_T_CAI1',
  'FT_T_CCA1',
  'FT_T_CCT1',
  'FT_T_COA1',
  'FT_T_COI1',
  'FT_T_COT1',
  'FT_T_EMM1',
  'FT_T_EXI1',
  'FT_T_FLG1',
  'FT_T_FND1',
  'FT_T_FRA1',
  'FT_T_FSA1',
  'FT_T_LAL1',
  'FT_T_LAT1',
  'FT_T_LAX1',
  'FT_T_LLD1',
  'FT_T_LPS1',
  'FT_T_LPX1',
  'FT_T_LRT1',
  'FT_T_PAR1',
  'FT_T_REG1',
  'FT_T_REI1',
  'FT_T_RLT1',
  'FT_T_RRM1',
  'FT_T_SAA1',
  'FT_T_SAA2',
  'FT_T_SAI1',
  'FT_T_SAP1',
  'FT_T_SAT1',
  'FT_T_SCA1',
  'FT_T_TBC1',
  'FT_T_UTD1'))
), objetos AS (
  SELECT n.nombre, NVL(s.table_owner, 'KYTL_GC') AS owner_real, NVL(s.table_name, n.nombre) AS tabla_real
  FROM   nombres n
  LEFT JOIN all_synonyms s ON s.synonym_name = n.nombre AND s.owner IN ('KYTL_GC', 'PUBLIC')
)
SELECT cc.owner, cc.constraint_name, o.nombre AS table_name, cc.column_name, cc.position
FROM   objetos o
JOIN   all_constraints k  ON k.owner = o.owner_real AND k.table_name = o.tabla_real AND k.constraint_type IN ('P', 'U', 'R')
JOIN   all_cons_columns cc ON cc.owner = k.owner AND cc.constraint_name = k.constraint_name
ORDER  BY o.nombre, cc.constraint_name, cc.position;
