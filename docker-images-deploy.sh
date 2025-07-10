#!/bin/bash
# 构建并推送 Docker 镜像到阿里云镜像中心
# 使用方法: ./build-and-push.sh [版本标签]

# 配置信息
REGISTRY_URL="registry.cn-hangzhou.aliyuncs.com"  # 阿里云镜像中心地址
NAMESPACE="xmark"  # 阿里云命名空间
IMAGE_NAME="codeup"  # 镜像名称
if [ -z "$1" ]; then
  VERSION=$(node -p "require('./package.json').version")
else
  VERSION="$1"
fi

# 完整的镜像标签
IMAGE_TAG="${REGISTRY_URL}/${NAMESPACE}/${IMAGE_NAME}:${VERSION}"

echo "===== 开始构建 Docker 镜像 ====="
echo "镜像标签: ${IMAGE_TAG}"

# 构建 Docker 镜像
docker build -t ${IMAGE_TAG} .

# 检查构建是否成功
if [ $? -ne 0 ]; then
    echo "❌ 镜像构建失败"
    exit 1
fi

echo "✅ 镜像构建成功: ${IMAGE_TAG}"

# 登录到阿里云镜像服务
echo "===== 登录阿里云镜像服务 ====="
echo "请输入阿里云镜像仓库的密码:"
read -s PASSWORD

docker login --username Renyiau --password ${PASSWORD} ${REGISTRY_URL}

# 检查登录是否成功
if [ $? -ne 0 ]; then
    echo "❌ 阿里云镜像服务登录失败"
    exit 1
fi

echo "✅ 阿里云镜像服务登录成功"

# 推送镜像到阿里云
echo "===== 开始推送镜像到阿里云 ====="
docker push ${IMAGE_TAG}

# 检查推送是否成功
if [ $? -ne 0 ]; then
    echo "❌ 镜像推送失败"
    exit 1
fi

echo "✅ 镜像推送成功: ${IMAGE_TAG}"

# 设置镜像版本号到应用版本文件中
echo "✅ 版本号已更新到 ${VERSION}: ${VERSION}"

echo "===== 构建和推送过程完成 ====="
echo "镜像地址: ${IMAGE_TAG}"
echo "命令示例: docker pull ${IMAGE_TAG}"

# 显示当前版本信息
echo ""
echo "当前应用版本信息:"
echo "名称: netfasttest"
echo "版本: ${VERSION}"
echo "构建时间: $(date '+%Y-%m-%d %H:%M:%S')"
