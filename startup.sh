#!/bin/bash

# Azure App Service 启动脚本
echo "=== Azure App Service 启动 ==="

# 设置环境变量
export PORT=${PORT:-8080}
export NODE_ENV=production
export PATH="/home/site/wwwroot/node_modules/.bin:$PATH"

echo "端口: $PORT, 环境: $NODE_ENV"

# 检查 node_modules 状态
echo "=== 检查依赖状态 ==="
if [ -d "node_modules" ]; then
    echo "✅ node_modules 目录存在"
    
    if [ -f "node_modules/.bin/next" ]; then
        echo "✅ Next.js 可执行文件存在"
    else
        echo "⚠️  Next.js 可执行文件缺失，尝试修复..."
        npm install next --no-save
    fi
    
    # 检查关键依赖
    if [ -d "node_modules/react" ] && [ -d "node_modules/react-dom" ]; then
        echo "✅ React 依赖正常"
    else
        echo "⚠️  React 依赖缺失，补充安装..."
        npm install react react-dom --no-save
    fi
else
    echo "❌ node_modules 目录不存在，完整安装依赖..."
    npm install --omit=dev
fi

# 构建应用（如果需要）
if [ ! -d ".next" ]; then
    echo "构建应用..."
    ./node_modules/.bin/next build || npm run build
fi

# 使用 standalone 模式启动
if [ -f ".next/standalone/server.js" ]; then
    echo "使用 standalone 模式启动..."
    exec node .next/standalone/server.js
else
    echo "使用传统模式启动..."
    exec ./node_modules/.bin/next start
fi