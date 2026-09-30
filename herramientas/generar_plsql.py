#!/usr/bin/env python3
"""
generar_plsql.py
================

Genera TODO el PL/SQL de las entidades sintéticas a partir de los mensajes XML de
``mensajes_entrada/`` y del catálogo ``mensajes_entrada/catalogo.json`` (D-017).

Salida (``plsql/generado/``, NO editar a mano):

    pkg_sint.pks/.pkb   ÚNICO paquete (D-023):
                          1. núcleo (fragmentos escritos a mano en plsql/fuente/)
                          2. un procedimiento crear_<entidad> por mensaje, agrupados por unidad
                          3. API: crear_bbdd / eliminar_bbdd / estado_borrado / resumen /
                             verificar / limpiar_restos
    manifiesto.json     tablas gestionadas, referencias y conteos (para pruebas)

Reglas de traducción (ver CLAUDE.md §4 y docs/DECISIONES.md):
  - Segmentos INSERT/OPTIMISTIC*/UNKNOWN -> un INSERT (FORALL) por segmento; REFERENCE/IGNORE -> nada.
  - Claves internas (D-018): la PK de un segmento, si es de una sola columna CHAR/VARCHAR2(10), es
    un OID. Si el mensaje la trae, ese valor se sustituye en TODO el mensaje por una clave nueva
    (NEW_OID); si no la trae, se genera una clave nueva para esa fila.
  - LAST_CHG_USR_ID -> 'TESTING:RDR'; START_TMS y LAST_CHG_TMS -> SYSDATE de la llamada.
  - Resto de valores: literales del mensaje (D-014), salvo los declarados como parámetros.
  - Referencias (D-019): cada FK cuyas columnas llevan literales del mensaje se valida antes de
    insertar (el dato maestro debe existir).

Uso:
    python3 herramientas/generar_plsql.py            # genera todo
    python3 herramientas/generar_plsql.py --comprobar # falla si lo generado no está al día
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from collections import OrderedDict
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from analizar_mensaje import cargar_modelo, leer_xml, resolver_columna  # noqa: E402

RAIZ = Path(__file__).resolve().parent.parent
ENTRADA = RAIZ / "mensajes_entrada"
CATALOGO = ENTRADA / "catalogo.json"
SALIDA = RAIZ / "plsql" / "generado"

ACCIONES_INSERT = {"INSERT", "OPTIMISTICUPDATE", "OPTIMISTICINSERT", "UNKNOWN"}
ACCIONES_SIN_EFECTO = {"REFERENCE", "IGNORE"}
FORMATO_FECHA_XML = "%m-%d-%Y %I:%M:%S %p"
LONGITUD_OID = 10
MAX_IDENTIFICADOR = 30          # identificadores prudentes (compatibles con cualquier COMPATIBLE)
PAQUETE = "PKG_SINT"            # ÚNICO paquete del generador (D-023)
PREFIJO_PROCEDIMIENTO = "crear_"
FUENTE = RAIZ / "plsql" / "fuente"   # fragmentos escritos a mano (núcleo)
MAX_LINEAS_AVISO = 150000        # aviso de tamaño del cuerpo (medido: 219.000 líneas compilan, D-023)

CABECERA_GENERADO = """ * GENERADO AUTOMÁTICAMENTE por herramientas/generar_plsql.py — NO EDITAR A MANO.
 * Para cambiarlo: modificar el mensaje XML o mensajes_entrada/catalogo.json y regenerar."""


class ErrorGeneracion(Exception):
    """Información insuficiente para generar una entidad (hay que preguntar al usuario)."""


# ----------------------------------------------------------------------------------------------
# Modelo interno de una entidad
# ----------------------------------------------------------------------------------------------
@dataclass
class Columna:
    nombre: str
    expresion: str          # expresión PL/SQL del valor
    origen: str             # comentario: de dónde sale el valor


@dataclass
class Fila:
    numero: int             # nº de segmento en el mensaje
    segmento: str
    accion: str
    tabla: str
    columnas: list = field(default_factory=list)
    omitidos: list = field(default_factory=list)   # tags sin columna física
    pk: str = ""                                   # columna PK (una sola) -> SINT_REGISTRO
    registro: str = ""                             # expresión del valor de la PK a registrar


@dataclass
class Clave:
    variable: str           # campo del registro de claves (k_...)
    tabla: str
    columna: str
    valor_mensaje: str | None


@dataclass
class Parametro:
    nombre: str
    tipo: str               # tabla.columna%TYPE
    defecto: str            # expresión PL/SQL del valor por defecto (valor del mensaje)
    descripcion: str
    campos: list


@dataclass
class Entidad:
    nombre: str
    procedimiento: str
    unidad: str
    mensaje: str
    descripcion: str
    filas: list
    claves: list
    parametros: list
    referencias: list       # (tabla_ref, [(col_ref, expresion)], usado_por)
    avisos: list
    paquete: str = ""       # se asigna al agrupar por unidad


# ----------------------------------------------------------------------------------------------
# Traducción de valores
# ----------------------------------------------------------------------------------------------
def literal_texto(valor: str) -> str:
    return "'" + valor.replace("'", "''") + "'"


def literal_fecha(valor: str) -> str:
    try:
        f = datetime.strptime(valor.strip(), FORMATO_FECHA_XML)
    except ValueError:
        try:
            f = datetime.strptime(valor.strip(), "%Y-%m-%d %H:%M:%S")
        except ValueError as e:
            raise ErrorGeneracion(f"Fecha con formato no reconocido: {valor!r}") from e
    return f"TO_DATE('{f:%Y-%m-%d %H:%M:%S}', 'YYYY-MM-DD HH24:MI:SS')"


def literal(valor: str, col: list, contexto: str) -> str:
    """Convierte el VALUE del XML en literal Oracle según el tipo físico de la columna."""
    nombre, tipo, longitud = col[0], col[1], col[2]
    if valor is None or valor == "":
        return "NULL"
    if tipo == "DATE":
        return literal_fecha(valor)
    if tipo.startswith("TIMESTAMP"):
        return literal_fecha(valor).replace("TO_DATE", "TO_TIMESTAMP")
    if tipo in ("NUMBER", "FLOAT", "INTEGER"):
        if not re.fullmatch(r"-?\d+(\.\d+)?", valor.strip()):
            raise ErrorGeneracion(f"{contexto}: valor no numérico {valor!r} para {nombre} ({tipo})")
        return valor.strip()
    if tipo in ("CHAR", "VARCHAR2", "NCHAR", "NVARCHAR2") and len(valor.encode("utf-8")) > longitud:
        raise ErrorGeneracion(f"{contexto}: {valor!r} excede la longitud de {nombre} ({tipo}({longitud}))")
    return literal_texto(valor)


def identificador(texto: str) -> str:
    return re.sub(r"[^A-Z0-9_]", "_", texto.upper()).strip("_")


# ----------------------------------------------------------------------------------------------
# Análisis de un mensaje -> Entidad
# ----------------------------------------------------------------------------------------------
def construir_entidad(ruta: Path, config: dict, modelo: dict) -> Entidad:
    raiz = leer_xml(ruta)
    cabecera = raiz.find("HEADER")
    nodo_unidad = cabecera.find("MAIN_ENTITY_TBL_TYP") if cabecera is not None else None
    unidad = identificador(config.get("unidad")
                           or (nodo_unidad.get("VALUE") if nodo_unidad is not None else "GENERAL"))
    nombre = identificador(config.get("nombre") or ruta.stem)
    procedimiento = PREFIJO_PROCEDIMIENTO + nombre.lower()
    if len(procedimiento) > MAX_IDENTIFICADOR:
        raise ErrorGeneracion(f"{ruta.name}: el procedimiento {procedimiento} supera {MAX_IDENTIFICADOR} "
                              f"caracteres; define un 'nombre' de máx. {MAX_IDENTIFICADOR - len(PREFIJO_PROCEDIMIENTO)} "
                              "caracteres en catalogo.json")

    # Parámetros declarados en el catálogo: {P_X: {campos: ["Segmento/TAG", ...], descripcion}}
    campo_a_param: dict = {}
    for p, d in (config.get("parametros") or {}).items():
        if not identificador(p).startswith("P_"):
            raise ErrorGeneracion(f"{ruta.name}: el parámetro {p} debe empezar por P_")
        for campo in d.get("campos", []):
            campo_a_param[campo] = identificador(p)

    avisos: list = []
    segmentos_insert = []
    for n, seg in enumerate(raiz.findall("SEGMENT"), start=1):
        tipo, accion = seg.get("TYPE"), (seg.get("ACTION") or "UNKNOWN").upper()
        if accion in ACCIONES_SIN_EFECTO:
            continue
        if accion not in ACCIONES_INSERT:
            raise ErrorGeneracion(f"{ruta.name} #{n} {tipo}: acción {accion} sin tratamiento definido (D-005)")
        s = modelo["segmentos"].get(tipo)
        if not s or not s["tabla"]:
            raise ErrorGeneracion(f"{ruta.name} #{n} {tipo}: segmento sin tabla física (tablas_manual.csv)")
        if s["origen_tabla"] == "inferida":
            raise ErrorGeneracion(f"{ruta.name} #{n} {tipo}: tabla {s['tabla']} inferida; confirmarla en "
                                  "esquema/modelo/tablas_manual.csv")
        segmentos_insert.append((n, tipo, accion, s, seg.find(tipo)))

    # 1ª pasada: valores del mensaje por fila y claves internas
    claves: list = []
    clave_de_valor: dict = {}           # valor OID del mensaje -> variable
    nombres_usados: set = set()
    filas_crudas = []

    def nueva_variable(columna: str) -> str:
        base = "k_" + columna.lower()
        var, i = base, 2
        while var in nombres_usados:
            var, i = f"{base}_{i}", i + 1
        nombres_usados.add(var)
        return var

    for n, tipo, accion, s, cuerpo in segmentos_insert:
        tabla = s["tabla"]
        t = modelo["tablas"][tabla]
        columnas = {c[0]: c for c in t["columnas"]}
        valores: OrderedDict = OrderedDict()
        omitidos = []
        for el in (cuerpo if cuerpo is not None else []):
            col, _ = resolver_columna(el.tag, s["xelm"], columnas)
            if not col or col not in columnas:
                omitidos.append(el.tag)
                continue
            valores[col] = (el.tag, el.get("VALUE"))

        claves_fila = {}
        pk = t["pk"]
        if len(pk) == 1:
            c = columnas[pk[0]]
            es_oid = c[1] in ("CHAR", "VARCHAR2") and c[2] == LONGITUD_OID
            if pk[0] in valores and es_oid:
                v = valores[pk[0]][1]
                if v in clave_de_valor:
                    raise ErrorGeneracion(f"{ruta.name} #{n} {tipo}: la clave {v} ya se inserta en otro "
                                          "segmento (segmento repetido: consultar)")
                var = nueva_variable(pk[0])
                clave_de_valor[v] = var
                claves.append(Clave(var, tabla, pk[0], v))
            elif pk[0] not in valores:
                if not es_oid:
                    raise ErrorGeneracion(f"{ruta.name} #{n} {tipo}: PK {pk[0]} no informada y no es un OID")
                var = nueva_variable(pk[0])
                claves_fila[pk[0]] = var
                claves.append(Clave(var, tabla, pk[0], None))
            else:
                avisos.append(f"#{n} {tipo}: PK {pk[0]} de negocio; se inserta el valor del mensaje")
        else:
            faltan = [c for c in pk if c not in valores]
            if faltan:
                raise ErrorGeneracion(f"{ruta.name} #{n} {tipo}: PK compuesta con columnas no informadas {faltan}")
        filas_crudas.append((n, tipo, accion, tabla, columnas, valores, omitidos, claves_fila))

    # 2ª pasada: expresiones de cada columna
    parametros: "OrderedDict[str, Parametro]" = OrderedDict()
    longitudes: dict = {}
    referencias: "OrderedDict[tuple, tuple]" = OrderedDict()
    filas = []
    for n, tipo, accion, tabla, columnas, valores, omitidos, claves_fila in filas_crudas:
        fila = Fila(n, tipo, accion, tabla, omitidos=omitidos)
        pk = modelo["tablas"][tabla]["pk"]
        if len(pk) != 1:
            raise ErrorGeneracion(f"{ruta.name} #{n} {tipo}: {tabla} tiene PK de {len(pk)} columnas; "
                                  "SINT_REGISTRO sólo admite PK de una columna (D-024): consultar")
        fila.pk = pk[0]
        exprs: dict = {}
        for col, var in claves_fila.items():
            exprs[col] = (f"l_k(i).{var}", "clave nueva (NEW_OID)")
        for col, (tag, valor) in valores.items():
            contexto = f"{ruta.name} #{n} {tipo}.{tag}"
            param = campo_a_param.get(f"{tipo}/{tag}")
            if col == "LAST_CHG_USR_ID":
                exprs[col] = ("c_usuario", f"{tag} (marca sintética)")
            elif col in ("START_TMS", "LAST_CHG_TMS"):
                exprs[col] = ("l_ahora", f"{tag} (momento de la llamada)")
            elif valor in clave_de_valor:
                exprs[col] = (f"l_k(i).{clave_de_valor[valor]}", f"{tag} = {valor} (clave nueva)")
            elif param:
                defecto = literal(valor, columnas[col], contexto)
                previo = parametros.get(param)
                if previo and previo.defecto != defecto:
                    raise ErrorGeneracion(f"{contexto}: el parámetro {param} tiene valores distintos en el mensaje")
                if not previo:
                    desc = (config["parametros"].get(param) or config["parametros"].get(param.lower()) or {})
                    parametros[param] = Parametro(param, f"{tabla.lower()}.{col.lower()}%TYPE", defecto,
                                                  desc.get("descripcion", ""), [])
                parametros[param].campos.append(f"{tipo}/{tag}")
                # El tipo del parámetro es el de la columna más restrictiva donde se usa
                longitudes.setdefault(param, []).append((columnas[col][2], f"{tabla.lower()}.{col.lower()}%TYPE"))
                parametros[param].tipo = min(longitudes[param])[1]
                exprs[col] = (param.lower(), f"{tag} (parámetro)")
            else:
                exprs[col] = (literal(valor, columnas[col], contexto), tag)
        # Columnas técnicas obligatorias aunque el mensaje no las traiga
        for col, expr in (("LAST_CHG_USR_ID", "c_usuario"), ("START_TMS", "l_ahora"), ("LAST_CHG_TMS", "l_ahora")):
            if col in columnas and col not in exprs:
                exprs[col] = (expr, "técnico (no viene en el mensaje)")
        faltan = [c for c, d in columnas.items() if d[5] == "N" and c not in exprs]
        if faltan:
            raise ErrorGeneracion(f"{ruta.name} #{n} {tipo}: columnas NOT NULL sin valor: {', '.join(faltan)}")
        # Orden físico de columnas (legibilidad y estabilidad del código generado)
        for col in columnas:
            if col in exprs:
                fila.columnas.append(Columna(col, *exprs[col]))
        # Valor de la PK para SINT_REGISTRO: si es un literal sobre CHAR(n), con el relleno
        # de blancos que Oracle aplica al guardarlo (el borrado compara por igualdad exacta).
        expr_pk = exprs[fila.pk][0]
        c_pk = columnas[fila.pk]
        fila.registro = (f"RPAD({expr_pk}, {c_pk[2]})" if c_pk[1] == "CHAR" and expr_pk.startswith("'")
                         else expr_pk)
        filas.append(fila)

        # Referencias: FKs cuyas columnas llevan literales o parámetros (no claves nuevas)
        for fk in modelo["tablas"][tabla]["fk"]:
            if not fk["tabla_ref"] or not fk["columnas"]:
                continue
            valores_fk = [exprs.get(c, ("NULL",))[0] for c in fk["columnas"]]
            if any(v == "NULL" or v.startswith("l_k(") or v in ("c_usuario", "l_ahora") for v in valores_fk):
                continue
            clave_ref = (fk["tabla_ref"], tuple(zip(fk["columnas_ref"], valores_fk)))
            referencias.setdefault(clave_ref, []).append(f"{tabla}.{'/'.join(fk['columnas'])}")

    return Entidad(nombre, procedimiento, unidad, str(ruta.relative_to(RAIZ)), config.get("descripcion", ""),
                   filas, claves, list(parametros.values()),
                   [(t, list(cols), usado) for (t, cols), usado in referencias.items()], avisos)


# ----------------------------------------------------------------------------------------------
# Emisión de PL/SQL
# ----------------------------------------------------------------------------------------------
def conteo_por_tabla(e: Entidad) -> "OrderedDict[str, int]":
    conteo: OrderedDict = OrderedDict()
    for f in e.filas:
        conteo[f.tabla] = conteo.get(f.tabla, 0) + 1
    return conteo


def firma_parametros(e: Entidad, con_defecto: bool = True) -> str:
    lineas = ["      p_cantidad IN PLS_INTEGER DEFAULT 1"]
    for p in e.parametros:
        lineas.append(f"      {p.nombre.lower()} IN {p.tipo}" + (f" DEFAULT {p.defecto}" if con_defecto else ""))
    return ",\n".join(lineas)


def firma(e: Entidad, con_defecto: bool) -> str:
    return f"""   PROCEDURE {e.procedimiento} (
{firma_parametros(e, con_defecto)})"""


def emitir_declaracion(e: Entidad) -> str:
    """Declaración de la entidad en la especificación del paquete de su unidad."""
    conteo = conteo_por_tabla(e)
    filas_txt = "\n".join(f"      *   {t:<28} {n}" for t, n in conteo.items())
    params_txt = "\n".join(f"      *   {p.nombre.lower():<20} {p.descripcion} [{', '.join(p.campos)}]"
                           for p in e.parametros) or "      *   (ninguno: la entidad es idéntica al mensaje)"
    return f"""   /* ------------------------------------------------------------------------
      * {e.nombre}
      * {e.descripcion}
      * Mensaje: {e.mensaje}
      * Filas por entidad ({len(e.filas)}):
{filas_txt}
      * Parámetros de variación (defecto = valor del mensaje, D-014):
{params_txt}
      * Crea p_cantidad entidades con los valores del mensaje; sólo las claves
      * internas son nuevas (NEW_OID). No hace COMMIT.
      * ---------------------------------------------------------------------- */
{firma(e, con_defecto=True)};
"""


def emitir_procedimiento(e: Entidad) -> str:
    """Implementación de la entidad en el cuerpo del paquete de su unidad."""
    ancho = max([len(c.nombre) for f in e.filas for c in f.columnas] + [10])
    campos = "\n".join(
        f"         {k.variable:<{ancho + 2}} {(k.tabla.lower() + '.' + k.columna.lower() + '%TYPE' + (',' if j < len(e.claves) - 1 else '')):<48}"
        f" -- {k.tabla}.{k.columna}" + (f" (mensaje: {k.valor_mensaje})" if k.valor_mensaje else " (no viene en el mensaje)")
        for j, k in enumerate(e.claves))
    genera = "\n".join(f"         l_k(i).{k.variable:<{ancho + 2}} := nuevo_oid;" for k in e.claves)

    refs = []
    for tabla_ref, cols, usado in e.referencias:
        where = "\n            AND ".join(f"{c.lower()} = {v}" for c, v in cols)
        partes = []
        for c, v in cols:
            if v.startswith("p_"):                       # parámetro: se muestra su valor en ejecución
                partes.append(literal_texto(f"{c} = ") + " || " + v)
            else:                                        # literal del mensaje
                texto = v[1:-1].replace("''", "'") if v.startswith("'") else v
                partes.append(literal_texto(f"{c} = {texto}"))
        desc = ", ".join(f"{c} = " + (v[1:-1] if v.startswith("'") else v) for c, v in cols)
        desc_expr = literal_texto(f"{tabla_ref}: ") + " || " + " || ', ' || ".join(partes)
        refs.append(f"""      -- {tabla_ref} ({desc}) <- {', '.join(sorted(set(usado)))}
      SELECT COUNT(*) INTO l_existe FROM {tabla_ref.lower()}
       WHERE {where};
      exigir_referencia(l_existe, {desc_expr});""")
    refs_txt = "\n\n".join(refs) or "      NULL;  -- el mensaje no referencia datos maestros"

    inserts = []
    for f in e.filas:
        cols = ",\n".join(f"             {c.nombre.lower()}" for c in f.columnas)
        vals = []
        for j, c in enumerate(f.columnas):
            coma = "," if j < len(f.columnas) - 1 else " "
            vals.append(f"             {c.expresion + coma:<{max(ancho, 40) + 2}} -- {c.nombre:<{ancho}} <- {c.origen}")
        omit = (f"\n      --   Elementos sin columna física (lógicos del motor, no se insertan): {', '.join(f.omitidos)}"
                if f.omitidos else "")
        inserts.append(f"""      -- Segmento #{f.numero} {f.segmento} ({f.accion}) -> {f.tabla}{omit}
      FORALL i IN 1 .. l_k.COUNT
         INSERT INTO {f.tabla.lower()} (
{cols})
         VALUES (
{chr(10).join(vals)}
         );
      FORALL i IN 1 .. l_k.COUNT   -- clave en SINT_REGISTRO para el borrado rápido (D-024)
         INSERT INTO sint_registro (tabla, columna_pk, clave, entidad)
         VALUES ('{f.tabla}', '{f.pk}', {f.registro}, c_entidad);""")

    sp = f"sp_{e.nombre.lower()[:25]}"
    return f"""   -- ==========================================================================
   -- {e.nombre} — mensaje {e.mensaje}
   -- ==========================================================================
{firma(e, con_defecto=False)}
   IS
      c_usuario           CONSTANT VARCHAR2(30) := gc_usuario_sintetico;
      c_entidad           CONSTANT VARCHAR2(30) := '{e.nombre[:30]}';
      c_filas_por_entidad CONSTANT PLS_INTEGER  := {len(e.filas)};
      l_ahora             CONSTANT DATE         := SYSDATE;   -- START_TMS y LAST_CHG_TMS (D-007)

      -- Claves internas de UNA entidad: una por cada OID del mensaje que se inserta
      -- y por cada PK que el mensaje no informa. Se generan todas antes de insertar.
      TYPE t_claves IS RECORD (
{campos}
      );
      TYPE t_lista_claves IS TABLE OF t_claves INDEX BY PLS_INTEGER;

      l_existe  PLS_INTEGER;
      l_k       t_lista_claves;
   BEGIN
      validar_cantidad(p_cantidad);

      -------------------------------------------------------------------------
      -- 1. Datos maestros referenciados: deben existir (D-019)
      -------------------------------------------------------------------------
{refs_txt}

      -------------------------------------------------------------------------
      -- 2. Claves internas nuevas para cada entidad
      -------------------------------------------------------------------------
      FOR i IN 1 .. p_cantidad LOOP
{genera}
      END LOOP;

      SAVEPOINT {sp};

      -------------------------------------------------------------------------
      -- 3. Inserciones: un FORALL por segmento del mensaje, en su orden
      -------------------------------------------------------------------------
{chr(10).join(chr(10) + x if i else x for i, x in enumerate(inserts))}

      traza('{e.nombre}: ' || p_cantidad || ' entidad(es), '
                            || p_cantidad * c_filas_por_entidad || ' filas');
   EXCEPTION
      WHEN OTHERS THEN
         traza('{e.nombre}: ERROR ' || SQLERRM);
         BEGIN
            ROLLBACK TO SAVEPOINT {sp};
         EXCEPTION
            WHEN OTHERS THEN NULL;  -- error anterior al SAVEPOINT: no hay nada que deshacer
         END;
         RAISE;
   END {e.procedimiento};
