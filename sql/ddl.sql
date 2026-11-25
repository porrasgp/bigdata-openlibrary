-- =====================================================================
-- Esquema estrella para el gold del ETL medallion (Open Library)
-- =====================================================================
-- Se ejecuta desde postgres/cargar_gold.py, que después carga los CSV de
-- data/gold con COPY. También puedes aplicarlo a mano:
--   psql -v ON_ERROR_STOP=1 -f sql/ddl.sql
--
-- Tablas de hechos: una fila por evento (valoración o cambio de lectura).
-- Dimensiones: obra (con clave sustituta) y fecha (calendario continuo).
-- La tabla resumen es el ejemplo de agregación ya lista para graficar.
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS estrella;

CREATE TABLE estrella.dim_obra (
    obra_sk                   integer PRIMARY KEY,
    clave_obra                text NOT NULL UNIQUE,
    titulo                    text NOT NULL,
    anio_primera_publicacion  integer,
    num_portadas              integer NOT NULL DEFAULT 0
);

CREATE TABLE estrella.dim_fecha (
    fecha      date PRIMARY KEY,
    anio       integer NOT NULL,
    trimestre  integer NOT NULL CHECK (trimestre BETWEEN 1 AND 4),
    mes        integer NOT NULL CHECK (mes BETWEEN 1 AND 12),
    dia        integer NOT NULL CHECK (dia BETWEEN 1 AND 31),
    decada     integer NOT NULL
);

CREATE TABLE estrella.fact_valoracion (
    fecha    date NOT NULL REFERENCES estrella.dim_fecha (fecha),
    obra_sk  integer NOT NULL REFERENCES estrella.dim_obra (obra_sk),
    valor    integer NOT NULL CHECK (valor BETWEEN 1 AND 5)
);

CREATE TABLE estrella.fact_lectura (
    fecha    date NOT NULL REFERENCES estrella.dim_fecha (fecha),
    obra_sk  integer NOT NULL REFERENCES estrella.dim_obra (obra_sk),
    estado   text NOT NULL
);

CREATE TABLE estrella.resumen_valoraciones_anio (
    anio           integer PRIMARY KEY,
    valoraciones   bigint NOT NULL,
    valor_promedio numeric(10, 2) NOT NULL
);

-- Índices para los joins y filtros habituales.
CREATE INDEX idx_valoracion_obra  ON estrella.fact_valoracion (obra_sk);
CREATE INDEX idx_valoracion_fecha ON estrella.fact_valoracion (fecha);
CREATE INDEX idx_lectura_obra     ON estrella.fact_lectura (obra_sk);
CREATE INDEX idx_lectura_fecha    ON estrella.fact_lectura (fecha);
CREATE INDEX idx_lectura_estado   ON estrella.fact_lectura (estado);
