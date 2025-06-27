#!/bin/bash

# Vercel 性能测试脚本
# 用途：测试Vercel部署的性能和可用性

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认测试URL
VERCEL_URL="https://netfasttest.vercel.app"
TEST_COUNT=5

# 显示帮助信息
show_help() {
    echo "Vercel性能测试脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -u, --url URL        指定测试URL (默认: $VERCEL_URL)"
    echo "  -c, --count NUM      测试次数 (默认: $TEST_COUNT)"
    echo "  -h, --help           显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0                              # 使用默认设置测试"
    echo "  $0 -u https://example.com       # 测试指定URL"
    echo "  $0 -c 10                        # 执行10次测试"
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--url)
            VERCEL_URL="$2"
            shift 2
            ;;
        -c|--count)
            TEST_COUNT="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}未知选项: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

echo -e "${GREEN}🚀 Vercel性能测试开始${NC}"
echo -e "${BLUE}测试URL: $VERCEL_URL${NC}"
echo -e "${BLUE}测试次数: $TEST_COUNT${NC}"
echo ""

# 检查必需工具
check_tools() {
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}❌ curl 未安装${NC}"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}⚠️  jq 未安装，将跳过JSON解析${NC}"
    fi
}

# DNS解析测试
test_dns() {
    echo -e "${BLUE}🔍 DNS解析测试${NC}"
    
    # 提取域名
    DOMAIN=$(echo "$VERCEL_URL" | sed 's|https\?://||' | cut -d'/' -f1)
    
    DNS_START=$(date +%s%3N)
    DNS_RESULT=$(nslookup "$DOMAIN" 2>/dev/null | grep "Address:" | tail -1 | awk '{print $2}')
    DNS_END=$(date +%s%3N)
    DNS_TIME=$((DNS_END - DNS_START))
    
    if [[ -n "$DNS_RESULT" ]]; then
        echo -e "${GREEN}✅ DNS解析成功: $DNS_RESULT (${DNS_TIME}ms)${NC}"
    else
        echo -e "${RED}❌ DNS解析失败${NC}"
        return 1
    fi
}

# 连通性测试
test_connectivity() {
    echo -e "${BLUE}🌐 连通性测试${NC}"
    
    # HTTP状态码测试
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$VERCEL_URL" --connect-timeout 10 --max-time 30)
    
    if [[ "$HTTP_CODE" == "200" ]]; then
        echo -e "${GREEN}✅ HTTP连接成功 (状态码: $HTTP_CODE)${NC}"
    else
        echo -e "${RED}❌ HTTP连接失败 (状态码: $HTTP_CODE)${NC}"
        return 1
    fi
}

# 首页性能测试
test_homepage() {
    echo -e "${BLUE}🏠 首页性能测试${NC}"
    
    local total_time=0
    local success_count=0
    
    for ((i=1; i<=TEST_COUNT; i++)); do
        echo -e "${YELLOW}测试 $i/$TEST_COUNT...${NC}"
        
        # 使用curl测试性能
        RESULT=$(curl -w "@curl-format.txt" -s -o /dev/null "$VERCEL_URL" 2>/dev/null)
        
        if [[ $? -eq 0 ]]; then
            TIME_TOTAL=$(echo "$RESULT" | grep "time_total" | awk '{print $2}')
            TIME_CONNECT=$(echo "$RESULT" | grep "time_connect" | awk '{print $2}')
            TIME_STARTTRANSFER=$(echo "$RESULT" | grep "time_starttransfer" | awk '{print $2}')
            SIZE_DOWNLOAD=$(echo "$RESULT" | grep "size_download" | awk '{print $2}')
            
            echo -e "  连接时间: ${TIME_CONNECT}s, 首字节时间: ${TIME_STARTTRANSFER}s, 总时间: ${TIME_TOTAL}s, 大小: ${SIZE_DOWNLOAD}字节"
            
            total_time=$(echo "$total_time + $TIME_TOTAL" | bc -l)
            ((success_count++))
        else
            echo -e "${RED}  ❌ 测试失败${NC}"
        fi
        
        sleep 1
    done
    
    if [[ $success_count -gt 0 ]]; then
        avg_time=$(echo "scale=3; $total_time / $success_count" | bc -l)
        echo -e "${GREEN}📊 首页平均响应时间: ${avg_time}s (成功率: $success_count/$TEST_COUNT)${NC}"
    else
        echo -e "${RED}❌ 所有首页测试均失败${NC}"
        return 1
    fi
}

