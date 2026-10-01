--------------------------------------------------------------------------------
-- capturar_huella.sql      *** SÓLO LECTURA DE DATOS DE GOLDENSOURCE ***
--
-- Captura la "huella" que deja GoldenSource al dar de alta una entidad desde la
-- Workstation: TODAS las filas escritas (confirmadas) en el esquema en los últimos
-- &minutos minutos, en cualquier tabla, más la transacción del motor (FT_T_TRID),
-- sus notificaciones (FT_T_NTEL) y los metadatos del mensaje procesado (FT_T_MSGP).
--
-- Sirve para descubrir qué hacen las reglas nativas (CFTI*/CGSC*) y los workflows
-- cuyo código no tenemos, y qué tablas toca un alta (D-030, D-040).
--
-- Uso (SQL Developer, conectado como KYTL_GC, en un entorno de PRUEBAS tranquilo):
--   1. Dar el alta en la Workstation y esperar 2-3 minutos (los workflows posteriores
--      al motor son asíncronos: REU, shortname, datos regulatorios...).
--   2. Pulsar F5 antes de que pasen &minutos minutos desde el alta (por defecto 10).
--   3. Pasar a Claude la salida del script y exportar el resultado de la consulta
--      "EXPORTAR ESTA CONSULTA" a CSV (clic derecho > Exportar > csv) en huellas/<Mensaje>.csv.
--
-- Cómo se decide qué filas son "de los últimos minutos" (D-040):
--   NO por LAST_CHG_TMS / CREATED_TMS: GoldenSource los escribe con el reloj del servidor de
--   aplicaciones, que puede ir desfasado (zona horaria) respecto al de la BBDD. Se usa
--   ORA_ROWSCN: el número de cambio (SCN) del COMMIT que escribió la fila, en el reloj de la BBDD.
--   ORA_ROWSCN es por bloque de datos: puede arrastrar filas antiguas que comparten bloque con
--   una fila nueva. Para no arrastrarlas, en las tablas con LAST_CHG_TMS se exige además que
--   LAST_CHG_TMS sea de las últimas &margen_horas horas (margen holgado frente al desfase).
--   El script informa del desfase entre LAST_CHG_TMS y la hora de la BBDD.
--
-- Rendimiento:
--   &modo = 'MODIFICADAS' (por defecto): sólo se leen las tablas que Oracle ha registrado
--     como modificadas en la ventana (USER_TAB_MODIFICATIONS, tras
--     DBMS_STATS.FLUSH_DATABASE_MONITORING_INFO). Si no hay permiso para el FLUSH, la vista se
--     actualiza sola cada ~15 min: el script lo avisa (repetir la captura más tarde o usar TODAS).
--   &modo = 'TODAS': todas las tablas (lento: cada una es una lectura completa).
--   Progreso desde otra sesión: SELECT module, action FROM v$session WHERE module = 'capturar_huella';
--
-- Crea (si no existe) la tabla SINT_HUELLA, que sólo contiene la última captura.
-- Para eliminarla: DROP TABLE sint_huella PURGE;
--------------------------------------------------------------------------------
SET SERVEROUTPUT ON SIZE UNLIMITED
SET VERIFY OFF
-- Por si en la misma sesión se ejecutó antes instalar.sql (SET DEFINE OFF): &minutos...
SET DEFINE ON

-- Minutos hacia atrás desde ahora (reloj de la BBDD) que se capturan.
DEFINE minutos = 10
-- MODIFICADAS (rápido, recomendado) o TODAS (lento).
DEFINE modo    = 'MODIFICADAS'
-- S = capturar también la transacción del motor (FT_T_TRID, FT_T_NTEL, FT_T_MSGP); N = omitirla.
DEFINE transacciones = 'S'
-- Patrón LIKE de tablas a revisar ('%' = todas).
DEFINE tablas  = '%'
-- Tablas con LAST_CHG_TMS: sólo filas con LAST_CHG_TMS en las últimas N horas (descarta filas
-- antiguas que comparten bloque con las nuevas; holgado frente a desfases de zona horaria).
DEFINE margen_horas = 26
-- Máximo de filas que se guardan por tabla (las de más se cuentan, no se guardan).
DEFINE max_filas = 500

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
  -- Tablas técnicas o de log que no forman parte de la entidad (la transacción se captura aparte).
  c_excluir CONSTANT VARCHAR2(400) :=
    '^(SINT_|FT_LOG_|FT_WF_|FT_T_TRID$|FT_T_MSG[SFPV]$|FT_T_NTEL$|FT_T_JBLG$|QRTZ_|BIN\$)';
  l_minutos  NUMBER := &minutos;
  l_margen   NUMBER := &margen_horas;
  l_max      NUMBER := &max_filas;
  l_desde    DATE   := SYSDATE - &minutos / 1440;      -- reloj de la BBDD
  l_scn      NUMBER;
  l_n        NUMBER;
  l_min_tms  DATE;
  l_max_tms  DATE;
  l_ult_tms  DATE;                                      -- LAST_CHG_TMS más reciente capturado
  l_orden    NUMBER := 0;
  l_filtro   VARCHAR2(4000);
  l_ctx      DBMS_XMLGEN.ctxHandle;
  l_xml      CLOB;
  l_tablas   PLS_INTEGER := 0;
  l_flush    BOOLEAN := TRUE;
  l_modo     VARCHAR2(20) := UPPER('&modo');
  l_ini      NUMBER;
  l_lentas   VARCHAR2(4000);

  -- Inserta en SINT_HUELLA el XML (ROWSET/ROW) de una consulta con el bind :S (SCN mínimo).
  PROCEDURE guardar(p_tabla VARCHAR2, p_consulta VARCHAR2, p_filas NUMBER) IS
  BEGIN
    l_ctx := DBMS_XMLGEN.newContext(p_consulta);
    DBMS_XMLGEN.setBindValue(l_ctx, 'S', TO_CHAR(l_scn));
    DBMS_XMLGEN.setNullHandling(l_ctx, DBMS_XMLGEN.DROP_NULLS);
    l_xml := DBMS_XMLGEN.getXML(l_ctx);
    DBMS_XMLGEN.closeContext(l_ctx);
    l_orden := l_orden + 1;
    INSERT INTO sint_huella (orden, tabla, num_filas, filas_xml)
    VALUES (l_orden, p_tabla, p_filas, l_xml);
  END guardar;
