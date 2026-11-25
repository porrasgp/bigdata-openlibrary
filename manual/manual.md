# Manual de ejecución manual - Big Data Open Library

Proyecto: ETL medallion en CSV, con publicación en HDFS, carga en PostgreSQL, consultas SQL y proyecto final.

Este manual explica cómo ejecutar cada paso a mano, sin magia ni scripts ocultos. También sirve como guía para los alumnos: cada fase tiene un objetivo, una salida concreta y una forma de verificarla antes de continuar.

## 0. Cómo usar este manual

### Objetivos de aprendizaje

- Explicar para qué sirve cada capa de la arquitectura Medallion.
- Ejecutar el pipeline bronze → silver → gold desde cero y leer sus salidas.
- Publicar el gold en HDFS y comprobar que los archivos lleguen íntegros.
- Cargar el modelo estrella en PostgreSQL con restricciones y verificar los conteos.
- Responder preguntas con SQL e interpretar un plan `EXPLAIN ANALYZE`.

### Ruta de aprendizaje

| Fase | Qué haces | Evidencia de que terminaste |
|---|---|---|
| 1 | Ejecutar el núcleo Medallion | CSV en `data/bronze`, `data/silver` y `data/gold` |
| 2 | Subir el gold a HDFS | Cinco CSV en `/medallion/gold/fecha=FECHA/` con hash verificado |
| 3 | Cargar PostgreSQL | Cinco tablas en `estrella` y cero huérfanos |
| 4 | Consultar y optimizar | Seis consultas, incluido `EXPLAIN ANALYZE` |

### Convenciones

> **Consejo:** Los bloques con borde son comandos. Cópialos en una terminal situada en la raíz del repo.

> **Importante:** Los valores `/ruta/al/...` son ejemplos comentados. `entorno.sh` detecta las rutas reales; no copies los marcadores.

> **Comprueba:** Cada fase termina con una prueba concreta. No pases a la siguiente sin ver el resultado esperado.

## 1. Qué se construye

