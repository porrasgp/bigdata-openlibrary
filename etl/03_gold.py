#!/usr/bin/env python3
"""Gold: modelo estrella listo para análisis, en CSV.

Tablas generadas en data/gold:
    dim_obra.csv                 una fila por obra (con clave sustituta)
    dim_fecha.csv                calendario continuo entre la primera y última fecha
    fact_valoracion.csv          una valoración por fila
    fact_lectura.csv             un cambio de estado de lectura por fila
    resumen_valoraciones_anio.csv  ejemplo de agregación "lista para usar"

Uso: python3 etl/03_gold.py
"""

import time

from pyspark.sql import functions as F
from pyspark.sql.window import Window

from common import GOLD, SILVER, crear_sesion, escribir_csv, leer_csv


def main():
    inicio = time.time()
    spark = crear_sesion("ol-gold")

    # Al leer CSV todo vuelve como texto: convertimos los tipos que usa el modelo.
    obras = leer_csv(spark, SILVER, "works").withColumn(
        "anio_primera_publicacion", F.expr("try_cast(anio_primera_publicacion as int)")
    ).withColumn("num_portadas", F.expr("try_cast(num_portadas as int)"))
    valoracion = leer_csv(spark, SILVER, "ratings").withColumn(
        "fecha", F.to_date("fecha")
    ).withColumn("valor", F.expr("try_cast(valor as int)"))
    lectura = leer_csv(spark, SILVER, "reading_log").withColumn(
        "fecha", F.to_date("fecha")
    )

    print("== Gold: modelo estrella", flush=True)

    # ----- dimensión de obra: clave sustituta estable y ordenada
    dim_obra = (
        obras.select(
            F.col("clave").alias("clave_obra"),
            "titulo",
            "anio_primera_publicacion",
            F.coalesce(F.col("num_portadas"), F.lit(0)).alias("num_portadas"),
        )
        .withColumn("obra_sk", F.row_number().over(Window.orderBy("clave_obra")).cast("int"))
        .select("obra_sk", "clave_obra", "titulo", "anio_primera_publicacion", "num_portadas")
    )

    # ----- dimensión de fecha: un día por fila, desde la min hasta la max de los hechos
    fechas = (
        valoracion.select("fecha")
        .unionByName(lectura.select("fecha"))
        .filter(F.col("fecha").isNotNull())
        .distinct()
    )
    rango = fechas.agg(F.min("fecha").alias("desde"), F.max("fecha").alias("hasta"))
    dim_fecha = (
        rango.filter(F.col("desde").isNotNull())
        .selectExpr("explode(sequence(desde, hasta, interval 1 day)) AS fecha")
        .select(
            "fecha",
            F.year("fecha").alias("anio"),
            F.quarter("fecha").alias("trimestre"),
            F.month("fecha").alias("mes"),
            F.dayofmonth("fecha").alias("dia"),
            (F.floor(F.year("fecha") / 10) * 10).cast("int").alias("decada"),
        )
    )

    # ----- tablas de hechos: unen cada evento con su obra
    o = dim_obra.alias("o")
    v = valoracion.alias("v")
    l = lectura.alias("l")

    fact_valoracion = (
        v.join(o, F.col("v.obra_clave") == F.col("o.clave_obra"), "inner")
        .select(
            F.col("v.fecha").alias("fecha"),
            F.col("o.obra_sk").alias("obra_sk"),
            F.col("v.valor").alias("valor"),
        )
    )
    fact_lectura = (
        l.join(o, F.col("l.obra_clave") == F.col("o.clave_obra"), "inner")
        .select(
            F.col("l.fecha").alias("fecha"),
            F.col("o.obra_sk").alias("obra_sk"),
            F.col("l.estado").alias("estado"),
        )
    )

    # ----- ejemplo de tabla agregada: ya está lista para graficar
    resumen = (
        fact_valoracion.groupBy(F.year("fecha").alias("anio"))
        .agg(
            F.count(F.lit(1)).alias("valoraciones"),
            F.round(F.avg("valor"), 2).alias("valor_promedio"),
        )
        .orderBy("anio")
    )

    tablas = {
        "dim_obra": dim_obra,
        "dim_fecha": dim_fecha,
        "fact_valoracion": fact_valoracion,
        "fact_lectura": fact_lectura,
        "resumen_valoraciones_anio": resumen,
    }
    for nombre, df in tablas.items():
        filas = df.count()
        escribir_csv(df, GOLD, nombre)
        print(f">> {nombre}: {filas} filas ({time.time() - inicio:.0f} s acumulados)", flush=True)

    spark.stop()
    print(f"Gold listo en {time.time() - inicio:.0f} s.", flush=True)


if __name__ == "__main__":
    main()
