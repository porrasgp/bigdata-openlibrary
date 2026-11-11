-- =====================================================================
-- Consultas básicas: SELECT, WHERE, GROUP BY, ORDER BY
-- =====================================================================

-- 1. Ediciones por década (sin nulos), de más antigua a más reciente
SELECT decada, count(*) AS ediciones
FROM openlibrary.edicion
WHERE decada IS NOT NULL
GROUP BY decada
ORDER BY decada;

-- 2. Los 10 idiomas con más ediciones
SELECT codigo AS idioma, count(*) AS ediciones
FROM openlibrary.edicion_idioma
GROUP BY codigo
ORDER BY ediciones DESC
LIMIT 10;

-- 3. Distribución de valoraciones (1 a 5 estrellas)
SELECT valor, count(*) AS valoraciones,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS porcentaje
FROM openlibrary.valoracion
GROUP BY valor
ORDER BY valor;

-- 4. Estados de lectura, con el número de obras distintas
SELECT estado, count(*) AS eventos, count(DISTINCT clave_obra) AS obras
FROM openlibrary.lectura
GROUP BY estado
ORDER BY eventos DESC;

-- 5. Obras con título largo: filtro por longitud de texto
SELECT clave_obra, titulo, length(titulo) AS longitud
FROM openlibrary.obra
WHERE length(titulo) > 40
ORDER BY longitud DESC
LIMIT 5;

-- 6. Editoriales con más ediciones (agregación sobre relación N:M)
SELECT e.nombre AS editorial, count(*) AS ediciones
FROM openlibrary.edicion_editorial ee
JOIN openlibrary.editorial e ON e.editorial_id = ee.editorial_id
GROUP BY e.nombre
ORDER BY ediciones DESC
LIMIT 10;
