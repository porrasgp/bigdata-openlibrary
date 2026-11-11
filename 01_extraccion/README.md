# 01 · Extracción

Objetivo: obtener los dumps de Open Library con una fecha fija y verificar que llegaron completos.

## Fuente

- Portal: https://openlibrary.org/developers/dumps
- Snapshot del curso: **2026-10-31**
- Licencia: CC0 1.0. Puedes reutilizar y redistribuir los datos sin restricciones.

| Archivo | Tamaño esperado |
|---|---|
| `ol_dump_editions_2026-10-31.txt.gz` | 12 630 804 778 bytes (12.6 GB) |
| `ol_dump_works_2026-10-31.txt.gz` | 4 078 855 962 bytes (4.1 GB) |
| `ol_dump_authors_2026-10-31.txt.gz` | 784 183 875 bytes (0.8 GB) |
| `ol_dump_ratings_2026-10-31.txt.gz` | 9 422 757 bytes (9 MB) |
| `ol_dump_reading-log_2026-10-31.txt.gz` | 125 242 203 bytes (125 MB) |

## Formato

Archivos TSV sin cabecera. Hay dos formatos:

**editions, works, authors** (5 columnas):

```
type <TAB> key <TAB> revision <TAB> last_modified <TAB> JSON
/type/edition <TAB> /books/OL10000008M <TAB> 3 <TAB> 2026-01-03T18:14:02 <TAB> {"title": "...", ...}
```

**ratings** (4 columnas): `obra <TAB> edición <TAB> valoración <TAB> fecha`

```
/works/OL1629179W <TAB> /books/OL22981670M <TAB> 5 <TAB> 2018-06-20
```

**reading-log** (4 columnas): `obra <TAB> edición <TAB> estado <TAB> fecha`

```
/works/OL3910802W <TAB> \N <TAB> Already Read <TAB> 2026-08-28
```

Notas:
- `\N` es un nulo (la edición no está asociada). Hay que tratarlo en la limpieza de la semana 2.
- Ejemplos de `key`: `/books/OL1M`, `/works/OL45883W`, `/authors/OL23919A`.
- Los JSON pueden tener cientos de bytes o varios KB; por eso el tamaño descomprimido es mucho mayor que el comprimido.

## Uso

```bash
# Muestra rápida (~50 000 líneas por dump, sin bajar todo):
./descargar_dumps.sh --solo-muestra

# Descarga completa (~17.6 GB; se puede reanudar si se corta):
./descargar_dumps.sh
```

Los archivos quedan en `data/raw/` y el manifiesto con SHA-256 en `data/raw/manifiesto_2026-10-31.tsv`.

Para comprobar la integridad más tarde:

```bash
cd ../data/raw
sha256sum -c <(awk -F'\t' 'NR>1{print $3"  "$1}' manifiesto_2026-10-31.tsv)
```

## Notas

- Si la descarga tarda demasiado, el portal ofrece torrents en el Internet Archive (`archive.org/details/ol_exports`).
- Tus alumnos pueden compartir una copia verificada en lugar de descargar cada uno. La comparación del manifiesto sirve para confirmar que es idéntica.
