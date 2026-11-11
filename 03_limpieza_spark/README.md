# 03 · Limpieza y modelado con PySpark

Pipeline de tres pasos: **raw → clean → curated**. Cada paso escribe Parquet en HDFS.

## Qué contiene esta carpeta

| Archivo | Paso | Qué hace |
|---|---|---|
| `common.py` | — | Configuración (rutas, memoria, particiones) y creación de la SparkSession |
| `01_raw_a_clean.py` | raw → clean | Parsea el TSV y el JSON, valida, registra rechazados y deduplica |
| `02_clean_a_curated.py` | clean → curated | Construye el modelo normalizado (obras, autores, ediciones, relaciones N:M) |
| `03_comparar_particionado.py` | (opcional) | Mide el efecto del particionado con `PartitionFilters` |

## Qué se hizo

1. **Parseo robusto**: cada línea se separa en columnas con `split` y el JSON se parsea con `from_json` y un esquema explícito. Un campo con tipo distinto queda en `null`; no tumba el registro.
2. **Validación con motivos**: cada registro se marca con el primer error que tenga (clave inválida, JSON roto, título vacío, valoración fuera de 1–5, fecha inválida...). Los rechazados se guardan en `/clean/_rechazados/` con su línea original, para poder revisarlos.
3. **Deduplicación**: si una obra aparece varias veces, se queda con la revisión más alta (y, si empata, la modificada más tarde), usando una función de ventana.
4. **Modelo normalizado**: obras, autores, ediciones y editoriales, con las relaciones N:M como tablas intermedias. Las claves foráneas obligatorias que apuntan a algo inexistente se rechazan; las opcionales se ponen a `null` y se cuentan.
5. **Normalización antes de deduplicar**: descubrimos que `"Editorial X"` y `"Editorial X "` (con espacio final) eran dos filas. Ahora se recortan los nombres antes de asignarles id.
6. **Particionado**: `edicion` se guarda particionada por `decada`. El script 03 demuestra que una consulta sobre una década solo lee esa carpeta.

## Qué necesitas para ejecutarlo

- HDFS en marcha con `/raw/openlibrary/fecha=...` cargado (`../02_hdfs/`).
- Entorno cargado: `source ../00_setup/env.sh` (define `OL_RAW`, `OL_CLEAN`, `OL_CURATED`...).
- Java 17 y PySpark 4.3.0 (ver `../00_setup/README.md`).
- Memoria: con 8 GB de RAM en la VM, `SPARK_DRIVER_MEMORY=3g` deja margen para el sistema.

## Cómo ejecutarlo

```bash
cd ~/bigdata-openlibrary/03_limpieza_spark
source ../00_setup/env.sh

# Modo prueba con la muestra (segundos):
export OL_RAW=hdfs://localhost:8020/raw/openlibrary/fecha=muestra
export OL_PARTICIONES=4

python3 01_raw_a_clean.py          # todos los tipos
python3 01_raw_a_clean.py --tipos editions   # solo uno

python3 02_clean_a_curated.py
python3 03_comparar_particionado.py  # opcional
```

Para los dumps completos, quita las dos primeras líneas `export` (o vuelve a `source ../00_setup/env.sh`) y sube `OL_PARTICIONES` a 16 o más.

Para ver el resultado:

```bash
hdfs dfs -ls /clean/openlibrary
hdfs dfs -ls /curated/openlibrary
```

### Salida esperada con la muestra

```
>> editions
   rechazados: 3
     - titulo_vacio: 3
   limpio: 1504 filas -> .../clean/openlibrary/editions
>> reading-log
   limpio: 1160547 filas -> .../clean/openlibrary/reading_log
```

`02_clean_a_curated.py` imprime, para cada relación, cuántas filas se rechazan por clave inexistente. Con la muestra debe ser 0 en todas.

## Qué debes entender

**Por qué Parquet.** Es columnar y comprimido. Una consulta que solo usa 3 de 16 columnas lee solo esas 3. Para el dataset completo, la diferencia es de decenas de gigas.

**Por qué `repartition()` después de leer.** El `.gz` no se puede dividir, así que Spark lo lee con una sola tarea. `repartition(N)` reparte las filas en N particiones para que el resto del pipeline use todos los núcleos. Lo que cuesta es la descompresión, que sigue siendo secuencial. Este es un límite real del formato, no un error del script.

**Por qué `try_element_at`, `try_cast` y `from_json` y no `[]` o `cast`.** Spark 4 viene con el modo ANSI activado: un índice fuera de rango o un `cast` inválido lanza un error y para el job. Con las variantes `try_` el dato malo queda en `null` y lo atrapa una regla de validación.

**Validar en vez de borrar.** Cada rechazo tiene un motivo y la línea original. Así puedes discutir con el dato: ¿son errores de la fuente o de nuestro parser?

**Qué es una FK en Spark.** Parquet no tiene claves foráneas. Las comprobamos a mano con `left_semi` (existe) y `left_anti` (no existe). PostgreSQL las volverá a comprobar al cargar, pero es mejor no llegar con datos rotos.

**Por qué `dense_rank` para los ids.** Asigna un entero estable según el orden alfabético del nombre. Es reproducible: el mismo dump da los mismos ids. Pero `Window.orderBy` sin partición lleva todos los datos a una sola tarea. Con la muestra no se nota; con los dumps completos puede volverse un cuello de botella. Es un buen ejercicio para la semana 2: ¿cómo lo harías sin una sola partición?

**Por qué `edicion` está particionada por década y las demás no.** Las consultas de la semana 4 filtran mucho por década. Sin particionado, Spark lee todo y filtra; con particionado, salta carpetas. Para tablas pequeñas no compensa; para `edicion` (millones de filas en el dump completo) sí.

## Problemas frecuentes

| Síntoma | Causa | Solución |
|---|---|---|
| `Path does not exist` | `OL_RAW` apunta a una fecha que no cargaste | Revisa `hdfs dfs -ls /raw/openlibrary` y ajusta `OL_RAW` |
| `Java heap space` o `OutOfMemoryError` | Driver con poca memoria para el dataset | `export SPARK_DRIVER_MEMORY=4g` (solo si tu VM lo permite) o usa la muestra |
| El job lleva mucho tiempo en 1 tarea | Es el `.gz` sin dividir (ver arriba) | Normal en la lectura inicial; si pasa en otra etapa, sube `OL_PARTICIONES` |
| `AnalysisException` por columna inexistente | Cambiaste un nombre en un paso y no en el siguiente | Revisa las columnas de salida del paso anterior en `clean` |
| `FileAlreadyExistsException` al escribir | Ejecutaste a medias un job anterior | Los scripts escriben con `overwrite`; vuelve a ejecutar |
| Muchos WARN en la consola | Logs de Spark y de Hadoop | Son normales; `setLogLevel("WARN")` los reduce |
