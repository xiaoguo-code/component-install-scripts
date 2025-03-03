# HBase集群一键部署脚本

## 使用方法

1. 在随便一台服务器上，上传脚本install-hbase-cluster.sh、config目录、hadoop目录和安装包，确保在同一目录
2. 修改install-hbase-cluster.sh脚本中的配置信息，包括：
    * HBASE_NODES: HBase集群节点列表
    * HBASE_HOSTNAMES: HBase集群节点主机名列表
    * SSH_USER: SSH连接用户名
    * HBASE_TAR: HBase安装包名称
    * HBASE_MASTER_HOSTNAME: HBase主节点主机名
3. 在脚本所在目录执行一下命令进行hbase安装
   ```shell
   bash install-hbase-cluster.sh install
   ```
4. 执行一下命令卸载hbase集群:
   ```shell
   bash install-hbase-cluster.sh uninstall
   ```
## 注意事项

1. 部署HBase，请提前部署好zookeeper，hadoop
2. 确保服务器时间一直，相差超过30s会导致regionserver起不来
2. config目录下要放上你调整后的配置文件hbase-env.sh和hbase-site.xm
3. hadoop目录下要放上你要连接的hadoop的配置文件core-site.xml和hdfs-site.xml