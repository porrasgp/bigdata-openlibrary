# 05 · Carga en PostgreSQL

Exporta las tablas curadas de HDFS a CSV y las carga en PostgreSQL con `COPY`. Después llena el esquema estrella.

## Qué contiene esta carpeta

| Archivo | Qué hace |
|---|---|
| `tablas.py` | Lista de tablas y sus columnas, en orden de carga. Lo usan los otros dos scripts |
| `exportar_csv.py` | Spark: lee `curated` de HDFS y escribe CSV sin cabecera en `data/export/` |
| `cargar_postgres.py` | psycopg: crea los esquemas y carga los CSV con `COPY` |
| `construir_estrella.sql` | Llena las dimensiones y los hechos del esquema `estrella` desde `openlibrary` |
| `verificar_carga.sql` | Conteos por tabla y tamaño en disco |

## Qué se hizo

1. **Exportación con control de formato.** Spark escribe CSV con comillas dobles (RFC 4180), sin recortar espacios y con nulos como campo vacío. Cada decisión tiene un comentario en `exportar_csv.py`, porque sin ellas `COPY` carga datos alterados.
2. **Carga con `COPY`**, no con `INSERT`. Para volúmenes grandes es mucho más rápido. Las tablas se cargan en orden de dependencias.
3. **Restricciones activas**: `COPY` respeta PK, FK y CHECK. Si un dato no cumple, la carga se detiene y dice qué fila y qué restricción.
4. **Esquema estrella** construido con SQL puro, desde el modelo normalizado, y repetible (`TRUNCATE ... RESTART IDENTITY`).
5. Probamos la carga completa con la muestra en PostgreSQL 16. Resultado: 200 obras, 381 autores, 878 editoriales, 47 443 valoraciones, 1 160 547 lecturas, con ningún error de restricción.

Durante la prueba encontramos y corregimos dos problemas:

- Dos editoriales con el mismo nombre, una con espacio final: `COPY` lo detectó con la restricción `UNIQUE`. Se corrigió recortando los nombres antes de deduplicar (`02_clean_a_curated.py`).
- Spark quitaba los espacios finales al escribir el CSV. Se desactivó con `ignoreTrailingWhiteSpace=false`.

## Qué necesitas para ejecutarlo

- Curated en HDFS (`../03_limpieza_spark/02_clean_a_curated.py` terminado).
- PostgreSQL 18 en marcha (`../00_setup/README.md`, sección 4).
- Entorno cargado: `source ../00_setup/env.sh`. Define `PGHOST`, `PGUSER` y `PGDATABASE`.
- Espacio: los CSV del dataset completo ocupan varias decenas de gigas; PostgreSQL con índices, otras tantas.

## Cómo ejecutarlo

```bash
cd ~/bigdata-openlibrary/05_carga_postgres
source ../00_setup/env.sh

# 1. Exportar las tablas curadas a CSV (Spark)
python3 exportar_csv.py

# 2. Crear esquemas y cargar (borra lo anterior con --reiniciar)
python3 cargar_postgres.py --reiniciar

# 3. Verificar
psql -f verificar_carga.sql
```

Salida esperada con la muestra:

```
>> obra: 200 filas
>> autor: 381 filas
>> editorial: 878 filas
...
>> valoracion: 47443 filas
>> lectura: 1160547 filas
Esquema estrella construido.
```

## Qué debes entender

**Por qué `COPY` y no `INSERT`.** `INSERT` procesa una fila por sentencia. `COPY` lee un flujo continuo y reduce el coste por fila a casi nada. Por eso el script lee los CSV en bloques de 1 MB y los envía por el mismo canal.

**Por qué el orden de carga importa.** Una FK exige que la fila apuntada ya exista. Por eso se cargan primero `obra`, `autor` y `editorial`, después `edicion` y al final las relaciones y los hechos. `tablas.py` tiene el orden.

**Por qué no cargamos Parquet directamente.** PostgreSQL no lee Parquet. Podríamos usar una extensión o cargar fila a fila desde Python, pero `COPY` lee CSV de forma nativa y el CSV lo puede abrir cualquiera en un editor.

**Nulos: vacío sin comillas.** En CSV, `,,` es un nulo y `,"",` es una cadena vacía. `COPY ... FORMAT csv` distingue las dos cosas. Por eso Spark se configura para escribir así (ver `exportar_csv.py`).

**Por qué `TRUNCATE` en el estrella.** Si ejecutas `construir_estrella.sql` dos veces, sin `TRUNCATE` duplicarías los hechos. Con él, el resultado es siempre el mismo.

**Tamaño en disco.** `verificar_carga.sql` usa `pg_total_relation_size`, que incluye índices. Es la cifra que cuenta para el disco de la VM. Compárala con el tamaño de los CSV: la base casi siempre ocupa más.

## Problemas frecuentes

| Síntoma | Causa | Solución |
|---|---|---|
| `Las tablas ya existen` | Carga anterior | `python3 cargar_postgres.py --reiniciar` |
| `No existe ../data/export` | No ejecutaste la exportación | `python3 exportar_csv.py` |
| `connection refused` o `could not connect` | PostgreSQL apagado | `sudo systemctl start postgresql` y revisa `PGHOST` |
| `password authentication failed` | Usuario con contraseña | Exporta `PGPASSWORD` o configura `peer` en `pg_hba.conf` |
| `duplicate key value violates unique constraint` | Datos repetidos en la fuente | Revisa el paso de deduplicación en `02_clean_a_curated.py` |
| `invalid input syntax for type` | Un CSV tiene un valor con formato inesperado | Busca la columna en el mensaje y revisa el tipo en `ddl_normalizado.sql` |
| La carga de `lectura` tarda mucho | Son millones de filas | Normal; con el dataset completo puede tardar bastante más |
