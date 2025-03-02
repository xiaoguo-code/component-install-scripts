#!/bin/bash
# 部署ZooKeeper集群脚本 install-zookeeper-cluster.sh

# 配置区域（部署前需修改以下变量）
##################################################
ZK_NODES=(                  # 集群节点信息（IP或主机名）
    "192.168.31.171"
    "192.168.31.172"
    "192.168.31.173"
)
ZK_HOSTNAMES=(               # 集群节点主机名
    "hadoop1"
    "hadoop2"
    "hadoop3"
)
SSH_USER="root"             # 目标服务器SSH用户名
ZK_TAR="apache-zookeeper-3.8.4-bin.tar.gz"  # 安装包名称
ZK_ADMIN_SERVER_PORT=8580          # 指定zk的AdminServer服务端口，用于提供监控和管理信息
ZK_ADMIN_SERVER_ENABLE=false      # AdminServer服务是否开启，默认关闭
##################################################

# 全局变量
ZK_INSTALL_DIR="/usr/local/zookeeper"
ZK_DATA_DIR="/data/zookeeper/data"
ZK_LOG_DIR="/data/zookeeper/logs"
ZK_TAR_BASENAME=$(basename "$ZK_TAR" .tar.gz)  # 安装包名解压后的文件名

# 检查参数合法性
if [ $# -ne 1 ]; then
    echo "用法: $0 [install/uninstall/start/stop/status]"
    exit 1
fi
# 检查JAVA_HOME是否有配置
if [ -z "$JAVA_HOME" ]; then
    echo "错误: JAVA_HOME 未设置，请先设置JAVA_HOME环境变量" >&2
    exit 1
fi
# 检查安装目录是否已安装，如果参数为install
if [ "$1" == "install" ] && [ -d "$ZK_INSTALL_DIR" ]; then
    echo "错误: $ZK_INSTALL_DIR 已存在，请先卸载" >&2
    exit 1
fi

# 生成节点配置
generate_config() {
    cat > /tmp/zoo.cfg << EOF
tickTime=2000
initLimit=10
syncLimit=5
clientPort=2181
dataDir=$ZK_DATA_DIR
dataLogDir=$ZK_LOG_DIR
$(for i in "${!ZK_HOSTNAMES[@]}"; do
    echo "server.$(echo "${ZK_NODES[i]}" | awk -F. '{print $4}')=${ZK_HOSTNAMES[i]}:2888:3888"
  done)
admin.serverPort=$ZK_ADMIN_SERVER_PORT
admin.enableServer=$ZK_ADMIN_SERVER_ENABLE
EOF
}

# 批量执行远程命令
remote_exec() {
    local cmd=$1
    for node in "${ZK_NODES[@]}"; do
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
    if [ ! -f "$ZK_TAR" ]; then
        echo "错误: 找不到ZooKeeper安装包 $ZK_TAR"
        exit 1
    fi

    # 生成配置文件
    generate_config

    # 批量部署到所有节点
    for node in "${ZK_NODES[@]}"; do
        echo -e "\n===== 部署到节点 $node 开始 ====="

        # 上传安装包
        scp $ZK_TAR $SSH_USER@$node:/tmp/

        # 执行安装命令
        ssh -T $SSH_USER@$node << EOF
set -e
# 解压安装
tar -xzf /tmp/$ZK_TAR -C /usr/local/
mv /usr/local/$ZK_TAR_BASENAME $ZK_INSTALL_DIR

# 配置环境变量
grep -q "ZK_HOME=" /etc/profile || \\
echo -e "\n# ZooKeeper环境变量\nexport ZK_HOME=$ZK_INSTALL_DIR\nexport PATH=\\\$PATH:\\\$ZK_HOME/bin" >> /etc/profile

source /etc/profile

# 创建数据目录
mkdir -p $ZK_DATA_DIR $ZK_LOG_DIR

# 设置myid（根据IP地址最后一位）
myid=\$(echo "$node" | awk -F. '{print \$4}')
echo \$myid > $ZK_DATA_DIR/myid
EOF

        # 分发配置文件
        scp /tmp/zoo.cfg $SSH_USER@$node:$ZK_INSTALL_DIR/conf/zoo.cfg
        echo -e "\n===== 部署到节点 $node 完成 ====="
    done

    echo "集群安装完成！"
}

# 卸载集群
uninstall_cluster() {
    remote_exec "rm -rf $ZK_INSTALL_DIR /data/zookeeper && sed -i '/ZooKeeper环境变量/d;/ZK_HOME=/d;/\$ZK_HOME\/bin/d' /etc/profile"
    echo "集群已卸载"
}

# 服务管理
service_control() {
    local action=$1
    remote_exec "$ZK_INSTALL_DIR/bin/zkServer.sh $action"
}

# 主逻辑
case "$1" in
    install)
        install_cluster
        ;;
    uninstall)
        uninstall_cluster
        ;;
    start|stop|status)
        service_control "$1"
        ;;
    *)
        echo "错误: 无效操作 '$1'"
        echo "用法: $0 [install/uninstall/start/stop/status]"
        exit 1
        ;;
esac
