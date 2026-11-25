-- Consultas de ejemplo sobre el esquema estrella cargado desde data/gold.
-- Uso: psql -v ON_ERROR_STOP=1 -f sql/consultas.sql
--
-- Todas responden preguntas que se pueden responder con las dos dimensiones
-- (obra y fecha) y las dos tablas de hechos (valoración y lectura).

\timing on

\echo === Q1. Top 10 de obras mejor valoradas (con al menos 100 valoraciones) ===
SELECT o.titulo,
       count(*) AS valoraciones,
       round(avg(f.valor), 2) AS promedio
FROM estrella.fact_valoracion f
JOIN estrella.dim_obra o USING (obra_sk)
GROUP BY o.obra_sk, o.titulo
HAVING count(*) >= 100
ORDER BY promedio DESC, valoraciones DESC
LIMIT 10;

\echo === Q2. Evolución mensual de valoraciones, con acumulado (ventana) ===
WITH mensual AS (
    SELECT date_trunc('month', fecha)::date AS mes, count(*) AS valoraciones
    FROM estrella.fact_valoracion
    GROUP BY 1
)
SELECT mes,
       valoraciones,
       sum(valoraciones) OVER (
           ORDER BY mes ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS acumulado
FROM mensual
ORDER BY mes;

\echo === Q3. Estados de lectura por año ===
SELECT d.anio, l.estado, count(*) AS eventos
FROM estrella.fact_lectura l
JOIN estrella.dim_fecha d USING (fecha)
GROUP BY d.anio, l.estado
ORDER BY d.anio, eventos DESC;

\echo === Q4. Valoración media por década ===
SELECT d.decada,
       count(*) AS valoraciones,
       round(avg(f.valor), 2) AS promedio
FROM estrella.fact_valoracion f
JOIN estrella.dim_fecha d USING (fecha)
GROUP BY d.decada
ORDER BY d.decada;

\echo === Q5. Comprobar el resumen del gold contra los hechos ===
SELECT r.anio,
       r.valoraciones AS guardadas,
       count(f.*) AS recalculadas,
       r.valor_promedio AS promedio_guardado,
       round(avg(f.valor), 2) AS promedio_recalculado
FROM estrella.resumen_valoraciones_anio r
LEFT JOIN estrella.fact_valoracion f
       ON date_part('year', f.fecha)::int = r.anio
GROUP BY r.anio, r.valoraciones, r.valor_promedio
ORDER BY r.anio;

\echo === Q6. EXPLAIN ANALYZE (para el ejercicio de optimización) ===
EXPLAIN ANALYZE
SELECT o.titulo, count(*) AS valoraciones
FROM estrella.fact_valoracion f
JOIN estrella.dim_obra o USING (obra_sk)
GROUP BY o.obra_sk, o.titulo
ORDER BY valoraciones DESC
LIMIT 10;

-- Ejercicio: quita los índices, vuelve a ejecutar Q6 y compara el plan.
--   DROP INDEX estrella.idx_valoracion_obra;
--   psql -f sql/ddl.sql   -- solo si quieres recrearlos en un esquema vacío
