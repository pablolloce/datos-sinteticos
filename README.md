# datos-sinteticos

Generador de datos sintéticos en PL/SQL (Oracle 19c, esquema `KYTL_GC`) para las pruebas
funcionales automáticas sobre el modelo GoldenSource. Traduce mensajes XML `STREET_REF`
del frontal a INSERTs; todos los registros se marcan con `LAST_CHG_USR_ID = 'TESTING:RDR'`
y se pueden borrar de golpe.

- Objetivo e instrucciones de trabajo: [`CLAUDE.md`](CLAUDE.md)
- Decisiones y preguntas abiertas: [`docs/DECISIONES.md`](docs/DECISIONES.md)
- Técnicas de optimización: [`docs/OPTIMIZACION_ORACLE.md`](docs/OPTIMIZACION_ORACLE.md)

## Uso en la BBDD (SQL Developer, conectado como KYTL_GC: abrir el script de `plsql/` y ejecutar con F5)

```sql
@instalar.sql                  -- compila PKG_SINT_NUCLEO y los paquetes de unidad
@generar_bbdd_sintetica.sql    -- crea todas las entidades sintéticas (una transacción)
@revertir_bbdd_sintetica.sql   -- borra todos los registros sintéticos
```

Llamadas sueltas:
```sql
EXEC pkg_sint_fins.generar_contrapartida_global(p_commit => TRUE);   -- 1 entidad igual al mensaje
EXEC pkg_sint_nucleo.resumen;
```

## Herramientas

```bash
python3 herramientas/construir_modelo.py                     # esquema/old/*.csv -> esquema/modelo/modelo.json
python3 herramientas/analizar_mensaje.py mensajes_entrada/<Mensaje>.xml -o docs/mapeos/<Mensaje>.md
python3 herramientas/analizar_mensaje.py --segmento FinancialInstitution
python3 herramientas/analizar_mensaje.py --tabla FT_T_FINS
herramientas/probar_en_local.sh                              # prueba completa en Oracle local (docker)
```
