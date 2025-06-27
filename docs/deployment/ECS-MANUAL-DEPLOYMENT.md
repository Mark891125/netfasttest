# ECS服务器手动部署指南

## 📋 概述

本指南详细介绍如何将网络速度测试Next.js应用手动部署到阿里云ECS服务器上。

## 🖥️ 服务器环境要求

### 最低配置
- **CPU**: 1核心
- **内存**: 2GB RAM
- **存储**: 20GB SSD
- **带宽**: 1Mbps
- **操作系统**: Ubuntu 20.04 LTS / CentOS 8 / Debian 11

### 推荐配置
- **CPU**: 2核心
- **内存**: 4GB RAM
- **存储**: 40GB SSD
- **带宽**: 5Mbps
- **操作系统**: Ubuntu 22.04 LTS

## 🚀 部署步骤

### 步骤1: 服务器基础环境准备

#### 1.1 连接到ECS服务器
```bash
# 使用SSH连接到服务器
ssh root@your-server-ip

# 或使用密钥文件
ssh -i your-key.pem root@your-server-ip
```

#### 1.2 更新系统包
```bash
# Ubuntu/Debian
sudo apt update && sudo apt upgrade -y

# CentOS/RHEL
sudo yum update -y
```

#### 1.3 安装必要工具
```bash
# Ubuntu/Debian
sudo apt install -y curl wget git unzip build-essential

# CentOS/RHEL
sudo yum install -y curl wget git unzip gcc gcc-c++ make
```

### 步骤2: 安装Node.js和npm

#### 2.1 使用NodeSource仓库安装Node.js 20
```bash
# 下载并安装NodeSource仓库
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -

# Ubuntu/Debian
sudo apt-get install -y nodejs

# CentOS/RHEL (使用不同的脚本)
curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
sudo yum install -y nodejs
```

#### 2.2 验证安装
```bash
node --version  # 应该显示 v20.x.x
npm --version   # 应该显示 10.x.x 或更高
```

#### 2.3 安装全局包管理工具
```bash
sudo npm install -g pm2 yarn
```

### 步骤3: 创建应用目录和用户

#### 3.1 创建专用用户（可选但推荐）
```bash
# 创建应用用户
sudo useradd -m -s /bin/bash netfasttest
sudo usermod -aG sudo netfasttest

# 切换到应用用户
sudo su - netfasttest
```

#### 3.2 创建应用目录
```bash
mkdir -p ~/apps/netfasttest
cd ~/apps/netfasttest
```

### 步骤4: 部署应用代码

#### 4.1 方法一：Git克隆（如果代码在仓库中）
```bash
# 克隆代码仓库
git clone https://github.com/yourusername/netfasttest.git .

# 或者如果是私有仓库
git clone https://your-token@github.com/yourusername/netfasttest.git .
```

#### 4.2 方法二：手动上传文件
```bash
# 在本地打包代码
cd /path/to/your/local/netfasttest
tar -czf netfasttest.tar.gz --exclude=node_modules --exclude=.next --exclude=.git *

# 上传到服务器
scp netfasttest.tar.gz root@your-server-ip:/home/netfasttest/apps/netfasttest/

# 在服务器上解压
cd ~/apps/netfasttest
tar -xzf netfasttest.tar.gz
rm netfasttest.tar.gz
```

#### 4.3 方法三：使用rsync同步
```bash
# 在本地执行，同步代码到服务器
rsync -avz --exclude=node_modules --exclude=.next --exclude=.git \
  /path/to/your/local/netfasttest/ \
  root@your-server-ip:/home/netfasttest/apps/netfasttest/
```

### 步骤5: 安装依赖和构建应用

#### 5.1 安装Node.js依赖
```bash
cd ~/apps/netfasttest

# 安装生产依赖
npm ci --only=production

# 或者安装所有依赖然后构建
npm install
```

#### 5.2 构建Next.js应用
```bash
# 设置环境变量
export NODE_ENV=production

# 构建应用
npm run build
```

#### 5.3 验证构建结果
```bash
# 检查构建文件
ls -la .next/

# 测试启动
npm start &
sleep 5
curl http://localhost:3000
killall node
```

### 步骤6: 配置环境变量

#### 6.1 创建生产环境配置
```bash
# 创建环境变量文件
cat > .env.production << EOF
NODE_ENV=production
PORT=3000
HOST=0.0.0.0
NEXT_TELEMETRY_DISABLED=1

# 根据需要添加其他环境变量
# DATABASE_URL=
# API_KEY=
EOF
```

#### 6.2 设置文件权限
```bash
chmod 600 .env.production
```

### 步骤7: 配置进程管理器（PM2）

#### 7.1 创建PM2配置文件
```bash
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'netfasttest',
    script: 'npm',
    args: 'start',
    cwd: '/home/netfasttest/apps/netfasttest',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true
  }]
}
EOF
```

#### 7.2 创建日志目录
```bash
mkdir -p logs
```

#### 7.3 启动应用
```bash
# 启动应用
pm2 start ecosystem.config.js

# 查看状态
pm2 status

# 查看日志
pm2 logs netfasttest

# 保存PM2配置
pm2 save

# 设置开机自启
pm2 startup
# 按照输出的指令执行，通常是：
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u netfasttest --hp /home/netfasttest
```

