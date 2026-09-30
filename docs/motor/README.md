# Motor de GoldenSource: cómo replicarlo en los datos sintéticos

Este directorio documenta **qué hace el motor de GoldenSource (TPS / Reference Engine) con
un mensaje `STREET_REF`** y las herramientas para acercar la BBDD sintética a lo que
GoldenSource crearía de verdad.

- [`MOTOR_GOLDENSOURCE.md`](MOTOR_GOLDENSOURCE.md): recorrido del mensaje dentro del motor,
  message set, reglas y plan para replicarlo.
- [`FLUJO_WORKSTATION.md`](FLUJO_WORKSTATION.md): qué escribe en la BBDD el guardado desde la
  Workstation (`CustomWorkstationWorkflow`): motor + workflows posteriores, y orden de réplica.
- [`REGLAS_OBSERVADAS.md`](REGLAS_OBSERVADAS.md): comportamiento **confirmado** de cada regla
  (se rellena con las capturas de huella).
- `reglas/<Mensaje>.md`: reglas que dispararía cada mensaje (`reglas_aplicables.py`).
- `huellas/<Mensaje>.md`: comparación mensaje vs lo que hizo GoldenSource (`comparar_huella.py`).

## Conexión con el repositorio `fileloading`

El material del motor **no se copia aquí**: está en el repositorio
[`pablolloce/fileloading`](https://github.com/pablolloce/fileloading) (rama `main`).
`herramientas/motor/sincronizar_fileloading.py` lee el clon local y escribe en `esquema/motor/`
los derivados que usan el generador y las herramientas (D-029); `esquema/motor/origen.json`
indica de qué commit salen.

| Qué | Dónde (en fileloading) |
|---|---|
| EAR del motor (jars de GoldenSource 8.7.1) | raíz del repositorio |
| Reglas Java del cliente | `rdrrules/rdrRules.jar` |
| Catálogo de reglas Java (qué hace cada una, riesgos) | `analisis/rdrRules.md` |
| Metadatos de reglas Java (modelos, segmentos, notificaciones) | `analisis/reglas_java.json` |
| Comportamiento inferido de las reglas nativas C++ | `analisis/reglas_nativas.csv` |
| Message set (reglas por segmento) y configuración de los motores | `extracciones/StreetRefMsgSet.xml`, `TPS-*.xml` |
| Workflows, feeds, mapeos, notificaciones | `extracciones/01..13-*.csv` |
| Consultas de extracción | `extracciones/extracciones.sql` |

Para re-sincronizar (sólo cuando cambie `fileloading`), clonar ambos repositorios en la misma carpeta:

```bash
git clone https://github.com/pablolloce/fileloading
git clone https://github.com/pablolloce/datos-sinteticos
cd datos-sinteticos && python3 herramientas/motor/sincronizar_fileloading.py
# u, otra ubicación:  FILELOADING_REPO=/ruta/a/fileloading python3 herramientas/motor/sincronizar_fileloading.py
```

## Herramientas

El generador (`generar_plsql.py`) aplica las reglas replicadas (`herramientas/motor/reglas_replicadas.py`,
D-031) antes de traducir cada mensaje; sus pruebas: `python3 herramientas/motor/probar_reglas.py`.

```bash
# Reglas que el motor ejecutaría con un mensaje (orden del motor, qué se sabe de cada una)
python3 herramientas/motor/reglas_aplicables.py mensajes_entrada/<Mensaje>.xml -o docs/motor/reglas/<Mensaje>.md

# Qué hizo GoldenSource de verdad con ese mensaje (requiere una captura, ver abajo)
python3 herramientas/motor/comparar_huella.py mensajes_entrada/<Mensaje>.xml huellas/<Mensaje>.csv \
        -o docs/motor/huellas/<Mensaje>.md
```

## Reglas sin código: dónde se definen y cómo saber qué hacen

El message set combina dos tipos de reglas:

| Tipo | Ejemplos | Código | Cómo sabemos qué hace |
|---|---|---|---|
| **Java del cliente** (`CGSCInvokeJavaRule` + clase `es.bbva.kytl.rules.*`) | `Uniqueness`, `setDifusion`, `FLG_Uniqueness` | **Sí** (`rdrRules.jar`, descompilado) | Leyendo el código (`analisis/rdrRules.md`) |
| **Nativas de GoldenSource** (`CFTI*`, `CGSC*`) | `CFTIInternalIdentifierCreator`, `CFTIConstrPrefId`, `CFTISeqNumGenerator` | **No**: librerías C++ compiladas del Reference Engine | Ver abajo |

**Dónde están definidas las nativas.** El motor carga las librerías que indica `ruleDlls` en
`TPS-1.xml` (`GenericRules;CamsRules;BenchmarkRules;SRJavaRules`). Son binarios instalados en el
servidor, en `${gs.bin.path}/ReferenceEngine`, y no forman parte del EAR. **Qué** reglas se
ejecutan, sobre qué segmento, en qué fase y con qué parámetros lo decide el message set
(`FT_T_XMGS.MSG_SET_BLOB`), que sí tenemos. Buena parte de **cómo** se comportan depende también
de tablas de configuración de la BBDD: claves de búsqueda (`FT_O_MKEY`, `FT_T_TIDX`/`TIDC`),
modelos (`MODLID`), secuencias, datos de dominio y el catálogo de notificaciones.

**Cómo conocer su comportamiento, de más a menos fiable:**

1. **Observarlo (captura de huella).** Es la fuente de verdad.
   1. En un entorno de pruebas, guardar la entidad desde la ventana de la Workstation.
   2. Ejecutar `plsql/motor/capturar_huella.sql` con la ventana de tiempo del guardado.
   3. Comparar con `comparar_huella.py`: sale cada fila y columna que el motor añadió o cambió
      respecto al mensaje, la regla candidata y las notificaciones.
   4. Si el tipo de mensaje guarda el mensaje procesado (`FT_T_MSGP.PROC_MSG_BIN`), éste muestra
      además la acción final de cada segmento.
   5. Cada comportamiento confirmado se anota en `REGLAS_OBSERVADAS.md`.
2. **Catálogo de notificaciones.** Los textos `STRDATA/RULEPRC` (403 definiciones en
   `extracciones/13-*.csv`) describen las situaciones que detectan las reglas nativas, p. ej.
   390 *"The preferred identifier has been set to…"* (`CFTIConstrPrefId`) o 165 *"Trying to
   change Primary Identifier"* (`CFTICheckPrimaryIDToBeUpdated`).
3. **Documentación del fabricante.** GoldenSource publica la referencia de reglas del Reference
   Engine en su portal de clientes. Es la forma oficial de conocer los parámetros de cada
   `CFTI*`/`CGSC*`. Conviene pedirla a quien gestione el contrato.
4. **Inspección de las librerías.** Si se dispone de los `.so`/`.dll` del Reference Engine,
   `strings` muestra las sentencias SQL y los mensajes que usa cada regla. Antes de ir más allá
   (desensamblado), revisar la licencia de GoldenSource.
5. **Inferencia por nombre y parámetros.** Es lo que recoge hoy `analisis/reglas_nativas.csv`,
   con un nivel de confianza por regla. Sirve para priorizar, no para implementar.

> **Estado de `capturar_huella.sql`:** escrito y revisado, pero **sin probar** (el entorno
> donde se preparó no tiene Oracle local). Probar primero en un entorno de pruebas.
