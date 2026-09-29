CREATE OR REPLACE PACKAGE pkg_sint
AS
/*******************************************************************************
 * GENERADO AUTOMÁTICAMENTE por herramientas/generar_plsql.py — NO EDITAR A MANO.
 * Para cambiarlo: modificar el mensaje XML o mensajes_entrada/catalogo.json y regenerar.
 *
 * FACHADA DE LA BBDD SINTÉTICA. Una sentencia para crear todo y otra para borrarlo:
 *
 *    EXEC pkg_sint.crear_bbdd;      -- borra lo sintético previo, crea todo, verifica y COMMIT
 *    EXEC pkg_sint.eliminar_bbdd;   -- borra todos los registros 'TESTING:RDR' y COMMIT
 *    EXEC pkg_sint.resumen;         -- filas sintéticas por tabla
 *
 * Entidades: 1 · Variaciones: 0 · Tablas gestionadas: 8
 ******************************************************************************/

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
