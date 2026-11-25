#!/usr/bin/env bash
# Detección del entorno local compartida por los scripts manuales.
# Uso: source entorno.sh   (definir funciones; no ejecuta nada por sí sola)
#
# Variables de override: OL_JAVA_HOME, OL_HADOOP_HOME, OL_HADOOP_CONF_DIR,
# OL_VENV, OL_PGBIN, OL_PGDATA.

ol_detectar_java() {
  if [[ -z "${JAVA_HOME:-}" || ! -x "${JAVA_HOME:-/}/bin/java" ]]; then
    if command -v java >/dev/null 2>&1; then
      JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
    else
      for cand in \
        "${OL_JAVA_HOME:-}" \
        "$HOME/Desktop/opt/jdk-17.0.21+9" \
        "$HOME/opt/jdk-17.0.21+9" \
        "$HOME/jdk-17.0.21+9"; do
        [[ -n "$cand" && -x "$cand/bin/java" ]] && { JAVA_HOME="$cand"; break; }
      done
    fi
  fi
  [[ -n "${JAVA_HOME:-}" && -x "$JAVA_HOME/bin/java" ]] || {
    echo "No encuentro Java 17 (usa OL_JAVA_HOME=/ruta/al/jdk)" >&2
    return 1
  }
  export JAVA_HOME
  export PATH="$JAVA_HOME/bin:$PATH"
}

ol_detectar_hadoop() {
  if [[ -z "${HADOOP_HOME:-}" || ! -x "${HADOOP_HOME:-/}/bin/hdfs" ]]; then
    for cand in \
      "${OL_HADOOP_HOME:-}" \
      "$HOME/Desktop/opt/hadoop-3.5.0" \
      "$HOME/opt/hadoop-3.5.0" \
      "$HOME/hadoop-3.5.0"; do
      [[ -n "$cand" && -x "$cand/bin/hdfs" ]] && { HADOOP_HOME="$cand"; break; }
    done
  fi
  [[ -n "${HADOOP_HOME:-}" && -x "$HADOOP_HOME/bin/hdfs" ]] || {
    echo "No encuentro Hadoop (usa OL_HADOOP_HOME=/ruta/al/hadoop)" >&2
    return 1
  }
  HADOOP_CONF_DIR="${OL_HADOOP_CONF_DIR:-$HADOOP_HOME/etc/hadoop}"
  export HADOOP_HOME HADOOP_CONF_DIR
  export HADOOP_HOME_WARN_SUPPRESS=1
  export PATH="$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH"
}

ol_venv_valido() {
  local venv="$1" modulos="$2"
  [[ -n "$venv" && -x "$venv/bin/python3" ]] || return 1
  "$venv/bin/python3" -c "import $modulos" >/dev/null 2>&1
}

ol_detectar_venv() {
  local modulos="${1:-pyspark}"
  local venv="${OL_VENV:-${VIRTUAL_ENV:-}}"

  if ! ol_venv_valido "$venv" "$modulos"; then
    venv=""
    for cand in \
      "$HOME/venv-bigdata" \
      "$HOME/Desktop/venv-bigdata" \
      "$HOME/.local/share/Trash/files/venv-bigdata"; do
      if ol_venv_valido "$cand" "$modulos"; then venv="$cand"; break; fi
    done
  fi
  [[ -n "$venv" ]] || {
    echo "No encuentro un venv con $modulos (usa OL_VENV=/ruta/al/venv)" >&2
    return 1
  }

  VENV="$venv"
  export VIRTUAL_ENV="$VENV"
  export PATH="$VENV/bin:$PATH"
  export PYSPARK_PYTHON="$VENV/bin/python3"
  export PYSPARK_DRIVER_PYTHON="$VENV/bin/python3"
}

