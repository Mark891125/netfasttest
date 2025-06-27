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

### 🌟 Azure Web App部署（推荐）
使用Azure App Service进行快速部署：

**快速部署:**
```bash
chmod +x azure-quick-deploy.sh
./azure-quick-deploy.sh
```

**完整部署:**
```bash
chmod +x azure-full-deploy.sh
./azure-full-deploy.sh
```

详见：`AZURE-CHECKLIST.md` 和 `AZURE-DEPLOYMENT-GUIDE.md`

### 🖥️ ECS服务器部署
手动部署到阿里云ECS或其他VPS服务器：

**自动部署（推荐）:**
```bash
# 上传脚本到服务器
scp ecs-auto-deploy.sh root@your-server-ip:/root/

# 连接服务器并运行
ssh root@your-server-ip
chmod +x ecs-auto-deploy.sh
./ecs-auto-deploy.sh
```

**手动部署:**
详见：`ECS-MANUAL-DEPLOYMENT.md`

**故障排除:**
详见：`ECS-TROUBLESHOOTING.md`

### 🐳 Docker容器部署
使用Docker容器进行部署：

```bash
# 构建镜像
docker build -t netfasttest .

# 运行容器
docker run -d -p 3000:3000 --name netfasttest netfasttest
```

## 许可证

MIT License
