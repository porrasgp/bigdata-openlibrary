# Manual de ejecución manual - Big Data Open Library

Proyecto: ETL medallion en CSV, con publicación en HDFS, carga en PostgreSQL, consultas SQL y proyecto final.

Este manual explica cómo ejecutar cada paso a mano, sin magia ni scripts ocultos. También sirve como guía para los alumnos: cada fase tiene un objetivo, un archivo de salida y una forma de verificarlo.

## 1. Qué se construye

Flujo completo (todas las flechas son pasos que puedes ejecutar a mano):

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
        |  psql -f sql/consultas.sql
        v
    Resultados y EXPLAIN ANALYZE

Objetivo de cada capa:

- Bronze: conservar el origen sin tocarlo. El manifiesto con hashes permite demostrar que no cambio.
- Silver: decidir que filas son validas. Los rechazos se guardan con el motivo, no se borran.
- Gold: organizar los datos para responder preguntas (dimensiones, hechos y un resumen).
- HDFS: publicar el gold en un lago con particion por fecha de snapshot.
- PostgreSQL: cargar el modelo estrella con restricciones PK, FK y CHECK.
- SQL: responder preguntas y medir planes de ejecución.

El nucleo (bronze, silver, gold) funciona sin HDFS ni PostgreSQL. Las demas fases son una extension sobre ese nucleo.

## 2. Requisitos

Necesitas:

- Java 17.
- Hadoop 3.5 con core-site.xml y hdfs-site.xml en $HADOOP_HOME/etc/hadoop.
- Python 3.11 o superior.
- PySpark 4.3.0 y psycopg 3.3.8.
- PostgreSQL 16 (o compatible) con un usuario y una base de datos.
- iconv, enscript y ps2pdf solo si quieres regenerar este PDF.

El orquestador crea el venv e instala las dependencias solas si no encuentra uno válido. Si prefieres hacerlo a mano:

    python3 -m venv venv-bigdata
    venv-bigdata/bin/pip install -r requirements.txt

El archivo requirements.txt contiene:

    pyspark==4.3.0
    psycopg[binary]==3.3.8

## 3. Preparación del entorno

Los scripts detectan Java, Hadoop, el venv y los binarios de PostgreSQL de forma automática, y preparan lo que falte: venv, PGDATA, rol/base y directorios HDFS. Si tu instalacion esta en otras rutas, usa variables de override:

    export OL_JAVA_HOME=/ruta/al/jdk-17
    export OL_HADOOP_HOME=/ruta/al/hadoop-3.5.0
    export OL_VENV=/ruta/al/venv
    export OL_PGBIN=/ruta/al/postgresql/bin
    export OL_PGDATA=/ruta/al/pgdata
    export OL_PGADMIN=postgres
    export OL_PGSOCKET=/tmp
    export OL_HDFS_DATA_DIR=/ruta/al/hdfs
    export PGHOST=localhost
    export PGPORT=5432
    export PGUSER=tu_usuario
    export PGDATABASE=tu_usuario

No hace falta exportarlas si todo esta en las rutas habituales. Para ver que se detecto, puedes hacer:

    source entorno.sh
    ol_detectar_java
    ol_detectar_hadoop
    ol_detectar_venv "pyspark, psycopg"
    ol_detectar_pg
    ol_resumen_entorno

entorno.sh solo define funciones: no modifica nada al hacer source. Las funciones ol_detectar_* y ol_asegurar_* si crean lo que falta cuando se invocan.

## 4. Paso 1: ejecutar el nucleo medallion (solo CSV)

Forma abreviada, desde la raiz del repo:

    bash ejecutar_todo.sh

Forma paso a paso (util en clase, para ver cada capa):

    python3 etl/01_bronze.py
    python3 etl/02_silver.py
    python3 etl/03_gold.py

Siempre en ese orden: bronze -> silver -> gold.

Que debe imprimir:

