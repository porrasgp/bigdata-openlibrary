-- Soluciones de los ejercicios SQL (ver ../ejercicios.md)
-- Para ejecutarlas: psql -f soluciones.sql

-- ---------------------------------------------------------------- E9
-- Dimensión de autor en el esquema estrella

CREATE TABLE IF NOT EXISTS estrella.dim_autor (
    autor_sk      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    clave_autor   text NOT NULL UNIQUE,
    nombre        text NOT NULL
);

TRUNCATE estrella.dim_autor RESTART IDENTITY;

INSERT INTO estrella.dim_autor (clave_autor, nombre)
SELECT clave_autor, nombre
FROM openlibrary.autor;

-- Valoraciones por autor. Una obra con dos autores cuenta para los dos,
-- así que la suma de esta columna puede superar el total de valoraciones.
SELECT a.nombre, count(*) AS valoraciones
FROM estrella.fact_valoracion fv
JOIN estrella.dim_obra o       ON o.obra_sk = fv.obra_sk
JOIN openlibrary.obra_autor oa ON oa.clave_obra = o.clave_obra
JOIN estrella.dim_autor a      ON a.clave_autor = oa.clave_autor
GROUP BY a.nombre
ORDER BY valoraciones DESC
LIMIT 10;

-- ---------------------------------------------------------------- E11
-- Decil de la media de valoración, solo obras con al menos 5 valoraciones

-- No se puede agrupar por una función de ventana: el decil se calcula en un CTE aparte.
WITH medias AS (
    SELECT clave_obra, count(*) AS n, avg(valor) AS media
    FROM openlibrary.valoracion
    GROUP BY clave_obra
    HAVING count(*) >= 5
),
deciles AS (
    SELECT media, ntile(10) OVER (ORDER BY media) AS decil
    FROM medias
)
SELECT decil,
       count(*) AS obras,
       round(min(media), 2) AS media_minima,
       round(max(media), 2) AS media_maxima
FROM deciles
GROUP BY decil
ORDER BY decil;
