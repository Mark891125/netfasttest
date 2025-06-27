#!/bin/bash

# Vercel 部署前检查脚本
# 用途：在部署前验证配置和修复常见问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔍 Vercel 部署前检查开始...${NC}"

# 检查Node.js版本
check_node_version() {
    echo -e "${BLUE}📋 检查 Node.js 版本...${NC}"
    
    NODE_VERSION=$(node --version | sed 's/v//')
    MAJOR_VERSION=$(echo $NODE_VERSION | cut -d. -f1)
    
    if [[ $MAJOR_VERSION -ge 18 ]]; then
        echo -e "${GREEN}✅ Node.js 版本: v${NODE_VERSION} (支持)${NC}"
    else
        echo -e "${RED}❌ Node.js 版本过低: v${NODE_VERSION}${NC}"
        echo -e "${YELLOW}💡 请升级到 Node.js 18+ 或 20 LTS${NC}"
        exit 1
    fi
}

# 检查package.json
check_package_json() {
    echo -e "${BLUE}📦 检查 package.json...${NC}"
    
    if [[ ! -f "package.json" ]]; then
        echo -e "${RED}❌ package.json 不存在${NC}"
        exit 1
    fi
    
    # 检查必需的脚本
    if ! jq -e '.scripts.build' package.json >/dev/null 2>&1; then
        echo -e "${RED}❌ 缺少 build 脚本${NC}"
        exit 1
    fi
    
    if ! jq -e '.scripts.start' package.json >/dev/null 2>&1; then
        echo -e "${RED}❌ 缺少 start 脚本${NC}"
        exit 1
    fi
    
    # 检查Next.js依赖
    if ! jq -e '.dependencies.next' package.json >/dev/null 2>&1; then
        echo -e "${RED}❌ 未找到 Next.js 依赖${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ package.json 配置正确${NC}"
}

# 检查Next.js配置
check_nextjs_config() {
    echo -e "${BLUE}⚙️  检查 Next.js 配置...${NC}"
    
    if [[ -f "next.config.ts" ]]; then
        echo -e "${GREEN}✅ 找到 next.config.ts${NC}"
        
        # 检查deprecated配置
        if grep -q "serverComponentsExternalPackages" next.config.ts; then
            echo -e "${YELLOW}⚠️  检测到已弃用的配置: serverComponentsExternalPackages${NC}"
            echo -e "${YELLOW}💡 建议更新为: serverExternalPackages${NC}"
        fi
        
    elif [[ -f "next.config.js" ]]; then
        echo -e "${GREEN}✅ 找到 next.config.js${NC}"
    else
        echo -e "${YELLOW}⚠️  未找到 Next.js 配置文件（将使用默认配置）${NC}"
    fi
}

# 检查vercel.json配置
check_vercel_config() {
    echo -e "${BLUE}🔧 检查 vercel.json 配置...${NC}"
    
    if [[ ! -f "vercel.json" ]]; then
        echo -e "${YELLOW}⚠️  vercel.json 不存在，将使用默认配置${NC}"
        return 0
    fi
    
    # 验证JSON语法
    if ! jq empty vercel.json >/dev/null 2>&1; then
        echo -e "${RED}❌ vercel.json 语法错误${NC}"
        echo -e "${YELLOW}💡 请检查JSON格式是否正确${NC}"
        exit 1
    fi
    
    # 检查builds和functions冲突
    if jq -e '.builds and .functions' vercel.json >/dev/null 2>&1; then
        echo -e "${RED}❌ vercel.json 同时包含 builds 和 functions 属性${NC}"
        echo -e "${YELLOW}💡 正在自动修复...${NC}"
        
        # 创建备份
        cp vercel.json vercel.json.backup
        
        # 移除builds属性
        jq 'del(.builds)' vercel.json > vercel.json.tmp && mv vercel.json.tmp vercel.json
        
        echo -e "${GREEN}✅ 已移除 builds 属性${NC}"
        echo -e "${BLUE}📄 原配置已备份为 vercel.json.backup${NC}"
    fi
    
    # 检查版本号
    if jq -e '.version == 2' vercel.json >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  检测到 version: 2，建议移除此属性${NC}"
        echo -e "${YELLOW}💡 Vercel会自动使用最新版本${NC}"
    fi
    
    echo -e "${GREEN}✅ vercel.json 配置正确${NC}"
}

