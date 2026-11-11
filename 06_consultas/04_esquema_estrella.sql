-- =====================================================================
-- Análisis sobre el esquema estrella (estrella.*)
-- Compara con las mismas preguntas sobre el modelo normalizado:
-- el estrella necesita menos joins y las preguntas por fecha son directas.
-- =====================================================================

-- 1. Valoración media por año de valoración
SELECT f.anio, count(*) AS valoraciones, round(avg(v.valor), 2) AS media
FROM estrella.fact_valoracion v
JOIN estrella.dim_fecha f ON f.fecha = v.fecha
GROUP BY f.anio
ORDER BY f.anio;

-- 2. Lecturas por década y estado (tabla dinámica con FILTER)
SELECT f.decada,
       count(*) FILTER (WHERE l.estado = 'Already Read')   AS leidos,
       count(*) FILTER (WHERE l.estado = 'Want to Read')   AS por_leer,
       count(*) FILTER (WHERE l.estado = 'Currently Reading') AS leyendo
FROM estrella.fact_lectura l
JOIN estrella.dim_fecha f ON f.fecha = l.fecha
GROUP BY f.decada
ORDER BY f.decada;

-- 3. Obras más antiguas (por año de primera publicación) con su media de valoración
SELECT o.titulo, o.anio_primera_publicacion, round(avg(v.valor), 2) AS media, count(*) AS n
FROM estrella.fact_valoracion v
JOIN estrella.dim_obra o ON o.obra_sk = v.obra_sk
WHERE o.anio_primera_publicacion IS NOT NULL
GROUP BY o.obra_sk, o.titulo, o.anio_primera_publicacion
HAVING count(*) >= 3
ORDER BY o.anio_primera_publicacion, media DESC
LIMIT 10;

-- 4. Trimestres con más actividad de lectura
SELECT f.anio, f.trimestre, count(*) AS eventos
FROM estrella.fact_lectura l
JOIN estrella.dim_fecha f ON f.fecha = l.fecha
GROUP BY f.anio, f.trimestre
ORDER BY eventos DESC
LIMIT 10;
