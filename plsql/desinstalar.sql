--------------------------------------------------------------------------------
-- desinstalar.sql
-- Deja el esquema como antes del generador: borra los datos sintéticos
-- registrados, el paquete PKG_SINT y la tabla SINT_REGISTRO.
--
-- SQL Developer (conectado como KYTL_GC): abrir desde plsql/ y pulsar F5.
--------------------------------------------------------------------------------
SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

PROMPT == Parando jobs de borrado en curso
BEGIN
   FOR r IN (SELECT job_name FROM user_scheduler_jobs WHERE job_name LIKE 'SINT\_ELIM\_%' ESCAPE '\') LOOP
      DBMS_SCHEDULER.drop_job(r.job_name, force => TRUE);
   END LOOP;
END;
/

PROMPT == Borrando datos sintéticos (en esta sesión; puede tardar, D-026)
EXEC pkg_sint.eliminar_bbdd(p_segundo_plano => FALSE);

PROMPT == Comprobando que no quedan filas sintéticas BLOQUEADAS (P-008, D-038)
DECLARE
   l_n PLS_INTEGER;
BEGIN
   SELECT COUNT(*) INTO l_n FROM sint_registro WHERE estado = 'BLOQUEADO';
   IF l_n > 0 THEN
      pkg_sint.estado_borrado;
      RAISE_APPLICATION_ERROR(-20003, l_n || ' filas sintéticas no se han podido borrar porque de ' ||
         'ellas cuelgan registros no sintéticos (ver arriba). Desinstalación detenida para no perder ' ||
         'su registro: borre esos registros y vuelva a ejecutar desinstalar.sql.');
   END IF;
END;
/

PROMPT == Índices temporales SINT_TMP_* que pudieran quedar
BEGIN
   FOR r IN (SELECT index_name FROM user_indexes WHERE index_name LIKE 'SINT\_TMP\_%' ESCAPE '\') LOOP
      EXECUTE IMMEDIATE 'DROP INDEX ' || DBMS_ASSERT.enquote_name(r.index_name);
   END LOOP;
END;
/

PROMPT == Borrando PKG_SINT y SINT_REGISTRO
DROP PACKAGE pkg_sint;
DROP TABLE sint_registro PURGE;
