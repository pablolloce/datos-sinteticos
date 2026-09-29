# Técnicas de optimización Oracle 19c

Catálogo de técnicas aplicadas (o candidatas) en el generador, con su justificación.
Cada técnica que se incorpore al código se marca como **APLICADA** e indica dónde.

| Técnica | Estado | Dónde |
|---|---|---|
| `FORALL` sobre colección de registros | APLICADA | `pkg_sint_fins.generar_contrapartida_global` |
| Claves generadas en memoria antes de insertar | APLICADA | ídem (colección `t_contrapartidas`) |
| Referencias resueltas una vez por llamada | APLICADA | ídem, paso 2 (funciones del núcleo) |
| Variables de enlace (bind) | APLICADA | `pkg_sint_nucleo.purgar` / `resumen`; SQL estático en el resto |
| Variables `%TYPE` en comparaciones con CHAR | APLICADA | `pkg_sint_nucleo` (referencias), D-012 |
| Control de transacción por el llamador + `SAVEPOINT` | APLICADA | generadores y purga |
| `DETERMINISTIC` en funciones puras | APLICADA | `pkg_sint_nucleo.fecha_xml` |
| `DBMS_ASSERT` en SQL dinámico | APLICADA (seguridad) | `pkg_sint_nucleo.tabla_segura` |
| División en paquetes por unidad funcional | APLICADA (mantenibilidad) | D-011 |
| Hint `APPEND` / `APPEND_VALUES` (direct-path) | DESCARTADA | ver abajo |

Medición en Oracle local (contenedor, sin concurrencia): 500 contrapartidas globales
= 5.500 filas en ~0,05 s. Para "cientos de entidades" el coste es despreciable.

## FORALL sobre colección de registros
Por cada entidad se generan todas sus claves (`NEW_OID`) en una colección PL/SQL y después
se lanza **un `FORALL` por tabla**. `FORALL` envía todas las filas al motor SQL en un único
cambio de contexto PL/SQL→SQL, en lugar de uno por fila (con 500 entidades: 11 sentencias
en vez de 5.500). Desde 11g se pueden referenciar campos de registro (`l_cptys(i).campo`)
dentro de `FORALL`.

Se prefiere a un único `INSERT ... SELECT ... CONNECT BY LEVEL <= n` porque varias tablas
hijas necesitan las claves generadas para la tabla padre: con la colección cada clave se
genera una vez y se reutiliza en todas las tablas sin volver a leer la BBDD.

## Referencias resueltas una vez por llamada
`GUNT_OID`, `CLSF_OID`, `STAT_DEF_ID` y `ORG_ID` son iguales para todas las entidades de una
llamada: se buscan/validan una sola vez antes de insertar (4–6 consultas por llamada en vez
de por fila), y si falta alguna se aborta sin haber escrito nada.

## Variables %TYPE con columnas CHAR (D-012)
Además de ser correcto funcionalmente (comparación con relleno de blancos), comparar la
columna con una variable de su mismo tipo evita conversiones implícitas y permite usar el
índice de la PK/UK, cosa que `RTRIM(columna) = :valor` impediría.

## Variables de enlace
El SQL dinámico de purga/resumen usa `:usr` en lugar de concatenar el literal: Oracle
reutiliza el cursor compartido (evita *hard parse*) y se elimina el riesgo de inyección.
El SQL estático PL/SQL ya usa variables de enlace de forma automática.

## Transacción controlada por el llamador + SAVEPOINT
Los generadores no hacen `COMMIT` interno (salvo `p_commit => TRUE`): se evita el coste de
confirmar cada entidad y `generar_bbdd_sintetica.sql` es atómico (todo o nada). Cada
generador marca un `SAVEPOINT` y ante error deshace sólo lo suyo, dejando intacto el resto
de la transacción del llamador.

## División en paquetes por unidad funcional
El tamaño de un paquete no afecta a la velocidad de ejecución de sus INSERT, pero sí a:
tiempo de compilación, memoria de la *shared pool* que ocupa al cargarse y, sobre todo, a
la invalidación en cascada (recompilar un paquete enorme por cambiar una entidad). Con un
núcleo estable y paquetes por unidad, cada cambio sólo recompila su unidad.

## Hint APPEND / APPEND_VALUES (direct-path) — descartado
Escribe por encima de la *high water mark* y reduce redo/undo, pero bloquea la tabla en
exclusiva hasta el COMMIT, obliga a confirmar antes de volver a leer la tabla en la misma
sesión y no aporta nada con cientos de filas. En tablas compartidas de GoldenSource sería
contraproducente.

## Purga
`DELETE ... WHERE last_chg_usr_id = :usr` recorre cada tabla completa si no hay índice
sobre `LAST_CHG_USR_ID`. En las tablas grandes de producción (p. ej. `FT_T_FINS`) puede
tardar segundos; si fuera un problema: tabla de control con las claves generadas (P-008)
para borrar por PK, o índice sobre `LAST_CHG_USR_ID` (a valorar con el DBA).
