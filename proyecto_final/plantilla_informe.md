# Informe del proyecto final

**Nombre:**
**Caso de estudio (A, B, C u otro):**
**Fecha del snapshot (`OL_FECHA`):**

## 1. Pregunta de negocio

Una o dos frases. Qué quieres saber y para quién.

## 2. Fuente de datos

- CSV usados de `muestra/csv/` y número de filas de cada uno.
- Licencia: CC0 1.0 (Open Library).
- Qué información no está incluida y por qué.
- Fecha del snapshot usada en HDFS y en el informe.

## 3. Arquitectura del pipeline

Diagrama o lista:

`muestra/csv` -> `bronze` -> `silver` -> `gold` -> `HDFS` -> `PostgreSQL` -> `consultas SQL`

Indica qué script produce cada paso y cómo se ejecuta todo a mano.

## 4. Limpieza y validación

- Reglas aplicadas en silver (tabla con motivo y cantidad rechazada).
- Tu validación o transformación propia: qué hace y por qué la añadiste.
- Decisión de deduplicación.
- Tratamiento de nulos y fechas.

## 5. Modelo de datos

- Diagrama del esquema estrella (`dim_obra`, `dim_fecha`, dos hechos y resumen).
- PK, FK y CHECK, con justificación.
- Extensiones que añadiste a `sql/ddl.sql`.
- Limitación importante: el gold actual no tiene autores, editoriales ni temas como dimensiones.

## 6. Resultados

- Tus 5 consultas principales y sus resultados.
- Al menos una tabla o gráfico.
- Responde explícitamente a la pregunta del apartado 1.

## 7. Optimización

| Consulta | Sin índices | Con índices | Cambio en el plan |
|---|---|---|---|
| | | | |

Explica qué viste en `EXPLAIN ANALYZE` (Seq Scan, Index Scan, tiempos).

## 8. Limitaciones

- Qué no puede responder este dataset.
- Sesgos posibles (por ejemplo, qué obras tienen más valoraciones registradas).
- Limitaciones técnicas del entorno (RAM, tiempo, una sola fecha de snapshot).

## 9. Conclusiones

Tres frases máximo: qué aprendiste del dato y qué harías diferente.

## Referencias

- Open Library Data Dumps: https://openlibrary.org/developers/dumps
- Licencia de los datos: https://openlibrary.org/developers/licensing
- Manual de ejecución de este repo: `manual/manual.pdf`
