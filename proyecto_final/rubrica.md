# Rúbrica del proyecto final

Total: 100 puntos.

| Criterio | Puntos | Excelente | Suficiente | Insuficiente |
|---|---:|---|---|---|
| **Medallion CSV** | 20 | Bronze/silver/gold correctos, hash en bronze, rechazos con motivo y al menos una validación propia bien justificada | Capas correctas y pipeline reproducible, sin validación propia | Capas mezcladas o pipeline que no corre desde cero |
| **HDFS** | 10 | Gold subido con ruta `fecha=...`, tamaño y SHA-256 verificados, reporte de bloques/replicación | Carga en HDFS funcional con ruta clara | Datos no subidos o ruta ambigua |
| **PostgreSQL** | 15 | Esquema estrella con PK/FK/CHECK, COPY verificable, conteos coincidentes y decisiones documentadas | Carga funcional con conteos revisados | Carga manual, incompleta o sin restricciones |
| **Consultas SQL** | 20 | Al menos 5 consultas propias que responden la pregunta, con joins, agregaciones y ventana donde aporta | 5 consultas correctas, sin ventanas | Consultas que no responden la pregunta |
| **Optimización** | 10 | `EXPLAIN ANALYZE` antes y después de índices, con interpretación de scans y tiempos | Mediciones sin interpretación | Sin mediciones |
| **Informe** | 15 | Pregunta clara, metodología, cifras reales y limitaciones bien explicadas | Resultados presentados sin limitaciones | Sin pregunta o sin conclusiones |
| **Presentación y demo** | 10 | Demo en vivo funciona y explica el flujo en 10 minutos | Presentación sin demo | No se presenta |

## Penalizaciones

- Subir datos generados de `data/` al repositorio: -10 puntos.
- Pipeline que no corre desde cero siguiendo el README: -10 puntos.
- Contraseñas o tokens en el repositorio: el proyecto queda en 0 puntos.
