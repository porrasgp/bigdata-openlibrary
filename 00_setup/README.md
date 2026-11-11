# 00 · Preparación del entorno

## Qué contiene esta carpeta

| Archivo | Para qué sirve |
|---|---|
| `README.md` | Esta guía: VM, Java, Hadoop, PostgreSQL y PySpark |
| `env.sh` | Variables del curso. Se carga en cada terminal nueva |
| `verificar.sh` | Comprueba que cada componente responde. Úsalo al terminar la instalación |

## Qué se hizo y qué comprobamos

Las versiones de esta guía se revisaron el 11 de noviembre de 2026:

| Componente | Versión | Cómo se instala | Estado |
|---|---|---|---|
| Ubuntu | 26.04.1 LTS | ISO de escritorio | Última LTS |
| Java | 17 | `openjdk-17-jdk-headless` (apt) | Requisito de Hadoop 3.5 en el servidor |
| Hadoop | 3.5.0 | Tarball de Apache, con SHA-512 | Probado en modo pseudo-distribuido |
| PostgreSQL | 18 | `postgresql` (apt) | Ubuntu 26.04 trae la 18.6 |
| PySpark | 4.3.0 | `pip` en entorno virtual | Probado con la muestra |

Probamos los pasos de Hadoop, HDFS y PySpark en un equipo con AlmaLinux (no Ubuntu), con JDK 17 en espacio de usuario. En Ubuntu, los comandos son los mismos, salvo las rutas de instalación de Java.

## Requisitos de la VM

| Recurso | Mínimo | Recomendado |
|---|---|---|
| Hipervisor | VirtualBox 7.x | VirtualBox 7.x |
| RAM de la VM | 8 GB | 8 GB |
| CPU | 4 vCPU | 4 vCPU |
| Disco | 120 GB | 120 GB, reservado dinámicamente |

Tu computadora anfitriona necesita al menos 12 GB de RAM para que la VM funcione bien.

## 1. Crear la VM en VirtualBox

1. Descarga Ubuntu 26.04.1 LTS desde https://releases.ubuntu.com/26.04/ (imagen de escritorio).
2. Nueva VM: tipo Linux, versión Ubuntu (64-bit).
3. Hardware: **8 GB de RAM** y **4 CPU**.
4. Disco: **120 GB**, VDI, reservado dinámicamente.
5. Instala Ubuntu con las opciones por defecto y crea un usuario.

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

Configura `~/hadoop-3.5.0/etc/hadoop/core-site.xml`:

```xml
<configuration>
  <property>
    <name>fs.defaultFS</name>
    <value>hdfs://localhost:8020</value>
  </property>
</configuration>
```

Configura `~/hadoop-3.5.0/etc/hadoop/hdfs-site.xml` (sustituye `USUARIO` por tu usuario de Linux):

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

Formatea el NameNode **solo la primera vez**:

```bash
source ~/bigdata-openlibrary/00_setup/env.sh
hdfs namenode -format -nonInteractive
```

Arranca HDFS. Este método no necesita SSH y es el que probamos:

```bash
hdfs --daemon start namenode
hdfs --daemon start datanode
jps                              # deben aparecer NameNode y DataNode
hdfs dfs -mkdir -p /raw /clean /curated
hdfs dfs -ls /
```

Verifica en el navegador: `http://localhost:9870`.

Para apagar: `hdfs --daemon stop datanode` y luego `hdfs --daemon stop namenode`.

> `start-dfs.sh` también existe, pero pide SSH sin contraseña a localhost. Si lo quieres usar: `ssh-keygen -t ed25519` y luego `ssh-copy-id localhost`.

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
pip install "pyspark==4.3.0" pandas pyarrow "psycopg[binary]"
python -c "import pyspark; print(pyspark.__version__)"   # 4.3.0
```

> PySpark necesita Python 3.11 o superior. Compruébalo con `python3 --version`.

## 6. Variables del curso

```bash
source ~/bigdata-openlibrary/00_setup/env.sh
```

Cárgalo en cada terminal nueva, o añádelo al final de `~/.bashrc`. El archivo define `JAVA_HOME`, `HADOOP_HOME`, el entorno virtual, la conexión a PostgreSQL y las rutas de HDFS que usan los scripts.

Si tu VM tiene menos de 8 GB de RAM, baja la memoria de Spark:

```bash
export SPARK_DRIVER_MEMORY=1g
```

## 7. Verificación

```bash
cd ~/bigdata-openlibrary
source 00_setup/env.sh
bash 00_setup/verificar.sh
```

Todas las líneas deben salir en `[OK]` antes de pasar a la semana 1.

## Problemas frecuentes

| Síntoma | Causa probable | Solución |
|---|---|---|
| `hdfs: command not found` | `env.sh` no cargado o `HADOOP_HOME` incorrecto | `source 00_setup/env.sh` y revisa `ls ~/hadoop-3.5.0/bin` |
| `localhost:9870` no responde | NameNode caído | `jps` debe mostrar NameNode y DataNode; revisa `~/hadoop-3.5.0/logs/` |
| `Connection refused` a `localhost:8020` | HDFS no arrancado | `hdfs --daemon start namenode` y `hdfs --daemon start datanode` |
| `UnsupportedClassVersionError` | Java distinto de 17 | `sudo update-alternatives --config java` y elige la 17 |
| `JAVA_HOME is not set` | Variables no cargadas | `source ~/bigdata-openlibrary/00_setup/env.sh` |
| `psql: FATAL: role does not exist` | Usuario sin rol de PostgreSQL | Repite `createuser --superuser $USER` |
| Spark se queda sin memoria | Driver demasiado grande para la VM | `export SPARK_DRIVER_MEMORY=2g` |
| VM muy lenta | Poca RAM disponible | Cierra apps del anfitrión; sube la RAM de la VM a 8 GB |
