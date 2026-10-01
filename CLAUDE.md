# CLAUDE.md — Objetivo e instrucciones del repositorio

> **Lectura obligatoria antes de cada tarea.** Este documento (junto con
> [`docs/DECISIONES.md`](docs/DECISIONES.md)) define qué se construye aquí y cómo.
> Claude Code lo carga automáticamente al inicio de cada sesión; aun así, antes de
> empezar cualquier tarea hay que releerlo y revisar las decisiones vigentes y las
> preguntas abiertas.

---

## 1. Objetivo

Construir, de forma incremental, un **generador de datos sintéticos en PL/SQL para
Oracle 19c** sobre la BBDD relacional de GoldenSource (esquema **`KYTL_GC`**, tablas
`FT_T_XXXX` y tablas custom).

- Los datos sintéticos son la base de las **pruebas funcionales automáticas** de la aplicación.
- Las entidades se definen con **mensajes XML `STREET_REF`** del frontal, que se dejan en
  [`mensajes_entrada/`](mensajes_entrada/). Habrá muchos tipos de entidad: unos con decenas
  y otros con cientos de elementos, y algunos con decenas de INSERT por individuo.
- El PL/SQL de cada entidad **se genera automáticamente** a partir de su mensaje
  (`herramientas/generar_plsql.py`, D-017) usando XSEG/XELM y la estructura física real de
  las tablas, condensados en [`esquema/modelo/modelo.json`](esquema/modelo/).
- En la BBDD hay **un único paquete, `PKG_SINT`** (D-023), sea cual sea el nº de entidades.
- Cada mensaje genera **la entidad que crearía GoldenSource al guardar ese mensaje desde la
  Workstation** (D-031): se aplican las reglas del motor replicadas y cambian las claves internas.
  Las variaciones **sólo** se crean cuando se piden por chat (D-014) y se declaran en
  [`mensajes_entrada/catalogo.json`](mensajes_entrada/catalogo.json).
- **Todo registro sintético lleva `LAST_CHG_USR_ID = 'TESTING:RDR'`** (D-001).
- **Instalación y ejecución separadas** (D-025):
  - Instalar/actualizar (desinstala lo anterior e instala lo nuevo): `plsql/instalar.sql` (F5).
  - Crear (SÓLO inserts, rápido): `EXEC pkg_sint.crear_bbdd;`
  - Eliminar (SÓLO borra lo insertado): `EXEC pkg_sint.eliminar_bbdd;` responde al instante;
    un job de Oracle hace el borrado físico en segundo plano (D-027). Progreso:
    `EXEC pkg_sint.estado_borrado;`
- Las filas creadas se anotan en la tabla **`SINT_REGISTRO`** y se borran por clave primaria,
  hijas antes que padres (D-024). Para que el borrado de filas padre no recorra por cada fila
  las tablas hijas con FK sin índice (D-026), el job crea índices temporales `SINT_TMP_*`
  (INVISIBLE, ONLINE), borra y los elimina, dejando el esquema como estaba (D-028).

## 2. Reglas de trabajo

1. **Rama**: se trabaja siempre sobre `main` (D-003).
2. **Antes de cada tarea**: releer este fichero y `docs/DECISIONES.md` (decisiones vigentes
   y preguntas abiertas). Si la tarea contradice una decisión vigente, avisar al usuario
   antes de continuar.
3. **Nunca inventar** estructura de BBDD (columnas, tipos, claves, valores de referencia):
   consultar `modelo.json` con las herramientas. Si falta información, preguntar al usuario
   y registrarlo como pregunta abierta (`P-xxx`).
4. **Nunca editar a mano** `plsql/generado/`: se cambia el generador, el mensaje, el catálogo
   o el núcleo (`plsql/fuente/`) y se regenera.
