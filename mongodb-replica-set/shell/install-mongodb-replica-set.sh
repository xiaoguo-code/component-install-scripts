#!/bin/bash
# 部署mongodb复制集脚本

# 配置区域（部署前需修改以下变量）
##################################################
MONGO_USER=shiny_maxdata                    # mongodb用户名
MONGO_PASSWORD=shiny_maxdata@2020            # mongodb密码
MONGO_TAR="mongodb-linux-x86_64-4.0.6.tgz"  # 安装包名称
MONGO_TAR_BASENAME=$(basename "$MONGO_TAR" .tgz)  # 安装包名解压后的文件名
MONGO_CACHE_SIZE_GB=1                       # mongodb缓存大小，单位GB
MONGO_REPLICA_SET_NAME=mongoReplicaSet      # 复制集名称
# 一主一从一仲裁
# 主节点
MONGO_PRIMARY_HOST=10.30.30.221                                 # 主节点ip
MONGO_PRIMARY_PORT=27018                                        # 主节点端口
MONGO_PRIMARY_PATH=/data/mongo1-$MONGO_PRIMARY_PORT             # 数据、日志、认证文件的存储路径
MONGO_PRIMARY_INSTALL_DIR="/usr/local/module/mongodb-1"         # 安装路径
# 从节点
MONGO_SECONDARY_HOST=10.30.85.22                                # 从节点ip
MONGO_SECONDARY_PORT=27018                                      # 从节点端口
MONGO_SECONDARY_PATH=/data/mongo2-$MONGO_SECONDARY_PORT         # 数据、日志、认证文件的存储路径
MONGO_SECONDARY_INSTALL_DIR="/usr/local/module/mongodb-2"       # 安装路径
# 仲裁节点
MONGO_ARBITER_HOST=10.30.85.33                                  # 仲裁节点ip
MONGO_ARBITER_PORT=27028                                        # 仲裁节点端口
MONGO_ARBITER_PATH=/data/mongo3-$MONGO_ARBITER_PORT             # 数据、日志、认证文件的存储路径
MONGO_ARBITER_INSTALL_DIR="/usr/local/module/mongodb-arbiter"   # 安装路径

SSH_USER="root"             # 目标服务器SSH用户名
##################################################
# 全局变量，可以不用修改
MONGO_KEY_FILE_NAME="access.key"                          # 复制集认证文件名
# 主节点
MONGO_PRIMARY_CONFIG_NAME=mongo-1.conf                     # 配置文件名
MONGO_PRIMARY_DATA_DIR="$MONGO_PRIMARY_PATH/db"                          # 数据路径
MONGO_PRIMARY_LOG_DIR="$MONGO_PRIMARY_PATH/log"                          # 日志路径
MONGO_PRIMARY_KEY_FILE_DIR="$MONGO_PRIMARY_PATH/mongodb-keyfile"            # 复制集认证文件路径
# 从节点
MONGO_SECONDARY_CONFIG_NAME=mongo-2.conf
MONGO_SECONDARY_DATA_DIR="$MONGO_SECONDARY_PATH/db"                          # 数据路径
MONGO_SECONDARY_LOG_DIR="$MONGO_SECONDARY_PATH/log"                          # 日志路径
MONGO_SECONDARY_KEY_FILE_DIR="$MONGO_SECONDARY_PATH/mongodb-keyfile"            # 复制集认证文件路径
# 仲裁节点
MONGO_ARBITER_CONFIG_NAME=mongo-arbiter.conf                  # 配置文件名
MONGO_ARBITER_DATA_DIR="$MONGO_ARBITER_PATH/db"                          # 数据路径
MONGO_ARBITER_LOG_DIR="$MONGO_ARBITER_PATH/log"                          # 日志路径
MONGO_ARBITER_KEY_FILE_DIR="$MONGO_ARBITER_PATH/mongodb-keyfile"            # 复制集认证文件路径


