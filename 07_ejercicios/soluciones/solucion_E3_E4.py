#!/usr/bin/env python3
"""Soluciones de los ejercicios de Spark (ver ../ejercicios.md).

E3: cuenta los rechazados de editions por motivo, leyendo el Parquet de rechazados.
E4: muestra la regla nueva que se añade a limpiar_ediciones() en 01_raw_a_clean.py.
"""

import sys
from pathlib import Path

from pyspark.sql import functions as F

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "03_limpieza_spark"))
from common import RECHAZADOS, crear_sesion  # noqa: E402


def e3():
    spark = crear_sesion("e3-rechazados")
    (
        spark.read.parquet(f"{RECHAZADOS}/editions")
        .groupBy("motivo").count()
        .orderBy(F.desc("count"))
        .show(truncate=False)
    )
    spark.stop()


# E4: añadir esta regla a la lista de reglas de limpiar_ediciones(), dentro de validar(...):
#
#     ("anio_implausible",
#      F.col("anio_publicacion").isNotNull()
#      & ((F.col("anio_publicacion") < 1450) | (F.col("anio_publicacion") > 2100))),
#
# Como anio_publicacion se calcula en el select posterior, la regla debe ir
# después de calcularlo: la forma limpia es extraer el año antes de validar, con
#     df = df.withColumn("anio_publicacion", anio_de("j.publish_date"))
# y luego validar. Ejecutar: python3 01_raw_a_clean.py --tipos editions

if __name__ == "__main__":
    e3()
