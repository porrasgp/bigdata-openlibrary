#!/usr/bin/env bash
# Genera manual/manual.pdf a partir de manual/manual.md.
#
# enscript no acepta UTF-8, asi que el texto se convierte a ISO-8859-1 (latin1)
# antes de crear el PostScript. Los caracteres que no existen en latin1 se
# transliteran con //TRANSLIT.
set -euo pipefail

cd "$(dirname "$0")"

for herramienta in iconv enscript ps2pdf; do
  command -v "$herramienta" >/dev/null 2>&1 || {
    echo "Falta la herramienta $herramienta" >&2
    exit 1
  }
done

mkdir -p /tmp/opencode
TEXTO=/tmp/opencode/manual-latin1.txt

# 1. Markdown legible como texto: quitamos los '# ' de los titulos.
iconv -f UTF-8 -t ISO-8859-1//TRANSLIT manual.md \
  | sed -E 's/^#{1,6} //' \
  > "$TEXTO"

# 2. Texto -> PostScript -> PDF.
enscript -X latin1 -M A4 -B -f Courier8 \
  --title="Manual de ejecucion - Big Data Open Library" \
  -p manual.ps "$TEXTO" >/dev/null
ps2pdf manual.ps manual.pdf
rm -f manual.ps

echo "PDF generado: $(pwd)/manual.pdf"
pdfinfo manual.pdf 2>/dev/null | grep -E '^(Pages|Page size|File size)' || true
