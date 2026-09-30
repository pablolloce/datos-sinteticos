# Qué hace GoldenSource con un mensaje STREET_REF

Resumen del análisis del EAR `fileloading` (GoldenSource 8.7.1.115) y de las extracciones de
configuración de la BBDD. El detalle y las pruebas están en el repositorio `fileloading`
(`analisis/`, `extracciones/`).

## 1. De la ventana a la BBDD

```
Ventana de la Workstation ──(guardar)──► mensaje STREET_REF (MSGCLASSIFICATION=WEBMSG)
Fichero / cola de proveedor ─► feed ─► mapeo MDX (FT_CFG_MSTP → FT_CFG_RSRC) ─► mensaje STREET_REF
                                           │
                    workflow "Basic Message Processing" (v6)
                                           │
               IsWorkstationMessage ? motor TPS-UI : motor TPS-1
                                           │
   Reference Engine (C++) + message set STREETREF (FT_T_XMGS) + reglas Java (rdrRules.jar)
                                           │
              INSERT / UPDATE en FT_T_* + notificaciones (FT_T_NTEL) + transacción (FT_T_TRID)
                                           │
          severidad < 50 ─► Store Vendor Data (VDDB) ─► cierre de transacción ─► publicación
```

- Los mensajes de este repositorio (`mensajes_entrada/`) son los que genera la Workstation
  al **guardar desde una ventana** (`WEBMSG`, modelo `MODLID` de la ventana, p. ej. `RDRFINSG`).
  Hoy el generador los traduce **literalmente** a INSERT (D-014, D-017).
- El motor no inserta el mensaje tal cual: antes, durante y después de cada segmento
  ejecuta reglas que **añaden filas, rellenan columnas, cambian acciones (p. ej. a `IGNORE`)
  o rechazan el mensaje**.

## 2. El message set

`StreetRefMsgSet.xml` (en `fileloading/extracciones/`) asigna reglas a los tipos de segmento:

- `Initial`: se ejecuta una vez por mensaje, antes de los segmentos. Contiene casi todas las
  reglas Java (unas 48), que deciden por `MODL_ID` si les afecta el mensaje.
- `<TipoDeSegmento>`: reglas de ese segmento.
- `Final`: se ejecuta una vez al final (identificador preferente, cierres de fechas, huérfanos…).
- Fases (`ORDER_TYP`): `B` antes de procesar el segmento, `A` después, `F` al final, `D` en
  borrado. `B` y `A` están claras por el uso; `F` y `D` se deducen de las reglas que las usan.
- Hallazgos que afectan a la replicación:
  - El segmento `Issue` está definido **dos veces**: no se sabe cuál de los dos bloques aplica
    el motor.
  - `CreateCopyLAGR `, `RulesCPTY ` y `RulesLAGR ` llevan **un espacio al final** del nombre de
    clase: si el motor no lo recorta, esas reglas no se ejecutan.
  - `SwapAgent` está comentada y `CorporateRelationship` no está configurada.
  - `InactiveFundMIFID` y `GenerateSSISId` están configuradas pero no hacen nada.

## 3. Ejemplo: alta de Contrapartida Global (`RDRFINSG`)

Informe completo en [`reglas/Ejemplo_Alta_Contrapartida_Global.md`](reglas/Ejemplo_Alta_Contrapartida_Global.md).
Lo que previsiblemente hace GoldenSource y la BBDD sintética no hace hoy:

| Regla | Efecto esperado | ¿Lo hace el generador? |
|---|---|---|
| `CFTIInternalIdentifierCreator` (nativa, `FinancialInstitution`, fase F, param `FINSID`) | Crea el identificador interno `FT_T_FIID` con contexto `FINSID` | No: falta una fila `FT_T_FIID` por contrapartida |
| `FLG_Uniqueness` (Java) | Nombre legal (`FLG_LEGAL_NME`) único; si ya existe → notificación 9001 (**ERROR**) | No: el generador crea N contrapartidas con el mismo nombre legal, que GoldenSource rechazaría |
| `Uniqueness` (Java) | Unicidad de identificadores del rol (9001/9002/9003, ERROR) | No valida |
| `ValidateCountryRegion` (Java) | Regiones `STSMNTCR` a `IGNORE` si el país no es CA | Sin efecto en este mensaje (no trae regiones) |
| `setDifusion` (Java) | `DATA_SRC_ID='DIFUSION'` en ENFR `OPE_BRANCH`, FIST de una lista, etc. | Depende de los valores del mensaje |
| `CFTIConstrPrefId` (nativa, `Final`) | Fija `PREF_FINS_ID`/contexto según la prioridad LEI, CUSIP, … BIC | No |

Todo esto está **por confirmar con una captura de huella** (README, "Descubrir qué hace una
regla").

## 4. Plan para replicar el motor en PL/SQL

| Fase | Qué | Estado |
|---|---|---|
| 0 | Saber qué reglas afectan a cada mensaje (`reglas_aplicables.py`) | Hecho |
| 1 | Capturar la huella real de cada tipo de entidad (empezando por Contrapartida Global) y anotar lo confirmado en `REGLAS_OBSERVADAS.md` | Pendiente (necesita entorno de pruebas) |
| 2 | Decidir si la BBDD sintética debe reproducir el motor o seguir fiel al mensaje (P-013) | Pendiente del usuario |
| 3 | Implementar cada regla confirmada **en el generador**, con una decisión `D-xxx` por regla | Pendiente de 1 y 2 |
| 4 | Verificar: capturar la huella de `pkg_sint.crear_bbdd` y compararla con la real (misma herramienta) | Pendiente |

Criterios para la fase 3:

- **Reglas deterministas sobre el mensaje** (añadir segmentos, poner `IGNORE`, fijar
  `DATA_SRC_ID`): se aplican en `generar_plsql.py` antes de traducir. El PL/SQL resultante
  sigue siendo estático.
- **Reglas que consultan la BBDD** (unicidad, `max+1`, secuencias, búsqueda de claves): se
  implementan como funciones del núcleo (`plsql/fuente/`), una por regla, llamadas desde el
  procedimiento de la entidad.
- **Reglas de validación** (notificaciones con severidad 40/50): el generador debe evitar
  crear datos que GoldenSource rechazaría, p. ej. nombres legales únicos por individuo. Esto
  choca con D-014 (entidades idénticas al mensaje) y hay que decidirlo (P-013).
- Una regla nativa **sólo se implementa cuando su efecto está confirmado** por una huella.
  Nunca a partir de la inferencia por nombre (CLAUDE.md, "Nunca inventar").
