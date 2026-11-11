-- =====================================================================
-- Medir el efecto de los índices con EXPLAIN ANALYZE
--
-- Procedimiento:
--   1. Quitar índices:    psql -f indices_quitar.sql
--   2. Ejecutar este archivo y anotar "Execution Time" de cada consulta.
--   3. Crear índices:     psql -f indices.sql
--   4. Ejecutar de nuevo y comparar.
--
-- BUFFERS muestra cuántas páginas de disco se leen (lo que más pesa en datos grandes).
-- =====================================================================

-- A. Ediciones de una obra concreta (búsqueda por clave foránea)
EXPLAIN (ANALYZE, BUFFERS)
SELECT e.clave_edicion, e.titulo, e.anio_publicacion
FROM openlibrary.edicion e
WHERE e.clave_obra = (
    SELECT clave_obra FROM openlibrary.valoracion GROUP BY clave_obra ORDER BY count(*) DESC LIMIT 1
);

-- B. Valoraciones de un rango de fechas (filtro por fecha)
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*), round(avg(valor), 2)
FROM openlibrary.valoracion
WHERE fecha BETWEEN DATE '2020-01-01' AND DATE '2020-12-31';

-- C. Join de valoraciones con obras y autores (sensible a índices de unión)
EXPLAIN (ANALYZE, BUFFERS)
SELECT a.nombre, count(*) AS valoraciones
FROM openlibrary.valoracion v
JOIN openlibrary.obra_autor oa ON oa.clave_obra = v.clave_obra
JOIN openlibrary.autor a       ON a.clave_autor = oa.clave_autor
GROUP BY a.nombre
ORDER BY valoraciones DESC
LIMIT 10;
