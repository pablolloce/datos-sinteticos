#!/usr/bin/env bash
# =============================================================================
# probar_en_local.sh
# Prueba de extremo a extremo del generador en un Oracle LOCAL y desechable
# (contenedor gvenzl/oracle-free). NUNCA toca la BBDD real.
#
#   1. Arranca (o reutiliza) el contenedor "ora-sint" con el usuario KYTL_GC.
#   2. Recrea las tablas implicadas a partir de esquema/modelo/modelo.json
#      (herramientas/generar_ddl_pruebas.py) + stub de NEW_OID.
#   3. Carga datos de referencia mínimos (plsql/pruebas/local/referencias_minimas.sql).
#   4. Instala los paquetes, genera la BBDD sintética, verifica y revierte.
#
# Uso:   herramientas/probar_en_local.sh
# Requisitos: docker. Al añadir una entidad, ampliar TABLAS y los scripts de prueba.
# =============================================================================
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
CONTENEDOR="ora-sint"
IMAGEN="gvenzl/oracle-free:23-slim-faststart"
CONEXION="KYTL_GC/kytl@localhost/FREEPDB1"

# Tablas a crear: primero las de referencia, después las gestionadas por el generador.
TABLAS=(
  FT_T_ENTR FT_T_GUNT FT_T_INCL FT_T_STDF
  FT_T_FINS FT_T_FIST FT_T_FIGU FINANCIAL_LEGAL_NAMES FT_T_FINR FT_T_FIRL FT_T_ENFR FT_T_FRCL
)

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTENEDOR"; then
  docker rm -f "$CONTENEDOR" >/dev/null 2>&1 || true
  docker run -d --name "$CONTENEDOR" -e ORACLE_PASSWORD=oracle \
         -e APP_USER=KYTL_GC -e APP_USER_PASSWORD=kytl "$IMAGEN" >/dev/null
  echo "Esperando a que arranque Oracle..."
  until docker logs "$CONTENEDOR" 2>&1 | grep -q "DATABASE IS READY"; do sleep 3; done
fi

sqlplus() {  # Ejecuta SQL*Plus dentro del contenedor desde /tmp/plsql
  docker exec -i -w /tmp/plsql "$CONTENEDOR" sqlplus -s "$CONEXION"
}

# Esquema limpio en cada ejecución
docker exec -i "$CONTENEDOR" sqlplus -s / as sysdba >/dev/null <<'EOF'
ALTER SESSION SET CONTAINER = FREEPDB1;
DROP USER kytl_gc CASCADE;
CREATE USER kytl_gc IDENTIFIED BY kytl QUOTA UNLIMITED ON users;
GRANT CREATE SESSION, CREATE TABLE, CREATE PROCEDURE, CREATE SEQUENCE TO kytl_gc;
EOF

docker exec -u root "$CONTENEDOR" rm -rf /tmp/plsql
docker cp "$RAIZ/plsql" "$CONTENEDOR:/tmp/plsql"
python3 "$RAIZ/herramientas/generar_ddl_pruebas.py" "${TABLAS[@]}" > /tmp/entorno_local.sql
docker cp /tmp/entorno_local.sql "$CONTENEDOR:/tmp/plsql/entorno_local.sql"

sqlplus <<'EOF' | grep -E "ORA-|SP2-|Warning" && { echo "ERROR creando el entorno"; exit 1; } || true
SET FEEDBACK OFF
@entorno_local.sql
@pruebas/local/referencias_minimas.sql
EOF

sqlplus <<'EOF'
@instalar.sql
@generar_bbdd_sintetica.sql
@pruebas/verificar_contrapartida_global.sql
@revertir_bbdd_sintetica.sql
EOF
