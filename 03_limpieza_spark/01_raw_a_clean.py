#!/usr/bin/env python3
"""Semana 2 · Paso 1: raw -> clean.

1. Lee cada dump de RAW como texto y separa las columnas por tabulador.
2. Parsea el JSON (editions, works, authors) con un esquema explícito.
3. Valida cada registro. Los que fallan van a RECHAZADOS con el motivo.
4. Deduplica por clave: si una obra aparece varias veces, gana la última revisión.
5. Guarda el resultado en CLEAN como Parquet, una carpeta por tipo.

Uso:
  python3 01_raw_a_clean.py                      # todos los tipos
  python3 01_raw_a_clean.py --tipos editions     # solo uno
"""

import argparse
import time

from pyspark.sql import functions as F
from pyspark.sql.types import (
    ArrayType,
    IntegerType,
    StringType,
    StructField,
    StructType,
)
from pyspark.sql.window import Window

from common import (
    CLEAN,
    PARTICIONES,
    PATRON_ARCHIVO,
    RAW,
    RECHAZADOS,
    crear_sesion,
)

TIPOS = ["editions", "works", "authors", "ratings", "reading-log"]

# Número de columnas de cada tipo de dump (separadas por tabulador)
COLUMNAS_ORIGEN = {"editions": 5, "works": 5, "authors": 5, "ratings": 4, "reading-log": 4}

# Patrón esperado de las claves
PATRON_CLAVE = {
    "editions": r"^/books/OL\d+M$",
    "works": r"^/works/OL\d+W$",
    "authors": r"^/authors/OL\d+A$",
}

# Esquemas de los JSON. Solo los campos que usamos; el resto se ignora.
# Un campo con tipo distinto al esquema queda en null, no tumba el registro.
LLAVE = StructType([StructField("key", StringType())])

ESQUEMA_EDICION = StructType([
    StructField("title", StringType()),
    StructField("subtitle", StringType()),
    StructField("publish_date", StringType()),
    StructField("publishers", ArrayType(StringType())),
    StructField("isbn_10", ArrayType(StringType())),
    StructField("isbn_13", ArrayType(StringType())),
    StructField("number_of_pages", IntegerType()),
    StructField("physical_format", StringType()),
    StructField("languages", ArrayType(LLAVE)),
    StructField("authors", ArrayType(LLAVE)),
    StructField("works", ArrayType(LLAVE)),
    StructField("covers", ArrayType(IntegerType())),
])

ESQUEMA_OBRA = StructType([
    StructField("title", StringType()),
    StructField("subtitle", StringType()),
    StructField("first_publish_date", StringType()),
    StructField("authors", ArrayType(StructType([
        StructField("author", LLAVE),
    ]))),
    StructField("subjects", ArrayType(StringType())),
    StructField("covers", ArrayType(IntegerType())),
])

ESQUEMA_AUTOR = StructType([
    StructField("name", StringType()),
    StructField("personal_name", StringType()),
    StructField("birth_date", StringType()),
    StructField("death_date", StringType()),
    StructField("alternate_names", ArrayType(StringType())),
])


# ---------------------------------------------------------------- utilidades

def campo(columna_array, posicion):
    """Elemento de un array de texto (posición 1 = primero). Devuelve null si no existe.

    try_element_at evita errores en modo ANSI (activo por defecto en Spark 4)
    cuando una línea tiene menos columnas de las esperadas.
    """
    return F.try_element_at(columna_array, F.lit(posicion))


def anio_de(columna):
    """Primer año de 4 dígitos (1500-2099) dentro de un texto, o null.

    Ejemplos: 'February 27, 1997' -> 1997, 'circa 1900' -> 1900, '' -> null.
    """
    return F.expr(
        f"try_cast(nullif(regexp_extract({columna}, '((?:1[5-9]|20)[0-9]{{2}})', 1), '') as int)"
    )


def fecha_de(columna):
    """Fecha ISO (AAAA-MM-DD) o null si no se puede leer."""
    return F.expr(f"try_cast({columna} as date)")


def validar(df, reglas):
    """Añade la columna 'motivo' con el primer error encontrado (null si el registro es válido).

    reglas: lista de (nombre_motivo, condicion_de_error) en orden de prioridad.
    Si la condición da null (dato ausente), se trata como error solo si se
    escribe con coalesce(..., True) en la propia regla.
    """
    motivo = F.lit(None).cast("string")
    for nombre, condicion in reversed(reglas):
        motivo = F.when(condicion, F.lit(nombre)).otherwise(motivo)
    return df.withColumn("motivo", motivo)


