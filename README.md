# Big Data con Open Library

Curso práctico de big data: desde la descarga de datos públicos hasta un proyecto final analítico.

Stack: Ubuntu 26.04 LTS, Java 17, Hadoop 3.5.0 (HDFS), PySpark 4.3.0, PostgreSQL 18.

## Datos

Fuente: [Open Library Data Dumps](https://openlibrary.org/developers/dumps), licencia **CC0 1.0** (dominio público).

Snapshot fijo: **2026-10-31**. Todos los alumnos usan la misma fecha.

| Dump | Comprimido | Uso en el curso |
|---|---|---|
| editions | 12.6 GB | Ediciones (tabla grande) |
| works | 4.1 GB | Obras |
| authors | 0.8 GB | Autores |
| ratings | 9 MB | Valoraciones de lectores |
| reading-log | 125 MB | Estado de lectura por obra |
| **Total** | **~17.6 GB** | |

Los datos completos no se suben al repositorio (ver `.gitignore`). Descárgalos con `01_extraccion/descargar_dumps.sh`. La carpeta `muestra/` contiene un subconjunto pequeño para probar el pipeline sin descargar todo. Los datos se usan en dos formatos:

- `muestra/*.tsv.gz`: copia del formato original de los dumps.
- `muestra/csv/*.csv`: el mismo contenido en CSV plano, con los campos del JSON como columnas. Es el formato de trabajo del curso. El conversor está en `01_extraccion/convertir_a_csv.py`.

## Requisitos de la VM

| Recurso | Mínimo |
|---|---|
| Hipervisor | VirtualBox |
| SO invitado | Ubuntu 26.04.1 LTS (escritorio o servidor) |
| RAM | 8 GB |
| CPU | 4 vCPU |
| Disco | 120 GB |

## Mapa del curso

| Semana | Carpeta | Contenido |
|---|---|---|
| 1 | `00_setup/`, `01_extraccion/`, `02_hdfs/` | Entorno, descarga de dumps, carga raw en HDFS |
| 2 | `03_limpieza_spark/` | PySpark: raw → clean → curated en Parquet |
| 3 | `04_modelado/`, `05_carga_postgres/` | Modelo 3FN, esquema estrella, carga a PostgreSQL |
| 4 | `06_consultas/`, `07_ejercicios/`, `08_proyecto_final/` | Consultas analíticas y proyecto final |

## Proyecto final

Trabajo individual. Eliges uno de estos casos de estudio:

- **A. Editorial:** tendencias de publicación por década, idioma y tema.
- **B. Biblioteca:** autores y temas con más ediciones y temas desatendidos.
- **C. Comportamiento lector:** obras más leídas, valoraciones y lectura por año.

Detalles, entregables y rúbrica en `08_proyecto_final/`.

## Inicio rápido

```bash
git clone https://github.com/porrasgp/bigdata-openlibrary.git
cd bigdata-openlibrary
# 1. Prepara la VM: ver 00_setup/README.md
# 2. Verifica el entorno:
./00_setup/verificar.sh
# 3. Descarga los datos (~17.6 GB):
./01_extraccion/descargar_dumps.sh
```
