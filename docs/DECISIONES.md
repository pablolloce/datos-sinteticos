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
  tablas gestionadas, **hijas antes que padres** (orden calculado por el generador a partir
  de las FKs, D-021). Es
  atómica: si falla (p. ej. ORA-02292 porque las pruebas crearon registros hijos con FK
  activa) se deshace entera (`SAVEPOINT`) y lanza `ORA-20003` indicando la tabla.
  Uso: `EXEC pkg_sint.eliminar_bbdd;` o `plsql/eliminar_bbdd_sintetica.sql`.
- Consecuencias: la lista de tablas la genera `generar_plsql.py`. FKs activas que apuntan a
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
- Consecuencias: `NEW_OID` es una función sin parámetros accesible desde `KYTL_GC` (confirmado, P-010).

### D-009 — Datos de referencia
- Fecha: 2026-09-29 · Estado: SUSTITUIDA POR D-019 (P-005)
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
  4. (2026-09-30) Si `FT_T_<TBL_ID>` es un sinónimo de una tabla de KYTL_GC
     (`esquema/old/SINONIMOS_ADICIONALES.csv`), esa tabla queda confirmada (origen "sinonimo"),
     p. ej. `RLT1 → REGISTER_LOG_TABLE`, `FLG1 → FINANCIAL_LEGAL_NAMES`. Los `*_ADICIONALES.csv` de
     columnas y restricciones no se cargan como tablas (son las mismas, con el nombre del sinónimo).

### D-011 — Estructura: núcleo + paquetes por unidad funcional
- Fecha: 2026-09-29 · Estado: SUSTITUIDA POR D-017 (sustituía a D-004)
- Contexto: el generador crecerá con muchas entidades; un único paquete sería difícil de
  mantener y cualquier cambio invalidaría todo.
- Decisión: `PKG_SINT_NUCLEO` (constantes, trazas, OIDs, referencias, purga) + un paquete
  por unidad funcional `PKG_SINT_<UNIDAD>` (la unidad = `MAIN_ENTITY_TBL_TYP` del mensaje o
  agrupación acordada). Un procedimiento `generar_<entidad>` por mensaje. Orquestación en
  un script de orquestación. Instalación en `KYTL_GC` con derechos del propietario.
- Consecuencias: el rendimiento no depende del tamaño del paquete (se ejecuta SQL en bloque);
  la división es por mantenibilidad y para poder recompilar una unidad sin tocar las demás.

### D-012 — Comparaciones con columnas CHAR
- Fecha: 2026-09-29 · Estado: VIGENTE
- Contexto: muchas claves GoldenSource son `CHAR(n)` (`INDUS_CL_SET_ID CHAR(10)`,
  `STAT_DEF_ID CHAR(8)`, `ORG_ID CHAR(4)`). Comparar una columna CHAR con un VARCHAR2 usa
  semántica sin relleno: `'TPFINF'` no encuentra `'TPFINF    '`.
- Decisión: las variables y parámetros usados sobre columnas CHAR se declaran con `%TYPE` de la
  columna (comparación con relleno de blancos y uso normal de índices). No usar `RTRIM(col)`.
  Los literales `'...'` de Oracle ya son de tipo CHAR, así que las validaciones generadas
  con literales también comparan correctamente.

### D-013 — Pruebas en Oracle local desechable
- Fecha: 2026-09-29 · Estado: VIGENTE
- Decisión: antes de cada commit de PL/SQL se ejecuta `herramientas/probar_en_local.sh`:
  contenedor `gvenzl/oracle-free` (23ai), tablas recreadas desde `modelo.json` (PK + FKs
  activas), stub de `NEW_OID` y referencias mínimas. Instala, genera, verifica y revierte.
- Consecuencias: el Oracle local es 23ai; hay que evitar sintaxis posterior a 19c (CLAUDE.md §7).
  La prueba local no sustituye una primera ejecución controlada en `KYTL_GC`.

### D-014 — Fidelidad al mensaje; variaciones sólo bajo petición
- Fecha: 2026-09-29 · Estado: VIGENTE, MATIZADA POR D-031 ("idéntica" = como la dejaría GoldenSource)
- Contexto: la BBDD sintética se construye principalmente a partir de mensajes XML.
- Decisión: cada paquete de entidad, llamado **sin parámetros**, crea **una** entidad con
  exactamente los valores del mensaje; sólo las claves internas son nuevas (`NEW_OID`, D-018).
  No se generan variaciones ni numeraciones automáticas. Las variaciones que el usuario pida
  por chat se declaran en `mensajes_entrada/catalogo.json` (parámetros de la entidad, con el
  valor del mensaje como defecto, y la lista `variaciones`) y el generador las añade a
  `pkg_sint.crear_bbdd`.

### D-015 — Valores "raros" del frontal se respetan
- Fecha: 2026-09-29 · Estado: VIGENTE salvo lo que cambien las reglas del motor (D-031)
- Decisión: se inserta lo que envía el frontal aunque parezca incoherente. Casos confirmados:
  `FT_T_FINR.PREF_ID_CTXT_TYP = 'Y'` es normal; en `FT_T_ENFR` el frontal no informa
  `INST_MNEM` (sólo `FINR_INST_MNEM`) y se deja nulo (otros procesos lo rellenan con
  `FINR_INST_MNEM`, pero no se imita si el mensaje no lo trae).