Flujo completo. Todas las flechas son pasos que puedes ejecutar a mano:

    muestra/csv/*.csv
        |
        |  etl/01_bronze.py  (copia exacta + SHA-256)
        v
    data/bronze/*.csv + _MANIFEST.csv
        |
        |  etl/02_silver.py  (validar, deduplicar, tipar)
        v
    data/silver/*.csv  +  _rechazados/*.csv
        |
        |  etl/03_gold.py  (modelo estrella)
        v
    data/gold/dim_*.csv, fact_*.csv, resumen_*.csv
        |
        |  hdfs/cargar_gold.sh
        v
    hdfs://localhost:8020/medallion/gold/fecha=FECHA/*.csv
        |
        |  postgres/cargar_gold.py  (COPY)
        v
    PostgreSQL: esquema estrella
        |
        |  "$PGBIN/psql" -f sql/consultas.sql
        v
    Resultados y EXPLAIN ANALYZE

Objetivo de cada capa:

- **Bronze:** conservar el origen sin tocarlo. El manifiesto con hashes permite demostrar que no cambió.
- **Silver:** decidir qué filas son válidas. Los rechazos se guardan con el motivo, no se borran.
- **Gold:** organizar los datos para responder preguntas (dimensiones, hechos y un resumen).
- **HDFS:** publicar el gold en un lago con partición por fecha de snapshot.
- **PostgreSQL:** cargar el modelo estrella con restricciones PK, FK y CHECK.
- **SQL:** responder preguntas y medir planes de ejecución.

> **Nota:** El núcleo (bronze, silver, gold) funciona sin HDFS ni PostgreSQL. Las demás fases son una extensión sobre ese núcleo.

## 2. Requisitos

Necesitas:

- Java 17.
- Hadoop 3.5 con `core-site.xml` y `hdfs-site.xml` en `$HADOOP_HOME/etc/hadoop`.
- Python 3.11 o superior.
- PySpark 4.3.0 y psycopg 3.3.8.
- PostgreSQL 16 (o compatible) con un usuario y una base de datos.
- Python con `reportlab` solo si quieres regenerar este PDF.

El orquestador crea el venv e instala las dependencias solas si no encuentra uno válido. Si prefieres hacerlo a mano:

```bash
python3 -m venv venv-bigdata
venv-bigdata/bin/pip install -r requirements.txt
```

El archivo `requirements.txt` contiene:

```text
pyspark==4.3.0
psycopg[binary]==3.3.8
reportlab==5.1.0
```

> **Consejo:** Si vas a regenerar el PDF con frecuencia, instala `requirements.txt` en el venv y usa siempre `$VENV/bin/python3`.

## 3. Preparación del entorno

Los scripts detectan Java, Hadoop, el venv y los binarios de PostgreSQL de forma automática, y preparan lo que falte: venv, PGDATA, rol/base y directorios HDFS. Si tu instalación está en otras rutas, usa variables de override:

```bash
# Ejemplos: solo si tus rutas son distintas; NO copies estos valores tal cual.
# export OL_JAVA_HOME=/ruta/al/jdk-17
# export OL_HADOOP_HOME=/ruta/al/hadoop-3.5.0
# export OL_VENV=/ruta/al/venv
# export OL_PGBIN=/ruta/al/postgresql/bin
# export OL_PGDATA=/ruta/al/pgdata
# export OL_PGADMIN=postgres
# export OL_PGSOCKET=/tmp
# export OL_HDFS_DATA_DIR=/ruta/al/hdfs
# export PGHOST=localhost
# export PGPORT=5432
# export PGUSER=tu_usuario
# export PGDATABASE=tu_usuario
```

No hace falta exportar nada si todo está en las rutas habituales. En esta máquina la detección da:

| Variable | Valor detectado |
|---|---|
| Java | `/home/datalab/Desktop/opt/jdk-17.0.21+9` |
| Hadoop | `/home/datalab/Desktop/opt/hadoop-3.5.0` |
| Venv | `/home/datalab/Desktop/venv-bigdata` |
| PGBIN | `/home/datalab/Desktop/venv-pgtest/lib/python3.12/site-packages/pgserver/pginstall/bin` |
| PGDATA | `/home/datalab/pgdata` (enlace a `/home/datalab/Desktop/opt/pgdata`) |
| PGUSER / PGDATABASE | `datalab` |

Para verificar la detección y dejar la terminal lista para los demás pasos, ejecuta esto **una vez en cada terminal**:

```bash
source entorno.sh
ol_detectar_java
ol_detectar_hadoop
ol_detectar_venv "pyspark, psycopg"
ol_detectar_pg
ol_asegurar_hdfs
ol_asegurar_postgres
ol_asegurar_roles_pg
ol_resumen_entorno
```

> **Consejo:** Después de ese bloque, usa `"$VENV/bin/python3"` y `"$PGBIN/psql"`. Si abres otra terminal, repite el bloque: `VENV` y `PGBIN` no se heredan entre sesiones.

> **Comprueba:** `ol_resumen_entorno` debe mostrar Java, Hadoop, Python, Postgres y PGDATA sin mensajes de error.

`entorno.sh` solo define funciones: no modifica nada al hacer `source`. Las funciones `ol_detectar_*` y `ol_asegurar_*` sí crean lo que falta cuando se invocan.

## 4. Paso 1: ejecutar el núcleo Medallion (solo CSV)

### 4.1. Forma abreviada

Desde la raíz del repo:

```bash
bash ejecutar_todo.sh
```

### 4.2. Forma paso a paso

Requiere el bloque de la sección 3, o al menos `source entorno.sh && ol_detectar_venv "pyspark"`:

```bash
"$VENV/bin/python3" etl/01_bronze.py
"$VENV/bin/python3" etl/02_silver.py
"$VENV/bin/python3" etl/03_gold.py
```

Siempre en ese orden: bronze → silver → gold.

Qué debe imprimir:

- **Bronze:** cinco CSV copiados y la ruta de `data/bronze/_MANIFEST.csv`.
- **Silver:** recuento de rechazos por motivo y filas limpias por tipo.
- **Gold:** filas de `dim_obra`, `dim_fecha`, `fact_valoracion`, `fact_lectura` y `resumen`.

### 4.3. Resultado esperado

Con la muestra incluida en el repo debes ver:

| Salida | Filas |
|---|---:|
| `data/silver/authors.csv` | 381 |
| `data/silver/works.csv` | 200 |
| `data/silver/editions.csv` | 1504 |
| `data/silver/ratings.csv` | 47443 |
| `data/silver/reading_log.csv` | 1160547 |
| `data/gold/dim_obra.csv` | 200 |
| `data/gold/dim_fecha.csv` | 3287 |
| `data/gold/fact_valoracion.csv` | 47443 |
| `data/gold/fact_lectura.csv` | 1160547 |
| `data/gold/resumen_valoraciones_anio.csv` | 9 |

> **Comprueba:** Solo se rechazan 3 ediciones por título vacío. Si ves miles de rechazos en `works`, revisa que `etl/common.py` use `multiLine=true`: las descripciones tienen saltos de línea dentro de comillas.

> **Nota:** Como `core-site.xml` define HDFS como sistema por defecto, `etl/common.py` usa `ruta.as_uri()` y `temporal.as_uri()` para forzar `file://`. Así Spark no busca los CSV locales dentro de HDFS.

Para inspeccionar el resultado:

```bash
ls -lh data/bronze data/silver data/gold
head data/silver/_rechazados/editions.csv
head data/gold/resumen_valoraciones_anio.csv
```

## 5. Paso 2: publicar el gold en HDFS

Primero asegúrate de que el gold exista (paso 1). Luego:

```bash
bash hdfs/cargar_gold.sh
bash hdfs/cargar_gold.sh 2026-11-25 --verificar-hash
bash hdfs/reportar_hdfs.sh
```

El primer comando usa la fecha de hoy como snapshot. El segundo fija la fecha y además lee cada archivo desde HDFS para comparar el SHA-256 con el local.

El destino es:

```text
/medallion/gold/fecha=FECHA/
```

Dentro están los cinco CSV del gold. El script:

1. Comprueba que HDFS responda. Si las rutas de `hdfs-site.xml` no existen, las enlaza con un HDFS ya formateado en `~/Desktop/hdfs` o `~/hdfs`; si no hay ninguno, crea y formatea uno vacío. Después arranca NameNode y DataNode.
2. Crea la carpeta de destino.
3. Sube cada CSV con `hdfs dfs -put -f`.
4. Compara el tamaño local con `hdfs dfs -du`.
5. Opcionalmente compara hashes con `hdfs dfs -cat`.

> **Consejo:** Usa la misma fecha de snapshot en HDFS y en PostgreSQL para que el informe final sea reproducible.

> **Comprueba:** Deben aparecer cinco líneas `sha256 verificado` y el mensaje `Carga en HDFS terminada.`

No hace falta hacerlo a mano: `ol_asegurar_hdfs` ya lo hace. Si aun así quieres arrancarlo manualmente:

```bash
# Solo si ol_detectar_java / ol_detectar_hadoop no funcionan:
export JAVA_HOME=/home/datalab/Desktop/opt/jdk-17.0.21+9
export HADOOP_HOME=/home/datalab/Desktop/opt/hadoop-3.5.0
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
export PATH=$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH
hdfs --daemon start namenode
hdfs --daemon start datanode
hdfs dfsadmin -safemode leave
```

## 6. Paso 3: cargar el gold en PostgreSQL

El orquestador lo deja listo: `ol_detectar_pg` busca un PGDATA existente en `$HOME/pgdata`, `$HOME/Desktop/opt/pgdata`, `$HOME/Desktop/pgdata` o `$HOME/opt/pgdata`; si no hay ninguno, ejecuta `initdb` en `$HOME/pgdata`. Después `ol_asegurar_roles_pg` crea el rol `PGUSER` y la base `PGDATABASE` conectando como `postgres` cuando hace falta.

Si prefieres hacerlo a mano, usa siempre los valores detectados:

```bash
source entorno.sh
ol_detectar_venv "psycopg"
ol_detectar_pg
ol_asegurar_postgres
ol_asegurar_roles_pg
"$PGBIN/pg_isready" -h localhost -p 5432
```

Si por alguna razón `ol_asegurar_postgres` no lo arranca, puedes lanzarlo con los valores ya detectados:

```bash
"$PGBIN/pg_ctl" -D "$PGDATA" -l /tmp/opencode/postgres.log -o "-p $PGPORT -k /tmp" start
```

Carga del esquema estrella con el venv, no con el `python3` del sistema:

```bash
"$VENV/bin/python3" postgres/cargar_gold.py --reiniciar
```

> **Importante:** `--reiniciar` borra y recrea el esquema `estrella`. Es repetible, pero no lo uses si quieres conservar datos cargados a mano.

Este script:

1. Borra y recrea el esquema `estrella`.
2. Ejecuta `sql/ddl.sql` con `CREATE TABLE`, PK, FK, CHECK e índices.
3. Carga las cinco tablas con `COPY FROM STDIN`, leyendo `data/gold/*.csv`.
4. Imprime el número de filas de cada tabla.

Verifica la carga:

```bash
"$PGBIN/psql" -v ON_ERROR_STOP=1 -d "$PGDATABASE" -f sql/verificar.sql
```

Salida esperada, además de cero filas huérfanas:

| Tabla | Filas |
|---|---:|
| `estrella.dim_obra` | 200 |
| `estrella.dim_fecha` | 3287 |
| `estrella.fact_valoracion` | 47443 |
| `estrella.fact_lectura` | 1160547 |
| `estrella.resumen_valoraciones_anio` | 9 |

> **Comprueba:** La suma de valoraciones del resumen debe ser 47443 y las cuatro comprobaciones de integridad deben dar 0.

## 7. Paso 4: ejecutar consultas SQL

Desde la raíz del repo:

```bash
"$PGBIN/psql" -v ON_ERROR_STOP=1 -d "$PGDATABASE" -f sql/consultas.sql
```

Para guardar la salida:

```bash
mkdir -p /tmp/opencode
"$PGBIN/psql" -v ON_ERROR_STOP=1 -d "$PGDATABASE" -f sql/consultas.sql > /tmp/opencode/consultas.out 2>&1
```

Qué hace cada consulta:

| Consulta | Pregunta que responde |
|---|---|
| Q1 | Top 10 de obras con mejor valoración media, con al menos 100 votos |
| Q2 | Valoraciones por mes con acumulado usando una función de ventana |
| Q3 | Estados de lectura por año |
| Q4 | Promedio de valoración por década |
| Q5 | Comparación del resumen guardado en gold contra los hechos |
| Q6 | `EXPLAIN ANALYZE` del join entre valoraciones y obras |

> **Comprueba:** La salida debe mostrar las seis cabeceras `=== Q1` a `=== Q6` y terminar sin errores.

Ejercicio de optimización: quita el índice `idx_valoracion_obra`, vuelve a ejecutar Q6 y compara el plan con el original. Discute si aparece `Seq Scan` u `Index Scan` y cuánto tarda cada uno.

## 8. Flujo completo en un solo comando

Cuando ya quieras ejecutar todo seguido:

```bash
bash ejecutar_todo_completo.sh
```

Hace exactamente esto, en orden:

1. Detectar Java, Hadoop y binarios de PostgreSQL; crear el venv con `pyspark` y `psycopg` si falta.
2. Preparar las rutas de HDFS, formatear si no hay metadata y arrancar NameNode y DataNode.
3. Preparar PGDATA, arrancar PostgreSQL y crear el rol y la base si faltan.
4. `bash ejecutar_todo.sh` (bronze → silver → gold).
5. `bash hdfs/cargar_gold.sh FECHA`.
6. `"$VENV/bin/python3" postgres/cargar_gold.py --reiniciar`.
7. `"$PGBIN/psql" -f sql/verificar.sql` y `"$PGBIN/psql" -f sql/consultas.sql`.

La fecha se puede fijar con `OL_FECHA`:

```bash
OL_FECHA=2026-11-25 bash ejecutar_todo_completo.sh
```

Al terminar imprime dónde quedó cada resultado: `data/`, HDFS y PostgreSQL.

## 9. Proyecto final

La carpeta `proyecto_final` contiene:

- `README.md`: casos de estudio A, B y C, entregables, reglas y cronograma de 4 semanas.
- `rubrica.md`: 100 puntos repartidos entre Medallion, HDFS, PostgreSQL, SQL, optimización, informe y presentación.
- `plantilla_informe.md`: secciones que debe tener el informe (máximo 6 páginas).

Resumen de los casos:

- **A:** evolución de valoraciones por año y década.
- **B:** obras con mejor valoración media y cuántos votos la respaldan.
- **C:** estados de lectura más frecuentes y cómo cambian con el tiempo.

Entregable mínimo: pipeline reproducible, una transformación o validación propia, gold publicado en HDFS, esquema estrella cargado, cinco consultas propias, `EXPLAIN ANALYZE` antes y después de índices, informe y demo de 10 minutos.

> **Importante:** No subir `data/` al repositorio, usar la misma fecha de snapshot en todas las fases y citar la licencia CC0 de Open Library.

## 10. Verificación y solución de problemas

| Síntoma | Causa probable | Acción |
|---|---|---|
| Spark busca `hdfs://localhost:8020/...` en vez de archivos locales | `core-site.xml` pone HDFS como `fs.defaultFS` | En `etl/common.py`, leer y escribir con `ruta.as_uri()` |
| Cientos de filas rechazadas en `works` | Descripciones con saltos de línea dentro de comillas | Usar `.option("multiLine", "true")` en `leer_csv()` |
| `hdfs dfs -ls /` falla | JAVA_HOME/HADOOP_HOME ausentes o daemon apagado | Exportar las variables, arrancar NameNode y DataNode, salir de safemode |
| `psql` dice que las tablas ya existen | Esquema previo | `"$VENV/bin/python3" postgres/cargar_gold.py --reiniciar` |
| psycopg no puede conectar | Variables de conexión incorrectas | Revisar `PGHOST`, `PGPORT`, `PGUSER`, `PGDATABASE` y usar `"$PGBIN/pg_isready"` |
| HDFS dice que el storage directory no existe | `hdfs-site.xml` apunta a una ruta ausente | El orquestador la enlaza con `~/Desktop/hdfs`; o exportar `OL_HDFS_DATA_DIR=/home/datalab/Desktop/hdfs` |
| `pg_ctl` dice que no existe pgdata | PGDATA no inicializado | `ol_detectar_pg` busca uno o ejecuta `initdb`; exporta `OL_PGDATA` si quieres otra ruta |
| `psql` dice que el rol no existe | Falta el rol `PGUSER` | `ol_asegurar_roles_pg` conecta como `postgres`; exporta `OL_PGADMIN` si hace falta |
| El PDF sale con caracteres raros | Generador antiguo basado en `enscript` | Usar `bash manual/generar_pdf.sh`, que genera el PDF con ReportLab y fuentes UTF-8 |

## 11. Mapa de archivos

| Archivo | Función |
|---|---|
| `ejecutar_todo.sh` | Núcleo Medallion en CSV |
| `ejecutar_todo_completo.sh` | Flujo completo |
| `entorno.sh` | Detección y preparación de Java, Hadoop, venv, HDFS y PostgreSQL |
| `requirements.txt` | `pyspark` + `psycopg` + `reportlab` |
| `muestra/csv/` | CSV de entrada versionados |
| `etl/common.py` | Rutas, SparkSession y E/S de CSV |
| `etl/01_bronze.py` | Copia + `_MANIFEST.csv` |
| `etl/02_silver.py` | Limpieza, validación y rechazos |
| `etl/03_gold.py` | Modelo estrella y resumen |
| `hdfs/cargar_gold.sh` | Subida a `/medallion/gold/fecha=FECHA/` |
| `hdfs/reportar_hdfs.sh` | Tamaño, bloques y replicación |
| `postgres/cargar_gold.py` | DDL + COPY desde `data/gold` |
| `sql/ddl.sql` | Esquema estrella |
| `sql/verificar.sql` | Conteos e integridad |
| `sql/consultas.sql` | Seis consultas de ejemplo |
| `proyecto_final/` | Casos, rúbrica y plantilla de informe |
| `manual/manual.md` | Fuente de este manual |
| `manual/generar_pdf.sh` | Regenera `manual.pdf` |
| `manual/generar_pdf.py` | Maqueta el PDF con ReportLab |
| `manual/manual.pdf` | Este documento |
| `docs/flujo.md` | Diagramas Mermaid |
| `docs/medallion.md` | Explicación didáctica de las capas |
| `data/` | Resultados generados, no versionados |

## 12. Cierre: glosario y checklist

### 12.1. Glosario exprés

| Término | Significado en este proyecto |
|---|---|
| Bronze | Copia íntegra del origen con huella SHA-256 |
| Silver | Datos validados, deduplicados y con rechazos explicados |
| Gold | Modelo estrella listo para análisis |
| Dimensión | Tabla de contexto: obra o fecha |
| Hecho | Tabla de eventos: valoración o lectura |
| Snapshot | Fecha que etiqueta una publicación del gold |
| R | Distancia entre entry, stop y target; también se usa para hablar de riesgo |

### 12.2. Checklist antes de entregar

- [ ] El gold local tiene 5 tablas con los conteos esperados.
- [ ] HDFS contiene los cinco CSV con `sha256 verificado`.
- [ ] PostgreSQL tiene cinco tablas en `estrella` y cero huérfanos.
- [ ] Las seis consultas SQL terminan sin errores.
- [ ] Hay `EXPLAIN ANALYZE` antes y después de tocar índices.
- [ ] El informe cita la licencia CC0 de Open Library.

> **Consejo:** Si puedes explicar en voz alta por qué una tabla es dimensión y otra hecho, ya estás listo para la demo.

## 13. Apéndice: cheat sheet

```bash
# Preparar la sesión (una vez por terminal)
source entorno.sh
ol_detectar_java
ol_detectar_hadoop
ol_detectar_venv "pyspark, psycopg"
ol_detectar_pg
ol_asegurar_hdfs
ol_asegurar_postgres
ol_asegurar_roles_pg

# Todo desde cero (orquestador)
bash ejecutar_todo_completo.sh

# O paso a paso, ya con el bloque anterior cargado
"$VENV/bin/python3" etl/01_bronze.py
"$VENV/bin/python3" etl/02_silver.py
"$VENV/bin/python3" etl/03_gold.py
bash hdfs/cargar_gold.sh "$(date +%F)" --verificar-hash
"$VENV/bin/python3" postgres/cargar_gold.py --reiniciar
"$PGBIN/psql" -v ON_ERROR_STOP=1 -d "$PGDATABASE" -f sql/verificar.sql
"$PGBIN/psql" -v ON_ERROR_STOP=1 -d "$PGDATABASE" -f sql/consultas.sql

# Regenerar este PDF
bash manual/generar_pdf.sh
```
