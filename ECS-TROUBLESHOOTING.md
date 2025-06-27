# ECS部署检查清单和故障排除

## ✅ 部署前检查清单

### 服务器准备
- [ ] ECS实例已创建并运行
- [ ] 安全组已配置（开放80, 443, 22端口）
- [ ] 获得服务器root访问权限
- [ ] 服务器带宽满足需求（建议5Mbps以上）
- [ ] 操作系统为支持的版本（Ubuntu 20.04+/CentOS 8+）

### 域名和DNS（可选）
- [ ] 域名已注册
- [ ] DNS A记录指向服务器IP
- [ ] 域名解析生效（使用`nslookup`检查）

### 代码准备
- [ ] 代码已推送到Git仓库，或准备本地上传包
- [ ] package.json包含正确的依赖
- [ ] 代码在本地测试通过
- [ ] 生产环境配置文件准备就绪

## 🚀 快速部署流程

### 方法1: 自动部署脚本（推荐）
```bash
# 1. 上传脚本到服务器
scp ecs-auto-deploy.sh root@your-server-ip:/root/

# 2. 连接到服务器
ssh root@your-server-ip

# 3. 运行自动部署脚本
chmod +x ecs-auto-deploy.sh
./ecs-auto-deploy.sh
```

### 方法2: 手动部署
详见 `ECS-MANUAL-DEPLOYMENT.md` 文档

## 🔍 部署验证步骤

### 1. 基础服务检查
```bash
# 检查Node.js和npm
node --version
npm --version

# 检查PM2状态
pm2 status

# 检查Nginx状态
systemctl status nginx
```

### 2. 应用服务检查
```bash
# 检查应用端口
netstat -tlnp | grep :3000
# 或使用ss命令
ss -tlnp | grep :3000

# 测试本地访问
curl http://localhost:3000

# 检查应用日志
pm2 logs netfasttest --lines 20
```

### 3. 网络访问检查
```bash
# 检查80端口
curl -I http://your-server-ip

# 检查API接口
curl http://your-server-ip/api/speed-test

# 检查从外部访问
# 在本地电脑执行
curl -I http://your-server-ip
```

## 🆘 常见问题故障排除

### 问题1: 应用无法启动

#### 症状
- PM2显示应用状态为"errored"或"stopped"
- 无法访问应用

#### 排查步骤
```bash
# 1. 查看PM2详细状态
pm2 describe netfasttest

# 2. 查看错误日志
pm2 logs netfasttest --err --lines 50

# 3. 检查端口占用
sudo lsof -i :3000

# 4. 手动启动测试
cd /home/netfasttest/apps/netfasttest
npm start
```

#### 可能原因和解决方案
- **端口被占用**: 更改端口或杀死占用进程
- **权限问题**: 检查文件权限 `chown -R netfasttest:netfasttest /home/netfasttest`
- **依赖缺失**: 重新安装依赖 `npm install`
- **构建失败**: 重新构建 `npm run build`

### 问题2: Nginx代理错误

#### 症状
- 访问网站显示502 Bad Gateway
- Nginx错误日志显示upstream错误

#### 排查步骤
```bash
# 1. 检查Nginx配置
nginx -t

# 2. 查看Nginx错误日志
tail -f /var/log/nginx/error.log

# 3. 检查后端服务
curl http://127.0.0.1:3000

# 4. 检查Nginx进程
systemctl status nginx
```

#### 解决方案
```bash
# 重新加载Nginx配置
nginx -s reload

# 重启Nginx服务
systemctl restart nginx

# 检查防火墙设置
ufw status
firewall-cmd --list-all
```

### 问题3: 内存不足

#### 症状
- 应用频繁重启
- 系统响应缓慢
- PM2显示内存使用过高

#### 排查步骤
```bash
# 检查内存使用
free -h
top -p $(pgrep node)

# 检查PM2内存限制
pm2 show netfasttest
```

