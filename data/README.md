# data/ · Datos locales (no se suben a GitHub)

Esta carpeta está en `.gitignore`. Contiene los datos grandes que descargas tú. Este README sí se sube, para que sepas qué poner aquí.

## Qué contiene (al terminar el curso)

| Carpeta | Contenido | Tamaño aprox. | Lo genera |
|---|---|---|---|
| `raw/` | Dumps comprimidos (`.txt.gz`) y `manifiesto_2026-10-31.tsv` | 17.6 GB | `01_extraccion/descargar_dumps.sh` |
| `cache_api/` | Respuestas de la API pública, una por archivo | 10–50 MB | `01_extraccion/construir_muestra.py` |
| `export/` | CSV de las tablas curadas, para `COPY` | 10–20 GB | `05_carga_postgres/exportar_csv.py` |
| `csv/` | CSV de los dumps completos | Varias decenas de GB | `01_extraccion/convertir_a_csv.py` (opcional) |

Las tablas de HDFS (`/clean`, `/curated`) no están aquí: viven en HDFS.

## Qué necesitas

- Unos **60 GB libres** para `raw/` y `export/`, más lo que ocupe PostgreSQL. Con los 120 GB de la VM hay margen si no duplicas `csv/`.
- Si borras `raw/`, no pierdes nada del pipeline siempre que conserves la copia en HDFS (`/raw/openlibrary/`).

## Cómo verificar lo que tienes

```bash
cd ~/bigdata-openlibrary/data/raw
sha256sum -c <(awk -F'\t' 'NR>1{print $3"  "$1}' manifiesto_2026-10-31.tsv)
du -sh ~/bigdata-openlibrary/data/*
```
