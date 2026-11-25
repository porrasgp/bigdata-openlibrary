# HDFS — publicación de la capa gold

Esta carpeta es la **extensión HDFS** del proyecto. El núcleo del ETL sigue siendo CSV local; aquí solo publicamos el resultado para simular un lago de datos.

## Archivos

| Archivo | Para qué sirve |
|---|---|
| `cargar_gold.sh` | Copia `data/gold/*.csv` a `/medallion/gold/fecha=FECHA/` y verifica tamaños (y hashes si se pide) |
| `reportar_hdfs.sh` | Muestra espacio, archivos, replicación y bloques de una ruta HDFS |

## Uso manual

```bash
# 1. Generar el gold primero
bash ejecutar_todo.sh

# 2. Subirlo a HDFS con la fecha de snapshot del día
bash hdfs/cargar_gold.sh

# 3. Fecha concreta y verificación fuerte
bash hdfs/cargar_gold.sh 2026-11-25 --verificar-hash

# 4. Inspeccionar el resultado
bash hdfs/reportar_hdfs.sh
bash hdfs/reportar_hdfs.sh /medallion/gold/fecha=2026-11-25
```

Si HDFS no responde, `cargar_gold.sh` arranca NameNode y DataNode y espera hasta que el clúster esté disponible.

## Detalles para los alumnos

- La ruta incluye `fecha=...` para que cada ejecución sea identificable y reproducible, igual que en un lago real con particiones por fecha.
- `hdfs dfs -put -f` sobrescribe el archivo si ya existía; el tamaño se compara con `hdfs dfs -du`.
- `--verificar-hash` lee el archivo desde HDFS y compara su SHA-256 con el local. Es más lento, pero demuestra que la copia es exacta.
- Los CSV ya están procesados; en un clúster real la capa bronze se guardaría en HDFS y Spark leería desde allí. Aquí se mantiene local para que el pipeline sea fácil de ejecutar en clase.
