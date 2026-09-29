CREATE OR REPLACE PACKAGE pkg_sint_nucleo
AS
/*******************************************************************************
 * Paquete : PKG_SINT_NUCLEO
 * Objetivo: Núcleo común del generador de datos sintéticos.
 *
 * Contiene:
 *   - Constantes comunes (marca de registro sintético, formatos, errores).
 *   - Trazas por DBMS_OUTPUT.
 *   - Generación de claves internas (OIDs) con la función NEW_OID de GoldenSource.
 *   - Validación de datos de referencia (deben existir en BBDD).
 *   - Resumen, conteo y purga genéricos sobre listas de tablas.
 *
 * Lo usan los paquetes GENERADOS (plsql/generado/): SINT_E_<ENTIDAD> y la
 * fachada PKG_SINT. Este paquete se escribe a mano y debe cambiar poco.
 *
 * Esquema : KYTL_GC (derechos del propietario: se instala en el mismo esquema
 *           que las tablas FT_T_*).
 *
 * Documentación: CLAUDE.md y docs/DECISIONES.md
 *
 * Historial:
 *   2026-09-29  Versión inicial.
 *   2026-09-29  Purga/resumen sobre listas recibidas; validación genérica de referencias (D-017).
 ******************************************************************************/

   ----------------------------------------------------------------------------
   -- Constantes comunes
   ----------------------------------------------------------------------------

   -- Marca de los registros sintéticos (D-001). Único lugar donde aparece el literal.
   gc_usuario_sintetico   CONSTANT VARCHAR2(30) := 'TESTING:RDR';

   -- Formato con el que el frontal serializa las fechas del XML (D-007).
   gc_formato_fecha_xml   CONSTANT VARCHAR2(30) := 'MM-DD-YYYY HH:MI:SS AM';
   gc_nls_fecha_xml       CONSTANT VARCHAR2(40) := 'NLS_DATE_LANGUAGE=ENGLISH';

   -- Límite de seguridad de entidades por llamada (evita ejecuciones accidentales).
   gc_max_entidades       CONSTANT PLS_INTEGER  := 100000;

   -- Errores propios del generador (rango de aplicación -20000..-20999).
   ge_parametro_invalido  CONSTANT PLS_INTEGER  := -20001;
   ge_referencia_no_existe CONSTANT PLS_INTEGER := -20002;
   ge_purga_bloqueada     CONSTANT PLS_INTEGER  := -20003;
   ge_verificacion_fallida CONSTANT PLS_INTEGER := -20004;

   ----------------------------------------------------------------------------
   -- Tipos comunes
   ----------------------------------------------------------------------------
   TYPE t_lista_tablas  IS TABLE OF VARCHAR2(128);
   TYPE t_lista_numeros IS TABLE OF PLS_INTEGER;

   ----------------------------------------------------------------------------
   -- Utilidades
   ----------------------------------------------------------------------------

   /* Activa/desactiva las trazas por DBMS_OUTPUT (por defecto activadas). */
   PROCEDURE set_trazas (p_activas IN BOOLEAN);

   /* Escribe una traza con marca de tiempo (si las trazas están activas). */
   PROCEDURE traza (p_texto IN VARCHAR2);

   /* Convierte una fecha tal como viene en el mensaje XML a DATE.
      Ejemplo: fecha_xml('09-29-2026 05:49:55 PM'). */
   FUNCTION fecha_xml (p_texto IN VARCHAR2) RETURN DATE DETERMINISTIC;

   /* Devuelve un OID nuevo de GoldenSource (envoltorio de NEW_OID, D-008). */
   FUNCTION nuevo_oid RETURN VARCHAR2;

   /* Lanza ge_parametro_invalido si p_cantidad no está en 1..gc_max_entidades. */
   PROCEDURE validar_cantidad (p_cantidad IN PLS_INTEGER);

   ----------------------------------------------------------------------------
   -- Datos de referencia (D-019)
   ----------------------------------------------------------------------------

   /* Lanza ge_referencia_no_existe si p_encontradas = 0. Los paquetes de entidad
      generados cuentan el dato maestro y llaman a este procedimiento. */
   PROCEDURE exigir_referencia (p_encontradas IN PLS_INTEGER,
                                p_descripcion IN VARCHAR2);

   ----------------------------------------------------------------------------
   -- Resumen y purga (las listas de tablas las genera PKG_SINT)
   ----------------------------------------------------------------------------

   /* Nº de filas sintéticas de una tabla. */
   FUNCTION contar (p_tabla IN VARCHAR2) RETURN PLS_INTEGER;

   /* Muestra por DBMS_OUTPUT las filas sintéticas de cada tabla de la lista. */
   PROCEDURE resumen (p_tablas IN t_lista_tablas);

   /* Borra TODAS las filas sintéticas de las tablas de la lista, en el orden dado
      (hijas antes que padres). Atómica: si falla, no borra nada (D-006). */
   PROCEDURE purgar (p_tablas IN t_lista_tablas,
                     p_commit IN BOOLEAN DEFAULT FALSE);

END pkg_sint_nucleo;
/
