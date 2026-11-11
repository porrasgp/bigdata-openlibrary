-- =====================================================================
-- Modelo normalizado (3FN) de Open Library
-- Esquema: openlibrary
--
-- Entidades:       obra, edicion, autor, editorial, idioma, tema
-- Relaciones 1:N:  obra -> edicion (una obra tiene muchas ediciones)
-- Relaciones N:M:  obra_autor, edicion_autor, edicion_editorial,
--                  edicion_idioma, obra_tema
-- Hechos:          valoracion, lectura (eventos sobre obras y ediciones)
--
-- Ejecutar con PostgreSQL 18 (ver 05_carga_postgres/README.md).
-- Este archivo solo crea tablas. Los datos se cargan con cargar_postgres.py.
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS openlibrary;

-- ---------------------------------------------------------------- entidades

CREATE TABLE openlibrary.obra (
    clave_obra                text PRIMARY KEY,                       -- /works/OL...W
    titulo                    text NOT NULL,
    subtitulo                 text,
    anio_primera_publicacion  integer CHECK (anio_primera_publicacion BETWEEN 1450 AND 2100),
    num_portadas              integer NOT NULL DEFAULT 0 CHECK (num_portadas >= 0),
    descripcion               text
);

CREATE TABLE openlibrary.autor (
    clave_autor       text PRIMARY KEY,                               -- /authors/OL...A
    nombre            text NOT NULL,
    nombre_personal   text,
    fecha_nacimiento  text,                                           -- texto: las fechas históricas son irregulares
    fecha_muerte      text
);

CREATE TABLE openlibrary.editorial (
    editorial_id  integer PRIMARY KEY,
    nombre        text NOT NULL UNIQUE
);

CREATE TABLE openlibrary.idioma (
    codigo  text PRIMARY KEY                                          -- ISO 639-2/3 de Open Library: 'eng', 'spa'...
);

CREATE TABLE openlibrary.tema (
    tema_id  integer PRIMARY KEY,
    nombre   text NOT NULL UNIQUE
);

CREATE TABLE openlibrary.edicion (
    clave_edicion      text PRIMARY KEY,                              -- /books/OL...M
    clave_obra         text REFERENCES openlibrary.obra (clave_obra), -- puede ser null si la obra no está en el dump
    titulo             text NOT NULL,
    subtitulo          text,
    fecha_publicacion  text,                                          -- texto original: "February 27, 1997"
    anio_publicacion   integer CHECK (anio_publicacion BETWEEN 1450 AND 2100),
    decada             integer,                                       -- derivada: 1990, 2000...
    paginas            integer CHECK (paginas > 0),
    formato_fisico     text,
    num_portadas       integer NOT NULL DEFAULT 0 CHECK (num_portadas >= 0),
    isbn_10            text,
    isbn_13            text
);

-- ---------------------------------------------------------------- relaciones N:M

CREATE TABLE openlibrary.obra_autor (
    clave_obra   text NOT NULL REFERENCES openlibrary.obra (clave_obra),
    clave_autor  text NOT NULL REFERENCES openlibrary.autor (clave_autor),
    PRIMARY KEY (clave_obra, clave_autor)
);

CREATE TABLE openlibrary.edicion_autor (
    clave_edicion  text NOT NULL REFERENCES openlibrary.edicion (clave_edicion),
    clave_autor    text NOT NULL REFERENCES openlibrary.autor (clave_autor),
    PRIMARY KEY (clave_edicion, clave_autor)
);

CREATE TABLE openlibrary.edicion_editorial (
    clave_edicion  text NOT NULL REFERENCES openlibrary.edicion (clave_edicion),
    editorial_id   integer NOT NULL REFERENCES openlibrary.editorial (editorial_id),
    PRIMARY KEY (clave_edicion, editorial_id)
);

CREATE TABLE openlibrary.edicion_idioma (
    clave_edicion  text NOT NULL REFERENCES openlibrary.edicion (clave_edicion),
    codigo         text NOT NULL REFERENCES openlibrary.idioma (codigo),
    PRIMARY KEY (clave_edicion, codigo)
);

CREATE TABLE openlibrary.obra_tema (
    clave_obra  text NOT NULL REFERENCES openlibrary.obra (clave_obra),
    tema_id     integer NOT NULL REFERENCES openlibrary.tema (tema_id),
    PRIMARY KEY (clave_obra, tema_id)
);

-- ---------------------------------------------------------------- hechos

-- Sin clave primaria: el dump no tiene usuario, así que dos valoraciones
-- iguales pueden ser de personas distintas. Discutir en clase.
CREATE TABLE openlibrary.valoracion (
    clave_obra     text NOT NULL REFERENCES openlibrary.obra (clave_obra),
    clave_edicion  text REFERENCES openlibrary.edicion (clave_edicion),
    valor          smallint NOT NULL CHECK (valor BETWEEN 1 AND 5),
    fecha          date NOT NULL
);

CREATE TABLE openlibrary.lectura (
    clave_obra     text NOT NULL REFERENCES openlibrary.obra (clave_obra),
    clave_edicion  text REFERENCES openlibrary.edicion (clave_edicion),
    estado         text NOT NULL,                                     -- 'Already Read', 'Want to Read'...
    fecha          date NOT NULL
);

-- Nota: los índices sobre claves foráneas NO se crean aquí a propósito.
-- En 06_consultas/indices.sql los creamos y medimos el efecto con EXPLAIN ANALYZE.
