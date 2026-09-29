--------------------------------------------------------------------------------
-- purgar.sql
-- Muestra el resumen de datos sintéticos, los borra todos y confirma.
--------------------------------------------------------------------------------
SET SERVEROUTPUT ON SIZE UNLIMITED

BEGIN
   pkg_datos_sinteticos.resumen;
   pkg_datos_sinteticos.purgar(p_commit => TRUE);
   pkg_datos_sinteticos.resumen;
END;
/
