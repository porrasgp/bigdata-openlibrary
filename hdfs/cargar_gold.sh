#!/usr/bin/env bash
# Sube data/gold/*.csv a HDFS en /medallion/gold/fecha=FECHA/.
#
# Uso:
#   bash hdfs/cargar_gold.sh [FECHA] [--verificar-hash]
#
# Ejemplos:
#   bash hdfs/cargar_gold.sh
#   bash hdfs/cargar_gold.sh 2026-11-25
#   bash hdfs/cargar_gold.sh 2026-11-25 --verificar-hash   (lee cada archivo de HDFS)
#
# Si HDFS no responde, el script arranca NameNode y DataNode.
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
cd "$RAIZ"
source ./entorno.sh

FECHA="${1:-$(date +%F)}"
VERIFICAR_HASH=false
[[ "${2:-}" == "--verificar-hash" ]] && VERIFICAR_HASH=true

ol_detectar_java
ol_detectar_hadoop
ol_asegurar_hdfs

ORIGEN="$RAIZ/data/gold"
DESTINO="/medallion/gold/fecha=$FECHA"

[[ -d "$ORIGEN" ]] || {
  echo "No existe $ORIGEN. Ejecuta primero: bash ejecutar_todo.sh" >&2
  exit 1
}

echo "========== HDFS: carga de la capa gold =========="
echo "  Origen:  $ORIGEN"
echo "  Destino: $DESTINO"
hdfs dfs -mkdir -p "$DESTINO"

shopt -s nullglob
archivos=("$ORIGEN"/*.csv)
[[ ${#archivos[@]} -gt 0 ]] || {
  echo "No hay CSV en $ORIGEN. Ejecuta primero el ETL." >&2
  exit 1
}

for f in "${archivos[@]}"; do
  nombre="$(basename "$f")"
  tam_local="$(stat -c %s "$f")"
  echo ">> $nombre ($tam_local bytes)"

  hdfs dfs -put -f "$f" "$DESTINO/$nombre"

  tam_hdfs="$(hdfs dfs -du "$DESTINO/$nombre" | awk '{print $1}')"
  [[ "$tam_local" == "$tam_hdfs" ]] || {
    echo "ERROR: tamaño distinto en HDFS para $nombre (local=$tam_local hdfs=$tam_hdfs)" >&2
    exit 1
  }
  echo "   tamaño verificado en HDFS"

  if $VERIFICAR_HASH; then
    h_local="$(sha256sum "$f" | awk '{print $1}')"
    h_hdfs="$(hdfs dfs -cat "$DESTINO/$nombre" | sha256sum | awk '{print $1}')"
    [[ "$h_local" == "$h_hdfs" ]] || {
      echo "ERROR: sha256 distinto para $nombre" >&2
      exit 1
    }
    echo "   sha256 verificado"
  fi
done

echo
echo "Contenido de $DESTINO:"
hdfs dfs -ls -h "$DESTINO"
echo "Carga en HDFS terminada."
