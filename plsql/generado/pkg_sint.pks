CREATE OR REPLACE PACKAGE pkg_sint
AS
/*******************************************************************************
 * GENERADO AUTOMÁTICAMENTE por herramientas/generar_plsql.py — NO EDITAR A MANO.
 * Para cambiarlo: modificar el mensaje XML o mensajes_entrada/catalogo.json y regenerar.
 * El núcleo se escribe a mano en plsql/fuente/ y se inserta aquí al generar.
 *
 * PKG_SINT — GENERADOR DE LA BBDD SINTÉTICA (único paquete, D-023)
 *
 *    EXEC pkg_sint.crear_bbdd;      -- SÓLO inserta toda la BBDD sintética y COMMIT (rápido)
 *    EXEC pkg_sint.eliminar_bbdd;   -- SÓLO borra lo insertado, por clave, y COMMIT (rápido)
 *    EXEC pkg_sint.resumen;         -- filas sintéticas registradas por tabla
 *    EXEC pkg_sint.limpiar_restos;  -- (ocasional, LENTO) borra por LAST_CHG_USR_ID lo no registrado
 *
 * Cada fila creada se anota en la tabla SINT_REGISTRO (tabla, columna PK, clave), de modo
 * que borrar y verificar van por clave primaria y no recorren tablas de millones de filas.
 *
 * Organización:
 *    1. NÚCLEO      utilidades comunes (plsql/fuente/)
 *    2. ENTIDADES   un procedimiento crear_<entidad> por mensaje, agrupados por unidad
 *    3. API         crear_bbdd, eliminar_bbdd, resumen, verificar, limpiar_restos
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
   ge_bbdd_ya_creada       CONSTANT PLS_INTEGER  := -20005;

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

   /* Inserta TODA la BBDD sintética (entidades de los mensajes + variaciones) en UNA
      transacción, la verifica (por clave, rápido) y hace COMMIT. No borra nada: si ya
      hay una BBDD sintética registrada, falla (ORA-20005) para no duplicarla. */
   PROCEDURE crear_bbdd (p_commit IN BOOLEAN DEFAULT TRUE);

   /* Borra, por clave primaria, todo lo insertado (SINT_REGISTRO) y hace COMMIT. */
   PROCEDURE eliminar_bbdd (p_commit IN BOOLEAN DEFAULT TRUE);

   /* Filas sintéticas registradas por tabla (sólo lee SINT_REGISTRO). */
   PROCEDURE resumen;

   /* Comprueba que las filas registradas existen y cuadran con lo esperado (ORA-20004). */
   PROCEDURE verificar;

   /* LENTO (recorre las tablas completas): borra toda fila con LAST_CHG_USR_ID =
      'TESTING:RDR' de las tablas gestionadas, esté o no registrada, y vacía el registro.
      Sólo para restos de versiones anteriores o datos no registrados. */
   PROCEDURE limpiar_restos (p_commit IN BOOLEAN DEFAULT TRUE);

END pkg_sint;
/
