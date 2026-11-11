#!/usr/bin/env python3
"""Semana 2 · Paso 3 (opcional): efecto del particionado en Spark.

Cuenta las ediciones de los años 2010 a 2019 de dos formas:
  A. Sobre 'clean/editions' (sin particionar): Spark lee todo y filtra después.
  B. Sobre 'curated/edicion' (particionado por 'decada'): Spark solo lee la
     carpeta decada=2010 y ni siquiera abre las demás.

Para cada caso imprime el tiempo medio de 3 ejecuciones y el plan. En el plan
de B busca la línea 'PartitionFilters': ahí está el filtro que hace que Spark
salte carpetas enteras (partition pruning).

Nota: con la muestra (1 500 ediciones) la diferencia es mínima; el efecto se
ve con el dataset completo, con millones de ediciones. Ver README.

Uso:
  python3 03_comparar_particionado.py
"""

import statistics
import time

from pyspark.sql import functions as F

from common import CLEAN, CURATED, crear_sesion


def medir(nombre, construir, repeticiones=3):
    tiempos = []
    total = None
    for _ in range(repeticiones):
        inicio = time.time()
        total = construir().count()  # count() fuerza la lectura completa de los Parquet
        tiempos.append(time.time() - inicio)
    print(f"{nombre}: {total} filas, mediana {statistics.median(tiempos):.2f} s "
          f"(ejecuciones: {', '.join(f'{t:.2f}' for t in tiempos)} s)", flush=True)
    return total


def main():
    spark = crear_sesion("ol-comparar-particionado")

    # Versión A: filtro sobre el año, en una tabla sin particiones
    def caso_a():
        editions = spark.read.parquet(f"{CLEAN}/editions")
        return editions.filter(F.col("anio_publicacion").between(2010, 2019))

    # Versión B: filtro sobre la columna de partición (decada = 2010 cubre 2010-2019)
    def caso_b():
        return spark.read.parquet(f"{CURATED}/edicion").filter(F.col("decada") == 2010)

    print("Plan del caso B (busca PartitionFilters):")
    caso_b().explain("formatted")

    print()
    medir("A. sin particionar (clean/editions)", caso_a)
    medir("B. particionado por decada (curated/edicion)", caso_b)

    spark.stop()


if __name__ == "__main__":
    main()
