# mongo复制集一键部署脚本
    脚本名：install-mongodb-replica-set.sh
    这是一个1主1从1仲裁的一键部署脚本
## 使用方法
    1. 将mongodb-replica-set.shell目录上传到服务器
    2. 主要修改install-mongodb-replica-set.sh中的如下配置：
        MONGO_USER=mongo                    # mongodb用户名
        MONGO_PASSWORD=mongo@123            # mongodb密码
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
    3.执行安装
        bash install-mongodb-replica-set.sh install
