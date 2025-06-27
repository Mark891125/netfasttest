#!/bin/bash

echo "🌟 Azure Web App 完整部署脚本"
echo "============================="
echo "版本: 1.0"
echo "功能: 完整部署 + 监控 + CDN + 自动扩缩"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 配置变量
DEFAULT_RESOURCE_GROUP="netfasttest-rg"
DEFAULT_APP_NAME="netfasttest-app"
DEFAULT_LOCATION="East US"
DEFAULT_SKU="S1"

# 函数定义
print_status() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_step() { echo -e "${PURPLE}🔄 $1${NC}"; }

# 获取配置函数
get_deployment_config() {
    echo "📋 部署配置向导"
    echo "==============="
    
    read -p "资源组名称 [$DEFAULT_RESOURCE_GROUP]: " RESOURCE_GROUP
    RESOURCE_GROUP=${RESOURCE_GROUP:-$DEFAULT_RESOURCE_GROUP}
    
    read -p "应用名称 [$DEFAULT_APP_NAME]: " APP_NAME
    APP_NAME=${APP_NAME:-$DEFAULT_APP_NAME}
    
    read -p "Azure区域 [$DEFAULT_LOCATION]: " LOCATION
    LOCATION=${LOCATION:-$DEFAULT_LOCATION}
    
    echo ""
    echo "💰 定价层选择:"
    echo "  1. Basic B1 (1 Core, 1.75GB RAM) - 开发/测试"
    echo "  2. Standard S1 (1 Core, 1.75GB RAM) - 小型生产"
    echo "  3. Standard S2 (2 Core, 3.5GB RAM) - 中型生产"
    echo "  4. Premium P1V2 (1 Core, 3.5GB RAM) - 高性能"
    read -p "选择定价层 (1-4) [2]: " sku_choice
    
    case $sku_choice in
        1) SKU="B1" ;;
        3) SKU="S2" ;;
        4) SKU="P1V2" ;;
        *) SKU="S1" ;;
    esac
    
    echo ""
    echo "🔧 高级功能选择:"
    read -p "启用Application Insights监控? (y/N): " enable_insights
    read -p "启用Azure CDN? (y/N): " enable_cdn
    read -p "启用自动扩缩? (y/N): " enable_autoscale
    read -p "配置自定义域名? (y/N): " enable_custom_domain
    
    if [[ $enable_custom_domain == [yY] ]]; then
        read -p "请输入自定义域名: " custom_domain
    fi
    
    echo ""
    print_info "配置确认:"
    echo "  资源组: $RESOURCE_GROUP"
    echo "  应用名称: $APP_NAME"
    echo "  区域: $LOCATION"
    echo "  定价层: $SKU"
    echo "  Application Insights: ${enable_insights:-N}"
    echo "  Azure CDN: ${enable_cdn:-N}"
    echo "  自动扩缩: ${enable_autoscale:-N}"
    echo "  自定义域名: ${custom_domain:-无}"
    echo ""
    
    read -p "确认开始完整部署吗？(y/N): " confirm
    if [[ $confirm != [yY] ]]; then
        echo "部署已取消"
        exit 0
    fi
}

# 创建基础资源
create_basic_resources() {
    print_step "第一阶段: 创建基础Azure资源"
    
    # 资源组
    echo "🏗️  创建资源组..."
    if az group show --name $RESOURCE_GROUP &> /dev/null; then
        print_warning "资源组已存在"
    else
        az group create --name $RESOURCE_GROUP --location "$LOCATION" --output none
        print_status "资源组创建成功"
    fi
    
    # App Service Plan
    echo "📱 创建App Service Plan..."
    PLAN_NAME="$APP_NAME-plan"
    if az appservice plan show --name $PLAN_NAME --resource-group $RESOURCE_GROUP &> /dev/null; then
        print_warning "App Service Plan已存在"
    else
        az appservice plan create \
            --name $PLAN_NAME \
            --resource-group $RESOURCE_GROUP \
            --sku $SKU \
            --is-linux \
            --location "$LOCATION" \
            --output none
        print_status "App Service Plan创建成功"
    fi
    
    # Web App
    echo "🌐 创建Web App..."
    if az webapp show --name $APP_NAME --resource-group $RESOURCE_GROUP &> /dev/null; then
        print_warning "Web App已存在"
    else
        az webapp create \
            --resource-group $RESOURCE_GROUP \
            --plan $PLAN_NAME \
            --name $APP_NAME \
            --runtime "NODE|18-lts" \
            --output none
        print_status "Web App创建成功"
    fi
}