#### 解决方案
```bash
# 增加PM2内存限制
pm2 delete netfasttest
# 修改ecosystem.config.js中的max_memory_restart
pm2 start ecosystem.config.js

# 启用系统swap
dd if=/dev/zero of=/swapfile bs=1024 count=1048576
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
```

### 问题4: 性能问题

#### 症状
- 响应时间过长
- 并发用户量低
- CPU使用率高

#### 优化方案
```bash
# 1. 增加PM2实例数
pm2 scale netfasttest 2

# 2. 启用Nginx缓存
# 在Nginx配置中添加缓存设置

# 3. 优化Node.js
export NODE_OPTIONS="--max-old-space-size=2048"

# 4. 使用CDN加速静态资源
```

### 问题5: SSL证书问题

#### 安装Let's Encrypt证书
```bash
# 安装Certbot
apt install -y certbot python3-certbot-nginx

# 获取证书
certbot --nginx -d your-domain.com

# 测试自动续期
certbot renew --dry-run
```

#### 手动SSL配置
```bash
# 在Nginx配置中添加SSL
server {
    listen 443 ssl;
    ssl_certificate /path/to/certificate.crt;
    ssl_certificate_key /path/to/private.key;
    
    # SSL配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
}
```

## 📊 性能监控和优化

### 系统监控
```bash
# 安装监控工具
apt install -y htop iotop iftop

# 实时监控
htop           # CPU和内存
iotop          # 磁盘I/O
iftop          # 网络流量
pm2 monit      # PM2监控
```

### 日志管理
```bash
# 设置日志轮转
cat > /etc/logrotate.d/netfasttest << EOF
/home/netfasttest/apps/netfasttest/logs/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    copytruncate
}
EOF

# 清理旧日志
find /home/netfasttest/apps/netfasttest/logs -name "*.log" -mtime +30 -delete
```

### 备份策略
```bash
# 创建备份脚本
cat > /home/netfasttest/backup.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/home/netfasttest/backups"
APP_DIR="/home/netfasttest/apps/netfasttest"

mkdir -p $BACKUP_DIR

# 备份应用代码
tar -czf $BACKUP_DIR/app_$DATE.tar.gz -C /home/netfasttest/apps netfasttest

# 备份Nginx配置
cp /etc/nginx/sites-available/netfasttest $BACKUP_DIR/nginx_$DATE.conf

# 清理7天前的备份
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
find $BACKUP_DIR -name "*.conf" -mtime +7 -delete

echo "备份完成: $DATE"
EOF

chmod +x /home/netfasttest/backup.sh

# 设置定时备份
crontab -e
# 添加: 0 2 * * * /home/netfasttest/backup.sh
```

## 🔧 常用管理命令

### 应用管理
```bash
# 启动应用
netfasttest-start

# 停止应用
netfasttest-stop

# 重启应用
netfasttest-restart

# 查看状态
netfasttest-status

# 更新应用
netfasttest-update
```

### 系统管理
```bash
# 查看系统负载
uptime
cat /proc/loadavg

# 查看磁盘使用
df -h
du -sh /home/netfasttest/*

# 查看网络连接
ss -tuln
netstat -tuln

# 查看进程
ps aux | grep node
ps aux | grep nginx
```

### 日志查看
```bash
# 应用日志
tail -f /home/netfasttest/apps/netfasttest/logs/combined.log

# Nginx访问日志
tail -f /var/log/nginx/access.log

# 系统日志
journalctl -u nginx -f
journalctl -u pm2-netfasttest -f
```

## 📞 技术支持

如果遇到无法解决的问题，请：

1. 收集错误日志和系统信息
2. 记录重现步骤
3. 检查服务器配置和资源使用情况
4. 参考官方文档和社区资源

### 有用的链接
- [Next.js部署文档](https://nextjs.org/docs/deployment)
- [PM2文档](https://pm2.keymetrics.io/docs/)
- [Nginx配置指南](https://nginx.org/en/docs/)
- [Node.js性能优化](https://nodejs.org/en/docs/guides/simple-profiling/)
