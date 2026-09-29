CREATE OR REPLACE PACKAGE pkg_sint_fins
AS
/*******************************************************************************
 * Paquete : PKG_SINT_FINS
 * Unidad  : Instituciones financieras / contrapartidas (MAIN_ENTITY_TBL_TYP = FINS)
 * Objetivo: Generar entidades sintéticas de esta unidad funcional a partir de
 *           los mensajes XML de mensajes_entrada/.
 *
 * Todas las filas se marcan con LAST_CHG_USR_ID = pkg_sint_nucleo.gc_usuario_sintetico
 * y se borran con pkg_sint_nucleo.purgar.
 *
 * Transacciones: no hace COMMIT salvo p_commit => TRUE. Ante un error deshace
 * todo lo insertado en la llamada (SAVEPOINT) y relanza la excepción.
 *
 * Historial:
 *   2026-09-29  generar_contrapartida_global (Ejemplo_Alta_Contrapartida_Global.xml).
 *   2026-09-29  Valores por defecto = valores del mensaje; sin numeración automática (D-014).
 ******************************************************************************/

   /* ---------------------------------------------------------------------------
    * GENERAR_CONTRAPARTIDA_GLOBAL
    * Mensaje origen: mensajes_entrada/Ejemplo_Alta_Contrapartida_Global.xml
    * Mapeo        : docs/mapeos/Ejemplo_Alta_Contrapartida_Global.md
    *
    * Por cada entidad inserta (11 filas):
    *   FT_T_FINS (1)  institución financiera
    *   FT_T_FIST (2)  estadísticos UKFIRM y MIFIFIRM
    *   FT_T_FIGU (1)  participación geográfica (país)
    *   FINANCIAL_LEGAL_NAMES (1) nombre legal
    *   FT_T_FINR (1)  rol INDVDUAL / BUSINESS
    *   FT_T_FIRL (1)  relación GLOBAL (la institución es su propia matriz)
    *   FT_T_ENFR (2)  rol ENT_OWN (entidad) y BRANCH_OWN (sucursal)
    *   FT_T_FRCL (1)  clasificación del rol (TPFINF / FINANCIAL)
    *
    * Fidelidad al mensaje (D-014): llamado sin parámetros crea UNA entidad con
    * exactamente los valores del mensaje (sólo las claves internas son nuevas, NEW_OID).
    * Los parámetros existen para las variaciones que se pidan expresamente por chat;
    * sus valores por defecto son los del mensaje.
    *
    * Parámetros:
    *   p_cantidad            nº de contrapartidas a crear (todas con los mismos valores).
    *   p_nombre              INST_NME, INST_DESC, INST_LEGAL_NME y FLG_LEGAL_NME
    *                         (en el mensaje los cuatro valen lo mismo).
    *   p_pais                GU_ID del país de la participación geográfica (FT_T_FIGU).
    *   p_org_id_entidad      ORG_ID del rol ENT_OWN.
    *   p_org_id_sucursal     ORG_ID del rol BRANCH_OWN.
    *   p_fecha_constitucion  INST_FOUNDING_DTE.
    *   p_commit              TRUE = confirma al terminar.
    * ------------------------------------------------------------------------- */
   PROCEDURE generar_contrapartida_global (
      p_cantidad            IN PLS_INTEGER DEFAULT 1,
      p_nombre              IN VARCHAR2    DEFAULT 'PROBANDO',
      p_pais                IN VARCHAR2    DEFAULT 'AF',
      p_org_id_entidad      IN VARCHAR2    DEFAULT '0182',
      p_org_id_sucursal     IN VARCHAR2    DEFAULT 'A18',
      p_fecha_constitucion  IN DATE        DEFAULT DATE '2026-09-29',
      p_commit              IN BOOLEAN     DEFAULT FALSE);

END pkg_sint_fins;
/
