#!/bin/bash
set -e

echo "快速部署 Next.js 应用到 Azure App Service..."

RESOURCE_GROUP="cn-hb3-networktest-rg"
WEBAPP_NAME="cn-hb3-sndbx-networktest-wapp-01"

# 简化参数处理
if [ "$1" = "--test" ]; then
    echo "🧪 测试模式：仅创建和验证部署包，不实际部署"
    TEST_MODE=true
else
    TEST_MODE=false
fi

# 0. 预检查和本地构建（如果需要）
echo "=== 预检查和准备 ==="

# # 确保 node_modules 存在
# if [ ! -d "node_modules" ]; then
#     echo "📦 node_modules 不存在，开始安装依赖..."
#     if command -v bun >/dev/null 2>&1; then
#         echo "使用 bun 安装依赖..."
#         bun install
#     else
#         echo "使用 npm 安装依赖..."
#         npm install
#     fi
# fi

# 确保应用已构建
if [ ! -d ".next" ]; then
    echo "🔨 .next 目录不存在，开始构建..."
    if command -v bun >/dev/null 2>&1; then
        echo "使用 bun 构建..."
        bun run build
    else
        echo "使用 npm 构建..."
        npm run build
    fi
fi

# 1. 检查权限和资源
echo "检查 Azure 权限和资源..."
if ! az webapp show --name $WEBAPP_NAME --resource-group $RESOURCE_GROUP --output none 2>/dev/null; then
    echo "❌ 错误: 无法访问 Web App '$WEBAPP_NAME'，请检查："
    echo "  1. 资源是否存在"
    echo "  2. 您是否有足够的权限"
    echo "  3. 是否登录到正确的订阅"
    exit 1
fi

# 清理之前的部署包（如果存在）
if [ -f "app.zip" ]; then
    echo "🗑️  清理之前的部署包..."
    rm -f app.zip
fi

# 2. 创建部署包
echo "打包部署文件..."

# 创建临时目录
TEMP_DIR=$(mktemp -d)
echo "临时目录: $TEMP_DIR"

# 复制必需文件
echo "复制项目文件..."

# 1. 检查和复制核心源文件
echo "=== 检查核心文件 ==="

# 检查 app 目录
if [ ! -d "app" ]; then
    echo "❌ 错误: app 目录不存在"
    exit 1
fi
echo "✅ app 目录存在"

# 检查 public 目录
if [ ! -d "public" ]; then
    echo "❌ 错误: public 目录不存在"
    exit 1
fi
echo "✅ public 目录存在"

# 检查 package.json
if [ ! -f "package.json" ]; then
    echo "❌ 错误: package.json 文件不存在"
    exit 1
fi
echo "✅ package.json 文件存在"

# 2. 复制核心文件
echo "=== 复制核心文件 ==="
echo "复制 app 目录..."
cp -r app $TEMP_DIR/
echo "复制 public 目录..."
cp -r public $TEMP_DIR/
echo "复制 package.json..."
cp package.json $TEMP_DIR/

# # 检查 node_modules 是否存在并复制
# if [ -d "node_modules" ]; then
#     echo "复制 node_modules 目录..."
#     cp -r node_modules $TEMP_DIR/
#     echo "✅ node_modules 目录已复制"
#     # 创建 .nvmrc 确保 Node.js 版本正确
#     echo "20" > $TEMP_DIR/.nvmrc
# else
#     echo "⚠️  node_modules 目录不存在，将依赖远程安装"
# fi

# 3. 检查和复制 .next 目录（如果存在）
echo "=== 检查构建文件 ==="
if [ -d ".next" ]; then
    echo "✅ 发现 .next 目录，复制预构建文件..."
    cp -r .next $TEMP_DIR/
    echo "✅ .next 目录已复制"
else
    echo "⚠️  .next 目录不存在，将在服务器端构建"
fi

# 4. 复制锁定文件
echo "=== 复制锁定文件 ==="
if [ -f "package-lock.json" ]; then
    cp package-lock.json $TEMP_DIR/
    echo "✅ 复制 package-lock.json"
elif [ -f "bun.lock" ]; then
    cp bun.lock $TEMP_DIR/
    echo "✅ 复制 bun.lock"
elif [ -f "yarn.lock" ]; then
    cp yarn.lock $TEMP_DIR/
    echo "✅ 复制 yarn.lock"
else
    echo "⚠️  未找到锁定文件"
fi

