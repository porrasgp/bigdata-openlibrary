# SQL — esquema, verificación y consultas

Los archivos de esta carpeta se usan después de cargar el gold en PostgreSQL.

| Archivo | Contenido |
|---|---|
| `ddl.sql` | `CREATE SCHEMA`, tablas `dim_obra`, `dim_fecha`, `fact_valoracion`, `fact_lectura`, `resumen_valoraciones_anio`, PK/FK/CHECK e índices |
| `verificar.sql` | Conteos, comprobación de claves foráneas y suma de control |
| `consultas.sql` | Seis consultas de ejemplo: agregaciones, joins, ventana, décadas, comprobación del resumen y `EXPLAIN ANALYZE` |

## Ejecución manual

```bash
psql -v ON_ERROR_STOP=1 -f sql/ddl.sql        # normalmente lo hace cargar_gold.py
psql -v ON_ERROR_STOP=1 -f sql/verificar.sql
psql -v ON_ERROR_STOP=1 -f sql/consultas.sql
```

Si ejecutas `ddl.sql` después de una carga, usa un esquema vacío o añade `--reiniciar` a `python3 postgres/cargar_gold.py`; las tablas no se sobrescriben solas.

## Preguntas que responden las consultas

1. ¿Qué obras tienen mejor valoración media (con un mínimo de valoraciones)?
2. ¿Cómo evoluciona mensualmente el número de valoraciones?
3. ¿Qué estados de lectura aparecen cada año?
4. ¿Cómo cambia la valoración media por década?
5. ¿Coincide el resumen guardado en gold con los hechos?
6. ¿Qué plan usa PostgreSQL para el join de valoraciones con obras?

La consulta 6 es la base del ejercicio de optimización del proyecto final: mide antes y después de quitar/crear índices.
