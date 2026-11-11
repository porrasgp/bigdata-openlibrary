-- =====================================================================
-- Joins: relaciones 1:N y N:M del modelo normalizado
-- =====================================================================

-- 1. Obra con sus autores (N:M a través de obra_autor)
SELECT o.titulo AS obra, a.nombre AS autor
FROM openlibrary.obra o
JOIN openlibrary.obra_autor oa ON oa.clave_obra = o.clave_obra
JOIN openlibrary.autor a       ON a.clave_autor = oa.clave_autor
ORDER BY o.titulo
LIMIT 20;

-- 2. Autores con más obras en el dataset
SELECT a.nombre AS autor, count(*) AS obras
FROM openlibrary.autor a
JOIN openlibrary.obra_autor oa ON oa.clave_autor = a.clave_autor
GROUP BY a.nombre
ORDER BY obras DESC
LIMIT 10;

-- 3. Obra con número de ediciones (1:N). LEFT JOIN para incluir obras sin ediciones
SELECT o.clave_obra, o.titulo, count(e.clave_edicion) AS ediciones
FROM openlibrary.obra o
LEFT JOIN openlibrary.edicion e ON e.clave_obra = o.clave_obra
GROUP BY o.clave_obra, o.titulo
ORDER BY ediciones DESC, o.titulo
LIMIT 10;

-- 4. Obras que nunca han sido valoradas (anti-join con NOT EXISTS).
--    OJO: en la muestra devuelve 0 filas, porque la muestra se eligió por eventos
--    (cada obra tiene valoraciones). En el dataset completo sí habrá resultados.
SELECT o.clave_obra, o.titulo
FROM openlibrary.obra o
WHERE NOT EXISTS (
    SELECT 1 FROM openlibrary.valoracion v WHERE v.clave_obra = o.clave_obra
)
ORDER BY o.titulo
LIMIT 10;

-- 5. Valoración media por obra, con título y autores (tres tablas)
SELECT o.titulo,
       string_agg(DISTINCT a.nombre, ', ') AS autores,
       count(*) AS valoraciones,
       round(avg(v.valor), 2) AS media
FROM openlibrary.valoracion v
JOIN openlibrary.obra o        ON o.clave_obra = v.clave_obra
LEFT JOIN openlibrary.obra_autor oa ON oa.clave_obra = o.clave_obra
LEFT JOIN openlibrary.autor a  ON a.clave_autor = oa.clave_autor
GROUP BY o.clave_obra, o.titulo
HAVING count(*) >= 3
ORDER BY media DESC, valoraciones DESC
LIMIT 10;

-- 6. Temas más frecuentes de las obras (N:M con tema)
SELECT t.nombre AS tema, count(*) AS obras
FROM openlibrary.obra_tema ot
JOIN openlibrary.tema t ON t.tema_id = ot.tema_id
GROUP BY t.nombre
ORDER BY obras DESC
LIMIT 10;

-- 7. Lecturas de cada obra con la edición que se leyó (si existe)
SELECT l.estado, o.titulo, e.titulo AS edicion, e.anio_publicacion
FROM openlibrary.lectura l
JOIN openlibrary.obra o ON o.clave_obra = l.clave_obra
LEFT JOIN openlibrary.edicion e ON e.clave_edicion = l.clave_edicion
LIMIT 20;