def ultima_revision(df):
    """Una fila por clave: la de mayor revisión (y, si empata, la modificada más tarde)."""
    ventana = Window.partitionBy("clave").orderBy(
        F.col("revision").desc(), F.col("ultima_modificacion").desc_nulls_last()
    )
    return (
        df.withColumn("_fila", F.row_number().over(ventana))
        .filter(F.col("_fila") == 1)
        .drop("_fila")
    )


# ---------------------------------------------------------------- lectura

def leer_lineas(spark, tipo):
    """Lee el dump como texto y separa en columnas. Cada fila tiene 'linea' y 'partes'."""
    # pathGlobFilter filtra por nombre dentro de la carpeta (evita rutas con comodín)
    texto = (
        spark.read.option("pathGlobFilter", PATRON_ARCHIVO[tipo])
        .text(RAW)
        .repartition(PARTICIONES)  # un .gz no es divisible: repartir tras leer
    )
    return (
        texto.select(
            F.col("value").alias("linea"),
            F.split(F.col("value"), "\t", COLUMNAS_ORIGEN[tipo]).alias("partes"),
        )
        .withColumn("n_columnas", F.size("partes"))
    )


# ---------------------------------------------------------------- por tipo

def limpiar_ediciones(spark):
    lineas = leer_lineas(spark, "editions")
    p = F.col("partes")
    df = lineas.select(
        "linea", "n_columnas",
        campo(p, 2).alias("clave"),
        campo(p, 3).alias("revision_txt"),
        campo(p, 4).alias("modificado_txt"),
        F.from_json(campo(p, 5), ESQUEMA_EDICION).alias("j"),
    )
    df = validar(df, [
        ("linea_malformada", F.col("n_columnas") != 5),
        ("clave_invalida", F.coalesce(~F.col("clave").rlike(PATRON_CLAVE["editions"]), F.lit(True))),
        ("json_invalido", F.col("j").isNull()),
        ("revision_invalida", F.coalesce(F.expr("try_cast(revision_txt as int)") < 1, F.lit(True))),
        ("titulo_vacio", F.coalesce(F.trim(F.col("j.title")) == "", F.lit(True))),
    ])
    validos = df.filter(F.col("motivo").isNull())
    rechazados = df.filter(F.col("motivo").isNotNull()).select("motivo", "linea")

    j = F.col("j")
    limpio = validos.select(
        F.col("clave"),
        F.expr("try_cast(revision_txt as int)").alias("revision"),
        F.expr("try_cast(modificado_txt as timestamp)").alias("ultima_modificacion"),
        F.col("j.title").alias("titulo"),
        F.col("j.subtitle").alias("subtitulo"),
        F.col("j.publish_date").alias("fecha_publicacion"),
        anio_de("j.publish_date").alias("anio_publicacion"),
        F.col("j.number_of_pages").alias("paginas"),
        F.col("j.physical_format").alias("formato_fisico"),
        F.size(F.coalesce(j["covers"], F.array())).alias("num_portadas"),
        F.coalesce(j["publishers"], F.array()).alias("editoriales"),
        F.coalesce(j["isbn_10"], F.array()).alias("isbn_10"),
        F.coalesce(j["isbn_13"], F.array()).alias("isbn_13"),
        # "/languages/eng" -> "eng"
        F.transform(F.coalesce(j["languages"], F.array()),
                    lambda x: F.regexp_extract(x["key"], r"/languages/(\w+)", 1)).alias("idiomas"),
        F.array_compact(F.transform(F.coalesce(j["authors"], F.array()), lambda x: x["key"])).alias("autores_claves"),
        F.array_compact(F.transform(F.coalesce(j["works"], F.array()), lambda x: x["key"])).alias("obras_claves"),
    )
    return ultima_revision(limpio), rechazados


