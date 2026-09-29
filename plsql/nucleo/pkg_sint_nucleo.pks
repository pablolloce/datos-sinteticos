CREATE OR REPLACE PACKAGE pkg_sint_nucleo
AS
/*******************************************************************************
 * Paquete : PKG_SINT_NUCLEO
 * Objetivo: Núcleo común del generador de datos sintéticos. Lo usan todos los
 *           paquetes de unidad funcional (PKG_SINT_<UNIDAD>).
 *
 * Contiene:
 *   - Constantes comunes (marca de registro sintético, formatos, valores técnicos).
 *   - Trazas por DBMS_OUTPUT.
 *   - Generación de claves internas (OIDs) con la función NEW_OID de GoldenSource.
 *   - Resolución/validación de datos de referencia (deben existir en BBDD).
 *   - Resumen y purga (reversión) de TODOS los datos sintéticos.
 *
 * Esquema : KYTL_GC (derechos del propietario: se instala en el mismo esquema
 *           que las tablas FT_T_*).
 *
 * Documentación: CLAUDE.md y docs/DECISIONES.md
 *
 * Historial:
 *   2026-09-29  Versión inicial.
 ******************************************************************************/

   ----------------------------------------------------------------------------
   -- Constantes comunes
   ----------------------------------------------------------------------------

   -- Marca de los registros sintéticos (D-001). Único lugar donde aparece el literal.
   gc_usuario_sintetico   CONSTANT VARCHAR2(30) := 'TESTING:RDR';

   -- Formato con el que el frontal serializa las fechas del XML (D-007).
   gc_formato_fecha_xml   CONSTANT VARCHAR2(30) := 'MM-DD-YYYY HH:MI:SS AM';
   gc_nls_fecha_xml       CONSTANT VARCHAR2(40) := 'NLS_DATE_LANGUAGE=ENGLISH';

   -- Valores técnicos habituales en los mensajes del frontal.
   gc_estado_activo       CONSTANT VARCHAR2(20) := 'ACTIVE';   -- DATA_STAT_TYP
   gc_fuente_rdr          CONSTANT VARCHAR2(40) := 'RDR';      -- DATA_SRC_ID

   -- Límite de seguridad de entidades por llamada (evita ejecuciones accidentales).
   gc_max_entidades       CONSTANT PLS_INTEGER  := 100000;

   -- Errores propios del generador (rango de aplicación -20000..-20999).
   ge_parametro_invalido  CONSTANT PLS_INTEGER  := -20001;
   ge_referencia_no_existe CONSTANT PLS_INTEGER := -20002;
   ge_purga_bloqueada     CONSTANT PLS_INTEGER  := -20003;

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
   -- Datos de referencia (D-009): deben existir; si no, error ge_referencia_no_existe
   ----------------------------------------------------------------------------

   /* GUNT_OID de una unidad geográfica vigente (FT_T_GUNT). Ej.: ('AF','COUNTRY',1). */
   FUNCTION oid_unidad_geografica (p_gu_id  IN VARCHAR2,
                                   p_gu_typ IN VARCHAR2,
                                   p_gu_cnt IN NUMBER) RETURN VARCHAR2;

   /* CLSF_OID de una clasificación vigente (FT_T_INCL). Ej.: ('TPFINF','FINANCIAL'). */
   FUNCTION oid_clasificacion (p_indus_cl_set_id IN VARCHAR2,
                               p_cl_value        IN VARCHAR2) RETURN VARCHAR2;

   /* Comprueba que existe la definición de estadístico (FT_T_STDF). */
   PROCEDURE validar_estadistico (p_stat_def_id IN VARCHAR2);

   /* Comprueba que existe la entidad organizativa (FT_T_ENTR). */
   PROCEDURE validar_organizacion (p_org_id IN VARCHAR2);

   ----------------------------------------------------------------------------
   -- Resumen y purga (reversión)
   ----------------------------------------------------------------------------

   /* Muestra por DBMS_OUTPUT cuántas filas sintéticas hay en cada tabla gestionada. */
   PROCEDURE resumen;

   /* Borra TODAS las filas sintéticas (LAST_CHG_USR_ID = gc_usuario_sintetico) de
      las tablas gestionadas, hijas antes que padres (D-006). */
   PROCEDURE purgar (p_commit IN BOOLEAN DEFAULT FALSE);

END pkg_sint_nucleo;
/
