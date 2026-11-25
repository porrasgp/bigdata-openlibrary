"""Configuración compartida del ETL medallion (solo CSV, Spark local).

Capas:
    muestra/csv  -> datos de ejemplo que vienen en el repo (origen)
    data/bronze  -> copia íntegra de los CSV de origen
    data/silver  -> datos limpios, deduplicados y validados
    data/gold    -> modelo analítico (estrella) listo para usar

Todo se ejecuta en local, sin HDFS ni PostgreSQL.
"""

import os
import shutil
from pathlib import Path

from pyspark.sql import SparkSession

RAIZ = Path(__file__).resolve().parent.parent
ORIGEN = RAIZ / "muestra" / "csv"
BRONZE = RAIZ / "data" / "bronze"
SILVER = RAIZ / "data" / "silver"
GOLD = RAIZ / "data" / "gold"

ARCHIVOS = {
    "authors": "authors.csv",
    "editions": "editions.csv",
    "works": "works.csv",
    "ratings": "ratings.csv",
    "reading-log": "reading-log.csv",
}


def crear_sesion(nombre):
    """SparkSession local, configurada para leer/escribir CSV."""
    return (
        SparkSession.builder.appName(nombre)
        .master(os.environ.get("SPARK_MASTER", "local[*]"))
        .config("spark.driver.memory", os.environ.get("SPARK_DRIVER_MEMORY", "2g"))
        .config("spark.sql.shuffle.partitions", os.environ.get("OL_PARTICIONES", "8"))
        .config("spark.sql.session.timeZone", "UTC")
        .getOrCreate()
    )


def leer_csv(spark, base, nombre):
    """Lee base/nombre.csv como texto (sin inferir tipos)."""
    ruta = base / f"{nombre}.csv"
    if not ruta.exists():
        raise SystemExit(f"No existe {ruta}. Ejecuta primero los pasos anteriores.")
    return (
        spark.read.option("header", "true")
        .option("inferSchema", "false")
        .option("multiLine", "true")
        .option("quote", '"')
        .option("escape", '"')
        .csv(ruta.as_uri())
    )


def escribir_csv(df, base, nombre):
    """Escribe un único archivo base/nombre.csv (no una carpeta de particiones).

    Spark escribe particiones en una carpeta temporal; aquí juntamos la única
    partición en un CSV normal, que es lo que queremos que lean los alumnos.
    """
    base.mkdir(parents=True, exist_ok=True)
    temporal = base / f"_{nombre}_tmp"
    (
        df.coalesce(1)
        .write.mode("overwrite")
        .option("header", "true")
        .option("quote", '"')
        .option("escape", '"')
        .option("ignoreLeadingWhiteSpace", "false")
        .option("ignoreTrailingWhiteSpace", "false")
        .csv(temporal.as_uri())
    )
    parte = next(temporal.glob("part-*.csv"))
    destino = base / f"{nombre}.csv"
    destino.unlink(missing_ok=True)
    parte.replace(destino)
    shutil.rmtree(temporal)
    print(f"   -> {destino.relative_to(RAIZ)}", flush=True)
    return destino
