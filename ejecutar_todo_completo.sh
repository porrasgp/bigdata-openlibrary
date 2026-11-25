#!/usr/bin/env bash
# Flujo completo y manual: CSV -> medallion -> HDFS -> PostgreSQL -> SQL.
# Uso: bash ejecutar_todo_completo.sh
#
# Hace lo mismo que ejecutar_todo.sh y además:
#   1. sube data/gold/*.csv a HDFS (/medallion/gold/fecha=FECHA/),
#   2. crea el esquema estrella en PostgreSQL y carga los CSV con COPY,
#   3. ejecuta las consultas de verificación y las de ejemplo.
#
# Overrides: OL_JAVA_HOME, OL_HADOOP_HOME, OL_VENV, OL_PGBIN, OL_PGDATA, OL_FECHA.
set -euo pipefail

cd "$(dirname "$0")"
source ./entorno.sh

echo "========== 0. Entorno =========="
ol_detectar_java
ol_detectar_hadoop
ol_detectar_venv "pyspark, psycopg"
ol_detectar_pg

export SPARK_LOCAL_IP="${SPARK_LOCAL_IP:-127.0.0.1}"
export SPARK_DRIVER_MEMORY="${SPARK_DRIVER_MEMORY:-2g}"
export OL_PARTICIONES="${OL_PARTICIONES:-8}"
FECHA="${OL_FECHA:-$(date +%F)}"

ol_resumen_entorno
echo "  Spark:    $("$VENV/bin/python3" -c 'import pyspark; print(pyspark.__version__)')"
echo "  psycopg:  $("$VENV/bin/python3" -c 'import psycopg; print(psycopg.__version__)')"
echo "  Snapshot: $FECHA"

echo "========== 1. HDFS =========="
ol_asegurar_hdfs
hdfs dfs -ls / | head -10

echo "========== 2. PostgreSQL =========="
ol_asegurar_postgres
ol_asegurar_roles_pg
"$PGBIN/psql" -v ON_ERROR_STOP=1 -d "$PGDATABASE" -tAc 'select current_database()'

echo "========== 3. ETL medallion (CSV local) =========="
bash ejecutar_todo.sh

echo "========== 4. Subir gold a HDFS =========="
bash hdfs/cargar_gold.sh "$FECHA"

echo "========== 5. Cargar gold en PostgreSQL =========="
"$VENV/bin/python3" postgres/cargar_gold.py --reiniciar

echo "========== 6. Verificar carga =========="
"$PGBIN/psql" -v ON_ERROR_STOP=1 -f sql/verificar.sql

echo "========== 7. Consultas de ejemplo =========="
mkdir -p /tmp/opencode
"$PGBIN/psql" -v ON_ERROR_STOP=1 -f sql/consultas.sql > /tmp/opencode/consultas.out 2>&1
echo "  Salida: /tmp/opencode/consultas.out ($(wc -l < /tmp/opencode/consultas.out) líneas)"
grep '^===' /tmp/opencode/consultas.out || true

echo "========== FIN =========="
echo "CSV local:  data/bronze, data/silver, data/gold"
echo "HDFS:       /medallion/gold/fecha=$FECHA"
echo "PostgreSQL: esquema estrella en $PGDATABASE"
echo "Manual PDF: manual/manual.pdf"