- Bronze: cinco CSV copiados y la ruta de data/bronze/_MANIFEST.csv.
- Silver: recuento de rechazos por motivo y número de filas limpias por tipo.
- Gold: filas de dim_obra, dim_fecha, fact_valoracion, fact_lectura y resumen.

Con la muestra incluida en el repo debes ver:

    data/silver/authors.csv               381 filas
    data/silver/works.csv                 200 filas
    data/silver/editions.csv            1504 filas
    data/silver/ratings.csv             47443 filas
    data/silver/reading_log.csv       1160547 filas
    data/gold/dim_obra.csv                200 filas
    data/gold/dim_fecha.csv              3287 filas
    data/gold/fact_valoracion.csv        47443 filas
    data/gold/fact_lectura.csv         1160547 filas
    data/gold/resumen_valoraciones_anio.csv  9 filas

Solo se rechazan 3 ediciones por titulo vacio. Si ves miles de rechazos en works, revisa que etl/common.py tenga la opcion multiLine=true: las descripciones tienen saltos de linea dentro de comillas.

Detalle importante: como core-site.xml define HDFS como sistema por defecto, etl/common.py usa ruta.as_uri() y temporal.as_uri() para forzar file://. Asi Spark no intenta buscar los CSV locales dentro de HDFS.

Para inspeccionar el resultado:

    ls -lh data/bronze data/silver data/gold
    head data/silver/_rechazados/editions.csv
    head data/gold/resumen_valoraciones_anio.csv

## 5. Paso 2: publicar el gold en HDFS

Primero asegurate de que el gold exista (paso 1). Luego:

    bash hdfs/cargar_gold.sh
    bash hdfs/cargar_gold.sh 2026-11-25 --verificar-hash
    bash hdfs/reportar_hdfs.sh

El primer comando usa la fecha de hoy como snapshot. El segundo fija la fecha y ademas lee cada archivo desde HDFS para comparar el SHA-256 con el local.

El destino es:

    /medallion/gold/fecha=FECHA/

Dentro estan los cinco CSV del gold. El script:

1. Comprueba que HDFS responda. Si las rutas de hdfs-site.xml no existen, las enlaza con un HDFS ya formateado en ~/Desktop/hdfs o ~/hdfs; si no hay ninguno, crea y formatea uno vacio. Despues arranca NameNode y DataNode.
2. Crea la carpeta de destino.
3. Sube cada CSV con hdfs dfs -put -f.
4. Compara el tamano local con hdfs dfs -du.
5. Opcionalmente compara hashes con hdfs dfs -cat.

No hace falta hacerlo a mano: ol_asegurar_hdfs ya lo hace. Si aun asi quieres arrancarlo manualmente:

    export JAVA_HOME=/ruta/al/jdk-17
    export HADOOP_HOME=/ruta/al/hadoop-3.5.0
    export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
    export PATH=$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH
    hdfs --daemon start namenode
    hdfs --daemon start datanode
    hdfs dfsadmin -safemode leave

## 6. Paso 3: cargar el gold en PostgreSQL

El orquestador lo deja listo: ol_detectar_pg busca un PGDATA existente en $HOME/pgdata, $HOME/Desktop/opt/pgdata, $HOME/Desktop/pgdata o $HOME/opt/pgdata; si no hay ninguno, ejecuta initdb en $HOME/pgdata. Despues ol_asegurar_roles_pg crea el rol PGUSER y la base PGDATABASE conectando como postgres cuando hace falta.

Si prefieres hacerlo a mano:

    PGBIN=/ruta/al/postgresql/bin
    PGDATA=/ruta/al/pgdata
    $PGBIN/pg_ctl -D $PGDATA -l /tmp/opencode/postgres.log -o "-p 5432 -k /tmp" start
    $PGBIN/pg_isready -h localhost -p 5432

Carga del esquema estrella:

    python3 postgres/cargar_gold.py --reiniciar

