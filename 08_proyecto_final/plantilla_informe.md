# Informe del proyecto final

**Nombre:** 
**Caso de estudio (A, B o C):** 
**Fecha del snapshot usado:** 2026-10-31

## 1. Pregunta de negocio

Una o dos frases. Qué quieres saber y para quién.

## 2. Fuente de datos

- Dumps usados y tamaños (ver `manifiesto_2026-10-31.tsv`).
- Licencia: CC0 1.0.
- Qué no está incluido y por qué.

## 3. Arquitectura del pipeline

Diagrama o lista: raw → HDFS → clean (Spark) → curated → CSV → PostgreSQL → consultas.

## 4. Limpieza y validación

- Reglas de validación (tabla con motivo y cantidad rechazada).
- Decisiones de deduplicación.
- Valores nulos y cómo se trataron.

## 5. Modelo de datos

- Diagrama ER o estrella.
- Claves primarias y foráneas, con justificación.
- Relaciones N:M y cómo se resolvieron.

## 6. Resultados

Consultas principales y sus resultados. Incluye al menos un gráfico o tabla.

## 7. Optimización

| Consulta | Sin índices | Con índices | Cambio en el plan |
|---|---|---|---|
| | | | |

## 8. Limitaciones

- Qué no puede responder el dataset.
- Sesgos (por ejemplo, qué obras tienden a estar registradas).
- Limitaciones técnicas del entorno (RAM, tiempos).

## 9. Conclusiones

Tres frases máximo: qué aprendiste del dato y qué harías diferente.

## Referencias

- Open Library Data Dumps: https://openlibrary.org/developers/dumps
- Licencia de los datos: https://openlibrary.org/developers/licensing
