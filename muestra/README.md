# `muestra/` — CSV de ejemplo

Esta carpeta contiene los **únicos datos que se versionan** en el repo: cinco CSV coherentes entre sí (obra, autor, edición, valoración y estado de lectura).

| Archivo | Filas aprox. | Descripción |
|---|---:|---|
| `csv/authors.csv` | 381 | Autores |
| `csv/works.csv` | 200 | Obras |
| `csv/editions.csv` | ~1.500 | Ediciones |
| `csv/ratings.csv` | ~47.000 | Valoraciones de 1 a 5 |
| `csv/reading-log.csv` | ~1.160.000 | Cambios de estado de lectura |

Estos archivos son la entrada del pipeline. `etl/01_bronze.py` los copia a `data/bronze/` sin modificarlos; a partir de ahí se aplica la arquitectura medallion.

No hacen falta dumps comprimidos ni descargas adicionales: con estos CSV el pipeline completo tarda menos de un minuto.

Para entender el flujo, lee [`docs/flujo.md`](../docs/flujo.md).
