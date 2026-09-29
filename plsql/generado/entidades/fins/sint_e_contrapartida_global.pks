CREATE OR REPLACE PACKAGE sint_e_contrapartida_global
AS
/*******************************************************************************
 * GENERADO AUTOMÁTICAMENTE por herramientas/generar_plsql.py — NO EDITAR A MANO.
 * Para cambiarlo: modificar el mensaje XML o mensajes_entrada/catalogo.json y regenerar.
 *
 * Entidad : CONTRAPARTIDA_GLOBAL
 * Alta de contrapartida global: institución financiera con estadísticos, país, nombre legal, rol, relación global, roles de entidad/sucursal y clasificación.
 * Mensaje : mensajes_entrada/Ejemplo_Alta_Contrapartida_Global.xml
 * Unidad  : FINS
 *
 * Filas insertadas por entidad (10):
 *   FT_T_FINS                    1
 *   FT_T_FIST                    2
 *   FT_T_FIGU                    1
 *   FINANCIAL_LEGAL_NAMES        1
 *   FT_T_FINR                    1
 *   FT_T_FIRL                    1
 *   FT_T_ENFR                    2
 *   FT_T_FRCL                    1
 *
 * Parámetros de variación (valor por defecto = valor del mensaje, D-014):
 *   (ninguno: la entidad es idéntica al mensaje)
 ******************************************************************************/

   gc_filas_por_entidad CONSTANT PLS_INTEGER := 10;

   /* Crea p_cantidad entidades con los valores del mensaje; sólo las claves
      internas son nuevas (NEW_OID). No hace COMMIT. Ante error deshace lo
      insertado por esta llamada y relanza la excepción. */
   PROCEDURE generar (
      p_cantidad IN PLS_INTEGER DEFAULT 1);

END sint_e_contrapartida_global;
/
