#!/usr/bin/env bash
# =============================================================================
# probar_en_local.sh
# Prueba de extremo a extremo del generador en un Oracle LOCAL y desechable
# (contenedor gvenzl/oracle-free). NUNCA toca la BBDD real.
#
#   1. Comprueba que plsql/generado está al día con los mensajes y el catálogo.
#   2. Arranca (o reutiliza) el contenedor "ora-sint" con el usuario KYTL_GC.
#   3. Recrea las tablas gestionadas y referenciadas (plsql/generado/manifiesto.json)
#      a partir de esquema/modelo/modelo.json + stub de NEW_OID.
#   4. Carga datos de referencia mínimos (plsql/pruebas/local/referencias_minimas.sql).
#   5. instalar.sql sobre una versión antigua, crear, crear de nuevo (debe negarse),
#      eliminar, limpiar_restos y desinstalar.
#
# Uso:   herramientas/probar_en_local.sh
# =============================================================================
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
CONTENEDOR="ora-sint"
IMAGEN="gvenzl/oracle-free:23-slim-faststart"
CONEXION="KYTL_GC/kytl@localhost/FREEPDB1"

python3 "$RAIZ/herramientas/generar_plsql.py" --comprobar

# Tablas: primero las referenciadas (datos maestros), después las gestionadas.
mapfile -t TABLAS < <(python3 - "$RAIZ/plsql/generado/manifiesto.json" <<'EOF'
import json, sys
m = json.load(open(sys.argv[1]))
vistas = []
for t in m["tablas_referenciadas"] + m["tablas_gestionadas"]:
    if t not in vistas:
        vistas.append(t)
print("\n".join(vistas))
EOF
)

if ! docker info >/dev/null 2>&1; then
  echo "Docker no está arrancado"; exit 1
fi
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
-- Paquetes de versiones anteriores (instalar.sql debe borrarlos)
CREATE PACKAGE pkg_sint_nucleo AS x NUMBER; END;
/
CREATE PACKAGE pkg_sint_fins AS x NUMBER; END;
/
CREATE PACKAGE sint_e_contrapartida_global AS x NUMBER; END;
/
EOF

# Resto sintético de una versión anterior (NO registrado): sólo lo borra limpiar_restos
sqlplus <<'EOF' >/dev/null
INSERT INTO ft_t_fins (inst_mnem, inst_nme, start_tms, last_chg_tms, last_chg_usr_id)
VALUES ('RESTO00001', 'RESTO VERSION ANTERIOR', SYSDATE, SYSDATE, 'TESTING:RDR');
COMMIT;
EOF

echo "=============== instalar.sql (sobre una versión anterior) ==============="
sqlplus <<'EOF'
@instalar.sql
SELECT object_name, object_type, status FROM user_objects
 WHERE object_name LIKE '%SINT%' ORDER BY 1, 2;
EOF
echo "=============== crear_bbdd_sintetica.sql ==============="
sqlplus <<'EOF'
SET TIMING ON
@crear_bbdd_sintetica.sql
EOF
echo "=============== crear otra vez: debe negarse (ORA-20005) sin tocar nada ==============="
sqlplus <<'EOF' | grep -E "ORA-2000|TOTAL"
@crear_bbdd_sintetica.sql
EXEC pkg_sint.resumen;
EOF
echo "=============== eliminar_bbdd_sintetica.sql ==============="
sqlplus <<'EOF'
SET TIMING ON
@eliminar_bbdd_sintetica.sql
EXEC pkg_sint.resumen;
SELECT COUNT(*) AS resto_sin_registrar FROM ft_t_fins WHERE last_chg_usr_id = 'TESTING:RDR';
EOF
echo "=============== crear + limpiar_restos (borra también lo no registrado) ==============="
sqlplus <<'EOF'
SET FEEDBACK OFF
EXEC pkg_sint.set_trazas(FALSE);
@crear_bbdd_sintetica.sql
EXEC pkg_sint.set_trazas(TRUE);
EXEC pkg_sint.limpiar_restos;
SELECT COUNT(*) AS sinteticas_restantes FROM ft_t_fins WHERE last_chg_usr_id = 'TESTING:RDR';
EOF
echo "=============== desinstalar.sql ==============="
sqlplus <<'EOF'
@desinstalar.sql
SELECT COUNT(*) AS objetos_restantes FROM user_objects WHERE object_name LIKE '%SINT%';
EOF