"""


def valor_variacion(p: Parametro, valor) -> str:
    if valor is None:
        return "NULL"
    if isinstance(valor, (int, float)):
        return str(valor)
    if p.defecto.startswith("TO_DATE"):
        return literal_fecha(str(valor))
    return literal_texto(str(valor))


def orden_purga(tablas: list, modelo: dict) -> list:
    """Orden de borrado: hijas antes que padres según las FKs entre tablas gestionadas."""
    conjunto = set(tablas)
    padres = {t: {fk["tabla_ref"] for fk in modelo["tablas"][t]["fk"]
                  if fk["tabla_ref"] in conjunto and fk["tabla_ref"] != t} for t in tablas}
    orden, pendientes = [], list(tablas)
    while pendientes:
        # una tabla se puede borrar cuando ninguna pendiente la referencia
        libres = [t for t in pendientes if not any(t in padres[o] for o in pendientes if o != t)]
        if not libres:              # ciclo de FKs: se respeta el orden inverso de inserción
            libres = [pendientes[-1]]
        siguiente = max(libres, key=lambda t: tablas.index(t))   # la última insertada primero
        orden.append(siguiente)
        pendientes.remove(siguiente)
    return orden


def seccion(titulo: str) -> str:
    return ("   -- #########################################################################\n"
            f"   -- {titulo}\n"
            "   -- #########################################################################\n")


def emitir_paquete(entidades: list, variaciones: list, modelo: dict) -> tuple[str, str, dict]:
    """PKG_SINT completo: núcleo (fragmentos a mano) + entidades por unidad + API."""
    for e in entidades:
        e.paquete = PAQUETE
    orden = sorted(entidades, key=lambda x: (x.unidad, x.nombre))

    tablas = []
    for e in orden:
        for t in conteo_por_tabla(e):
            if t not in tablas:
                tablas.append(t)
    purga = orden_purga(tablas, modelo)

    esperadas: OrderedDict = OrderedDict((t, 0) for t in tablas)
    llamadas = []
    por_nombre = {e.nombre: e for e in entidades}
    for e in orden:
        llamadas.append(f"      {e.procedimiento};   -- {e.unidad}: {e.mensaje}")
        for t, n in conteo_por_tabla(e).items():
            esperadas[t] += n
    llamadas_var = []
    for v in variaciones:
        e = por_nombre.get(identificador(v["entidad"]))
        if not e:
            raise ErrorGeneracion(f"Variación sobre entidad desconocida: {v['entidad']}")
        cantidad = int(v.get("cantidad", 1))
        params = {p.nombre: p for p in e.parametros}
        args = [f"p_cantidad => {cantidad}"]
        for nombre, valor in (v.get("valores") or {}).items():
            p = params.get(identificador(nombre))
            if not p:
                raise ErrorGeneracion(f"Variación de {e.nombre}: parámetro {nombre} no declarado en catalogo.json")
            args.append(f"{p.nombre.lower()} => {valor_variacion(p, valor)}")
        llamadas_var.append(f"      -- [{v.get('fecha', '')}] {v.get('peticion', '')}\n"
                            f"      {e.procedimiento}({', '.join(args)});")
        for t, n in conteo_por_tabla(e).items():
            esperadas[t] += n * cantidad

    def por_unidad(emitir) -> str:
        bloques, unidad = [], None
        for e in orden:
            if e.unidad != unidad:
                unidad = e.unidad
                bloques.append(seccion(f"ENTIDADES — UNIDAD {unidad}"))
            bloques.append(emitir(e))
        return "\n".join(bloques)

    indice = "\n".join(f" *   {e.unidad:<6} {e.procedimiento:<30} {len(e.filas):>4} filas  {e.mensaje}" for e in orden)
    lista = lambda ts: ",\n".join(f"      '{t}'" for t in ts)  # noqa: E731
    cuentas = ",\n".join(f"      {n}" for n in esperadas.values())
    nucleo_spec = (FUENTE / "nucleo_especificacion.sql").read_text(encoding="utf-8").rstrip()
    nucleo_body = (FUENTE / "nucleo_cuerpo.sql").read_text(encoding="utf-8").rstrip()
    marca = "   -- <<DATOS_GENERADOS>>"
    if marca not in nucleo_body:
        raise ErrorGeneracion(f"Falta la marca {marca.strip()} en plsql/fuente/nucleo_cuerpo.sql")
    datos = f"""   -- ---- Datos generados (API) -------------------------------------------------
   -- Tablas gestionadas en orden de primera inserción (resumen y verificación).
   g_tablas CONSTANT t_lista_tablas := t_lista_tablas(
{lista(tablas)});

   -- Filas sintéticas esperadas tras crear_bbdd, en el mismo orden que g_tablas.
   g_filas_esperadas CONSTANT t_lista_numeros := t_lista_numeros(
{cuentas});

   -- Orden de borrado: hijas antes que padres (calculado a partir de las FKs).
   g_tablas_purga CONSTANT t_lista_tablas := t_lista_tablas(
{lista(purga)});
   -- ---------------------------------------------------------------------------"""
    nucleo_body = nucleo_body.replace(marca, datos)

    cabecera = f"""/*******************************************************************************
{CABECERA_GENERADO}
 * El núcleo se escribe a mano en plsql/fuente/ y se inserta aquí al generar.
 *
 * PKG_SINT — GENERADOR DE LA BBDD SINTÉTICA (único paquete, D-023)
 *
 *    EXEC pkg_sint.crear_bbdd;      -- SÓLO inserta toda la BBDD sintética y COMMIT (rápido)
 *    EXEC pkg_sint.eliminar_bbdd;   -- elimina lo insertado: responde al instante y un job de
 *                                   -- Oracle lo borra físicamente en segundo plano (D-027)
 *    EXEC pkg_sint.estado_borrado;  -- progreso del borrado en segundo plano
 *    EXEC pkg_sint.resumen;         -- filas sintéticas registradas por tabla y estado
 *    EXEC pkg_sint.limpiar_restos;  -- (ocasional, LENTO) borra por LAST_CHG_USR_ID lo no registrado
 *
 * Cada fila creada se anota en la tabla SINT_REGISTRO (tabla, columna PK, clave), de modo
 * que borrar y verificar van por clave primaria y no recorren tablas de millones de filas.
 *
 * Organización:
 *    1. NÚCLEO      utilidades comunes (plsql/fuente/)
 *    2. ENTIDADES   un procedimiento crear_<entidad> por mensaje, agrupados por unidad
 *    3. API         crear_bbdd, eliminar_bbdd, estado_borrado, resumen, verificar, limpiar_restos
 *
 * Entidades: {len(entidades)} · Variaciones: {len(variaciones)} · Tablas gestionadas: {len(tablas)}
 *   Unidad Procedimiento                  Filas  Mensaje
{indice}
 ******************************************************************************/"""

    spec = f"""CREATE OR REPLACE PACKAGE pkg_sint
