#!/usr/bin/env python3
"""Carga en PostgreSQL los CSV de data/gold con COPY.

El origen es la salida del ETL medallion (modelo estrella). No se usa HDFS
como intermediario: los CSV se leen directamente desde disco.

Pasos:
  1. Ejecuta sql/ddl.sql (esquema estrella con PK, FK y CHECK).
  2. Carga cada tabla con COPY ... FROM STDIN, en orden de dependencias.
  3. Muestra el número de filas de cada tabla.

Conexión: variables estándar de libpq (PGHOST, PGPORT, PGUSER, PGDATABASE).
Con --reiniciar se borra y recrea el esquema estrella; es repetible.

Uso:
  python3 postgres/cargar_gold.py --reiniciar
"""

import argparse
import sys
import time
from pathlib import Path

import psycopg

RAIZ = Path(__file__).resolve().parent.parent
DDL = RAIZ / "sql" / "ddl.sql"
GOLD = RAIZ / "data" / "gold"
TAMANO_BLOQUE = 1 << 20  # 1 MB

# Orden: primero las dimensiones, después los hechos y por último el resumen.
TABLAS = (
    ("dim_obra", ("obra_sk", "clave_obra", "titulo", "anio_primera_publicacion", "num_portadas")),
    ("dim_fecha", ("fecha", "anio", "trimestre", "mes", "dia", "decada")),
    ("fact_valoracion", ("fecha", "obra_sk", "valor")),
    ("fact_lectura", ("fecha", "obra_sk", "estado")),
    ("resumen_valoraciones_anio", ("anio", "valoraciones", "valor_promedio")),
)


def reiniciar(conn):
    with conn.cursor() as cur:
        cur.execute("DROP SCHEMA IF EXISTS estrella CASCADE")
    conn.commit()
    print("Esquema estrella anterior eliminado.", flush=True)


def crear_esquema(conn):
    if not DDL.exists():
        sys.exit(f"No existe {DDL}. No se puede crear el esquema.")
    with conn.cursor() as cur:
        cur.execute(DDL.read_text(encoding="utf-8"))
    conn.commit()
    print("Esquema estrella creado desde sql/ddl.sql.", flush=True)


def cargar_tabla(conn, tabla, columnas, ruta):
    inicio = time.time()
    lista = ", ".join(columnas)
    consulta = f"COPY estrella.{tabla} ({lista}) FROM STDIN WITH (FORMAT csv, HEADER true)"

    with conn.cursor() as cur:
        with cur.copy(consulta) as copia:
            with open(ruta, encoding="utf-8", newline="") as archivo:
                while bloque := archivo.read(TAMANO_BLOQUE):
                    copia.write(bloque)
    conn.commit()

    with conn.cursor() as cur:
        cur.execute(f"SELECT count(*) FROM estrella.{tabla}")
        filas = cur.fetchone()[0]
    print(f">> {tabla}: {filas} filas ({time.time() - inicio:.1f} s)", flush=True)


def main():
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("--reiniciar", action="store_true",
                    help="borra el esquema estrella antes de crear los CSV")
    ap.add_argument("--gold", default=str(GOLD),
                    help="carpeta con los CSV generados (por defecto data/gold)")
    args = ap.parse_args()

    gold = Path(args.gold).resolve()
    for tabla, _ in TABLAS:
        if not (gold / f"{tabla}.csv").exists():
            sys.exit(f"No existe {gold / (tabla + '.csv')}. Ejecuta antes: bash ejecutar_todo.sh")

    try:
        with psycopg.connect() as conn:
            if args.reiniciar:
                reiniciar(conn)
            crear_esquema(conn)
            for tabla, columnas in TABLAS:
                cargar_tabla(conn, tabla, columnas, gold / f"{tabla}.csv")
    except psycopg.errors.DuplicateTable:
        sys.exit("Las tablas ya existen. Usa --reiniciar para recrearlas.")
    except psycopg.OperationalError as exc:
        sys.exit(
            f"No se pudo conectar a PostgreSQL ({exc}). "
            "Revisa PGHOST, PGPORT, PGUSER y PGDATABASE."
        )

    print("Carga terminada.", flush=True)
    print("Verifica con: psql -v ON_ERROR_STOP=1 -f sql/verificar.sql", flush=True)


if __name__ == "__main__":
    main()
