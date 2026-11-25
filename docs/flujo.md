# Flujo de ejecución y de datos

Hay dos niveles bien separados:

1. **Núcleo medallion:** CSV local → bronze → silver → gold.
2. **Extensión:** gold → HDFS → PostgreSQL → consultas SQL → proyecto final.

Puedes ejecutar solo el núcleo o el flujo completo. En ambos casos todo se hace a mano desde la raíz del repo.

## 1. Flujo de datos del núcleo (archivos)

```mermaid
flowchart LR
    A["muestra/csv/<br/>5 CSV de ejemplo"] -->|01_bronze.py<br/>copia + SHA-256| B["data/bronze/<br/>CSV intactos + _MANIFEST.csv"]
    B -->|02_silver.py<br/>validar · dedupe · tipar| C["data/silver/<br/>CSV limpios"]
    C -->|filas que fallan| D["data/silver/_rechazados/<br/>CSV con motivo"]
    C -->|03_gold.py<br/>modelo estrella| E["data/gold/<br/>dim_*.csv · fact_*.csv"]
    E --> F["resumen_valoraciones_anio.csv"]
```

En el núcleo, cada flecha es un archivo real en disco. No hay HDFS ni base de datos: puedes abrir cualquier CSV con `head` o con un editor.

## 2. Flujo de ejecución del núcleo (scripts)

```mermaid
flowchart TD
    S["ejecutar_todo.sh"] --> E["0. Detectar Java, Hadoop y el venv con PySpark"]
    E --> B["1. python3 etl/01_bronze.py"]
    B --> V["2. python3 etl/02_silver.py"]
    V --> G["3. python3 etl/03_gold.py"]
    G --> R["4. Listar los CSV generados en data/"]
    V -.si hay rechazos.-> D["data/silver/_rechazados/"]
```

`ejecutar_todo.sh` es el script del núcleo. Los tres scripts de `etl/` también se pueden ejecutar por separado, siempre en orden bronze → silver → gold.

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

## 4. Flujo completo (extensión)

```mermaid
flowchart LR
    G["data/gold/*.csv"] -->|hdfs/cargar_gold.sh| H["HDFS<br/>/medallion/gold/fecha=FECHA/"]
    G -->|postgres/cargar_gold.py<br/>COPY| P["PostgreSQL<br/>esquema estrella"]
    H -->|opcional: inspeccionar| R["hdfs/reportar_hdfs.sh"]
    P -->|sql/verificar.sql| V["conteos e integridad"]
    P -->|sql/consultas.sql| Q["6 consultas + EXPLAIN ANALYZE"]
    Q --> F["proyecto_final/<br/>caso, rúbrica e informe"]
    M["manual/manual.pdf"] -.explica todo.-> G
```

HDFS y PostgreSQL son dos destinos independientes del mismo gold: uno publica los CSV en un lago con partición por fecha; el otro los carga en tablas con restricciones.

## 5. Flujo de ejecución completo

```mermaid
flowchart TD
    C["ejecutar_todo_completo.sh"] --> E0["0. Detectar Java, Hadoop, venv y PostgreSQL"]
    E0 --> E1["1. Asegurar HDFS y PostgreSQL"]
    E1 --> N["2. bash ejecutar_todo.sh<br/>bronze -> silver -> gold"]
    N --> E2["3. bash hdfs/cargar_gold.sh FECHA"]
    E2 --> E3["4. python3 postgres/cargar_gold.py --reiniciar"]
    E3 --> E4["5. psql -f sql/verificar.sql"]
    E4 --> E5["6. psql -f sql/consultas.sql"]
    E5 --> E6["7. Resultados en pantalla y /tmp/opencode/consultas.out"]
```

## 6. Qué mirar después de ejecutar

```bash
# CSV finales y rechazos
ls -lh data/bronze data/silver data/gold
head data/silver/_rechazados/*.csv
head data/gold/resumen_valoraciones_anio.csv

# HDFS
bash hdfs/reportar_hdfs.sh

# PostgreSQL
psql -v ON_ERROR_STOP=1 -f sql/verificar.sql
psql -v ON_ERROR_STOP=1 -f sql/consultas.sql
```

Para la explicación paso a paso, consulta el [manual PDF](../manual/manual.pdf). Para la teoría de las capas, lee [medallion.md](medallion.md).
