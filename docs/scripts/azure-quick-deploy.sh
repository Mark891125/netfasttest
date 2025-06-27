#!/bin/bash

echo "🚀 Azure Web App 快速部署脚本"
echo "=============================="
echo "版本: 1.0"
echo "适用于: Next.js 网络速度测试应用"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量（可根据需要修改）
DEFAULT_RESOURCE_GROUP="netfasttest-rg"
DEFAULT_APP_NAME="netfasttest-app"
DEFAULT_LOCATION="East US"
DEFAULT_SKU="B1"

# 函数：打印带颜色的消息
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# 函数：检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 未安装。请先安装 $1"
        return 1
    fi
    return 0
}

# 函数：获取用户输入
get_user_input() {
    read -p "资源组名称 [$DEFAULT_RESOURCE_GROUP]: " RESOURCE_GROUP
    RESOURCE_GROUP=${RESOURCE_GROUP:-$DEFAULT_RESOURCE_GROUP}
    
    read -p "应用名称 [$DEFAULT_APP_NAME]: " APP_NAME
    APP_NAME=${APP_NAME:-$DEFAULT_APP_NAME}
    
    read -p "Azure区域 [$DEFAULT_LOCATION]: " LOCATION
    LOCATION=${LOCATION:-$DEFAULT_LOCATION}
    
    read -p "定价层 [$DEFAULT_SKU]: " SKU
    SKU=${SKU:-$DEFAULT_SKU}
    
    echo ""
    print_info "配置确认:"
    echo "  资源组: $RESOURCE_GROUP"
    echo "  应用名称: $APP_NAME"
    echo "  区域: $LOCATION"
    echo "  定价层: $SKU"
    echo ""
    
    read -p "确认以上配置吗？(y/N): " confirm
    if [[ $confirm != [yY] ]]; then
        echo "部署已取消"
        exit 0
    fi
}

