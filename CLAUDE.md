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
- Las entidades se definen a partir de **mensajes XML `STREET_REF`** que genera el frontal
  (Workstation), que se dejan en [`mensajes_entrada/`](mensajes_entrada/).
- Cada mensaje se **traduce a INSERTs** usando los metadatos del motor (XSEG: segmento → tabla;
  XELM: elemento XML → columna) y la estructura física real de las tablas (columnas y
  constraints), todo ello condensado en [`esquema/modelo/modelo.json`](esquema/modelo/).
- Cada mensaje genera **una entidad idéntica al mensaje** (sólo cambian las claves internas).
  Las entidades adicionales con variaciones **sólo** se crean cuando se piden expresamente
  por chat, y se añaden al PL/SQL (D-014).
- **Todo registro sintético lleva `LAST_CHG_USR_ID = 'TESTING:RDR'`** para identificarlo
  y poder **borrarlo todo de golpe** (script de reversión).
- Entregable final: scripts PL/SQL que se instalan en `KYTL_GC` y se ejecutan a voluntad
  (`plsql/instalar.sql`, `plsql/generar_bbdd_sintetica.sql`, `plsql/revertir_bbdd_sintetica.sql`).

## 2. Reglas de trabajo

1. **Rama**: se trabaja siempre sobre `main` (D-003).
2. **Antes de cada tarea**: releer este fichero y `docs/DECISIONES.md` (decisiones vigentes
   y preguntas abiertas). Si la tarea contradice una decisión vigente, avisar al usuario
   antes de continuar.
3. **Nunca inventar** estructura de BBDD (columnas, tipos, claves, valores de referencia):
   consultar `modelo.json` con las herramientas. Si falta información, preguntar al usuario
   y registrarlo como pregunta abierta (`P-xxx`).
4. **Registrar decisiones**: todo comportamiento que se corrija o se acuerde durante una
   iteración se añade a `docs/DECISIONES.md` (nueva `D-xxx`) y, si es una regla general,
   se refleja también en este documento.
5. **Documentación**: el PL/SQL debe ser legible por personas: cabecera por objeto,
   comentario por bloque lógico, nombres explícitos en español, sin "números mágicos"
   (usar constantes). Cada INSERT indica el segmento del mensaje del que procede.
6. **Idioma**: documentación, comentarios y nombres propios del generador en español.
   Los nombres de tablas/columnas de GoldenSource se mantienen tal cual.
7. **Probar antes de subir**: todo cambio de PL/SQL se compila y ejecuta con
   `herramientas/probar_en_local.sh` (Oracle local desechable, D-013).
