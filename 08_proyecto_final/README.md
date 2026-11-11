# 08 · Proyecto final

Trabajo individual de 4 semanas. Construyes el pipeline completo para responder una pregunta de negocio sobre Open Library y presentas los resultados.

## Qué contiene esta carpeta

| Archivo | Para qué sirve |
|---|---|
| `README.md` | Este documento: entregables, casos, reglas y cronograma |
| `rubrica.md` | Criterios de evaluación (100 puntos) |
| `plantilla_informe.md` | Estructura del informe final |

Esta carpeta no contiene código: el proyecto es tu propio repositorio, construido a partir del curso.

## Qué se hizo

- Definimos tres casos de estudio con su pregunta, tablas clave, métricas sugeridas y una pista de modelado.
- Escribimos la rúbrica con cuatro niveles por criterio, para que sepas qué se espera antes de empezar.
- Dejamos una plantilla de informe con las secciones que pide la rúbrica.

## Qué necesitas para empezar

- Haber completado las semanas 1 a 3: el pipeline corre con la muestra y la base de datos se carga sin errores.
- Un repositorio propio en GitHub (público o privado).
- El dataset completo descargado (ver `../01_extraccion/README.md`) y cargado en HDFS.

## Casos de estudio

### A. Editorial: tendencias de publicación
- **Pregunta:** ¿cómo cambian el número de ediciones, el formato físico y el número de páginas por década y por idioma?
- **Tablas clave:** `edicion`, `edicion_idioma`, `edicion_editorial`, `editorial`.
- **Métricas sugeridas:** ediciones por década, páginas medianas por formato, top 10 editoriales por década, idiomas con más crecimiento.
- **Pista de modelado:** `decada` ya está precalculada; compara con calcularla en la consulta.

### B. Biblioteca: cobertura de autores y temas
- **Pregunta:** ¿qué autores y temas tienen más ediciones, y cuáles están poco representados?
- **Tablas clave:** `autor`, `obra_autor`, `obra_tema`, `tema`, `edicion_autor`.
- **Métricas sugeridas:** obras por autor, temas con pocas obras pero muchas valoraciones, autores sin ediciones.
- **Pista de modelado:** las relaciones N:M son el centro de este caso; usa `EXISTS` y `NOT EXISTS`.

### C. Comportamiento lector: qué se lee y cómo se valora
- **Pregunta:** ¿qué obras se leen más, cómo se valoran y cómo cambia la lectura en el tiempo?
- **Tablas clave:** `valoracion`, `lectura`, `obra`, `estrella.fact_valoracion`, `estrella.fact_lectura`.
- **Métricas sugeridas:** valoración media por obra con umbral mínimo, actividad mensual con acumulado, estados de lectura por año.
- **Pista de modelado:** usa el esquema estrella; es el caso que más se beneficia de las dimensiones de fecha.

## Entregables

1. **Pipeline reproducible.** Ejecución en orden desde `data/raw` hasta PostgreSQL, con un README que indique cómo correrlo desde cero. Puedes reutilizar los scripts, pero debes modificar o añadir al menos una transformación o validación propia.
2. **Modelo de datos.** DDL con PK, FK y restricciones justificadas, y diagrama ER (Mermaid, draw.io o imagen).
3. **Consultas analíticas.** Al menos 5 que respondan tu pregunta, y `EXPLAIN ANALYZE` de al menos 2 antes y después de los índices.
4. **Informe.** Con `plantilla_informe.md`, máximo 6 páginas.
5. **Presentación** de 10 minutos con demo en vivo de una consulta.

## Reglas

- Los datos son públicos (CC0). Cita la fuente en el informe.
- No subas datos crudos al repositorio. Sí puedes subir muestras pequeñas (menos de 100 MB por archivo).
- Cada decisión de limpieza o modelado debe justificarse en el informe.
- Usa siempre la **misma fecha de snapshot** (`2026-10-31`) para que tus resultados sean reproducibles.
- No subas contraseñas, tokens ni la clave de tu cuenta de GitHub al repositorio.

## Qué debes entender antes de empezar

- **Un proyecto es reproducible si otro alumno puede correrlo siguiendo tu README.** Si tu README dice "ejecuta el script" sin decir en qué orden, en qué carpeta o con qué variables, no es reproducible.
- **Decide la pregunta antes que las tablas.** Si empiezas por el modelo, terminarás con un modelo bonito que no responde nada.
- **Mide antes de optimizar.** Un índice que no cambia el plan no mejora nada, aunque parezca buena idea.
- **Las limitaciones son parte del resultado.** Un informe que dice "esto no se puede responder con estos datos, y por qué" vale más que uno que afirma de más.

## Cronograma

| Semana | Objetivo |
|---|---|
| 1 | Entorno funcionando, dumps verificados, carga en HDFS, caso elegido |
| 2 | Pipeline raw → clean → curated con al menos una validación propia |
| 3 | Modelo en PostgreSQL con restricciones, carga completa y verificada |
| 4 | Consultas, índices medidos, informe y presentación |

## Evaluación

Ver [`rubrica.md`](rubrica.md). Total: 100 puntos.
