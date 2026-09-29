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
- Cada mensaje genera **una entidad idéntica al mensaje** (sólo cambian las claves internas).
  Las variaciones **sólo** se crean cuando se piden por chat (D-014) y se declaran en
  [`mensajes_entrada/catalogo.json`](mensajes_entrada/catalogo.json).
- **Todo registro sintético lleva `LAST_CHG_USR_ID = 'TESTING:RDR'`** (D-001).
- **Una sentencia crea toda la BBDD sintética y otra la elimina** (D-021):
  `EXEC pkg_sint.crear_bbdd;` / `EXEC pkg_sint.eliminar_bbdd;` (o los scripts
  `plsql/crear_bbdd_sintetica.sql` / `plsql/eliminar_bbdd_sintetica.sql`, F5 en SQL Developer).

## 2. Reglas de trabajo

1. **Rama**: se trabaja siempre sobre `main` (D-003).
2. **Antes de cada tarea**: releer este fichero y `docs/DECISIONES.md` (decisiones vigentes
   y preguntas abiertas). Si la tarea contradice una decisión vigente, avisar al usuario
   antes de continuar.
3. **Nunca inventar** estructura de BBDD (columnas, tipos, claves, valores de referencia):
   consultar `modelo.json` con las herramientas. Si falta información, preguntar al usuario
   y registrarlo como pregunta abierta (`P-xxx`).
4. **Nunca editar a mano** `plsql/generado/`, `plsql/instalar.sql` ni `plsql/desinstalar.sql`:
   se cambia el generador, el mensaje o el catálogo y se regenera.
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
   ≤ 23 caracteres, y descripción). Sin parámetros salvo petición expresa.
3. Generar: `python3 herramientas/generar_plsql.py`. Si falla, el mensaje de error indica la
   información que falta (columna NOT NULL sin valor, PK no OID, fecha no reconocida...) →
   preguntar al usuario; no inventar valores.
4. Revisar el paquete generado (`plsql/generado/entidades/<unidad>/sint_e_<entidad>.pkb`) y
   añadir a `plsql/pruebas/local/referencias_minimas.sql` los datos maestros que valida.
5. `herramientas/probar_en_local.sh`, actualizar el catálogo de la sección 6, decisiones,
   commit + push a `main`.

### Variación pedida por chat ("genera N como X cambiando Y")
1. Declarar el parámetro en la entidad del catálogo (`parametros`: nombre `P_...` y campos
   `Segmento/TAG` a los que se aplica).
2. Añadir la variación en `variaciones` (fecha, petición literal, entidad, cantidad, valores).
3. Regenerar, probar en local, actualizar la sección 6 y commit.

## 4. Traducción mensaje XML → INSERT (implementada en el generador)

- `SEGMENT/@TYPE` = `XSEG.SEGMENT_NME`. Tabla: `FT_T_` || `XSEG.SEGMENT_DESC`, salvo tablas
  custom declaradas en `esquema/modelo/tablas_manual.csv` (D-010).
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
herramientas/generar_plsql.py      <- mensajes + catálogo -> plsql/generado + instalar/desinstalar
herramientas/generar_ddl_pruebas.py<- DDL de tablas para el Oracle local de pruebas
herramientas/probar_en_local.sh    <- prueba de extremo a extremo en Oracle local (docker)
plsql/crear_bbdd_sintetica.sql     <- F5: instala el código + crea toda la BBDD sintética
plsql/eliminar_bbdd_sintetica.sql  <- F5: borra toda la BBDD sintética
plsql/instalar.sql                 <- (generado) compila núcleo + entidades + fachada
plsql/desinstalar.sql              <- (generado) borra datos y paquetes
plsql/nucleo/                      <- PKG_SINT_NUCLEO (a mano): OIDs, trazas, purga, referencias
plsql/generado/pkg_sint.*          <- (generado) fachada: crear_bbdd, eliminar_bbdd, resumen, verificar
plsql/generado/entidades/<unidad>/ <- (generado) SINT_E_<ENTIDAD>: un paquete por mensaje
plsql/generado/manifiesto.json     <- (generado) tablas, orden de purga, conteos esperados
plsql/pruebas/local/               <- datos maestros mínimos para el Oracle local
```

## 6. Catálogo de entidades implementadas

| Entidad | Mensaje | Paquete | Unidad | Filas/entidad | Tablas | Estado |
|---|---|---|---|---|---|---|
| CONTRAPARTIDA_GLOBAL | `Ejemplo_Alta_Contrapartida_Global.xml` | `SINT_E_CONTRAPARTIDA_GLOBAL` | FINS | 10 | FT_T_FINS, FT_T_FIST (x2), FT_T_FIGU, FINANCIAL_LEGAL_NAMES, FT_T_FINR, FT_T_FIRL, FT_T_ENFR (x2), FT_T_FRCL | Probada en local; pendiente de ejecutar en KYTL_GC |

Variaciones solicitadas por chat: ninguna.

## 7. Arquitectura y convenciones PL/SQL

- **Tres capas** (D-017):
  1. `PKG_SINT_NUCLEO` (a mano, estable): constantes, `nuevo_oid`, trazas, `exigir_referencia`,
     `contar`, `resumen`, `purgar`.
  2. `SINT_E_<ENTIDAD>` (generado, uno por mensaje): `generar(p_cantidad [, parámetros])`.
  3. `PKG_SINT` (generado): `crear_bbdd`, `eliminar_bbdd`, `resumen`, `verificar`; contiene la
     lista de llamadas, las tablas gestionadas, el orden de purga (calculado por FKs) y los
     conteos esperados.
- Instalación en `KYTL_GC` con derechos del propietario. Scripts compatibles con SQL Developer
  (F5) y SQL*Plus (D-016); los `@@` con subcarpetas sólo en scripts de `plsql/` (D-020).
- Patrón de `generar`: validar cantidad → validar referencias → claves nuevas en colección →
  `SAVEPOINT` → un `FORALL` por segmento → sin COMMIT. Ante error: `ROLLBACK TO SAVEPOINT`.
- `crear_bbdd`: una transacción; borra lo sintético previo, crea, **verifica conteos** y COMMIT.
- Prefijos: `gc_` constantes, `g_` variables de paquete, `ge_` códigos de error, `p_` parámetros,
  `l_` variables locales, `c_` constantes locales, `t_` tipos, `k_` claves generadas.
- `'TESTING:RDR'` sólo en `pkg_sint_nucleo.gc_usuario_sintetico`.
- Código compatible con Oracle 19c (el Oracle local es 23ai: no usar `BOOLEAN` en SQL,
  `IF EXISTS`, `SQL_MACRO` escalar, `SELECT` sin `FROM`, etc.).
