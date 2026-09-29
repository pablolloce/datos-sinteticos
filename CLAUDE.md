# CLAUDE.md — Objetivo e instrucciones del repositorio

> **Lectura obligatoria antes de cada tarea.** Este documento (junto con
> [`docs/DECISIONES.md`](docs/DECISIONES.md)) define qué se construye aquí y cómo.
> Claude Code lo carga automáticamente al inicio de cada sesión; aun así, antes de
> empezar cualquier tarea hay que releerlo y revisar las decisiones vigentes y las
> preguntas abiertas.

---

## 1. Objetivo

Construir, de forma incremental, un **generador de datos sintéticos en PL/SQL para
Oracle 19c** sobre la BBDD relacional de GoldenSource (tablas `FT_T_XXXX`).

- Los datos sintéticos son la base de las **pruebas funcionales automáticas** de la aplicación.
- Las entidades se definen a partir de **mensajes XML `STREET_REF`** que genera el frontal
  (Workstation), que se dejan en [`mensajes_entrada/`](mensajes_entrada/).
- Cada mensaje se **traduce a INSERTs** usando los metadatos del motor:
  - [`esquema/XSEG.csv`](esquema/XSEG.csv) (`FT_T_XSEG`): segmento del mensaje → tabla.
  - [`esquema/XELM.csv`](esquema/XELM.csv) (`FT_T_XELM`): elemento XML → columna de la tabla.
- A partir de un mensaje se podrán generar **N entidades** variando campos concretos.
- **Todo registro sintético lleva `LAST_CHG_USR_ID = 'TESTING:RDR'`** para identificarlo
  y poder **borrarlo todo de golpe** (procedimiento de purga).

## 2. Reglas de trabajo

1. **Rama**: se trabaja siempre sobre `main` (ver D-003).
2. **Antes de cada tarea**: releer este fichero y `docs/DECISIONES.md` (decisiones vigentes
   y preguntas abiertas). Si la tarea contradice una decisión vigente, avisar al usuario
   antes de continuar.
3. **Nunca inventar** estructura de BBDD (columnas, tipos, claves, valores de referencia).
   Si falta información, preguntar al usuario y registrarlo como pregunta abierta (`P-xxx`).
4. **Registrar decisiones**: todo comportamiento que se corrija o se acuerde durante una
   iteración se añade a `docs/DECISIONES.md` (nueva `D-xxx`) y, si es una regla general,
   se refleja también en este documento.
5. **Documentación**: el PL/SQL debe ser legible por personas: cabecera por objeto,
   comentario por bloque lógico, nombres explícitos en español, sin "números mágicos"
   (usar constantes del paquete).
6. **Idioma**: documentación, comentarios y nombres propios del generador en español.
   Los nombres de tablas/columnas de GoldenSource se mantienen tal cual.
