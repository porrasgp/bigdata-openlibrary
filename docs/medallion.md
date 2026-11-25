# Arquitectura Medallion (bronze → silver → gold)

Este proyecto es una versión reducida del curso: **solo CSV** y un ETL en tres capas. La idea medallion es que cada capa tenga una responsabilidad clara y que el resultado de una sea la entrada de la siguiente.

> Analogía: el bronze es lo que llega en la mina, el silver es lo que ya fue lavado y clasificado, y el gold es la joya lista para mostrar.

| Capa | Nombre en el proyecto | Qué contiene | Quién la produce | Regla de oro |
|---|---|---|---|---|
| **Bronze** | `data/bronze/` | Copia exacta de `muestra/csv/*.csv` + `_MANIFEST.csv` con tamaño y SHA-256 | `etl/01_bronze.py` | **No se limpia nada.** Si algo está mal, se conserva para poder diagnosticarlo. |
| **Silver** | `data/silver/` | Datos válidos, tipados, deduplicados y unificados. Rechazos en `_rechazados/` | `etl/02_silver.py` | **Calidad.** Aquí se decide qué es correcto y qué se descarta. |
| **Gold** | `data/gold/` | Modelo estrella (`dim_*`, `fact_*`) y agregaciones listas para análisis | `etl/03_gold.py` | **Negocio.** Se organiza para responder preguntas, no para almacenar. |

## ¿Por qué tres capas y no un solo script?

1. **Reproducibilidad.** Puedes volver a ejecutar una capa sin repetir las anteriores.
2. **Auditabilidad.** Si una cifra del gold sale rara, miras el silver; si el silver duda, comparas con el bronze.
3. **Separación de responsabilidades.** La persona que carga datos no tiene por qué saber qué pregunta se responderá después.
4. **Economía.** Cada capa se guarda una sola vez y se reutiliza.

## Qué pasa en cada capa de este proyecto

### 1. Bronze — aterrizaje

`etl/01_bronze.py` copia los cinco CSV de `muestra/csv/` a `data/bronze/` y escribe un manifiesto con el hash de cada archivo. Eso permite demostrar que el origen no se tocó.

```bash
python3 etl/01_bronze.py
```

### 2. Silver — limpieza

`etl/02_silver.py` lee el bronze con Spark y aplica reglas explícitas:

- la clave tiene el formato esperado (`/books/OL...M`, `/works/OL...W`, `/authors/OL...A`);
- la revisión es un número ≥ 1;
- título y nombre no están vacíos;
- si una clave aparece varias veces, gana la revisión más alta;
- fechas y números se convierten a su tipo;
- las valoraciones deben estar entre 1 y 5;
- las filas que fallan se escriben en `data/silver/_rechazados/` con el motivo.

```bash
python3 etl/02_silver.py
```

**Pregunta para discutir:** ¿por qué guardamos los rechazos en vez de borrarlos? Porque son la evidencia para mejorar las reglas.

### 3. Gold — modelo analítico

`etl/03_gold.py` convierte el silver en un modelo estrella:

- `dim_obra`: una fila por obra, con un `obra_sk` entero estable.
- `dim_fecha`: un calendario continuo entre la primera y la última fecha de los hechos.
- `fact_valoracion`: una valoración por fila.
- `fact_lectura`: un cambio de estado de lectura por fila.
- `resumen_valoraciones_anio`: ejemplo de agregación ya lista para graficar.

```bash
python3 etl/03_gold.py
```

**Pregunta para discutir:** ¿por qué la dimensión de fecha se genera completa y no solo con las fechas que aparecen? Para que las consultas no rompan cuando un año no tiene eventos.

## Permisos de cambio por capa

| Capa | Se puede cambiar | No se debe cambiar |
|---|---|---|
| Bronze | Nada (es la evidencia) | El contenido de los CSV originales |
| Silver | Reglas de limpieza, dedupe, tipos | El hecho de guardar los rechazos |
| Gold | Dimensiones, hechos, agregaciones | Las claves naturales que llegan del silver |

## Ejercicios sugeridos

1. Añade una regla en silver: títulos con más de 200 caracteres van a rechazos.
2. Cambia el orden de deduplicación por `ultima_modificacion` en lugar de `revision`.
3. Crea una nueva tabla en gold: valoraciones por década.
4. Compara el tamaño de `data/bronze` y `data/gold`: explica por qué el gold es más pequeño.

## Extensión del proyecto

El núcleo termina en `data/gold/`. A partir de ahí, el flujo completo añade dos destinos y una capa de análisis:

- [`hdfs/cargar_gold.sh`](../hdfs/cargar_gold.sh) publica los CSV en `/medallion/gold/fecha=FECHA/`.
- [`postgres/cargar_gold.py`](../postgres/cargar_gold.py) crea el esquema `estrella` con `sql/ddl.sql` y carga los CSV con `COPY`.
- [`sql/consultas.sql`](../sql/consultas.sql) contiene seis consultas sobre las dos dimensiones y las dos tablas de hechos.
- [`proyecto_final/`](../proyecto_final/) propone casos, rúbrica e informe.
- [`manual/manual.pdf`](../manual/manual.pdf) explica cómo ejecutar todo a mano.

Puedes lanzar todas las fases con `bash ejecutar_todo_completo.sh` o hacerlas una por una. En los dos casos se respeta el orden de capas descrito arriba.
