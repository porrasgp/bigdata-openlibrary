# Big Data con Open Library

Curso práctico de big data con datos públicos: desde la descarga de un dataset real hasta un proyecto final analítico. Todo el pipeline se ejecuta en una VM de Ubuntu en VirtualBox.

Stack: Ubuntu 26.04 LTS · Java 17 · Hadoop 3.5.0 (HDFS) · PySpark 4.3.0 · PostgreSQL 18 · Python 3.11+

## Datos

Fuente: [Open Library Data Dumps](https://openlibrary.org/developers/dumps), licencia **CC0 1.0** (dominio público).
Snapshot fijo: **2026-10-31**. Todos los alumnos usan la misma fecha.

| Dump | Comprimido | Uso |
|---|---:|---|
| editions | 12.6 GB | Ediciones (tabla grande) |
| works | 4.1 GB | Obras |
| authors | 0.8 GB | Autores |
| ratings | 9 MB | Valoraciones |
| reading-log | 125 MB | Estado de lectura |
| **Total** | **~17.6 GB** | |

Los datos completos **no se suben** al repositorio (ver `.gitignore`). Se descargan con `01_extraccion/descargar_dumps.sh`. La carpeta `muestra/` tiene un subconjunto coherente de 60 MB para probar el pipeline sin descargar todo.

## Requisitos de la VM

| Recurso | Mínimo |
|---|---|
| Hipervisor | VirtualBox 7.x |
| SO invitado | Ubuntu 26.04.1 LTS (escritorio) |
| RAM | 8 GB |
| CPU | 4 vCPU |
| Disco | 120 GB |

## Mapa del curso

Cada carpeta tiene su propio README con qué contiene, qué se hizo, qué necesitas y qué debes entender.

| Semana | Carpeta | Contenido |
|---|---|---|
| 1 | [`00_setup/`](00_setup/README.md) | Entorno: Java, Hadoop, PostgreSQL, PySpark y verificación |
| 1 | [`01_extraccion/`](01_extraccion/README.md) | Descarga verificada de dumps, muestra coherente y conversión a CSV |
| 1 | [`02_hdfs/`](02_hdfs/README.md) | Carga de la zona raw en HDFS |
| 2 | [`03_limpieza_spark/`](03_limpieza_spark/README.md) | PySpark: raw → clean → curated, validación y modelo normalizado |
| 3 | [`04_modelado/`](04_modelado/README.md) | DDL del modelo normalizado y del esquema estrella, diagrama ER |
| 3 | [`05_carga_postgres/`](05_carga_postgres/README.md) | Exportación a CSV y carga con `COPY` |
| 4 | [`06_consultas/`](06_consultas/README.md) | Consultas, ventanas, índices y `EXPLAIN ANALYZE` |
| 4 | [`07_ejercicios/`](07_ejercicios/README.md) | 12 ejercicios con soluciones |
| 4 | [`08_proyecto_final/`](08_proyecto_final/README.md) | Proyecto individual: casos de estudio, rúbrica e informe |

Carpetas de datos: [`muestra/`](muestra/README.md) y [`data/`](data/README.md).

## Orden de ejecución

```bash
# Semana 1: entorno y datos
source 00_setup/env.sh
bash 00_setup/verificar.sh
./01_extraccion/descargar_dumps.sh                 # o solo: ratings reading-log
./02_hdfs/cargar_raw.sh data/raw 2026-10-31

# Semana 2: limpieza en Spark
cd 03_limpieza_spark
python3 01_raw_a_clean.py
python3 02_clean_a_curated.py

# Semana 3: carga en PostgreSQL
cd ../05_carga_postgres
python3 exportar_csv.py
python3 cargar_postgres.py --reiniciar
psql -f verificar_carga.sql

# Semana 4: consultas
cd ../06_consultas
psql -f 01_basicas.sql
```

Para probar todo primero con la muestra, carga `muestra/` en HDFS con `./02_hdfs/cargar_raw.sh muestra muestra` y exporta `OL_RAW=hdfs://localhost:8020/raw/openlibrary/fecha=muestra` antes del paso 2 de la semana 2.

## Estado de las pruebas

Probamos el pipeline completo con la muestra, en un equipo de desarrollo con las mismas versiones (JDK 17, Hadoop 3.5.0, PySpark 4.3.0). La base de datos se probó con PostgreSQL 16, porque es la versión disponible en ese equipo; el SQL es compatible con PostgreSQL 18.

| Paso | Probado con la muestra |
|---|---|
| Descarga de dumps y verificación SHA-256 | Sí (`ratings`, `reading-log`) |
| Construcción de la muestra desde la API | Sí (200 obras, sin claves rotas) |
| Carga en HDFS con verificación de tamaño y hash | Sí |
| Limpieza y curado en PySpark | Sí, sin rechazos por clave foránea |
| Exportación a CSV y carga con `COPY` | Sí, con restricciones activas |
| Consultas de las semanas 3 y 4 | Sí, sin errores |
| Pipeline con los **dumps completos** | **No**: requiere la VM del alumno, 17.6 GB y varias horas |

Con los dumps completos, algunas etapas pueden tardar bastante más que con la muestra, sobre todo la lectura del `editions` comprimido (un solo archivo `.gz` no se puede dividir). Los tiempos reales dependen de la VM.

## Proyecto final

Trabajo individual. Eliges uno de estos casos de estudio:

- **A. Editorial:** tendencias de publicación por década, idioma y tema.
- **B. Biblioteca:** autores y temas con más ediciones y temas desatendidos.
- **C. Comportamiento lector:** obras más leídas, valoraciones y lectura por año.

Detalles, entregables y rúbrica en [`08_proyecto_final/`](08_proyecto_final/README.md).
