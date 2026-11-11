#!/usr/bin/env bash
# Descarga los dumps de Open Library con fecha fija y verifica tamaño y SHA-256.
# Genera un manifiesto para que todos los alumnos trabajen con exactamente los mismos datos.
#
# Uso:
#   ./descargar_dumps.sh                      # los 5 dumps del curso (~17.6 GB)
#   ./descargar_dumps.sh ratings reading-log  # solo algunos (ej. los pequeños, ~135 MB)
#
# Licencia de los datos: CC0 1.0 (dominio público). Fuente: openlibrary.org/developers/dumps
# Si se corta la descarga, vuelve a ejecutar: continúa desde donde quedó (curl -C -).

set -euo pipefail

FECHA="2026-10-31"                       # snapshot fijo: no usar "latest"
BASE_URL="https://openlibrary.org/data"
DESTINO="${DESTINO:-$(cd "$(dirname "$0")/.." && pwd)/data/raw}"
TODOS=(editions works authors ratings reading-log)

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  sed -n '2,8p' "$0"
  exit 0
fi

if [[ $# -gt 0 ]]; then
  DUMPS=("$@")
else
  DUMPS=("${TODOS[@]}")
fi

for tipo in "${DUMPS[@]}"; do
  [[ " ${TODOS[*]} " == *" $tipo "* ]] || { echo "Tipo desconocido: $tipo (usa: ${TODOS[*]})" >&2; exit 1; }
done

for cmd in curl gzip sha256sum; do
  command -v "$cmd" >/dev/null || { echo "Falta el comando: $cmd" >&2; exit 1; }
done

mkdir -p "$DESTINO"
MANIFIESTO="$DESTINO/manifiesto_${FECHA}.tsv"
if [[ ! -f "$MANIFIESTO" ]]; then
  printf "archivo\tbytes\tsha256\n" > "$MANIFIESTO"
fi

for tipo in "${DUMPS[@]}"; do
  nombre="ol_dump_${tipo}_${FECHA}.txt.gz"
  url="$BASE_URL/$nombre"
  ruta="$DESTINO/$nombre"

  # Si ya está en el manifiesto con el mismo tamaño, no se vuelve a bajar
  if grep -q "^${nombre}"$'\t' "$MANIFIESTO" && [[ -f "$ruta" ]]; then
    echo ">> $nombre ya está verificado en el manifiesto; se omite"
    continue
  fi

  esperado=$(curl -sIL --max-time 60 "$url" | tr -d '\r' | awk 'tolower($1)=="content-length:"{t=$2} END{print t}')
  if [[ -z "${esperado:-}" ]]; then
    echo "No se pudo obtener el tamaño de $url" >&2
    exit 1
  fi

  echo ">> Descargando $nombre ($esperado bytes)"
  curl -L --progress-bar --retry 5 --retry-delay 10 -C - -o "$ruta" "$url"

  real=$(stat -c %s "$ruta")
  if [[ "$real" != "$esperado" ]]; then
    echo "Tamaño incorrecto para $nombre: $real de $esperado. Vuelve a ejecutar el script." >&2
    exit 1
  fi

  gzip -t "$ruta"
  hash=$(sha256sum "$ruta" | awk '{print $1}')
  grep -v "^${nombre}"$'\t' "$MANIFIESTO" > "$MANIFIESTO.tmp" || true
  mv "$MANIFIESTO.tmp" "$MANIFIESTO"
  printf "%s\t%s\t%s\n" "$nombre" "$real" "$hash" >> "$MANIFIESTO"
  echo "   OK  sha256=$hash"
done

echo "Listo. Manifiesto: $MANIFIESTO"
