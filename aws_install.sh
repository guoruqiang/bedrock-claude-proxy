#!/bin/bash

# 检查 Docker 是否已安装
if ! command -v docker &> /dev/null; then
    echo "Docker 未安装。正在安装 Docker..."
    # 更新 apt 软件包索引
    sudo apt update
    # 安装必要的软件包
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
    # 添加 Docker 的官方 GPG 密钥
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/docker.gpg
    # 添加 Docker 的稳定版存储库
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    # 再次更新 apt 软件包索引
    sudo apt update
    # 安装 Docker
    sudo apt install -y docker-ce
    # 启动 Docker 服务并将其设置为在系统引导时启动
    sudo systemctl start docker
    sudo systemctl enable docker
else
    echo "Docker 已安装。"
fi

# 检查 Docker Compose 是否已安装
if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose 未安装。正在安装 Docker Compose..."
    # 下载最新的 Docker Compose 发行版
    DOCKER_COMPOSE_VERSION="v2.24.6"
    sudo curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    # 授予可执行权限
    sudo chmod +x /usr/local/bin/docker-compose
    # 创建一个指向可执行文件的符号链接
    sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
else
    echo "Docker Compose 已安装。"
fi

# 验证安装
sudo docker --version
sudo docker-compose --version

# 检查是否为 root 用户
if [ "$EUID" -eq 0 ]; then
    TARGET_DIR="/root/bedrock-claude-proxy"
else
    USER=$(whoami)
    HOME_DIR=$(eval echo ~$USER)
    TARGET_DIR="$HOME_DIR/bedrock-claude-proxy"
fi

# 确保目录存在
sudo mkdir -p $TARGET_DIR

# 删除旧的 docker-compose.yml 文件（如果存在）
sudo rm -f $TARGET_DIR/docker-compose.yml

# 提示用户输入环境变量
read -p "API_KEY: 填写调用所用的 API-Key 自己随便设置: " API_KEY
read -p "AWS_BEDROCK_ACCESS_KEY: " AWS_BEDROCK_ACCESS_KEY
read -p "AWS_BEDROCK_SECRET_KEY: " AWS_BEDROCK_SECRET_KEY
read -p "AWS_BEDROCK_REGION (默认 us-east-1): " AWS_BEDROCK_REGION
AWS_BEDROCK_REGION=${AWS_BEDROCK_REGION:-us-east-1}
read -p "AWS_BEDROCK_MODEL_MAPPINGS: " AWS_BEDROCK_MODEL_MAPPINGS

# 创建新的 docker-compose.yml 文件
sudo bash -c "cat <<EOF > $TARGET_DIR/docker-compose.yml
version: '3'
services:
  bedrock-claude-proxy:
    image: \"mmhk/bedrock-claude-proxy\"
    restart: always
    environment:
      API_KEY: \"$API_KEY\"
      AWS_BEDROCK_ACCESS_KEY: \"$AWS_BEDROCK_ACCESS_KEY\"
      AWS_BEDROCK_SECRET_KEY: \"$AWS_BEDROCK_SECRET_KEY\"
      AWS_BEDROCK_REGION: \"$AWS_BEDROCK_REGION\"
      AWS_BEDROCK_MODEL_MAPPINGS: \"$AWS_BEDROCK_MODEL_MAPPINGS\"
    ports:
      - \"3100:3000\"
EOF"

# 检查服务是否正在运行
if sudo docker ps --format '{{.Names}}' | grep -q 'bedrock-claude-proxy'; then
    echo "服务 bedrock-claude-proxy 已存在，正在停止并移除..."
    cd $TARGET_DIR
    sudo docker-compose down
fi

# 进入目录并运行 docker-compose 命令
cd $TARGET_DIR
sudo docker-compose pull
sudo docker-compose up -d

echo "Docker 和 Docker Compose 已成功安装并配置。服务已启动。"
