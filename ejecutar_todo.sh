#!/usr/bin/env bash
# Ejecuta TODO el pipeline medallion en local, leyendo y escribiendo solo CSV.
# Uso: bash ejecutar_todo.sh
#
# Orden: bronze -> silver -> gold. No necesita HDFS ni PostgreSQL.
# Si tu entorno está en otra ruta, puedes override: OL_JAVA_HOME, OL_HADOOP_HOME, OL_VENV.
set -euo pipefail

cd "$(dirname "$0")"

echo "========== 0. Entorno =========="

# Java
if [[ -z "${JAVA_HOME:-}" || ! -x "${JAVA_HOME:-/}/bin/java" ]]; then
  if command -v java >/dev/null 2>&1; then
    JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
  else
    for cand in \
      "${OL_JAVA_HOME:-}" \
      "$HOME/Desktop/opt/jdk-17.0.21+9" \
      "$HOME/opt/jdk-17.0.21+9" \
      "$HOME/jdk-17.0.21+9"; do
      [[ -n "$cand" && -x "$cand/bin/java" ]] && JAVA_HOME="$cand" && break
    done
  fi
fi
[[ -n "${JAVA_HOME:-}" && -x "$JAVA_HOME/bin/java" ]] || { echo "No encuentro Java 17" >&2; exit 1; }

# Hadoop (Spark lo usa para el sistema de archivos local)
if [[ -z "${HADOOP_HOME:-}" || ! -x "${HADOOP_HOME:-/}/bin/hadoop" ]]; then
  for cand in \
    "${OL_HADOOP_HOME:-}" \
    "$HOME/Desktop/opt/hadoop-3.5.0" \
    "$HOME/opt/hadoop-3.5.0" \
    "$HOME/hadoop-3.5.0"; do
    [[ -n "$cand" && -x "$cand/bin/hadoop" ]] && HADOOP_HOME="$cand" && break
  done
fi
if [[ -n "${HADOOP_HOME:-}" && -d "$HADOOP_HOME/etc/hadoop" ]]; then
  export HADOOP_HOME HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"
fi

# Venv con PySpark
VENV="${OL_VENV:-${VIRTUAL_ENV:-}}"
if [[ -z "$VENV" || ! -x "$VENV/bin/python3" ]] ||
   ! "$VENV/bin/python3" -c 'import pyspark' >/dev/null 2>&1; then
  VENV=""
  for cand in \
    "$HOME/venv-bigdata" \
    "$HOME/Desktop/venv-bigdata" \
    "$HOME/.local/share/Trash/files/venv-bigdata"; do
    if [[ -x "$cand/bin/python3" ]] && "$cand/bin/python3" -c 'import pyspark' >/dev/null 2>&1; then
      VENV="$cand"; break
    fi
  done
fi
[[ -n "$VENV" ]] || { echo "No encuentro PySpark (usa OL_VENV=/ruta/al/venv)" >&2; exit 1; }

export JAVA_HOME VIRTUAL_ENV="$VENV"
export PATH="$JAVA_HOME/bin:${HADOOP_HOME:-}/bin:$VENV/bin:$PATH"
export PYSPARK_PYTHON="$VENV/bin/python3"
export PYSPARK_DRIVER_PYTHON="$VENV/bin/python3"
export SPARK_LOCAL_IP="${SPARK_LOCAL_IP:-127.0.0.1}"
export SPARK_DRIVER_MEMORY="${SPARK_DRIVER_MEMORY:-2g}"
export OL_PARTICIONES="${OL_PARTICIONES:-8}"

echo "  Java:   $JAVA_HOME"
echo "  Hadoop: ${HADOOP_HOME:-(no necesario)}"
echo "  Spark:  $($VENV/bin/python3 -c 'import pyspark; print(pyspark.__version__)')"

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
echo "Para ver el flujo y la teoría: docs/flujo.md y docs/medallion.md"
