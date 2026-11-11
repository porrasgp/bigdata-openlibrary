#!/usr/bin/env python3
"""Convierte los dumps TSV de Open Library a CSV con columnas planas.

Los dumps de editions, works y authors traen un JSON por línea. Este script
extrae los campos útiles a columnas. Las listas se separan con "|".
ratings y reading-log ya son tabulares; solo se les pone cabecera.

Usa solo la biblioteca estándar y lee en streaming: no carga el archivo en memoria.

Uso:
  # Un archivo:
  python3 convertir_a_csv.py --entrada muestra/muestra_editions.tsv.gz --tipo editions --salida muestra/csv/editions.csv

  # Todos los dumps de una carpeta (detecta el tipo por el nombre del archivo):
  python3 convertir_a_csv.py --todo data/raw --salida data/csv
"""

import argparse
import csv
import gzip
import json
import re
import sys
from pathlib import Path

SEP = "|"  # separador para valores múltiples dentro de una celda

COLUMNAS = {
    "editions": [
        "clave", "revision", "ultima_modificacion", "titulo", "subtitulo",
        "fecha_publicacion", "editoriales", "isbn_10", "isbn_13", "paginas",
        "formato_fisico", "idiomas", "autores_claves", "obras_claves",
        "temas", "num_portadas",
    ],
    "works": [
        "clave", "revision", "ultima_modificacion", "titulo", "subtitulo",
        "fecha_primera_publicacion", "autores_claves", "temas",
        "num_portadas", "descripcion",
    ],
    "authors": [
        "clave", "revision", "ultima_modificacion", "nombre",
        "nombre_personal", "fecha_nacimiento", "fecha_muerte",
        "nombres_alternativos",
    ],
    "ratings": ["obra_clave", "edicion_clave", "valoracion", "fecha"],
    "reading-log": ["obra_clave", "edicion_clave", "estado", "fecha"],
}

# Nombre de archivo del dump -> tipo
PATRON_TIPO = re.compile(r"ol_dump_(editions|works|authors|ratings|reading-log)_")


def texto(valor):
    """Convierte a texto; None y \\N pasan a vacío."""
    if valor is None or valor == r"\N":
        return ""
    return str(valor)


def unir(lista):
    """Une una lista de textos con SEP. Acepta listas de strings o dicts con 'key'."""
    if not lista:
        return ""
    partes = []
    for x in lista:
        if isinstance(x, dict):
            x = x.get("key", "")
        if x:
            partes.append(str(x))
    return SEP.join(partes)


def descripcion_texto(valor):
    """Algunos campos 'description' son {'type':..., 'value': '...'} y otros texto plano."""
    if isinstance(valor, dict):
        return valor.get("value", "") or ""
    return valor or ""


def fila_edicion(registro, clave, revision, modificado):
    return [
        clave, revision, modificado,
        texto(registro.get("title")),
        texto(registro.get("subtitle")),
        texto(registro.get("publish_date")),
        unir(registro.get("publishers")),
        unir(registro.get("isbn_10")),
        unir(registro.get("isbn_13")),
        texto(registro.get("number_of_pages")),
        texto(registro.get("physical_format")),
        unir(registro.get("languages")),
        unir(registro.get("authors")),
        unir(registro.get("works")),
        unir(registro.get("subjects")),
        len(registro.get("covers") or []),
    ]


def fila_obra(registro, clave, revision, modificado):
    autores = []
    for a in registro.get("authors") or []:
        autor = a.get("author") if isinstance(a, dict) else None
        if isinstance(autor, dict) and autor.get("key"):
            autores.append(autor["key"])
    return [
        clave, revision, modificado,
        texto(registro.get("title")),
        texto(registro.get("subtitle")),
        texto(registro.get("first_publish_date")),
        SEP.join(autores),
        unir(registro.get("subjects")),
        len(registro.get("covers") or []),
        descripcion_texto(registro.get("description")),
    ]


