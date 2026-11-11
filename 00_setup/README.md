# 00 · Preparación del entorno

Objetivo: dejar lista una VM Ubuntu 26.04.1 LTS en VirtualBox con Java 17, Hadoop 3.5.0 en modo pseudo-distribuido, PostgreSQL 18 y PySpark 4.3.0.

## 1. Crear la VM en VirtualBox

1. Descarga Ubuntu 26.04.1 LTS desde https://releases.ubuntu.com/26.04/ (imagen ISO de escritorio).
2. Nueva VM: tipo Linux, versión Ubuntu (64-bit).
3. Hardware: **8 GB de RAM**, **4 CPU**.
4. Disco: **120 GB**, VDI, reservado dinámicamente.
5. Instala Ubuntu con las opciones por defecto y crea un usuario con el nombre que uses en el curso.

> Tu computadora anfitriona necesita al menos 12 GB de RAM para que la VM funcione bien.

### Redirección de puertos (NAT)

Configuración → Red → Adaptador 1 → Avanzadas → Redirección de puertos:

| Nombre | Protocolo | Puerto anfitrión | Puerto invitado |
|---|---|---|---|
| HDFS UI | TCP | 9870 | 9870 |
| HDFS RPC | TCP | 8020 | 8020 |
| PostgreSQL | TCP | 5432 | 5432 |

Así puedes abrir `http://localhost:9870` desde Windows.

## 2. Paquetes base

```bash
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y openjdk-17-jdk-headless python3-venv python3-pip \
  postgresql postgresql-contrib curl wget git
```

Comprueba Java:

```bash
java -version   # debe mostrar: openjdk version "17..."
```

> Usamos Java 17 y no una versión más nueva porque las notas de Hadoop 3.5 indican que Java 17 es el requisito del servidor. Spark 4.3 también lo soporta.

## 3. Hadoop 3.5.0 (pseudo-distribuido)

```bash
cd ~
wget https://dlcdn.apache.org/hadoop/common/hadoop-3.5.0/hadoop-3.5.0.tar.gz
wget https://downloads.apache.org/hadoop/common/hadoop-3.5.0/hadoop-3.5.0.tar.gz.sha512

# El .sha512 de Apache tiene formato "SHA512 (archivo) = hash"; lo convertimos para verificar:
echo "$(awk -F' = ' '{print $2}' hadoop-3.5.0.tar.gz.sha512)  hadoop-3.5.0.tar.gz" | sha512sum -c -
# Debe responder: hadoop-3.5.0.tar.gz: OK

tar -xzf hadoop-3.5.0.tar.gz
```

Añade a `~/.bashrc`:

```bash
export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
export HADOOP_HOME=$HOME/hadoop-3.5.0
export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin
```

Configura `$HADOOP_HOME/etc/hadoop/core-site.xml`:

```xml
<configuration>
  <property>
    <name>fs.defaultFS</name>
    <value>hdfs://localhost:8020</value>
  </property>
</configuration>
```

Configura `$HADOOP_HOME/etc/hadoop/hdfs-site.xml`:

```xml
<configuration>
  <property>
    <name>dfs.replication</name>
    <value>1</value>
  </property>
  <property>
    <name>dfs.namenode.name.dir</name>
    <value>file:///home/USUARIO/hdfs/namenode</value>
  </property>
  <property>
    <name>dfs.datanode.data.dir</name>
    <value>file:///home/USUARIO/hdfs/datanode</value>
  </property>
</configuration>
```

Sustituye `USUARIO` por tu usuario. Luego:

```bash
hdfs namenode -format -nonInteractive
start-dfs.sh
hdfs dfs -mkdir -p /raw /clean /curated
hdfs dfs -ls /
```

Verifica en el navegador: `http://localhost:9870`.

Para apagar el clúster al terminar: `stop-dfs.sh`.

> Si `start-dfs.sh` pide contraseña por SSH, configura SSH sin contraseña a localhost: `ssh-keygen -t ed25519`, luego `ssh-copy-id localhost`.

## 4. PostgreSQL 18

Ubuntu 26.04 incluye PostgreSQL 18 (paquete `postgresql-18`, versión 18.6 en los repositorios oficiales). La versión 18.7 más reciente no está en el repositorio de Ubuntu; no es necesaria para el curso. Compruébalo:

```bash
psql --version           # debe mostrar 18.x
sudo systemctl enable --now postgresql
sudo -u postgres createuser --superuser $USER
createdb $USER
psql -c "select version();"
```

## 5. PySpark 4.3.0 en entorno virtual

```bash
python3 -m venv ~/venv-bigdata
source ~/venv-bigdata/bin/activate
pip install --upgrade pip
pip install "pyspark==4.3.0" pandas pyarrow psycopg[binary]
python -c "import pyspark; print(pyspark.__version__)"   # 4.3.0
```

Añade `source ~/venv-bigdata/bin/activate` a tu `~/.bashrc` si quieres que se active siempre.

## 6. Verificación

```bash
cd bigdata-openlibrary
bash 00_setup/verificar.sh
```

Todas las líneas deben salir en `[OK]` antes de pasar a la semana 1.

## Problemas frecuentes

| Síntoma | Causa probable | Solución |
|---|---|---|
| `NameNode` no arranca | Java distinto de 17 | `update-alternatives --config java` y elige la 17 |
| `localhost:9870` no responde | NameNode caído | `jps` debe mostrar NameNode y DataNode; revisa `$HADOOP_HOME/logs/` |
| Spark: `JAVA_HOME is not set` | Variables no cargadas | `source ~/.bashrc` |
| VM muy lenta | Poca RAM disponible | Cierra apps en el anfitrión; sube a 8 GB si son 4 |
| `psql: FATAL: role does not exist` | Usuario sin rol de PostgreSQL | Repite el `createuser` del paso 4 |