### 步骤8: 配置Nginx反向代理

#### 8.1 安装Nginx
```bash
# Ubuntu/Debian
sudo apt install -y nginx

# CentOS/RHEL
sudo yum install -y nginx
```

#### 8.2 创建Nginx配置
```bash
sudo tee /etc/nginx/sites-available/netfasttest << 'EOF'
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;  # 替换为你的域名
    
    # 客户端IP传递
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # 静态文件缓存
    location /_next/static {
        proxy_pass http://127.0.0.1:3000;
        proxy_cache_valid 200 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Gzip压缩
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
}
EOF
```

#### 8.3 启用站点配置
```bash
# Ubuntu/Debian
sudo ln -s /etc/nginx/sites-available/netfasttest /etc/nginx/sites-enabled/

# 测试配置
sudo nginx -t

# 重启Nginx
sudo systemctl restart nginx
sudo systemctl enable nginx
```

### 步骤9: 配置防火墙

#### 9.1 配置iptables（如果使用）
```bash
# 允许HTTP和HTTPS流量
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# 保存规则
sudo iptables-save > /etc/iptables/rules.v4
```

#### 9.2 配置ufw（Ubuntu）
```bash
sudo ufw allow 'Nginx Full'
sudo ufw allow ssh
sudo ufw enable
```

#### 9.3 配置firewalld（CentOS）
```bash
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

### 步骤10: SSL证书配置（可选）

#### 10.1 使用Let's Encrypt免费证书
```bash
# 安装Certbot
sudo apt install -y certbot python3-certbot-nginx

# 获取证书
sudo certbot --nginx -d your-domain.com -d www.your-domain.com

# 测试自动续期
sudo certbot renew --dry-run
```

## 🔧 部署后管理

### 应用管理命令
```bash
# 查看应用状态
pm2 status

# 重启应用
pm2 restart netfasttest

# 停止应用
pm2 stop netfasttest

# 查看日志
pm2 logs netfasttest

# 监控应用
pm2 monit
```

### 更新应用
```bash
# 拉取最新代码
cd ~/apps/netfasttest
git pull origin main

# 安装新依赖
npm install

# 重新构建
npm run build

# 重启应用
pm2 restart netfasttest
```

### 数据库备份（如果有）
```bash
# 创建备份脚本
cat > backup.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/home/netfasttest/backups"
mkdir -p $BACKUP_DIR

# 备份应用文件
tar -czf $BACKUP_DIR/app_backup_$DATE.tar.gz -C /home/netfasttest/apps netfasttest

# 清理7天前的备份
find $BACKUP_DIR -name "app_backup_*.tar.gz" -mtime +7 -delete
EOF

chmod +x backup.sh

# 添加到定时任务
crontab -e
# 添加行: 0 2 * * * /home/netfasttest/backup.sh
```

## 📊 监控和日志

### 系统监控
```bash
# 查看系统资源
htop
df -h
free -h

# 查看网络连接
netstat -tlnp | grep :80
ss -tlnp | grep :3000
```

### 应用日志
```bash
# PM2日志
pm2 logs netfasttest --lines 100

# Nginx日志
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# 系统日志
sudo journalctl -u nginx -f
```

## 🆘 故障排除

### 常见问题及解决方案

#### 问题1: 应用无法启动
```bash
# 检查端口占用
sudo lsof -i :3000

# 检查Node.js进程
ps aux | grep node

# 检查PM2状态
pm2 describe netfasttest
```

#### 问题2: Nginx代理错误
```bash
# 检查Nginx配置
sudo nginx -t

# 检查后端连接
curl http://127.0.0.1:3000

# 查看Nginx错误日志
sudo tail -f /var/log/nginx/error.log
```

#### 问题3: 性能问题
```bash
# 监控系统资源
top
iotop
iftop

# 调整PM2实例数
pm2 scale netfasttest 2  # 增加到2个实例
```

## 📝 维护建议

1. **定期更新**: 每月更新系统包和Node.js
2. **监控资源**: 定期检查CPU、内存、磁盘使用情况
3. **备份数据**: 设置自动备份策略
4. **安全更新**: 及时应用安全补丁
5. **日志管理**: 定期清理和轮转日志文件

## 🔒 安全加固

### 基础安全配置
```bash
# 禁用root SSH登录
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

# 更改SSH端口
sudo sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config

# 重启SSH服务
sudo systemctl restart sshd

# 安装fail2ban
sudo apt install -y fail2ban
```

### 应用安全
```bash
# 设置文件权限
chmod 750 ~/apps/netfasttest
chmod 640 ~/apps/netfasttest/.env.production

# 配置Nginx安全头
# 在Nginx配置中添加：
# add_header X-Frame-Options "SAMEORIGIN";
# add_header X-Content-Type-Options "nosniff";
# add_header X-XSS-Protection "1; mode=block";
```

这个指南涵盖了从服务器准备到应用部署、监控维护的完整流程。您可以根据实际需求调整配置参数。
