# huellas

Capturas de lo que hizo GoldenSource al procesar un mensaje, exportadas desde SQL Developer
tras ejecutar `plsql/motor/capturar_huella.sql` (última consulta, columnas `TABLA` y
`FILAS_XML`, formato CSV).

- Nombre: `<Mensaje>.csv`, igual que el mensaje de `mensajes_entrada/` que se guardó.
- Contienen datos del entorno de pruebas: anonimizar si hace falta antes de subirlas.
- Se analizan con:
  `python3 herramientas/motor/comparar_huella.py mensajes_entrada/<Mensaje>.xml huellas/<Mensaje>.csv -o docs/motor/huellas/<Mensaje>.md`
