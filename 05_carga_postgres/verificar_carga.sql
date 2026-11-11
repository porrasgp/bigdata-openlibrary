-- Conteos y tamaño de cada tabla. Ejecutar con:
--   psql -f verificar_carga.sql

\echo '== Filas por tabla (openlibrary)'
SELECT 'obra' AS tabla, count(*) AS filas FROM openlibrary.obra
UNION ALL SELECT 'autor', count(*) FROM openlibrary.autor
UNION ALL SELECT 'editorial', count(*) FROM openlibrary.editorial
UNION ALL SELECT 'idioma', count(*) FROM openlibrary.idioma
UNION ALL SELECT 'tema', count(*) FROM openlibrary.tema
UNION ALL SELECT 'edicion', count(*) FROM openlibrary.edicion
UNION ALL SELECT 'obra_autor', count(*) FROM openlibrary.obra_autor
UNION ALL SELECT 'edicion_autor', count(*) FROM openlibrary.edicion_autor
UNION ALL SELECT 'edicion_editorial', count(*) FROM openlibrary.edicion_editorial
UNION ALL SELECT 'edicion_idioma', count(*) FROM openlibrary.edicion_idioma
UNION ALL SELECT 'obra_tema', count(*) FROM openlibrary.obra_tema
UNION ALL SELECT 'valoracion', count(*) FROM openlibrary.valoracion
UNION ALL SELECT 'lectura', count(*) FROM openlibrary.lectura;

\echo '== Filas por tabla (estrella)'
SELECT 'dim_obra' AS tabla, count(*) AS filas FROM estrella.dim_obra
UNION ALL SELECT 'dim_fecha', count(*) FROM estrella.dim_fecha
UNION ALL SELECT 'fact_valoracion', count(*) FROM estrella.fact_valoracion
UNION ALL SELECT 'fact_lectura', count(*) FROM estrella.fact_lectura;

\echo '== Tamaño en disco (tabla + índices)'
SELECT n.nspname AS esquema,
       c.relname AS tabla,
       pg_size_pretty(pg_total_relation_size(c.oid)) AS tamano
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('openlibrary', 'estrella') AND c.relkind = 'r'
ORDER BY pg_total_relation_size(c.oid) DESC;

\echo '== Tamaño total de los esquemas'
SELECT n.nspname AS esquema,
       pg_size_pretty(sum(pg_total_relation_size(c.oid))) AS tamano
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('openlibrary', 'estrella') AND c.relkind = 'r'
GROUP BY n.nspname;
