# muestra/ · Datos de prueba

Subconjunto coherente de Open Library para probar el pipeline sin descargar 17 GB.

## Qué contiene

| Archivo | Filas | Contenido |
|---|---:|---|
| `muestra_works.tsv.gz` | 200 | Obras (formato de los dumps) |
| `muestra_editions.tsv.gz` | 1 507 | Ediciones de esas obras (hasta 8 por obra) |
| `muestra_authors.tsv.gz` | 381 | Autores de las obras y ediciones |
| `muestra_ratings.tsv.gz` | 47 443 | Valoraciones de esas obras |
| `muestra_reading-log.tsv.gz` | 1 160 547 | Lecturas de esas obras |
| `csv/*.csv` | igual | Los mismos datos en CSV, con los campos del JSON como columnas |
| `resumen.json` | — | Cómo se construyó la muestra |

## Qué se hizo

1. Contamos valoraciones y lecturas por obra en los dumps completos y elegimos las 200 obras con más eventos.
2. Pedimos a la API pública de Open Library sus ediciones y autores (con límite de tasa y caché).
3. Filtramos valoraciones y lecturas para que solo apunten a esas obras.
4. Escribimos los archivos con el mismo formato que los dumps, y los exportamos a CSV con `01_extraccion/convertir_a_csv.py`.

Detalles y motivos en `../01_extraccion/README.md`.

## Qué necesitas para usarla

- Nada más que este repositorio. No hace falta conexión a internet.
- Para el pipeline: HDFS con la muestra cargada (`../02_hdfs/cargar_raw.sh ../muestra muestra`).
- Para explorar los CSV: cualquier editor, LibreOffice, o `pandas.read_csv`.

## Cómo usarla

```bash
# Explorar en la terminal
head -3 csv/works.csv
python3 -c "import pandas as pd; print(pd.read_csv('csv/editions.csv').head())"
```

Los CSV de `reading-log` y `ratings` tienen cabecera; los de `csv/` de las tablas de la base de datos no la tienen (son solo para explorar).

## Qué debes entender

- **Es una muestra, no un subconjunto aleatorio.** Se eligieron las obras más populares. Las conclusiones sobre el dataset completo no se pueden sacar de la muestra: está sesgada hacia las obras con más lectores.
- **La API no es el dump.** La muestra refleja el estado de la API cuando se construyó. Los números pueden no coincidir exactamente con los del dump de 2026-10-31.
- **Es coherente.** Cada clave de valoración, lectura o relación apunta a algo que está en la muestra. Por eso el pipeline pasa sin rechazos por integridad referencial.
- **Pesa 60 MB.** El archivo más grande es `muestra_reading-log.tsv.gz` (4.4 MB comprimido, 1.1 M filas).
