# 07 · Ejercicios

Doce ejercicios repartidos en las cuatro semanas. Cada uno dice qué archivo usar y qué entregar.

## Qué contiene esta carpeta

| Archivo | Qué es |
|---|---|
| `ejercicios.md` | Enunciados de los 12 ejercicios, agrupados por semana |
| `soluciones/soluciones.sql` | Soluciones SQL (E9 y E11) |
| `soluciones/solucion_E3_E4.py` | Soluciones de Spark (E3 y E4) |

## Qué se hizo

- Escribimos los enunciados para que se resuelvan con lo que ya está en el repositorio, sin cambiar la arquitectura.
- Dejamos las soluciones en carpeta aparte para que el alumno intente primero.
- Probamos las dos soluciones SQL contra la base de la muestra. Encontramos dos errores de ventanas que ya están corregidos.
- La solución de E4 es un fragmento que hay que pegar en `01_raw_a_clean.py`; no es un script independiente.

## Qué necesitas para ejecutarlo

Depende del ejercicio:

- **Semana 1 (E1, E2):** HDFS en marcha con la muestra cargada.
- **Semana 2 (E3 a E6):** Spark y los datos de la semana 2 en HDFS.
- **Semana 3 (E7 a E9):** PostgreSQL con la base cargada.
- **Semana 4 (E10 a E12):** la base cargada y, para E10, poder ejecutar `indices.sql` e `indices_quitar.sql`.

## Cómo ejecutarlos

```bash
cd ~/bigdata-openlibrary/07_ejercicios
source ../00_setup/env.sh

# Soluciones SQL (para comparar con tu respuesta)
psql -f soluciones/soluciones.sql

# Soluciones de Spark
python3 soluciones/solucion_E3_E4.py
```

## Qué debes entender

- Los ejercicios siguen el mismo orden del curso. Si te atascas en la semana 4, vuelve al README de la carpeta que corresponda.
- En E10 la tabla de tiempos debes llenarla con el dataset completo. La muestra tarda milisegundos y no sirve para comparar.
- E12 es el más importante para el proyecto final: si encuentras una pregunta que te interesa aquí, esa es tu punto de partida.
