# 06 · Consultas, índices y optimización

Consultas analíticas sobre el modelo normalizado y el esquema estrella, y medición del efecto de los índices.

## Qué contiene esta carpeta

| Archivo | Tema |
|---|---|
| `01_basicas.sql` | SELECT, WHERE, GROUP BY, ORDER BY, porcentajes |
| `02_joins.sql` | INNER y LEFT JOIN, relaciones N:M, NOT EXISTS, HAVING |
| `03_ventanas.sql` | Funciones de ventana (`rank`, `sum OVER`, `lag`, `ntile`, `first_value`) y CTE |
| `04_esquema_estrella.sql` | Las mismas preguntas sobre `estrella.*`, con `FILTER` |
| `indices.sql` | Crea los índices de claves foráneas y de fechas |
| `indices_quitar.sql` | Los elimina, para repetir la medición "antes" |
| `05_explain.sql` | Tres consultas con `EXPLAIN (ANALYZE, BUFFERS)` |

## Qué se hizo

1. Escribimos consultas para las tres formas de unir tablas del curso: 1:N (obra → ediciones), N:M (obra ↔ autores) y de hechos (valoración → obra).
2. Probamos cada archivo con `ON_ERROR_STOP=1`. Encontramos tres errores de SQL que solo se ven al ejecutar, y están corregidos:
   - Un alias de ventana no puede usarse en `WHERE`: se resuelve con un CTE intermedio.
   - No se puede agrupar por una función de ventana (`GROUP BY ntile(...)`): igual, con un CTE.
   - Una consulta de títulos largos devolvía cero filas; se cambió el umbral.
3. Medimos el efecto de los índices con `EXPLAIN ANALYZE`. Con la muestra el tiempo no es representativo, pero **sí cambia el plan**: en `05_explain.sql` pasamos de `Seq Scan` a `Bitmap Index Scan` en la búsqueda de ediciones por obra y en el filtro por fecha.

## Qué necesitas para ejecutarlo

- Base cargada (`../05_carga_postgres/`).
- Entorno cargado: `source ../00_setup/env.sh`.

## Cómo ejecutarlo

```bash
cd ~/bigdata-openlibrary/06_consultas
source ../00_setup/env.sh

# Consultas (cada una imprime su resultado)
psql -f 01_basicas.sql
psql -f 02_joins.sql
psql -f 03_ventanas.sql
psql -f 04_esquema_estrella.sql

# Índices: medir antes y después
psql -f indices_quitar.sql
psql -f 05_explain.sql > antes.txt
psql -f indices.sql
psql -f 05_explain.sql > despues.txt
diff antes.txt despues.txt | less
```

En `05_explain.sql` busca dos líneas en cada consulta: `Execution Time` (tiempo real) y el tipo de nodo (`Seq Scan`, `Index Scan`, `Bitmap Heap Scan`, `Hash Join`, `Nested Loop`...).

## Qué debes entender

**Leer un plan.** `EXPLAIN` muestra el plan estimado; `EXPLAIN ANALYZE` lo ejecuta y añade el tiempo real y el número de filas reales. Compara `rows=` (estimado) con `actual ... rows=` (real): si difieren mucho, las estadísticas están desactualizadas y conviene ejecutar `ANALYZE`.

**Seq Scan vs. Index Scan.** Un `Seq Scan` lee toda la tabla. Un índice ayuda cuando la consulta devuelve una fracción pequeña de las filas. Si devuelve casi todas, PostgreSQL elige `Seq Scan` aunque haya índice, y tiene razón.

**Por qué índices en claves foráneas.** PostgreSQL crea índice para la PK, pero **no** para la FK. Sin índice en `edicion.clave_obra`, cada join o borrado de obra recorre toda la tabla de ediciones.

**Por qué no indexar todo.** Cada índice ocupa espacio y ralentiza las cargas (`COPY` tiene que actualizarlos). Por eso los índices están en un archivo aparte y se crean después de cargar: es más rápido construir un índice sobre datos cargados que insertar fila a fila con el índice ya creado.

**Ventanas vs. GROUP BY.** `GROUP BY` colapsa filas en una. Una ventana calcula sobre un conjunto de filas y **conserva cada fila**. Por eso puedes tener el ranking de cada obra dentro de su década sin perder el título. Las ventanas se evalúan después del `WHERE` y del `GROUP BY`; por eso no puedes filtrar por ellas en el mismo nivel.

**CTE.** Un `WITH` da nombre a un resultado intermedio. En PostgreSQL 12 y posteriores, el optimizador puede integrarlo en la consulta principal. Úsalo para legibilidad, y para separar un paso que no se puede expresar en un solo `SELECT` (como filtrar por una ventana).

**La muestra no sirve para medir tiempos.** Con 1.5 k ediciones y 47 k valoraciones, todo cabe en caché y los tiempos son de milisegundos. Mide tiempos con el dataset completo; aquí solo compruebas el cambio de plan.

## Problemas frecuentes

| Síntoma | Causa | Solución |
|---|---|---|
| `window functions are not allowed in WHERE` | Filtrar por una ventana en el mismo nivel | Envuélvela en un CTE y filtra después |
| `window functions are not allowed in GROUP BY` | Agrupar por una ventana | Calcula la ventana en un CTE y agrupa fuera |
| `column "x" does not exist` | Alias usado antes de definirse | El alias de `SELECT` no existe en `WHERE`; repite la expresión o usa un CTE |
| Consulta devuelve 0 filas en la muestra | La muestra es pequeña o está sesgada | Comprueba en el dataset completo; anótalo en tu informe |
| `NOTICE: index ... does not exist, skipping` | `indices_quitar.sql` sin índices previos | Es normal: solo informa |
