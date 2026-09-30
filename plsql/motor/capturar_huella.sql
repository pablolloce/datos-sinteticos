--------------------------------------------------------------------------------
-- capturar_huella.sql      *** SÓLO LECTURA DE DATOS DE GOLDENSOURCE ***
--
-- Captura la "huella" que deja el motor de GoldenSource al procesar un mensaje:
-- todas las filas de las tablas del esquema cuyo LAST_CHG_TMS cae en una ventana
-- de tiempo, más la transacción del motor (FT_T_TRID), sus notificaciones
-- (FT_T_NTEL) y los metadatos del mensaje procesado (FT_T_MSGP).
--
-- Sirve para descubrir qué hacen las reglas nativas (CFTI*/CGSC*) cuyo código no
-- tenemos: se guarda una entidad desde la ventana de la Workstation, se captura la
-- huella y se compara con el mensaje con herramientas/motor/comparar_huella.py.
-- Ver docs/motor/README.md, apartado "Descubrir qué hace una regla".
--
-- Uso (SQL Developer, conectado como KYTL_GC, en un entorno de PRUEBAS tranquilo):
--   1. Anotar la hora, guardar la entidad en la Workstation, esperar 2-3 minutos
--      (los workflows posteriores al motor son asíncronos: REU, shortname,
--      datos regulatorios...; ver docs/motor/FLUJO_WORKSTATION.md) y anotar la hora.
--   2. Ajustar los DEFINE de abajo y pulsar F5.
--   3. Exportar el resultado de la última consulta (SINT_HUELLA) a CSV
--      (clic derecho > Exportar > csv) y dejarlo en huellas/<Mensaje>.csv.
--
-- Rendimiento: recorre las tablas que casan con &tablas (sin índice por
-- LAST_CHG_TMS, lectura completa). Acotar con &tablas si el esquema es grande.
--
-- Crea (si no existe) la tabla SINT_HUELLA, que sólo contiene la última captura.
-- Para eliminarla: DROP TABLE sint_huella PURGE;
--------------------------------------------------------------------------------
SET SERVEROUTPUT ON SIZE UNLIMITED
SET VERIFY OFF

-- Ventana de tiempo (formato AAAA-MM-DD HH24:MI:SS). Holgura de unos segundos.
DEFINE desde   = '2026-09-30 10:00:00'
DEFINE hasta   = '2026-09-30 10:05:00'
-- Patrón LIKE de tablas a revisar ('%' = todas las que tienen LAST_CHG_TMS).
DEFINE tablas  = '%'
-- Patrón LIKE de LAST_CHG_USR_ID. Dejar '%': las reglas escriben con otros usuarios
-- (DIFUSION, REACTIVE, ANNEXCOPY, BDI_RESTORE, ...).
DEFINE usuario = '%'

ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS';
ALTER SESSION SET NLS_TIMESTAMP_FORMAT = 'YYYY-MM-DD HH24:MI:SS.FF';

DECLARE
  l_existe PLS_INTEGER;
BEGIN
  SELECT COUNT(*) INTO l_existe FROM user_tables WHERE table_name = 'SINT_HUELLA';
  IF l_existe = 0 THEN
    EXECUTE IMMEDIATE q'[
      CREATE TABLE sint_huella (
        orden        NUMBER,
        tabla        VARCHAR2(128),
        num_filas    NUMBER,
        filas_xml    CLOB,
        capturado    DATE DEFAULT SYSDATE)]';
  END IF;
END;
/

