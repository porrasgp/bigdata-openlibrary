#!/usr/bin/env python3
"""Bronze: copia los CSV de origen a data/bronze sin modificarlos.

La capa bronze es el "aterrizaje" de los datos: se conservan tal cual llegan.
Aquí NO se limpia nada; solo se copia y se deja constancia de tamaño y hash
para poder demostrar después que el origen no cambió.

Uso: python3 etl/01_bronze.py
"""

import hashlib
import shutil

from common import ARCHIVOS, BRONZE, ORIGEN


def sha256(ruta):
    h = hashlib.sha256()
    with open(ruta, "rb") as f:
        for bloque in iter(lambda: f.read(1 << 20), b""):
            h.update(bloque)
    return h.hexdigest()


def main():
    BRONZE.mkdir(parents=True, exist_ok=True)
    manifest = ["archivo,bytes,sha256"]

    print("== Bronze: copia de los CSV de origen", flush=True)
    for nombre in ARCHIVOS.values():
        origen = ORIGEN / nombre
        destino = BRONZE / nombre
        shutil.copy2(origen, destino)
        tamano = destino.stat().st_size
        hash_hex = sha256(destino)
        manifest.append(f"{nombre},{tamano},{hash_hex}")
        print(f">> {nombre}: {tamano} bytes", flush=True)

    (BRONZE / "_MANIFEST.csv").write_text("\n".join(manifest) + "\n", encoding="utf-8")
    print(f">> manifiesto: {BRONZE / '_MANIFEST.csv'}", flush=True)
    print("Bronze listo.", flush=True)


if __name__ == "__main__":
    main()