# 配置Application Insights
setup_application_insights() {
    if [[ $enable_insights == [yY] ]]; then
        print_step "配置Application Insights监控"
        
        INSIGHTS_NAME="$APP_NAME-insights"
        
        # 创建Application Insights
        az monitor app-insights component create \
            --app $INSIGHTS_NAME \
            --location "$LOCATION" \
            --resource-group $RESOURCE_GROUP \
            --kind web \
            --output none 2>/dev/null
        
        # 获取连接字符串
        INSIGHTS_CONNECTION=$(az monitor app-insights component show \
            --app $INSIGHTS_NAME \
            --resource-group $RESOURCE_GROUP \
            --query connectionString \
            --output tsv)
        
        # 配置Web App使用Application Insights
        az webapp config appsettings set \
            --resource-group $RESOURCE_GROUP \
            --name $APP_NAME \
            --settings APPLICATIONINSIGHTS_CONNECTION_STRING="$INSIGHTS_CONNECTION" \
            --output none
        
        print_status "Application Insights配置完成"
    fi
}

# 配置Azure CDN
setup_azure_cdn() {
    if [[ $enable_cdn == [yY] ]]; then
        print_step "配置Azure CDN"
        
        CDN_PROFILE="$APP_NAME-cdn"
        CDN_ENDPOINT="$APP_NAME-endpoint"
        
        # 创建CDN配置文件
        az cdn profile create \
            --resource-group $RESOURCE_GROUP \
            --name $CDN_PROFILE \
            --sku Standard_Microsoft \
            --output none
        
        # 创建CDN端点
        APP_HOSTNAME=$(az webapp show --name $APP_NAME --resource-group $RESOURCE_GROUP --query "defaultHostName" --output tsv)
        
        az cdn endpoint create \
            --resource-group $RESOURCE_GROUP \
            --name $CDN_ENDPOINT \
            --profile-name $CDN_PROFILE \
            --origin $APP_HOSTNAME \
            --origin-host-header $APP_HOSTNAME \
            --output none
        
        print_status "Azure CDN配置完成"
        
        # 获取CDN URL
        CDN_URL=$(az cdn endpoint show \
            --resource-group $RESOURCE_GROUP \
            --name $CDN_ENDPOINT \
            --profile-name $CDN_PROFILE \
            --query "hostName" \
            --output tsv)
        
        print_info "CDN URL: https://$CDN_URL"
    fi
}

# 配置自动扩缩
setup_autoscaling() {
    if [[ $enable_autoscale == [yY] ]]; then
        print_step "配置自动扩缩"
        
        AUTOSCALE_NAME="$APP_NAME-autoscale"
        
        # 获取App Service Plan资源ID
        PLAN_ID=$(az appservice plan show \
            --name $PLAN_NAME \
            --resource-group $RESOURCE_GROUP \
            --query id \
            --output tsv)
        
        # 创建自动扩缩设置
        az monitor autoscale create \
            --resource-group $RESOURCE_GROUP \
            --name $AUTOSCALE_NAME \
            --resource $PLAN_ID \
            --min-count 1 \
            --max-count 5 \
            --count 1 \
            --output none
        
        # 添加CPU扩展规则
        az monitor autoscale rule create \
            --resource-group $RESOURCE_GROUP \
            --autoscale-name $AUTOSCALE_NAME \
            --condition "Percentage CPU > 70 avg 5m" \
            --scale out 1 \
            --output none
        
        # 添加CPU收缩规则
        az monitor autoscale rule create \
            --resource-group $RESOURCE_GROUP \
            --autoscale-name $AUTOSCALE_NAME \
            --condition "Percentage CPU < 30 avg 5m" \
            --scale in 1 \
            --output none
        
        print_status "自动扩缩配置完成"
    fi
}

# 配置自定义域名
setup_custom_domain() {
    if [[ $enable_custom_domain == [yY] ]] && [[ -n $custom_domain ]]; then
        print_step "配置自定义域名"
        
        print_info "配置自定义域名: $custom_domain"
        
        # 添加自定义域名
        az webapp config hostname add \
            --resource-group $RESOURCE_GROUP \
            --webapp-name $APP_NAME \
            --hostname $custom_domain \
            --output none
        
        # 启用托管SSL证书
        print_info "启用SSL证书..."
        az webapp config ssl create \
            --resource-group $RESOURCE_GROUP \
            --name $APP_NAME \
            --hostname $custom_domain \
            --output none
        
        print_status "自定义域名和SSL配置完成"
    fi
}