7. **Commits** pequeños y descriptivos, uno por tarea lógica (p. ej. "Añade entidad
   Contrapartida Global").

## 3. Flujo de trabajo por iteración (nueva entidad)

1. El usuario añade un XML en `mensajes_entrada/` (ver convenciones en
   [`mensajes_entrada/README.md`](mensajes_entrada/README.md)) y, opcionalmente, pide
   generar N entidades variando ciertos campos.
2. Generar el informe de mapeo:
   ```bash
   python3 herramientas/analizar_mensaje.py mensajes_entrada/<Mensaje>.xml \
          -o docs/mapeos/<Mensaje>.md
   ```
3. Revisar la sección **Avisos** del informe (segmentos sin XELM, elementos sin columna,
   OIDs a generar, acciones desconocidas). Cada aviso no resuelto → pregunta al usuario.
4. Clasificar cada campo del mensaje:
   - **Fijo**: se copia del mensaje (catálogos, tipos, `DATA_SRC_ID`...).
   - **Variable**: debe ser único o cambiar por entidad (mnemónicos, OIDs, nombres...).
   - **Técnico**: lo fija el generador (`LAST_CHG_USR_ID`, `LAST_CHG_TMS`, `START_TMS`...).
   - **Referencia**: apunta a datos maestros existentes (p. ej. `CLSF_OID`, `GU_ID`);
     no se generan, se validan.
5. Implementar en `plsql/paquete/` un procedimiento público `generar_<entidad>` con
   parámetro de cantidad y parámetros para los campos variables.
6. Añadir las tablas nuevas a la lista de purga **en el orden correcto** (hijas antes que
   padres) y actualizar el catálogo de entidades (sección 6).
7. Añadir/actualizar el script de prueba en `plsql/pruebas/`.
8. Registrar decisiones nuevas en `docs/DECISIONES.md`. Commit + push a `main`.

## 4. Traducción mensaje XML → INSERT

- `SEGMENT/@TYPE` = `XSEG.SEGMENT_NME`; tabla = `FT_T_` || `XSEG.SEGMENT_DESC`
  (sólo filas vigentes: `END_TMS` vacío).
- Cada elemento hijo `<TAG VALUE="..."/>` se mapea con `XELM (SEGMENT_ID, ELEMENT_XML_TAG) → COL_NME`.
- `SEGMENT/@ACTION` (ver D-005):
  - `INSERT` → insert en la tabla.
  - `REFERENCE` → no inserta; referencia a una entidad del mismo mensaje.
  - `OPTIMISTICUPDATE` → pendiente de confirmar (P-004).
- Fechas del mensaje: formato `MM-DD-YYYY HH:MI:SS AM` (ver D-007).
- `LASTCHGUSRID` del mensaje **se ignora** y se sustituye por `'TESTING:RDR'` (D-001).
- XELM puede contener elementos "lógicos" que el motor usa para resolver claves
  (p. ej. `INSTNME`, `FINSID` en tablas hijas) y que quizá no existen físicamente:
  **validar siempre contra la estructura física** de la tabla (P-003).

## 5. Estructura del repositorio

```
CLAUDE.md                      <- este documento (objetivo + instrucciones)
docs/DECISIONES.md             <- registro de decisiones (D-xxx) y preguntas abiertas (P-xxx)
docs/OPTIMIZACION_ORACLE.md    <- técnicas de optimización aplicadas y su justificación
docs/mapeos/                   <- informes de mapeo generados por mensaje
esquema/                       <- extracciones XSEG / XELM (y futuras: columnas, constraints)
mensajes_entrada/              <- mensajes XML de entrada (uno por entidad)
herramientas/                  <- utilidades de apoyo (análisis de mensajes)
plsql/instalar.sql             <- script maestro de instalación
plsql/paquete/                 <- especificación (.pks) y cuerpo (.pkb) del paquete generador
plsql/pruebas/                 <- scripts de ejecución, verificación y purga
```

## 6. Catálogo de entidades implementadas

| Entidad | Mensaje | Procedimiento | Tablas (orden de inserción) | Estado |
|---|---|---|---|---|
| Contrapartida Global | `Ejemplo_Alta_Contrapartida_Global.xml` | `generar_contrapartida_global` (previsto) | FINS, FIST, FIGU, FLG1, FINR, FIRL, ENFR, FRCL | Análisis hecho; bloqueado por P-001..P-005 |

## 7. Convenciones PL/SQL

- Un único paquete `PKG_DATOS_SINTETICOS` (spec `.pks` + body `.pkb`).
- Prefijos: `gc_` constantes globales, `g_` variables globales de paquete, `p_` parámetros,
  `l_` variables locales, `t_` tipos, `c_` cursores.
- Constante `gc_usuario_sintetico := 'TESTING:RDR'`: **nunca** escribir el literal fuera de ella.
- Sin `COMMIT` dentro de los procedimientos de generación salvo parámetro explícito
  (`p_commit`): quien llama controla la transacción.
- Operaciones en bloque (`INSERT ... SELECT`, `FORALL`) en lugar de fila a fila; explicar
  cada técnica en `docs/OPTIMIZACION_ORACLE.md`.
- Variables de enlace siempre; SQL dinámico sólo donde sea imprescindible (purga genérica)
  y con `DBMS_ASSERT` para los nombres de objeto.
- Trazas con `DBMS_OUTPUT` a través del procedimiento interno `traza` (activable).
- Código compatible con Oracle 19c (no usar sintaxis 21c+ como `SQL_MACRO` escalar, JSON types, etc.).
