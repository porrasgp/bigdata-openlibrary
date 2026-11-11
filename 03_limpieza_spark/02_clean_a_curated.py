#!/usr/bin/env python3
"""Semana 2 · Paso 2: clean -> curated (modelo normalizado).

Convierte las tablas limpias (una fila por registro del dump) en tablas
relacionales: obras, autores, ediciones y las tablas intermedias de
relaciones muchos a muchos. Este es el modelo que cargamos en PostgreSQL
en la semana 3 (ver 04_modelado/ddl_normalizado.sql).

Integridad referencial en Spark (no existe FK en Parquet):
  - FK obligatoria (ej. obra_autor.clave_autor): si el destino no existe,
    la fila se manda a RECHAZADOS.
  - FK opcional (ej. edicion.clave_obra): si el destino no existe,
    el valor se pone en null y se cuenta.

Decisiones que conviene discutir con los alumnos:
  - Una edición puede apuntar a varias obras; nos quedamos con la primera.
  - Una edición puede tener varios ISBN; nos quedamos con el primero.
  - Los temas de las ediciones no se usan; solo los de las obras.
  - editorial_id y tema_id se generan con dense_rank: son estables, pero
    en el dump completo esa ventana usa una sola partición (ver README).

Uso:
  python3 02_clean_a_curated.py
"""

import time

from pyspark.sql import functions as F
from pyspark.sql.window import Window

from common import CLEAN, CURATED, RECHAZADOS, crear_sesion


def leer(spark, nombre):
    return spark.read.parquet(f"{CLEAN}/{nombre}")


def claves(df, columna):
    """Lista distinta de claves con el nombre _ref, para unir."""
    return df.select(F.col(columna).alias("_ref")).distinct()


def exigir_fk(df, columna, referencia, columna_ref, nombre):
    """FK obligatoria: conserva las filas con destino existente. Las demás van a RECHAZADOS."""
    ref = claves(referencia, columna_ref)
    cumple = df.join(ref, F.col(columna) == F.col("_ref"), "left_semi")
    fallan = df.join(ref, F.col(columna) == F.col("_ref"), "left_anti")

    n_fallan = fallan.count()
    print(f"   FK {nombre}.{columna}: {n_fallan} filas sin destino -> rechazadas", flush=True)
    if n_fallan:
        fallan.withColumn("motivo", F.lit(f"fk_inexistente:{columna}")) \
            .write.mode("overwrite").parquet(f"{RECHAZADOS}/curated/{nombre}_{columna}")
    return cumple


def anular_fk(df, columna, referencia, columna_ref, nombre):
    """FK opcional: si el destino no existe, la columna queda en null."""
    ref = claves(referencia, columna_ref)
    unido = df.join(ref, F.col(columna) == F.col("_ref"), "left")
    n_anuladas = unido.filter(F.col(columna).isNotNull() & F.col("_ref").isNull()).count()
    print(f"   FK opcional {nombre}.{columna}: {n_anuladas} valores puestos a null", flush=True)
    return unido.withColumn(
        columna, F.when(F.col("_ref").isNull(), F.lit(None)).otherwise(F.col(columna))
    ).drop("_ref")


def con_id_denso(df, columna, nombre_id):
    """Asigna un id entero estable (1, 2, 3...) ordenando por el nombre."""
    ventana = Window.orderBy(columna)  # una sola partición: ver nota en el README
    return df.withColumn(nombre_id, F.dense_rank().over(ventana))


def nombres_no_vacios(df, columna):
    return df.filter(F.col(columna).isNotNull() & (F.trim(F.col(columna)) != ""))