# 检查参数合法性
if [ $# -ne 1 ]; then
    echo "用法: $0 [install/uninstall]"
    exit 1
fi

## 检查安装目录是否已安装，如果参数为install
if [ "$1" == "install" ]; then
  ssh $SSH_USER@$MONGO_PRIMARY_HOST "if [ -d $MONGO_PRIMARY_INSTALL_DIR ] || [ -d $MONGO_PRIMARY_PATH ]; then echo '1'; else echo '0'; fi"
    if [ $? -eq 1 ]; then
        echo "错误: $MONGO_PRIMARY_INSTALL_DIR 或 $MONGO_PRIMARY_PATH 已存在，请先卸载" >&2
        exit 1
    fi
  ssh $SSH_USER@$MONGO_SECONDARY_HOST "if [ -d $MONGO_SECONDARY_INSTALL_DIR ] || [ -d $MONGO_SECONDARY_PATH ]; then echo '1'; else echo '0'; fi"
  if [ $? -eq 1 ]; then
      echo "错误: $MONGO_SECONDARY_INSTALL_DIR 或 $MONGO_SECONDARY_PATH 已存在，请先卸载" >&2
      exit 1
  fi
  ssh $SSH_USER@$MONGO_ARBITER_HOST "if [ -d $MONGO_ARBITER_INSTALL_DIR ] || [ -d $MONGO_ARBITER_PATH ]; then echo '1'; else echo '0'; fi"
  if [ $? -eq 1 ]; then
      echo "错误: $MONGO_ARBITER_INSTALL_DIR 或 $MONGO_ARBITER_PATH 已存在，请先卸载" >&2
      exit 1
  fi
fi


# 生成初始化的配置，mongo-1.conf,mongo-2.conf,mongo-arbiter.conf
generate_config() {
    rm -f /tmp/$MONGO_PRIMARY_CONFIG_NAME
    cat > /tmp/$MONGO_PRIMARY_CONFIG_NAME << EOF
systemLog:
    destination: file
    path: "$MONGO_PRIMARY_LOG_DIR/mongod.log"                 # 日志文件位置
    logAppend: true                        # 日志开启追加的方式
storage:
    dbPath: "$MONGO_PRIMARY_DATA_DIR"               # 数据存放路径
    journal:
        enabled: true
    directoryPerDB: true
    engine: "wiredTiger"
    wiredTiger:
        engineConfig:
            cacheSizeGB: $MONGO_CACHE_SIZE_GB                       #数据缓存大小
security:
    authorization: disabled                           #是否开启认证，默认 disabled（关闭）
    #clusterAuthMode: "keyFile"
    #keyFile: $MONGO_PRIMARY_KEY_FILE_DIR/access.key              #指定用于副本集或分片集群成员之间认证的秘钥文件路径（开启此项默认开启auth）
replication:
    replSetName: $MONGO_REPLICA_SET_NAME                              #集群名称
    oplogSizeMB: 2048
processManagement:
    fork: true                                  # 是否以守护进程的方式启动，设置为true，通过mongod -f mong.conf启动会释放出终端
net:
    bindIp: 0.0.0.0                             #0.0.0.0全部ip可访问
    #binIpAll: true                              #为bindIp: 0.0.0.0的新配置字段
    port: $MONGO_PRIMARY_PORT                                        # 执行端口
setParameter:
    enableLocalhostAuthBypass: false
EOF
    rm -f /tmp/$MONGO_SECONDARY_CONFIG_NAME
    cat > /tmp/$MONGO_SECONDARY_CONFIG_NAME << EOF
systemLog:
    destination: file
    path: "$MONGO_SECONDARY_LOG_DIR/mongod.log"                 # 日志文件位置
    logAppend: true                        # 日志开启追加的方式
storage:
    dbPath: "$MONGO_SECONDARY_DATA_DIR"               # 数据存放路径
    journal:
        enabled: true
    directoryPerDB: true
    engine: "wiredTiger"
    wiredTiger:
        engineConfig:
            cacheSizeGB: $MONGO_CACHE_SIZE_GB                       #数据缓存大小
security:
    authorization: disabled                           #是否开启认证，默认 disabled（关闭）
    #clusterAuthMode: "keyFile"
    #keyFile: $MONGO_SECONDARY_KEY_FILE_DIR/access.key              #指定用于副本集或分片集群成员之间认证的秘钥文件路径（开启此项默认开启auth）
replication:
    replSetName: $MONGO_REPLICA_SET_NAME                              #集群名称
    oplogSizeMB: 2048
processManagement:
    fork: true                                  # 是否以守护进程的方式启动，设置为true，通过mongod -f mong.conf启动会释放出终端
net:
    bindIp: 0.0.0.0                             #0.0.0.0全部ip可访问
    #binIpAll: true                              #为bindIp: 0.0.0.0的新配置字段
    port: $MONGO_SECONDARY_PORT                                        # 执行端口
setParameter:
    enableLocalhostAuthBypass: false
EOF
    rm -f /tmp/$MONGO_ARBITER_CONFIG_NAME
    cat > /tmp/$MONGO_ARBITER_CONFIG_NAME << EOF
systemLog:
    destination: file
    path: "$MONGO_ARBITER_LOG_DIR/mongod.log"                 # 日志文件位置
    logAppend: true                        # 日志开启追加的方式
storage:
    dbPath: "$MONGO_ARBITER_DATA_DIR"               # 数据存放路径
    journal:
        enabled: true
    directoryPerDB: true
    engine: "wiredTiger"
    wiredTiger:
        engineConfig:
            cacheSizeGB: $MONGO_CACHE_SIZE_GB                       #数据缓存大小
security:
    authorization: disabled                           #是否开启认证，默认 disabled（关闭）
    #clusterAuthMode: "keyFile"
    #keyFile: $MONGO_ARBITER_KEY_FILE_DIR/access.key              #指定用于副本集或分片集群成员之间认证的秘钥文件路径（开启此项默认开启auth）
replication:
    replSetName: $MONGO_REPLICA_SET_NAME                              #集群名称
    oplogSizeMB: 2048
processManagement:
    fork: true                                  # 是否以守护进程的方式启动，设置为true，通过mongod -f mong.conf启动会释放出终端
net:
    bindIp: 0.0.0.0                             #0.0.0.0全部ip可访问
    #binIpAll: true                              #为bindIp: 0.0.0.0的新配置字段
    port: $MONGO_ARBITER_PORT                                        # 执行端口
setParameter:
    enableLocalhostAuthBypass: false
EOF
}

# 创建账号密码后从新生成的配置，mongo-1.conf,mongo-2.conf,mongo-arbiter.conf
generate_new_config() {
    rm -f /tmp/$MONGO_PRIMARY_CONFIG_NAME
    cat > /tmp/$MONGO_PRIMARY_CONFIG_NAME << EOF
systemLog:
    destination: file
    path: "$MONGO_PRIMARY_LOG_DIR/mongod.log"                 # 日志文件位置
    logAppend: true                        # 日志开启追加的方式
storage:
    dbPath: "$MONGO_PRIMARY_DATA_DIR"               # 数据存放路径
    journal:
        enabled: true
    directoryPerDB: true
    engine: "wiredTiger"
    wiredTiger:
        engineConfig:
            cacheSizeGB: $MONGO_CACHE_SIZE_GB                       #数据缓存大小
security:
    authorization: disabled                           #是否开启认证，默认 disabled（关闭）
    clusterAuthMode: "keyFile"
    keyFile: $MONGO_PRIMARY_KEY_FILE_DIR/access.key              #指定用于副本集或分片集群成员之间认证的秘钥文件路径（开启此项默认开启auth）
replication:
    replSetName: $MONGO_REPLICA_SET_NAME                              #集群名称
    oplogSizeMB: 2048
processManagement:
    fork: true                                  # 是否以守护进程的方式启动，设置为true，通过mongod -f mong.conf启动会释放出终端
net:
    bindIp: 0.0.0.0                             #0.0.0.0全部ip可访问
    #binIpAll: true                              #为bindIp: 0.0.0.0的新配置字段
    port: $MONGO_PRIMARY_PORT                                        # 执行端口
setParameter:
    enableLocalhostAuthBypass: false
EOF
    rm -f /tmp/$MONGO_SECONDARY_CONFIG_NAME
    cat > /tmp/$MONGO_SECONDARY_CONFIG_NAME << EOF
systemLog:
    destination: file
    path: "$MONGO_SECONDARY_LOG_DIR/mongod.log"                 # 日志文件位置
    logAppend: true                        # 日志开启追加的方式
storage:
    dbPath: "$MONGO_SECONDARY_DATA_DIR"               # 数据存放路径
    journal:
        enabled: true
    directoryPerDB: true
    engine: "wiredTiger"
    wiredTiger:
        engineConfig:
            cacheSizeGB: $MONGO_CACHE_SIZE_GB                       #数据缓存大小
security:
    authorization: disabled                           #是否开启认证，默认 disabled（关闭）
    clusterAuthMode: "keyFile"
    keyFile: $MONGO_SECONDARY_KEY_FILE_DIR/access.key              #指定用于副本集或分片集群成员之间认证的秘钥文件路径（开启此项默认开启auth）
replication:
    replSetName: $MONGO_REPLICA_SET_NAME                              #集群名称
    oplogSizeMB: 2048
processManagement:
    fork: true                                  # 是否以守护进程的方式启动，设置为true，通过mongod -f mong.conf启动会释放出终端
net:
    bindIp: 0.0.0.0                             #0.0.0.0全部ip可访问
    #binIpAll: true                              #为bindIp: 0.0.0.0的新配置字段
    port: $MONGO_SECONDARY_PORT                                        # 执行端口
setParameter:
    enableLocalhostAuthBypass: false
EOF
    rm -f /tmp/$MONGO_ARBITER_CONFIG_NAME
    cat > /tmp/$MONGO_ARBITER_CONFIG_NAME << EOF
systemLog:
    destination: file
    path: "$MONGO_ARBITER_LOG_DIR/mongod.log"                 # 日志文件位置
    logAppend: true                        # 日志开启追加的方式
storage:
    dbPath: "$MONGO_ARBITER_DATA_DIR"               # 数据存放路径
    journal:
        enabled: true
    directoryPerDB: true
    engine: "wiredTiger"
    wiredTiger:
        engineConfig:
            cacheSizeGB: $MONGO_CACHE_SIZE_GB                       #数据缓存大小
security:
    authorization: disabled                           #是否开启认证，默认 disabled（关闭）
    clusterAuthMode: "keyFile"
    keyFile: $MONGO_ARBITER_KEY_FILE_DIR/access.key              #指定用于副本集或分片集群成员之间认证的秘钥文件路径（开启此项默认开启auth）
replication:
    replSetName: $MONGO_REPLICA_SET_NAME                              #集群名称
    oplogSizeMB: 2048
processManagement:
    fork: true                                  # 是否以守护进程的方式启动，设置为true，通过mongod -f mong.conf启动会释放出终端
net:
    bindIp: 0.0.0.0                             #0.0.0.0全部ip可访问
    #binIpAll: true                              #为bindIp: 0.0.0.0的新配置字段
    port: $MONGO_ARBITER_PORT                                        # 执行端口
setParameter:
    enableLocalhostAuthBypass: false
EOF
}


# 初始化安装
init_install() {
  echo "------------- 1. 开始初始化安装 -------------"
    # 本地校验
    if [ ! -f "$MONGO_TAR" ]; then
        echo "错误: 找不到mongodb安装包 $MONGO_TAR"
        exit 1
    fi
    # 生成配置文件
    echo "生成初始化的配置"
    generate_config
    echo "分发配置和安装包"
    # 上传安装包和配置文件到各个节点
    scp $MONGO_TAR /tmp/$MONGO_PRIMARY_CONFIG_NAME $SSH_USER@$MONGO_PRIMARY_HOST:/tmp/
    scp $MONGO_TAR /tmp/$MONGO_SECONDARY_CONFIG_NAME $SSH_USER@$MONGO_SECONDARY_HOST:/tmp/
    scp $MONGO_TAR /tmp/$MONGO_ARBITER_CONFIG_NAME $SSH_USER@$MONGO_ARBITER_HOST:/tmp/
    # 主节点部署
    echo "主节点部署启动"
    ssh -T $SSH_USER@$MONGO_PRIMARY_HOST << EOF
set -e
# 创建数据目录
mkdir -p $MONGO_PRIMARY_INSTALL_DIR $MONGO_PRIMARY_DATA_DIR $MONGO_PRIMARY_LOG_DIR $MONGO_PRIMARY_KEY_FILE_DIR
# 解压安装
tar -xzf /tmp/$MONGO_TAR -C /tmp/
cp -r /tmp/$MONGO_TAR_BASENAME/* $MONGO_PRIMARY_INSTALL_DIR
# 复制配置文件
cp /tmp/$MONGO_PRIMARY_CONFIG_NAME $MONGO_PRIMARY_INSTALL_DIR
# 启动mongodb
$MONGO_PRIMARY_INSTALL_DIR/bin/mongod -f $MONGO_PRIMARY_INSTALL_DIR/$MONGO_PRIMARY_CONFIG_NAME
EOF
    # 从节点部署
    echo "从节点部署启动"
    ssh -T $SSH_USER@$MONGO_SECONDARY_HOST << EOF
set -e
# 创建数据目录
mkdir -p $MONGO_SECONDARY_INSTALL_DIR $MONGO_SECONDARY_DATA_DIR $MONGO_SECONDARY_LOG_DIR $MONGO_SECONDARY_KEY_FILE_DIR
# 解压安装
tar -xzf /tmp/$MONGO_TAR -C /tmp/
cp -r /tmp/$MONGO_TAR_BASENAME/* $MONGO_SECONDARY_INSTALL_DIR
# 复制配置文件
cp /tmp/$MONGO_SECONDARY_CONFIG_NAME $MONGO_SECONDARY_INSTALL_DIR
# 启动mongodb
$MONGO_SECONDARY_INSTALL_DIR/bin/mongod -f $MONGO_SECONDARY_INSTALL_DIR/$MONGO_SECONDARY_CONFIG_NAME
EOF
    # 仲裁节点部署
    echo "仲裁节点部署启动"
    ssh -T $SSH_USER@$MONGO_ARBITER_HOST << EOF
set -e
# 创建数据目录
mkdir -p $MONGO_ARBITER_INSTALL_DIR $MONGO_ARBITER_DATA_DIR $MONGO_ARBITER_LOG_DIR $MONGO_ARBITER_KEY_FILE_DIR
# 解压安装
tar -xzf /tmp/$MONGO_TAR -C /tmp/
cp -r /tmp/$MONGO_TAR_BASENAME/* $MONGO_ARBITER_INSTALL_DIR
# 复制配置文件
cp /tmp/$MONGO_ARBITER_CONFIG_NAME $MONGO_ARBITER_INSTALL_DIR
# 启动mongodb
$MONGO_ARBITER_INSTALL_DIR/bin/mongod -f $MONGO_ARBITER_INSTALL_DIR/$MONGO_ARBITER_CONFIG_NAME
EOF
    # 等待10s
    echo "请稍等10秒"
    sleep 10
    echo "mongo复制集各个节点启动完成！"
}


# 初始化集群命令
init_cluster() {
    echo "------------- 2. 开始初始化集群 -------------"
    # 主节点初始化
    ssh -T $SSH_USER@$MONGO_PRIMARY_HOST << EOF
set -e
# 初始化集群
$MONGO_PRIMARY_INSTALL_DIR/bin/mongo --host $MONGO_PRIMARY_HOST --port $MONGO_PRIMARY_PORT --eval "rs.initiate({ _id: '$MONGO_REPLICA_SET_NAME', members: [ { _id: 0, host: '$MONGO_PRIMARY_HOST:$MONGO_PRIMARY_PORT','priority': 2 }, { _id: 1, host: '$MONGO_SECONDARY_HOST:$MONGO_SECONDARY_PORT','priority': 1}, { _id: 2, host: '$MONGO_ARBITER_HOST:$MONGO_ARBITER_PORT', arbiterOnly: true } ] })"
EOF
    echo "请稍等60秒,等待复制集完全初始化"
    sleep 60
    echo "mongo复制集初始化完成！"
    echo "查看mongo rs.status()信息"
    $MONGO_PRIMARY_INSTALL_DIR/bin/mongo --host $MONGO_PRIMARY_HOST --port $MONGO_PRIMARY_PORT --eval "rs.status()"
}
# 设置账号密码
set_auth() {
    echo "------------- 3. 开始设置账号密码 -------------"
    echo "mongo复制集设置账号密码开始"
    ssh -T $SSH_USER@$MONGO_PRIMARY_HOST << EOF
set -e
# 切换到admin库：use admin; 创建用户
$MONGO_PRIMARY_INSTALL_DIR/bin/mongo --host $MONGO_PRIMARY_HOST --port $MONGO_PRIMARY_PORT --authenticationDatabase admin --eval "db.getSiblingDB('admin').createUser({user: '$MONGO_USER', pwd: '$MONGO_PASSWORD', roles: [{role: 'root', db: 'admin'}]})"
EOF
    echo "mongo复制集设置账号密码完成！"
    # 创建认证文件
    echo "创建认证文件"
    ssh -T $SSH_USER@$MONGO_PRIMARY_HOST << EOF
set -e
# 创建命令：
openssl rand -base64 666 > $MONGO_PRIMARY_KEY_FILE_DIR/access.key
# 赋予可读的权限：
chmod 600 $MONGO_PRIMARY_KEY_FILE_DIR/access.key
scp -r $MONGO_PRIMARY_KEY_FILE_DIR/access.key $SSH_USER@$MONGO_SECONDARY_HOST:$MONGO_SECONDARY_KEY_FILE_DIR
scp -r $MONGO_PRIMARY_KEY_FILE_DIR/access.key $SSH_USER@$MONGO_ARBITER_HOST:$MONGO_ARBITER_KEY_FILE_DIR
EOF
   echo "创建认证文件完成"
}
# 替换新配置
replace_config() {
    echo "------------- 4. 开始替换配置文件 -------------"
  echo "mongo复制集配置文件替换开始"
  generate_new_config
  # 覆盖替换配置文件
  scp /tmp/$MONGO_PRIMARY_CONFIG_NAME $SSH_USER@$MONGO_PRIMARY_HOST:$MONGO_PRIMARY_INSTALL_DIR
  scp /tmp/$MONGO_SECONDARY_CONFIG_NAME $SSH_USER@$MONGO_SECONDARY_HOST:$MONGO_SECONDARY_INSTALL_DIR
  scp /tmp/$MONGO_ARBITER_CONFIG_NAME $SSH_USER@$MONGO_ARBITER_HOST:$MONGO_ARBITER_INSTALL_DIR
  echo "mongo复制集配置文件替换完成！"
}

# 重启mongo
restart_mongo() {
  echo "------------- 5. 开始重启mongo -------------"
  echo "mongo复制集重启开始"
  ssh -T $SSH_USER@$MONGO_PRIMARY_HOST << EOF
set -e
$MONGO_PRIMARY_INSTALL_DIR/bin/mongod --config $MONGO_PRIMARY_INSTALL_DIR/$MONGO_PRIMARY_CONFIG_NAME --shutdown
$MONGO_PRIMARY_INSTALL_DIR/bin/mongod --config $MONGO_PRIMARY_INSTALL_DIR/$MONGO_PRIMARY_CONFIG_NAME
EOF
  ssh -T $SSH_USER@$MONGO_SECONDARY_HOST << EOF
set -e
$MONGO_SECONDARY_INSTALL_DIR/bin/mongod --config $MONGO_SECONDARY_INSTALL_DIR/$MONGO_SECONDARY_CONFIG_NAME --shutdown
$MONGO_SECONDARY_INSTALL_DIR/bin/mongod --config $MONGO_SECONDARY_INSTALL_DIR/$MONGO_SECONDARY_CONFIG_NAME
EOF
  ssh -T $SSH_USER@$MONGO_ARBITER_HOST << EOF
set -e
$MONGO_ARBITER_INSTALL_DIR/bin/mongod --config $MONGO_ARBITER_INSTALL_DIR/$MONGO_ARBITER_CONFIG_NAME --shutdown
$MONGO_ARBITER_INSTALL_DIR/bin/mongod --config $MONGO_ARBITER_INSTALL_DIR/$MONGO_ARBITER_CONFIG_NAME
EOF
  echo "mongo重启完成！"
}

# 安装集群
install_cluster() {
  echo "开始安装mongo集群！"
  init_install
  init_cluster
  set_auth
  replace_config
  restart_mongo
  echo "mongo集群安装完成！"
}

remote_exec() {
    local node=$1
    local cmd=$2
    echo -e "\n>>> 在节点 $node 执行: $cmd"
    ssh -T $SSH_USER@$node <<< "$cmd"
    if [ $? -ne 0 ]; then
        echo "!!! 节点 $node 执行失败"
        return 1
    else
        echo "!!! 节点 $node 执行成功"
	  fi
}

# 卸载集群
uninstall_cluster() {
    echo "mongo集群开始卸载"
    remote_exec $MONGO_PRIMARY_HOST "rm -rf $MONGO_PRIMARY_INSTALL_DIR $MONGO_PRIMARY_PATH"
    remote_exec $MONGO_SECONDARY_HOST "rm -rf $MONGO_SECONDARY_INSTALL_DIR $MONGO_SECONDARY_PATH"
    remote_exec $MONGO_ARBITER_HOST "rm -rf $MONGO_ARBITER_INSTALL_DIR $MONGO_ARBITER_PATH"
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