5. **Registrar decisiones**: todo comportamiento que se corrija o se acuerde durante una
   iteración se añade a `docs/DECISIONES.md` (nueva `D-xxx`) y, si es una regla general,
   se refleja también en este documento. Si la corrección es de traducción, se implementa
   **en el generador** (así se aplica a todas las entidades).
6. **Documentación**: el PL/SQL (escrito o generado) debe ser legible por personas: cabecera
   por objeto, comentario por bloque, y en el generado cada valor indica de qué elemento del
   mensaje procede.
7. **Idioma**: documentación, comentarios y nombres propios del generador en español.
   Los nombres de tablas/columnas de GoldenSource se mantienen tal cual.
8. **Probar antes de subir**: `herramientas/probar_en_local.sh` (Oracle local desechable, D-013).
9. **Commits** pequeños y descriptivos, uno por tarea lógica. Los ficheros generados se suben
   al repositorio (el usuario instala desde SQL Developer sin Python).

## 3. Flujo de trabajo

### Nueva entidad (el usuario deja un XML en `mensajes_entrada/`)
1. Informe de mapeo y revisión de avisos:
   ```bash
   python3 herramientas/analizar_mensaje.py mensajes_entrada/<Mensaje>.xml -o docs/mapeos/<Mensaje>.md
   ```
   Avisos (segmentos sin tabla, tablas inferidas, elementos sin columna, acciones
   desconocidas) → preguntar al usuario.
2. Añadir la entrada en `mensajes_entrada/catalogo.json` (nombre corto de la entidad,
   ≤ 24 caracteres → procedimiento `crear_<nombre>`, y descripción). Sin parámetros salvo
   petición expresa.
3. Generar: `python3 herramientas/generar_plsql.py`. Si falla, el mensaje de error indica la
   información que falta (columna NOT NULL sin valor, PK no OID, fecha no reconocida...) →
   preguntar al usuario; no inventar valores.
4. Revisar el procedimiento generado (`crear_<entidad>` en `plsql/generado/pkg_sint.pkb`,
   sección de su unidad), vigilar el aviso de tamaño del generador (D-023) y añadir a
   `plsql/pruebas/local/referencias_minimas.sql` los datos maestros que valida.
5. `herramientas/probar_en_local.sh`, actualizar el catálogo de la sección 6, decisiones,
   commit + push a `main`.

### Variación pedida por chat ("genera N como X cambiando Y")
1. Declarar el parámetro en la entidad del catálogo (`parametros`: nombre `P_...` y campos
   `Segmento/TAG` a los que se aplica).
2. Añadir la variación en `variaciones` (fecha, petición literal, entidad, cantidad, valores).
3. Regenerar, probar en local, actualizar la sección 6 y commit.

## 4. Traducción mensaje XML → INSERT (implementada en el generador)

- `SEGMENT/@TYPE` = `XSEG.SEGMENT_NME`. Tabla: `FT_T_` || `XSEG.SEGMENT_DESC`, salvo tablas
  custom declaradas en `esquema/modelo/tablas_manual.csv` o resueltas por sinónimo
  (`esquema/old/SINONIMOS_ADICIONALES.csv`) (D-010).
- Elemento `<TAG VALUE="..."/>` → columna vía XELM (heredado del segmento con el mismo
  `SEGMENT_DESC` si no tiene); si el tag no está en XELM, columna física de igual nombre sin
  guiones bajos (D-010). Elementos sin columna física: no se insertan (quedan comentados).
- `SEGMENT/@ACTION` (D-005): `INSERT`, `OPTIMISTICUPDATE`, `OPTIMISTICINSERT`, `UNKNOWN` →
  INSERT; `REFERENCE`, `IGNORE` → nada; `UPDATE`/`DELETE`/`INSERTIFUPDATE` → consultar.
- **Claves internas (D-018)**: PK de una columna `CHAR/VARCHAR2(10)` = OID. Si el mensaje la
  trae, ese valor se sustituye por una clave nueva (`NEW_OID`) en **todo** el mensaje (así
  se propagan las relaciones padre-hijo); si no la trae, se genera una clave nueva.