def limpiar_obras(spark):
    lineas = leer_lineas(spark, "works")
    p = F.col("partes")
    df = lineas.select(
        "linea", "n_columnas",
        campo(p, 2).alias("clave"),
        campo(p, 3).alias("revision_txt"),
        campo(p, 4).alias("modificado_txt"),
        campo(p, 5).alias("json_txt"),
        F.from_json(campo(p, 5), ESQUEMA_OBRA).alias("j"),
    )
    df = validar(df, [
        ("linea_malformada", F.col("n_columnas") != 5),
        ("clave_invalida", F.coalesce(~F.col("clave").rlike(PATRON_CLAVE["works"]), F.lit(True))),
        ("json_invalido", F.col("j").isNull()),
        ("revision_invalida", F.coalesce(F.expr("try_cast(revision_txt as int)") < 1, F.lit(True))),
        ("titulo_vacio", F.coalesce(F.trim(F.col("j.title")) == "", F.lit(True))),
    ])
    validos = df.filter(F.col("motivo").isNull())
    rechazados = df.filter(F.col("motivo").isNotNull()).select("motivo", "linea")

    j = F.col("j")
    # 'description' es a veces {"type": ..., "value": "..."} y a veces texto plano.
    # No lo tipamos en el esquema porque mezcla ambos formatos.
    descripcion = F.coalesce(
        F.get_json_object("json_txt", "$.description.value"),
        F.when(F.get_json_object("json_txt", "$.description").rlike("^[^{]"),
               F.get_json_object("json_txt", "$.description")),
    )
    limpio = validos.select(
        F.col("clave"),
        F.expr("try_cast(revision_txt as int)").alias("revision"),
        F.expr("try_cast(modificado_txt as timestamp)").alias("ultima_modificacion"),
        F.col("j.title").alias("titulo"),
        F.col("j.subtitle").alias("subtitulo"),
        F.col("j.first_publish_date").alias("primera_publicacion"),
        anio_de("j.first_publish_date").alias("anio_primera_publicacion"),
        F.array_compact(F.transform(F.coalesce(j["authors"], F.array()),
                                    lambda x: x["author"]["key"])).alias("autores_claves"),
        F.coalesce(j["subjects"], F.array()).alias("temas"),
        F.size(F.coalesce(j["covers"], F.array())).alias("num_portadas"),
        descripcion.alias("descripcion"),
    )
    return ultima_revision(limpio), rechazados


def limpiar_autores(spark):
    lineas = leer_lineas(spark, "authors")
    p = F.col("partes")
    df = lineas.select(
        "linea", "n_columnas",
        campo(p, 2).alias("clave"),
        campo(p, 3).alias("revision_txt"),
        campo(p, 4).alias("modificado_txt"),
        F.from_json(campo(p, 5), ESQUEMA_AUTOR).alias("j"),
    )
    df = validar(df, [
        ("linea_malformada", F.col("n_columnas") != 5),
        ("clave_invalida", F.coalesce(~F.col("clave").rlike(PATRON_CLAVE["authors"]), F.lit(True))),
        ("json_invalido", F.col("j").isNull()),
        ("revision_invalida", F.coalesce(F.expr("try_cast(revision_txt as int)") < 1, F.lit(True))),
        ("nombre_vacio", F.coalesce(F.trim(F.col("j.name")) == "", F.lit(True))),
    ])
    validos = df.filter(F.col("motivo").isNull())
    rechazados = df.filter(F.col("motivo").isNotNull()).select("motivo", "linea")

    limpio = validos.select(
        F.col("clave"),
        F.expr("try_cast(revision_txt as int)").alias("revision"),
        F.expr("try_cast(modificado_txt as timestamp)").alias("ultima_modificacion"),
        F.col("j.name").alias("nombre"),
        F.col("j.personal_name").alias("nombre_personal"),
        F.col("j.birth_date").alias("fecha_nacimiento"),
        F.col("j.death_date").alias("fecha_muerte"),
        F.coalesce(F.col("j.alternate_names"), F.array()).alias("nombres_alternativos"),
    )
    return ultima_revision(limpio), rechazados


