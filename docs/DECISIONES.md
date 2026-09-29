# Registro de decisiones

Sistema de decisiones del proyecto. Cada vez que en una iteración se detecta un
comportamiento que hay que corregir o se acuerda una regla, se registra aquí.

## Cómo usar este documento

- **Decisión (`D-xxx`)**: regla acordada. Estados: `VIGENTE`, `PROPUESTA` (a validar por
  el usuario), `SUSTITUIDA POR D-yyy` (nunca se borra una decisión, se sustituye).
- **Pregunta abierta (`P-xxx`)**: información que falta. Al resolverse, se marca
  `RESUELTA → D-xxx` y se crea/actualiza la decisión correspondiente.
- Si la decisión es una regla general de trabajo, se refleja también en `CLAUDE.md`.

Plantilla:

```
### D-xxx — Título corto
- Fecha: AAAA-MM-DD · Estado: VIGENTE | PROPUESTA | SUSTITUIDA POR D-yyy
- Contexto: qué se observó / por qué hace falta.
- Decisión: qué se hace.
- Consecuencias: impacto en el código / en otras decisiones.
```

---

## Decisiones

### D-001 — Marca de registros sintéticos
- Fecha: 2026-09-29 · Estado: VIGENTE
- Contexto: hay que identificar y poder borrar de golpe todos los datos sintéticos.
- Decisión: toda fila insertada por el generador lleva `LAST_CHG_USR_ID = 'TESTING:RDR'`,
  definida una única vez en `pkg_sint_nucleo.gc_usuario_sintetico`. El valor `LASTCHGUSRID`
  del mensaje se ignora.
- Consecuencias: la purga se basa en esta columna (D-006). Ver P-008.

### D-002 — Mapeo segmento → tabla → columna
- Fecha: 2026-09-29 · Estado: VIGENTE (ampliada por D-010)
- Decisión: `SEGMENT/@TYPE = XSEG.SEGMENT_NME` (vigente); tabla = `FT_T_` || `XSEG.SEGMENT_DESC`;
  columna = `XELM.COL_NME` por `(SEGMENT_ID, ELEMENT_XML_TAG)`, validada contra la estructura
  física (`ALL_TAB_COLUMNS`). Excepciones y reglas de respaldo en D-010.

### D-003 — Rama de trabajo
- Fecha: 2026-09-29 · Estado: VIGENTE
- Decisión: se trabaja siempre sobre `main`.

### D-004 — Estructura del generador: paquete único
- Fecha: 2026-09-29 · Estado: SUSTITUIDA POR D-011

### D-005 — Tratamiento de las acciones de segmento
- Fecha: 2026-09-29 · Estado: VIGENTE (confirmada por el usuario, P-004)
- Contexto: acciones GoldenSource: INSERT, UPDATE, DELETE, UNKNOWN, OPTIMISTICINSERT,
  OPTIMISTICUPDATE, REFERENCE, INSERTIFUPDATE, IGNORE. `OPTIMISTICUPDATE` = actualiza o
  inserta sin lookups previos (optimización de rendimiento del motor).
- Decisión: el generador siempre crea entidades nuevas, por lo que `INSERT`,
  `OPTIMISTICUPDATE`, `OPTIMISTICINSERT` y `UNKNOWN` → INSERT. `REFERENCE` → no inserta
  (sólo sirve al motor para resolver FKs / padre-hijo). `IGNORE` → nada.
  `UPDATE`, `DELETE`, `INSERTIFUPDATE` → consultar al usuario cuando aparezcan.

### D-006 — Purga (reversión) de datos sintéticos
- Fecha: 2026-09-29 · Estado: VIGENTE
- Decisión: `pkg_sint_nucleo.purgar` borra por `LAST_CHG_USR_ID = gc_usuario_sintetico` las
  tablas de `g_tablas_gestionadas`, en **orden inverso de inserción** (hijas primero). Es
  atómica: si falla (p. ej. ORA-02292 porque las pruebas crearon registros hijos con FK
  activa) se deshace entera (`SAVEPOINT`) y lanza `ORA-20003` indicando la tabla.
  Script de uso: `plsql/revertir_bbdd_sintetica.sql`.
