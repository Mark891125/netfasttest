#!/bin/bash

# Azure App Service 简化启动脚本
echo "=== Azure App Service 启动 ==="

# 设置环境变量
export PORT=${PORT:-8080}
export NODE_ENV=production
export PATH="/home/site/wwwroot/node_modules/.bin:$PATH"

echo "端口: $PORT, 环境: $NODE_ENV"

# 强制安装 Next.js（如果缺失）
if [ ! -f "node_modules/.bin/next" ]; then
    echo "安装 Next.js..."
    npm install next --save
fi

# 安装所有依赖（确保完整）
echo "确保依赖完整安装..."
npm install --omit=dev

# 构建应用（如果需要）
if [ ! -d ".next" ]; then
    echo "构建应用..."
    ./node_modules/.bin/next build || npm run build
fi

# 启动应用
echo "启动应用..."
exec ./node_modules/.bin/next start
