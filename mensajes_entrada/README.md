# mensajes_entrada

Mensajes XML `STREET_REF` generados por el frontal, uno por entidad a construir.

## Convenciones

- **Nombre del fichero**: `<Operacion>_<Entidad>.xml`, en CamelCase y sin espacios.
  Ejemplo: `Alta_Contrapartida_Global.xml`. (El ejemplo inicial conserva el prefijo `Ejemplo_`.)
- Se admite el mensaje tal cual lo exporta la Workstation, incluida la cabecera de texto
  previa a `<?xml ...?>`; la herramienta de análisis la ignora.
- No editar el mensaje a mano salvo para anonimizar datos; si se hace, indicarlo en el chat.

## Qué se genera a partir de cada mensaje (D-014)

Cada mensaje produce **una entidad idéntica al mensaje**: mismos valores en todos los
campos; sólo las claves internas (OIDs) son nuevas, generadas con `NEW_OID`.

## Variaciones (sólo bajo petición)

Si se necesitan entidades adicionales con cambios, se piden por el chat indicando el
mensaje de partida, la cantidad y, para cada campo, el valor o la regla. Ejemplo:

> A partir de `Ejemplo_Alta_Contrapartida_Global.xml`, genera 3 contrapartidas con país
> `ES` y nombres `CPTY ES 1`, `CPTY ES 2`, `CPTY ES 3`.

La variación se añade, documentada, a la sección 2 de `plsql/generar_bbdd_sintetica.sql`.
