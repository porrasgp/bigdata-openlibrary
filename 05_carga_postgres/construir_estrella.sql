-- Llena el esquema estrella a partir del modelo normalizado.
-- Se ejecuta desde cargar_postgres.py después de cargar openlibrary.*.
-- Es repetible: vacía las tablas antes de llenarlas.

TRUNCATE estrella.fact_lectura, estrella.fact_valoracion,
         estrella.dim_obra, estrella.dim_fecha
RESTART IDENTITY;

INSERT INTO estrella.dim_obra (clave_obra, titulo, anio_primera_publicacion, num_portadas)
SELECT clave_obra, titulo, anio_primera_publicacion, num_portadas
FROM openlibrary.obra;

-- Calendario continuo entre la primera y la última fecha de los hechos
INSERT INTO estrella.dim_fecha (fecha, anio, trimestre, mes, dia, decada)
SELECT
    d::date,
    extract(year FROM d)::int,
    extract(quarter FROM d)::int,
    extract(month FROM d)::int,
    extract(day FROM d)::int,
    (floor(extract(year FROM d) / 10) * 10)::int
FROM (
    SELECT min(f) AS desde, max(f) AS hasta
    FROM (
        SELECT fecha AS f FROM openlibrary.valoracion
        UNION ALL
        SELECT fecha FROM openlibrary.lectura
    ) fechas
) rango,
generate_series(rango.desde, rango.hasta, interval '1 day') AS d
WHERE rango.desde IS NOT NULL;

INSERT INTO estrella.fact_valoracion (fecha, obra_sk, valor)
SELECT v.fecha, o.obra_sk, v.valor
FROM openlibrary.valoracion v
JOIN estrella.dim_obra o ON o.clave_obra = v.clave_obra;

INSERT INTO estrella.fact_lectura (fecha, obra_sk, estado)
SELECT l.fecha, o.obra_sk, l.estado
FROM openlibrary.lectura l
JOIN estrella.dim_obra o ON o.clave_obra = l.clave_obra;

ANALYZE estrella.dim_obra;
ANALYZE estrella.dim_fecha;
ANALYZE estrella.fact_valoracion;
ANALYZE estrella.fact_lectura;
