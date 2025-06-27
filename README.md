# 网络速度测试应用

这是一个基于 Next.js 开发的网络速度测试应用程序，能够分析访问者的IP地理位置、测量网络延迟和下载速度，并提供历史记录功能。

## 功能特性

### 🌍 IP地理位置分析
- 自动检测访问者的真实IP地址（支持代理和负载均衡器）
- 使用geoip-lite库解析IP归属地（国家、地区、城市）
- 实时显示地理位置信息

### ⚡ 网络性能测试
- **延迟测试**: 测量客户端到服务器的响应时间
- **下载速度测试**: 通过下载测试文件测量实际下载速度
- 实时显示测试结果

### 📊 性能监控
- 服务器端日志记录每次请求的详细信息
- 控制台输出格式：`[时间] IP: xxx | 位置: xxx | 响应时间: xxxms | 大小: xxxbytes`
- 实时性能数据监控

### 📝 历史记录管理
- Session级别的测试记录存储
- 显示最近20次测试记录
- 支持清除历史记录
- 测试记录包含：时间戳、IP地址、地理位置、响应时间、下载速度等

## 技术架构

### 前端技术
- **Next.js 15.3.4**: React框架，支持SSR和API路由
- **TypeScript**: 类型安全的JavaScript
- **CSS Modules**: 组件化样式管理
- **响应式设计**: 支持移动端和桌面端

### 后端技术
- **Next.js API Routes**: 服务端API接口
- **geoip-lite**: IP地理位置解析
- **date-fns**: 日期时间处理
- **uuid**: 唯一标识符生成

### 数据存储
- **SessionStorage**: 客户端历史记录存储
- **服务器日志**: 性能数据记录

## API接口

### POST /api/speed-test
延迟测试接口
- 测量客户端到服务器的响应时间
- 返回IP地址、地理位置、响应时间等信息

### GET /api/speed-test
基本信息获取接口
- 获取客户端IP和地理位置信息
- 测量GET请求的响应时间

### GET /api/download-test?size=500
下载速度测试接口
- 参数：size (KB) - 测试文件大小
- 生成指定大小的测试数据进行下载速度测试
- 返回测试文件数据

## 安装和运行

### 环境要求
- Node.js 18+
- npm 或 yarn

### 安装依赖
```bash
npm install
```

### 开发模式
```bash
npm run dev
```
应用将在 http://localhost:3000 运行

### 生产构建
```bash
npm run build
npm start
```

## 使用说明

1. **延迟测试**: 点击"延迟测试"按钮测量网络延迟
2. **下载测试**: 点击"下载测试"按钮测量下载速度（使用500KB测试文件）
3. **查看结果**: 测试完成后会显示详细的测试结果
4. **历史记录**: 点击"显示历史记录"查看之前的测试记录
5. **清除记录**: 点击"清除记录"删除所有历史数据

## 监控和日志

服务器会在控制台输出每次请求的详细信息：
- 请求时间
- 客户端IP地址
- IP归属地信息
- 响应时间
- 请求大小

## 部署选项

### 🚀 Vercel部署（推荐）
使用Vercel进行快速云端部署：

**部署前检查:**
```bash
# 运行部署前检查，确保配置正确
chmod +x docs/scripts/vercel-precheck.sh
./docs/scripts/vercel-precheck.sh
```

**一键部署:**
```bash
# 使用快速部署脚本
chmod +x docs/scripts/vercel-deploy.sh
./docs/scripts/vercel-deploy.sh

# 或手动部署
npm install -g vercel
vercel login
vercel --prod
```

**性能测试:**
```bash
# 部署完成后测试性能
chmod +x docs/scripts/test-vercel-performance.sh
./docs/scripts/test-vercel-performance.sh
```

**常见问题修复:**
- 如遇到 `builds` 和 `functions` 冲突错误，已自动修复
- 配置文件已优化兼容 Next.js 15.3.4
- 支持 Node.js 18+ 和 20 LTS

**故障排查:**
如遇网络访问问题，详见：[docs/deployment/VERCEL-TROUBLESHOOTING.md](docs/deployment/VERCEL-TROUBLESHOOTING.md)