- Consecuencias: cada entidad nueva añade sus tablas a la lista. FKs activas que apuntan a
  tablas gestionadas (a vigilar): hacia `FT_T_FINS` desde FIRR, ETPY, FINS_REGULATION_ATTR;
  hacia `FT_T_FINR` desde PFIN, RMPS, RGAT, FLMR, FIRR, ATRN, FPPR, FINS_REGULATION_ATTR.

### D-007 — Fechas
- Fecha: 2026-09-29 · Estado: PROPUESTA
- Decisión: constante `gc_formato_fecha_xml = 'MM-DD-YYYY HH:MI:SS AM'` con
  `NLS_DATE_LANGUAGE=ENGLISH` (función `pkg_sint_nucleo.fecha_xml`). `START_TMS` y
  `LAST_CHG_TMS` = `SYSDATE` del momento de la llamada (el mismo valor para todas las filas
  de una llamada). Fechas de negocio (p. ej. `INST_FOUNDING_DTE`) = valor del mensaje como
  valor por defecto de un parámetro.

### D-008 — Generación de claves internas (OIDs)
- Fecha: 2026-09-29 · Estado: VIGENTE (P-001)
- Decisión: toda clave interna (OIDs, `INST_MNEM`, `STAT_ID`...) se obtiene con la función
  `NEW_OID` de GoldenSource a través de `pkg_sint_nucleo.nuevo_oid` (único punto de llamada).
  Los OIDs que aparecen en el mensaje de ejemplo **no se reutilizan**: sólo indican qué
  segmentos comparten clave.
- Consecuencias: se asume `NEW_OID` sin parámetros y accesible desde `KYTL_GC` (ver P-010).

### D-009 — Datos de referencia
- Fecha: 2026-09-29 · Estado: VIGENTE (P-005)
- Decisión: los datos maestros deben existir en BBDD; el generador no los crea. Se resuelven
  o validan **una vez por llamada**, antes de insertar, con funciones del núcleo:
  `oid_unidad_geografica` (FT_T_GUNT por GU_ID/GU_TYP/GU_CNT), `oid_clasificacion`
  (FT_T_INCL por INDUS_CL_SET_ID/CL_VALUE), `validar_estadistico` (FT_T_STDF),
  `validar_organizacion` (FT_T_ENTR). Si no existen: `ORA-20002` y no se inserta nada.
- Consecuencias: los OIDs de referencia del mensaje (`GUNT3B2===`, `=002DCDB88`) no se
  copian literalmente; se buscan por su clave de negocio, lo que permite variar el país, etc.

### D-010 — Resolución de tablas y columnas no directas
- Fecha: 2026-09-29 · Estado: VIGENTE
- Contexto: el segmento `FINSFinancialLegalNames` (TBL_ID `FLG1`) no tiene filas XELM ni
  existe `FT_T_FLG1`; XELM no contiene `FINROID` ni `GUNTOID`, pero las tablas sí tienen
  `FINR_OID` y `GUNT_OID`.
- Decisión:
  1. Tablas custom sin prefijo `FT_T_` se declaran en `esquema/modelo/tablas_manual.csv`
     (`FLG1 → FINANCIAL_LEGAL_NAMES`). `construir_modelo.py` además **infiere** la tabla cuando
     una única tabla contiene todas las columnas XELM; una tabla inferida debe confirmarse
     en `tablas_manual.csv` antes de usarla.
  2. Segmento sin XELM → hereda el XELM de otro segmento vigente con el mismo `SEGMENT_DESC`
     (`FINSFinancialLegalNames` hereda de `FinancialLegalNames`, SEGMENT_ID 3001690).
  3. Tag sin XELM → columna física con el mismo nombre sin guiones bajos.

### D-011 — Estructura: núcleo + paquetes por unidad funcional
- Fecha: 2026-09-29 · Estado: VIGENTE (sustituye a D-004)
- Contexto: el generador crecerá con muchas entidades; un único paquete sería difícil de
  mantener y cualquier cambio invalidaría todo.