Este script:

1. Borra y recrea el esquema estrella (por eso es repetible).
2. Ejecuta sql/ddl.sql con CREATE TABLE, PK, FK, CHECK e indices.
3. Carga las cinco tablas con COPY FROM STDIN, leyendo data/gold/*.csv.
4. Imprime el número de filas de cada tabla.

Si las tablas ya existen y no usas --reiniciar, el script avisa para no borrar datos por accidente.

Verifica la carga:

    psql -v ON_ERROR_STOP=1 -f sql/verificar.sql

Salida esperada (ademas de cero filas huérfanas):

    tabla                      filas
    dim_obra                     200
    dim_fecha                   3287
    fact_valoracion            47443
    fact_lectura             1160547
    resumen_valoraciones_anio      9

La suma de valoraciones del resumen debe ser 47443.

## 7. Paso 4: ejecutar consultas SQL

Desde la raiz del repo:

    psql -v ON_ERROR_STOP=1 -f sql/consultas.sql

Para guardar la salida:

    psql -v ON_ERROR_STOP=1 -f sql/consultas.sql > /tmp/opencode/consultas.out 2>&1

Que hace cada consulta:

- Q1: top 10 de obras con mejor valoracion media, con al menos 100 votos.
- Q2: valoraciones por mes con acumulado usando una funcion de ventana.
- Q3: estados de lectura por ano.
- Q4: promedio de valoracion por decada.
- Q5: compara el resumen guardado en el gold con los hechos recalculados.
- Q6: EXPLAIN ANALYZE del join entre valoraciones y obras.

Ejercicio de optimizacion: quita el indice idx_valoracion_obra, vuelve a ejecutar Q6 y compara el plan con el original. Discute si aparece Seq Scan o Index Scan y cuanto tarda cada uno.

## 8. Flujo completo en un solo comando

Cuando ya quieras ejecutar todo seguido:

    bash ejecutar_todo_completo.sh

Hace exactamente esto, en orden:

1. Detectar Java, Hadoop y binarios de PostgreSQL; crear el venv con pyspark y psycopg si falta.
2. Preparar las rutas de HDFS, formatear si no hay metadata y arrancar NameNode y DataNode.
3. Preparar PGDATA, arrancar PostgreSQL y crear el rol y la base si faltan.
4. bash ejecutar_todo.sh (bronze -> silver -> gold).
5. bash hdfs/cargar_gold.sh FECHA.
6. python3 postgres/cargar_gold.py --reiniciar.
7. psql -f sql/verificar.sql y psql -f sql/consultas.sql.

La fecha se puede fijar con OL_FECHA:

    OL_FECHA=2026-11-25 bash ejecutar_todo_completo.sh

Al terminar imprime donde quedo cada resultado: data/, HDFS y PostgreSQL.

## 9. Proyecto final

La carpeta proyecto_final contiene:

- README.md: casos de estudio A, B y C, entregables, reglas y cronograma de 4 semanas.
- rubrica.md: 100 puntos repartidos entre medallion, HDFS, PostgreSQL, SQL, optimizacion, informe y presentacion.
- plantilla_informe.md: secciones que debe tener el informe (maximo 6 páginas).

Resumen de los casos:

- A: evolucion de valoraciones por ano y decada.
- B: obras con mejor valoracion media y cuantos votos la respaldan.
- C: estados de lectura mas frecuentes y como cambian con el tiempo.

Entregable mínimo: pipeline reproducible, una transformacion o validacion propia, gold publicado en HDFS, esquema estrella cargado, cinco consultas propias, EXPLAIN ANALYZE antes y despues de indices, informe y demo de 10 minutos.

Reglas que mas se olvidan: no subir data/ al repositorio, usar la misma fecha de snapshot en todas las fases y citar la licencia CC0 de Open Library.

## 10. Verificación y solución de problemas

Problema: Spark busca hdfs://localhost:8020/... en vez de archivos locales.
Causa: core-site.xml pone HDFS como fs.defaultFS.
solución: en etl/common.py, leer y escribir con ruta.as_uri() para forzar file://.

Problema: aparecen cientos de filas rechazadas en works con texto de descripcion en la columna clave.
Causa: las descripciones tienen saltos de linea dentro de comillas.
solución: etl/common.py debe usar .option("multiLine", "true") en leer_csv().

Problema: hdfs dfs -ls / falla.
solución: exportar JAVA_HOME, HADOOP_HOME y HADOOP_CONF_DIR; arrancar NameNode y DataNode; salir de safemode.

Problema: psql dice que las tablas ya existen.
solución: ejecutar python3 postgres/cargar_gold.py --reiniciar.

Problema: psycopg no puede conectar.
solución: revisar PGHOST, PGPORT, PGUSER y PGDATABASE; comprobar con pg_isready.

Problema: HDFS dice que el storage directory no existe.
Causa: hdfs-site.xml apunta a una ruta que aun no existe en esta maquina.
solución: el orquestador la enlaza con ~/Desktop/hdfs o crea y formatea una vacia; tambien puedes exportar OL_HDFS_DATA_DIR=/ruta/al/hdfs.

Problema: pg_ctl dice que no existe el directorio pgdata.
solución: ol_detectar_pg busca un PGDATA existente o ejecuta initdb; exporta OL_PGDATA si quieres otra ruta.

Problema: psql dice que el rol no existe.
solución: ol_asegurar_roles_pg conecta como postgres para crearlo; exporta OL_PGADMIN si tu superusuario tiene otro nombre.

Problema: al regenerar el PDF salen caracteres raros.
Causa: enscript no acepta UTF-8.
solución: manual/generar_pdf.sh convierte con iconv a ISO-8859-1 y usa enscript -X latin1.

## 11. Mapa de archivos

    ejecutar_todo.sh             nucleo medallion (CSV)
    ejecutar_todo_completo.sh    flujo completo
    entorno.sh                   deteccion y preparacion automatica de Java, Hadoop, venv, HDFS y PostgreSQL
    requirements.txt             pyspark + psycopg
    muestra/csv/                 CSV de entrada (versionados)
    etl/common.py                rutas, SparkSession, lectura/escritura CSV
    etl/01_bronze.py             copia + _MANIFEST.csv
    etl/02_silver.py             limpieza, validacion y rechazos
    etl/03_gold.py               modelo estrella y resumen
    hdfs/cargar_gold.sh          subida a /medallion/gold/fecha=FECHA/
    hdfs/reportar_hdfs.sh        tamano, bloques y replicacion
    postgres/cargar_gold.py      DDL + COPY desde data/gold
    sql/ddl.sql                  esquema estrella
    sql/verificar.sql            conteos e integridad
    sql/consultas.sql            seis consultas de ejemplo
    proyecto_final/              caso, rubrica y plantilla de informe
    manual/manual.md             fuente de este manual
    manual/generar_pdf.sh        regenera manual.pdf
    manual/manual.pdf            este documento
    docs/flujo.md                diagramas Mermaid
    docs/medallion.md            explicacion didactica de las capas
    data/                        resultados generados (no versionados)

## Apendice: cheat sheet

    # Todo desde cero
    bash ejecutar_todo_completo.sh

    # Solo el nucleo
    bash ejecutar_todo.sh

    # Paso a paso
    python3 etl/01_bronze.py
    python3 etl/02_silver.py
    python3 etl/03_gold.py
    bash hdfs/cargar_gold.sh $(date +%F) --verificar-hash
    python3 postgres/cargar_gold.py --reiniciar
    psql -v ON_ERROR_STOP=1 -f sql/verificar.sql
    psql -v ON_ERROR_STOP=1 -f sql/consultas.sql

    # Regenerar este PDF
    bash manual/generar_pdf.sh
