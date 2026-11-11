#!/usr/bin/env python3
"""Construye una muestra COHERENTE de Open Library para practicar el pipeline.

Por qué no basta con "las primeras líneas" de cada dump: las obras, ediciones y
autores de la muestra se referirían a claves que no están en la muestra, y las
tablas de relación quedarían vacías. Esta muestra se arma así:

  1. Cuenta valoraciones y lecturas por obra en los dumps completos
     'ratings' y 'reading-log' (son pequeños: ~135 MB comprimidos).
  2. Elige las N obras con más eventos (desempate por clave, así es reproducible).
  3. Para cada obra pide a la API pública de Open Library: la obra, sus
     ediciones (hasta E por obra) y los autores de ambas.
  4. Filtra valoraciones y lecturas a esas obras. La edición se deja en \\N
     si no está en la muestra (en el modelo queda null).
  5. Escribe muestra/*.tsv.gz con el mismo formato que los dumps.

Requisitos:
  - Haber descargado antes ratings y reading-log:
      ../01_extraccion/descargar_dumps.sh ratings reading-log
  - Conexión a internet. Peticiones educadas: User-Agent identificable, una cada
    0,5 s, reintentos con espera si el servidor responde 429 o 5xx, y caché en
    data/cache_api/ para no volver a pedir lo mismo.

Nota: la API devuelve el estado ACTUAL de los registros, que puede ser más
reciente que el snapshot 2026-10-31. Por eso la muestra no es idéntica al dump;
es internamente consistente, que es lo que necesitamos para practicar.

Uso:
  python3 construir_muestra.py                 # 200 obras, 8 ediciones por obra
  python3 construir_muestra.py --obras 50      # más rápido, para pruebas
"""

import argparse
import collections
import gzip
import json
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
RAW = RAIZ / "data" / "raw"
CACHE = RAIZ / "data" / "cache_api"
SALIDA = RAIZ / "muestra"

BASE = "https://openlibrary.org"
UA = "bigdata-curso/1.0 (https://github.com/porrasgp/bigdata-openlibrary; uso educativo)"
PAUSA = 0.5  # segundos entre peticiones

FECHA_DUMP = "2026-10-31"


def ruta_cache(clave):
    CACHE.mkdir(parents=True, exist_ok=True)
    return CACHE / (re.sub(r"[^A-Za-z0-9_.-]", "_", clave) + ".json")


def pedir(ruta, query=""):
    """GET a la API con caché. Devuelve el JSON, o None si no existe (404)."""
    archivo = ruta_cache(ruta + query)
    if archivo.exists():
        return json.loads(archivo.read_text(encoding="utf-8"))

    url = BASE + ruta + query
    for intento in range(4):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=60) as resp:
                datos = json.loads(resp.read().decode("utf-8"))
            time.sleep(PAUSA)
            archivo.write_text(json.dumps(datos, ensure_ascii=False), encoding="utf-8")
            return datos
        except urllib.error.HTTPError as e:
            if e.code == 404:
                time.sleep(PAUSA)
                archivo.write_text("null", encoding="utf-8")
                return None
            if e.code in (429, 500, 502, 503, 504):
                espera = 10 * (intento + 1)
                print(f"   HTTP {e.code} en {ruta}; espero {espera} s", file=sys.stderr)
                time.sleep(espera)
                continue
            raise
        except urllib.error.URLError:
            time.sleep(10 * (intento + 1))
    raise RuntimeError(f"No se pudo obtener {url}")


def fecha_texto(valor):
    """last_modified llega como {'type': ..., 'value': '...'} en la API."""
    if isinstance(valor, dict):
        return valor.get("value", "")
    return valor or ""


def claves_de_autores(lista):
    """Autores de una obra ({'author': {'key'}}) o de una edición ({'key'})."""
    salida = []
    for a in lista or []:
        if isinstance(a, dict):
            k = a.get("key") or (a.get("author") or {}).get("key")
            if k:
                salida.append(k)
    return salida


def contar_eventos():
    """Número de valoraciones + lecturas por obra en los dumps completos."""
    conteo = collections.Counter()
    for nombre in ("ratings", "reading-log"):
        archivo = RAW / f"ol_dump_{nombre}_{FECHA_DUMP}.txt.gz"
        if not archivo.exists():
            sys.exit(f"Falta {archivo}. Ejecuta: ../01_extraccion/descargar_dumps.sh ratings reading-log")
        with gzip.open(archivo, "rt", encoding="utf-8", errors="replace") as f:
            for linea in f:
                obra = linea.split("\t", 1)[0]
                if obra.startswith("/works/"):
                    conteo[obra] += 1
    return conteo


def elegir_obras(conteo, n):
    """Obras de tipo /type/work (no redirecciones), en orden de eventos."""
    candidatas = sorted(conteo.items(), key=lambda kv: (-kv[1], kv[0]))
    elegidas, descartadas = [], 0
    for clave, _ in candidatas:
        if len(elegidas) >= n:
            break
        obra = pedir(f"{clave}.json")
        if not obra or obra.get("type", {}).get("key") != "/type/work":
            descartadas += 1
            continue
        elegidas.append(obra)
    print(f"Obras elegidas: {len(elegidas)} (descartadas por no ser /type/work: {descartadas})")
    return elegidas


