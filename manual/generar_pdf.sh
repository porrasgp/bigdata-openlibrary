#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

elegido="${PYTHON:-}"
if [[ -z "$elegido" && -n "${VENV:-}" && -x "$VENV/bin/python3" ]] && "$VENV/bin/python3" -c 'import reportlab' >/dev/null 2>&1; then
  elegido="$VENV/bin/python3"
fi
elegido="${elegido:-python3}"

if ! "$elegido" -c 'import reportlab' >/dev/null 2>&1; then
  echo "Falta reportlab: instala requirements.txt o ejecuta pip install reportlab" >&2
  exit 1
fi

"$elegido" generar_pdf.py
