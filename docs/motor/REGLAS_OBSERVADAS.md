# Reglas del motor: comportamiento confirmado

Aquí sólo entra lo **observado** en una captura de huella (`plsql/motor/capturar_huella.sql` +
`herramientas/motor/comparar_huella.py`) o leído en el código de `rdrRules.jar`. Lo inferido
por nombre vive en `fileloading/analisis/reglas_nativas.csv` y no se implementa.

Plantilla:

```
### <RULE_NME> (<segmento>, fase <B|A|F|D>, parámetros)
- Fuente: huella <fichero> (fecha, entorno) | código <Clase.java:línea>
- Mensaje: <Mensaje>.xml
- Efecto observado: tablas/filas/columnas que crea o cambia, con valores.
- Condiciones: cuándo actúa y cuándo no.
- Replicación: cómo se implementa (generador | núcleo PL/SQL) → D-xxx
```

---

Sin entradas todavía: pendiente de la primera captura (Contrapartida Global).