BEGIN
  DELETE FROM sint_huella;
  DBMS_APPLICATION_INFO.set_module('capturar_huella', 'inicio');

  -- SCN (reloj de la BBDD) de hace &minutos minutos: filas confirmadas desde entonces.
  l_scn := TIMESTAMP_TO_SCN(SYSTIMESTAMP - NUMTODSINTERVAL(l_minutos, 'MINUTE'));
  DBMS_OUTPUT.put_line('Hora de la BBDD: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') ||
                       ' · se capturan filas confirmadas desde ' || TO_CHAR(l_desde, 'HH24:MI:SS') ||
                       ' (SCN ' || l_scn || ')');

  IF l_modo = 'MODIFICADAS' THEN
    -- Vuelca a USER_TAB_MODIFICATIONS los contadores de DML que Oracle guarda en memoria.
    BEGIN
      DBMS_STATS.flush_database_monitoring_info;
    EXCEPTION
      WHEN OTHERS THEN
        l_flush := FALSE;
        DBMS_OUTPUT.put_line('AVISO: no se ha podido ejecutar DBMS_STATS.FLUSH_DATABASE_MONITORING_INFO ('
                             || SQLERRM || '). USER_TAB_MODIFICATIONS puede no incluir aún los cambios '
                             || 'más recientes: repetir la captura más tarde o usar modo TODAS.');
    END;
  END IF;

  DBMS_OUTPUT.put_line(RPAD('TABLA', 32) || LPAD('FILAS', 7) || '  LAST_CHG_TMS (mín - máx)');
  FOR t IN (SELECT u.table_name,
                   (SELECT COUNT(*) FROM user_tab_columns c
                     WHERE c.table_name = u.table_name AND c.column_name = 'LAST_CHG_TMS') AS con_tms
              FROM user_tables u
             WHERE u.table_name LIKE '&tablas'
               AND u.temporary = 'N'
               AND NOT REGEXP_LIKE(u.table_name, c_excluir)
               AND (l_modo = 'TODAS'
                    OR EXISTS (SELECT 1 FROM user_tab_modifications m
                                WHERE m.table_name = u.table_name
                                  AND m.partition_name IS NULL
                                  AND m.timestamp >= l_desde - 1 / 1440
                                  AND m.inserts + m.updates + m.deletes > 0))
             ORDER BY u.table_name)
  LOOP
    l_tablas := l_tablas + 1;
    l_ini    := DBMS_UTILITY.get_time;
    DBMS_APPLICATION_INFO.set_action(SUBSTR(l_tablas || ': ' || t.table_name, 1, 64));
    l_filtro := ' WHERE ORA_ROWSCN >= TO_NUMBER(:S)' ||
                CASE WHEN t.con_tms > 0 THEN ' AND last_chg_tms >= SYSDATE - ' || l_margen || ' / 24' END;
    BEGIN
      IF t.con_tms > 0 THEN
        EXECUTE IMMEDIATE 'SELECT COUNT(*), MIN(last_chg_tms), MAX(last_chg_tms) FROM "' ||
                          t.table_name || '"' || l_filtro
          INTO l_n, l_min_tms, l_max_tms USING TO_CHAR(l_scn);
      ELSE
        EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM "' || t.table_name || '"' || l_filtro
          INTO l_n USING TO_CHAR(l_scn);
        l_min_tms := NULL;
        l_max_tms := NULL;
      END IF;
      IF l_n > 0 THEN
        guardar(t.table_name,
                'SELECT * FROM "' || t.table_name || '"' || l_filtro || ' AND ROWNUM <= ' || l_max, l_n);
        DBMS_OUTPUT.put_line(RPAD(t.table_name, 32) || LPAD(l_n, 7) ||
                             CASE WHEN l_min_tms IS NOT NULL THEN '  ' || TO_CHAR(l_min_tms, 'DD HH24:MI:SS') ||
                                  ' - ' || TO_CHAR(l_max_tms, 'DD HH24:MI:SS') END ||
                             CASE WHEN l_n > l_max THEN '  (se guardan ' || l_max || ')' END);
        IF l_max_tms IS NOT NULL AND (l_ult_tms IS NULL OR l_max_tms > l_ult_tms) THEN
          l_ult_tms := l_max_tms;
        END IF;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.put_line('Aviso: ' || t.table_name || ' no se ha podido leer: ' || SQLERRM);
    END;
    IF DBMS_UTILITY.get_time - l_ini > 1000 AND NVL(LENGTH(l_lentas), 0) < 3800 THEN   -- > 10 s
      l_lentas := l_lentas || ' ' || t.table_name || ' (' || ROUND((DBMS_UTILITY.get_time - l_ini) / 100) || ' s)';
    END IF;
  END LOOP;

  DBMS_APPLICATION_INFO.set_action('transacciones');
  IF UPPER('&transacciones') = 'S' THEN
    -- 2. Transacciones del motor confirmadas en la ventana, sus notificaciones y el mensaje
    --    procesado (sin el BLOB; ver consulta final para exportarlo). CREATED_TMS sólo acota la
    --    lectura (holgado: puede ir con otro reloj); la ventana la da ORA_ROWSCN.
    l_filtro := ' WHERE ORA_ROWSCN >= TO_NUMBER(:S) AND created_tms >= SYSDATE - ' || l_margen || ' / 24';
    guardar('#FT_T_TRID', 'SELECT * FROM ft_t_trid' || l_filtro, NULL);
    guardar('#FT_T_NTEL', 'SELECT n.* FROM ft_t_ntel n WHERE n.trn_id IN (SELECT trn_id FROM ft_t_trid' ||
                          l_filtro || ')', NULL);
    guardar('#FT_T_MSGP',
            'SELECT p.trn_id, p.proc_msg_cnt, p.proc_msg_stat_cde, p.msg_fmt_typ, p.xref_tbl_typ, '
            || 'p.xref_tbl_row_oid, p.entity_chg_ind, p.data_src_id, p.last_chg_usr_id, p.proc_msg_tms, '
            || 'DBMS_LOB.getlength(p.proc_msg_bin) AS bytes FROM ft_t_msgp p WHERE p.trn_id IN '
            || '(SELECT trn_id FROM ft_t_trid' || l_filtro || ')', NULL);
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ft_t_trid' || l_filtro INTO l_n USING TO_CHAR(l_scn);
    DBMS_OUTPUT.put_line('Transacciones del motor (FT_T_TRID) en la ventana: ' || l_n);
  END IF;
  COMMIT;

  SELECT COUNT(*) INTO l_n FROM sint_huella WHERE tabla NOT LIKE '#%';
  DBMS_OUTPUT.put_line('Modo ' || l_modo || CASE WHEN l_modo = 'MODIFICADAS' AND NOT l_flush
                       THEN ' (sin FLUSH: puede faltar algo)' END
                       || ' · tablas revisadas: ' || l_tablas || ' · con filas nuevas: ' || l_n);
  IF l_ult_tms IS NOT NULL THEN
    DBMS_OUTPUT.put_line('Desfase aparente LAST_CHG_TMS - hora de la BBDD: ' ||
                         ROUND((l_ult_tms - SYSDATE) * 24 * 60) || ' min (LAST_CHG_TMS más reciente ' ||
                         TO_CHAR(l_ult_tms, 'YYYY-MM-DD HH24:MI:SS') || ')');
  END IF;
  IF l_lentas IS NOT NULL THEN
    DBMS_OUTPUT.put_line('Tablas lentas (> 10 s):' || l_lentas);
  END IF;
  DBMS_APPLICATION_INFO.set_module(NULL, NULL);
EXCEPTION
  WHEN OTHERS THEN
    DBMS_APPLICATION_INFO.set_module(NULL, NULL);
    IF SQLCODE IN (-8180, -8181) THEN
      RAISE_APPLICATION_ERROR(-20010, 'No se puede convertir la hora en SCN (' || SQLERRM ||
                              '): ejecutar la captura antes de que pasen &minutos minutos desde el alta.');
    END IF;
    RAISE;
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
 WHERE UPPER('&transacciones') = 'S'
   AND t.created_tms >= SYSDATE - &margen_horas / 24
   AND t.ORA_ROWSCN >= TIMESTAMP_TO_SCN(SYSTIMESTAMP - NUMTODSINTERVAL(&minutos, 'MINUTE'));
