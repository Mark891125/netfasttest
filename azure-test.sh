#!/bin/bash

echo "🧪 Azure Web App 健康检查和测试工具"
echo "==================================="
echo "版本: 1.0"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# 函数定义
print_status() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_test() { echo -e "${PURPLE}🧪 $1${NC}"; }

# 基本健康检查
basic_health_check() {
    local APP_URL=$1
    
    print_test "基本健康检查: $APP_URL"
    
    # HTTP状态检查
    local HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" "https://$APP_URL" --max-time 30)
    local RESPONSE_TIME=$(curl -o /dev/null -s -w "%{time_total}" "https://$APP_URL" --max-time 30)
    
    if [ "$HTTP_STATUS" = "200" ]; then
        print_status "HTTP状态检查通过 (200)"
        print_info "响应时间: ${RESPONSE_TIME}s"
    else
        print_error "HTTP状态检查失败: $HTTP_STATUS"
        return 1
    fi
    
    return 0
}

# API功能测试
api_functional_test() {
    local APP_URL=$1
    
    print_test "API功能测试"
    
    # 测试API端点
    echo "  - 测试 /api/speed-test 端点..."
    local API_STATUS=$(curl -o /dev/null -s -w "%{http_code}" "https://$APP_URL/api/speed-test" --max-time 30)
    
    if [ "$API_STATUS" = "200" ]; then
        print_status "API端点可访问"
    else
        print_warning "API端点状态码: $API_STATUS"
    fi
    
    # 测试API功能
    echo "  - 测试API功能..."
    local API_RESPONSE=$(curl -s -X POST "https://$APP_URL/api/speed-test" \
        -H "Content-Type: application/json" \
        -d '{"test": "health-check"}' \
        --max-time 30)
    
    if echo "$API_RESPONSE" | grep -q "success.*true"; then
        print_status "API功能测试通过"
    else
        print_warning "API功能测试结果: $API_RESPONSE"
    fi
}

# 性能测试
performance_test() {
    local APP_URL=$1
    local TEST_COUNT=${2:-5}
    
    print_test "性能测试 (${TEST_COUNT}次)"
    
    local TOTAL_TIME=0
    local SUCCESS_COUNT=0
    
    for i in $(seq 1 $TEST_COUNT); do
        echo "  - 测试 $i/$TEST_COUNT..."
        
        local START_TIME=$(date +%s.%N)
        local HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" "https://$APP_URL" --max-time 30)
        local END_TIME=$(date +%s.%N)
        
        if [ "$HTTP_STATUS" = "200" ]; then
            local RESPONSE_TIME=$(echo "$END_TIME - $START_TIME" | bc)
            TOTAL_TIME=$(echo "$TOTAL_TIME + $RESPONSE_TIME" | bc)
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            echo "    响应时间: ${RESPONSE_TIME}s"
        else
            print_warning "    请求失败: $HTTP_STATUS"
        fi
        
        sleep 1
    done
    
    if [ $SUCCESS_COUNT -gt 0 ]; then
        local AVG_TIME=$(echo "scale=3; $TOTAL_TIME / $SUCCESS_COUNT" | bc)
        print_status "性能测试完成"
        print_info "成功率: $SUCCESS_COUNT/$TEST_COUNT"
        print_info "平均响应时间: ${AVG_TIME}s"
    else
        print_error "所有性能测试均失败"
        return 1
    fi
}

