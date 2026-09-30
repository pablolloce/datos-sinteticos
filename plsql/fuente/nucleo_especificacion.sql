   /* ==========================================================================
    * NÚCLEO — PARTE PÚBLICA (fragmento escrito a mano)
    * Fuente: plsql/fuente/nucleo_especificacion.sql. El generador lo inserta en
    * la especificación de PKG_SINT. No se ejecuta por separado.
    * ======================================================================== */

   -- Marca de los registros sintéticos (D-001). Único lugar donde aparece el literal.
   gc_usuario_sintetico    CONSTANT VARCHAR2(30) := 'TESTING:RDR';

   -- Límite de seguridad de entidades por llamada (evita ejecuciones accidentales).
   gc_max_entidades        CONSTANT PLS_INTEGER  := 100000;

   -- Errores propios del generador (rango de aplicación -20000..-20999).
   ge_parametro_invalido   CONSTANT PLS_INTEGER  := -20001;
   ge_referencia_no_existe CONSTANT PLS_INTEGER  := -20002;
   ge_purga_bloqueada      CONSTANT PLS_INTEGER  := -20003;
   ge_verificacion_fallida CONSTANT PLS_INTEGER  := -20004;
   ge_bbdd_ya_creada       CONSTANT PLS_INTEGER  := -20005;
   ge_rechazo_motor        CONSTANT PLS_INTEGER  := -20006;  -- GoldenSource rechazaría el mensaje (D-035)

   /* Activa/desactiva las trazas por DBMS_OUTPUT (por defecto activadas). */
   PROCEDURE set_trazas (p_activas IN BOOLEAN);
