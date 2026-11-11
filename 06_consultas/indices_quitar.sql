-- Quita los índices creados en indices.sql (para repetir la medición "antes").

DROP INDEX IF EXISTS openlibrary.ix_edicion_clave_obra;
DROP INDEX IF EXISTS openlibrary.ix_edicion_decada;
DROP INDEX IF EXISTS openlibrary.ix_obra_autor_autor;
DROP INDEX IF EXISTS openlibrary.ix_valoracion_obra;
DROP INDEX IF EXISTS openlibrary.ix_valoracion_fecha;
DROP INDEX IF EXISTS openlibrary.ix_lectura_obra;
