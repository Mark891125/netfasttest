#!/bin/bash

echo "🚀 ECS服务器自动部署脚本"
echo "========================="
echo "版本: 1.0"
echo "适用于: Ubuntu 20.04/22.04, CentOS 8/9"
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
print_step() { echo -e "${PURPLE}🔄 $1${NC}"; }

# 配置变量
APP_NAME="netfasttest"
APP_DIR="/home/$APP_NAME/apps/$APP_NAME"
NGINX_SITE="/etc/nginx/sites-available/$APP_NAME"
NODE_VERSION="20"
PORT="3000"

# 检测操作系统
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        print_error "无法检测操作系统"
        exit 1
    fi
    
    print_info "检测到操作系统: $OS $VER"
}

# 检查是否为root用户
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "请使用root用户运行此脚本"
        exit 1
    fi
}

# 更新系统包
update_system() {
    print_step "更新系统包..."
    
    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        apt update && apt upgrade -y
        apt install -y curl wget git unzip build-essential software-properties-common
    elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then
        yum update -y
        yum install -y curl wget git unzip gcc gcc-c++ make epel-release
    else
        print_error "不支持的操作系统: $OS"
        exit 1
    fi
    
    print_status "系统包更新完成"
}

# 安装Node.js
install_nodejs() {
    print_step "安装Node.js $NODE_VERSION..."
    
    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
        apt-get install -y nodejs
    elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then
        curl -fsSL https://rpm.nodesource.com/setup_${NODE_VERSION}.x | bash -
        yum install -y nodejs
    fi
    
    # 验证安装
    NODE_VER=$(node --version)
    NPM_VER=$(npm --version)
    
    print_status "Node.js安装完成: $NODE_VER"
    print_status "npm版本: $NPM_VER"
    
    # 安装全局包
    npm install -g pm2 yarn
}

# 创建应用用户
create_app_user() {
    print_step "创建应用用户..."
    
    if id "$APP_NAME" &>/dev/null; then
        print_warning "用户 $APP_NAME 已存在"
    else
        useradd -m -s /bin/bash $APP_NAME
        usermod -aG sudo $APP_NAME
        print_status "用户 $APP_NAME 创建成功"
    fi
    
    # 创建应用目录
    mkdir -p $APP_DIR
    chown -R $APP_NAME:$APP_NAME /home/$APP_NAME
}

# 安装Nginx
install_nginx() {
    print_step "安装Nginx..."
    
    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        apt install -y nginx
    elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then
        yum install -y nginx
    fi
    
    systemctl enable nginx
    systemctl start nginx
    print_status "Nginx安装完成"
}

# 配置防火墙
configure_firewall() {
    print_step "配置防火墙..."
    
    if command -v ufw &> /dev/null; then
        # Ubuntu UFW
        ufw allow ssh
        ufw allow 'Nginx Full'
        ufw --force enable
        print_status "UFW防火墙配置完成"
    elif command -v firewall-cmd &> /dev/null; then
        # CentOS firewalld
        systemctl enable firewalld
        systemctl start firewalld
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --permanent --add-service=ssh
        firewall-cmd --reload
        print_status "firewalld防火墙配置完成"
    else
        print_warning "未检测到防火墙管理工具，请手动配置"
    fi
}

# 部署应用代码
deploy_application() {
    print_step "部署应用代码..."
    
    read -p "请选择部署方式 [1=Git克隆, 2=本地上传]: " deploy_method
    
    case $deploy_method in
        1)
            read -p "请输入Git仓库URL: " git_url
            if [ -z "$git_url" ]; then
                print_error "Git URL不能为空"
                exit 1
            fi
            
            sudo -u $APP_NAME git clone $git_url $APP_DIR
            ;;
        2)
            print_info "请先将代码上传到服务器，然后按任意键继续..."
            read -p "代码文件路径: " code_path
            
            if [ ! -f "$code_path" ]; then
                print_error "文件不存在: $code_path"
                exit 1
            fi
            
            sudo -u $APP_NAME tar -xzf $code_path -C $APP_DIR
            ;;
        *)
            print_error "无效的选择"
            exit 1
            ;;
    esac
    
    chown -R $APP_NAME:$APP_NAME $APP_DIR
    print_status "应用代码部署完成"
}

# 安装依赖和构建
build_application() {
    print_step "安装依赖和构建应用..."
    
    cd $APP_DIR
    
    # 安装依赖
    sudo -u $APP_NAME npm install
    
    # 构建应用
    sudo -u $APP_NAME NODE_ENV=production npm run build
    
    print_status "应用构建完成"
}

# 配置PM2
configure_pm2() {
    print_step "配置PM2进程管理..."
    
    # 创建PM2配置文件
    cat > $APP_DIR/ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: '$APP_NAME',
    script: 'npm',
    args: 'start',
    cwd: '$APP_DIR',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: $PORT
    },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true
  }]
}
EOF

    # 创建日志目录
    sudo -u $APP_NAME mkdir -p $APP_DIR/logs
    
    # 启动应用
    cd $APP_DIR
    sudo -u $APP_NAME pm2 start ecosystem.config.js
    sudo -u $APP_NAME pm2 save
    
    # 设置开机自启
    pm2 startup systemd -u $APP_NAME --hp /home/$APP_NAME
    
    print_status "PM2配置完成"
}