DECLARE
  -- Tablas técnicas o de log que no forman parte de la entidad.
  c_excluir CONSTANT VARCHAR2(400) :=
    '^(SINT_|FT_LOG_|FT_WF_|FT_T_TRID$|FT_T_MSG[SFPV]$|FT_T_NTEL$|FT_T_JBLG$|QRTZ_|BIN\$)';
  l_desde  DATE := TO_DATE('&desde', 'YYYY-MM-DD HH24:MI:SS');
  l_hasta  DATE := TO_DATE('&hasta', 'YYYY-MM-DD HH24:MI:SS');
  l_n      NUMBER;
  l_orden  NUMBER := 0;
  l_sql    VARCHAR2(4000);
  l_ctx    DBMS_XMLGEN.ctxHandle;
  l_xml    CLOB;
  l_tablas PLS_INTEGER := 0;

  -- Inserta en SINT_HUELLA el XML (ROWSET/ROW) de una consulta.
  PROCEDURE guardar(p_tabla VARCHAR2, p_consulta VARCHAR2, p_filas NUMBER) IS
  BEGIN
    l_ctx := DBMS_XMLGEN.newContext(p_consulta);
    DBMS_XMLGEN.setBindValue(l_ctx, 'D', TO_CHAR(l_desde, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_XMLGEN.setBindValue(l_ctx, 'H', TO_CHAR(l_hasta, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_XMLGEN.setNullHandling(l_ctx, DBMS_XMLGEN.DROP_NULLS);
    l_xml := DBMS_XMLGEN.getXML(l_ctx);
    DBMS_XMLGEN.closeContext(l_ctx);
    l_orden := l_orden + 1;
    INSERT INTO sint_huella (orden, tabla, num_filas, filas_xml)
    VALUES (l_orden, p_tabla, p_filas, l_xml);
  END guardar;
BEGIN
  DELETE FROM sint_huella;

  -- 1. Filas de negocio modificadas en la ventana.
  FOR t IN (SELECT c.table_name
              FROM user_tab_columns c
              JOIN user_tables u ON u.table_name = c.table_name
             WHERE c.column_name = 'LAST_CHG_TMS'
               AND c.table_name LIKE '&tablas'
               AND NOT REGEXP_LIKE(c.table_name, c_excluir)
             ORDER BY c.table_name)
  LOOP
    l_tablas := l_tablas + 1;
    l_sql := 'SELECT COUNT(*) FROM "' || t.table_name || '" WHERE last_chg_tms BETWEEN :d AND :h'
          || CASE WHEN '&usuario' <> '%' THEN ' AND last_chg_usr_id LIKE ''&usuario''' END;
    BEGIN
      EXECUTE IMMEDIATE l_sql INTO l_n USING l_desde, l_hasta;
      IF l_n > 0 THEN
        guardar(t.table_name,
                'SELECT * FROM "' || t.table_name || '" WHERE last_chg_tms BETWEEN '
                || 'TO_DATE(:D, ''YYYY-MM-DD HH24:MI:SS'') AND TO_DATE(:H, ''YYYY-MM-DD HH24:MI:SS'')'
                || CASE WHEN '&usuario' <> '%' THEN ' AND last_chg_usr_id LIKE ''&usuario''' END,
                l_n);
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.put_line('Aviso: ' || t.table_name || ' no se ha podido leer: ' || SQLERRM);
    END;
  END LOOP;

  -- 2. Transacciones del motor creadas en la ventana, sus notificaciones y el
  --    mensaje procesado (sin el BLOB; ver consulta final para exportarlo).
  guardar('#FT_T_TRID',
          'SELECT * FROM ft_t_trid WHERE created_tms BETWEEN '
          || 'TO_DATE(:D, ''YYYY-MM-DD HH24:MI:SS'') AND TO_DATE(:H, ''YYYY-MM-DD HH24:MI:SS'')', NULL);
  guardar('#FT_T_NTEL',
          'SELECT n.* FROM ft_t_ntel n WHERE n.trn_id IN (SELECT trn_id FROM ft_t_trid WHERE created_tms BETWEEN '
          || 'TO_DATE(:D, ''YYYY-MM-DD HH24:MI:SS'') AND TO_DATE(:H, ''YYYY-MM-DD HH24:MI:SS''))', NULL);
  guardar('#FT_T_MSGP',
          'SELECT p.trn_id, p.proc_msg_cnt, p.proc_msg_stat_cde, p.msg_fmt_typ, p.xref_tbl_typ, '
          || 'p.xref_tbl_row_oid, p.entity_chg_ind, p.data_src_id, p.last_chg_usr_id, p.proc_msg_tms, '
          || 'DBMS_LOB.getlength(p.proc_msg_bin) AS bytes FROM ft_t_msgp p WHERE p.trn_id IN '
          || '(SELECT trn_id FROM ft_t_trid WHERE created_tms BETWEEN '
          || 'TO_DATE(:D, ''YYYY-MM-DD HH24:MI:SS'') AND TO_DATE(:H, ''YYYY-MM-DD HH24:MI:SS''))', NULL);
  COMMIT;

  SELECT COUNT(*) INTO l_n FROM sint_huella WHERE tabla NOT LIKE '#%';
  DBMS_OUTPUT.put_line('Tablas revisadas: ' || l_tablas || ' · con cambios en la ventana: ' || l_n);
END;
/

-- Resumen: tablas con filas en la ventana.
SELECT orden, tabla, num_filas FROM sint_huella ORDER BY orden;

-- EXPORTAR ESTA CONSULTA A CSV (huellas/<Mensaje>.csv).
SELECT tabla, filas_xml FROM sint_huella ORDER BY orden;

-- Mensajes de la transacción (exportar los BLOB a fichero si se quieren comparar):
--   SUB_MSG_BIN  = mensaje recibido;  FMT_MSG_BIN = mensaje traducido (STREET_REF que entra al motor);
--   PROC_MSG_BIN = mensaje procesado (lo que el motor hizo con cada segmento), si el tipo de
--   mensaje lo guarda (FT_CFG_MSTP.SAVE_PROCESSED_MSG_TYP / CAPTURE_PROCESSED_MSG_IND).
SELECT t.trn_id, s.sub_msg_bin, f.fmt_msg_bin, p.proc_msg_bin
  FROM ft_t_trid t
  LEFT JOIN ft_t_msgs s ON s.trn_id = t.trn_id
  LEFT JOIN ft_t_msgf f ON f.trn_id = t.trn_id
  LEFT JOIN ft_t_msgp p ON p.trn_id = t.trn_id
 WHERE t.created_tms BETWEEN TO_DATE('&desde', 'YYYY-MM-DD HH24:MI:SS')
                         AND TO_DATE('&hasta', 'YYYY-MM-DD HH24:MI:SS');
