#!/usr/bin/env bash
# Levanta entorno + pipeline completo del curso usando la muestra de 60 MB.
# Uso: bash levantar_todo.sh
#
# Paths instalados en esta máquina (se detectan solos; se pueden override):
#   OL_JAVA_HOME, OL_HADOOP_HOME, OL_VENV, OL_PGBIN, OL_PGDATA
set -euo pipefail

cd "$(dirname "$0")"
mkdir -p /tmp/opencode

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
      if [[ -n "$cand" && -x "$cand/bin/java" ]]; then JAVA_HOME="$cand"; break; fi
    done
  fi
fi
[[ -n "${JAVA_HOME:-}" && -x "$JAVA_HOME/bin/java" ]] || { echo "No encuentro Java 17" >&2; exit 1; }

# Hadoop
if [[ -z "${HADOOP_HOME:-}" || ! -x "${HADOOP_HOME:-/}/bin/hdfs" ]]; then
  for cand in \
    "${OL_HADOOP_HOME:-}" \
    "$HOME/Desktop/opt/hadoop-3.5.0" \
    "$HOME/opt/hadoop-3.5.0" \
    "$HOME/hadoop-3.5.0"; do
    if [[ -n "$cand" && -x "$cand/bin/hdfs" ]]; then HADOOP_HOME="$cand"; break; fi
  done
fi
[[ -n "${HADOOP_HOME:-}" && -x "$HADOOP_HOME/bin/hdfs" ]] || { echo "No encuentro Hadoop" >&2; exit 1; }
export HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"

# Venv con PySpark y psycopg
VENV_BIGDATA="${OL_VENV:-${VIRTUAL_ENV:-}}"
if [[ -z "$VENV_BIGDATA" || ! -x "$VENV_BIGDATA/bin/python3" ]] ||
   ! "$VENV_BIGDATA/bin/python3" -c 'import pyspark, psycopg' >/dev/null 2>&1; then
  VENV_BIGDATA=""
  for cand in \
    "$HOME/venv-bigdata" \
    "$HOME/Desktop/venv-bigdata" \
    "$HOME/.local/share/Trash/files/venv-bigdata"; do
    if [[ -x "$cand/bin/python3" ]] && "$cand/bin/python3" -c 'import pyspark, psycopg' >/dev/null 2>&1; then
      VENV_BIGDATA="$cand"; break
    fi
  done
fi
[[ -n "$VENV_BIGDATA" ]] || { echo "No encuentro el venv con pyspark + psycopg (usa OL_VENV=...)" >&2; exit 1; }

# Binarios de PostgreSQL
PGBIN="${OL_PGBIN:-}"
if [[ -z "$PGBIN" || ! -x "$PGBIN/psql" ]]; then
  if command -v psql >/dev/null 2>&1; then
    PGBIN="$(dirname "$(command -v psql)")"
  else
    for cand in \
      "$HOME/Desktop/venv-pgtest/lib/python3.12/site-packages/pgserver/pginstall/bin" \
      "$HOME/venv-pgtest/lib/python3.12/site-packages/pgserver/pginstall/bin"; do
      if [[ -x "$cand/psql" ]]; then PGBIN="$cand"; break; fi
    done
  fi
fi
[[ -n "${PGBIN:-}" && -x "$PGBIN/psql" ]] || { echo "No encuentro psql (usa OL_PGBIN=...)" >&2; exit 1; }
PGDATA="${OL_PGDATA:-$HOME/pgdata}"

export JAVA_HOME HADOOP_HOME VIRTUAL_ENV="$VENV_BIGDATA"
export PATH="$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$VENV_BIGDATA/bin:$PGBIN:$PATH"
export PYSPARK_PYTHON="$VENV_BIGDATA/bin/python3"
export PYSPARK_DRIVER_PYTHON="$VENV_BIGDATA/bin/python3"
export SPARK_LOCAL_IP="${SPARK_LOCAL_IP:-127.0.0.1}"

