-- Verificación mínima después de cargar el gold.
-- Uso: psql -v ON_ERROR_STOP=1 -f sql/verificar.sql

\echo === Conteo de tablas (valores esperados en la muestra) ===
SELECT 'dim_obra' AS tabla, count(*) AS filas FROM estrella.dim_obra
UNION ALL SELECT 'dim_fecha', count(*) FROM estrella.dim_fecha
UNION ALL SELECT 'fact_valoracion', count(*) FROM estrella.fact_valoracion
UNION ALL SELECT 'fact_lectura', count(*) FROM estrella.fact_lectura
UNION ALL SELECT 'resumen_valoraciones_anio', count(*) FROM estrella.resumen_valoraciones_anio
ORDER BY tabla;

\echo === Integridad referencial (las cuatro filas deben dar 0) ===
SELECT 'valoracion sin obra' AS prueba, count(*) AS filas
FROM estrella.fact_valoracion f
LEFT JOIN estrella.dim_obra o ON o.obra_sk = f.obra_sk
WHERE o.obra_sk IS NULL
UNION ALL
SELECT 'valoracion sin fecha', count(*)
FROM estrella.fact_valoracion f
LEFT JOIN estrella.dim_fecha d ON d.fecha = f.fecha
WHERE d.fecha IS NULL
UNION ALL
SELECT 'lectura sin obra', count(*)
FROM estrella.fact_lectura f
LEFT JOIN estrella.dim_obra o ON o.obra_sk = f.obra_sk
WHERE o.obra_sk IS NULL
UNION ALL
SELECT 'lectura sin fecha', count(*)
FROM estrella.fact_lectura f
LEFT JOIN estrella.dim_fecha d ON d.fecha = f.fecha
WHERE d.fecha IS NULL
ORDER BY prueba;

\echo === Suma de control del resumen ===
SELECT sum(valoraciones) AS total_valoraciones,
       round(avg(valor_promedio), 2) AS promedio_de_promedios
FROM estrella.resumen_valoraciones_anio;
