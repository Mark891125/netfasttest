#!/bin/bash

echo "🔧 Azure 部署故障排除工具"
echo "========================="
echo "版本: 1.0"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 函数定义
print_status() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# 检查Azure CLI和登录状态
check_azure_cli() {
    echo "🔍 检查Azure CLI状态..."
    
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI 未安装"
        echo "安装方法: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        return 1
    fi
    
    print_status "Azure CLI 已安装"
    
    if ! az account show &> /dev/null; then
        print_warning "未登录Azure，请运行: az login"
        return 1
    fi
    
    print_status "Azure 登录状态正常"
    
    echo "当前订阅:"
    az account show --query "{name:name, id:id}" --output table
    return 0
}

# 检查应用状态
check_app_status() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "用法: check_app_status <资源组> <应用名>"
        return 1
    fi
    
    local RESOURCE_GROUP=$1
    local APP_NAME=$2
    
    echo "📱 检查应用状态: $APP_NAME"
    
    # 检查Web App是否存在
    if ! az webapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        print_error "Web App '$APP_NAME' 在资源组 '$RESOURCE_GROUP' 中不存在"
        return 1
    fi
    
    print_status "Web App 存在"
    
    # 获取应用信息
    local APP_URL=$(az webapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query "defaultHostName" --output tsv)
    local APP_STATE=$(az webapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query "state" --output tsv)
    
    echo "  应用URL: https://$APP_URL"
    echo "  应用状态: $APP_STATE"
    
    # 检查HTTP状态
    echo "🌐 检查HTTP响应..."
    local HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" "https://$APP_URL" --max-time 30)
    
    if [ "$HTTP_STATUS" = "200" ]; then
        print_status "HTTP状态正常 (200)"
    else
        print_warning "HTTP状态异常: $HTTP_STATUS"
    fi
    
    # 检查API
    echo "🧪 检查API状态..."
    local API_STATUS=$(curl -o /dev/null -s -w "%{http_code}" "https://$APP_URL/api/speed-test" --max-time 30)
    
    if [ "$API_STATUS" = "200" ]; then
        print_status "API状态正常 (200)"
    else
        print_warning "API状态异常: $API_STATUS"
    fi
}

# 检查应用日志
check_app_logs() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "用法: check_app_logs <资源组> <应用名>"
        return 1
    fi
    
    local RESOURCE_GROUP=$1
    local APP_NAME=$2
    
    echo "📋 获取应用日志..."
    
    # 启用日志（如果未启用）
    az webapp log config \
        --resource-group "$RESOURCE_GROUP" \
        --name "$APP_NAME" \
        --application-logging filesystem \
        --level information \
        --output none &> /dev/null
    
    # 显示最近的日志
    echo "最近的应用日志:"
    az webapp log download --resource-group "$RESOURCE_GROUP" --name "$APP_NAME" --log-file "app-logs.zip" &> /dev/null
    
    if [ -f "app-logs.zip" ]; then
        print_status "日志文件已下载: app-logs.zip"
        unzip -q app-logs.zip
        
        if [ -f "LogFiles/Application/applicationLog.txt" ]; then
            echo "=== 最近的应用日志 ==="
            tail -20 LogFiles/Application/applicationLog.txt
        fi
        
        # 清理
        rm -rf LogFiles app-logs.zip
    else
        print_warning "无法下载日志文件"
    fi
}

# 检查部署配置
check_deployment_config() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "用法: check_deployment_config <资源组> <应用名>"
        return 1
    fi
    
    local RESOURCE_GROUP=$1
    local APP_NAME=$2
    
    echo "⚙️  检查部署配置..."
    
    # 检查应用设置
    echo "应用设置:"
    az webapp config appsettings list --resource-group "$RESOURCE_GROUP" --name "$APP_NAME" --query "[].{name:name, value:value}" --output table
    
    echo ""
    
    # 检查启动命令
    echo "启动配置:"
    az webapp config show --resource-group "$RESOURCE_GROUP" --name "$APP_NAME" --query "{startupFile:linuxFxVersion, alwaysOn:alwaysOn}" --output table
    
    echo ""
    
    # 检查扩展设置
    echo "扩展设置:"
    local PLAN_NAME=$(az webapp show --resource-group "$RESOURCE_GROUP" --name "$APP_NAME" --query "serverFarmId" --output tsv | sed 's/.*\///')
    az appservice plan show --resource-group "$RESOURCE_GROUP" --name "$PLAN_NAME" --query "{sku:sku.name, instances:numberOfWorkers}" --output table
}

