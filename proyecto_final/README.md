# Proyecto final

Trabajo individual de 4 semanas. Debes usar el pipeline del curso para responder una pregunta sobre los datos de Open Library y presentar los resultados.

La diferencia respecto a las prácticas es que **tú eliges la pregunta** y añades al menos una transformación o validación propia.

## Qué contiene esta carpeta

| Archivo | Para qué sirve |
|---|---|
| `README.md` | Este documento: casos, entregables, reglas y cronograma |
| `rubrica.md` | Criterios de evaluación (100 puntos) |
| `plantilla_informe.md` | Estructura del informe final |

Aquí no hay código: el proyecto es tu propio repositorio, construido a partir de este.

## Qué necesitas para empezar

1. Haber ejecutado `bash ejecutar_todo.sh` (CSV → bronze → silver → gold).
2. Haber ejecutado `bash hdfs/cargar_gold.sh` y `python3 postgres/cargar_gold.py --reiniciar`.
3. Haber probado `psql -f sql/verificar.sql` y `psql -f sql/consultas.sql`.
4. Leer el [manual PDF](../manual/manual.pdf) para saber cómo ejecutar todo a mano.

El flujo completo también se puede lanzar con:

```bash
bash ejecutar_todo_completo.sh
```

## Casos de estudio

### A. Evolución temporal de las valoraciones

- **Pregunta:** ¿cómo cambia el número de valoraciones y su promedio por año y por década?
- **Tablas clave:** `estrella.fact_valoracion`, `estrella.dim_fecha`.
- **Métricas sugeridas:** valoraciones por año, promedio por década, acumulado mensual, picos atípicos.
- **Pista:** `dim_fecha` ya trae `anio`, `trimestre`, `mes` y `decada`; úsalas antes de calcularlas a mano.

### B. Calidad percibida de las obras

- **Pregunta:** ¿qué obras tienen mejor valoración media y cuántos votos respaldan esa media?
- **Tablas clave:** `estrella.dim_obra`, `estrella.fact_valoracion`.
- **Métricas sugeridas:** top 10 con umbral mínimo de votos, dispersión de votos, obras con pocas valoraciones.
- **Pista:** sin umbral mínimo, una obra con un solo voto de 5 empata con una obra muy valorada. Discútelo en el informe.

### C. Comportamiento lector

- **Pregunta:** ¿qué estados de lectura aparecen más y cómo cambian con el tiempo?
- **Tablas clave:** `estrella.fact_lectura`, `estrella.dim_fecha`, `estrella.dim_obra`.
- **Métricas sugeridas:** eventos por estado y año, obras con más eventos, ratio entre estados.
- **Pista:** `fact_lectura` registra cambios de estado, no lectores únicos. No confundas evento con persona.

Puedes proponer otro caso si la pregunta se puede responder con las tablas del gold. Si necesitas otra columna, añádela en la capa silver/gold y justifica el cambio.

## Entregables

1. **Pipeline reproducible.** Desde los CSV de `muestra/csv/` hasta PostgreSQL, con un README que indique el orden exacto de ejecución. Debes modificar o añadir al menos una transformación o validación propia en `etl/`.
2. **Publicación en HDFS.** Sube el gold con `hdfs/cargar_gold.sh` y reporta la ruta `fecha=...`, el tamaño y la comprobación de hash.
3. **Modelo en PostgreSQL.** Usa el esquema `estrella`, justifica PK/FK/CHECK y documents cualquier extensión que hagas en `sql/ddl.sql`.
4. **Consultas analíticas.** Al menos 5 que respondan tu pregunta; puedes partir de `sql/consultas.sql` pero debes añadir las tuyas.
5. **Optimización.** `EXPLAIN ANALYZE` de al menos 2 consultas antes y después de crear/quitar índices, con interpretación del plan.
6. **Informe.** Usa `plantilla_informe.md`. Máximo 6 páginas.
7. **Presentación.** 10 minutos con demo en vivo de una consulta.

## Reglas

- Los datos son públicos (CC0). Cita la fuente en el informe.
- Usa siempre la **misma fecha de snapshot** (`OL_FECHA`, por defecto el día de ejecución) en HDFS, PostgreSQL y el informe.
- No subas datos generados (`data/`), contraseñas ni tokens al repositorio.
- Cada decisión de limpieza o modelado debe estar justificada.
- Si una pregunta no se puede responder con estos datos, di por qué: eso también es un resultado.

## Qué debes entender antes de empezar

- **Reproducible** significa que otra persona puede correrlo siguiendo solo tu README.
- **La pregunta va antes que el modelo.** No diseñes tablas sin saber qué vas a responder.
- **Mide antes de optimizar.** Un índice que no cambia el plan no mejora nada.
- **Las limitaciones son parte del resultado.** No afirmes más de lo que el dataset permite.

## Cronograma

| Semana | Objetivo |
|---|---|
| 1 | Entorno funcionando, medallion CSV ejecutado, caso elegido |
| 2 | Validación/transformación propia en silver o gold y carga en HDFS verificada |
| 3 | PostgreSQL cargado y consultas propias funcionando |
| 4 | Optimización medida, informe y presentación |

## Evaluación

Ver [`rubrica.md`](rubrica.md). Total: 100 puntos.
