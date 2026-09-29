# datos-sinteticos

Generador de datos sintéticos en PL/SQL (Oracle 19c) para las pruebas funcionales
automáticas sobre el modelo GoldenSource. Traduce mensajes XML `STREET_REF` del frontal
a INSERTs; todos los registros se marcan con `LAST_CHG_USR_ID = 'TESTING:RDR'` y se pueden
borrar de golpe.

- Objetivo e instrucciones de trabajo: [`CLAUDE.md`](CLAUDE.md)
- Decisiones y preguntas abiertas: [`docs/DECISIONES.md`](docs/DECISIONES.md)
- Técnicas de optimización: [`docs/OPTIMIZACION_ORACLE.md`](docs/OPTIMIZACION_ORACLE.md)

## Uso rápido

```bash
# Analizar un mensaje de entrada (segmento -> tabla -> columnas)
python3 herramientas/analizar_mensaje.py mensajes_entrada/<Mensaje>.xml -o docs/mapeos/<Mensaje>.md

# Ver el mapeo completo de un segmento
python3 herramientas/analizar_mensaje.py --segmento FinancialInstitution
```

```sql
-- Instalar el paquete (desde plsql/)
@instalar.sql
-- Borrar todos los datos sintéticos
@pruebas/purgar.sql
```
