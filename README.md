# datos-sinteticos

Generador de datos sintéticos en PL/SQL (Oracle 19c, esquema `KYTL_GC`) para las pruebas
funcionales automáticas sobre el modelo GoldenSource. Cada mensaje XML `STREET_REF` del
frontal se traduce automáticamente a un paquete PL/SQL; todos los registros se marcan con
`LAST_CHG_USR_ID = 'TESTING:RDR'`.

- Objetivo e instrucciones de trabajo: [`CLAUDE.md`](CLAUDE.md)
- Decisiones y preguntas abiertas: [`docs/DECISIONES.md`](docs/DECISIONES.md)
- Técnicas de optimización: [`docs/OPTIMIZACION_ORACLE.md`](docs/OPTIMIZACION_ORACLE.md)

## Uso en la BBDD (SQL Developer, conectado como KYTL_GC)

Abrir el script desde la carpeta `plsql/` y pulsar **F5** (ejecutar como script):

| Script | Qué hace |
|---|---|
| `plsql/crear_bbdd_sintetica.sql` | Instala/actualiza el código y crea **toda** la BBDD sintética (borra antes lo sintético previo, verifica conteos, COMMIT) |
| `plsql/eliminar_bbdd_sintetica.sql` | Borra **toda** la BBDD sintética (COMMIT) |
| `plsql/instalar.sql` | Sólo instala/actualiza el código |
| `plsql/desinstalar.sql` | Borra los datos sintéticos y el código |

Con el código ya instalado, basta una sentencia:

```sql
EXEC pkg_sint.crear_bbdd;      -- crea todo
EXEC pkg_sint.eliminar_bbdd;   -- elimina todo
EXEC pkg_sint.resumen;         -- filas sintéticas por tabla
```

## Herramientas (desarrollo)

```bash
python3 herramientas/construir_modelo.py            # esquema/old/*.csv -> esquema/modelo/modelo.json
python3 herramientas/analizar_mensaje.py mensajes_entrada/<Mensaje>.xml -o docs/mapeos/<Mensaje>.md
python3 herramientas/generar_plsql.py               # mensajes + catálogo -> plsql/generado, instalar.sql...
python3 herramientas/generar_plsql.py --comprobar   # ¿está lo generado al día?
herramientas/probar_en_local.sh                     # prueba completa en Oracle local (docker)
```
