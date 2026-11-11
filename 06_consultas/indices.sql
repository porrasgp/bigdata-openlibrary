-- Índices para las consultas de la semana 4.
-- Antes de ejecutar, mide con 05_explain.sql; después, vuelve a medir.
-- Para deshacer todos los índices: indices_quitar.sql

CREATE INDEX IF NOT EXISTS ix_edicion_clave_obra   ON openlibrary.edicion (clave_obra);
CREATE INDEX IF NOT EXISTS ix_edicion_decada       ON openlibrary.edicion (decada);
CREATE INDEX IF NOT EXISTS ix_obra_autor_autor     ON openlibrary.obra_autor (clave_autor);
CREATE INDEX IF NOT EXISTS ix_valoracion_obra      ON openlibrary.valoracion (clave_obra);
CREATE INDEX IF NOT EXISTS ix_valoracion_fecha     ON openlibrary.valoracion (fecha);
CREATE INDEX IF NOT EXISTS ix_lectura_obra         ON openlibrary.lectura (clave_obra);

ANALYZE openlibrary.edicion;
ANALYZE openlibrary.obra_autor;
ANALYZE openlibrary.valoracion;
ANALYZE openlibrary.lectura;
