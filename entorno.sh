#!/usr/bin/env bash
# Detección y preparación automática del entorno, compartida por los scripts manuales.
# Uso: source entorno.sh   (define funciones; no ejecuta nada por sí sola)
#
# Las funciones ol_detectar_* y ol_asegurar_* sí pueden crear lo que falte:
#   - Java 17 y Hadoop 3.5 (descarga si no están instalados),
#   - venv con los módulos pedidos (instala requirements.txt del proyecto),
#   - binarios de PostgreSQL mediante pgserver si no hay psql,
#   - PGDATA inicializado si no existe,
#   - rol y base de datos PostgreSQL,
#   - directorios de NameNode/DataNode y formato del NameNode sin metadata previa.
#
# Variables de override: OL_TOOLS_DIR, OL_JAVA_HOME, OL_JAVA_URL,
# OL_HADOOP_HOME, OL_HADOOP_CONF_DIR, OL_HADOOP_URL, OL_VENV, OL_PGVENV,
# OL_PGBIN, OL_PGDATA, OL_PGADMIN, OL_PGSOCKET, OL_HDFS_DATA_DIR.

OL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

OL_TOOLS_DIR="${OL_TOOLS_DIR:-}"
if [[ -z "$OL_TOOLS_DIR" ]]; then
  if [[ -d "$HOME/Desktop" ]]; then
    OL_TOOLS_DIR="$HOME/Desktop/opt"
  else
    OL_TOOLS_DIR="$HOME/opt"
  fi
fi

ol_descargar() {
  local url="$1" dest="$2"
  command -v curl >/dev/null 2>&1 || {
    echo "Falta curl para descargar $url" >&2
    return 1
  }
  echo "Descargando $url..."
  curl -fL --retry 3 -o "$dest" "$url" || return 1
}

ol_enlazar_herramienta() {
  local patron="$1" dest="$2" extraida
  extraida=$(find "$(dirname "$dest")" -maxdepth 1 -type d -name "$patron" 2>/dev/null \
    | sort -V | tail -n 1)
  [[ -n "$extraida" ]] || return 1
  ln -sfn "$extraida" "$dest"
}

ol_instalar_java() {
  local dest="$OL_TOOLS_DIR/jdk"
  local url="${OL_JAVA_URL:-https://corretto.aws/downloads/latest/amazon-corretto-17-x64-linux-jdk.tar.gz}"
  local tmp="/tmp/opencode/jdk-17.tar.gz"
  mkdir -p "$OL_TOOLS_DIR" /tmp/opencode
  echo "No hay Java 17: instalando Amazon Corretto 17 (~185 MB)..."
  ol_descargar "$url" "$tmp" || return 1
  tar -xzf "$tmp" -C "$OL_TOOLS_DIR" || return 1
  ol_enlazar_herramienta 'amazon-corretto-17*' "$dest" || return 1
  rm -f "$tmp"
}

ol_configurar_hadoop_base() {
  local conf="$1/etc/hadoop"
  mkdir -p "$conf"
  if [[ ! -s "$conf/core-site.xml" ]]; then
    cat > "$conf/core-site.xml" <<'XML'
<configuration>
  <property><name>fs.defaultFS</name><value>hdfs://localhost:8020</value></property>
</configuration>
XML
  fi
  if [[ ! -s "$conf/hdfs-site.xml" ]]; then
    cat > "$conf/hdfs-site.xml" <<XML
<configuration>
  <property><name>dfs.replication</name><value>1</value></property>
  <property><name>dfs.namenode.name.dir</name><value>file://$HOME/hdfs/namenode</value></property>
  <property><name>dfs.datanode.data.dir</name><value>file://$HOME/hdfs/datanode</value></property>
</configuration>
XML
  fi
}

ol_instalar_hadoop() {
  local dest="$OL_TOOLS_DIR/hadoop"
  local url="${OL_HADOOP_URL:-https://archive.apache.org/dist/hadoop/common/hadoop-3.5.0/hadoop-3.5.0.tar.gz}"
  local tmp="/tmp/opencode/hadoop-3.5.0.tar.gz"
  local extraida
  mkdir -p "$OL_TOOLS_DIR" /tmp/opencode
  echo "No hay Hadoop: instalando Hadoop 3.5.0 (~555 MB)..."
  ol_descargar "$url" "$tmp" || return 1
  tar -xzf "$tmp" -C "$OL_TOOLS_DIR" || return 1
  extraida=$(find "$OL_TOOLS_DIR" -maxdepth 1 -type d -name 'hadoop-3.*' 2>/dev/null \
    | sort -V | tail -n 1)
  [[ -n "$extraida" ]] || return 1
  ln -sfn "$extraida" "$dest"
  ol_configurar_hadoop_base "$extraida"
  rm -f "$tmp"
}