- **Referencias (D-019)**: valores literales en columnas con FK (datos maestros) se copian del
  mensaje y se **validan** antes de insertar; si falta alguno, ORA-20002 y no se crea nada.
- Técnicos: `LAST_CHG_USR_ID` = `'TESTING:RDR'`; `START_TMS`, `LAST_CHG_TMS` = `SYSDATE` de la
  llamada (D-007). Fechas de negocio del mensaje (`MM-DD-YYYY HH:MI:SS AM`) → `TO_DATE` literal.
- Se respeta lo que envía el frontal aunque parezca incoherente (D-015).

## 4 bis. Réplica del motor de GoldenSource (D-029 a D-033)

Guardar desde una ventana de la Workstation genera el mensaje (`WEBMSG`) y dispara
`CustomWorkstationWorkflow`, que lo procesa con el motor (`Basic Message Processing`, TPS-UI):
message set `STREETREF` + reglas Java de `rdrRules.jar`. El generador replica ese procesamiento
antes de traducir el mensaje a INSERT. Documentación en [`docs/motor/`](docs/motor/README.md).

- Configuración del motor: `esquema/motor/*.json`, generada con
  `python3 herramientas/motor/sincronizar_fileloading.py` desde el repositorio `fileloading`
  (`FILELOADING_REPO` o `../fileloading`). No copiar aquí material de GoldenSource (D-029).
- Réplicas: `herramientas/motor/reglas_replicadas.py` (`REPLICAS`), sobre la vista del mensaje por
  columnas de `herramientas/motor/mensaje_motor.py`. Una regla Java se replica desde su código
  (citar `Clase.process`); una nativa `CFTI*`/`CGSC*` sólo si una huella confirma su efecto y está
  en `docs/motor/REGLAS_OBSERVADAS.md` (D-030). Réplicas idempotentes (D-033).
- Tras tocar una réplica: `python3 herramientas/motor/probar_reglas.py` (añadir un caso por regla).
- Validaciones que rechazan el mensaje (D-035): `herramientas/motor/validaciones_motor.py`. Si
  `generar_plsql.py` falla con "GoldenSource rechazaría estos mensajes", **no se sube nada**: se
  devuelve el mensaje de error al usuario por el chat, tal cual, y **se le pide un valor nuevo para
  el campo duplicado** que indica el error; nunca se inventa ni se añade un sufijo. Si el error llega
  al ejecutar en la BBDD (-20006, el valor ya existe en KYTL_GC), se hace lo mismo.
- Se replican también las tablas de control, difusión y cachés de los workflows posteriores al
  motor (D-036); no los envíos ESB/MQ/JMS, ficheros ni correos.
- Fase 2 (D-037): `herramientas/motor/flujo_workstation.py` añade al mensaje un segmento por cada
  fila que escriben los workflows posteriores al motor, portando su código decodificado
  (`fileloading/extracciones/decodificado/`). Lo no replicado queda como PENDIENTE en la cabecera
  del procedimiento y se comenta con el usuario.
- Estructura de tablas custom accedidas por sinónimo: `esquema/extraer_tablas_adicionales.sql`
  → `esquema/old/*_ADICIONALES.csv` → `construir_modelo.py` (P-021).
- Por cada mensaje nuevo, además del informe de mapeo:
  `python3 herramientas/motor/reglas_aplicables.py mensajes_entrada/<Mensaje>.xml -o docs/motor/reglas/<Mensaje>.md`;
  revisar las reglas pendientes que le afectan y comentarlas con el usuario.
- Huellas: el usuario da el alta en la Workstation, espera 2-3 minutos y ejecuta
  `plsql/motor/capturar_huella.sql` (captura todo lo confirmado en los últimos 10 minutos por
  `ORA_ROWSCN`, D-040); deja el CSV en `huellas/` y se analiza con
  `herramientas/motor/comparar_huella.py` (D-032). Tablas sin relación aparente: se revisan con él.