AS
{cabecera}

{seccion("1. NÚCLEO")}
{nucleo_spec}

{seccion("2. ENTIDADES")}
{por_unidad(emitir_declaracion)}
{seccion("3. API")}
   /* Inserta TODA la BBDD sintética (entidades de los mensajes + variaciones) en UNA
      transacción, la verifica (por clave, rápido) y hace COMMIT. No borra nada: si ya
      hay una BBDD sintética registrada, falla (ORA-20005) para no duplicarla. */
   PROCEDURE crear_bbdd (p_commit IN BOOLEAN DEFAULT TRUE);

   /* Elimina FÍSICAMENTE todo lo insertado (D-027):
        1. Inmediato: marca las claves registradas como BORRANDO (crear_bbdd ya puede volver
           a ejecutarse).
        2. Un job de Oracle (DBMS_SCHEDULER) borra por clave, hijas antes que padres.
      p_segundo_plano => FALSE hace el paso 2 en esta sesión (espera a que termine).
      El paso 2 es lento por cada fila de tabla padre (FT_T_FINS, FT_T_FINR...): Oracle
      recorre las tablas hijas con FK sin índice (D-026). */
   PROCEDURE eliminar_bbdd (p_segundo_plano IN BOOLEAN DEFAULT TRUE);

   /* Progreso del borrado en segundo plano: filas pendientes, jobs en curso y últimas
      ejecuciones (con el error, si lo hubo). */
   PROCEDURE estado_borrado;

   /* Uso interno: acción del job de borrado. No es necesario llamarlo a mano. */
   PROCEDURE ejecutar_borrado_pendiente;

   /* Filas sintéticas registradas por tabla (sólo lee SINT_REGISTRO). */
   PROCEDURE resumen;

   /* Comprueba que las filas registradas existen y cuadran con lo esperado (ORA-20004). */
   PROCEDURE verificar;

   /* LENTO (recorre las tablas completas): borra toda fila con LAST_CHG_USR_ID =
      'TESTING:RDR' de las tablas gestionadas, esté o no registrada, y vacía el registro.
      Sólo para restos de versiones anteriores o datos no registrados. */
   PROCEDURE limpiar_restos (p_commit IN BOOLEAN DEFAULT TRUE);