def fila_autor(registro, clave, revision, modificado):
    return [
        clave, revision, modificado,
        texto(registro.get("name")),
        texto(registro.get("personal_name")),
        texto(registro.get("birth_date")),
        texto(registro.get("death_date")),
        unir(registro.get("alternate_names")),
    ]


CONVERTIDORES_JSON = {
    "editions": fila_edicion,
    "works": fila_obra,
    "authors": fila_autor,
}


def convertir(entrada, tipo, salida):
    """Convierte un dump. Devuelve (filas_escritas, filas_descartadas)."""
    if tipo not in COLUMNAS:
        raise ValueError(f"Tipo desconocido: {tipo}")

    escritas = descartadas = 0
    salida = Path(salida)
    salida.parent.mkdir(parents=True, exist_ok=True)

    abrir = gzip.open if str(entrada).endswith(".gz") else open
    with abrir(entrada, "rt", encoding="utf-8", errors="replace") as fin, \
         open(salida, "w", encoding="utf-8", newline="") as fout:
        escritor = csv.writer(fout, quoting=csv.QUOTE_MINIMAL)
        escritor.writerow(COLUMNAS[tipo])

        if tipo in CONVERTIDORES_JSON:
            convertir_fila = CONVERTIDORES_JSON[tipo]
            for linea in fin:
                partes = linea.rstrip("\n").split("\t")
                if len(partes) != 5:
                    descartadas += 1
                    continue
                try:
                    registro = json.loads(partes[4])
                except json.JSONDecodeError:
                    descartadas += 1
                    continue
                escritor.writerow(convertir_fila(registro, partes[1], partes[2], partes[3]))
                escritas += 1
        else:
            # ratings (4 columnas) y reading-log (4 columnas): ya son tabulares
            for linea in fin:
                partes = linea.rstrip("\n").split("\t")
                if len(partes) != 4:
                    descartadas += 1
                    continue
                escritor.writerow([texto(p) for p in partes])
                escritas += 1

    return escritas, descartadas


def tipo_desde_nombre(ruta):
    m = PATRON_TIPO.search(Path(ruta).name)
    return m.group(1) if m else None


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    grupo = ap.add_mutually_exclusive_group(required=True)
    grupo.add_argument("--entrada", help="archivo TSV (.txt.gz o .txt)")
    grupo.add_argument("--todo", metavar="CARPETA", help="convierte todos los dumps de la carpeta")
    ap.add_argument("--tipo", choices=sorted(COLUMNAS), help="tipo de dump (con --entrada)")
    ap.add_argument("--salida", required=True, help="archivo CSV (con --entrada) o carpeta (con --todo)")
    args = ap.parse_args()

    if args.entrada:
        tipo = args.tipo or tipo_desde_nombre(args.entrada)
        if not tipo:
            ap.error("no se pudo detectar el tipo; usa --tipo")
        pares = [(args.entrada, tipo, args.salida)]
    else:
        carpeta = Path(args.todo)
        pares = []
        for archivo in sorted(carpeta.glob("*ol_dump_*.txt.gz")) + sorted(carpeta.glob("muestra_*.tsv.gz")):
            tipo = tipo_desde_nombre(archivo) or re.sub(r"^muestra_|\.tsv\.gz$", "", archivo.name)
            if tipo not in COLUMNAS:
                continue
            pares.append((archivo, tipo, Path(args.salida) / f"{tipo}.csv"))
        if not pares:
            print(f"No encontré dumps en {carpeta}", file=sys.stderr)
            sys.exit(1)

    for entrada, tipo, salida in pares:
        print(f">> {tipo}: {entrada} -> {salida}", flush=True)
        escritas, descartadas = convertir(entrada, tipo, salida)
        print(f"   {escritas} filas escritas, {descartadas} descartadas", flush=True)


if __name__ == "__main__":
    main()
