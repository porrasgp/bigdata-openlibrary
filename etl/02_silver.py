#!/usr/bin/env python3
"""Silver: limpieza, validación y deduplicación de los CSV bronze.

Reglas aplicadas:
    - clave con el formato esperado (/books/OL...M, /works/OL...W, ...)
    - revisión numérica >= 1 y título/nombre no vacío
    - una sola fila por clave: gana la revisión más alta
    - fechas y números convertidos a su tipo
    - valoraciones entre 1 y 5
    - las filas que fallan se guardan en data/silver/_rechazados/

Uso: python3 etl/02_silver.py
"""

import shutil
import time

from pyspark.sql import functions as F
from pyspark.sql.window import Window

from common import BRONZE, SILVER, crear_sesion, escribir_csv, leer_csv


# ---------------------------------------------------------------- utilidades

def anio_de(columna):
    """Primer año de 4 dígitos (1500-2099) dentro de un texto, o null."""
    return F.expr(
        f"try_cast(nullif(regexp_extract({columna}, '((?:1[5-9]|20)[0-9]{{2}})', 1), '') as int)"
    )


def nulo_si_vacio(columna):
    """Recorta espacios y convierte la cadena vacía en null."""
    return F.when(F.trim(F.coalesce(columna, F.lit(""))) == "", F.lit(None)).otherwise(
        F.trim(columna)
    )


def validar(df, reglas):
    """Añade 'motivo' con el primer error encontrado (null si la fila es válida)."""
    motivo = F.lit(None).cast("string")
    for nombre, condicion in reversed(reglas):
        motivo = F.when(condicion, F.lit(nombre)).otherwise(motivo)
    return df.withColumn("motivo", motivo)


def ultima_revision(df):
    """Una fila por clave: la de mayor revisión (y última modificación)."""
    ventana = Window.partitionBy("clave").orderBy(
        F.col("revision").desc(), F.col("ultima_modificacion").desc_nulls_last()
    )
    return (
        df.withColumn("_fila", F.row_number().over(ventana))
        .filter(F.col("_fila") == 1)
        .drop("_fila")
    )


# ---------------------------------------------------------------- limpieza

def limpiar_autores(spark):
    df = leer_csv(spark, BRONZE, "authors")
    df = validar(df, [
        ("clave_invalida", F.coalesce(~F.col("clave").rlike(r"^/authors/OL\d+A$"), F.lit(True))),
        ("revision_invalida", F.coalesce(F.expr("try_cast(revision as int)") < 1, F.lit(True))),
        ("nombre_vacio", F.coalesce(F.trim(F.col("nombre")) == "", F.lit(True))),
    ])
    limpio = df.filter(F.col("motivo").isNull()).select(
        "clave",
        F.expr("try_cast(revision as int)").alias("revision"),
        F.expr("try_cast(ultima_modificacion as timestamp)").alias("ultima_modificacion"),
        F.trim("nombre").alias("nombre"),
        nulo_si_vacio(F.col("nombre_personal")).alias("nombre_personal"),
        nulo_si_vacio(F.col("fecha_nacimiento")).alias("fecha_nacimiento"),
        nulo_si_vacio(F.col("fecha_muerte")).alias("fecha_muerte"),
        nulo_si_vacio(F.col("nombres_alternativos")).alias("nombres_alternativos"),
    )
    return ultima_revision(limpio), df.filter(F.col("motivo").isNotNull())


def limpiar_obras(spark):
    df = leer_csv(spark, BRONZE, "works")
    df = validar(df, [
        ("clave_invalida", F.coalesce(~F.col("clave").rlike(r"^/works/OL\d+W$"), F.lit(True))),
        ("revision_invalida", F.coalesce(F.expr("try_cast(revision as int)") < 1, F.lit(True))),
        ("titulo_vacio", F.coalesce(F.trim(F.col("titulo")) == "", F.lit(True))),
    ])
    limpio = df.filter(F.col("motivo").isNull()).select(
        "clave",
        F.expr("try_cast(revision as int)").alias("revision"),
        F.expr("try_cast(ultima_modificacion as timestamp)").alias("ultima_modificacion"),
        F.trim("titulo").alias("titulo"),
        nulo_si_vacio(F.col("subtitulo")).alias("subtitulo"),
        anio_de("fecha_primera_publicacion").alias("anio_primera_publicacion"),
        nulo_si_vacio(F.col("autores_claves")).alias("autores_claves"),
        nulo_si_vacio(F.col("temas")).alias("temas"),
        F.expr("try_cast(num_portadas as int)").alias("num_portadas"),
        "descripcion",
    )
    return ultima_revision(limpio), df.filter(F.col("motivo").isNotNull())