END pkg_sint;
/
"""
    body = f"""CREATE OR REPLACE PACKAGE BODY pkg_sint
AS
{cabecera}

{seccion("1. NÚCLEO")}
{nucleo_body}

{por_unidad(emitir_procedimiento)}
{seccion("3. API")}
   PROCEDURE resumen
   IS
   BEGIN
      resumen_registro;
   END resumen;

   PROCEDURE verificar
   IS
   BEGIN
      verificar_registro(g_tablas, g_filas_esperadas);
   END verificar;

   PROCEDURE eliminar_bbdd (p_segundo_plano IN BOOLEAN DEFAULT TRUE)
   IS
      l_marcadas   PLS_INTEGER;
      l_pendientes PLS_INTEGER;
   BEGIN
      l_marcadas := marcar_para_borrar;
      SELECT COUNT(*) INTO l_pendientes FROM sint_registro WHERE estado = gc_borrando;
      traza('Eliminación de la BBDD sintética: ' || l_marcadas || ' filas marcadas; ' ||
            l_pendientes || ' pendientes de borrado físico');
      IF l_pendientes = 0 THEN
         traza('No hay nada que borrar.');
      ELSIF p_segundo_plano THEN
         traza('Borrado físico lanzado en segundo plano (job ' || lanzar_job_borrado ||
               '). Progreso: EXEC pkg_sint.estado_borrado;');
      ELSE
         borrar_pendientes(g_tablas_purga);
      END IF;
   END eliminar_bbdd;

   PROCEDURE estado_borrado
   IS
   BEGIN
      informe_borrado;
   END estado_borrado;

   PROCEDURE ejecutar_borrado_pendiente
   IS
   BEGIN
      DBMS_OUTPUT.enable(NULL);   -- la salida del job queda en USER_SCHEDULER_JOB_RUN_DETAILS.OUTPUT
      borrar_pendientes(g_tablas_purga);
   END ejecutar_borrado_pendiente;

   PROCEDURE limpiar_restos (p_commit IN BOOLEAN DEFAULT TRUE)
   IS
   BEGIN
      purgar_por_usuario(g_tablas_purga, p_commit);
   END limpiar_restos;

   PROCEDURE crear_bbdd (p_commit IN BOOLEAN DEFAULT TRUE)
   IS
   BEGIN
      traza('=== Creación de la BBDD sintética ===');
      IF hay_registro THEN
         RAISE_APPLICATION_ERROR(ge_bbdd_ya_creada,
            'Ya existe una BBDD sintética registrada: ejecute antes EXEC pkg_sint.eliminar_bbdd;');
      END IF;
      SAVEPOINT sp_crear_bbdd;

      -------------------------------------------------------------------------
      -- 1. Entidades de los mensajes (una entidad idéntica a cada mensaje)
      -------------------------------------------------------------------------
{chr(10).join(llamadas)}

      -------------------------------------------------------------------------
      -- 2. Variaciones solicitadas por chat (mensajes_entrada/catalogo.json)
      -------------------------------------------------------------------------
{chr(10).join(llamadas_var) or '      NULL;  -- ninguna'}

      verificar;          -- por clave primaria: sólo lee las filas recién creadas
      IF p_commit THEN
         COMMIT;
      END IF;
      traza('=== BBDD sintética creada' ||
            CASE WHEN p_commit THEN ' (COMMIT)' ELSE ' (pendiente de COMMIT)' END || ' ===');
   EXCEPTION
      WHEN OTHERS THEN
         ROLLBACK TO SAVEPOINT sp_crear_bbdd;
         traza('ERROR: creación deshecha. ' || SQLERRM);
         RAISE;
   END crear_bbdd;

