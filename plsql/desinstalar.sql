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

PROMPT == Borrando PKG_SINT y SINT_REGISTRO
DROP PACKAGE pkg_sint;
DROP TABLE sint_registro PURGE;