8. **Commits** pequeños y descriptivos, uno por tarea lógica (p. ej. "Añade entidad
   Contrapartida Global").

## 3. Flujo de trabajo por iteración (nueva entidad)

1. El usuario añade un XML en `mensajes_entrada/` (convenciones en
   [`mensajes_entrada/README.md`](mensajes_entrada/README.md)) y, opcionalmente, pide
   generar N entidades variando ciertos campos.
2. Generar el informe de mapeo:
   ```bash
   python3 herramientas/analizar_mensaje.py mensajes_entrada/<Mensaje>.xml -o docs/mapeos/<Mensaje>.md
   ```
3. Revisar el informe: **Avisos** (segmentos sin tabla, tablas inferidas, elementos sin
   columna, acciones desconocidas), **NOT NULL no informadas** (OIDs a generar) y
   **FKs** (referencias a validar). Cada aviso no resuelto → pregunta al usuario.
4. Clasificar cada campo del mensaje:
   - **Fijo**: se copia del mensaje como constante del paquete (catálogos, tipos, `DATA_SRC_ID`...).
   - **Parametrizable**: datos de negocio que previsiblemente se querrán variar (nombres,
     país, organizaciones...) → parámetro cuyo **valor por defecto es el del mensaje** (D-014).
     Nunca se generan variaciones que no se hayan pedido.
   - **Clave**: OID / mnemónico interno → `pkg_sint_nucleo.nuevo_oid` (D-008).
   - **Técnico**: lo fija el generador (`LAST_CHG_USR_ID`, `LAST_CHG_TMS`, `START_TMS`).
   - **Referencia**: dato maestro existente (`GUNT_OID`, `CLSF_OID`, `STAT_DEF_ID`, `ORG_ID`...)
     → se resuelve/valida una vez por llamada con las funciones del núcleo (D-009).
5. Implementar `generar_<entidad>` en el paquete de su **unidad funcional**
   (`plsql/unidades/pkg_sint_<unidad>`; si la unidad no existe, crearla — D-011).
   Seguir la plantilla de `pkg_sint_fins.generar_contrapartida_global`.
6. Añadir las tablas nuevas a `g_tablas_gestionadas` en `pkg_sint_nucleo.pkb`
   **en orden de inserción** (la purga las recorre al revés).
7. Añadir la llamada **sin parámetros** en la sección 1 de `plsql/generar_bbdd_sintetica.sql`
   (las variaciones pedidas por chat van a la sección 2, documentadas), el script de verificación en
   `plsql/pruebas/`, las tablas en `herramientas/probar_en_local.sh` y, si hacen falta,
   datos de referencia en `plsql/pruebas/local/referencias_minimas.sql`.
8. Ejecutar `herramientas/probar_en_local.sh`. Actualizar el catálogo (sección 6) y
   `docs/DECISIONES.md`. Commit + push a `main`.

## 4. Traducción mensaje XML → INSERT

- `SEGMENT/@TYPE` = `XSEG.SEGMENT_NME`. Tabla física: `FT_T_` || `XSEG.SEGMENT_DESC`, salvo
  tablas custom declaradas en `esquema/modelo/tablas_manual.csv` (D-010).
- Elemento `<TAG VALUE="..."/>` → columna vía XELM. Si el segmento no tiene filas XELM se
  hereda el XELM de otro segmento con el mismo `SEGMENT_DESC`; si el tag no está en XELM se
  empareja con la columna física de igual nombre sin guiones bajos (`FINROID` → `FINR_OID`) (D-010).
- Elementos XELM sin columna física (p. ej. `INSTNME`, `FINSID` en tablas hijas) son
  lógicos del motor: **no se insertan**.
- `SEGMENT/@ACTION` (D-005): `INSERT`, `OPTIMISTICUPDATE`, `OPTIMISTICINSERT`, `UNKNOWN`
  → INSERT (la entidad siempre es nueva); `REFERENCE` → no inserta (sólo resuelve claves);
  `IGNORE` → se ignora; `UPDATE`/`DELETE`/`INSERTIFUPDATE` → consultar al usuario.
- Fechas del mensaje: formato `MM-DD-YYYY HH:MI:SS AM` (D-007).
- `LASTCHGUSRID` del mensaje **se ignora** y se sustituye por `'TESTING:RDR'` (D-001).
- Se respeta lo que envía el frontal aunque parezca incoherente (D-015); ante la duda, preguntar.

## 5. Estructura del repositorio

```
CLAUDE.md                          <- este documento (objetivo + instrucciones)
docs/DECISIONES.md                 <- decisiones (D-xxx) y preguntas abiertas (P-xxx)
docs/OPTIMIZACION_ORACLE.md        <- técnicas de optimización aplicadas y su justificación
docs/mapeos/                       <- informes de mapeo generados por mensaje
esquema/old/                       <- extracciones originales (XSEG, XELM, ALL_TAB_COLUMNS, ALL_CONSTRAINTS, ALL_CONS_COLUMNS)
esquema/modelo/modelo.json         <- modelo compacto generado (segmentos + tablas); NO editar
esquema/modelo/tablas_manual.csv   <- TBL_ID -> tabla física confirmada a mano
mensajes_entrada/                  <- mensajes XML de entrada (uno por entidad)
herramientas/construir_modelo.py   <- old/*.csv -> modelo.json (re-ejecutar si cambian las extracciones)
herramientas/analizar_mensaje.py   <- informe de mapeo de un mensaje / segmento / tabla
herramientas/generar_ddl_pruebas.py<- DDL de tablas para el Oracle local de pruebas
herramientas/probar_en_local.sh    <- prueba de extremo a extremo en Oracle local (docker)
plsql/instalar.sql                 <- instala núcleo + unidades en KYTL_GC
plsql/generar_bbdd_sintetica.sql   <- construye la BBDD sintética completa
plsql/revertir_bbdd_sintetica.sql  <- borra todos los registros sintéticos
plsql/nucleo/                      <- PKG_SINT_NUCLEO: constantes, OIDs, referencias, purga
plsql/unidades/                    <- PKG_SINT_<UNIDAD>: generadores por unidad funcional
plsql/pruebas/                     <- verificaciones; pruebas/local/ sólo para Oracle local
```

Consultas rápidas:
```bash
python3 herramientas/analizar_mensaje.py --segmento FinancialInstitution   # XELM + tabla
python3 herramientas/analizar_mensaje.py --tabla FT_T_FINS                 # columnas, PK, FKs
```

## 6. Catálogo de entidades implementadas

| Entidad | Mensaje | Procedimiento | Tablas (orden de inserción) | Filas/entidad | Estado |
|---|---|---|---|---|---|
| Contrapartida Global | `Ejemplo_Alta_Contrapartida_Global.xml` | `pkg_sint_fins.generar_contrapartida_global` | FT_T_FINS, FT_T_FIST (x2), FT_T_FIGU, FINANCIAL_LEGAL_NAMES, FT_T_FINR, FT_T_FIRL, FT_T_ENFR (x2), FT_T_FRCL | 11 | Implementada y probada en local; pendiente de ejecutar en KYTL_GC |

Variaciones solicitadas por chat: ninguna.

## 7. Convenciones PL/SQL

- **Núcleo + unidades funcionales** (D-011): `PKG_SINT_NUCLEO` (común) y un paquete
  `PKG_SINT_<UNIDAD>` por unidad funcional (`FINS`, ...). Las unidades sólo dependen del núcleo.
- Se instalan en `KYTL_GC` con derechos del propietario (sin `AUTHID CURRENT_USER`).
- Scripts compatibles con **SQL Developer** (ejecución como script, F5) y SQL*Plus (D-016).
- Prefijos: `gc_` constantes de paquete, `g_` variables de paquete, `ge_` códigos de error,
  `p_` parámetros, `l_` variables locales, `c_` constantes locales, `t_` tipos.
- `pkg_sint_nucleo.gc_usuario_sintetico` es el **único** sitio con `'TESTING:RDR'` en los
  paquetes (los scripts SQL de verificación pueden usar el literal).
- Patrón de generador: validar parámetros → resolver referencias (una vez) → generar claves
  en una colección → `SAVEPOINT` → un `FORALL` por tabla/segmento → `COMMIT` sólo si `p_commit`.
  Ante error: `ROLLBACK TO SAVEPOINT` y relanzar.
- Variables para comparar con columnas `CHAR` declaradas con `%TYPE` (D-012).
- SQL dinámico sólo en la purga/resumen genéricos, con `DBMS_ASSERT` y variables de enlace.
- Trazas con `pkg_sint_nucleo.traza` (activable con `set_trazas`).
- Código compatible con Oracle 19c (no usar sintaxis 21c+/23ai aunque el Oracle local la acepte:
  p. ej. `BOOLEAN` en SQL, `IF EXISTS`, `SQL_MACRO` escalar, `FROM` opcional sin `DUAL`).