END pkg_sint;
/
"""
    manifiesto = {"paquete": PAQUETE, "lineas_cuerpo": body.count("\n"),
                  "tablas_gestionadas": tablas, "orden_purga": purga,
                  "filas_esperadas": dict(esperadas),
                  "tablas_referenciadas": sorted({r[0] for e in entidades for r in e.referencias}),
                  "entidades": [{"nombre": e.nombre, "procedimiento": e.procedimiento, "unidad": e.unidad,
                                 "mensaje": e.mensaje, "filas_por_entidad": len(e.filas),
                                 "avisos": e.avisos} for e in orden]}
    return spec, body, manifiesto


def emitir_diagnostico(manifiesto: dict) -> str:
    """plsql/diagnostico_borrado.sql: FKs activas de otras tablas hacia las tablas gestionadas
    y si su(s) columna(s) tienen índice. Sin índice, cada fila padre borrada recorre la hija
    entera (y bloquea la hija mientras dura): es la causa de un eliminar_bbdd lento (D-026)."""
    lista = ", ".join(f"'{t}'" for t in manifiesto["tablas_gestionadas"])
    return f"""--------------------------------------------------------------------------------
-- diagnostico_borrado.sql
-- GENERADO AUTOMÁTICAMENTE por herramientas/generar_plsql.py — NO EDITAR A MANO.
--
-- ¿Por qué tarda eliminar_bbdd? Al borrar una fila de una tabla padre, Oracle comprueba
-- cada FK ACTIVA que apunta a ella desde otras tablas. Si la columna de la FK en la tabla
-- hija NO tiene índice, Oracle recorre la hija entera POR CADA FILA borrada (y la bloquea).
--
-- Este script lista esas FKs para las tablas del generador, indica si están indexadas y
-- propone el CREATE INDEX que lo resolvería (a validar/ejecutar por el DBA).
--
-- SQL Developer (conectado como KYTL_GC): abrir y pulsar F5. Sólo consulta, no cambia nada.
--------------------------------------------------------------------------------
SET LINESIZE 250 PAGESIZE 200
COLUMN padre       FORMAT A22
COLUMN hija        FORMAT A24
COLUMN fk          FORMAT A28
COLUMN columnas    FORMAT A30
COLUMN indexada    FORMAT A8
COLUMN filas_hija  FORMAT 999,999,999,999
COLUMN propuesta   FORMAT A110

