#!/usr/bin/env bash
# Descarga los dumps de Open Library con fecha fija, verifica tamaños
# y genera un manifiesto con SHA-256 para que todos trabajen con los mismos datos.
#
# Uso:
#   ./descargar_dumps.sh                 # descarga los 5 dumps del curso
#   ./descargar_dumps.sh --solo-muestra  # solo las primeras 5 000 líneas de cada uno
#
# Licencia de los datos: CC0 1.0 (dominio público). Fuente: openlibrary.org/developers/dumps

set -euo pipefail

FECHA="2026-10-31"                       # snapshot fijo: no usar "latest"
BASE_URL="https://openlibrary.org/data"
DESTINO="${DESTINO:-$(cd "$(dirname "$0")/.." && pwd)/data/raw}"
DUMPS=(${DUMPS_OVERRIDE:-editions works authors ratings reading-log})
LINEAS_MUESTRA="${LINEAS_MUESTRA:-5000}"
SOLO_MUESTRA=false

for arg in "$@"; do
  case "$arg" in
    --solo-muestra) SOLO_MUESTRA=true ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "Argumento no reconocido: $arg" >&2; exit 1 ;;
  esac
done

for cmd in curl gzip sha256sum; do
  command -v "$cmd" >/dev/null || { echo "Falta el comando: $cmd" >&2; exit 1; }
done

mkdir -p "$DESTINO"
MANIFIESTO="$DESTINO/manifiesto_${FECHA}.tsv"
if ! $SOLO_MUESTRA && [[ ! -f "$MANIFIESTO" ]]; then
  printf "archivo\tbytes\tsha256\n" > "$MANIFIESTO"
fi

for tipo in "${DUMPS[@]}"; do
  nombre="ol_dump_${tipo}_${FECHA}.txt.gz"
  url="$BASE_URL/$nombre"
  ruta="$DESTINO/$nombre"

  if $SOLO_MUESTRA; then
    # Muestra: solo las primeras líneas, sin bajar el archivo completo.
    # head cierra la tubería, por eso curl puede fallar: es normal.
    salida="$DESTINO/muestra_${tipo}.tsv.gz"
    echo ">> Muestra de $tipo -> $salida"
    curl -sL --max-time 300 "$url" 2>/dev/null \
      | gzip -dc 2>/dev/null | head -n "$LINEAS_MUESTRA" | gzip -c > "$salida" || true
    echo "   $(gzip -dc "$salida" | wc -l) líneas, $(stat -c %s "$salida") bytes"
    continue
  fi

  esperado=$(curl -sIL --max-time 60 "$url" | tr -d '\r' | awk 'tolower($1)=="content-length:"{t=$2} END{print t}')
  if [[ -z "${esperado:-}" ]]; then
    echo "No se pudo obtener el tamaño de $url" >&2
    exit 1
  fi

  # -C - reanuda descargas interrumpidas
  echo ">> Descargando $nombre ($esperado bytes)"
  curl -L --progress-bar --retry 5 --retry-delay 10 -C - -o "$ruta" "$url"

  real=$(stat -c %s "$ruta")
  if [[ "$real" != "$esperado" ]]; then
    echo "Tamaño incorrecto para $nombre: $real de $esperado. Vuelve a ejecutar el script." >&2
    exit 1
  fi

  gzip -t "$ruta"
  hash=$(sha256sum "$ruta" | awk '{print $1}')
  printf "%s\t%s\t%s\n" "$nombre" "$real" "$hash" >> "$MANIFIESTO"
  echo "   OK  sha256=$hash"
done

if ! $SOLO_MUESTRA; then
  echo "Listo. Manifiesto: $MANIFIESTO"
fi
