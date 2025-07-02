#!/bin/bash
set -e

echo "🚀 构建 Next.js Standalone 模式部署包..."

# Azure App Service 配置
RESOURCE_GROUP="cn-hb3-networktest-rg"
WEBAPP_NAME="cn-hb3-sndbx-networktest-wapp-01"

# 处理命令行参数
DEPLOY_TO_AZURE=false
TEST_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --deploy)
            DEPLOY_TO_AZURE=true
            shift
            ;;
        --test)
            TEST_MODE=true
            shift
            ;;
        --help)
            echo "🚀 Next.js Standalone 构建和部署工具"
            echo ""
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  --deploy    构建完成后自动部署到 Azure App Service"
            echo "  --test      仅构建和创建部署包，不部署"
            echo "  --help      显示此帮助信息"
            echo ""
            echo "使用示例:"
            echo "  $0                    # 仅构建本地部署包"
            echo "  $0 --test            # 测试构建，创建 app.zip"
            echo "  $0 --deploy          # 构建并自动部署到 Azure"
            echo ""
            echo "Azure 配置:"
            echo "  资源组: $RESOURCE_GROUP"
            echo "  Web App: $WEBAPP_NAME"
            echo ""
            echo "注意事项:"
            echo "  - 使用 --deploy 前请确保已登录 Azure CLI"
            echo "  - Standalone 模式构建包含所有依赖，无需在服务器安装"
            echo "  - 构建输出为 app.zip，可手动部署到任何支持 Node.js 的服务器"
            exit 0
            ;;
        *)
            echo "未知选项: $1"
            echo "使用 --help 查看可用选项"
            exit 1
            ;;
    esac
done

if [ "$DEPLOY_TO_AZURE" = "true" ]; then
    echo "🔵 模式: 构建并部署到 Azure"
elif [ "$TEST_MODE" = "true" ]; then
    echo "🧪 模式: 仅构建测试"
else
    echo "📦 模式: 仅构建本地包"
fi
echo ""

# 清理之前的构建和部署包
echo "🧹 清理之前的构建..."
rm -rf .next
rm -f app.zip

# 检查 Node.js 版本
echo "📋 检查环境..."
echo "Node.js 版本: $(node --version)"
echo "npm 版本: $(npm --version)"

# 安装依赖（如果需要）
if [ ! -d "node_modules" ]; then
    echo "📦 安装依赖..."
    npm ci
else
    echo "✅ 依赖已存在"
fi

# 构建应用
echo "🔨 构建 Next.js 应用（Standalone 模式）..."
npm run build

# 验证 standalone 构建是否成功
if [ ! -d ".next/standalone" ]; then
    echo "❌ 错误: Standalone 构建失败，.next/standalone 目录不存在"
    echo "请检查 next.config.ts 中是否配置了 output: 'standalone'"
    exit 1
fi

if [ ! -f ".next/standalone/server.js" ]; then
    echo "❌ 错误: server.js 文件不存在"
    exit 1
fi

echo "✅ Standalone 构建成功"

# 创建临时目录用于打包
TEMP_DIR=$(mktemp -d)
echo "📁 创建临时目录: $TEMP_DIR"