# 检查API路由
check_api_routes() {
    echo -e "${BLUE}🌐 检查 API 路由...${NC}"
    
    if [[ -d "app/api" ]]; then
        echo -e "${GREEN}✅ 找到 App Router API 目录${NC}"
        
        # 检查speed-test API
        if [[ -f "app/api/speed-test/route.ts" ]]; then
            echo -e "${GREEN}✅ speed-test API 路由存在${NC}"
        else
            echo -e "${YELLOW}⚠️  未找到 speed-test API 路由${NC}"
        fi
        
    elif [[ -d "pages/api" ]]; then
        echo -e "${GREEN}✅ 找到 Pages Router API 目录${NC}"
    else
        echo -e "${YELLOW}⚠️  未找到 API 路由目录${NC}"
    fi
}

# 本地构建测试
test_build() {
    echo -e "${BLUE}🔨 执行本地构建测试...${NC}"
    
    # 清理之前的构建
    if [[ -d ".next" ]]; then
        rm -rf .next
    fi
    
    # 执行构建
    if npm run build; then
        echo -e "${GREEN}✅ 本地构建成功${NC}"
    else
        echo -e "${RED}❌ 本地构建失败${NC}"
        echo -e "${YELLOW}💡 请先修复构建错误再进行部署${NC}"
        exit 1
    fi
}

# 检查环境变量
check_env_vars() {
    echo -e "${BLUE}🔐 检查环境变量...${NC}"
    
    if [[ -f ".env.local" ]]; then
        echo -e "${GREEN}✅ 找到 .env.local${NC}"
    elif [[ -f ".env" ]]; then
        echo -e "${GREEN}✅ 找到 .env${NC}"
    else
        echo -e "${YELLOW}⚠️  未找到环境变量文件（如不需要可忽略）${NC}"
    fi
    
    # 检查是否有敏感信息
    if [[ -f ".env.local" ]]; then
        if grep -q "API_KEY\|SECRET\|PASSWORD" .env.local; then
            echo -e "${YELLOW}⚠️  检测到敏感信息，请确保在Vercel中正确配置环境变量${NC}"
        fi
    fi
}

# 网络连通性测试
test_vercel_connectivity() {
    echo -e "${BLUE}🌐 测试 Vercel 连通性...${NC}"
    
    if curl -s --connect-timeout 5 https://vercel.com >/dev/null; then
        echo -e "${GREEN}✅ Vercel 连通性正常${NC}"
    else
        echo -e "${RED}❌ 无法连接到 Vercel${NC}"
        echo -e "${YELLOW}💡 请检查网络连接或使用VPN/代理${NC}"
        return 1
    fi
}

# 生成部署建议
generate_suggestions() {
    echo -e "${BLUE}💡 部署建议:${NC}"
    echo "1. 确保选择合适的区域（亚洲用户建议：hkg1香港, sin1新加坡）"
    echo "2. 监控首次部署的冷启动时间"
    echo "3. 部署后使用 test-vercel-performance.sh 测试性能"
    echo "4. 如遇网络问题，可考虑 Azure 或 ECS 部署方案"
    echo ""
}

# 主检查流程
main() {
    echo -e "${GREEN}🚀 开始部署前检查...${NC}"
    echo ""
    
    check_node_version
    echo ""
    
    check_package_json
    echo ""
    
    check_nextjs_config
    echo ""
    
    check_vercel_config
    echo ""
    
    check_api_routes
    echo ""
    
    check_env_vars
    echo ""
    
    test_build
    echo ""
    
    test_vercel_connectivity
    echo ""
    
    generate_suggestions
    
    echo -e "${GREEN}✅ 部署前检查完成！${NC}"
    echo -e "${BLUE}🚀 现在可以安全地执行: vercel --prod${NC}"
}

# 脚本选项
case "$1" in
    "config")
        check_vercel_config
        ;;
    "build")
        test_build
        ;;
    "network")
        test_vercel_connectivity
        ;;
    *)
        main
        ;;
esac