配置文件：
- `vercel.json` - Vercel部署配置（根目录）
- `docs/templates/vercel.simple.json` - 简化配置模板
- `docs/deployment/VERCEL-DEPLOYMENT-GUIDE.md` - 详细部署指南

### 🌟 Azure Web App部署
使用Azure App Service进行快速部署：

**快速部署:**
```bash
chmod +x docs/scripts/azure-quick-deploy.sh
./docs/scripts/azure-quick-deploy.sh
```

**完整部署:**
```bash
chmod +x docs/scripts/azure-full-deploy.sh
./docs/scripts/azure-full-deploy.sh
```

详见：[docs/deployment/AZURE-DEPLOYMENT-GUIDE.md](docs/deployment/AZURE-DEPLOYMENT-GUIDE.md)

### 🖥️ ECS服务器部署
手动部署到阿里云ECS或其他VPS服务器：

详见：[docs/deployment/ECS-MANUAL-DEPLOYMENT.md](docs/deployment/ECS-MANUAL-DEPLOYMENT.md)

**故障排除:**
详见：[docs/deployment/ECS-TROUBLESHOOTING.md](docs/deployment/ECS-TROUBLESHOOTING.md)

### 🐳 Docker容器部署
使用Docker容器进行部署：

```bash
# 构建镜像
docker build -t netfasttest .

# 运行容器
docker run -d -p 3000:3000 --name netfasttest netfasttest
```

## 生产环境注意事项

### Node.js版本选择
- **推荐**: Node.js 20 LTS（长期支持版本）
- **支持**: Node.js 18.17+ 和 Node.js 22+
- 详见：[docs/deployment/NODEJS-VERSION-GUIDE.md](docs/deployment/NODEJS-VERSION-GUIDE.md)

### 网络访问问题
如果部署后无法访问（特别是Vercel），可能的原因：
1. **网络防火墙限制**: 某些网络环境可能限制访问Vercel
2. **DNS解析问题**: 尝试更换DNS服务器（如8.8.8.8）
3. **SSL连接超时**: 网络环境对SSL握手的限制

**解决方案**:
- 使用VPN或代理访问
- 选择其他部署平台（Azure、ECS等）
- 联系网络管理员确认访问权限

### 性能优化建议
1. **API响应优化**: 地理位置查询与延迟测量分离
2. **缓存策略**: 合理设置HTTP缓存头
3. **CDN加速**: 利用全球CDN节点
4. **监控告警**: 设置性能监控和异常告警

## 技术支持

### 部署相关文档
- [docs/README.md](docs/README.md) - 部署文档和脚本总览
- [docs/CONFIG-FILES-GUIDE.md](docs/CONFIG-FILES-GUIDE.md) - 配置文件详细说明
- [docs/deployment/VERCEL-DEPLOYMENT-GUIDE.md](docs/deployment/VERCEL-DEPLOYMENT-GUIDE.md) - Vercel部署指南
- [docs/deployment/VERCEL-TROUBLESHOOTING.md](docs/deployment/VERCEL-TROUBLESHOOTING.md) - Vercel故障排查
- [docs/deployment/AZURE-DEPLOYMENT-GUIDE.md](docs/deployment/AZURE-DEPLOYMENT-GUIDE.md) - Azure部署指南
- [docs/deployment/ECS-MANUAL-DEPLOYMENT.md](docs/deployment/ECS-MANUAL-DEPLOYMENT.md) - ECS手动部署指南
- [docs/deployment/NODEJS-VERSION-GUIDE.md](docs/deployment/NODEJS-VERSION-GUIDE.md) - Node.js版本选择指南

### 脚本工具
- `docs/scripts/vercel-precheck.sh` - Vercel部署前检查脚本
- `docs/scripts/vercel-deploy.sh` - Vercel快速部署脚本
- `docs/scripts/test-vercel-performance.sh` - Vercel性能测试脚本
- `docs/scripts/azure-quick-deploy.sh` - Azure快速部署脚本

## 许可证

MIT License
