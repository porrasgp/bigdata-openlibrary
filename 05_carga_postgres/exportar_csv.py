#!/usr/bin/env python3
"""Exporta las tablas curadas (Parquet en HDFS) a CSV sin cabecera, para COPY.

Spark escribe una carpeta por tabla con archivos part-*.csv. Usamos:
  - sin cabecera: el COPY indica las columnas explícitamente (ver tablas.py);
  - escape con comillas dobles (RFC 4180): los títulos con " se escapan bien
    (el escape por defecto de Spark, la barra invertida, no lo es para COPY);
  - sin recortar espacios: por defecto Spark quita los espacios al inicio y al
    final al escribir, y "Nombre " pasaría a ser "Nombre" (dato alterado);
  - null se escribe como campo vacío sin comillas (COPY lo lee como NULL), y
    la cadena vacía como "" (COPY la lee como cadena vacía).

Uso:
  python3 exportar_csv.py                       # a ../data/export
  python3 exportar_csv.py --salida /ruta/otra
"""

import argparse
import sys
import time
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
# common.py vive en la carpeta de la semana 2; lo importamos desde aquí
sys.path.insert(0, str(RAIZ / "03_limpieza_spark"))

from common import CURATED, crear_sesion  # noqa: E402
from tablas import TABLAS  # noqa: E402


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--salida", default=str(RAIZ / "data" / "export"),
                    help="carpeta local de salida (por defecto ../data/export)")
    args = ap.parse_args()

    salida = Path(args.salida).resolve()
    salida.mkdir(parents=True, exist_ok=True)
    # Spark necesita el prefijo file:// para escribir en el disco local,
    # porque el sistema por defecto es HDFS.
    destino_base = salida.as_uri()

    spark = crear_sesion("ol-exportar-csv")
    for tabla, columnas in TABLAS.items():
        inicio = time.time()
        df = spark.read.parquet(f"{CURATED}/{tabla}").select(*columnas)
        destino = f"{destino_base}/{tabla}"
        (
            df.write.mode("overwrite")
            .option("header", "false")
            .option("quote", '"')
            .option("escape", '"')
            .option("ignoreLeadingWhiteSpace", "false")
            .option("ignoreTrailingWhiteSpace", "false")
            .csv(destino)
        )
        print(f">> {tabla}: {len(columnas)} columnas -> {salida / tabla} ({time.time() - inicio:.0f} s)", flush=True)

    spark.stop()
    print(f"Listo: {salida}")


if __name__ == "__main__":
    main()
