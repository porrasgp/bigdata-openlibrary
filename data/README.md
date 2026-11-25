# `data/` — capas generadas por el ETL

Esta carpeta **no se sube a Git** (`.gitignore`). Se crea cada vez que ejecutas:

```bash
bash ejecutar_todo.sh
```

| Subcarpeta | Contenido | Lo produce |
|---|---|---|
| `data/bronze/` | Copia exacta de `muestra/csv/*.csv` y un `_MANIFEST.csv` con SHA-256 | `etl/01_bronze.py` |
| `data/silver/` | CSV limpios, deduplicados y validados | `etl/02_silver.py` |
| `data/silver/_rechazados/` | Filas que no pasaron las reglas, con el motivo | `etl/02_silver.py` |
| `data/gold/` | Modelo estrella y agregaciones listas para análisis | `etl/03_gold.py` |

Los CSV originales que sí se versionan están en [`muestra/csv/`](../muestra/csv/). Aquí solo hay resultados intermedios que se pueden regenerar.

## Destinos posteriores del gold

El contenido de `data/gold/` se publica en dos sitios cuando ejecutas el flujo completo:

| Destino | Script | Ruta/esquema |
|---|---|---|
| HDFS | [`hdfs/cargar_gold.sh`](../hdfs/cargar_gold.sh) | `/medallion/gold/fecha=FECHA/` |
| PostgreSQL | [`postgres/cargar_gold.py`](../postgres/cargar_gold.py) | esquema `estrella` |

El lanzador de todo es [`ejecutar_todo_completo.sh`](../ejecutar_todo_completo.sh) y el procedimiento manual está en [`manual/manual.pdf`](../manual/manual.pdf).