### D-016 — Herramienta de ejecución: SQL Developer
- Fecha: 2026-09-29 · Estado: VIGENTE (P-007)
- Decisión: los scripts de `plsql/` se ejecutan en SQL Developer, conectado como `KYTL_GC`,
  abriendo el fichero y ejecutándolo como script (**F5**, no "Ejecutar sentencia"). Sólo se
  usan comandos de script compatibles con SQL Developer y SQL*Plus/SQLcl: `SET SERVEROUTPUT`,
  `PROMPT`, `@@` (rutas relativas al script abierto), `SHOW ERRORS`, `WHENEVER SQLERROR`.
  La salida de `DBMS_OUTPUT` aparece en la pestaña "Salida de script".

### D-017 — PL/SQL generado a partir de los mensajes (sustituye a D-011)
- Fecha: 2026-09-29 · Estado: VIGENTE (la parte "un paquete por entidad" la sustituye D-023)
- Contexto: habrá muchos tipos de entidad, algunos con cientos de elementos y decenas de
  INSERT por individuo. Escribir a mano cada INSERT no escala y es propenso a errores.
- Decisión: `herramientas/generar_plsql.py` traduce cada mensaje (reglas de CLAUDE.md §4) a un
  paquete `SINT_E_<ENTIDAD>` con SQL **estático** (un `FORALL` por segmento, un comentario por
  valor indicando su origen), y genera la fachada `PKG_SINT`, `instalar.sql` y
  `desinstalar.sql`. A mano sólo se mantiene `PKG_SINT_NUCLEO`. La configuración por entidad
  (nombre, parámetros) y las variaciones viven en `mensajes_entrada/catalogo.json`.
- Consecuencias: SQL estático ⇒ Oracle valida en la compilación que tablas y columnas existen.
  Un paquete por entidad ⇒ tamaño acotado y recompilación independiente. Las correcciones de
  traducción se hacen una vez en el generador. Lo generado se sube al repositorio.

### D-018 — Claves internas del mensaje
- Fecha: 2026-09-29 · Estado: VIGENTE
- Decisión: la PK de un segmento, si es de una sola columna `CHAR/VARCHAR2(10)`, es un OID.
  Si el mensaje trae su valor, **ese valor se sustituye por una clave nueva en todo el
  mensaje** (propaga padre→hijo: p. ej. `INSTMNEM`, `FINROID`, `PRNTINSTMNEM`,
  `FINRINSTMNEM`); si no lo trae, se genera una clave nueva para esa fila. PK de negocio (no
  OID) → valor literal del mensaje, con aviso. PK compuesta → valores del mensaje (con
  sustitución si coinciden con un OID nuevo); si falta alguna columna, error de generación.
- Consecuencias: cada individuo creado tiene claves propias y las relaciones internas del
  mensaje se mantienen.

### D-019 — Datos de referencia: literal del mensaje + validación (sustituye a D-009)
- Fecha: 2026-09-29 · Estado: VIGENTE
- Decisión: los valores que apuntan a datos maestros (columnas con FK, activa o no, que no son
  claves nuevas) se insertan **tal cual vienen en el mensaje** (p. ej. `GUNT_OID =
  GUNT3B2===`, `CLSF_OID = =002DCDB88`, `STAT_DEF_ID`, `ORG_ID`). Antes de insertar, cada
  paquete comprueba que existen (`SELECT COUNT(*)` por la PK/UK referenciada); si falta
  alguno: ORA-20002 indicando tabla y valor, y `crear_bbdd` se deshace entera.
- Consecuencias: el mensaje debe proceder de un entorno con los mismos datos maestros que
  `KYTL_GC`. Si en una variación se cambia un campo con dato maestro asociado (p. ej. el país
  y su `GUNT_OID`), hay que parametrizar ambos.

### D-020 — Rutas de los scripts SQL
- Fecha: 2026-09-29 · Estado: VIGENTE (con un único paquete, instalar.sql ya no se genera)
- Contexto: SQL*Plus resuelve `@@carpeta/fichero` de un script anidado respecto al directorio
  actual, y SQL Developer respecto al script que lo llama.
- Decisión: sólo los scripts de `plsql/` usan `@@` con subcarpetas (`instalar.sql` lista todos
  los paquetes); los scripts anidados se llaman sin subcarpeta (`@@instalar.sql`). En SQL*Plus
  hay que situarse en `plsql/`; en SQL Developer, abrir el script desde `plsql/`.

### D-021 — Una sentencia para crear y otra para eliminar; verificación automática
- Fecha: 2026-09-29 · Estado: SUSTITUIDA POR D-025 (crear ya no borra antes ni recorre tablas)
- Decisión: `EXEC pkg_sint.crear_bbdd;` borra lo sintético previo, crea todas las entidades y
  variaciones, **verifica** que cada tabla tiene exactamente las filas esperadas (calculadas
  por el generador) y hace COMMIT; todo en una transacción (repetible sin duplicar).
  `EXEC pkg_sint.eliminar_bbdd;` borra todo lo sintético. Scripts equivalentes para F5:
  `plsql/crear_bbdd_sintetica.sql` (además instala/actualiza el código) y
  `plsql/eliminar_bbdd_sintetica.sql`.

