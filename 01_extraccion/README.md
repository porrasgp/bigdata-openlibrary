# 01 · Extracción

## Qué contiene esta carpeta

| Archivo | Para qué sirve | Tiempo aprox. |
|---|---|---|
| `descargar_dumps.sh` | Descarga los dumps con fecha fija y verifica tamaño y SHA-256 | 1 a 3 horas (17.6 GB) |
| `construir_muestra.py` | Construye la muestra coherente de `muestra/` desde la API pública | 10 a 15 minutos |
| `convertir_a_csv.py` | Convierte los dumps (TSV con JSON) a CSV plano | Horas con dumps completos |

## Qué se hizo

1. **Verificamos las URLs y tamaños** de los dumps de la fecha 2026-10-31. El tamaño total comprimido es de 17.6 GB; la página oficial indicaba cifras antiguas.
2. **Descargador con verificación**: comprueba el tamaño contra el servidor, reanuda descargas cortadas y guarda el SHA-256 en `data/raw/manifiesto_2026-10-31.tsv`. Lo probamos con `ratings` y `reading-log`, y el hash coincide con el manifiesto.
3. **Muestra coherente**: las primeras líneas de cada dump no sirven, porque las obras, ediciones y autores de la muestra no se referían entre sí y las tablas de relación quedaban vacías. La muestra actual toma las 200 obras con más valoraciones y lecturas en los dumps completos, y trae de la API sus ediciones y autores. Resultado: 200 obras, 1 507 ediciones, 381 autores, 47 443 valoraciones y 1 160 547 lecturas, sin ninguna clave rota.
4. **Conversor a CSV**: convierte cada dump a CSV plano, con los campos del JSON como columnas. Usa solo la biblioteca estándar de Python, así que no necesita Spark.

## Qué necesitas para ejecutarlo

- Entorno del curso cargado (`source ../00_setup/env.sh`) para `descargar_dumps.sh`: solo necesita `curl`, `gzip` y `sha256sum`.
- Python 3.11 o superior para los scripts `.py`. No necesitan Spark.
- Conexión a internet. Los dumps pesan 17.6 GB; con 10 Mbps tardan unas 4 horas.
- Espacio: unos 20 GB para los dumps y 60 MB para la muestra.

## Cómo ejecutarlo

```bash
cd ~/bigdata-openlibrary/01_extraccion

# 1. Dumps completos (todos, o solo algunos):
./descargar_dumps.sh                       # los 5 dumps
./descargar_dumps.sh ratings reading-log   # solo los pequeños (~135 MB)

# 2. Muestra coherente (necesita ratings y reading-log descargados):
python3 construir_muestra.py                # 200 obras, 8 ediciones por obra
python3 construir_muestra.py --obras 50     # más rápido, para probar

# 3. CSV para explorar con pandas, Excel o LibreOffice:
python3 convertir_a_csv.py --todo ../muestra --salida ../muestra/csv
python3 convertir_a_csv.py --todo ../data/raw --salida ../data/csv   # dumps completos (lento)
```

Para verificar que los dumps descargados son íntegros:

```bash
cd ../data/raw
sha256sum -c <(awk -F'\t' 'NR>1{print $3"  "$1}' manifiesto_2026-10-31.tsv)
```

## Qué debes entender

**Formato de los dumps.** Son archivos TSV sin cabecera:

- `editions`, `works`, `authors`: `tipo <TAB> clave <TAB> revision <TAB> fecha <TAB> JSON`.
- `ratings`: `obra <TAB> edicion <TAB> valoracion <TAB> fecha` (sin usuario).
- `reading-log`: `obra <TAB> edicion <TAB> estado <TAB> fecha`.

`\N` marca un nulo. El JSON va dentro de la última columna; eso obliga a parsearlo en la limpieza.

**Por qué la verificación de hash.** Si dos alumnos descargan el "mismo" dump y tienen hashes distintos, sus resultados no se pueden comparar. La fecha fija (2026-10-31) y el manifiesto garantizan que todos trabajan con los mismos datos.

**Por qué una muestra y no solo los dumps.** Para probar un pipeline no hace falta procesar 17 GB; con pocos megabytes ya aparecen muchos errores de código. Pero la muestra tiene que ser coherente: si una valoración apunta a una obra que no está en la muestra, la prueba de integridad referencial falla por una razón que no es un error del código.

**Por qué la API y no solo los dumps para la muestra.** La API devuelve el estado actual de cada registro, y los dumps son de una fecha fija. La muestra no es idéntica al dump de 2026-10-31, pero es consistente consigo misma. Está escrito en `muestra/resumen.json`.

**Respeto a la API.** `construir_muestra.py` identifica su User-Agent, espera 0.5 s entre peticiones, reintenta con espera si el servidor responde 429 o 5xx, y guarda cada respuesta en `data/cache_api/` para no volver a pedir lo mismo. `robots.txt` no prohíbe `/works/` ni `/authors/`. No uses `/api` ni `/search`, que sí están prohibidos.

**Licencia.** Los datos son CC0 1.0 (dominio público), así que pueden copiarse y redistribuirse. Cítalos de todos modos.

## Problemas frecuentes

| Síntoma | Causa | Solución |
|---|---|---|
| `Tamaño incorrecto` al descargar | Descarga interrumpida | Vuelve a ejecutar el script: continúa desde donde quedó |
| `No se pudo obtener el tamaño` | Sin internet o servidor caído | Revisa la conexión y reintenta más tarde |
| `Falta .../ol_dump_ratings_...` al construir la muestra | No descargaste los dumps | `./descargar_dumps.sh ratings reading-log` |
| La muestra tarda mucho | Limitación de la API (0.5 s por petición) | Usa `--obras 50` para probar |
| `HTTP 429` en la consola | Demasiadas peticiones | El script espera y reintenta solo |