ol_detectar_pg() {
  PGBIN="${OL_PGBIN:-}"
  if [[ -z "$PGBIN" || ! -x "$PGBIN/psql" ]]; then
    if command -v psql >/dev/null 2>&1; then
      PGBIN="$(dirname "$(command -v psql)")"
    else
      for cand in \
        "$HOME/Desktop/venv-pgtest/lib/python3.12/site-packages/pgserver/pginstall/bin" \
        "$HOME/venv-pgtest/lib/python3.12/site-packages/pgserver/pginstall/bin"; do
        [[ -x "$cand/psql" ]] && { PGBIN="$cand"; break; }
      done
    fi
  fi
  [[ -n "${PGBIN:-}" && -x "$PGBIN/psql" ]] || {
    echo "No encuentro psql (usa OL_PGBIN=/ruta/al/bin)" >&2
    return 1
  }

  PGDATA="${OL_PGDATA:-$HOME/pgdata}"
  PGHOST="${PGHOST:-localhost}"
  PGPORT="${PGPORT:-5432}"
  PGUSER="${PGUSER:-${USER:-$(id -un)}}"
  PGDATABASE="${PGDATABASE:-$PGUSER}"
  export PGBIN PGDATA PGHOST PGPORT PGUSER PGDATABASE
  export PATH="$PGBIN:$PATH"
}

ol_asegurar_hdfs() {
  if ! hdfs dfs -ls / >/dev/null 2>&1; then
    echo "HDFS no responde: arrancando NameNode y DataNode..."
    hdfs --daemon start namenode
    hdfs --daemon start datanode
    for _ in $(seq 1 30); do
      hdfs dfs -ls / >/dev/null 2>&1 && break
      sleep 2
    done
  fi
  if ! hdfs dfs -ls / >/dev/null 2>&1; then
    echo "HDFS sigue sin responder. Revisa HADOOP_CONF_DIR y los logs." >&2
    return 1
  fi
  hdfs dfsadmin -safemode leave >/dev/null 2>&1 || true
}

ol_asegurar_postgres() {
  mkdir -p /tmp/opencode
  if ! "$PGBIN/pg_isready" -h "$PGHOST" -p "$PGPORT" >/dev/null 2>&1; then
    echo "PostgreSQL no responde: arrancando..."
    "$PGBIN/pg_ctl" -D "$PGDATA" -l /tmp/opencode/postgres.log \
      -o "-p $PGPORT -k /tmp" start
  fi
  if ! "$PGBIN/pg_isready" -h "$PGHOST" -p "$PGPORT" >/dev/null 2>&1; then
    echo "PostgreSQL sigue sin responder. Revisa OL_PGDATA y /tmp/opencode/postgres.log" >&2
    return 1
  fi
}

ol_asegurar_roles_pg() {
  if ! "$PGBIN/psql" -v ON_ERROR_STOP=1 -d postgres -tAc \
      "SELECT 1 FROM pg_roles WHERE rolname = '$PGUSER'" | grep -q 1; then
    echo "Creando rol PostgreSQL $PGUSER..."
    "$PGBIN/psql" -v ON_ERROR_STOP=1 -d postgres \
      -c "CREATE ROLE \"$PGUSER\" LOGIN SUPERUSER"
  fi
  if ! "$PGBIN/psql" -v ON_ERROR_STOP=1 -d postgres -tAc \
      "SELECT 1 FROM pg_database WHERE datname = '$PGDATABASE'" | grep -q 1; then
    echo "Creando base de datos $PGDATABASE..."
    "$PGBIN/createdb" -O "$PGUSER" "$PGDATABASE"
  fi
}

ol_resumen_entorno() {
  echo "  Java:     $JAVA_HOME"
  echo "  Hadoop:   ${HADOOP_HOME:-(no necesario)}"
  echo "  Python:   $("$VENV/bin/python3" -c 'import sys; print(sys.version.split()[0])')"
  [[ -n "${PGBIN:-}" ]] && echo "  Postgres: $PGHOST:$PGPORT ($PGUSER/$PGDATABASE)"
}
