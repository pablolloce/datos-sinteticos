CREATE OR REPLACE PACKAGE pkg_sint
AS
/*******************************************************************************
 * GENERADO AUTOMÁTICAMENTE por herramientas/generar_plsql.py — NO EDITAR A MANO.
 * Para cambiarlo: modificar el mensaje XML o mensajes_entrada/catalogo.json y regenerar.
 * El núcleo se escribe a mano en plsql/fuente/ y se inserta aquí al generar.
 *
 * PKG_SINT — GENERADOR DE LA BBDD SINTÉTICA (único paquete, D-023)
 *
 *    EXEC pkg_sint.crear_bbdd;      -- borra lo sintético previo, crea todo, verifica y COMMIT
 *    EXEC pkg_sint.eliminar_bbdd;   -- borra todos los registros 'TESTING:RDR' y COMMIT
 *    EXEC pkg_sint.resumen;         -- filas sintéticas por tabla
 *
 * Organización:
 *    1. NÚCLEO      utilidades comunes (plsql/fuente/)
 *    2. ENTIDADES   un procedimiento crear_<entidad> por mensaje, agrupados por unidad
 *    3. API         crear_bbdd, eliminar_bbdd, resumen, verificar
 *
 * Entidades: 1 · Variaciones: 0 · Tablas gestionadas: 8
 *   Unidad Procedimiento                  Filas  Mensaje
 *   FINS   crear_contrapartida_global       10 filas  mensajes_entrada/Ejemplo_Alta_Contrapartida_Global.xml
 ******************************************************************************/

   -- #########################################################################
   -- 1. NÚCLEO
   -- #########################################################################

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

   /* Activa/desactiva las trazas por DBMS_OUTPUT (por defecto activadas). */
   PROCEDURE set_trazas (p_activas IN BOOLEAN);

   -- #########################################################################
   -- 2. ENTIDADES
   -- #########################################################################

   -- #########################################################################
   -- ENTIDADES — UNIDAD FINS
   -- #########################################################################

   /* ------------------------------------------------------------------------
      * CONTRAPARTIDA_GLOBAL
      * Alta de contrapartida global: institución financiera con estadísticos, país, nombre legal, rol, relación global, roles de entidad/sucursal y clasificación.
      * Mensaje: mensajes_entrada/Ejemplo_Alta_Contrapartida_Global.xml
      * Filas por entidad (10):
      *   FT_T_FINS                    1
      *   FT_T_FIST                    2
      *   FT_T_FIGU                    1
      *   FINANCIAL_LEGAL_NAMES        1
      *   FT_T_FINR                    1
      *   FT_T_FIRL                    1
      *   FT_T_ENFR                    2
      *   FT_T_FRCL                    1
      * Parámetros de variación (defecto = valor del mensaje, D-014):
      *   (ninguno: la entidad es idéntica al mensaje)
      * Crea p_cantidad entidades con los valores del mensaje; sólo las claves
      * internas son nuevas (NEW_OID). No hace COMMIT.
      * ---------------------------------------------------------------------- */
   PROCEDURE crear_contrapartida_global (
      p_cantidad IN PLS_INTEGER DEFAULT 1);

   -- #########################################################################
   -- 3. API
   -- #########################################################################

   /* Crea la BBDD sintética completa en UNA transacción.
      p_limpiar_antes: borra antes los registros sintéticos existentes (recomendado).
      p_commit       : confirma al terminar. */
   PROCEDURE crear_bbdd (p_limpiar_antes IN BOOLEAN DEFAULT TRUE,
                         p_commit        IN BOOLEAN DEFAULT TRUE);

   /* Borra TODOS los registros sintéticos de las tablas gestionadas. */
   PROCEDURE eliminar_bbdd (p_commit IN BOOLEAN DEFAULT TRUE);

   /* Filas sintéticas por tabla gestionada. */
   PROCEDURE resumen;

   /* Compara las filas sintéticas con las esperadas; ORA-20004 si no cuadran. */
   PROCEDURE verificar;

END pkg_sint;
/
