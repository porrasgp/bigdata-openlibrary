"""Configuración y utilidades compartidas por los jobs de la semana 2.

Todo se configura con variables de entorno, así el mismo código sirve para
la muestra (rutas locales o HDFS) y para los dumps completos.

Variables:
  OL_RAW          carpeta con los dumps crudos        (por defecto: HDFS, fecha 2026-10-31)
  OL_CLEAN        salida de limpieza (Parquet)         (por defecto: HDFS /clean/openlibrary)
  OL_CURATED      salida curada (Parquet)              (por defecto: HDFS /curated/openlibrary)
  OL_RECHAZADOS   registros rechazados (Parquet)       (por defecto: HDFS /clean/_rechazados)
  OL_PARTICIONES  particiones tras leer un .gz         (por defecto: 16)
  SPARK_MASTER    local[*], local[4], yarn...          (por defecto: local[*])
  SPARK_DRIVER_MEMORY  memoria del driver              (por defecto: 3g)
"""

import os

from pyspark.sql import SparkSession

RAW = os.environ.get("OL_RAW", "hdfs://localhost:8020/raw/openlibrary/fecha=2026-10-31")
CLEAN = os.environ.get("OL_CLEAN", "hdfs://localhost:8020/clean/openlibrary")
CURATED = os.environ.get("OL_CURATED", "hdfs://localhost:8020/curated/openlibrary")
RECHAZADOS = os.environ.get("OL_RECHAZADOS", "hdfs://localhost:8020/clean/_rechazados")
PARTICIONES = int(os.environ.get("OL_PARTICIONES", "16"))

# Patrón de archivo dentro de RAW para cada tipo de dump
PATRON_ARCHIVO = {
    "editions": "*editions*",
    "works": "*works*",
    "authors": "*authors*",
    "ratings": "*ratings*",
    "reading-log": "*reading-log*",
}


def crear_sesion(nombre):
    """Crea la SparkSession con la configuración del curso."""
    spark = (
        SparkSession.builder.appName(nombre)
        .master(os.environ.get("SPARK_MASTER", "local[*]"))
        .config("spark.driver.memory", os.environ.get("SPARK_DRIVER_MEMORY", "3g"))
        .config("spark.sql.shuffle.partitions", str(PARTICIONES))
        .config("spark.sql.session.timeZone", "UTC")
        .getOrCreate()
    )
    spark.sparkContext.setLogLevel("WARN")
    return spark
