#!/usr/bin/env bash
# Muestra cómo quedaron los datos en HDFS: tamaños, bloques y replicación.
# Sirve para la discusión de la semana 1 (bloques, replicación, archivos gzip no divisibles).
#
# Uso: ./reportar_hdfs.sh [RUTA_HDFS]     (por defecto: /raw)

set -uo pipefail

RUTA="${1:-/raw}"

command -v hdfs >/dev/null || { echo "hdfs no está en PATH" >&2; exit 1; }

echo "== Espacio usado en $RUTA"
hdfs dfs -du -h -s "$RUTA"

echo
echo "== Archivos y factor de replicación"
hdfs dfs -ls -R -h "$RUTA" | grep -v "^d" || true

echo
echo "== Bloques (fsck)"
hdfs fsck "$RUTA" -files -blocks 2>/dev/null | grep -E "^/|Total blocks|Default replication|Average block size" || true

echo
echo "Nota: un .gz no se puede dividir en bloques para procesamiento paralelo;"
echo "Spark necesita repartition() después de leerlo. Lo vemos en 03_limpieza_spark."