WITH gestionadas AS (
   SELECT column_value AS tabla
     FROM TABLE(sys.odcivarchar2list({lista}))
), fks AS (
   SELECT p.table_name AS padre, c.table_name AS hija, c.constraint_name AS fk
     FROM user_constraints c
     JOIN user_constraints p ON p.owner = c.r_owner AND p.constraint_name = c.r_constraint_name
    WHERE c.constraint_type = 'R'
      AND c.status = 'ENABLED'
      AND p.table_name IN (SELECT tabla FROM gestionadas)
)
SELECT padre, hija, fk, columnas, indexada, filas_hija,
       CASE WHEN indexada = 'NO'
            THEN 'CREATE INDEX ' || SUBSTR('IX_' || fk, 1, 30) || ' ON ' || hija || ' (' || columnas || ') ONLINE;'
       END AS propuesta
  FROM (
SELECT f.padre, f.hija, f.fk,
       (SELECT LISTAGG(cc.column_name, ', ') WITHIN GROUP (ORDER BY cc.position)
          FROM user_cons_columns cc WHERE cc.constraint_name = f.fk) AS columnas,
       CASE WHEN EXISTS (
               -- un índice de la hija cuyas primeras columnas son las de la FK
               SELECT 1 FROM user_indexes i
                WHERE i.table_name = f.hija
                  AND NOT EXISTS (
                      SELECT 1 FROM user_cons_columns cc
                       WHERE cc.constraint_name = f.fk
                         AND NOT EXISTS (
                             SELECT 1 FROM user_ind_columns ic
                              WHERE ic.index_name = i.index_name
                                AND ic.column_name = cc.column_name
                                AND ic.column_position = cc.position)))
            THEN 'SI' ELSE 'NO' END AS indexada,
       (SELECT t.num_rows FROM user_tables t WHERE t.table_name = f.hija) AS filas_hija
  FROM fks f
       )
 ORDER BY indexada, filas_hija DESC NULLS LAST, padre, hija;
