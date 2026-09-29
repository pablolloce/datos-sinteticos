--------------------------------------------------------------------------------
-- verificar_contrapartida_global.sql
-- Comprueba la coherencia de las Contrapartidas Globales sintéticas: cada
-- FT_T_FINS sintética debe tener exactamente las filas hijas esperadas.
-- Resultado esperado: la consulta de incoherencias NO devuelve filas.
--------------------------------------------------------------------------------
SET PAGESIZE 100 LINESIZE 200

PROMPT == Contrapartidas sintéticas
SELECT COUNT(*) AS contrapartidas
  FROM ft_t_fins
 WHERE last_chg_usr_id = 'TESTING:RDR';

PROMPT == Incoherencias (debe salir vacío)
WITH fins AS (
   SELECT inst_mnem, inst_nme FROM ft_t_fins WHERE last_chg_usr_id = 'TESTING:RDR'
), conteos AS (
   SELECT f.inst_mnem, f.inst_nme,
          (SELECT COUNT(*) FROM ft_t_fist x WHERE x.inst_mnem = f.inst_mnem)             AS fist,
          (SELECT COUNT(*) FROM ft_t_figu x WHERE x.inst_mnem = f.inst_mnem)             AS figu,
          (SELECT COUNT(*) FROM financial_legal_names x WHERE x.inst_mnem = f.inst_mnem) AS flg,
          (SELECT COUNT(*) FROM ft_t_finr x WHERE x.inst_mnem = f.inst_mnem)             AS finr,
          (SELECT COUNT(*) FROM ft_t_firl x WHERE x.inst_mnem = f.inst_mnem)             AS firl,
          (SELECT COUNT(*) FROM ft_t_enfr x WHERE x.finr_inst_mnem = f.inst_mnem)        AS enfr,
          (SELECT COUNT(*) FROM ft_t_frcl x WHERE x.inst_mnem = f.inst_mnem)             AS frcl
     FROM fins f
)
SELECT *
  FROM conteos
 WHERE (fist, figu, flg, finr, firl, enfr, frcl) NOT IN ((2, 1, 1, 1, 1, 2, 1));