ol_detectar_java() {
  local encontrado=""

  if [[ -n "${JAVA_HOME:-}" && -x "${JAVA_HOME:-/}/bin/java" ]]; then
    encontrado="$JAVA_HOME"
  fi
  if [[ -z "$encontrado" ]]; then
    for cand in \
      "${OL_JAVA_HOME:-}" \
      "$OL_TOOLS_DIR/jdk" \
      "$OL_TOOLS_DIR"/jdk-* \
      "$HOME"/opt/jdk-* \
      "$HOME/.jdk"/jdk-* \
      "$HOME"/jdk-*; do
      [[ -n "$cand" && -x "$cand/bin/java" ]] && { encontrado="$cand"; break; }
    done
  fi
  if [[ -z "$encontrado" ]] && command -v java >/dev/null 2>&1; then
    encontrado="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
  fi
  if [[ -z "$encontrado" ]]; then
    ol_instalar_java || return 1
    encontrado="$OL_TOOLS_DIR/jdk"
  fi

  JAVA_HOME="$encontrado"
  [[ -x "$JAVA_HOME/bin/java" ]] || {
    echo "No pude instalar Java 17 (usa OL_JAVA_URL=/ruta/al/jdk.tar.gz)" >&2
    return 1
  }
  export JAVA_HOME
  export PATH="$JAVA_HOME/bin:$PATH"
}

ol_detectar_hadoop() {
  local encontrado=""

  if [[ -n "${HADOOP_HOME:-}" && -x "${HADOOP_HOME:-/}/bin/hdfs" ]]; then
    encontrado="$HADOOP_HOME"
  fi
  if [[ -z "$encontrado" ]]; then
    for cand in \
      "${OL_HADOOP_HOME:-}" \
      "$OL_TOOLS_DIR/hadoop" \
      "$OL_TOOLS_DIR"/hadoop-* \
      "$HOME"/opt/hadoop-* \
      "$HOME"/hadoop-*; do
      [[ -n "$cand" && -x "$cand/bin/hdfs" ]] && { encontrado="$cand"; break; }
    done
  fi
  if [[ -z "$encontrado" ]]; then
    ol_instalar_hadoop || return 1
    encontrado="$OL_TOOLS_DIR/hadoop"
  fi

  HADOOP_HOME="$encontrado"
  [[ -x "$HADOOP_HOME/bin/hdfs" ]] || {
    echo "No pude instalar Hadoop (usa OL_HADOOP_URL=/ruta/hadoop.tar.gz)" >&2
    return 1
  }
  ol_configurar_hadoop_base "$HADOOP_HOME"
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

  if [[ "$modulos" == *pyspark* ]]; then
    ol_detectar_java || return 1
  fi

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

ol_instalar_pg() {
  local venv
  if [[ -d "$HOME/Desktop" ]]; then
    venv="${OL_PGVENV:-$HOME/Desktop/venv-pgtest}"
  else
    venv="${OL_PGVENV:-$HOME/venv-pgtest}"
  fi
  local cand
  echo "No hay psql: instalando binarios de PostgreSQL mediante pgserver..."
  python3 -m venv "$venv" || return 1
  "$venv/bin/python3" -m pip install --upgrade pip >/dev/null 2>&1 || true
  "$venv/bin/python3" -m pip install pgserver || return 1
  for cand in "$venv"/lib/python*/site-packages/pgserver/pginstall/bin; do
    if [[ -x "$cand/psql" ]]; then PGBIN="$cand"; return 0; fi
  done
  return 1
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
  if [[ -z "${PGBIN:-}" || ! -x "$PGBIN/psql" ]]; then
    ol_instalar_pg || {
      echo "No encuentro ni pude instalar psql (usa OL_PGBIN=/ruta/al/bin)" >&2
      return 1
    }
  fi

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
