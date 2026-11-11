-- =====================================================================
-- Esquema estrella para análisis (Open Library)
-- Esquema: estrella
--
-- Tablas de hechos (una fila por evento):
--   fact_valoracion   una valoración de una obra
--   fact_lectura      un cambio de estado de lectura de una obra
-- Dimensiones:
--   dim_obra          obra (con clave sustituta)
--   dim_fecha         calendario (una fila por día)
--
-- Se llena con 05_carga_postgres/construir_estrella.sql, a partir del
-- modelo normalizado (esquema openlibrary).
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS estrella;

CREATE TABLE estrella.dim_fecha (
    fecha    date PRIMARY KEY,
    anio     integer NOT NULL,
    trimestre integer NOT NULL CHECK (trimestre BETWEEN 1 AND 4),
    mes      integer NOT NULL CHECK (mes BETWEEN 1 AND 12),
    dia      integer NOT NULL CHECK (dia BETWEEN 1 AND 31),
    decada   integer NOT NULL
);

CREATE TABLE estrella.dim_obra (
    obra_sk                   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    clave_obra                text NOT NULL UNIQUE,                 -- clave natural, para cargar y depurar
    titulo                    text NOT NULL,
    anio_primera_publicacion  integer,
    num_portadas              integer NOT NULL
);

CREATE TABLE estrella.fact_valoracion (
    valoracion_sk  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha          date NOT NULL REFERENCES estrella.dim_fecha (fecha),
    obra_sk        integer NOT NULL REFERENCES estrella.dim_obra (obra_sk),
    valor          smallint NOT NULL CHECK (valor BETWEEN 1 AND 5)
);

CREATE TABLE estrella.fact_lectura (
    lectura_sk  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha       date NOT NULL REFERENCES estrella.dim_fecha (fecha),
    obra_sk     integer NOT NULL REFERENCES estrella.dim_obra (obra_sk),
    estado      text NOT NULL
);