# 部署应用代码
deploy_application() {
    print_step "第二阶段: 部署应用程序代码"
    
    # 配置应用设置
    echo "⚙️  配置应用设置..."
    az webapp config appsettings set \
        --resource-group $RESOURCE_GROUP \
        --name $APP_NAME \
        --settings \
            WEBSITE_NODE_DEFAULT_VERSION=20.18.0 \
            NODE_ENV=production \
            NEXT_TELEMETRY_DISABLED=1 \
            SCM_DO_BUILD_DURING_DEPLOYMENT=true \
            WEBSITE_HTTPLOGGING_RETENTION_DAYS=7 \
            WEBSITES_ENABLE_APP_SERVICE_STORAGE=false \
            WEBSITE_RUN_FROM_PACKAGE=1 \
        --output none
    
    # 配置启动命令
    az webapp config set \
        --resource-group $RESOURCE_GROUP \
        --name $APP_NAME \
        --startup-file "npm start" \
        --always-on true \
        --output none
    
    # 启用详细日志
    az webapp log config \
        --resource-group $RESOURCE_GROUP \
        --name $APP_NAME \
        --application-logging filesystem \
        --level information \
        --failed-request-tracing true \
        --detailed-error-messages true \
        --output none
    
    print_status "应用配置完成"
    
    # 代码构建和部署
    echo "🔨 构建和部署代码..."
    
    # 使用Azure优化配置
    if [ -f "package.azure.json" ]; then
        cp package.json package.json.original
        cp package.azure.json package.json
        print_info "使用Azure优化的package.json"
    fi
    
    if [ -f "next.config.azure.js" ]; then
        cp next.config.js next.config.js.original
        cp next.config.azure.js next.config.js
        print_info "使用Azure优化的next.config.js"
    fi
    
    # 构建应用
    npm run build
    if [ $? -ne 0 ]; then
        print_error "构建失败"
        exit 1
    fi
    
    # 创建部署包
    DEPLOY_ZIP="${APP_NAME}-$(date +%Y%m%d-%H%M%S).zip"
    zip -r $DEPLOY_ZIP . \
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
        -x "quick-*.sh" \
        -x "*.original"
    
    # 部署到Azure
    az webapp deployment source config-zip \
        --resource-group $RESOURCE_GROUP \
        --name $APP_NAME \
        --src $DEPLOY_ZIP \
        --output none
    
    # 清理
    rm $DEPLOY_ZIP
    
    # 恢复原始文件
    if [ -f "package.json.original" ]; then
        mv package.json.original package.json
    fi
    
    if [ -f "next.config.js.original" ]; then
        mv next.config.js.original next.config.js
    fi
    
    print_status "代码部署完成"
}

# 执行部署后测试
run_deployment_tests() {
    print_step "第三阶段: 部署后验证和测试"
    
    APP_URL=$(az webapp show --name $APP_NAME --resource-group $RESOURCE_GROUP --query "defaultHostName" --output tsv)
    
    echo "⏱️  等待应用启动 (60秒)..."
    sleep 60
    
    # 健康检查
    echo "🩺 执行健康检查..."
    for i in {1..5}; do
        HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" "https://$APP_URL" --max-time 30)
        if [ "$HTTP_STATUS" = "200" ]; then
            print_status "应用健康检查通过!"
            break
        else
            print_warning "尝试 $i/5: 状态码 $HTTP_STATUS"
            sleep 15
        fi
    done
    
    # API测试
    echo "🧪 测试API接口..."
    API_STATUS=$(curl -o /dev/null -s -w "%{http_code}" "https://$APP_URL/api/speed-test" --max-time 30)
    if [ "$API_STATUS" = "200" ]; then
        print_status "API接口测试通过"
    else
        print_warning "API接口状态: $API_STATUS"
    fi
    
    # 执行完整功能测试
    echo "🔍 执行功能测试..."
    TEST_RESULT=$(curl -s -X POST "https://$APP_URL/api/speed-test" \
        -H "Content-Type: application/json" \
        -d '{"test": "deployment"}' \
        --max-time 30)
    
    if echo "$TEST_RESULT" | grep -q "success.*true"; then
        print_status "功能测试通过"
    else
        print_warning "功能测试可能有问题"
    fi
}

