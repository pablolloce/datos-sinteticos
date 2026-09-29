# Técnicas de optimización Oracle 19c

Catálogo de técnicas aplicadas (o candidatas) en el generador, con su justificación.
Cada técnica que se incorpore al código se marca como **APLICADA** e indica dónde.

| Técnica | Estado | Dónde |
|---|---|---|
| Variables de enlace (bind) | APLICADA | `purgar`, `resumen` |
| `INSERT ... SELECT` con generador de filas | PREVISTA | `generar_<entidad>` |
| `FORALL` + `BULK COLLECT` | PREVISTA | cuando haya que encadenar claves entre tablas |
| Control de transacción por el llamador | APLICADA | todo el paquete |
| `DETERMINISTIC` en funciones puras | APLICADA | `fecha_xml` |
| `DBMS_ASSERT` en SQL dinámico | APLICADA (seguridad) | `tabla_segura` |
| Hint `APPEND` (direct-path) | DESCARTADA POR AHORA | ver abajo |

## Variables de enlace
El SQL dinámico usa `:usr` en lugar de concatenar el literal. Oracle reutiliza el cursor
compartido (evita *hard parse*) y se elimina el riesgo de inyección.

## Generación en bloque en una sola sentencia SQL
Para crear N entidades no se hace un bucle con N INSERTs (N cambios de contexto
PL/SQL↔SQL), sino una sola sentencia:

```sql
INSERT INTO ft_t_fins (inst_mnem, inst_nme, ..., last_chg_usr_id)
SELECT <oid generado para n>, 'CPTY_SINT_' || LPAD(n, 4, '0'), ..., gc_usuario_sintetico
FROM  (SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= p_cantidad);
```
El motor SQL procesa todas las filas en una pasada: menos *context switches*, menos redo
por fila y mejor uso de la caché.

## FORALL / BULK COLLECT
Cuando una tabla hija necesita claves generadas en la tabla padre, se guardan en una
colección (`RETURNING ... BULK COLLECT INTO`) y se insertan las hijas con `FORALL`:
un único cambio de contexto por lote en lugar de uno por fila.

## Transacción controlada por el llamador
Los procedimientos no hacen `COMMIT` interno: se evita el coste de sincronizar el redo en
cada entidad y la generación completa es atómica (o todo o nada). La purga admite
`p_commit => TRUE` para su uso desde scripts.

## Hint APPEND (direct-path insert) — descartado por ahora
Escribe por encima de la *high water mark* y reduce redo/undo, pero bloquea la tabla en
exclusiva hasta el COMMIT, obliga a confirmar antes de volver a leer la tabla en la misma
sesión y se degrada a inserción convencional si hay FKs o triggers activos. En tablas
compartidas de GoldenSource no compensa salvo volúmenes muy grandes (ver P-009).

## Purga
El `DELETE ... WHERE last_chg_usr_id = :usr` recorre cada tabla completa si no hay índice
sobre `LAST_CHG_USR_ID`. Para volúmenes de pruebas es aceptable; si la purga fuera lenta,
alternativas: índice (a valorar con el DBA) o tabla de control con las claves generadas
(ver P-008), que además permite borrar por clave primaria.
