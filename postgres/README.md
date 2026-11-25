# PostgreSQL — carga del modelo gold

Esta carpeta contiene el cargador PostgreSQL del proyecto. Toma los CSV de `data/gold/` y los inserta en el esquema `estrella` con `COPY`.

## Archivo

`cargar_gold.py` crea el esquema (usando `sql/ddl.sql`) y carga las cinco tablas en orden de dependencias: dimensiones → hechos → resumen.

## Uso manual

```bash
# Necesita psycopg: pip install -r requirements.txt
python3 postgres/cargar_gold.py --reiniciar

# Verificación y consultas
psql -v ON_ERROR_STOP=1 -f sql/verificar.sql
psql -v ON_ERROR_STOP=1 -f sql/consultas.sql
```

`--reiniciar` borra y recrea el esquema `estrella`, así que el proceso es repetible. Sin esa opción, si las tablas ya existen el script avisa para evitar borrar datos por accidente.

## Conexión

Se usan las variables estándar de PostgreSQL:

```bash
export PGHOST=localhost
export PGPORT=5432
export PGUSER=gsolano
export PGDATABASE=gsolano
```

El orquestador `ejecutar_todo_completo.sh` detecta los binarios de PostgreSQL, arranca el servidor si hace falta y crea el rol y la base si no existen.

## Conteos esperados con la muestra

| Tabla | Filas |
|---|---:|
| `estrella.dim_obra` | 200 |
| `estrella.dim_fecha` | 3.287 |
| `estrella.fact_valoracion` | 47.443 |
| `estrella.fact_lectura` | 1.160.547 |
| `estrella.resumen_valoraciones_anio` | 9 |

`sql/verificar.sql` también comprueba que no haya hechos huérfanos (deben dar 0).
