"""Tablas del modelo normalizado, con sus columnas en el orden del CSV.

Lo usan dos scripts:
  - exportar_csv.py (Spark) escribe estas columnas, en este orden, sin cabecera.
  - cargar_postgres.py (psycopg) hace COPY de esas columnas a cada tabla.

El orden del diccionario es también el orden de carga: primero las tablas
a las que otras apuntan con clave foránea (obra, autor...), después las
relaciones y al final los hechos. Si cambias una columna aquí, cámbiala
también en 04_modelado/ddl_normalizado.sql.
"""

TABLAS = {
    "obra": [
        "clave_obra", "titulo", "subtitulo", "anio_primera_publicacion",
        "num_portadas", "descripcion",
    ],
    "autor": [
        "clave_autor", "nombre", "nombre_personal", "fecha_nacimiento", "fecha_muerte",
    ],
    "editorial": ["editorial_id", "nombre"],
    "idioma": ["codigo"],
    "tema": ["tema_id", "nombre"],
    "edicion": [
        "clave_edicion", "clave_obra", "titulo", "subtitulo", "fecha_publicacion",
        "anio_publicacion", "decada", "paginas", "formato_fisico", "num_portadas",
        "isbn_10", "isbn_13",
    ],
    "obra_autor": ["clave_obra", "clave_autor"],
    "edicion_autor": ["clave_edicion", "clave_autor"],
    "edicion_editorial": ["clave_edicion", "editorial_id"],
    "edicion_idioma": ["clave_edicion", "codigo"],
    "obra_tema": ["clave_obra", "tema_id"],
    "valoracion": ["clave_obra", "clave_edicion", "valor", "fecha"],
    "lectura": ["clave_obra", "clave_edicion", "estado", "fecha"],
}