## 5. Estructura del repositorio

```
CLAUDE.md                          <- este documento (objetivo + instrucciones)
docs/DECISIONES.md                 <- decisiones (D-xxx) y preguntas abiertas (P-xxx)
docs/OPTIMIZACION_ORACLE.md        <- técnicas de optimización aplicadas y su justificación
docs/mapeos/                       <- informes de mapeo por mensaje (analizar_mensaje.py)
esquema/old/                       <- extracciones originales (XSEG, XELM, ALL_TAB_COLUMNS, ALL_CONSTRAINTS, ALL_CONS_COLUMNS)
esquema/modelo/modelo.json         <- modelo compacto generado (segmentos + tablas); NO editar
esquema/modelo/tablas_manual.csv   <- TBL_ID -> tabla física confirmada a mano
mensajes_entrada/*.xml             <- mensajes (admite subcarpetas, p. ej. por unidad)
mensajes_entrada/catalogo.json     <- nombre de cada entidad, parámetros y variaciones
herramientas/construir_modelo.py   <- esquema/old/*.csv -> modelo.json
herramientas/analizar_mensaje.py   <- informe de mapeo de un mensaje / segmento / tabla
herramientas/generar_plsql.py      <- mensajes + catálogo + núcleo -> plsql/generado/pkg_sint.*
herramientas/generar_ddl_pruebas.py<- DDL de tablas para el Oracle local de pruebas
herramientas/probar_en_local.sh    <- prueba de extremo a extremo en Oracle local (docker)
herramientas/motor/                <- réplica del motor: sincronización, reglas, huellas (D-029..D-033)
esquema/motor/                     <- configuración del motor sincronizada desde fileloading (NO editar)
docs/motor/                        <- funcionamiento del motor, reglas observadas e informes
plsql/motor/capturar_huella.sql    <- captura lo que hizo GoldenSource con un mensaje (D-030)
plsql/motor/diagnostico_finsid.sql <- sólo lectura: FINSID / GET_IDENTIFIER_ID y filas por INST_MNEM (P-022)
huellas/                           <- capturas exportadas a CSV (entrada de comparar_huella.py)
plsql/instalar.sql                 <- F5: desinstala versiones anteriores + SINT_REGISTRO + compila PKG_SINT
plsql/crear_bbdd_sintetica.sql     <- F5: EXEC pkg_sint.crear_bbdd (sólo inserts)
plsql/eliminar_bbdd_sintetica.sql  <- F5: EXEC pkg_sint.eliminar_bbdd (sólo borrado por clave)
plsql/desinstalar.sql              <- borra datos, PKG_SINT y SINT_REGISTRO
plsql/diagnostico_borrado.sql      <- (generado) FKs activas hacia tablas gestionadas sin índice (D-026)
plsql/fuente/nucleo_*.sql          <- núcleo escrito a mano (fragmentos que se insertan en PKG_SINT)
plsql/generado/pkg_sint.pks/.pkb   <- (generado) EL paquete: núcleo + entidades por unidad + API
plsql/generado/manifiesto.json     <- (generado) tablas, orden de purga, conteos, tamaño
plsql/pruebas/local/               <- datos maestros mínimos para el Oracle local
```

## 6. Catálogo de entidades implementadas

| Entidad | Mensaje | Procedimiento | Unidad | Filas/entidad | Tablas | Estado |
|---|---|---|---|---|---|---|
| CONTRAPARTIDA_GLOBAL | `Ejemplo_Alta_Contrapartida_Global.xml` | `pkg_sint.crear_contrapartida_global` | FINS | 11 | FT_T_FINS, FT_T_FIST (x2), FT_T_FIGU, FINANCIAL_LEGAL_NAMES, FT_T_FINR, FT_T_FIRL, FT_T_ENFR (x2), FT_T_FRCL, REGISTER_LOG_TABLE (fase 2, CONTROLDR) | Probada en local (2026-09-30), incluida la réplica del motor D-031..D-037 y `capturar_huella.sql`; pendiente de ejecutar en KYTL_GC y de huella (reglas nativas) |