def recolectar(obras, ediciones_por_obra):
    """Trae ediciones y autores de las obras elegidas."""
    ediciones, autores = {}, {}
    for i, obra in enumerate(obras, 1):
        clave = obra["key"]
        lista = pedir(f"{clave}/editions.json", f"?limit={ediciones_por_obra}")
        for ed in (lista or {}).get("entries", []):
            if ed.get("type", {}).get("key") != "/type/edition":
                continue
            ediciones.setdefault(ed["key"], ed)
            for k in claves_de_autores(ed.get("authors")):
                autores.setdefault(k, None)
        for k in claves_de_autores(obra.get("authors")):
            autores.setdefault(k, None)
        if i % 25 == 0:
            print(f"   obras procesadas: {i}/{len(obras)}; ediciones: {len(ediciones)}", flush=True)

    print(f"Descargando {len(autores)} autores...", flush=True)
    for i, k in enumerate(sorted(autores), 1):
        autores[k] = pedir(f"{k}.json")
        if i % 100 == 0:
            print(f"   autores: {i}/{len(autores)}", flush=True)
    autores = {k: v for k, v in autores.items() if v and v.get("type", {}).get("key") == "/type/author"}
    return ediciones, autores


def linea(tipo, registro):
    """Una línea en el formato de los dumps: tipo, clave, revisión, fecha, JSON."""
    return "\t".join([
        tipo,
        registro["key"],
        str(registro.get("revision", 1)),
        fecha_texto(registro.get("last_modified")),
        json.dumps(registro, ensure_ascii=False),
    ])


def escribir_gz(ruta, lineas):
    with gzip.open(ruta, "wt", encoding="utf-8", newline="\n") as f:
        for l in lineas:
            f.write(l + "\n")


def filtrar_eventos(nombre, obras_ok, ediciones_ok):
    """Lee ratings o reading-log completo y conserva solo las filas de la muestra."""
    archivo = RAW / f"ol_dump_{nombre}_{FECHA_DUMP}.txt.gz"
    salida = []
    with gzip.open(archivo, "rt", encoding="utf-8", errors="replace") as f:
        for linea_txt in f:
            partes = linea_txt.rstrip("\n").split("\t")
            if len(partes) != 4 or partes[0] not in obras_ok:
                continue
            edicion = partes[1] if partes[1] in ediciones_ok else r"\N"
            salida.append("\t".join([partes[0], edicion, partes[2], partes[3]]))
    return salida


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--obras", type=int, default=200, help="número de obras (por defecto 200)")
    ap.add_argument("--ediciones", type=int, default=8, help="ediciones por obra (por defecto 8)")
    args = ap.parse_args()

    inicio = time.time()
    print("1/5 Contando eventos en ratings y reading-log...", flush=True)
    conteo = contar_eventos()
    print(f"   {len(conteo)} obras distintas con eventos")

    print("2/5 Eligiendo obras...", flush=True)
    obras = elegir_obras(conteo, args.obras)
    obras_ok = {o["key"] for o in obras}

    print("3/5 Descargando ediciones y autores de la API...", flush=True)
    ediciones, autores = recolectar(obras, args.ediciones)
    ediciones_ok = set(ediciones)

    print("4/5 Filtrando valoraciones y lecturas...", flush=True)
    valoraciones = filtrar_eventos("ratings", obras_ok, ediciones_ok)
    lecturas = filtrar_eventos("reading-log", obras_ok, ediciones_ok)

    print("5/5 Escribiendo la muestra...", flush=True)
    SALIDA.mkdir(exist_ok=True)
    escribir_gz(SALIDA / "muestra_works.tsv.gz", (linea("/type/work", o) for o in obras))
    escribir_gz(SALIDA / "muestra_editions.tsv.gz", (linea("/type/edition", e) for e in ediciones.values()))
    escribir_gz(SALIDA / "muestra_authors.tsv.gz", (linea("/type/author", a) for a in autores.values()))
    escribir_gz(SALIDA / "muestra_ratings.tsv.gz", valoraciones)
    escribir_gz(SALIDA / "muestra_reading-log.tsv.gz", lecturas)

    resumen = {
        "obras": len(obras),
        "ediciones": len(ediciones),
        "autores": len(autores),
        "valoraciones": len(valoraciones),
        "lecturas": len(lecturas),
        "ediciones_por_obra_maximo": args.ediciones,
        "fuente_eventos": f"dumps {FECHA_DUMP}",
        "fuente_registros": "API pública de Open Library (estado actual)",
    }
    (SALIDA / "resumen.json").write_text(json.dumps(resumen, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(resumen, indent=2, ensure_ascii=False))
    print(f"Listo en {time.time() - inicio:.0f} s")


if __name__ == "__main__":
    main()