def limpiar_ediciones(spark):
    df = leer_csv(spark, BRONZE, "editions")
    df = validar(df, [
        ("clave_invalida", F.coalesce(~F.col("clave").rlike(r"^/books/OL\d+M$"), F.lit(True))),
        ("revision_invalida", F.coalesce(F.expr("try_cast(revision as int)") < 1, F.lit(True))),
        ("titulo_vacio", F.coalesce(F.trim(F.col("titulo")) == "", F.lit(True))),
    ])
    limpio = df.filter(F.col("motivo").isNull()).select(
        "clave",
        F.expr("try_cast(revision as int)").alias("revision"),
        F.expr("try_cast(ultima_modificacion as timestamp)").alias("ultima_modificacion"),
        F.trim("titulo").alias("titulo"),
        nulo_si_vacio(F.col("subtitulo")).alias("subtitulo"),
        nulo_si_vacio(F.col("fecha_publicacion")).alias("fecha_publicacion"),
        anio_de("fecha_publicacion").alias("anio_publicacion"),
        nulo_si_vacio(F.col("editoriales")).alias("editoriales"),
        nulo_si_vacio(F.col("isbn_10")).alias("isbn_10"),
        nulo_si_vacio(F.col("isbn_13")).alias("isbn_13"),
        F.expr("try_cast(paginas as int)").alias("paginas"),
        nulo_si_vacio(F.col("formato_fisico")).alias("formato_fisico"),
        nulo_si_vacio(F.col("idiomas")).alias("idiomas"),
        nulo_si_vacio(F.col("autores_claves")).alias("autores_claves"),
        nulo_si_vacio(F.col("obras_claves")).alias("obras_claves"),
        F.expr("try_cast(num_portadas as int)").alias("num_portadas"),
    )
    return ultima_revision(limpio), df.filter(F.col("motivo").isNotNull())


def limpiar_valoraciones(spark):
    df = leer_csv(spark, BRONZE, "ratings")
    df = validar(df, [
        ("obra_invalida", F.coalesce(~F.col("obra_clave").rlike(r"^/works/OL\d+W$"), F.lit(True))),
        ("edicion_invalida", F.col("edicion_clave").isNotNull()
         & ~F.col("edicion_clave").rlike(r"^/books/OL\d+M$")),
        ("valor_fuera_de_rango", F.coalesce(
            ~F.expr("try_cast(valoracion as int) between 1 and 5"), F.lit(True))),
        ("fecha_invalida", F.expr("try_cast(fecha as date)").isNull()),
    ])
    limpio = df.filter(F.col("motivo").isNull()).select(
        nulo_si_vacio(F.col("obra_clave")).alias("obra_clave"),
        nulo_si_vacio(F.col("edicion_clave")).alias("edicion_clave"),
        F.expr("try_cast(valoracion as int)").alias("valor"),
        F.expr("try_cast(fecha as date)").alias("fecha"),
    )
    return limpio, df.filter(F.col("motivo").isNotNull())


def limpiar_lectura(spark):
    df = leer_csv(spark, BRONZE, "reading-log")
    df = validar(df, [
        ("obra_invalida", F.coalesce(~F.col("obra_clave").rlike(r"^/works/OL\d+W$"), F.lit(True))),
        ("edicion_invalida", F.col("edicion_clave").isNotNull()
         & ~F.col("edicion_clave").rlike(r"^/books/OL\d+M$")),
        ("estado_vacio", F.coalesce(F.trim(F.col("estado")) == "", F.lit(True))),
        ("fecha_invalida", F.expr("try_cast(fecha as date)").isNull()),
    ])
    limpio = df.filter(F.col("motivo").isNull()).select(
        nulo_si_vacio(F.col("obra_clave")).alias("obra_clave"),
        nulo_si_vacio(F.col("edicion_clave")).alias("edicion_clave"),
        F.trim("estado").alias("estado"),
        F.expr("try_cast(fecha as date)").alias("fecha"),
    )
    return limpio, df.filter(F.col("motivo").isNotNull())


# ---------------------------------------------------------------- main

def main():
    inicio = time.time()
    spark = crear_sesion("ol-silver")
    trabajos = {
        "authors": limpiar_autores,
        "works": limpiar_obras,
        "editions": limpiar_ediciones,
        "ratings": limpiar_valoraciones,
        "reading-log": limpiar_lectura,
    }
    nombres = {
        "authors": "authors", "works": "works", "editions": "editions",
        "ratings": "ratings", "reading-log": "reading_log",
    }

    # Empezamos sin rechazos: si una ejecución anterior generó archivos, se borran.
    rechazados_dir = SILVER / "_rechazados"
    if rechazados_dir.exists():
        shutil.rmtree(rechazados_dir)
    rechazados_dir.mkdir(parents=True, exist_ok=True)

    print("== Silver: limpieza y validación", flush=True)
    for tipo, funcion in trabajos.items():
        print(f">> {tipo}", flush=True)
        limpio, rechazados = funcion(spark)
        rechazados = rechazados.cache()

        total = rechazados.count()
        print(f"   rechazados: {total}", flush=True)
        if total:
            for fila in rechazados.groupBy("motivo").count().orderBy(F.desc("count")).collect():
                print(f"     - {fila['motivo']}: {fila['count']}", flush=True)
            escribir_csv(
                rechazados.withColumn("tipo", F.lit(tipo)),
                SILVER / "_rechazados", nombres[tipo],
            )

        filas = limpio.count()
        escribir_csv(limpio, SILVER, nombres[tipo])
        print(f"   limpio: {filas} filas ({time.time() - inicio:.0f} s acumulados)", flush=True)
        rechazados.unpersist()

    spark.stop()
    print(f"Silver listo en {time.time() - inicio:.0f} s.", flush=True)


if __name__ == "__main__":
    main()