Variaciones solicitadas por chat: ninguna.

## 7. Arquitectura y convenciones PL/SQL

- **Un único paquete `PKG_SINT`** (D-023), generado, con tres secciones:
  1. NÚCLEO (escrito a mano en `plsql/fuente/`, el generador lo inserta): constantes,
     `nuevo_oid`, `traza`, `exigir_referencia`, registro de claves (`hay_registro`,
     `borrar_registrados`, `resumen_registro`, `verificar_registro`) y `purgar_por_usuario`.
  2. ENTIDADES: un procedimiento público `crear_<entidad>(p_cantidad [, parámetros])` por
     mensaje, agrupados por unidad funcional (`MAIN_ENTITY_TBL_TYP`).
  3. API: `crear_bbdd`, `eliminar_bbdd`, `resumen`, `verificar`, `limpiar_restos` (listas de tablas, orden de
     purga calculado por FKs y conteos esperados, declarados en la marca `<<DATOS_GENERADOS>>`
     del núcleo porque en PL/SQL las declaraciones van antes que los procedimientos).
- Instalación en `KYTL_GC` con derechos del propietario. Scripts compatibles con SQL Developer
  (F5) y SQL*Plus (D-016); los `@@` con subcarpetas sólo en scripts de `plsql/` (D-020).
- Patrón de `crear_<entidad>`: validar cantidad → validar referencias → claves nuevas en colección →
  `SAVEPOINT` → por segmento, un `FORALL` INSERT + un `FORALL` a `SINT_REGISTRO` → sin COMMIT.
  Ante error: `ROLLBACK TO SAVEPOINT`. Toda tabla gestionada debe tener PK de una columna (D-024).
- `crear_bbdd`: sólo inserta (falla con ORA-20005 si hay claves ACTIVAS registradas), verifica
  por clave y COMMIT. `eliminar_bbdd`: marca las claves como BORRANDO (inmediato) y lanza un job
  `SINT_ELIM_*` (uno a la vez) que crea índices temporales `SINT_TMP_*` sobre las FKs sin
  índice hacia tablas con ≥ 2 filas pendientes (hijas de ≥ 10.000 filas), borra por clave,
  hijas→padres, con COMMIT cada 20 claves, y quita los índices (D-027, D-028).
  `SINT_REGISTRO.estado`: ACTIVO / BORRANDO / BLOQUEADO. Se borra todo lo que se puede (D-038):
  una fila de la que cuelgan registros no sintéticos queda BLOQUEADA (no se tocan datos ajenos),
  `estado_borrado` dice qué FK lo impide y el siguiente `eliminar_bbdd` la reintenta.
  El borrado es **por entidad** (D-039): en todas las tablas del modelo con `INST_MNEM` (la PK de
  la tabla principal de la unidad) se borran las filas de las contrapartidas sintéticas, las haya
  insertado o no el generador (una sentencia por tabla).
- `limpiar_restos`: borrado LENTO por `LAST_CHG_USR_ID`, sólo para restos no registrados.
- Prefijos: `gc_` constantes, `g_` variables de paquete, `ge_` códigos de error, `p_` parámetros,
  `l_` variables locales, `c_` constantes locales, `t_` tipos, `k_` claves generadas.
- `'TESTING:RDR'` sólo en `gc_usuario_sintetico` (plsql/fuente/nucleo_especificacion.sql).
- Código compatible con Oracle 19c (el Oracle local es 23ai: no usar `BOOLEAN` en SQL,
  `IF EXISTS`, `SQL_MACRO` escalar, `SELECT` sin `FROM`, etc.).