export PGHOST="${PGHOST:-localhost}"
export PGPORT="${PGPORT:-5432}"
export PGUSER="${PGUSER:-$USER}"
export PGDATABASE="${PGDATABASE:-$USER}"

# Datos: siempre la muestra, para que el pipeline sea reproducible y rápido.
export OL_RAW="hdfs://localhost:8020/raw/openlibrary/fecha=muestra"
export OL_CLEAN="hdfs://localhost:8020/clean/openlibrary"
export OL_CURATED="hdfs://localhost:8020/curated/openlibrary"
export OL_RECHAZADOS="hdfs://localhost:8020/clean/_rechazados"
export SPARK_DRIVER_MEMORY="${SPARK_DRIVER_MEMORY:-3g}"
export OL_PARTICIONES="${OL_PARTICIONES:-8}"

echo "  Java:    $JAVA_HOME"
echo "  Hadoop:  $HADOOP_HOME"
echo "  Python:  $($VENV_BIGDATA/bin/python3 -c 'import pyspark; print(pyspark.__version__)')"
echo "  Postgres: $PGHOST:$PGPORT ($PGUSER/$PGDATABASE)"

echo "========== 1. HDFS =========="
if ! hdfs dfs -ls / >/dev/null 2>&1; then
  echo "HDFS no responde: arrancando NameNode y DataNode..."
  hdfs --daemon start namenode
  hdfs --daemon start datanode
  for _ in $(seq 1 30); do
    hdfs dfs -ls / >/dev/null 2>&1 && break
    sleep 2
  done
fi
hdfs dfs -ls / >/dev/null
hdfs dfsadmin -safemode leave >/dev/null 2>&1 || true
hdfs dfs -ls /

echo "========== 2. PostgreSQL =========="
if ! "$PGBIN/pg_isready" -h "$PGHOST" -p "$PGPORT" >/dev/null 2>&1; then
  echo "PostgreSQL no responde: arrancando..."
  "$PGBIN/pg_ctl" -D "$PGDATA" -l /tmp/opencode/postgres.log \
    -o "-p $PGPORT -k /tmp" start
fi
psql -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname = '$PGUSER'" | grep -q 1 ||
  psql -v ON_ERROR_STOP=1 -d postgres -c "CREATE ROLE \"$PGUSER\" LOGIN SUPERUSER"
psql -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '$PGDATABASE'" | grep -q 1 ||
  createdb -O "$PGUSER" "$PGDATABASE"
psql -tAc 'SELECT version();'

echo "========== 3. Muestra -> HDFS (raw) =========="
bash 02_hdfs/cargar_raw.sh muestra muestra

echo "========== 4. Limpieza y curado (Spark) =========="
python3 03_limpieza_spark/01_raw_a_clean.py
python3 03_limpieza_spark/02_clean_a_curated.py
python3 03_limpieza_spark/03_comparar_particionado.py

echo "========== 5. Curated -> CSV =========="
python3 05_carga_postgres/exportar_csv.py

echo "========== 6. DDL + COPY + estrella =========="
python3 05_carga_postgres/cargar_postgres.py --reiniciar
psql -v ON_ERROR_STOP=1 -f 05_carga_postgres/verificar_carga.sql

echo "========== 7. Consultas =========="
for f in 01_basicas 02_joins 03_ventanas 04_esquema_estrella; do
  echo "--- $f.sql ---"
  psql -v ON_ERROR_STOP=1 -f "06_consultas/$f.sql" > "/tmp/opencode/$f.out" 2>&1
  echo "   lineas=$(wc -l < "/tmp/opencode/$f.out") errores=$(grep -ci error "/tmp/opencode/$f.out")"
done
psql -v ON_ERROR_STOP=1 -f 06_consultas/indices.sql >/dev/null
psql -v ON_ERROR_STOP=1 -f 06_consultas/05_explain.sql > /tmp/opencode/05_explain.out 2>&1
echo "   EXPLAIN: $(wc -l < /tmp/opencode/05_explain.out) lineas"

echo "========== FIN =========="
echo "Listo. Salidas de consultas en /tmp/opencode/"
