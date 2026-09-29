# Técnicas de optimización Oracle 19c

Catálogo de técnicas aplicadas (o candidatas) en el generador, con su justificación.
Cada técnica que se incorpore al código se marca como **APLICADA** e indica dónde.

| Técnica | Estado | Dónde |
|---|---|---|
| SQL estático generado (no SQL dinámico por fila) | APLICADA | paquetes `SINT_E_*` (D-017) |
| `FORALL` por segmento sobre colección de claves | APLICADA | `SINT_E_*.generar` |
| Claves generadas en memoria antes de insertar | APLICADA | `SINT_E_*.generar` (colección `t_lista_claves`) |
| Referencias validadas una vez por llamada | APLICADA | `SINT_E_*.generar`, paso 1 |
| Un paquete por entidad | APLICADA (mantenibilidad) | D-017 |
| Variables de enlace (bind) | APLICADA | `pkg_sint_nucleo.contar` / `purgar`; SQL estático en el resto |
| `%TYPE` en parámetros y comparaciones con CHAR | APLICADA | parámetros de variación, D-012 |
| Transacción única + `SAVEPOINT` | APLICADA | `pkg_sint.crear_bbdd`, `SINT_E_*.generar`, `purgar` |
| `DBMS_ASSERT` en SQL dinámico | APLICADA (seguridad) | `pkg_sint_nucleo.tabla_segura` |
| Hint `APPEND` / `APPEND_VALUES` (direct-path) | DESCARTADA | ver abajo |

Medición en Oracle local (contenedor, sin concurrencia): 303 contrapartidas globales
(3.030 filas, 10 FORALL por llamada) en ~0,05 s. Para "cientos de entidades" el coste es
despreciable; el tiempo de `crear_bbdd` lo dominará la purga previa (ver abajo).

## SQL estático generado
Cada entidad se traduce a INSERT estáticos. Frente a un motor genérico que construyera SQL
dinámico leyendo el XML en ejecución:
- Oracle compila y valida en la instalación que las tablas y columnas existen y los tipos
  encajan (los errores aparecen al instalar, no al crear datos).
- Cursores compartidos sin *parse* en cada ejecución.
- El código es legible: cada valor lleva un comentario con el elemento del mensaje del que sale.

## FORALL por segmento
Todas las claves de las N entidades se generan primero en una colección y después cada
segmento se inserta con **un `FORALL`**: un único cambio de contexto PL/SQL→SQL por segmento,
en lugar de uno por fila. Una entidad con 40 segmentos y `p_cantidad => 200` son 40 sentencias,
no 8.000. Desde 11g se pueden referenciar campos de registro (`l_k(i).campo`) en `FORALL`.

## Referencias validadas una vez por llamada
Los datos maestros de un mensaje son iguales para todas sus copias: se comprueban una vez
(un `COUNT(*)` por PK/UK, con índice) antes de insertar; si falta alguno se aborta sin escribir.

## Un paquete por entidad
El tamaño de un paquete no afecta a la velocidad de sus INSERT, pero sí al tiempo de
compilación, a la memoria que ocupa en la *shared pool* y a la invalidación en cascada. Con
un paquete por entidad cada cambio sólo recompila esa entidad, y un paquete con cientos de
columnas sigue siendo manejable.

## %TYPE con columnas CHAR (D-012)
Los parámetros de variación se declaran con el `%TYPE` de la columna más restrictiva donde se
usan: comparación correcta con columnas CHAR, sin conversiones implícitas, y un valor
demasiado largo falla al llamar, no a mitad de la inserción.

## Transacción única + SAVEPOINT
`crear_bbdd` es todo o nada: purga previa + todas las entidades + verificación en una
transacción. Cada `generar` marca un `SAVEPOINT` y, ante error, deshace sólo lo suyo.

## Hint APPEND / APPEND_VALUES (direct-path) — descartado
Reduce redo/undo, pero bloquea la tabla en exclusiva hasta el COMMIT, impide volver a leerla
en la misma transacción (la verificación lo haría) y no aporta nada con cientos de filas. En
tablas compartidas de GoldenSource sería contraproducente.

## Purga
`DELETE ... WHERE last_chg_usr_id = :usr` recorre cada tabla completa si no hay índice sobre
`LAST_CHG_USR_ID`. En tablas grandes de producción (p. ej. `FT_T_FINS`) puede tardar
segundos por tabla; si con muchas tablas fuera un problema: tabla de control con las claves
generadas (P-008) para borrar por PK, o índice sobre `LAST_CHG_USR_ID` (a valorar con el DBA).