# 复制版本控制文件
if [ -f ".nvmrc" ]; then
    cp .nvmrc $TEMP_DIR/
    echo "✅ 复制 .nvmrc"
fi

# 5. 复制配置文件
echo "=== 复制配置文件 ==="
cp next.config.azure.ts $TEMP_DIR/next.config.ts
cp tsconfig.json $TEMP_DIR/
cp .deployment $TEMP_DIR/
echo "✅ 配置文件复制完成"

# 6. 复制启动脚本
echo "=== 复制启动脚本 ==="
cp startup.sh $TEMP_DIR/
echo "✅ 启动脚本复制完成"

# 7. 验证部署包完整性
echo "=== 验证部署包完整性 ==="

# 验证必需的目录和文件
REQUIRED_DIRS=("app" "public")
REQUIRED_FILES=("package.json" "next.config.ts" "startup.sh" )
OPTIONAL_DIRS=("node_modules" ".next")

echo "检查必需目录:"
for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$TEMP_DIR/$dir" ]; then
        echo "  ✅ $dir/ 目录存在"
    else
        echo "  ❌ $dir/ 目录缺失"
        exit 1
    fi
done

echo "检查可选目录:"
for dir in "${OPTIONAL_DIRS[@]}"; do
    if [ -d "$TEMP_DIR/$dir" ]; then
        echo "  ✅ $dir/ 目录存在"
    else
        echo "  ⚠️  $dir/ 目录不存在"
    fi
done

echo "检查必需文件:"
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$TEMP_DIR/$file" ]; then
        echo "  ✅ $file 文件存在"
    else
        echo "  ❌ $file 文件缺失"
        exit 1
    fi
done

# 检查可选的 .next 目录
if [ -d "$TEMP_DIR/.next" ]; then
    echo "  ✅ .next/ 目录存在 (预构建)"
else
    echo "  ⚠️  .next/ 目录不存在 (将远程构建)"
fi

# 显示部署包内容概览
echo "=== 部署包内容概览 ==="
echo "总文件数: $(find $TEMP_DIR -type f | wc -l)"
echo "目录结构:"
ls -la $TEMP_DIR/
echo ""
echo "app/ 目录内容:"
ls -la $TEMP_DIR/app/ | head -10
echo ""

# 创建部署包
cd $TEMP_DIR
echo "创建部署包..."
zip -r $OLDPWD/app.zip . -q

# 清理临时目录
cd $OLDPWD
rm -rf $TEMP_DIR
echo "✅ 部署包创建完成"

# 3. 测试模式退出
if [ "$TEST_MODE" = "true" ]; then
    echo "🧪 测试模式完成，部署包已创建为 app.zip"
    echo "可以手动检查包内容: unzip -l app.zip"
    echo "要执行实际部署，请运行: ./quick-deploy.sh"
    exit 0
fi

# 4. 配置 Azure App Service
echo "配置 Azure App Service..."

# 设置基本环境变量（.deployment 文件已包含构建配置）
echo "设置环境变量..."
az webapp config appsettings set \
  --resource-group $RESOURCE_GROUP \
  --name $WEBAPP_NAME \
  --settings \
    PORT=8080 \
    WEBSITES_PORT=8080 \
    WEBSITE_NODE_DEFAULT_VERSION=20.x \
    NPM_CONFIG_PRODUCTION=false \
  --output none

echo "✅ 配置完成，构建选项由 .deployment 文件控制"

# 设置启动命令
echo "设置启动命令..."
az webapp config set \
  --resource-group $RESOURCE_GROUP \
  --name $WEBAPP_NAME \
  --output none

# 5. 部署到 Azure（带重试机制）
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
    rm -f app.zip
    exit 1
fi

# 6. 清理和重启
echo "清理部署包..."
rm -f app.zip

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
sleep 10

# 7. 获取访问地址和健康检查
echo "获取访问地址..."
WEBAPP_URL=$(az webapp show \
  --name $WEBAPP_NAME \
  --resource-group $RESOURCE_GROUP \
  --query defaultHostName \
  --output tsv 2>/dev/null)

if [ -n "$WEBAPP_URL" ]; then
    echo "🌐 访问地址: https://$WEBAPP_URL"
    
    # 简单的健康检查
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
echo "🎉 部署完成！"
echo "📝 查看日志: az webapp log tail --name $WEBAPP_NAME --resource-group $RESOURCE_GROUP"
echo "🔄 如果遇到问题，可以重新运行此脚本"