"""


# ----------------------------------------------------------------------------------------------
def generar(destino: Path) -> tuple[list, dict]:
    modelo = cargar_modelo()
    catalogo = json.loads(CATALOGO.read_text(encoding="utf-8"))
    config_entidades = catalogo.get("entidades", {})
    mensajes = sorted(p for p in ENTRADA.rglob("*.xml"))
    if not mensajes:
        raise ErrorGeneracion("No hay mensajes en mensajes_entrada/")

    entidades, errores = [], []
    for ruta in mensajes:
        clave = str(ruta.relative_to(ENTRADA))
        try:
            entidades.append(construir_entidad(ruta, config_entidades.get(clave, {}), modelo))
        except ErrorGeneracion as ex:
            errores.append(str(ex))
    nombres = [e.procedimiento for e in entidades]
    for n in {n for n in nombres if nombres.count(n) > 1}:
        errores.append(f"Procedimiento duplicado {n}: definir 'nombre' distinto en catalogo.json")
    if errores:
        raise ErrorGeneracion("\n".join(errores))

    spec, body, manifiesto = emitir_paquete(entidades, catalogo.get("variaciones", []), modelo)
    if destino.exists():
        shutil.rmtree(destino)
    destino.mkdir(parents=True)
    (destino / "pkg_sint.pks").write_text(spec, encoding="utf-8")
    (destino / "pkg_sint.pkb").write_text(body, encoding="utf-8")
    (destino.parent / "diagnostico_borrado.sql").write_text(emitir_diagnostico(manifiesto), encoding="utf-8")
    (destino / "manifiesto.json").write_text(json.dumps(manifiesto, ensure_ascii=False, indent=2) + "\n",
                                             encoding="utf-8")
    return entidades, manifiesto


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--comprobar", action="store_true", help="Sólo comprueba que plsql/generado está al día")
    args = p.parse_args()
    try:
        if args.comprobar:
            import filecmp
            import tempfile
            with tempfile.TemporaryDirectory() as tmp:
                nuevo = Path(tmp) / "generado"
                generar(nuevo)
                c = filecmp.dircmp(nuevo, SALIDA) if SALIDA.exists() else None
                if c is None or c.left_only or c.right_only or any(
                        not filecmp.cmp(nuevo / f, SALIDA / f, shallow=False) for f in c.common_files):
                    print("plsql/generado NO está al día: ejecuta python3 herramientas/generar_plsql.py")
                    return 1
            print("plsql/generado está al día.")
            return 0
        entidades, manifiesto = generar(SALIDA)
    except ErrorGeneracion as ex:
        print(f"ERROR: no se puede generar (falta información):\n{ex}", file=sys.stderr)
        return 1
    for e in sorted(entidades, key=lambda x: (x.unidad, x.nombre)):
        print(f"{e.unidad:<6} {e.procedimiento:<32} {len(e.filas):>4} filas/entidad  {e.mensaje}")
        for a in e.avisos:
            print(f"   aviso: {a}")
    lineas = manifiesto["lineas_cuerpo"]
    print(f"Generado plsql/generado/pkg_sint.pks/.pkb: {len(entidades)} entidad(es), {lineas} líneas de cuerpo.")
    if lineas > MAX_LINEAS_AVISO:
        print(f"AVISO: el cuerpo supera {MAX_LINEAS_AVISO} líneas; valorar separar el núcleo o compactar (D-023).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
