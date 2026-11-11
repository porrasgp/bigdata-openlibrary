#!/usr/bin/env bash
# Sube los dumps (o la muestra) a HDFS, zona raw, con la fecha del snapshot en la ruta.
#
# Uso:
#   ./cargar_raw.sh CARPETA_LOCAL [FECHA] [--verificar-hash]
#
# Ejemplos:
#   ./cargar_raw.sh ../data/raw 2026-10-31            # dumps completos
#   ./cargar_raw.sh ../muestra muestra                # muestra del repositorio
#   ./cargar_raw.sh ../data/raw 2026-10-31 --verificar-hash   # lento: lee cada archivo de HDFS
#
# Destino: /raw/openlibrary/fecha=FECHA/

set -euo pipefail

if [[ $# -lt 1 ]]; then
  sed -n '2,11p' "$0"
  exit 1
fi

ORIGEN="$1"
FECHA="${2:-2026-10-31}"
VERIFICAR_HASH=false
[[ "${3:-}" == "--verificar-hash" ]] && VERIFICAR_HASH=true

DESTINO="/raw/openlibrary/fecha=${FECHA}"

fallo() { echo "ERROR: $*" >&2; exit 1; }

command -v hdfs >/dev/null || fallo "hdfs no está en PATH. Carga hadoop-env (ver 00_setup/README.md)."
hdfs dfs -ls / >/dev/null 2>&1 || fallo "HDFS no responde. Arranca con: start-dfs.sh (o hdfs --daemon start namenode/datanode)"
[[ -d "$ORIGEN" ]] || fallo "no existe la carpeta $ORIGEN"

shopt -s nullglob
archivos=("$ORIGEN"/*.txt.gz "$ORIGEN"/*.tsv.gz)
[[ ${#archivos[@]} -gt 0 ]] || fallo "no hay archivos *.txt.gz ni *.tsv.gz en $ORIGEN"

hdfs dfs -mkdir -p "$DESTINO"

for f in "${archivos[@]}"; do
  nombre=$(basename "$f")
  tam_local=$(stat -c %s "$f")

  echo ">> $nombre ($tam_local bytes) -> $DESTINO"
  hdfs dfs -put -f "$f" "$DESTINO/$nombre"

  # hdfs dfs -du imprime: tamaño  espacio_ocupado_con_replicas  ruta
  tam_hdfs=$(hdfs dfs -du "$DESTINO/$nombre" | awk '{print $1}')
  [[ "$tam_local" == "$tam_hdfs" ]] || fallo "tamaño distinto en HDFS para $nombre: local=$tam_local hdfs=$tam_hdfs"
  echo "   tamaño OK"

  if $VERIFICAR_HASH; then
    h_local=$(sha256sum "$f" | awk '{print $1}')
    h_hdfs=$(hdfs dfs -cat "$DESTINO/$nombre" | sha256sum | awk '{print $1}')
    [[ "$h_local" == "$h_hdfs" ]] || fallo "hash distinto para $nombre"
    echo "   sha256 OK ($h_hdfs)"
  fi
done

echo
echo "Contenido de $DESTINO:"
hdfs dfs -ls -h "$DESTINO"
