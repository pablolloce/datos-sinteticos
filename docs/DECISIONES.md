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
  definida una única vez en la constante `gc_usuario_sintetico`. El valor `LASTCHGUSRID`
  del mensaje se ignora.
- Consecuencias: la purga se basa en esta columna (D-006). Ver P-008 sobre filas que las
  pruebas funcionales modifiquen después.

### D-002 — Mapeo segmento → tabla → columna
- Fecha: 2026-09-29 · Estado: VIGENTE
- Contexto: el mensaje STREET_REF define segmentos; los metadatos XSEG/XELM los traducen.
- Decisión: `SEGMENT/@TYPE = XSEG.SEGMENT_NME` (vigente, `END_TMS` nulo); tabla =
  `FT_T_` || `XSEG.SEGMENT_DESC`; columna = `XELM.COL_NME` por `(SEGMENT_ID, ELEMENT_XML_TAG)`.
- Consecuencias: el informe `herramientas/analizar_mensaje.py` aplica esta regla.

### D-003 — Rama de trabajo
- Fecha: 2026-09-29 · Estado: VIGENTE
- Decisión: se trabaja siempre sobre `main`.

### D-004 — Estructura del generador
- Fecha: 2026-09-29 · Estado: VIGENTE
- Decisión: un único paquete `PKG_DATOS_SINTETICOS`; un procedimiento público
  `generar_<entidad>` por mensaje de entrada, con parámetro de cantidad y parámetros para
  los campos variables; un procedimiento `purgar` común.
- Consecuencias: el paquete crece por entidades; cada entidad documenta en su cabecera el
  mensaje de origen.

### D-005 — Tratamiento de las acciones de segmento
- Fecha: 2026-09-29 · Estado: PROPUESTA
- Decisión: `INSERT` → insert; `REFERENCE` (con `NotNewEntity="Y"`) → no se inserta, sólo
  indica que los segmentos siguientes cuelgan de esa entidad; `OPTIMISTICUPDATE` → se trata
  como insert cuando la entidad es nueva (pendiente de P-004).

### D-006 — Purga de datos sintéticos
- Fecha: 2026-09-29 · Estado: VIGENTE
- Decisión: `purgar` borra por `LAST_CHG_USR_ID = gc_usuario_sintetico` recorriendo una
  lista de tablas mantenida en el paquete, **en orden inverso de dependencias** (hijas
  antes que padres) para no violar claves ajenas. Informa de las filas borradas por tabla.
- Consecuencias: cada entidad nueva debe añadir sus tablas a la lista en el orden correcto.

### D-007 — Formato de fechas del mensaje y fechas técnicas
- Fecha: 2026-09-29 · Estado: PROPUESTA
- Contexto: el frontal serializa fechas como `MM-DD-YYYY HH:MI:SS AM` (NLS inglés).
- Decisión: constante `gc_formato_fecha_xml = 'MM-DD-YYYY HH:MI:SS AM'` con
  `NLS_DATE_LANGUAGE=ENGLISH` explícito en `TO_DATE`. `LAST_CHG_TMS` y `START_TMS` = momento
  de generación (`SYSDATE`), no las fechas del mensaje; resto de fechas de negocio
  (p. ej. `INST_FOUNDING_DTE`) se toman del mensaje salvo que se pidan como variables.

---

## Preguntas abiertas

| Id | Pregunta | Estado |
|---|---|---|
| P-001 | **Generación de OIDs** (`FINR_OID`, `FIRL_OID`, `ENFR_OID`, `INST_MNEM`...). El motor los genera (formato 10 caracteres, p. ej. `f-uBI7(qW1`). ¿Existe una función/secuencia en BBDD para obtenerlos o podemos generar los nuestros con un patrón propio que no colisione? | ABIERTA |
| P-002 | Segmento `FINSFinancialLegalNames` (SEGMENT_ID 99991901, tabla `FT_T_FLG1`) **no tiene filas en XELM**. Necesitamos su mapeo elemento → columna. | ABIERTA |
| P-003 | **Estructura física** de las tablas (`ALL_TAB_COLUMNS`: tipo, longitud, nulabilidad) y **constraints** (`ALL_CONSTRAINTS`/`ALL_CONS_COLUMNS`: PK, FK, UK). XELM incluye elementos lógicos (`INSTNME`, `FINSID`...) que quizá no son columnas reales; y el elemento `FINROID` no aparece en XELM. | ABIERTA |
| P-004 | Semántica de `OPTIMISTICUPDATE` para una entidad nueva: ¿equivale a INSERT? | ABIERTA |
| P-005 | **Datos de referencia**: `CLSF_OID` (`=002DCDB88`), `GUNTOID` (`GUNT3B2===`), `ORG_ID` (`0182`, `A18`), `STAT_DEF_ID`... ¿existen igual en la BBDD destino? ¿se validan o se asumen? | ABIERTA |
| P-006 | ¿Hay **triggers**, auditoría o tablas de historial sobre las `FT_T_*` que se disparen con los INSERT (y que también haya que purgar)? | ABIERTA |
| P-007 | Permisos y despliegue: esquema propietario, ¿podemos crear el paquete (y una tabla de control/log) en ese esquema? Cliente de ejecución (SQL*Plus, SQL Developer, pipeline...). | ABIERTA |
| P-008 | Si las pruebas funcionales **modifican** registros sintéticos (cambia `LAST_CHG_USR_ID`) o **crean** registros que cuelgan de ellos, la purga por usuario no los encontraría. ¿Se contempla? Alternativa: tabla de control con las claves generadas. | ABIERTA |
| P-009 | Volumen esperado (decenas, miles, millones de entidades) para dimensionar las técnicas de carga. | ABIERTA |