- Decisión: `PKG_SINT_NUCLEO` (constantes, trazas, OIDs, referencias, purga) + un paquete
  por unidad funcional `PKG_SINT_<UNIDAD>` (la unidad = `MAIN_ENTITY_TBL_TYP` del mensaje o
  agrupación acordada). Un procedimiento `generar_<entidad>` por mensaje. Orquestación en
  `plsql/generar_bbdd_sintetica.sql`. Instalación en `KYTL_GC` con derechos del propietario.
- Consecuencias: el rendimiento no depende del tamaño del paquete (se ejecuta SQL en bloque);
  la división es por mantenibilidad y para poder recompilar una unidad sin tocar las demás.

### D-012 — Comparaciones con columnas CHAR
- Fecha: 2026-09-29 · Estado: VIGENTE
- Contexto: muchas claves GoldenSource son `CHAR(n)` (`INDUS_CL_SET_ID CHAR(10)`,
  `STAT_DEF_ID CHAR(8)`, `ORG_ID CHAR(4)`). Comparar una columna CHAR con un VARCHAR2 usa
  semántica sin relleno: `'TPFINF'` no encuentra `'TPFINF    '`.
- Decisión: las variables usadas en `WHERE` sobre columnas CHAR se declaran con `%TYPE` de la
  columna (comparación con relleno de blancos y uso normal de índices). No usar `RTRIM(col)`.

### D-013 — Pruebas en Oracle local desechable
- Fecha: 2026-09-29 · Estado: VIGENTE
- Decisión: antes de cada commit de PL/SQL se ejecuta `herramientas/probar_en_local.sh`:
  contenedor `gvenzl/oracle-free` (23ai), tablas recreadas desde `modelo.json` (PK + FKs
  activas), stub de `NEW_OID` y referencias mínimas. Instala, genera, verifica y revierte.
- Consecuencias: el Oracle local es 23ai; hay que evitar sintaxis posterior a 19c (CLAUDE.md §7).
  La prueba local no sustituye una primera ejecución controlada en `KYTL_GC`.

---

## Preguntas abiertas

| Id | Pregunta | Estado |
|---|---|---|
| P-001 | Generación de OIDs. | RESUELTA → D-008 (función `NEW_OID`) |
| P-002 | Segmento `FINSFinancialLegalNames` sin XELM. | RESUELTA → D-010 (tabla `FINANCIAL_LEGAL_NAMES`, XELM heredado) — **confirmar tabla** |
| P-003 | Estructura física y constraints. | RESUELTA → extracciones en `esquema/old/`, `modelo.json` |
| P-004 | Semántica de `OPTIMISTICUPDATE`. | RESUELTA → D-005 |
| P-005 | Datos de referencia. | RESUELTA → D-009 (deben existir en BBDD) |
| P-006 | Triggers / auditoría / historial. | RESUELTA: no hay |
| P-007 | Esquema y despliegue. | RESUELTA: `KYTL_GC` (D-011). Pendiente: herramienta de ejecución (SQL*Plus, SQL Developer...) |
| P-008 | Registros sintéticos modificados por las pruebas (cambia `LAST_CHG_USR_ID`) o registros de las pruebas que cuelgan de ellos: la purga por usuario no los cubre. | ABIERTA — riesgo aceptado; propuesta: tabla de control con las claves generadas. **Pendiente de definir** |
| P-009 | Volumen esperado. | RESUELTA: cientos de entidades (500 contrapartidas = 5.500 filas en ~0,05 s en local) |
| P-010 | Firma exacta de `NEW_OID`: ¿función sin parámetros que devuelve el OID (CHAR/VARCHAR2(10))? ¿propietario `KYTL_GC` o sinónimo? | ABIERTA |
| P-011 | Contrapartida Global: ¿qué campos deben variar entre entidades además del nombre y el país? ¿Cuántas contrapartidas se quieren en la BBDD sintética (ahora 10)? | ABIERTA |