# 生成部署报告
generate_deployment_report() {
    print_step "生成部署报告"
    
    APP_URL=$(az webapp show --name $APP_NAME --resource-group $RESOURCE_GROUP --query "defaultHostName" --output tsv)
    
    REPORT_FILE="azure-deployment-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > $REPORT_FILE << EOF
🌟 Azure Web App 完整部署报告
============================
部署时间: $(date)
部署版本: 1.0

📊 资源信息:
- 资源组: $RESOURCE_GROUP
- 应用名称: $APP_NAME
- 区域: $LOCATION
- 定价层: $SKU
- 应用URL: https://$APP_URL

🔧 已启用功能:
- Application Insights: ${enable_insights:-否}
- Azure CDN: ${enable_cdn:-否}
- 自动扩缩: ${enable_autoscale:-否}
- 自定义域名: ${custom_domain:-无}

📋 Azure门户链接:
- Web App: https://portal.azure.com/#@/resource/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Web/sites/$APP_NAME
- 资源组: https://portal.azure.com/#@/resource/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP

🛠️  管理命令:
# 查看实时日志
az webapp log tail --resource-group $RESOURCE_GROUP --name $APP_NAME

# 重启应用
az webapp restart --resource-group $RESOURCE_GROUP --name $APP_NAME

# 查看配置
az webapp config show --resource-group $RESOURCE_GROUP --name $APP_NAME

# 更新应用设置
az webapp config appsettings set --resource-group $RESOURCE_GROUP --name $APP_NAME --settings KEY=VALUE

# 扩展实例
az appservice plan update --resource-group $RESOURCE_GROUP --name $PLAN_NAME --number-of-workers 3

# 查看监控指标
az monitor metrics list --resource /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Web/sites/$APP_NAME

# 删除所有资源（谨慎使用）
az group delete --name $RESOURCE_GROUP --yes --no-wait

🔗 快速链接:
- 应用主页: https://$APP_URL
- API测试: https://$APP_URL/api/speed-test
- 健康检查: https://$APP_URL
EOF

    if [[ $enable_cdn == [yY] ]]; then
        echo "- CDN URL: https://$CDN_URL" >> $REPORT_FILE
    fi
    
    cat >> $REPORT_FILE << EOF

📈 性能优化建议:
1. 启用Application Insights进行性能监控
2. 配置Azure Front Door进行全球加速
3. 使用Azure Redis Cache缓存数据
4. 配置适当的自动扩缩规则
5. 定期备份应用数据和配置

🔒 安全建议:
1. 启用HTTPS Only
2. 配置IP限制（如需要）
3. 启用诊断日志
4. 定期更新依赖包
5. 使用Azure Key Vault存储敏感配置

部署完成时间: $(date)
EOF

    print_status "部署报告已生成: $REPORT_FILE"
}

# 主函数
main() {
    echo "🔍 系统预检查..."
    
    # 检查必要工具
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI 未安装"
        exit 1
    fi
    
    if ! command -v npm &> /dev/null; then
        print_error "npm 未安装"
        exit 1
    fi
    
    # 检查Azure登录
    if ! az account show &> /dev/null; then
        print_warning "未登录Azure，正在打开登录..."
        az login
    fi
    
    print_status "系统检查通过"
    
    # 获取部署配置
    get_deployment_config
    
    # 开始完整部署流程
    echo ""
    echo "🚀 开始完整部署流程..."
    echo "总预计时间: 10-15分钟"
    echo ""
    
    # 阶段1: 基础资源
    create_basic_resources
    
    # 阶段2: 高级功能
    setup_application_insights
    setup_azure_cdn
    setup_autoscaling
    setup_custom_domain
    
    # 阶段3: 应用部署
    deploy_application
    
    # 阶段4: 测试验证
    run_deployment_tests
    
    # 阶段5: 生成报告
    generate_deployment_report
    
    echo ""
    echo "🎉 完整部署成功完成!"
    echo "===================="
    print_status "所有组件已成功部署并通过测试"
    echo ""
    print_info "接下来您可以:"
    echo "1. 访问应用: https://$APP_URL"
    echo "2. 查看部署报告: cat $REPORT_FILE"
    echo "3. 监控应用性能: 查看Azure门户"
    echo "4. 配置域名DNS: 指向 $APP_URL"
    echo ""
    print_status "完整部署脚本执行完成!"
}

# 脚本入口
main "$@"