# 主函数
main() {
    echo "🔍 预检查..."
    
    # 检查必要工具
    check_command "az" || exit 1
    check_command "npm" || exit 1
    check_command "node" || exit 1
    check_command "jq" || print_warning "jq 未安装，某些功能可能不可用"
    
    print_status "所有必要工具已安装"
    
    # 检查Azure CLI登录状态
    echo "🔐 检查Azure登录状态..."
    if ! az account show &> /dev/null; then
        print_warning "未登录Azure，正在打开登录..."
        az login
        if [ $? -ne 0 ]; then
            print_error "Azure登录失败"
            exit 1
        fi
    fi
    
    print_status "Azure 登录验证成功"
    
    # 显示当前订阅
    echo "📊 当前订阅信息:"
    az account show --query "{subscriptionId:id, subscriptionName:name, tenantId:tenantId}" --output table
    
    # 获取用户配置
    get_user_input
    
    # 开始部署
    echo "🚀 开始部署..."
    
    # 1. 创建资源组
    echo "🏗️  步骤 1/8: 创建资源组..."
    if az group show --name $RESOURCE_GROUP &> /dev/null; then
        print_warning "资源组 $RESOURCE_GROUP 已存在，跳过创建"
    else
        az group create --name $RESOURCE_GROUP --location "$LOCATION" --output none
        if [ $? -eq 0 ]; then
            print_status "资源组创建成功"
        else
            print_error "资源组创建失败"
            exit 1
        fi
    fi
    
    # 2. 创建App Service Plan
    echo "📱 步骤 2/8: 创建App Service Plan..."
    PLAN_NAME="$APP_NAME-plan"
    if az appservice plan show --name $PLAN_NAME --resource-group $RESOURCE_GROUP &> /dev/null; then
        print_warning "App Service Plan已存在，跳过创建"
    else
        az appservice plan create \
            --name $PLAN_NAME \
            --resource-group $RESOURCE_GROUP \
            --sku $SKU \
            --is-linux \
            --location "$LOCATION" \
            --output none
        if [ $? -eq 0 ]; then
            print_status "App Service Plan创建成功"
        else
            print_error "App Service Plan创建失败"
            exit 1
        fi
    fi
    
    # 3. 创建Web App
    echo "🌐 步骤 3/8: 创建Web App..."
    if az webapp show --name $APP_NAME --resource-group $RESOURCE_GROUP &> /dev/null; then
        print_warning "Web App已存在，跳过创建"
    else
        az webapp create \
            --resource-group $RESOURCE_GROUP \
            --plan $PLAN_NAME \
            --name $APP_NAME \
            --runtime "NODE|18-lts" \
            --output none
        if [ $? -eq 0 ]; then
            print_status "Web App创建成功"
        else
            print_error "Web App创建失败"
            exit 1
        fi
    fi
    
    # 4. 配置应用设置
    echo "⚙️  步骤 4/8: 配置应用设置..."
    az webapp config appsettings set \
        --resource-group $RESOURCE_GROUP \
        --name $APP_NAME \
        --settings \
            WEBSITE_NODE_DEFAULT_VERSION=20.18.0 \
            NODE_ENV=production \
            NEXT_TELEMETRY_DISABLED=1 \
            SCM_DO_BUILD_DURING_DEPLOYMENT=true \
            WEBSITE_HTTPLOGGING_RETENTION_DAYS=3 \
        --output none
    
    print_status "应用设置配置完成"
    
    # 5. 配置启动命令
    echo "🚀 步骤 5/8: 配置启动命令..."
    az webapp config set \
        --resource-group $RESOURCE_GROUP \
        --name $APP_NAME \
        --startup-file "npm start" \
        --output none
    
    print_status "启动命令配置完成"
    
    # 6. 启用日志
    echo "📋 步骤 6/8: 启用应用日志..."
    az webapp log config \
        --resource-group $RESOURCE_GROUP \
        --name $APP_NAME \
        --application-logging filesystem \
        --level information \
        --output none
    
    print_status "日志配置完成"
    
    # 7. 本地构建测试
    echo "🔨 步骤 7/8: 本地构建测试..."
    if [ -f "package.azure.json" ]; then
        print_info "使用Azure优化的package.json"
        cp package.azure.json package.json.backup
    fi
    
    if [ -f "next.config.azure.js" ]; then
        print_info "使用Azure优化的next.config.js"
        cp next.config.azure.js next.config.js.backup
    fi
    
    npm run build
    if [ $? -eq 0 ]; then
        print_status "本地构建成功"
    else
        print_error "本地构建失败，请检查代码"
        exit 1
    fi
    
    # 8. 部署代码
    echo "📦 步骤 8/8: 部署代码..."
    
    # 创建部署包
    print_info "创建部署包..."
    zip -r ${APP_NAME}-deployment.zip . \
        -x "node_modules/*" \
        -x ".git/*" \
        -x ".next/cache/*" \
        -x "*.zip" \
        -x ".env.local" \
        -x "*.log" \
        -x "azure-*.sh" \
        -x "test-*.sh" \
        -x "demo-*.sh" \
        -x "multi-*.sh" \
        -x "quick-*.sh"
    
    # 部署到Azure
    print_info "上传到Azure Web App..."
    az webapp deployment source config-zip \
        --resource-group $RESOURCE_GROUP \
        --name $APP_NAME \
        --src ${APP_NAME}-deployment.zip \
        --output none
    
    if [ $? -eq 0 ]; then
        print_status "代码部署成功"
    else
        print_error "代码部署失败"
        exit 1
    fi
    
    # 清理临时文件
    rm ${APP_NAME}-deployment.zip
    
    # 恢复备份文件
    if [ -f "package.json.backup" ]; then
        mv package.json.backup package.json
    fi
    
    if [ -f "next.config.js.backup" ]; then
        mv next.config.js.backup next.config.js
    fi
    
    # 获取应用URL
    APP_URL=$(az webapp show --name $APP_NAME --resource-group $RESOURCE_GROUP --query "defaultHostName" --output tsv)
    
    echo ""
    echo "🎉 部署完成!"
    echo "============="
    print_status "应用已成功部署到Azure Web App"
    echo ""
    print_info "访问信息:"
    echo "  🌐 应用URL: https://$APP_URL"
    echo "  📊 Azure门户: https://portal.azure.com/#@/resource/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Web/sites/$APP_NAME"
    echo ""
    print_info "有用命令:"
    echo "  查看日志: az webapp log tail --resource-group $RESOURCE_GROUP --name $APP_NAME"
    echo "  重启应用: az webapp restart --resource-group $RESOURCE_GROUP --name $APP_NAME"
    echo "  停止应用: az webapp stop --resource-group $RESOURCE_GROUP --name $APP_NAME"
    echo "  删除资源: az group delete --name $RESOURCE_GROUP --yes --no-wait"
    echo ""
    
    # 应用启动等待
    print_info "等待应用启动 (30秒)..."
    sleep 30
    
    # 健康检查
    echo "🩺 执行健康检查..."
    HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" "https://$APP_URL")
    
    if [ "$HTTP_STATUS" = "200" ]; then
        print_status "应用健康检查通过!"
        
        # 测试API
        print_info "测试API接口..."
        API_STATUS=$(curl -o /dev/null -s -w "%{http_code}" "https://$APP_URL/api/speed-test")
        if [ "$API_STATUS" = "200" ]; then
            print_status "API接口正常工作"
        else
            print_warning "API接口可能有问题 (状态码: $API_STATUS)"
        fi
        
    else
        print_warning "应用可能还在启动中 (状态码: $HTTP_STATUS)"
        print_info "请稍后访问: https://$APP_URL"
    fi
    
    echo ""
    print_status "快速部署脚本执行完成!"
    print_info "如需更多功能，请运行: ./azure-full-deploy.sh"
}

# 脚本入口
main "$@"
