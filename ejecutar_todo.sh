#!/usr/bin/env bash
# Ejecuta el núcleo medallion en local, leyendo y escribiendo solo CSV.
# Uso: bash ejecutar_todo.sh
#
# Orden: bronze -> silver -> gold. No necesita HDFS ni PostgreSQL.
# Para el flujo completo (HDFS + PostgreSQL + SQL) usa ejecutar_todo_completo.sh.
set -euo pipefail

cd "$(dirname "$0")"
source ./entorno.sh

echo "========== 0. Entorno =========="
ol_detectar_java
ol_detectar_hadoop
ol_detectar_venv "pyspark"

export SPARK_LOCAL_IP="${SPARK_LOCAL_IP:-127.0.0.1}"
export SPARK_DRIVER_MEMORY="${SPARK_DRIVER_MEMORY:-2g}"
export OL_PARTICIONES="${OL_PARTICIONES:-8}"

ol_resumen_entorno
echo "  Spark:    $("$VENV/bin/python3" -c 'import pyspark; print(pyspark.__version__)')"

mkdir -p data/bronze data/silver data/gold

echo "========== 1. Bronze: CSV de origen =========="
python3 etl/01_bronze.py

echo "========== 2. Silver: limpieza y validación =========="
python3 etl/02_silver.py

echo "========== 3. Gold: modelo estrella =========="
python3 etl/03_gold.py

echo "========== Resultado =========="
for capa in bronze silver gold; do
  echo "-- data/$capa"
  find "data/$capa" -maxdepth 2 -name '*.csv' -printf '%P  %s bytes\n' | sort
done

echo "========== FIN =========="
echo "Núcleo CSV listo. Para subirlo a HDFS y cargar PostgreSQL:"
echo "  bash ejecutar_todo_completo.sh"
echo "Teoría y diagramas: docs/flujo.md y docs/medallion.md"