# 配置Nginx
configure_nginx() {
    print_step "配置Nginx反向代理..."
    
    read -p "请输入域名 (留空使用服务器IP): " domain_name
    if [ -z "$domain_name" ]; then
        domain_name="_"
    fi
    
    # 创建Nginx配置
    cat > $NGINX_SITE << EOF
server {
    listen 80;
    server_name $domain_name;
    
    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    location /_next/static {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_cache_valid 200 1y;
        add_header Cache-Control "public, immutable";
    }
    
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
    
    # 安全头部
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
EOF

    # 启用站点
    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        ln -sf $NGINX_SITE /etc/nginx/sites-enabled/
        rm -f /etc/nginx/sites-enabled/default
    elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then
        ln -sf $NGINX_SITE /etc/nginx/conf.d/$APP_NAME.conf
    fi
    
    # 测试配置
    nginx -t
    if [ $? -eq 0 ]; then
        systemctl reload nginx
        print_status "Nginx配置完成"
    else
        print_error "Nginx配置测试失败"
        exit 1
    fi
}

# 创建管理脚本
create_management_scripts() {
    print_step "创建管理脚本..."
    
    # 创建启动脚本
    cat > /usr/local/bin/$APP_NAME-start << EOF
#!/bin/bash
cd $APP_DIR
sudo -u $APP_NAME pm2 start ecosystem.config.js
EOF

    # 创建停止脚本
    cat > /usr/local/bin/$APP_NAME-stop << EOF
#!/bin/bash
sudo -u $APP_NAME pm2 stop $APP_NAME
EOF

    # 创建重启脚本
    cat > /usr/local/bin/$APP_NAME-restart << EOF
#!/bin/bash
cd $APP_DIR
sudo -u $APP_NAME pm2 restart $APP_NAME
EOF

    # 创建状态检查脚本
    cat > /usr/local/bin/$APP_NAME-status << EOF
#!/bin/bash
sudo -u $APP_NAME pm2 status
sudo -u $APP_NAME pm2 logs $APP_NAME --lines 20
EOF

    # 创建更新脚本
    cat > /usr/local/bin/$APP_NAME-update << EOF
#!/bin/bash
cd $APP_DIR
echo "停止应用..."
sudo -u $APP_NAME pm2 stop $APP_NAME

echo "拉取最新代码..."
sudo -u $APP_NAME git pull

echo "安装依赖..."
sudo -u $APP_NAME npm install

echo "构建应用..."
sudo -u $APP_NAME NODE_ENV=production npm run build

echo "启动应用..."
sudo -u $APP_NAME pm2 start $APP_NAME

echo "更新完成!"
EOF

    # 设置执行权限
    chmod +x /usr/local/bin/$APP_NAME-*
    
    print_status "管理脚本创建完成"
}

# 最终检查和信息输出
final_check() {
    print_step "最终检查..."
    
    # 检查应用状态
    sleep 5
    if sudo -u $APP_NAME pm2 list | grep -q "online"; then
        print_status "应用运行正常"
    else
        print_error "应用启动失败"
        sudo -u $APP_NAME pm2 logs $APP_NAME
        exit 1
    fi
    
    # 检查HTTP响应
    if curl -s http://localhost:$PORT > /dev/null; then
        print_status "HTTP服务正常"
    else
        print_warning "HTTP服务可能有问题"
    fi
    
    # 输出访问信息
    SERVER_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip)
    
    echo ""
    echo "🎉 部署完成!"
    echo "=============="
    print_status "应用已成功部署到ECS服务器"
    echo ""
    print_info "访问信息:"
    echo "  🌐 应用URL: http://$SERVER_IP"
    if [ "$domain_name" != "_" ]; then
        echo "  🌐 域名访问: http://$domain_name"
    fi
    echo ""
    print_info "管理命令:"
    echo "  启动应用: $APP_NAME-start"
    echo "  停止应用: $APP_NAME-stop"
    echo "  重启应用: $APP_NAME-restart"
    echo "  查看状态: $APP_NAME-status"
    echo "  更新应用: $APP_NAME-update"
    echo ""
    print_info "文件位置:"
    echo "  应用目录: $APP_DIR"
    echo "  日志目录: $APP_DIR/logs"
    echo "  Nginx配置: $NGINX_SITE"
    echo ""
    print_info "下一步建议:"
    echo "  1. 配置域名DNS解析"
    echo "  2. 安装SSL证书: certbot --nginx -d $domain_name"
    echo "  3. 设置定期备份"
    echo "  4. 配置监控告警"
}

# 主函数
main() {
    echo "🔍 开始自动部署流程..."
    echo ""
    
    # 确认开始部署
    read -p "确认开始自动部署吗？(y/N): " confirm
    if [[ $confirm != [yY] ]]; then
        echo "部署已取消"
        exit 0
    fi
    
    detect_os
    check_root
    update_system
    install_nodejs
    create_app_user
    install_nginx
    configure_firewall
    deploy_application
    build_application
    configure_pm2
    configure_nginx
    create_management_scripts
    final_check
}

# 脚本入口
main "$@"