# API性能测试
test_api() {
    echo -e "${BLUE}🔧 API性能测试${NC}"
    
    API_URL="$VERCEL_URL/api/speed-test"
    local total_time=0
    local success_count=0
    
    for ((i=1; i<=TEST_COUNT; i++)); do
        echo -e "${YELLOW}API测试 $i/$TEST_COUNT...${NC}"
        
        # 测试API响应时间
        START_TIME=$(date +%s%3N)
        RESPONSE=$(curl -s "$API_URL" --connect-timeout 10 --max-time 30)
        END_TIME=$(date +%s%3N)
        
        if [[ $? -eq 0 ]] && [[ -n "$RESPONSE" ]]; then
            RESPONSE_TIME=$((END_TIME - START_TIME))
            
            # 尝试解析JSON响应
            if command -v jq &> /dev/null; then
                API_RESPONSE_TIME=$(echo "$RESPONSE" | jq -r '.responseTime' 2>/dev/null || echo "N/A")
                echo -e "  客户端延迟: ${RESPONSE_TIME}ms, API报告延迟: ${API_RESPONSE_TIME}ms"
            else
                echo -e "  客户端延迟: ${RESPONSE_TIME}ms"
            fi
            
            total_time=$((total_time + RESPONSE_TIME))
            ((success_count++))
        else
            echo -e "${RED}  ❌ API测试失败${NC}"
        fi
        
        sleep 1
    done
    
    if [[ $success_count -gt 0 ]]; then
        avg_time=$((total_time / success_count))
        echo -e "${GREEN}📊 API平均响应时间: ${avg_time}ms (成功率: $success_count/$TEST_COUNT)${NC}"
    else
        echo -e "${RED}❌ 所有API测试均失败${NC}"
        return 1
    fi
}

# 负载测试
test_load() {
    echo -e "${BLUE}⚡ 简单负载测试${NC}"
    
    # 并发请求测试
    echo -e "${YELLOW}执行5个并发请求...${NC}"
    
    for i in {1..5}; do
        (
            START=$(date +%s%3N)
            curl -s "$VERCEL_URL" > /dev/null
            END=$(date +%s%3N)
            TIME=$((END - START))
            echo "并发请求 $i: ${TIME}ms"
        ) &
    done
    
    wait
    echo -e "${GREEN}✅ 并发测试完成${NC}"
}

# SSL证书检查
test_ssl() {
    echo -e "${BLUE}🔒 SSL证书检查${NC}"
    
    DOMAIN=$(echo "$VERCEL_URL" | sed 's|https\?://||' | cut -d'/' -f1)
    
    # 检查SSL证书
    SSL_INFO=$(echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ SSL证书有效${NC}"
        echo "$SSL_INFO" | sed 's/^/  /'
    else
        echo -e "${RED}❌ SSL证书检查失败${NC}"
    fi
}

# 地理位置性能测试
test_geo_performance() {
    echo -e "${BLUE}🌍 地理位置性能测试${NC}"
    
    # 测试多个地理位置的延迟
    REGIONS=("香港" "新加坡" "东京" "首尔")
    
    for region in "${REGIONS[@]}"; do
        echo -e "${YELLOW}测试从 $region 的访问性能...${NC}"
        
        # 使用不同的DNS服务器模拟不同地区
        case $region in
            "香港")
                DNS="8.8.8.8"
                ;;
            "新加坡") 
                DNS="1.1.1.1"
                ;;
            "东京")
                DNS="208.67.222.222"
                ;;
            "首尔")
                DNS="114.114.114.114"
                ;;
        esac
        
        # 使用指定DNS进行测试
        RESULT=$(curl -w "%{time_total}" -s -o /dev/null --dns-servers "$DNS" "$VERCEL_URL" 2>/dev/null)
        
        if [[ $? -eq 0 ]]; then
            echo -e "  $region 响应时间: ${RESULT}s"
        else
            echo -e "${RED}  $region 测试失败${NC}"
        fi
    done
}

# 生成测试报告
generate_report() {
    echo ""
    echo -e "${GREEN}📋 测试报告总结${NC}"
    echo "========================="
    echo "测试时间: $(date)"
    echo "测试URL: $VERCEL_URL"
    echo "测试次数: $TEST_COUNT"
    echo ""
    echo -e "${BLUE}建议:${NC}"
    echo "1. 如果响应时间 > 2秒，考虑优化代码或配置"
    echo "2. 如果成功率 < 100%，检查网络稳定性"
    echo "3. 定期运行此测试监控性能变化"
    echo ""
    echo -e "${YELLOW}💡 优化建议:${NC}"
    echo "- 使用Vercel的Edge Functions提升性能"
    echo "- 启用静态文件缓存"
    echo "- 优化API响应大小"
    echo "- 选择离用户最近的部署区域"
}

# 主测试流程
main() {
    check_tools
    
    echo -e "${GREEN}开始性能测试...${NC}"
    echo ""
    
    # 依次执行各项测试
    test_dns || echo -e "${RED}DNS测试失败，继续其他测试...${NC}"
    echo ""
    
    test_connectivity || { echo -e "${RED}连通性测试失败，停止后续测试${NC}"; exit 1; }
    echo ""
    
    test_ssl
    echo ""
    
    test_homepage
    echo ""
    
    test_api
    echo ""
    
    test_load
    echo ""
    
    test_geo_performance
    echo ""
    
    generate_report
    
    echo -e "${GREEN}🎉 性能测试完成！${NC}"
}

# 运行主程序
main
