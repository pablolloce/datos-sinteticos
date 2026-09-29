# mensajes_entrada

Mensajes XML `STREET_REF` generados por el frontal, uno por entidad a construir.

## Convenciones

- **Nombre del fichero**: `<Operacion>_<Entidad>.xml`, en CamelCase y sin espacios.
  Ejemplo: `Alta_Contrapartida_Global.xml`. (El ejemplo inicial conserva el prefijo `Ejemplo_`.)
- Se admite el mensaje tal cual lo exporta la Workstation, incluida la cabecera de texto
  previa a `<?xml ...?>`; la herramienta de análisis la ignora.
- No editar el mensaje a mano salvo para anonimizar datos; si se hace, indicarlo en el chat.

## Peticiones de variación ("genera N entidades cambiando X")

Se piden por el chat indicando, para cada campo que debe variar:

| Campo (elemento XML) | Regla | Ejemplo |
|---|---|---|
| `INSTNME` | prefijo + secuencial | `CPTY_SINT_0001`, `CPTY_SINT_0002`... |
| `GUID` | lista de valores en ciclo | `ES`, `FR`, `DE` |
| `STATCHARVALTXT` | valor fijo distinto al del mensaje | `N` |

El procedimiento `generar_<entidad>` expondrá esos campos como parámetros, de modo que
las variaciones se hacen llamando al procedimiento con otros valores, sin tocar código.
