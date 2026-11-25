#!/usr/bin/env bash
# Detección y preparación automática del entorno, compartida por los scripts manuales.
# Uso: source entorno.sh   (define funciones; no ejecuta nada por sí sola)
#
# Las funciones ol_detectar_* y ol_asegurar_* sí pueden crear lo que falte:
#   - venv con los módulos pedidos (instala requirements.txt del proyecto),
#   - PGDATA inicializado si no existe,
#   - rol y base de datos PostgreSQL,
#   - directorios de NameNode/DataNode y formato del NameNode sin metadata previa.
#
# Variables de override: OL_JAVA_HOME, OL_HADOOP_HOME, OL_HADOOP_CONF_DIR,
# OL_VENV, OL_PGBIN, OL_PGDATA, OL_PGADMIN, OL_PGSOCKET, OL_HDFS_DATA_DIR.

OL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ol_detectar_java() {
  if [[ -z "${JAVA_HOME:-}" || ! -x "${JAVA_HOME:-/}/bin/java" ]]; then
    if command -v java >/dev/null 2>&1; then
      JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
    else
      for cand in \
        "${OL_JAVA_HOME:-}" \
        "$HOME/Desktop"/opt/jdk-* \
        "$HOME"/opt/jdk-* \
        "$HOME"/jdk-*; do
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
      "$HOME/Desktop"/opt/hadoop-* \
      "$HOME"/opt/hadoop-* \
      "$HOME"/hadoop-*; do
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

ol_instalar_venv() {
  local venv="$1" modulos="$2"
  local req="$OL_ROOT/requirements.txt"
  echo "No hay un venv con $modulos: creando $venv..."
  python3 -m venv "$venv" || {
    echo "No pude crear el venv con python3 -m venv" >&2
    return 1
  }
  if [[ ! -f "$req" ]]; then
    echo "Falta $req: no sé qué paquetes instalar" >&2
    return 1
  fi
  "$venv/bin/python3" -m pip install --upgrade pip >/dev/null 2>&1 || true
  "$venv/bin/python3" -m pip install -r "$req" || return 1
  ol_venv_valido "$venv" "$modulos"
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

  if [[ -z "$venv" ]]; then
    if [[ -d "$HOME/Desktop" ]]; then
      venv="$HOME/Desktop/venv-bigdata"
    else
      venv="$HOME/venv-bigdata"
    fi
    ol_instalar_venv "$venv" "$modulos" || {
      echo "No encuentro ni pude crear un venv con $modulos" >&2
      return 1
    }
  fi

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
        "$HOME/Desktop"/venv-pgtest/lib/python*/site-packages/pgserver/pginstall/bin \
        "$HOME"/venv-pgtest/lib/python*/site-packages/pgserver/pginstall/bin; do
        [[ -x "$cand/psql" ]] && { PGBIN="$cand"; break; }
      done
    fi
  fi
  [[ -n "${PGBIN:-}" && -x "$PGBIN/psql" ]] || {
    echo "No encuentro psql (usa OL_PGBIN=/ruta/al/bin)" >&2
    return 1
  }

  PGUSER="${PGUSER:-${USER:-$(id -un)}}"
  PGHOST="${PGHOST:-localhost}"
  PGPORT="${PGPORT:-5432}"
  PGDATABASE="${PGDATABASE:-$PGUSER}"

  PGDATA="${OL_PGDATA:-}"
  if [[ -z "$PGDATA" || ! -f "$PGDATA/PG_VERSION" ]]; then
    for cand in \
      "$HOME/pgdata" \
      "$HOME/Desktop/opt/pgdata" \
      "$HOME/Desktop/pgdata" \
      "$HOME/opt/pgdata"; do
      if [[ -f "$cand/PG_VERSION" ]]; then PGDATA="$cand"; break; fi
    done
  fi
  if [[ -z "${PGDATA:-}" || ! -f "$PGDATA/PG_VERSION" ]]; then
    PGDATA="${OL_PGDATA:-$HOME/pgdata}"
    echo "No hay PGDATA válido: inicializando $PGDATA..."
    mkdir -p "$PGDATA"
    "$PGBIN/initdb" -D "$PGDATA" -U "$PGUSER" \
      --auth-local=trust --auth-host=trust >/dev/null || {
        echo "No pude inicializar PGDATA en $PGDATA" >&2
        return 1
      }
  fi

  export PGBIN PGDATA PGHOST PGPORT PGUSER PGDATABASE
  export PATH="$PGBIN:$PATH"
}

ol_asegurar_hdfs() {
  # La configuración puede apuntar a rutas que no existen en esta máquina.
  # Si hay un HDFS ya formateado en otra ruta conocida, se enlaza sin borrar nada.
  ol_preparar_dir_hdfs dfs.namenode.name.dir namenode || return 1
  ol_preparar_dir_hdfs dfs.datanode.data.dir datanode || return 1

  local nn_dir
  nn_dir="$(ol_hdfs_conf_key dfs.namenode.name.dir)"
  if [[ -n "$nn_dir" && ! -f "$nn_dir/current/VERSION" ]]; then
    echo "HDFS: no hay metadata previa; formateando NameNode en $nn_dir..."
    hdfs namenode -format -nonInteractive >/dev/null 2>&1 || {
      echo "No pude formatear el NameNode" >&2
      return 1
    }
  fi

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

ol_hdfs_conf_key() {
  hdfs getconf -confKey "$1" 2>/dev/null | tail -n 1 | sed 's|^file://||'
}

ol_preparar_dir_hdfs() {
  local key="$1" nombre="$2"
  local ruta candidato
  local candidatos=()

  ruta="$(ol_hdfs_conf_key "$key")"
  [[ -n "$ruta" ]] || return 0
  if [[ -d "$ruta" ]]; then return 0; fi

  if [[ -n "${OL_HDFS_DATA_DIR:-}" ]]; then
    candidatos+=("$OL_HDFS_DATA_DIR/$nombre")
  fi
  candidatos+=("$HOME/Desktop/hdfs/$nombre" "$HOME/hdfs/$nombre")

  for candidato in "${candidatos[@]}"; do
    [[ -n "$candidato" && -d "$candidato/current" ]] || continue
    echo "HDFS: $ruta no existe; enlazando con $candidato"
    mkdir -p "$(dirname "$ruta")"
    ln -s "$candidato" "$ruta"
    return 0
  done

  echo "HDFS: creando directorio vacío $ruta"
  mkdir -p "$ruta"
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
  local host="${OL_PGSOCKET:-$PGHOST}"
  local admin="${OL_PGADMIN:-}"
  local consulta=()

  # Si el rol de usuario aún no existe, hay que conectarse como administrador.
  if [[ -z "$admin" ]]; then
    if "$PGBIN/psql" -h "$host" -U "$PGUSER" -d postgres -tAc 'SELECT 1' >/dev/null 2>&1; then
      admin="$PGUSER"
    else
      admin="postgres"
    fi
  fi

  consulta=("$PGBIN/psql" -h "$host" -U "$admin" -v ON_ERROR_STOP=1 -d postgres -tAc)

  if ! "${consulta[@]}" "SELECT 1 FROM pg_roles WHERE rolname = '$PGUSER'" | grep -q 1; then
    echo "Creando rol PostgreSQL $PGUSER..."
    "$PGBIN/psql" -h "$host" -U "$admin" -v ON_ERROR_STOP=1 -d postgres \
      -c "CREATE ROLE \"$PGUSER\" LOGIN SUPERUSER"
  fi
  if ! "${consulta[@]}" "SELECT 1 FROM pg_database WHERE datname = '$PGDATABASE'" | grep -q 1; then
    echo "Creando base de datos $PGDATABASE..."
    "$PGBIN/createdb" -h "$host" -U "$admin" -O "$PGUSER" "$PGDATABASE"
  fi
}

ol_resumen_entorno() {
  echo "  Java:     $JAVA_HOME"
  echo "  Hadoop:   ${HADOOP_HOME:-(no necesario)}"
  echo "  Python:   $("$VENV/bin/python3" -c 'import sys; print(sys.version.split()[0])')"
  [[ -n "${PGBIN:-}" ]] && echo "  Postgres: $PGHOST:$PGPORT ($PGUSER/$PGDATABASE)"
  [[ -n "${PGDATA:-}" ]] && echo "  PGDATA:   $PGDATA"
}
