CREATE OR REPLACE PACKAGE pkg_datos_sinteticos
AUTHID CURRENT_USER
AS
/*******************************************************************************
 * Paquete : PKG_DATOS_SINTETICOS
 * Objetivo: Generador de datos sintéticos para las pruebas funcionales
 *           automáticas sobre el modelo GoldenSource (tablas FT_T_XXXX).
 *
 * Origen  : Cada procedimiento GENERAR_<ENTIDAD> traduce un mensaje XML
 *           STREET_REF de la carpeta mensajes_entrada/ a INSERTs, usando el
 *           mapeo XSEG (segmento -> tabla) y XELM (elemento -> columna).
 *
 * Marca   : Todas las filas se insertan con LAST_CHG_USR_ID = 'TESTING:RDR'
 *           (constante GC_USUARIO_SINTETICO) y se eliminan con PURGAR.
 *
 * Transacciones: los procedimientos NO hacen COMMIT salvo que se indique
 *           p_commit => TRUE. Quien llama controla la transacción.
 *
 * Documentación del proyecto: CLAUDE.md y docs/DECISIONES.md
 *
 * Historial:
 *   2026-09-29  Esqueleto inicial: constantes, trazas y purga.
 ******************************************************************************/

   ----------------------------------------------------------------------------
   -- Constantes públicas
   ----------------------------------------------------------------------------

   -- Marca de los registros sintéticos (D-001). Único lugar donde aparece el literal.
   gc_usuario_sintetico  CONSTANT VARCHAR2(30) := 'TESTING:RDR';

   -- Formato de fecha con el que el frontal serializa las fechas del XML (D-007).
   gc_formato_fecha_xml  CONSTANT VARCHAR2(30) := 'MM-DD-YYYY HH:MI:SS AM';
   gc_nls_fecha_xml      CONSTANT VARCHAR2(40) := 'NLS_DATE_LANGUAGE=ENGLISH';

   ----------------------------------------------------------------------------
   -- Utilidades públicas
   ----------------------------------------------------------------------------

   /* Activa/desactiva las trazas por DBMS_OUTPUT (por defecto activadas). */
   PROCEDURE set_trazas (p_activas IN BOOLEAN);

   /* Convierte una fecha tal como viene en el mensaje XML a DATE.
      Ejemplo: fecha_xml('09-29-2026 05:49:55 PM'). */
   FUNCTION fecha_xml (p_texto IN VARCHAR2) RETURN DATE DETERMINISTIC;

   ----------------------------------------------------------------------------
   -- Generación de entidades (se añade un procedimiento por mensaje de entrada)
   ----------------------------------------------------------------------------

   -- (pendiente) PROCEDURE generar_contrapartida_global (...);

   ----------------------------------------------------------------------------
   -- Consulta y purga
   ----------------------------------------------------------------------------

   /* Muestra por DBMS_OUTPUT cuántas filas sintéticas hay en cada tabla gestionada. */
   PROCEDURE resumen;

   /* Borra TODAS las filas sintéticas (LAST_CHG_USR_ID = GC_USUARIO_SINTETICO)
      de las tablas gestionadas, respetando el orden de dependencias (D-006). */
   PROCEDURE purgar (p_commit IN BOOLEAN DEFAULT FALSE);

END pkg_datos_sinteticos;
/