### D-022 — Corrección: filas por Contrapartida Global
- Fecha: 2026-09-29 · Estado: VIGENTE
- Contexto: se documentó por error que la Contrapartida Global insertaba 11 filas.
- Decisión: son **10** (FINS 1, FIST 2, FIGU 1, FINANCIAL_LEGAL_NAMES 1, FINR 1, FIRL 1,
  ENFR 2, FRCL 1). Los conteos los calcula ahora el generador y se verifican al crear.

### D-023 — Un único paquete PKG_SINT
- Fecha: 2026-09-29 · Estado: VIGENTE (indicación del usuario; sustituye "un paquete por
  entidad" de D-017)
- Contexto: un paquete por entidad llenaría el esquema de objetos. PL/SQL no admite
  paquetes anidados.
- Decisión: todo en `PKG_SINT` (generado): sección NÚCLEO (fragmentos escritos a mano en
  `plsql/fuente/`), sección ENTIDADES (un procedimiento `crear_<entidad>` por mensaje,
  agrupados por unidad) y sección API. `instalar.sql` borra automáticamente los paquetes de
  versiones anteriores (`PKG_SINT_NUCLEO`, `PKG_SINT_FINS`, `PKG_SINT_ENTIDADES`,
  `PKG_DATOS_SINTETICOS`, `SINT_E_*`).
- Límite medido (Oracle local, contenedor con poca memoria): 600 entidades del tamaño de la
  Contrapartida Global (6.000 FORALL, 219.000 líneas, 12 MB) compilan en 36 s; 1.200 fallan
  por memoria de compilación (ORA-04036, depende del servidor). El generador avisa a partir
  de 150.000 líneas; si se alcanzara, opciones: separar el núcleo en un 2º paquete o compactar
  el código generado.
- Consecuencias: un cambio en cualquier entidad recompila el paquete entero (segundos hoy).

### D-024 — Registro de claves SINT_REGISTRO: crear y eliminar sin recorrer tablas
- Fecha: 2026-09-30 · Estado: VIGENTE
- Contexto: crear y eliminar tardaban mucho en KYTL_GC: localizar lo sintético por
  `LAST_CHG_USR_ID` (sin índice) obliga a recorrer tablas de 0,2–2,4 M filas (~10 M en total
  con sólo la Contrapartida Global), y `crear_bbdd` lo hacía 3 veces (purga, verificación,
  resumen).
- Decisión: tabla `SINT_REGISTRO` (IOT, PK `(tabla, clave)`; columnas `columna_pk`, `entidad`,
  `creado_tms`), creada por `instalar.sql` si no existe y conservada entre instalaciones.
  Cada `FORALL` de inserción va seguido de un `FORALL` que anota la PK de las filas creadas.
  `eliminar_bbdd` borra por PK (FORALL de DELETE por índice) en orden hijas→padres y después
  las tablas que queden en el registro; `verificar` y `resumen` también van por el registro.
  Toda tabla gestionada debe tener PK de una sola columna (si no, error de generación).
- Medición local (4 tablas con 1 M filas): crear 0,04 s, eliminar 0,02 s; el borrado por
  `LAST_CHG_USR_ID` (ahora `limpiar_restos`) recorre las tablas y escala con su tamaño.
- Consecuencias: un objeto más en el esquema (la tabla). Resuelve la primera parte de P-008:
  si las pruebas cambian el `LAST_CHG_USR_ID` de una fila sintética, se sigue borrando por su
  clave. Si hay registros NO sintéticos colgando con FK activa, el borrado se deshace (ORA-20003).
  Coste residual: al borrar filas de `FT_T_FINS`/`FT_T_FINR`, Oracle comprueba las FKs activas
  de sus tablas hijas; si esas columnas no tienen índice, cada fila borrada recorre la hija.

### D-025 — Instalación separada de la ejecución
- Fecha: 2026-09-30 · Estado: VIGENTE (indicación del usuario; sustituye a D-021)
- Decisión:
  - `plsql/instalar.sql`: único comando de instalación/actualización. Desinstala los paquetes
    de versiones anteriores, crea `SINT_REGISTRO` si no existe y compila `PKG_SINT`.
  - `EXEC pkg_sint.crear_bbdd;` (o `crear_bbdd_sintetica.sql`): SÓLO inserts + verificación
    por clave + COMMIT. Si ya hay BBDD registrada, ORA-20005 (no duplica, no borra).
  - `EXEC pkg_sint.eliminar_bbdd;` (o `eliminar_bbdd_sintetica.sql`): SÓLO borra lo registrado.
  - `EXEC pkg_sint.limpiar_restos;`: ocasional y lento, para restos no registrados (p. ej.
    datos creados por versiones anteriores del generador).

### D-026 — Borrado lento por FKs sin índice en tablas hijas
- Fecha: 2026-09-30 · Estado: VIGENTE (pendiente de acción del DBA, P-012)
- Contexto: `eliminar_bbdd` sigue siendo muy lento en KYTL_GC aunque borra por PK. Medido en
  local: borrar 1 fila padre cuya tabla hija (3 M filas) tiene una FK activa SIN índice tarda
  7,4 s; con índice, 0,01 s. Oracle comprueba la hija por CADA fila padre borrada (5 filas en
  una sentencia ≈ 5 recorridos) y además la bloquea mientras dura. `FT_T_FINS` y `FT_T_FINR`
  tienen 14 FKs activas desde otras tablas (FINS_REGULATION_ATTR con 2,1 M filas, ETPY, FIRR,
  ATRN, PFIN, RMPS, RGAT, FLMR, FPPR).
- Decisión: no se puede resolver desde el generador (no se deben desactivar constraints de
  GoldenSource). Se genera `plsql/diagnostico_borrado.sql`, que lista las FKs activas hacia las
  tablas gestionadas, si están indexadas, las filas de la hija y el `CREATE INDEX` propuesto.
  La solución es que el DBA cree esos índices (práctica recomendada de Oracle: toda FK con
  borrados en el padre debe estar indexada; también evita bloqueos de la tabla hija).
- Consecuencias: el coste de `eliminar_bbdd` es ≈ nº de filas padre sintéticas × nº de FKs
  sin índice × tamaño de las hijas, hasta que existan los índices.

### D-027 — Borrado físico en segundo plano (DBMS_SCHEDULER)
- Fecha: 2026-09-30 · Estado: VIGENTE (indicación del usuario; descartados: índices nuevos,
  borrado lógico con END_TMS y desactivar FKs)
- Contexto: el diagnóstico en KYTL_GC muestra ~90 FKs activas sin índice hacia `FT_T_FINS` y
  ~80 hacia `FT_T_FINR` (p. ej. `FT_T_ISID` 15 M filas, `FT_T_SWCH` 2,6 M ×3, `FT_T_SUFR` 2,6 M,
  `FT_T_FIID` 1,5 M, `FT_T_ENFR` 1,1 M...): ~38 M filas leídas por cada Contrapartida Global
  borrada. El orden hijas→padres ya se aplica, pero no evita la comprobación: Oracle debe
  demostrar que la hija no referencia a la fila padre y, sin índice, la recorre entera. Medido
  en local (hija de 3 M filas): 1 fila padre 0,18 s, 10 → 1,7 s, 50 → 8,4 s, 100 → 17,1 s
  (lineal; agrupar en una sentencia no ayuda). Sólo la validación de una FK recorre la hija
  una vez para todas las claves, y exige desactivar/reactivar la FK (descartado).
- Decisión: `eliminar_bbdd` marca las claves registradas como `BORRANDO` (instantáneo; permite
  volver a crear enseguida) y lanza un job `SINT_ELIM_<fecha>` (DBMS_SCHEDULER, requiere
  `CREATE JOB`) que borra por PK, hijas→padres, en bloques de 20 claves con COMMIT (progreso
  visible y reanudable: relanzar `eliminar_bbdd` recoge lo pendiente). `estado_borrado`
  informa de pendientes, jobs en curso y últimas ejecuciones con su error.
  `eliminar_bbdd(p_segundo_plano => FALSE)` hace el borrado en la sesión (lo usa desinstalar).
- Consecuencias: el comando es inmediato, pero el borrado físico total sigue siendo lineal con
  el nº de filas padre sintéticas (con cientos de entidades, horas) y, mientras se comprueba
  cada fila padre, Oracle bloquea brevemente la tabla hija frente a escrituras de la aplicación.

### D-028 — Índices auxiliares temporales durante el borrado
- Fecha: 2026-09-30 · Estado: VIGENTE (confirmado por el usuario: `UNLIMITED TABLESPACE` y
  `CREATE INDEX ... INVISIBLE ONLINE` funcionan en KYTL_GC)
- Contexto: medido en KYTL_GC, borrar una Contrapartida Global tarda 58,5 s (FT_T_FINS 48 s,
  FT_T_FINR 10 s) y el coste es lineal: 100 contrapartidas ≈ 1 h 40 min (D-027). En local, un
  índice INVISIBLE sobre la FK de la hija lo usa Oracle en la comprobación de FK: borrar 20
  filas padre con hija de 3 M filas pasa de 3,81 s a 0,00 s; crear el índice cuesta 5,65 s
  (~1,5 lecturas de la hija), una sola vez por borrado.
- Decisión: el job de borrado, antes de borrar, crea un índice `SINT_TMP_<hash>` INVISIBLE
  ONLINE (sin ONLINE si la edición no lo permite) por cada FK activa sin índice que apunte a
  una tabla con ≥ 2 filas pendientes (`gc_min_filas_padre`) y cuya hija tenga ≥ 10.000 filas
  (`gc_min_filas_hija`; las pequeñas se recorren al instante). Después borra y elimina todos
  los `SINT_TMP_*`, también ante error. `instalar.sql` y `desinstalar.sql` limpian los que
  hubieran quedado. Un solo job a la vez (los índices son compartidos).
- Medido en KYTL_GC (2026-09-30): 5 contrapartidas (50 filas) borradas en 1 min 27 s, frente a
  ~4 min 50 s sin índices temporales (5 × 58,5 s); el tiempo es casi todo creación de índices
  (p. ej. FT_T_ENFR 1,1 M filas 4,5 s; FT_T_SSIR 1 M filas 3,4 s; FT_T_ADTP 0,8 M filas 3,1 s).
- Consecuencias: el borrado cuesta ≈ crear los índices una vez (independiente del nº de
  entidades) en lugar de una lectura completa de cada hija por fila padre. Con 1 sola fila
  padre no se crean (sería más lento). Mientras existen, los índices ocupan espacio (el de
  FT_T_ISID, ~350–400 MB) y ralentizan levemente las escrituras en esas hijas; al ser
  invisibles no cambian los planes de las consultas de la aplicación.

### D-029 — Conocimiento del motor de GoldenSource sincronizado desde `fileloading`
- Fecha: 2026-09-30 · Estado: VIGENTE (confirmada por el usuario: el entorno de trabajo es este
  repositorio y `fileloading` es la fuente)
- Contexto: el EAR, `rdrRules.jar`, el message set y las extracciones de configuración están en
  `pablolloce/fileloading` (rama `main`).
- Decisión: ese material **no se copia**. `herramientas/motor/sincronizar_fileloading.py` es el
  único que lee `fileloading` (`FILELOADING_REPO` o `../fileloading`) y escribe en
  `esquema/motor/` los derivados que usan el generador y las herramientas (message set, metadatos
  de reglas Java, reglas nativas, notificaciones, commit de origen). Se re-sincroniza y se sube
  cada vez que cambia `fileloading`.
- Consecuencias: el generador no necesita `fileloading` para funcionar; `esquema/motor/origen.json`
  dice de qué commit salen los datos.

### D-030 — Comportamiento de reglas nativas: sólo lo observado
- Fecha: 2026-09-30 · Estado: VIGENTE
- Contexto: las reglas `CFTI*`/`CGSC*` son C++ compilado y no tenemos su código.
- Decisión: una regla nativa sólo se replica cuando su efecto está **confirmado** por una
  captura de huella (`plsql/motor/capturar_huella.sql` + `herramientas/motor/comparar_huella.py`)
  y anotado en `docs/motor/REGLAS_OBSERVADAS.md`. La inferencia por nombre
  (`fileloading/analisis/reglas_nativas.csv`) sólo sirve para priorizar.


### D-031 — El generador replica el motor de GoldenSource (mensajes de la Workstation)
- Fecha: 2026-09-30 · Estado: VIGENTE (P-013, indicación del usuario; modifica D-014 y D-015)
- Contexto: los mensajes de `mensajes_entrada/` los genera la Workstation al guardar desde una
  ventana (`WEBMSG`). El guardado dispara `CustomWorkstationWorkflow` (v22), que envía el mensaje
  al motor (`Basic Message Processing`, motor TPS-UI) y después lanza procesos de negocio.
  El motor aplica el message set STREETREF y las reglas Java de `rdrRules.jar` antes de escribir.
- Decisión: la BBDD sintética debe quedar **como la dejaría GoldenSource** al procesar el mensaje,
  no como el mensaje literal. Reglas:
  1. Antes de traducir, `generar_plsql.py` aplica al mensaje las reglas replicadas
     (`herramientas/motor/reglas_replicadas.py`) en el orden del message set: `Initial`, por
     segmento fases B y A, fase F y `Final` (D-033).
  2. Réplicas deterministas (sólo dependen del mensaje): en Python, sobre el mensaje.
     Réplicas que consultan o escriben la BBDD: funciones del núcleo PL/SQL (pendiente).
  3. Cada procedimiento generado documenta en su cabecera las reglas aplicadas, las replicadas
     sin efecto y las pendientes; cada segmento, los cambios que le hizo el motor. El manifiesto
     las lista por entidad.
  4. Una regla Java se replica a partir de su código; una nativa sólo tras confirmarla con una
     huella (D-030).
  5. La marca sintética `LAST_CHG_USR_ID = 'TESTING:RDR'` (D-001) prevalece sobre los usuarios que
     fijan las reglas (p. ej. `DIFUSION` de `setDifusion`).
- Consecuencias: D-014 pasa a significar "entidad idéntica a la que crearía GoldenSource con ese
  mensaje"; D-015 se mantiene para lo que el motor no cambia. Replicadas hoy: `ValidateCountryRegion`,
  `setDifusion` (altas), `generateLagrLaan`, `FLG_Uniqueness` (parte MEX→MX); sin efecto:
  `GenerateSSISId`, `InactiveFundMIFID`. Pruebas: `herramientas/motor/probar_reglas.py`.

### D-032 — Validación: sintaxis en Oracle local, comportamiento en el entorno del usuario
- Fecha: 2026-09-30 · Estado: VIGENTE (P-014)
- Decisión: la sintaxis del PL/SQL y de los scripts (incluido `plsql/motor/capturar_huella.sql`)
  se valida con la BBDD simulada de `herramientas/probar_en_local.sh`. El usuario ejecuta las
  capturas de huella en un entorno con GoldenSource y sube el CSV a `huellas/`.
- Resultado (2026-09-30, entorno del usuario): `probar_en_local.sh` completo en verde (instalar sobre
  versión anterior, crear, crear negado ORA-20005, eliminar en segundo plano, crear mientras borra,
  borrado síncrono, índices temporales con hija de 300.000 filas, limpiar_restos, desinstalar: 0
  índices `SINT_TMP_*`, 0 filas sintéticas, 0 objetos); `extraer_tablas_adicionales.sql`,
  `diagnostico_borrado.sql` y `capturar_huella.sql` se ejecutan sin errores. La prueba local crea
  ahora también las 6 tablas del motor que usa `capturar_huella.sql` (FT_T_TRID, NTEL, MSGP, MSGF,
  MSGS, JBLG) y la ejecuta.
- Revisión 2026-09-30: `capturar_huella.sql` hace `SET DEFINE ON` (tras `instalar.sql`, que deja
  `SET DEFINE OFF`, en la misma hoja de SQL Developer fallaba con ORA-01841); `crear_bbdd` ya no
  envuelve ORA-20005 en ORA-01086 (sólo vuelve al SAVEPOINT si llegó a marcarlo).

### D-033 — Orden de ejecución de las reglas del message set
- Fecha: 2026-09-30 · Estado: PROPUESTA (deducido, pendiente de confirmar con huellas)
- Decisión: `Initial` (una vez) → por cada segmento del mensaje, en su orden, reglas de su tipo de
  fase `B` y luego `A` → reglas de fase `F` de todos los segmentos (`D` sólo en borrados) → `Final`.
  Una regla asociada a un tipo de segmento se ejecuta una vez por segmento de ese tipo; las réplicas
  deben ser idempotentes.

### D-034 — Alcance de la réplica: el guardado completo desde la Workstation
- Fecha: 2026-09-30 · Estado: VIGENTE (indicación del usuario: "guardar por ventana" =
  mensaje de Workstation + guardar, que lanza `CustomWorkstationWorkflow`)
- Decisión: se replica lo que escribe en la BBDD el guardado: fase 1 (motor: message set y reglas
  Java) y fase 2 (workflows lanzados tras el motor: REU, shortname, datos regulatorios, casos por
  modelo, auditoría México...). Orden y bloqueos en `docs/motor/FLUJO_WORKSTATION.md`, apartado 3.
  Publicaciones a ESB/MQ/JMS, ficheros y correos no se replican.
- Consecuencias: la lógica de la fase 2 que está en BLOB se obtiene con
  `fileloading/extracciones/extracciones_workstation.sql` (W1–W6) y se decodifica con
  `fileloading/herramientas/decodificar_extracciones.py`; después se re-sincroniza.

### D-035 — Validaciones del motor: el generador no crea lo que GoldenSource rechazaría
- Fecha: 2026-09-30 · Estado: VIGENTE (P-017, indicación del usuario)
- Contexto: el motor rechaza mensajes con notificaciones de severidad 40/50 (p. ej. `FLG_Uniqueness`:
  nombre legal ya activo → STRDATA/JAVARULE/9001 ERROR).
- Decisión (`herramientas/motor/validaciones_motor.py`):
  1. **Al generar**: `generar_plsql.py` comprueba con los mensajes, el catálogo, las variaciones y las
     cantidades si GoldenSource rechazaría algo (p. ej. dos entidades con el mismo nombre legal). Si
     es así, falla con el texto de la notificación de GoldenSource, **no actualiza `plsql/generado/`**
     y Claude devuelve ese mensaje al usuario por el chat.
  2. **Al ejecutar**: cada `crear_<entidad>` comprueba antes de insertar, contra los datos que ya hay
     en la BBDD, lo mismo que el motor; si lo rechazaría, falla con `ge_rechazo_motor` (-20006) y el
     texto de la notificación, sin crear nada (`crear_bbdd` se deshace entera).
- Si hay un duplicado **se pide que se cambie el valor** (indicación del usuario, 2026-09-30): los
  mensajes de error, al generar y al ejecutar, dicen qué campo duplicado hay que cambiar
  (`Segmento/ETIQUETA` del mensaje o parámetro `P_...`) y Claude pide al usuario por el chat el nuevo
  valor; nunca se cambia por su cuenta (sin sufijos automáticos). El nuevo valor se aplica como
  parámetro + variación (D-014) o editando el mensaje si el usuario lo indica.
- Replicadas: `FLG_Uniqueness` (nombre legal). Pendiente: `Uniqueness` (identificadores).
- Consecuencias: un mensaje cuyo nombre legal ya existe en `KYTL_GC` (p. ej. porque se guardó
  desde la Workstation para obtenerlo) no se puede crear tal cual: hay que parametrizar el nombre
  legal (variación) o eliminar antes la entidad original. El nombre legal se busca en la tabla del
  segmento (`FINANCIAL_LEGAL_NAMES`); la regla original consulta `FT_T_FLG1` (P-020).
- Ajuste (revisión 2026-09-30): no cuentan las filas sintéticas en `SINT_REGISTRO` con estado
  `BORRANDO` (ya eliminadas, pendientes del job de D-027); así se puede crear justo después de
  `eliminar_bbdd` sin esperar a que termine el borrado físico.

### D-036 — Se replican también las tablas de control, difusión y cachés
- Fecha: 2026-09-30 · Estado: VIGENTE (P-018, indicación del usuario: "por si acaso")
- Decisión: además de las entidades de negocio, se replican las escrituras de los workflows
  posteriores al motor en `FT_T_RLT1`, `FT_T_EMM1`, `FT_T_CCA1`, `FT_T_CAC1`, `CACHE_COUNTERPARTIES`,
  `FT_T_VREQ`, `FT_T_ALG1`, `FT_T_UTD1`. Siguen sin replicarse los envíos (ESB/MQ/JMS), ficheros y
  correos. Orden: `docs/motor/FLUJO_WORKSTATION.md`, apartado 3 (prioridad 7 → se incluye).

### D-037 — Fase 2: las escrituras de los workflows se añaden al mensaje como segmentos
- Fecha: 2026-09-30 · Estado: VIGENTE
- Contexto: tras el motor, `CustomWorkstationWorkflow` lanza workflows que escriben en la BBDD
  (D-034, D-036). Su código está decodificado en `fileloading/extracciones/decodificado/`.
- Decisión: `herramientas/motor/flujo_workstation.py` replica esos workflows sobre el mensaje ya
  procesado por el motor y **añade un segmento STREET_REF por cada fila que escriben** (atributo
  `ORIGEN` = workflow; etiquetas XELM del segmento de la tabla). El generador los traduce como el
  resto: claves nuevas (las referencias a OIDs del mensaje se sustituyen), marca sintética
  (`LAST_CHG_USR_ID`, D-001) y fechas técnicas; quedan en `SINT_REGISTRO` y se borran igual.
  Lo que no está replicado se avisa como PENDIENTE en la cabecera del procedimiento; nunca se inventa.
- Replicado: `Checks` (rama) y `CheckDatosRegulatorios` camino GLOBAL → fila de control `CONTROLDR`
  en `FT_T_RLT1`. Para una contrapartida GLOBAL nueva el resto de workflows no escribe datos de
  negocio ni de control (análisis en `docs/motor/FLUJO_WORKSTATION.md`, apartado 4).
- `FT_T_RLT1` = `REGISTER_LOG_TABLE` (sinónimo confirmado, P-021): la Contrapartida Global crea 11 filas.

### D-038 — Eliminar borra todo lo que se puede; lo que no, queda BLOQUEADO
- Fecha: 2026-09-30 · Estado: VIGENTE (P-008, indicación del usuario: "debería borrarse todo lo que se pueda")
- Contexto: si una prueba crea registros propios (no sintéticos) que cuelgan por FK de una fila
  sintética, esa fila no se puede borrar (ORA-02292). Antes el borrado se detenía (ORA-20003).
- Decisión:
  1. `eliminar_bbdd` (job o síncrono) borra con `FORALL ... SAVE EXCEPTIONS`: las filas con hijos
     no sintéticos se saltan y quedan en `SINT_REGISTRO` con estado **`BLOQUEADO`**; el resto se
     borra. Sus padres sintéticos quedan también bloqueados (su hija sintética sigue existiendo).
     Los registros de las pruebas **no se borran** (no son sintéticos: no se tocan datos ajenos).
  2. `estado_borrado` lista las bloqueadas por tabla con la FK y la tabla hija que lo impiden.
  3. El siguiente `eliminar_bbdd` reintenta las BLOQUEADAS (pasan a BORRANDO con las ACTIVAS).
  4. `crear_bbdd` no cuenta las BLOQUEADAS (sólo impiden crear las ACTIVAS). Ojo: si una bloqueada
     tiene un nombre legal ACTIVO, `FLG_Uniqueness` (D-035) rechazará crear otra con ese nombre.
  5. `limpiar_restos` también borra todo lo que puede (fila a fila en las tablas con hijos ajenos).
  6. `desinstalar.sql` se detiene (ORA-20003) si quedan BLOQUEADAS, para no perder su registro.
- Probado en local con una tabla hija no sintética (`probar_en_local.sh`, apartado P-008).
- Ampliada por D-039: los registros de las pruebas que tienen la clave de la entidad (INST_MNEM)
  SÍ se borran; sólo quedan BLOQUEADAS las filas de las que cuelgan registros por otras columnas.

### D-039 — El borrado es por entidad: todas las tablas con INST_MNEM
- Fecha: 2026-10-01 · Estado: VIGENTE (indicación del usuario: "lo mejor es borrar por entidades
  [...] TODAS las tablas de contrapartidas tienen INST_MNEM, así aseguramos que registros que no
  insertemos nosotros se borran también")
- Contexto: en el modelo hay 185 tablas con `INST_MNEM` y sólo 2 FKs habilitadas `INST_MNEM` →
  `FT_T_FINS`: al borrar la FINS, los registros que las pruebas o GoldenSource hubieran colgado de
  ella (FIID FINSID, ISID...) quedarían huérfanos sin ningún error.
- Decisión: tabla principal de cada unidad = `FT_T_<unidad>` (FINS), columna = su PK (`INST_MNEM`).
  El generador declara `g_orden_borrado` (tablas gestionadas + todas las del modelo con esa columna,
  sin vistas, hijas antes que padres) y `g_barrido_columna`/`g_barrido_principal`. El job, antes del
  borrado por clave de cada tabla, ejecuta UNA sentencia
  `DELETE tabla WHERE INST_MNEM IN (claves de FT_T_FINS en BORRANDO)`: una lectura por tabla y
  borrado (no por fila). Las tablas del modelo que no existen en el esquema se ignoran. Si alguna
  fila tiene hijos (ORA-02292) se repite fila a fila y se saltan las que no se pueden borrar.
- Coste: una lectura completa de cada tabla con INST_MNEM sin índice, una vez por borrado (job en
  segundo plano). `plsql/motor/diagnostico_finsid.sql` (apartado 6) mide esos tiempos en KYTL_GC.
- `limpiar_restos` sigue limitado a las tablas gestionadas (por `LAST_CHG_USR_ID`).
- Probado en local: un FIID creado por "las pruebas" para la contrapartida sintética se borra.

---

## Preguntas abiertas

| Id | Pregunta | Estado |
|---|---|---|
| P-001 | Generación de OIDs. | RESUELTA → D-008 (función `NEW_OID`) |
| P-002 | Segmento `FINSFinancialLegalNames` sin XELM. | RESUELTA → D-010 (tabla `FINANCIAL_LEGAL_NAMES` confirmada por el usuario, XELM heredado) |
| P-003 | Estructura física y constraints. | RESUELTA → extracciones en `esquema/old/`, `modelo.json` |
| P-004 | Semántica de `OPTIMISTICUPDATE`. | RESUELTA → D-005 |
| P-005 | Datos de referencia. | RESUELTA → D-009 (deben existir en BBDD) |
| P-006 | Triggers / auditoría / historial. | RESUELTA: no hay |
| P-007 | Esquema y despliegue. | RESUELTA: `KYTL_GC` (D-011), SQL Developer (D-016) |
| P-008 | Registros sintéticos modificados por las pruebas (cambia `LAST_CHG_USR_ID`) o registros de las pruebas que cuelgan de ellos. | RESUELTA → D-038: se borra todo lo que se puede; lo que tiene registros no sintéticos colgando queda BLOQUEADO y se reintenta |
| P-009 | Volumen esperado. | RESUELTA: cientos de entidades (303 contrapartidas = 3.030 filas en ~0,05 s en local) |
| P-010 | Firma exacta de `NEW_OID`. | RESUELTA: función sin parámetros que devuelve el OID de 10 caracteres, accesible desde `KYTL_GC` (D-008) |
| P-011 | Variaciones y cantidades de la Contrapartida Global. | RESUELTA → D-014 (una entidad idéntica al mensaje; variaciones sólo por petición) |
| P-012 | ¿Puede el DBA crear los índices que propone `plsql/diagnostico_borrado.sql` sobre las FKs sin índice (D-026)? ¿Edición Enterprise (para `CREATE INDEX ... ONLINE`)? | RESUELTA: no hace falta (usuario): basta con poder crear índices temporales (D-028); sin Enterprise se crean sin ONLINE (ORA-00439 → reintento sin ONLINE) |
| P-013 | ¿La BBDD sintética debe reproducir lo que haría el motor aunque difiera del mensaje? | RESUELTA → D-031 (sí, para mensajes de la Workstation) |
| P-014 | ¿Dónde se validan los scripts y se capturan las huellas? | RESUELTA → D-032. Pendiente saber si los mensajes de la Workstation guardan el mensaje procesado (`FT_T_MSGP`): lo dirá la primera huella |
| P-015 | ¿Se puede obtener de GoldenSource la referencia de reglas del Reference Engine (`CFTI*`/`CGSC*`) o las librerías `GenericRules`/`CamsRules` del servidor? | PARCIAL: `fileloading/analisis/rdrRules.md` confirma que `CFTI*`/`CGSC*` son reglas nativas C++ del motor, sin código en ningún jar. Vías: huellas (D-030) o documentación del fabricante (soporte GoldenSource) |
| P-016 | ¿Recorta el motor los espacios del nombre de clase de `CGSCInvokeJavaRule` (`CreateCopyLAGR `, `RulesCPTY `, `RulesLAGR `)? Si no, esas reglas no se ejecutan en GoldenSource. Se confirma con una huella de un mensaje LAGR/FINSX (notificaciones 9037/9043/9046/9050). | ABIERTA (se revisará más adelante, usuario 2026-09-30) |
| P-017 | Unicidades del motor: ¿fallar o generar valores únicos? | RESUELTA → D-035 (detectar, avisar por el chat y no actualizar el PL/SQL) |
| P-018 | ¿Replicar las tablas de control de difusión y cachés? | RESUELTA → D-036 (sí) |
| P-019 | Extraer W1–W6 (`fileloading/extracciones/extracciones_workstation.sql`). | RESUELTA: subidas a `fileloading/extracciones/` y decodificadas en `fileloading/extracciones/decodificado/` |
| P-020 | ¿`FT_T_FLG1` es sinónimo de `FINANCIAL_LEGAL_NAMES`? | RESUELTA: sí (`SINONIMOS_ADICIONALES.csv`); la validación de D-035 es correcta |
| P-021 | Tablas custom `FT_T_*1` accedidas por sinónimo. | RESUELTA → D-010 punto 4 (35 TBL_ID confirmados por sinónimo, todos en KYTL_GC) |
| P-022 | FINSID: la contrapartida sintética no tiene FIID `FINSID` (lo crea `CFTIInternalIdentifierCreator`; según el usuario con el procedimiento `GET_IDENTIFIER_ID`). Falta su firma, su código y las columnas que rellena GoldenSource en esa fila: `plsql/motor/diagnostico_finsid.sql`. | ABIERTA (2026-10-01) |
