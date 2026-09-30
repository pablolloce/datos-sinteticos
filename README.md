# datos-sinteticos

Generador de datos sintéticos en PL/SQL (Oracle 19c, esquema `KYTL_GC`) para las pruebas
funcionales automáticas sobre el modelo GoldenSource. Cada mensaje XML `STREET_REF` del
frontal se traduce automáticamente a un procedimiento del único paquete `PKG_SINT`; todos
los registros se marcan con
`LAST_CHG_USR_ID = 'TESTING:RDR'`.

- Objetivo e instrucciones de trabajo: [`CLAUDE.md`](CLAUDE.md)
- Decisiones y preguntas abiertas: [`docs/DECISIONES.md`](docs/DECISIONES.md)
- Técnicas de optimización: [`docs/OPTIMIZACION_ORACLE.md`](docs/OPTIMIZACION_ORACLE.md)

## Uso en la BBDD (SQL Developer, conectado como KYTL_GC)

**Instalar / actualizar** (cada vez que cambie el código): abrir `plsql/instalar.sql` desde
la carpeta `plsql/` y pulsar **F5**. Desinstala la versión anterior e instala la nueva
(paquete `PKG_SINT` y tabla de registro `SINT_REGISTRO`). No toca datos.

**Ejecutar** (rápido, no recorre tablas):

```sql
EXEC pkg_sint.crear_bbdd;      -- SÓLO inserta toda la BBDD sintética
EXEC pkg_sint.eliminar_bbdd;   -- SÓLO borra lo insertado
EXEC pkg_sint.resumen;         -- filas sintéticas por tabla
EXEC pkg_sint.limpiar_restos;  -- ocasional y LENTO: borra restos no registrados (versiones anteriores)
```

`plsql/crear_bbdd_sintetica.sql` y `plsql/eliminar_bbdd_sintetica.sql` hacen lo mismo con F5.
`plsql/desinstalar.sql` borra datos, paquete y tabla de registro.

Si `eliminar_bbdd` es lento: `plsql/diagnostico_borrado.sql` (F5, sólo consulta) lista las
claves ajenas activas de otras tablas hacia las tablas del generador que no tienen índice y
propone el `CREATE INDEX` (a validar por el DBA). Ver D-026.

## Herramientas (desarrollo)

```bash
python3 herramientas/construir_modelo.py            # esquema/old/*.csv -> esquema/modelo/modelo.json
python3 herramientas/analizar_mensaje.py mensajes_entrada/<Mensaje>.xml -o docs/mapeos/<Mensaje>.md
python3 herramientas/generar_plsql.py               # mensajes + catálogo -> plsql/generado/pkg_sint.*
python3 herramientas/generar_plsql.py --comprobar   # ¿está lo generado al día?
herramientas/probar_en_local.sh                     # prueba completa en Oracle local (docker)
```
