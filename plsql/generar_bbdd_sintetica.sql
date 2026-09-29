--------------------------------------------------------------------------------
-- generar_bbdd_sintetica.sql
-- Construye la BBDD sintética completa: llama a cada generador.
-- Es el script que se ejecuta "a voluntad".
--
-- Uso (SQL Developer, conectado como KYTL_GC): abrir este fichero desde plsql/
-- y ejecutarlo como script (F5). También vale en SQL*Plus / SQLcl: @generar_bbdd_sintetica.sql
--
-- Organización (D-014):
--   1. Entidades de los mensajes: una llamada SIN parámetros por mensaje de
--      mensajes_entrada/ -> una entidad idéntica al mensaje.
--   2. Variaciones: sólo las pedidas expresamente por chat, cada una documentada.
--
-- Todo va en UNA transacción: si falla cualquier generador no queda nada a medias.
-- Para rehacer desde cero: revertir_bbdd_sintetica.sql y volver a lanzar este.
--------------------------------------------------------------------------------
SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

BEGIN
   pkg_sint_nucleo.traza('=== Generación de la BBDD sintética ===');

   ----------------------------------------------------------------------------
   -- 1. Entidades de los mensajes de entrada (valores exactos del mensaje)
   ----------------------------------------------------------------------------
   -- Ejemplo_Alta_Contrapartida_Global.xml
   pkg_sint_fins.generar_contrapartida_global;

   ----------------------------------------------------------------------------
   -- 2. Variaciones solicitadas por chat
   --    Formato: -- [fecha] petición resumida  +  llamada con parámetros
   ----------------------------------------------------------------------------
   -- (ninguna por ahora)

   COMMIT;
   pkg_sint_nucleo.resumen;
END;
/
