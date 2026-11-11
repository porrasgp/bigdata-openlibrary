-- =====================================================================
-- Funciones de ventana y CTE
-- =====================================================================

-- 1. Ranking de obras por valoración media dentro de cada década
--    de su primera publicación (solo obras con al menos 3 valoraciones)
-- Un alias de ventana (puesto) no se puede usar en WHERE: por eso hay un segundo CTE.
WITH medias AS (
    SELECT o.clave_obra, o.titulo, o.anio_primera_publicacion,
           (o.anio_primera_publicacion / 10) * 10 AS decada,
           count(*) AS valoraciones,
           avg(v.valor) AS media
    FROM openlibrary.obra o
    JOIN openlibrary.valoracion v ON v.clave_obra = o.clave_obra
    WHERE o.anio_primera_publicacion IS NOT NULL
    GROUP BY o.clave_obra, o.titulo, o.anio_primera_publicacion
    HAVING count(*) >= 3
),
ranking AS (
    SELECT decada, titulo, valoraciones, media,
           rank() OVER (PARTITION BY decada ORDER BY media DESC, valoraciones DESC) AS puesto
    FROM medias
)
SELECT decada, titulo, valoraciones, round(media, 2) AS media, puesto
FROM ranking
WHERE puesto <= 3
ORDER BY decada, puesto;

-- 2. Lecturas por mes y acumulado (suma acumulada con ventana)
WITH por_mes AS (
    SELECT date_trunc('month', fecha)::date AS mes, count(*) AS eventos
    FROM openlibrary.lectura
    GROUP BY 1
)
SELECT mes, eventos,
       sum(eventos) OVER (ORDER BY mes) AS acumulado
FROM por_mes
ORDER BY mes;

-- 3. Cambio mes a mes en el número de valoraciones (LAG)
WITH por_mes AS (
    SELECT date_trunc('month', fecha)::date AS mes, count(*) AS n
    FROM openlibrary.valoracion
    GROUP BY 1
)
SELECT mes, n,
       n - lag(n) OVER (ORDER BY mes) AS cambio_respecto_mes_anterior
FROM por_mes
ORDER BY mes
LIMIT 24;

-- 4. Primera y última valoración de cada obra (first_value / last_value)
SELECT DISTINCT
       o.titulo,
       first_value(v.fecha) OVER w AS primera,
       last_value(v.fecha)  OVER w AS ultima,
       count(*) OVER (PARTITION BY o.clave_obra) AS valoraciones
FROM openlibrary.valoracion v
JOIN openlibrary.obra o ON o.clave_obra = v.clave_obra
WINDOW w AS (
    PARTITION BY o.clave_obra ORDER BY v.fecha
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
)
ORDER BY valoraciones DESC, o.titulo
LIMIT 10;

-- 5. Cuartiles de popularidad: cuántas valoraciones tiene cada cuartil de obras.
--    La ventana va en un CTE: no se puede agrupar por una función de ventana.
WITH conteo AS (
    SELECT clave_obra, count(*) AS n
    FROM openlibrary.valoracion
    GROUP BY clave_obra
),
cuartiles AS (
    SELECT n, ntile(4) OVER (ORDER BY n) AS cuartil
    FROM conteo
)
SELECT cuartil,
       min(n) AS min_valoraciones,
       max(n) AS max_valoraciones,
       count(*) AS obras
FROM cuartiles
GROUP BY cuartil
ORDER BY cuartil;
