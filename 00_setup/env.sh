# Variables del curso. Cargar en cada terminal nueva:
#   source ~/bigdata-openlibrary/00_setup/env.sh
#
# Si cambiaste rutas de instalación, ajusta HADOOP_HOME y el venv antes de cargarlo.

# Java 17 (paquete openjdk-17-jdk-headless)
export JAVA_HOME="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(which java)")")")}"

# Hadoop 3.5.0 (descomprimido en tu carpeta personal)
export HADOOP_HOME="${HADOOP_HOME:-$HOME/hadoop-3.5.0}"
export HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"
export HADOOP_HOME_WARN_SUPPRESS=1
export PATH="$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH"

# Entorno virtual con PySpark 4.3.0 y dependencias
if [[ -f "$HOME/venv-bigdata/bin/activate" ]]; then
  source "$HOME/venv-bigdata/bin/activate"
fi

# PostgreSQL: conexión local con tu usuario de Linux
export PGHOST="${PGHOST:-localhost}"
export PGPORT="${PGPORT:-5432}"
export PGUSER="${PGUSER:-$USER}"
export PGDATABASE="${PGDATABASE:-$USER}"

# Rutas de datos del curso (ver 03_limpieza_spark/common.py)
export OL_RAW="hdfs://localhost:8020/raw/openlibrary/fecha=2026-10-31"
export OL_CLEAN="hdfs://localhost:8020/clean/openlibrary"
export OL_CURATED="hdfs://localhost:8020/curated/openlibrary"
export OL_RECHAZADOS="hdfs://localhost:8020/clean/_rechazados"

# Recursos de Spark: ajusta a tu VM (8 GB -> driver 3g; 4 GB -> 1g y solo muestra)
export SPARK_DRIVER_MEMORY="${SPARK_DRIVER_MEMORY:-3g}"
export OL_PARTICIONES="${OL_PARTICIONES:-8}"

echo "Entorno del curso cargado: Java $(java -version 2>&1 | head -1 | cut -d'"' -f2), Hadoop $(hadoop version 2>/dev/null | head -1 | awk '{print $2}'), PostgreSQL usuario $PGUSER"
