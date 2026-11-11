# 04 · Modelado de datos

Diseño del modelo relacional (3FN) y del esquema estrella que se cargan en PostgreSQL.

## Qué contiene esta carpeta

| Archivo | Qué es |
|---|---|
| `ddl_normalizado.sql` | Tablas del esquema `openlibrary`: entidades, relaciones N:M y hechos, con PK, FK y CHECK |
| `ddl_estrella.sql` | Tablas del esquema `estrella`: dos hechos y dos dimensiones |
| `diagrama_er.md` | Diagrama ER en Mermaid (GitHub lo renderiza) |

## Qué se hizo

1. Partimos de las tablas limpias de la semana 2 y decidimos qué entidades son independientes (`obra`, `autor`, `editorial`, `idioma`, `tema`, `edicion`) y cuáles son relaciones (`obra_autor`, `edicion_autor`, `edicion_editorial`, `edicion_idioma`, `obra_tema`).
2. Escribimos el DDL con claves primarias compuestas en las relaciones N:M y con `CHECK` en los rangos (año entre 1450 y 2100, valoración entre 1 y 5, páginas positivas).
3. Documentamos dos decisiones que no son obvias:
   - `valoracion` y `lectura` **no tienen clave primaria**: el dump no identifica al usuario, así que dos filas iguales pueden ser eventos distintos.
   - `edicion.clave_obra` es **opcional**: una edición puede apuntar a una obra que no está en el dump.
4. Diseñamos el esquema estrella con clave sustituta (`GENERATED ALWAYS AS IDENTITY`) en las dimensiones y los hechos en grano de evento.
5. Probamos el DDL en PostgreSQL 16 (la versión de prueba del entorno de desarrollo); el curso usa 18. El SQL que usamos existe en ambas.

## Qué necesitas para ejecutarlo

- PostgreSQL 18 en marcha y `PGUSER`/`PGDATABASE` configurados (`../00_setup/env.sh`).
- Para crear las tablas, no hace falta cargar datos. Los scripts de la carpeta 05 aplican estos DDL.

```bash
cd ~/bigdata-openlibrary/04_modelado
psql -v ON_ERROR_STOP=1 -f ddl_normalizado.sql
psql -v ON_ERROR_STOP=1 -f ddl_estrella.sql
```

> Si ya existen las tablas, los DDL fallan. Para empezar de cero usa `cargar_postgres.py --reiniciar` (carpeta 05), que borra los esquemas antes de crearlos.

## Qué debes entender

**Normalizar.** Una obra tiene muchos autores, y un autor escribe muchas obras. Si guardáramos el nombre del autor dentro de cada obra, el nombre se repetiría y cambiarlo costaría miles de actualizaciones. Por eso `autor` es una tabla propia y `obra_autor` enlaza las dos.

**Claves naturales y sustitutas.** Las claves de Open Library (`/works/OL...W`) son estables y se pueden buscar en el sitio web; las usamos como clave primaria. Para `editorial` y `tema`, usamos un entero porque los nombres son largos y pueden tener variantes.

**Por qué CHECK.** Un año de publicación de 1 o de 9999 es casi siempre un error de digitación en la fuente. Un `CHECK` impide que entre aunque el script de carga tenga un fallo.

**Por qué una tabla sin clave primaria.** Es una decisión, no un descuido. Si pusiéramos `PRIMARY KEY (clave_obra, fecha)` perderíamos valoraciones distintas del mismo día. Un ID sustituto (`bigserial`) resolvería el problema, pero tiene un coste: el ID no existe en la fuente. Discútelo en clase.

**Estrella vs. normalizado.** El normalizado es bueno para mantener datos sin duplicados. El estrella es mejor para análisis: menos joins, y las preguntas por fecha son directas. Por eso `estrella.fact_valoracion` tiene `fecha` y `obra_sk` y no pide unir cinco tablas para contar.

**Grano.** Antes de diseñar un hecho hay que decidir qué representa una fila. Aquí, una fila es un evento: una valoración o un cambio de estado de lectura. Si quisieras "valoración media por obra y mes", eso es una agregación sobre el hecho, no otro hecho.

## Problemas frecuentes

| Síntoma | Causa | Solución |
|---|---|---|
| `relation "openlibrary.obra" already exists` | Las tablas ya existen | `cargar_postgres.py --reiniciar` o `DROP SCHEMA openlibrary CASCADE` |
| `permission denied for schema public` | Usuario sin permisos | Trabaja en el esquema `openlibrary` (ya está calificado en el DDL) |
| Error de FK al cargar | Una fila apunta a una clave que no existe | Revisa el paso de FK en `02_clean_a_curated.py` (con la muestra debe ser 0) |
