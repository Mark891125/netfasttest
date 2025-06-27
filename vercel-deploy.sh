#!/bin/bash

# Vercel 快速部署脚本
# 用途：快速部署和排查 Next.js 应用到 Vercel

set -e

echo "🚀 Vercel 快速部署脚本启动..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查必需工具
check_requirements() {
    echo -e "${BLUE}📋 检查部署环境...${NC}"
    
    # 检查Node.js版本
    if ! command -v node &> /dev/null; then
        echo -e "${RED}❌ Node.js 未安装${NC}"
        exit 1
    fi
    
    NODE_VERSION=$(node --version | sed 's/v//')
    echo -e "${GREEN}✅ Node.js: ${NODE_VERSION}${NC}"
    
    # 检查npm
    if ! command -v npm &> /dev/null; then
        echo -e "${RED}❌ npm 未安装${NC}"
        exit 1
    fi
    
    NPM_VERSION=$(npm --version)
    echo -e "${GREEN}✅ npm: ${NPM_VERSION}${NC}"
    
    # 检查git
    if ! command -v git &> /dev/null; then
        echo -e "${RED}❌ git 未安装${NC}"
        exit 1
    fi
}

# 安装Vercel CLI
install_vercel_cli() {
    echo -e "${BLUE}📦 检查 Vercel CLI...${NC}"
    
    if ! command -v vercel &> /dev/null; then
        echo -e "${YELLOW}⚠️  Vercel CLI 未安装，正在安装...${NC}"
        npm install -g vercel
    else
        VERCEL_VERSION=$(vercel --version)
        echo -e "${GREEN}✅ Vercel CLI: ${VERCEL_VERSION}${NC}"
    fi
}

# 检查项目配置
check_project_config() {
    echo -e "${BLUE}🔍 检查项目配置...${NC}"
    
    # 检查package.json
    if [[ ! -f "package.json" ]]; then
        echo -e "${RED}❌ package.json 不存在${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ package.json 存在${NC}"
    
    # 检查Next.js配置
    if [[ ! -f "next.config.ts" ]] && [[ ! -f "next.config.js" ]]; then
        echo -e "${YELLOW}⚠️  Next.js 配置文件不存在${NC}"
    else
        echo -e "${GREEN}✅ Next.js 配置文件存在${NC}"
    fi
    
    # 检查vercel.json
    if [[ ! -f "vercel.json" ]]; then
        echo -e "${YELLOW}⚠️  vercel.json 不存在，将使用默认配置${NC}"
    else
        echo -e "${GREEN}✅ vercel.json 存在${NC}"
    fi
    
    # 检查app目录结构
    if [[ -d "app" ]]; then
        echo -e "${GREEN}✅ 使用 App Router 结构${NC}"
    elif [[ -d "pages" ]]; then
        echo -e "${GREEN}✅ 使用 Pages Router 结构${NC}"
    else
        echo -e "${RED}❌ 未找到有效的 Next.js 路由结构${NC}"
        exit 1
    fi
}

# 安装依赖
install_dependencies() {
    echo -e "${BLUE}📦 安装项目依赖...${NC}"
    
    if [[ -f "package-lock.json" ]]; then
        npm ci
    elif [[ -f "yarn.lock" ]]; then
        yarn install --frozen-lockfile
    elif [[ -f "pnpm-lock.yaml" ]]; then
        pnpm install --frozen-lockfile
    elif [[ -f "bun.lockb" ]]; then
        bun install --frozen-lockfile
    else
        npm install
    fi
    
    echo -e "${GREEN}✅ 依赖安装完成${NC}"
}

# 本地构建测试
test_build() {
    echo -e "${BLUE}🔨 本地构建测试...${NC}"
    
    npm run build
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ 本地构建成功${NC}"
    else
        echo -e "${RED}❌ 本地构建失败${NC}"
        exit 1
    fi
}

# Vercel登录
vercel_login() {
    echo -e "${BLUE}🔐 检查 Vercel 登录状态...${NC}"
    
    if ! vercel whoami &> /dev/null; then
        echo -e "${YELLOW}⚠️  未登录 Vercel，请登录...${NC}"
        vercel login
    else
        USER=$(vercel whoami)
        echo -e "${GREEN}✅ 已登录 Vercel: ${USER}${NC}"
    fi
}

# 部署到Vercel
deploy_to_vercel() {
    echo -e "${BLUE}🚀 部署到 Vercel...${NC}"
    
    # 生产环境部署
    vercel --prod
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Vercel 部署成功${NC}"
        
        # 获取部署URL
        URL=$(vercel ls --meta url | head -1)
        echo -e "${GREEN}🌐 部署地址: ${URL}${NC}"
        
        # 测试部署
        test_deployment "$URL"
    else
        echo -e "${RED}❌ Vercel 部署失败${NC}"
        echo -e "${YELLOW}💡 查看部署日志: vercel logs${NC}"
        exit 1
    fi
}

# 测试部署
test_deployment() {
    local url=$1
    echo -e "${BLUE}🧪 测试部署...${NC}"
    
    # 测试首页
    echo -e "${YELLOW}测试首页...${NC}"
    if curl -s -f "$url" > /dev/null; then
        echo -e "${GREEN}✅ 首页访问正常${NC}"
    else
        echo -e "${RED}❌ 首页访问失败${NC}"
    fi
    
    # 测试API
    echo -e "${YELLOW}测试API...${NC}"
    if curl -s -f "$url/api/speed-test" > /dev/null; then
        echo -e "${GREEN}✅ API 访问正常${NC}"
    else
        echo -e "${RED}❌ API 访问失败${NC}"
        echo -e "${YELLOW}💡 检查API路由配置${NC}"
    fi
}

# 网络连接测试
test_network() {
    echo -e "${BLUE}🌐 网络连接测试...${NC}"
    
    # 测试DNS解析
    echo -e "${YELLOW}测试DNS解析...${NC}"
    if nslookup vercel.com > /dev/null 2>&1; then
        echo -e "${GREEN}✅ DNS解析正常${NC}"
    else
        echo -e "${RED}❌ DNS解析失败${NC}"
        echo -e "${YELLOW}💡 尝试更换DNS: 8.8.8.8${NC}"
    fi
    
    # 测试Vercel连通性
    echo -e "${YELLOW}测试Vercel连通性...${NC}"
    if curl -s -f https://vercel.com > /dev/null; then
        echo -e "${GREEN}✅ Vercel连通性正常${NC}"
    else
        echo -e "${RED}❌ 无法连接到Vercel${NC}"
        echo -e "${YELLOW}💡 检查网络防火墙设置${NC}"
    fi
}

# 主函数
main() {
    echo -e "${GREEN}🎯 开始 Vercel 快速部署流程${NC}"
    
    check_requirements
    test_network
    install_vercel_cli
    check_project_config
    install_dependencies
    test_build
    vercel_login
    deploy_to_vercel
    
    echo -e "${GREEN}🎉 Vercel 部署流程完成！${NC}"
    echo -e "${BLUE}📚 如遇问题，请查看: VERCEL-TROUBLESHOOTING.md${NC}"
}

# 脚本选项
case "$1" in
    "test")
        test_network
        ;;
    "build")
        install_dependencies
        test_build
        ;;
    "deploy")
        vercel_login
        deploy_to_vercel
        ;;
    *)
        main
        ;;
esac
