#!/usr/bin/env bash
# Verifica que el entorno del curso está listo.
# Uso: ./verificar.sh
# Sale con código 0 si todo pasa, 1 si algo falla.

set -uo pipefail

ok=0; fallos=0
pasa()  { echo "  [OK]    $1"; ok=$((ok+1)); }
falla() { echo "  [FALLA] $1"; fallos=$((fallos+1)); }

comprobar() {  # comprobar "descripción" comando...
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then pasa "$desc"; else falla "$desc"; fi
}

echo "== Sistema"
RAM_GB=$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)
if [[ "$RAM_GB" -ge 7 ]]; then pasa "RAM: ${RAM_GB} GB (mínimo 8 GB asignados a la VM)"
else falla "RAM: ${RAM_GB} GB (se necesitan al menos 8 GB en la VM)"; fi

DISCO_GB=$(df -BG --output=avail "$HOME" | tail -1 | tr -dc '0-9')
if [[ "$DISCO_GB" -ge 60 ]]; then pasa "Disco libre en \$HOME: ${DISCO_GB} GB"
else falla "Disco libre en \$HOME: ${DISCO_GB} GB (se recomiendan 60 GB o más)"; fi

echo "== Java"
comprobar "Java 17 instalado" bash -c 'java -version 2>&1 | grep -q "version \"17"'

echo "== Hadoop"
comprobar "hadoop en PATH" command -v hadoop
comprobar "Versión 3.5.x" bash -c 'hadoop version 2>/dev/null | head -1 | grep -q "Hadoop 3\.5"'
comprobar "HDFS responde (hdfs dfs -ls /)" hdfs dfs -ls /
comprobar "Interfaz web del NameNode en 9870" bash -c 'curl -sL -o /dev/null -w "%{http_code}" http://localhost:9870 | grep -q 200'

echo "== PostgreSQL"
comprobar "psql en PATH" command -v psql
comprobar "Servidor activo en localhost:5432" pg_isready -h localhost -p 5432
comprobar "Versión 18.x" bash -c 'psql -h localhost -U "${PGUSER:-$USER}" -d postgres -tAc "show server_version" 2>/dev/null | grep -q "^18"'

echo "== Python y PySpark"
comprobar "Python 3.11 o superior" python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)'
comprobar "PySpark 4.3.x importable" python3 -c 'import pyspark, sys; sys.exit(0 if pyspark.__version__.startswith("4.3") else 1)'
comprobar "Spark arranca en modo local" python3 -c 'from pyspark.sql import SparkSession; s=SparkSession.builder.master("local[1]").getOrCreate(); s.range(3).count(); s.stop()'

echo
echo "Resultado: $ok correctos, $fallos fallidos."
[[ $fallos -eq 0 ]] && exit 0 || exit 1