# 负载测试
load_test() {
    local APP_URL=$1
    local CONCURRENT_USERS=${2:-10}
    local DURATION=${3:-30}
    
    print_test "负载测试 (${CONCURRENT_USERS}并发用户，${DURATION}秒)"
    
    # 检查ab命令是否可用
    if ! command -v ab &> /dev/null; then
        print_warning "Apache Bench (ab) 未安装，跳过负载测试"
        print_info "安装方法: sudo apt-get install apache2-utils (Ubuntu) 或 brew install apache2 (macOS)"
        return 0
    fi
    
    local TOTAL_REQUESTS=$((CONCURRENT_USERS * DURATION))
    
    echo "  - 执行负载测试..."
    local AB_RESULT=$(ab -n $TOTAL_REQUESTS -c $CONCURRENT_USERS "https://$APP_URL/" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        print_status "负载测试完成"
        
        # 解析结果
        local REQUESTS_PER_SEC=$(echo "$AB_RESULT" | grep "Requests per second" | awk '{print $4}')
        local TIME_PER_REQUEST=$(echo "$AB_RESULT" | grep "Time per request.*mean" | head -1 | awk '{print $4}')
        local FAILED_REQUESTS=$(echo "$AB_RESULT" | grep "Failed requests" | awk '{print $3}')
        
        print_info "每秒请求数: $REQUESTS_PER_SEC"
        print_info "平均请求时间: ${TIME_PER_REQUEST}ms"
        print_info "失败请求数: $FAILED_REQUESTS"
    else
        print_error "负载测试失败"
        return 1
    fi
}

# 端到端功能测试
e2e_functional_test() {
    local APP_URL=$1
    
    print_test "端到端功能测试"
    
    # 1. 首页加载测试
    echo "  - 测试首页加载..."
    local HOME_RESPONSE=$(curl -s "https://$APP_URL" --max-time 30)
    
    if echo "$HOME_RESPONSE" | grep -q "网络速度测试"; then
        print_status "首页加载正常"
    else
        print_warning "首页内容可能异常"
    fi
    
    # 2. API综合测试
    echo "  - 测试网络速度检测API..."
    local SPEED_TEST_RESPONSE=$(curl -s -X POST "https://$APP_URL/api/speed-test" \
        -H "Content-Type: application/json" \
        -d '{"testSize": 1024}' \
        --max-time 60)
    
    if echo "$SPEED_TEST_RESPONSE" | grep -q '"success":true'; then
        print_status "速度测试API正常"
        
        # 检查返回的数据字段
        if echo "$SPEED_TEST_RESPONSE" | grep -q '"ip":\|"location":\|"responseTime":'; then
            print_status "API返回数据完整"
        else
            print_warning "API返回数据可能不完整"
        fi
    else
        print_warning "速度测试API响应: $SPEED_TEST_RESPONSE"
    fi
    
    # 3. 错误处理测试
    echo "  - 测试错误处理..."
    local ERROR_RESPONSE=$(curl -s -X POST "https://$APP_URL/api/speed-test" \
        -H "Content-Type: application/json" \
        -d '{"invalid": "data"}' \
        --max-time 30)
    
    if echo "$ERROR_RESPONSE" | grep -q '"success":false\|"error":'; then
        print_status "错误处理正常"
    else
        print_warning "错误处理可能异常"
    fi
}

# 安全测试
security_test() {
    local APP_URL=$1
    
    print_test "安全测试"
    
    # 检查安全头部
    echo "  - 检查安全头部..."
    local HEADERS=$(curl -s -I "https://$APP_URL" --max-time 30)
    
    local SECURITY_HEADERS=(
        "X-Content-Type-Options"
        "X-Frame-Options"
        "X-XSS-Protection"
    )
    
    for HEADER in "${SECURITY_HEADERS[@]}"; do
        if echo "$HEADERS" | grep -qi "$HEADER"; then
            print_status "$HEADER 头部存在"
        else
            print_warning "$HEADER 头部缺失"
        fi
    done
    
    # 检查HTTPS重定向
    echo "  - 检查HTTPS重定向..."
    local HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" "http://$APP_URL" --max-time 30)
    
    if [ "$HTTP_STATUS" = "301" ] || [ "$HTTP_STATUS" = "302" ]; then
        print_status "HTTP到HTTPS重定向正常"
    else
        print_warning "HTTP重定向状态: $HTTP_STATUS"
    fi
}

# 生成测试报告
generate_test_report() {
    local APP_URL=$1
    local REPORT_FILE="azure-health-check-$(date +%Y%m%d-%H%M%S).txt"
    
    print_info "生成测试报告: $REPORT_FILE"
    
    cat > $REPORT_FILE << EOF
🧪 Azure Web App 健康检查报告
=============================
测试时间: $(date)
应用URL: https://$APP_URL

📋 测试摘要:
EOF
    
    # 重新运行所有测试并记录结果
    echo "重新执行所有测试..."
    
    {
        echo ""
        echo "1. 基本健康检查:"
        basic_health_check "$APP_URL" && echo "   ✅ 通过" || echo "   ❌ 失败"
        
        echo ""
        echo "2. API功能测试:"
        api_functional_test "$APP_URL" && echo "   ✅ 通过" || echo "   ❌ 失败"
        
        echo ""
        echo "3. 性能测试:"
        performance_test "$APP_URL" 3 && echo "   ✅ 通过" || echo "   ❌ 失败"
        
        echo ""
        echo "4. 端到端功能测试:"
        e2e_functional_test "$APP_URL" && echo "   ✅ 通过" || echo "   ❌ 失败"
        
        echo ""
        echo "5. 安全测试:"
        security_test "$APP_URL" && echo "   ✅ 通过" || echo "   ❌ 失败"
        
        echo ""
        echo "📊 测试详情请查看上方输出"
        echo ""
        echo "🔗 相关链接:"
        echo "- 应用主页: https://$APP_URL"
        echo "- API测试: https://$APP_URL/api/speed-test"
        echo "- Azure门户: https://portal.azure.com"
        
    } >> $REPORT_FILE
    
    print_status "测试报告已生成: $REPORT_FILE"
}

# 主函数
main() {
    if [ $# -eq 0 ]; then
        echo "用法: $0 <应用URL> [选项]"
        echo ""
        echo "选项:"
        echo "  all          - 执行所有测试 (默认)"
        echo "  basic        - 仅执行基本健康检查"
        echo "  api          - 仅执行API功能测试"
        echo "  performance  - 仅执行性能测试"
        echo "  load         - 仅执行负载测试"
        echo "  e2e          - 仅执行端到端测试"
        echo "  security     - 仅执行安全测试"
        echo "  report       - 生成完整测试报告"
        echo ""
        echo "示例:"
        echo "  $0 myapp.azurewebsites.net all"
        echo "  $0 myapp.azurewebsites.net performance"
        exit 1
    fi
    
    local APP_URL=$1
    local TEST_TYPE=${2:-all}
    
    # 移除协议前缀（如果存在）
    APP_URL=$(echo "$APP_URL" | sed 's|https\?://||')
    
    echo "🎯 目标应用: https://$APP_URL"
    echo "📋 测试类型: $TEST_TYPE"
    echo ""
    
    case $TEST_TYPE in
        "basic")
            basic_health_check "$APP_URL"
            ;;
        "api")
            api_functional_test "$APP_URL"
            ;;
        "performance")
            performance_test "$APP_URL" 5
            ;;
        "load")
            load_test "$APP_URL" 10 30
            ;;
        "e2e")
            e2e_functional_test "$APP_URL"
            ;;
        "security")
            security_test "$APP_URL"
            ;;
        "report")
            generate_test_report "$APP_URL"
            ;;
        "all"|*)
            echo "🚀 开始完整测试套件..."
            echo ""
            
            basic_health_check "$APP_URL"
            echo ""
            
            api_functional_test "$APP_URL"
            echo ""
            
            performance_test "$APP_URL" 5
            echo ""
            
            load_test "$APP_URL" 5 15
            echo ""
            
            e2e_functional_test "$APP_URL"
            echo ""
            
            security_test "$APP_URL"
            echo ""
            
            print_status "所有测试完成!"
            
            # 询问是否生成报告
            read -p "是否生成详细测试报告? (y/N): " generate_report
            if [[ $generate_report == [yY] ]]; then
                generate_test_report "$APP_URL"
            fi
            ;;
    esac
}

# 脚本入口
main "$@"
