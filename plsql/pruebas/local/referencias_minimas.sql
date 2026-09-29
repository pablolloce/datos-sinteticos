--------------------------------------------------------------------------------
-- referencias_minimas.sql
-- SOLO ENTORNO LOCAL DE PRUEBAS. Datos de referencia mínimos que en KYTL_GC ya
-- existen (FT_T_GUNT, FT_T_INCL, FT_T_STDF, FT_T_ENTR) para poder ejecutar los
-- generadores. Valores tomados de los mensajes de mensajes_entrada/.
--------------------------------------------------------------------------------
INSERT INTO ft_t_gunt (gunt_oid, gu_id, gu_typ, gu_cnt, prnt_gu_id, prnt_gu_typ, prnt_gu_cnt,
                       stop_pay_ind, start_tms, last_chg_tms, last_chg_usr_id)
VALUES ('GUNT3B2===', 'AF', 'COUNTRY', 1, 'WORLD', 'WORLD', 1, 'N', SYSDATE, SYSDATE, 'LOCAL');

INSERT INTO ft_t_incl (clsf_oid, indus_cl_set_id, cl_value, cl_nme, start_tms, last_chg_tms, last_chg_usr_id)
VALUES ('=002DCDB88', 'TPFINF', 'FINANCIAL', 'FINANCIAL', SYSDATE, SYSDATE, 'LOCAL');

INSERT INTO ft_t_stdf (stat_def_id, stat_val_typ, stat_nme, start_tms, last_chg_tms, last_chg_usr_id)
VALUES ('UKFIRM', 'CHAR', 'UK FIRM', SYSDATE, SYSDATE, 'LOCAL');
INSERT INTO ft_t_stdf (stat_def_id, stat_val_typ, stat_nme, start_tms, last_chg_tms, last_chg_usr_id)
VALUES ('MIFIFIRM', 'CHAR', 'MIFID FIRM', SYSDATE, SYSDATE, 'LOCAL');

INSERT INTO ft_t_entr (org_id, ent_short_nme, ent_leg_nme, start_tms, last_chg_tms, last_chg_usr_id)
VALUES ('0182', 'ENT 0182', 'ENTIDAD 0182', SYSDATE, SYSDATE, 'LOCAL');
INSERT INTO ft_t_entr (org_id, ent_short_nme, ent_leg_nme, start_tms, last_chg_tms, last_chg_usr_id)
VALUES ('A18', 'ENT A18', 'ENTIDAD A18', SYSDATE, SYSDATE, 'LOCAL');

COMMIT;
