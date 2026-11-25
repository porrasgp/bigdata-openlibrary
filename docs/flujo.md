# Flujo de ejecución y de datos

Hay dos formas de leer este diagrams: **qué archivos se producen** y **en qué orden se ejecutan los scripts**.

## 1. Flujo de datos (archivos)

```mermaid
flowchart LR
    A["muestra/csv/<br/>5 CSV de ejemplo"] -->|01_bronze.py<br/>copia + SHA-256| B["data/bronze/<br/>CSV intactos + _MANIFEST.csv"]
    B -->|02_silver.py<br/>validar · dedupe · tipar| C["data/silver/<br/>CSV limpios"]
    C -->|filas que fallan| D["data/silver/_rechazados/<br/>CSV con motivo"]
    C -->|03_gold.py<br/>modelo estrella| E["data/gold/<br/>dim_*.csv · fact_*.csv"]
    E -->|resumen| F["resumen_valoraciones_anio.csv"]
    E --> G["Análisis / gráficos"]
```

La regla importante: **cada flecha es un archivo real en disco**. No hay HDFS, no hay base de datos y no hay Parquet. Puedes abrir cualquier CSV con un editor o con `head`.

## 2. Flujo de ejecución (scripts)

```mermaid
flowchart TD
    S["ejecutar_todo.sh<br/>(archivo manual, en la raíz)"] --> E["0. Detectar Java, Hadoop y el venv con PySpark"]
    E --> B["1. python3 etl/01_bronze.py"]
    B --> V["2. python3 etl/02_silver.py"]
    V --> G["3. python3 etl/03_gold.py"]
    G --> R["4. Listar los CSV generados en data/"]
    V -.si hay rechazos.-> D["data/silver/_rechazados/"]
```

`ejecutar_todo.sh` es el **único archivo que necesitas ejecutar a mano**. Los tres scripts de `etl/` también se pueden ejecutar por separado, pero, en ese caso, debes respetar el orden bronze → silver → gold.

## 3. Secuencia desde el punto de vista del alumno

```mermaid
sequenceDiagram
    participant U as Alumno
    participant S as ejecutar_todo.sh
    participant B as 01_bronze.py
    participant V as 02_silver.py
    participant G as 03_gold.py

    U->>S: bash ejecutar_todo.sh
    S->>S: preparar JAVA_HOME / HADOOP_HOME / PySpark
    S->>B: ejecutar
    B-->>S: data/bronze/*.csv + manifiesto
    S->>V: ejecutar
    V-->>S: data/silver/*.csv (+ rechazos)
    S->>G: ejecutar
    G-->>S: data/gold/*.csv
    S-->>U: resumen de archivos generados
```

## 4. Qué mirar después de ejecutar

```bash
# Ver los CSV finales
ls -lh data/bronze data/silver data/gold

# Ver por qué se rechazaron filas
head data/silver/_rechazados/*.csv

# Ver la tabla analítica final
head data/gold/resumen_valoraciones_anio.csv
```

Si quieres entender el significado de cada capa, lee [medallion.md](medallion.md).
