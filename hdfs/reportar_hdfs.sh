#!/usr/bin/env bash
# Muestra tamaños, archivos y bloques de una ruta HDFS.
#
# Uso: bash hdfs/reportar_hdfs.sh [RUTA]
# Por defecto: /medallion (donde este proyecto escribe el gold).
set -uo pipefail

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
cd "$RAIZ"
source ./entorno.sh

ol_detectar_java
ol_detectar_hadoop
ol_asegurar_hdfs || exit 1

RUTA="${1:-/medallion}"

echo "== Espacio usado en $RUTA"
hdfs dfs -du -h -s "$RUTA" 2>&1 || true

echo
echo "== Archivos y factor de replicación"
hdfs dfs -ls -R -h "$RUTA" 2>&1 | grep -v '^d' || true

echo
echo "== Bloques (fsck)"
hdfs fsck "$RUTA" -files -blocks 2>/dev/null \
  | grep -E '^/|Total blocks|Default replication|Average block size' || true

echo
echo "Nota: aquí subimos CSV ya procesados. En un clúster real la capa bronze"
echo "guardaría los archivos de origen y Spark leería directamente desde HDFS."
