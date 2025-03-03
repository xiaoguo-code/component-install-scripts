#!/bin/bash
# 部署HBase集群脚本 install-HBase-cluster.sh

# 配置区域（部署前需修改以下变量）
##################################################
HBASE_NODES=(                  # 集群节点信息（IP或主机名）
    "192.168.31.171"
    "192.168.31.172"
    "192.168.31.173"
)
HBASE_HOSTNAMES=(               # 集群节点主机名
    "hadoop1"
    "hadoop2"
    "hadoop3"
)
SSH_USER="root"             # 目标服务器SSH用户名
HBASE_TAR="hbase-1.3.1-bin.tar.gz"  # 安装包名称
HBASE_MASTER_HOSTNAME=hadoop1       # HBase Master节点主机名
##################################################

# 全局变量
HBASE_INSTALL_DIR="/usr/local/hbase-1.3.1"
HBASE_TAR_BASENAME=$(basename "$HBASE_TAR" -bin.tar.gz)  # 安装包名解压后的目录名

# 检查参数合法性
if [ $# -ne 1 ]; then
    echo "用法: $0 [install/uninstall/start/stop]"
    exit 1
fi
# 目录不能是根目录
if [ "$HBASE_INSTALL_DIR" == "/" ]; then
    echo "错误: $HBASE_INSTALL_DIR 不能是根目录" >&2
    exit 1
fi
if [ "$1" == "install" ];then
  # 检查JAVA_HOME是否有配置
  if [ -z "$JAVA_HOME" ]; then
      echo "错误: JAVA_HOME 未设置，请先设置JAVA_HOME环境变量" >&2
      exit 1
  fi
  # 检查安装目录是否已安装，如果参数为install
  if [ -d "$HBASE_INSTALL_DIR" ]; then
      echo "错误: $HBASE_INSTALL_DIR 已存在，请先卸载" >&2
      exit 1
  fi
  # 检查./config/hbase-env.sh文件是否存在
  if [ ! -f "./config/hbase-env.sh" ]; then
      echo "错误: ./config/hbase-env.sh 文件不存在" >&2
      exit 1
  fi
  # 检查./config/hbase-site.xml文件是否存在
  if [ ! -f "./config/hbase-site.xml" ]; then
      echo "错误: ./config/hbase-site.xml 文件不存在" >&2
      exit 1
  fi
  # 检查./hadoop/hdfs-site.xml文件是否存在
  if [ ! -f "./hadoop/hdfs-site.xml" ]; then
      echo "错误: ./hadoop/hdfs-site.xml 文件不存在" >&2
      exit 1
  fi
  # 检查./config/core-site.xml文件是否存在
  if [ ! -f "./hadoop/core-site.xml" ]; then
      echo "错误: ./hadoop/core-site.xml 文件不存在" >&2
      exit 1
  fi
fi


# 生成hbase-env.sh配置
generate_env_config(){
  # 将config目录下的hbase-env.sh内容写入/tmp/hbase-env.sh
  cat ./config/hbase-env.sh > /tmp/hbase-env.sh
}
# 生成hbase-site.xml配置
generate_site_config(){
  cat ./config/hbase-site.xml > /tmp/hbase-site.xml
}
# 生成regionservers配置
generate_regionservers_config(){
  # 将HBASE_HOSTNAMES遍历换行写入
  rm -f /tmp/regionservers
  for node in "${HBASE_HOSTNAMES[@]}"; do
    echo "$node" >> /tmp/regionservers
  done
}
# 生成backup-masters配置
generate_backup_masters_config(){
  # 将HBASE_HOSTNAMES遍历换行写入，除HBASE_MASTER_HOSTNAME外
  rm -f /tmp/backup-masters
  for node in "${HBASE_HOSTNAMES[@]}"; do
    if [ "$node" != "$HBASE_MASTER_HOSTNAME" ]; then
      echo "$node" >> /tmp/backup-masters
    fi
  done
}
# 生成core-site.xml配置
generate_core_site_config(){
  cat ./hadoop/core-site.xml > /tmp/core-site.xml
}
# 生成hdfs-site.xml配置
generate_hdfs_site_config(){
  cat ./hadoop/hdfs-site.xml > /tmp/hdfs-site.xml
}

# 批量执行远程命令
remote_exec() {
  local cmd=$1
  for node in "${HBASE_NODES[@]}"; do
    echo -e "\n>>> 在节点 $node 执行: $cmd"
    ssh -T $SSH_USER@$node <<< "$cmd"
    if [ $? -ne 0 ]; then
        echo "!!! 节点 $node 执行失败"
        return 1
    else
        echo "!!! 节点 $node 执行成功"
    fi
  done
}

# 安装集群
install_cluster() {
    # 本地校验
    if [ ! -f "$HBASE_TAR" ]; then
        echo "错误: 找不到HBase安装包 $HBASE_TAR"
        exit 1
    fi
    # 生成hbase-env.sh文件
    generate_env_config
    # 生成hbase-site.xml文件
    generate_site_config
    # 生成regionservers文件
    generate_regionservers_config
    # 生成backup-masters文件
    generate_backup_masters_config
    # 生成core-site.xml文件
    generate_core_site_config
    # 生成hdfs-site.xml文件
    generate_hdfs_site_config


    # 批量部署到所有节点
    for node in "${HBASE_NODES[@]}"; do
        echo -e "\n===== 部署到节点 $node 开始 ====="

        # 上传安装包
        scp $HBASE_TAR $SSH_USER@$node:/tmp/

        # 执行安装命令
        ssh -T $SSH_USER@$node << EOF
set -e
# 解压安装
tar -xzf /tmp/$HBASE_TAR -C /tmp/
mv /tmp/$HBASE_TAR_BASENAME $HBASE_INSTALL_DIR

# 配置环境变量
grep -q "HBASE_HOME=" /etc/profile || \\
echo -e "\n# HBase环境变量\nexport HBASE_HOME=$HBASE_INSTALL_DIR\nexport PATH=\\\$PATH:\\\$HBASE_HOME/bin" >> /etc/profile
source /etc/profile
EOF
        # 分发配置文件
        scp -r /tmp/hbase-env.sh $SSH_USER@$node:$HBASE_INSTALL_DIR/conf/hbase-env.sh
        scp -r /tmp/hbase-site.xml $SSH_USER@$node:$HBASE_INSTALL_DIR/conf/hbase-site.xml
        scp -r /tmp/regionservers $SSH_USER@$node:$HBASE_INSTALL_DIR/conf/regionservers
        scp -r /tmp/backup-masters $SSH_USER@$node:$HBASE_INSTALL_DIR/conf/backup-masters
        scp -r /tmp/core-site.xml $SSH_USER@$node:$HBASE_INSTALL_DIR/conf/core-site.xml
        scp -r /tmp/hdfs-site.xml $SSH_USER@$node:$HBASE_INSTALL_DIR/conf/hdfs-site.xml
        echo -e "\n===== 部署到节点 $node 完成 ====="
    done
    echo "集群安装完成！"
}

# 卸载集群
uninstall_cluster() {
    remote_exec "rm -rf $HBASE_INSTALL_DIR  && sed -i '/HBase环境变量/d;/HBASE_HOME=/d;/\$HBASE_HOME\/bin/d' /etc/profile"
    echo "集群已卸载"
}


# 主逻辑
case "$1" in
    install)
        install_cluster
        ;;
    uninstall)
        uninstall_cluster
        ;;
    *)
        echo "错误: 无效操作 '$1'"
        echo "用法: $0 [install/uninstall]"
        exit 1
        ;;
esac