def main():
    inicio = time.time()
    spark = crear_sesion("ol-clean-a-curated")
    tablas = {}

    ed = leer(spark, "editions")
    wk = leer(spark, "works")
    au = leer(spark, "authors")
    rt = leer(spark, "ratings")
    lg = leer(spark, "reading_log")

    # ----- entidades principales
    obra = wk.select(
        F.col("clave").alias("clave_obra"),
        "titulo", "subtitulo", "anio_primera_publicacion", "num_portadas", "descripcion",
    )
    tablas["obra"] = obra

    autor = au.select(
        F.col("clave").alias("clave_autor"),
        "nombre", "nombre_personal", "fecha_nacimiento", "fecha_muerte",
    )
    tablas["autor"] = autor

    # Base de ediciones: conserva las listas para construir las relaciones.
    # Se descartan al final (ver columnas de tablas["edicion"]).
    # Los nombres se recortan antes de deduplicar: "Editorial X " y "Editorial X"
    # son el mismo valor para una persona, y la UNIQUE de PostgreSQL los trataría distinto.
    ed_base = ed.select(
        F.col("clave").alias("clave_edicion"),
        F.try_element_at("obras_claves", F.lit(1)).alias("clave_obra"),
        "titulo", "subtitulo", "fecha_publicacion", "anio_publicacion",
        (F.floor(F.col("anio_publicacion") / 10) * 10).cast("int").alias("decada"),
        F.col("paginas"), F.col("formato_fisico"), F.col("num_portadas"),
        F.try_element_at("isbn_10", F.lit(1)).alias("isbn_10"),
        F.try_element_at("isbn_13", F.lit(1)).alias("isbn_13"),
        F.array_distinct(F.transform(F.col("editoriales"), lambda x: F.trim(x))).alias("editoriales"),
        "idiomas", "autores_claves",
    )

    # ----- relaciones N:M
    obra_autor = (
        wk.select(F.col("clave").alias("clave_obra"),
                  F.explode("autores_claves").alias("clave_autor"))
        .distinct()
    )
    obra_autor = exigir_fk(obra_autor, "clave_obra", obra, "clave_obra", "obra_autor")
    obra_autor = exigir_fk(obra_autor, "clave_autor", autor, "clave_autor", "obra_autor")
    tablas["obra_autor"] = obra_autor

    edicion_autor = (
        ed_base.select("clave_edicion", F.explode("autores_claves").alias("clave_autor"))
        .distinct()
    )
    edicion_autor = exigir_fk(edicion_autor, "clave_autor", autor, "clave_autor", "edicion_autor")
    tablas["edicion_autor"] = edicion_autor

    editorial = con_id_denso(
        nombres_no_vacios(
            ed_base.select(F.explode("editoriales").alias("nombre")).distinct(), "nombre"),
        "nombre", "editorial_id",
    ).cache()
    tablas["editorial"] = editorial.select("editorial_id", "nombre")

    edicion_editorial = (
        ed_base.select("clave_edicion", F.explode("editoriales").alias("nombre"))
        .join(editorial, "nombre")
        .select("clave_edicion", "editorial_id")
        .distinct()
    )
    tablas["edicion_editorial"] = edicion_editorial

    idioma = nombres_no_vacios(
        ed_base.select(F.explode("idiomas").alias("codigo")).distinct(), "codigo")
    tablas["idioma"] = idioma

    edicion_idioma = (
        ed_base.select("clave_edicion", F.explode("idiomas").alias("codigo"))
        .filter(F.col("codigo") != "")
        .distinct()
    )
    tablas["edicion_idioma"] = edicion_idioma

    # Temas de las obras, recortados igual que las editoriales
    obra_temas = wk.select(
        F.col("clave").alias("clave_obra"),
        F.array_distinct(F.transform(F.col("temas"), lambda x: F.trim(x))).alias("temas"),
    )
    tema = con_id_denso(
        nombres_no_vacios(
            obra_temas.select(F.explode("temas").alias("nombre")).distinct(), "nombre"),
        "nombre", "tema_id",
    ).cache()
    tablas["tema"] = tema.select("tema_id", "nombre")

    obra_tema = (
        obra_temas.select("clave_obra", F.explode("temas").alias("nombre"))
        .join(tema, "nombre")
        .select("clave_obra", "tema_id")
        .distinct()
    )
    obra_tema = exigir_fk(obra_tema, "clave_obra", obra, "clave_obra", "obra_tema")
    tablas["obra_tema"] = obra_tema

    # ----- tabla principal de ediciones (sin las listas)
    edicion = anular_fk(ed_base, "clave_obra", obra, "clave_obra", "edicion")
    tablas["edicion"] = edicion.select(
        "clave_edicion", "clave_obra", "titulo", "subtitulo", "fecha_publicacion",
        "anio_publicacion", "decada", "paginas", "formato_fisico", "num_portadas",
        "isbn_10", "isbn_13",
    )

    # ----- hechos: valoraciones y lectura
    valoracion = exigir_fk(rt, "obra_clave", obra, "clave_obra", "valoracion")
    valoracion = anular_fk(valoracion, "edicion_clave", tablas["edicion"], "clave_edicion", "valoracion")
    tablas["valoracion"] = valoracion.select("obra_clave", "edicion_clave", "valor", "fecha")

    lectura = exigir_fk(lg, "obra_clave", obra, "clave_obra", "lectura")
    lectura = anular_fk(lectura, "edicion_clave", tablas["edicion"], "clave_edicion", "lectura")
    tablas["lectura"] = lectura.select("obra_clave", "edicion_clave", "estado", "fecha")

    # Nombres de salida: la tabla de hechos usa 'obra_clave' en vez de 'clave_obra'
    # para que el modelo quede claro al leerlo en PostgreSQL.
    tablas["valoracion"] = tablas["valoracion"].withColumnRenamed("obra_clave", "clave_obra") \
        .withColumnRenamed("edicion_clave", "clave_edicion")
    tablas["lectura"] = tablas["lectura"].withColumnRenamed("obra_clave", "clave_obra") \
        .withColumnRenamed("edicion_clave", "clave_edicion")

    # ----- escritura
    for nombre, df in tablas.items():
        ruta = f"{CURATED}/{nombre}"
        escritor = df.write.mode("overwrite")
        if nombre == "edicion":
            escritor = escritor.partitionBy("decada")  # ver 03_comparar_particionado.py
        escritor.parquet(ruta)
        print(f">> {nombre}: {spark.read.parquet(ruta).count()} filas", flush=True)

    print(f"Listo en {time.time() - inicio:.0f} s", flush=True)
    spark.stop()


if __name__ == "__main__":
    main()
