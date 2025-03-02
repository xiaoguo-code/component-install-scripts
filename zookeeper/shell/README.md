# zookeeper集群一键部署脚本

## 使用方法

1. 在随便一台服务器上，上传脚本install-zookeeper-cluster.sh和zookeeper安装包，确保在同一目录
2. 修改install-zookeeper-cluster.sh脚本中的配置信息，包括：
    * ZK_NODES: 集群节点信息（IP或主机名）
    * ZK_HOSTNAMES: 集群节点主机名
    * SSH_USER: 目标服务器SSH用户名
    * ZK_TAR: 安装包名称
    * ZK_ADMIN_SERVER_PORT: 指定zk的AdminServer服务端口，用于提供监控和管理信息
    * ZK_ADMIN_SERVER_ENABLE: AdminServer服务是否开启，默认关闭
    * 等变量。
2. 在脚本所在目录下执行以下命令进行zookeeper安装：
   ```shell
   chmod +x install-zookeeper-cluster.sh
   ./install-zookeeper-cluster.sh install
   ```
4. 执行以下命令启动ZooKeeper集群：
   ```shell
   ./install-zookeeper-cluster.sh start
   ```
5. 执行以下命令停止ZooKeeper集群：
   ```shell
   ./install-zookeeper-cluster.sh stop
   ```
6. 执行以下命令查看ZooKeeper集群状态：
   ```shell
   ./install-zookeeper-cluster.sh status
   ```
7. 执行以下命令卸载ZooKeeper集群：
   ```shell
   ./install-zookeeper-cluster.sh uninstall
   ```

## 注意事项

1. 请确保所有节点上的防火墙已关闭，或者已开放ZooKeeper所需的端口（默认为2181）。
2. 请确保所有节点上的SSH服务已启动，并且节点之前配置好了免密，以便脚本可以通过SSH连接到所有节点。
3. 请确保所有节点上的JAVA_HOME环境变量已配置好，并且指向正确的Java安装目录。
4. 请确保所有节点上的ZooKeeper安装目录（默认为/usr/local/zookeeper）不存在，或者已卸载。
5. 请确保所有节点上的ZooKeeper数据目录（默认为/data/zookeeper/data）不存在，或者已卸载。
6. 请确保所有节点上的ZooKeeper日志目录（默认为/data/zookeeper/logs）不存在，或者已卸载。
7. 请确保所有节点上的ZooKeeper安装包（默认为apache-zookeeper-3.8.4-bin.tar.gz）已存在，并且位于脚本所在目录下。

## 脚本说明

1. 脚本首先会检查参数的合法性，如果参数不合法，则会输出错误信息并退出。
2. 脚本会检查JAVA_HOME环境变量是否已配置，如果未配置，则会输出错误信息并退出。
3. 脚本会检查安装目录是否已存在，如果已存在，则会输出错误信息并退出。
4. 脚本会生成ZooKeeper的配置文件，并将配置文件复制到所有节点上。
5. 脚本会启动ZooKeeper服务，并检查服务是否启动成功。
6. 脚本会停止ZooKeeper服务，并检查服务是否停止成功。
7. 脚本会查看ZooKeeper集群状态，并输出状态信息。
8. 脚本会卸载ZooKeeper服务，并检查服务是否卸载成功。