# 修复常见问题
fix_common_issues() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "用法: fix_common_issues <资源组> <应用名>"
        return 1
    fi
    
    local RESOURCE_GROUP=$1
    local APP_NAME=$2
    
    echo "🔧 修复常见问题..."
    
    # 1. 确保Node.js版本正确
    print_info "设置Node.js版本..."
    az webapp config appsettings set \
        --resource-group "$RESOURCE_GROUP" \
        --name "$APP_NAME" \
        --settings WEBSITE_NODE_DEFAULT_VERSION=20.18.0 \
        --output none
    
    # 2. 启用详细日志
    print_info "启用详细日志..."
    az webapp log config \
        --resource-group "$RESOURCE_GROUP" \
        --name "$APP_NAME" \
        --application-logging filesystem \
        --level verbose \
        --failed-request-tracing true \
        --detailed-error-messages true \
        --output none
    
    # 3. 重启应用
    print_info "重启应用..."
    az webapp restart --resource-group "$RESOURCE_GROUP" --name "$APP_NAME" --output none
    
    print_status "常见问题修复完成"
    
    # 等待重启
    print_info "等待应用重启 (30秒)..."
    sleep 30
    
    # 重新检查状态
    check_app_status "$RESOURCE_GROUP" "$APP_NAME"
}

# 性能诊断
performance_diagnostic() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "用法: performance_diagnostic <资源组> <应用名>"
        return 1
    fi
    
    local RESOURCE_GROUP=$1
    local APP_NAME=$2
    
    echo "📊 性能诊断..."
    
    # 获取应用URL
    local APP_URL=$(az webapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query "defaultHostName" --output tsv)
    
    # 响应时间测试
    echo "🕐 响应时间测试..."
    for i in {1..5}; do
        local RESPONSE_TIME=$(curl -o /dev/null -s -w "%{time_total}" "https://$APP_URL" --max-time 30)
        echo "  测试 $i: ${RESPONSE_TIME}s"
    done
    
    # 检查资源使用
    echo "💾 资源使用情况..."
    local PLAN_NAME=$(az webapp show --resource-group "$RESOURCE_GROUP" --name "$APP_NAME" --query "serverFarmId" --output tsv | sed 's/.*\///')
    
    # 获取CPU和内存指标（需要一些时间收集数据）
    print_info "获取性能指标..."
    az monitor metrics list \
        --resource "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Web/sites/$APP_NAME" \
        --metric CpuPercentage \
        --interval PT1H \
        --query "value[0].timeseries[0].data[-1:][].{time:timeStamp, cpu:average}" \
        --output table 2>/dev/null || print_warning "无法获取性能指标（可能需要等待数据收集）"
}

# 主菜单
show_menu() {
    echo ""
    echo "🛠️  Azure 故障排除选项:"
    echo "1. 检查Azure CLI和登录状态"
    echo "2. 检查应用状态"
    echo "3. 检查应用日志"
    echo "4. 检查部署配置"
    echo "5. 修复常见问题"
    echo "6. 性能诊断"
    echo "7. 全面诊断"
    echo "8. 退出"
    echo ""
    read -p "请选择选项 (1-8): " choice
    
    case $choice in
        1)
            check_azure_cli
            ;;
        2)
            read -p "资源组名称: " rg
            read -p "应用名称: " app
            check_app_status "$rg" "$app"
            ;;
        3)
            read -p "资源组名称: " rg
            read -p "应用名称: " app
            check_app_logs "$rg" "$app"
            ;;
        4)
            read -p "资源组名称: " rg
            read -p "应用名称: " app
            check_deployment_config "$rg" "$app"
            ;;
        5)
            read -p "资源组名称: " rg
            read -p "应用名称: " app
            fix_common_issues "$rg" "$app"
            ;;
        6)
            read -p "资源组名称: " rg
            read -p "应用名称: " app
            performance_diagnostic "$rg" "$app"
            ;;
        7)
            read -p "资源组名称: " rg
            read -p "应用名称: " app
            echo "🔍 开始全面诊断..."
            check_azure_cli
            check_app_status "$rg" "$app"
            check_deployment_config "$rg" "$app"
            check_app_logs "$rg" "$app"
            performance_diagnostic "$rg" "$app"
            ;;
        8)
            echo "退出故障排除工具"
            exit 0
            ;;
        *)
            echo "无效选项，请重新选择"
            ;;
    esac
}

# 主程序
main() {
    # 检查基本工具
    if ! command -v curl &> /dev/null; then
        print_error "curl 未安装，某些功能可能不可用"
    fi
    
    if [ $# -eq 0 ]; then
        # 交互模式
        while true; do
            show_menu
        done
    else
        # 命令行模式
        case $1 in
            "check-cli")
                check_azure_cli
                ;;
            "check-app")
                check_app_status "$2" "$3"
                ;;
            "check-logs")
                check_app_logs "$2" "$3"
                ;;
            "check-config")
                check_deployment_config "$2" "$3"
                ;;
            "fix-issues")
                fix_common_issues "$2" "$3"
                ;;
            "performance")
                performance_diagnostic "$2" "$3"
                ;;
            "full-diagnostic")
                check_azure_cli
                check_app_status "$2" "$3"
                check_deployment_config "$2" "$3"
                check_app_logs "$2" "$3"
                performance_diagnostic "$2" "$3"
                ;;
            *)
                echo "用法: $0 [check-cli|check-app|check-logs|check-config|fix-issues|performance|full-diagnostic] [资源组] [应用名]"
                echo "或者运行 $0 进入交互模式"
                exit 1
                ;;
        esac
    fi
}

# 脚本入口
main "$@"
