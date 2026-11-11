# Rúbrica del proyecto final

Total: 100 puntos.

| Criterio | Puntos | Excelente | Suficiente | Insuficiente |
|---|---:|---|---|---|
| **Ingesta y HDFS** | 10 | Dumps verificados con SHA-256, carga en HDFS con comprobación de tamaño, zonas raw/clean/curated documentadas | Carga en HDFS funcional, sin verificación | Datos no cargados o sin ruta clara |
| **Limpieza con Spark** | 20 | Tipos correctos, deduplicación justificada, al menos una validación propia con motivos registrados | Tipos y deduplicación correctos, sin validación propia | Errores de tipo o duplicados sin tratar |
| **Modelo de datos** | 20 | 3FN o estrella justificado, PK/FK/CHECK correctos, diagrama claro, decisiones documentadas (nulos, FK opcionales) | Modelo correcto con restricciones básicas | Tablas sin claves o relaciones erróneas |
| **Carga en PostgreSQL** | 10 | Carga reproducible con COPY, conteos verificados, tamaño medido | Carga funcional, verificación parcial | Carga manual o incompleta |
| **Consultas** | 15 | Al menos 5 consultas correctas, uso de joins N:M, ventanas y CTE donde aportan | 5 consultas correctas, sin ventanas | Consultas que no responden la pregunta |
| **Optimización** | 10 | EXPLAIN ANALYZE antes y después de índices, interpretación de scans y tiempos | Mediciones sin interpretación | Sin mediciones |
| **Informe** | 10 | Pregunta clara, metodología, resultados con cifras, limitaciones | Resultados presentados sin limitaciones | Sin pregunta o sin conclusiones |
| **Presentación y demo** | 5 | Demo en vivo funciona, explica el pipeline en 10 minutos | Presentación sin demo | No se presenta |

## Penalizaciones

- Subir datos crudos al repositorio: -10 puntos.
- Pipeline que no corre desde cero siguiendo el README: -10 puntos.
- Contraseñas o tokens en el repositorio: el proyecto queda en 0 puntos.
