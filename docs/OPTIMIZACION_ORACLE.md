# Técnicas de optimización Oracle 19c

Catálogo de técnicas aplicadas (o candidatas) en el generador, con su justificación.
Cada técnica que se incorpore al código se marca como **APLICADA** e indica dónde.

| Técnica | Estado | Dónde |
|---|---|---|
| Índices temporales INVISIBLE ONLINE durante el borrado | APLICADA | job de borrado, `crear_indices_temporales` (D-028) |
| Registro de claves (IOT) + borrado por PK | APLICADA | `SINT_REGISTRO`, `eliminar_bbdd`, `verificar` (D-024) |
| SQL estático generado (no SQL dinámico por fila) | APLICADA | `PKG_SINT.crear_<entidad>` (D-017) |
| `FORALL` por segmento sobre colección de claves | APLICADA | `crear_<entidad>` |
| Claves generadas en memoria antes de insertar | APLICADA | `crear_<entidad>` (colección `t_lista_claves`) |
| Referencias validadas una vez por llamada | APLICADA | `crear_<entidad>`, paso 1 |
| Un único paquete, tamaño vigilado | APLICADA | D-023 |
| Variables de enlace (bind) | APLICADA | `borrar_tabla_registrada`, `purgar_por_usuario`; SQL estático en el resto |
| `%TYPE` en parámetros y comparaciones con CHAR | APLICADA | parámetros de variación, D-012 |
| Transacción única + `SAVEPOINT` | APLICADA | `crear_bbdd`, `crear_<entidad>`, `borrar_registrados` |
| `DBMS_ASSERT` en SQL dinámico | APLICADA (seguridad) | `tabla_segura` |
| Hint `APPEND` / `APPEND_VALUES` (direct-path) | DESCARTADA | ver abajo |

Medición en Oracle local (contenedor, sin concurrencia), con 4 tablas de 1 M filas:
`crear_bbdd` 0,04 s y `eliminar_bbdd` 0,02 s; no dependen del tamaño de las tablas.

## Registro de claves (SINT_REGISTRO) y borrado por PK (D-024)
Localizar lo sintético por `LAST_CHG_USR_ID` (sin índice) obliga a un *full scan* de cada
tabla: en KYTL_GC son ~10 M filas sólo para la Contrapartida Global, y crece con cada entidad.
En su lugar, cada inserción anota su PK en `SINT_REGISTRO`:
- Es una tabla **organizada por índice (IOT)** con PK `(tabla, clave)`: los datos viven en el
  propio índice, sin tabla aparte, y las lecturas por tabla son un *range scan*.
- El borrado lee las claves de una tabla (`BULK COLLECT`) y lanza un `FORALL` de
  `DELETE ... WHERE pk = :clave`: cada fila se localiza por el índice único de la PK.
- La verificación recorre el registro (pequeño) y comprueba cada clave con `EXISTS` sobre la PK.
El coste es proporcional a las filas sintéticas (cientos), no al tamaño de las tablas (millones),
**siempre que las FKs de otras tablas hacia las tablas borradas estén indexadas** (D-026):
si no, Oracle recorre cada tabla hija por cada fila padre borrada (medido: 7,4 s por fila con
una hija de 3 M filas sin índice, 0,01 s con índice). `plsql/diagnostico_borrado.sql` las lista.
El coste es lineal con las filas padre (100 filas → 17 s por cada hija de 3 M filas) aunque se
borren en una sola sentencia: por eso el borrado físico se hace en segundo plano (D-027), en
bloques de 20 claves con COMMIT.

## Índices temporales INVISIBLE ONLINE durante el borrado (D-028)
Oracle usa también los índices **invisibles** para la comprobación de FK al borrar la fila
padre (medido: 20 filas padre, hija de 3 M filas: 3,81 s sin índice → 0,00 s con índice
invisible). El job crea uno por cada FK sin índice relevante, borra y los elimina:
- INVISIBLE: el optimizador no lo usa para las consultas de la aplicación → sus planes no cambian.
- ONLINE: la construcción no bloquea las escrituras de la aplicación en la tabla hija.
- Coste: crear el índice ≈ 1,5 lecturas de la hija, **una vez por borrado**, en lugar de una
  lectura completa por cada fila padre borrada.

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

## Un único paquete, tamaño vigilado (D-023)
El tamaño de un paquete no afecta a la velocidad de sus INSERT, pero sí a la memoria y el
tiempo de compilación. Medido en local: 219.000 líneas (600 entidades como la Contrapartida
Global) compilan en 36 s; el doble agota la memoria de compilación de un contenedor pequeño.
El generador informa del tamaño en cada ejecución y avisa a partir de 150.000 líneas.
Los procedimientos de entidad son independientes entre sí (tipos y constantes locales), de
modo que, si hiciera falta, separarlos en otro paquete sería un cambio sólo del generador.

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

## limpiar_restos (borrado por LAST_CHG_USR_ID)
Se mantiene sólo para restos no registrados (p. ej. datos de versiones anteriores). Recorre
cada tabla completa: es lento y debe usarse de forma ocasional.