# 1. 复制 standalone 应用到根目录
echo "📋 复制 standalone 应用文件到根目录..."
cp -r .next/standalone/* $TEMP_DIR/

# 2. 复制静态文件
echo "📋 复制静态文件..."
if [ -d ".next/static" ]; then
    mkdir -p $TEMP_DIR/.next/static
    cp -r .next/static/* $TEMP_DIR/.next/static/
    echo "✅ 静态文件复制完成"
else
    echo "⚠️  .next/static 目录不存在"
fi

# 3. 复制必要的构建文件
echo "📋 复制必要的构建文件..."
# 复制 build-id 文件（Next.js 需要）
if [ -f ".next/BUILD_ID" ]; then
    mkdir -p $TEMP_DIR/.next
    cp .next/BUILD_ID $TEMP_DIR/.next/
    echo "✅ BUILD_ID 文件复制完成"
fi

# 复制其他必要的构建文件
for file in .next/app-build-manifest.json .next/build-manifest.json .next/prerender-manifest.json .next/routes-manifest.json; do
    if [ -f "$file" ]; then
        mkdir -p $TEMP_DIR/.next
        cp "$file" "$TEMP_DIR/.next/"
        echo "✅ $(basename $file) 复制完成"
    fi
done

# 3. 复制 public 文件（如果存在）
if [ -d "public" ]; then
    echo "📋 复制 public 目录..."
    cp -r public $TEMP_DIR/
    echo "✅ public 目录复制完成"
else
    echo "⚠️  public 目录不存在"
fi

# 4. 创建启动脚本（用于本地测试，Azure 不使用）
echo "📋 创建启动脚本..."
cat > $TEMP_DIR/start.sh << 'EOF'
echo "🚀 启动 Next.js Standalone 应用..."

# 自动检测运行环境
if [ -n "$WEBSITES_PORT" ]; then
    # Azure App Service 环境
    export PORT=${WEBSITES_PORT}
    export HOSTNAME=0.0.0.0
    echo "🔵 检测到 Azure App Service 环境"
    echo "端口: $PORT (来自 WEBSITES_PORT)"
else
    # 本地或其他环境
    export PORT=${PORT:-3000}
    export HOSTNAME=${HOSTNAME:-0.0.0.0}
    echo "🏠 本地部署环境"
    echo "端口: $PORT"
fi

echo "主机: $HOSTNAME"
echo "工作目录: $(pwd)"
echo "Node.js 版本: $(node --version)"

# 检查必需文件
if [ ! -f "server.js" ]; then
    echo "❌ 错误: server.js 文件不存在"
    exit 1
fi

echo "文件列表:"
ls -la

echo "启动 server.js..."
exec node server.js
EOF

# 注意：在 Azure App Service 中，我们直接使用 "node server.js" 作为启动命令
# start.sh 脚本主要用于本地测试，Azure 不依赖此脚本的执行权限

# 5. 创建 package.json（简化版，仅用于运行时）
echo "📋 创建运行时 package.json..."
cat > $TEMP_DIR/package.json << EOF
{
  "name": "netfasttest-standalone",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "start": "node server.js"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
EOF

# 6. 验证部署包完整性
echo "🔍 验证部署包完整性..."

# 检查必需文件
REQUIRED_FILES=("server.js" "package.json" "start.sh")
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$TEMP_DIR/$file" ]; then
        echo "  ✅ $file 存在"
    else
        echo "  ❌ $file 缺失"
        exit 1
    fi
done

# 检查目录结构
echo "📂 目录结构:"
echo "根目录文件:"
ls -la $TEMP_DIR/
echo ""
echo ".next 目录:"
if [ -d "$TEMP_DIR/.next" ]; then
    ls -la $TEMP_DIR/.next/
else
    echo "  .next 目录不存在"
fi

# 7. 创建部署包
echo "📦 创建部署包 app.zip..."
cd $TEMP_DIR
zip -r ../app.zip . -x "*.DS_Store*" "*.git*"
cd - > /dev/null

# 移动到当前目录
mv $TEMP_DIR/../app.zip ./app.zip

# 清理临时目录
rm -rf $TEMP_DIR

# 8. 显示部署包信息
echo "✅ 部署包创建完成!"
echo "📊 部署包信息:"
echo "  文件名: app.zip"
echo "  大小: $(du -h app.zip | cut -f1)"
echo "  路径: $(pwd)/app.zip"

# 9. Azure 部署（如果启用）
if [ "$DEPLOY_TO_AZURE" = "true" ]; then
    echo ""
    echo "� 开始部署到 Azure App Service..."
    
    # 检查 Azure CLI
    if ! command -v az >/dev/null 2>&1; then
        echo "❌ 错误: Azure CLI 未安装"
        echo "请安装 Azure CLI: https://docs.microsoft.com/cli/azure/install-azure-cli"
        exit 1
    fi
    
    # 检查 Azure 登录状态
    if ! az account show >/dev/null 2>&1; then
        echo "❌ 错误: 未登录 Azure"
        echo "请运行: az login"
        exit 1
    fi
    
    echo "检查 Azure 权限和资源..."
    if ! az webapp show --name $WEBAPP_NAME --resource-group $RESOURCE_GROUP --output none 2>/dev/null; then
        echo "❌ 错误: 无法访问 Web App '$WEBAPP_NAME'，请检查："
        echo "  1. 资源是否存在"
        echo "  2. 您是否有足够的权限"
        echo "  3. 是否登录到正确的订阅"
        exit 1
    fi
    
    # 配置 Azure App Service 用于 Standalone 模式
    echo "配置 Azure App Service..."
    az webapp config appsettings set \
      --resource-group $RESOURCE_GROUP \
      --name $WEBAPP_NAME \
      --settings \
        PORT=8080 \
        WEBSITES_PORT=8080 \
        HOSTNAME=0.0.0.0 \
        WEBSITE_NODE_DEFAULT_VERSION=20.x \
        NPM_CONFIG_PRODUCTION=false \
      --output none
    
    # 设置启动命令为 Standalone 模式
    echo "设置启动命令..."
    az webapp config set \
      --resource-group $RESOURCE_GROUP \
      --name $WEBAPP_NAME \
      --startup-file "node server.js" \
      --output none
    
    # 部署到 Azure（带重试机制）
    echo "部署到 Azure..."
    echo "部署包大小: $(ls -lah app.zip | awk '{print $6}')"
    
    DEPLOY_RETRIES=3
    DEPLOY_SUCCESS=false
    
    for i in $(seq 1 $DEPLOY_RETRIES); do
        echo "尝试部署 ($i/$DEPLOY_RETRIES)..."
        
        if az webapp deploy \
            --resource-group $RESOURCE_GROUP \
            --name $WEBAPP_NAME \
            --src-path app.zip \
            --type zip \
            --timeout 600; then
            echo "✅ 部署成功！"
            DEPLOY_SUCCESS=true
            break
        else
            echo "❌ 部署失败 (尝试 $i/$DEPLOY_RETRIES)"
            if [ $i -lt $DEPLOY_RETRIES ]; then
                echo "等待 30 秒后重试..."
                sleep 30
            fi
        fi
    done
    
    if [ "$DEPLOY_SUCCESS" = "false" ]; then
        echo "❌ 部署最终失败，已重试 $DEPLOY_RETRIES 次"
        echo "请检查网络连接或稍后重试"
        exit 1
    fi
    
    # 重启应用
    echo "重启应用..."
    if az webapp restart \
      --resource-group $RESOURCE_GROUP \
      --name $WEBAPP_NAME \
      --output none; then
        echo "✅ 应用重启成功"
    else
        echo "⚠️  应用重启可能失败，但部署已完成"
    fi
    
    # 等待应用启动
    echo "等待应用启动..."
    sleep 15
    
    # 获取访问地址和健康检查
    echo "获取访问地址..."
    WEBAPP_URL=$(az webapp show \
      --name $WEBAPP_NAME \
      --resource-group $RESOURCE_GROUP \
      --query defaultHostName \
      --output tsv 2>/dev/null)
    
    if [ -n "$WEBAPP_URL" ]; then
        echo "🌐 访问地址: https://$WEBAPP_URL"
        
        # 健康检查
        echo "进行健康检查..."
        if curl -f -s --max-time 30 "https://$WEBAPP_URL" > /dev/null; then
            echo "✅ 应用响应正常"
        else
            echo "⚠️  应用可能仍在启动中，请稍后访问"
        fi
    else
        echo "⚠️  无法获取访问地址，但部署可能已成功"
    fi
    
    echo ""
    echo "🎉 Azure 部署完成！"
    echo "📝 查看日志: az webapp log tail --name $WEBAPP_NAME --resource-group $RESOURCE_GROUP"
    
    # 清理部署包（可选）
    echo ""
    read -p "🗑️  是否删除本地部署包 app.zip? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f app.zip
        echo "✅ 部署包已清理"
    else
        echo "📦 部署包保留为: $(pwd)/app.zip"
    fi
    
elif [ "$TEST_MODE" = "true" ]; then
    echo ""
    echo "🧪 测试模式完成，部署包已创建为 app.zip"
    echo "可以手动检查包内容: unzip -l app.zip"
    echo "要部署到 Azure，请运行: ./build-standalone.sh --deploy"
    
else
    echo ""
    echo "🚀 本地构建完成！"
    echo ""
    echo "📋 部署选项:"
    echo "1. 手动部署:"
    echo "   - 上传 app.zip 到目标服务器"
    echo "   - 解压到应用目录"
    echo "   - 运行: ./start.sh 或 node server.js"
    echo ""
    echo "2. Azure 自动部署:"
    echo "   ./build-standalone.sh --deploy"
    echo ""
    echo "3. 测试构建包:"
    echo "   ./build-standalone.sh --test"
fi

echo ""
echo "📝 Standalone 模式说明:"
echo "- 服务器需要 Node.js 18+ 环境"
echo "- 无需安装额外依赖，standalone 模式已包含所有必需文件"
echo "- 默认端口为 3000，Azure App Service 中为 8080"
echo "- 本地启动: ./start.sh 或 node server.js"
echo "- Azure 启动: 自动使用 node server.js（由 Azure App Service 配置）"
