# Ejercicios

Cada ejercicio indica en qué semana se resuelve y qué archivo del repositorio usar.
Las soluciones están en `soluciones/`. Intenta resolverlos antes de mirarlas.

---

## Semana 1: HDFS

**E1. Espacio real con replicación.**
Con `hdfs dfs -du -s /raw` se ve el tamaño lógico. Calcula cuánto espacio
ocuparía el dataset completo (17.6 GB comprimidos) con factor de replicación 3
en un clúster de 3 DataNodes. ¿Cabe en un disco de 120 GB? Justifica.

**E2. Cambiar la replicación.**
Sube un archivo cualquiera de `muestra/` a `/tmp/prueba/`, cambia su factor de
replicación a 2 con `hdfs dfs -setrep` y comprueba el cambio con `hdfs fsck`.
En un clúster de un solo nodo, ¿qué pasa si pides replicación 3? ¿Por qué?

---

## Semana 2: PySpark

**E3. Rechazados por motivo.**
Sin ejecutar el job completo, escribe un script que lea
`/clean/_rechazados/editions` y muestre cuántos registros hay por `motivo`.
Compara con la salida de `01_raw_a_clean.py`.

**E4. Nueva regla de validación.**
Añade a `limpiar_ediciones` en `01_raw_a_clean.py` la regla
`anio_implausible`: el año de publicación debe estar entre 1450 y 2100.
Ejecuta el job solo para `editions` (`--tipos editions`) y dime cuántos
registros nuevos se rechazan en la muestra.

**E5. ¿Por qué repartir después de leer?**
En `common.py`/`01_raw_a_clean.py` hay un `repartition(PARTICIONES)` justo
después de `spark.read.text`. Explica qué pasaría con un `.txt.gz` de 12 GB si
quitas esa línea. Pista: un gzip no se puede dividir en bloques.

**E6. Partición por década.**
Ejecuta `03_comparar_particionado.py`. Explica con tus palabras por qué la
consulta sobre la tabla particionada es más rápida y qué muestra el plan
(`PartitionFilters`).

---

## Semana 3: Modelado y carga

**E7. Relación N:M con atributos.**
Hoy `obra_autor` solo guarda las claves. Diseña una extensión que guarde el
**tipo de rol** del autor (autor, ilustrador, traductor...). ¿Cambia la clave
primaria? Escribe el DDL.

**E8. Clave primaria de los hechos.**
`valoracion` no tiene clave primaria. Explica por qué, y propone una solución
que no pierda filas (por ejemplo, una clave sustituta). ¿Qué cambia en
`tablas.py` y en la carga?

**E9. Dimensión de autor en el esquema estrella.**
Escribe el DDL de `estrella.dim_autor` y el `INSERT ... SELECT` que la llena
desde `openlibrary.autor`. Después, escribe una consulta que cuente valoraciones
por autor usando `obra_autor`.

---

## Semana 4: Consultas y optimización

**E10. Medir un índice.**
Ejecuta `06_consultas/05_explain.sql` sin índices (`indices_quitar.sql`) y con
ellos (`indices.sql`). Completa esta tabla:

| Consulta | Sin índices (ms) | Con índices (ms) | Tipo de scan antes | Tipo de scan después |
|---|---|---|---|---|
| A | | | | |
| B | | | | |
| C | | | | |

**E11. Ventana: percentil de valoración.**
Escribe una consulta que, para cada obra con al menos 5 valoraciones, dé su
media y en qué decil de media queda (`ntile(10)`).

**E12. Pregunta propia.**
Formula una pregunta de negocio sobre el dataset que requiera al menos un join
N:M y una ventana. Escribe la consulta y explica qué responde.
