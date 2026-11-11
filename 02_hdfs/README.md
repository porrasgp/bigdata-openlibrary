# 02 · HDFS: carga de la zona raw

## Qué contiene esta carpeta

| Archivo | Para qué sirve |
|---|---|
| `cargar_raw.sh` | Sube los dumps (o la muestra) a `/raw/openlibrary/fecha=...` y comprueba tamaño (y opcionalmente hash) |
| `reportar_hdfs.sh` | Muestra tamaños, replicación y bloques de lo cargado |

## Qué se hizo

1. Instalamos Hadoop 3.5.0 en modo pseudo-distribuido (un nodo, replicación 1) y comprobamos que NameNode, DataNode y la interfaz web (`localhost:9870`) responden.
2. Creamos la estructura de zonas: `/raw` (datos tal cual llegaron), `/clean` (Parquet tipado) y `/curated` (modelo final).
3. Cargamos la muestra en `/raw/openlibrary/fecha=muestra/` y comprobamos que cada archivo llega con el mismo tamaño y el mismo SHA-256 que en local.
4. Verificamos con `reportar_hdfs.sh` que cada archivo ocupa un bloque con replicación 1.

## Qué necesitas para ejecutarlo

- HDFS en marcha (ver `00_setup/README.md`, sección 3).
- Entorno cargado: `source ../00_setup/env.sh`.
- Los dumps en `../data/raw/` (ver `01_extraccion/README.md`), o la muestra en `../muestra/`.

## Cómo ejecutarlo

```bash
cd ~/bigdata-openlibrary/02_hdfs
source ../00_setup/env.sh

# Modo prueba: la muestra del repositorio (60 MB, segundos)
./cargar_raw.sh ../muestra muestra

# Dumps completos (17.6 GB, tardan varios minutos en subir)
./cargar_raw.sh ../data/raw 2026-10-31

# Opcional: verificar también el hash (lee cada archivo de HDFS: lento con los dumps completos)
./cargar_raw.sh ../data/raw 2026-10-31 --verificar-hash

# Ver lo cargado
./reportar_hdfs.sh /raw
```

La ruta `fecha=...` es el nombre del snapshot. Usa `muestra` para la muestra y `2026-10-31` para los dumps completos; los scripts de la semana 2 leen `2026-10-31` por defecto.

## Resultado esperado con la muestra

```
Found 5 items
-rw-r--r--   1 datalab supergroup    208.5 K ... muestra_ratings.tsv.gz
-rw-r--r--   1 datalab supergroup      4.2 M ... muestra_reading-log.tsv.gz
...
Total blocks (validated): 5 (avg. block size 338029 B)
Default replication factor: 1
```

## Qué debes entender

**HDFS parte los archivos en bloques** (128 MB por defecto en Hadoop 3). Cada bloque se guarda en uno o más DataNodes según el factor de replicación. En nuestra VM hay un solo DataNode, así que el factor es 1. En un clúster real sería 3: cada bloque aparece en tres máquinas y el dato sobrevive a la caída de dos.

**Un `.gz` no se puede dividir.** Un archivo gzip solo se puede descomprimir de principio a fin. Esto tiene una consecuencia importante: aunque HDFS tenga 100 bloques de un `ol_dump_editions` de 12.6 GB, Spark lo leerá con una sola tarea hasta que se haga `repartition()`. Lo verás en `03_limpieza_spark/01_raw_a_clean.py`.

**Por qué guardamos el archivo comprimido en raw.** Es la copia exacta de lo que publicó la fuente. Si algo sale mal después, siempre puedes volver a procesar desde aquí. Los `.gz` ocupan menos espacio, y el coste de descomprimir se paga una vez en Spark.

**Por qué la verificación de tamaño.** `hdfs dfs -put` puede terminar con un archivo incompleto si se corta la red. Comparar el tamaño con el archivo local es una comprobación barata. El hash es más seguro, pero lee todo el archivo de nuevo.

**Por qué fecha en la ruta.** Si cargas otro snapshot mañana, la ruta es distinta y no pisas los datos del anterior. Es el mismo principio que la partición por fecha de los data lakes.

## Problemas frecuentes

| Síntoma | Causa | Solución |
|---|---|---|
| `HDFS no responde` | NameNode o DataNode apagados | `hdfs --daemon start namenode` y `hdfs --daemon start datanode` |
| `Name node is in safe mode` | HDFS acaba de arrancar y no tiene bloques suficientes | `hdfs dfsadmin -safemode wait` |
| `No space left on device` | Disco de la VM lleno | Revisa `df -h`; borra `data/` de otros snapshots o amplía el disco |
| La carga es muy lenta | Disco lento de la VM | Es normal con 17 GB; la muestra tarda segundos |
| `put: ... File exists` | El archivo ya existe | El script usa `-put -f` y sobrescribe; si falla, borra con `hdfs dfs -rm` |
