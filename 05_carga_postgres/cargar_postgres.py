#!/usr/bin/env python3
"""Crea el esquema en PostgreSQL y carga los CSV exportados con COPY.

Pasos:
  1. Crea los esquemas openlibrary y estrella (ddl_normalizado.sql, ddl_estrella.sql).
     Con --reiniciar, borra antes los esquemas existentes.
  2. Carga cada tabla con COPY desde los archivos part-*.csv, en orden de dependencias.
     Si una fila rompe una clave foránea o una restricción, COPY falla y dice cuál.
  3. Llena el esquema estrella (construir_estrella.sql).
  4. Muestra conteos y tamaño de cada tabla.

Conexión: variables de entorno estándar de PostgreSQL (libpq):
  PGHOST (por defecto localhost), PGPORT (5432), PGUSER, PGPASSWORD, PGDATABASE.

Uso:
  python3 cargar_postgres.py --reiniciar
"""

import argparse
import sys
import time
from pathlib import Path

import psycopg

from tablas import TABLAS

RAIZ = Path(__file__).resolve().parent.parent
DDL_NORMALIZADO = RAIZ / "04_modelado" / "ddl_normalizado.sql"
DDL_ESTRELLA = RAIZ / "04_modelado" / "ddl_estrella.sql"
CONSTRUIR_ESTRELLA = Path(__file__).resolve().parent / "construir_estrella.sql"
TAMANO_BLOQUE = 1 << 20  # 1 MB


def reiniciar_esquemas(conn):
    with conn.cursor() as cur:
        cur.execute("DROP SCHEMA IF EXISTS estrella CASCADE")
        cur.execute("DROP SCHEMA IF EXISTS openlibrary CASCADE")
    conn.commit()
    print("Esquemas anteriores eliminados.")


def crear_esquemas(conn):
    with conn.cursor() as cur:
        cur.execute(DDL_NORMALIZADO.read_text(encoding="utf-8"))
        cur.execute(DDL_ESTRELLA.read_text(encoding="utf-8"))
    conn.commit()
    print("Esquemas creados.")


def cargar_tabla(conn, tabla, columnas, carpeta):
    partes = sorted(carpeta.glob("part-*.csv"))
    if not partes:
        raise SystemExit(f"No hay archivos part-*.csv en {carpeta}. Ejecuta antes exportar_csv.py.")

    inicio = time.time()
    lista = ", ".join(columnas)
    with conn.cursor() as cur:
        with cur.copy(f"COPY openlibrary.{tabla} ({lista}) FROM STDIN WITH (FORMAT csv)") as copia:
            for parte in partes:
                with open(parte, encoding="utf-8", newline="") as f:
                    while bloque := f.read(TAMANO_BLOQUE):
                        copia.write(bloque)
    conn.commit()
    with conn.cursor() as cur:
        cur.execute(f"SELECT count(*) FROM openlibrary.{tabla}")
        filas = cur.fetchone()[0]
    print(f">> {tabla}: {filas} filas ({time.time() - inicio:.1f} s)", flush=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--export", default=str(RAIZ / "data" / "export"),
                    help="carpeta con las tablas exportadas (por defecto ../data/export)")
    ap.add_argument("--reiniciar", action="store_true",
                    help="borra los esquemas openlibrary y estrella antes de crearlos")
    args = ap.parse_args()

    export = Path(args.export).resolve()
    if not export.exists():
        sys.exit(f"No existe {export}. Ejecuta antes exportar_csv.py.")

    with psycopg.connect() as conn:
        if args.reiniciar:
            reiniciar_esquemas(conn)
        try:
            crear_esquemas(conn)
        except psycopg.errors.DuplicateTable:
            sys.exit("Las tablas ya existen. Usa --reiniciar para recrearlas.")

        for tabla, columnas in TABLAS.items():
            cargar_tabla(conn, tabla, columnas, export / tabla)

        with conn.cursor() as cur:
            cur.execute(CONSTRUIR_ESTRELLA.read_text(encoding="utf-8"))
        conn.commit()
        print("Esquema estrella construido.")

    print("Carga terminada. Verifica con: psql -f verificar_carga.sql")


if __name__ == "__main__":
    main()
