# mensajes_entrada

Mensajes XML `STREET_REF` generados por el frontal, uno por entidad a construir, y el
catálogo `catalogo.json`.

## Convenciones

- **Nombre del fichero**: `<Operacion>_<Entidad>.xml`, en CamelCase y sin espacios.
  Ejemplo: `Alta_Contrapartida_Global.xml`. (El ejemplo inicial conserva el prefijo `Ejemplo_`.)
- Se pueden organizar en subcarpetas (p. ej. por unidad: `fins/`, `issu/`...).
- Se admite el mensaje tal cual lo exporta la Workstation, incluida la cabecera de texto
  previa a `<?xml ...?>`.
- No editar el mensaje a mano salvo para anonimizar datos; si se hace, indicarlo en el chat.

## Qué se genera a partir de cada mensaje (D-014, D-017)

Cada mensaje produce un paquete `SINT_E_<ENTIDAD>` que crea **una entidad idéntica al
mensaje**: mismos valores; sólo las claves internas (OIDs) son nuevas (`NEW_OID`).

## catalogo.json

```json
{
  "entidades": {
    "Ejemplo_Alta_Contrapartida_Global.xml": {         // ruta relativa a mensajes_entrada/
      "nombre": "CONTRAPARTIDA_GLOBAL",                 // paquete SINT_E_<nombre> (máx. 23 caracteres)
      "descripcion": "Alta de contrapartida global ...",
      "parametros": {                                   // sólo si se piden variaciones
        "P_NOMBRE": {
          "descripcion": "Nombre de la institución",
          "campos": ["FinancialInstitution/INSTNME",    // Segmento/TAG donde se aplica
                     "FINSFinancialLegalNames/FLGLEGALNME"]
        }
      }
    }
  },
  "variaciones": [                                      // entidades adicionales pedidas por chat
    {
      "fecha": "2026-10-01",
      "peticion": "3 contrapartidas llamadas CPTY ES",
      "entidad": "CONTRAPARTIDA_GLOBAL",
      "cantidad": 3,
      "valores": { "P_NOMBRE": "CPTY ES" }
    }
  ]
}
```

(El JSON real no admite comentarios; aquí se incluyen sólo como explicación.)

## Variaciones (sólo bajo petición)

Se piden por el chat indicando el mensaje de partida, la cantidad y, para cada campo, el
valor. Ejemplo:

> A partir de `Ejemplo_Alta_Contrapartida_Global.xml`, genera 3 contrapartidas con nombre
> `CPTY ES`.

Se declaran en `catalogo.json`, se regenera el PL/SQL y quedan incluidas en
`pkg_sint.crear_bbdd`.