def limpiar_valoraciones(spark):
    lineas = leer_lineas(spark, "ratings")
    p = F.col("partes")
    df = lineas.select(
        "linea", "n_columnas",
        nulo_si_vacio_arr(p, 1).alias("obra_clave"),
        nulo_si_vacio_arr(p, 2).alias("edicion_clave"),
        campo(p, 3).alias("valor_txt"),
        campo(p, 4).alias("fecha_txt"),
    )
    df = validar(df, [
        ("linea_malformada", F.col("n_columnas") != 4),
        ("obra_invalida", F.coalesce(~F.col("obra_clave").rlike(r"^/works/OL\d+W$"), F.lit(True))),
        ("edicion_invalida", F.col("edicion_clave").isNotNull() & ~F.col("edicion_clave").rlike(r"^/books/OL\d+M$")),
        ("valor_fuera_de_rango", F.coalesce(~F.expr("try_cast(valor_txt as int) between 1 and 5"), F.lit(True))),
        ("fecha_invalida", F.expr("try_cast(fecha_txt as date)").isNull()),
    ])
    validos = df.filter(F.col("motivo").isNull())
    rechazados = df.filter(F.col("motivo").isNotNull()).select("motivo", "linea")
    # Sin deduplicar: el dump no tiene usuario, así que dos valoraciones iguales pueden ser de personas distintas.
    limpio = validos.select(
        "obra_clave", "edicion_clave",
        F.expr("try_cast(valor_txt as int)").alias("valor"),
        F.expr("try_cast(fecha_txt as date)").alias("fecha"),
    )
    return limpio, rechazados


def limpiar_lectura(spark):
    lineas = leer_lineas(spark, "reading-log")
    p = F.col("partes")
    df = lineas.select(
        "linea", "n_columnas",
        nulo_si_vacio_arr(p, 1).alias("obra_clave"),
        nulo_si_vacio_arr(p, 2).alias("edicion_clave"),
        campo(p, 3).alias("estado"),
        campo(p, 4).alias("fecha_txt"),
    )
    df = validar(df, [
        ("linea_malformada", F.col("n_columnas") != 4),
        ("obra_invalida", F.coalesce(~F.col("obra_clave").rlike(r"^/works/OL\d+W$"), F.lit(True))),
        ("edicion_invalida", F.col("edicion_clave").isNotNull() & ~F.col("edicion_clave").rlike(r"^/books/OL\d+M$")),
        ("estado_vacio", F.coalesce(F.trim(F.col("estado")) == "", F.lit(True))),
        ("fecha_invalida", F.expr("try_cast(fecha_txt as date)").isNull()),
    ])
    validos = df.filter(F.col("motivo").isNull())
    rechazados = df.filter(F.col("motivo").isNotNull()).select("motivo", "linea")
    limpio = validos.select(
        "obra_clave", "edicion_clave", "estado",
        F.expr("try_cast(fecha_txt as date)").alias("fecha"),
    )
    return limpio, rechazados


def nulo_si_vacio_arr(array_col, posicion):
    """Igual que nulo_si_vacio, pero para una posición de un array."""
    valor = campo(array_col, posicion)
    return F.when(valor.isin("", "\\N"), F.lit(None)).otherwise(valor)


# ---------------------------------------------------------------- main

def guardar(df, nombre):
    ruta = f"{CLEAN}/{nombre}"
    df.write.mode("overwrite").parquet(ruta)
    return ruta


def main():
    ap = argparse.ArgumentParser(description="raw -> clean")
    ap.add_argument("--tipos", nargs="+", choices=TIPOS, default=TIPOS)
    args = ap.parse_args()

    spark = crear_sesion("ol-raw-a-clean")
    trabajos = {
        "editions": limpiar_ediciones,
        "works": limpiar_obras,
        "authors": limpiar_autores,
        "ratings": limpiar_valoraciones,
        "reading-log": limpiar_lectura,
    }
    nombres = {"editions": "editions", "works": "works", "authors": "authors",
               "ratings": "ratings", "reading-log": "reading_log"}

    for tipo in args.tipos:
        inicio = time.time()
        print(f">> {tipo}", flush=True)
        resultado = trabajos[tipo](spark)
        limpio, rechazados = resultado if isinstance(resultado, tuple) else (resultado, None)

        if rechazados is not None:
            rechazados = rechazados.withColumn("tipo", F.lit(tipo)).cache()
            # Cuenta por motivo: sirve para discutir la calidad de los datos
            conteo = rechazados.groupBy("motivo").count().orderBy(F.desc("count")).collect()
            total_rech = sum(r["count"] for r in conteo)
            print(f"   rechazados: {total_rech}", flush=True)
            for r in conteo:
                print(f"     - {r['motivo']}: {r['count']}", flush=True)
            rechazados.write.mode("overwrite").parquet(f"{RECHAZADOS}/{nombres[tipo]}")

        ruta = guardar(limpio, nombres[tipo])
        filas = spark.read.parquet(ruta).count()
        print(f"   limpio: {filas} filas -> {ruta} ({time.time() - inicio:.0f} s)", flush=True)

    spark.stop()


if __name__ == "__main__":
    main()
