# Vercel 部署指南

## 概述

本指南提供网络速度测试应用在Vercel平台的完整部署方案，包括配置优化、故障排查和性能监控。

## 快速开始

### 1. 环境准备

```bash
# 安装Vercel CLI
npm install -g vercel

# 克隆项目
git clone <your-repo-url>
cd netfasttest

# 安装依赖
npm install

# 本地测试
npm run dev
```

### 2. 一键部署

```bash
# 使用快速部署脚本
./vercel-deploy.sh

# 或手动部署
vercel login
vercel --prod
```

## 配置详解

### vercel.json 配置

```json
{
  "version": 2,
  "regions": ["hkg1", "sin1", "nrt1", "icn1"],
  "functions": {
    "app/api/speed-test/route.ts": {
      "maxDuration": 30
    }
  },
  "headers": [
    {
      "source": "/api/(.*)",
      "headers": [
        {
          "key": "Cache-Control",
          "value": "no-cache, no-store, must-revalidate"
        }
      ]
    }
  ]
}
```

**关键配置说明**：
- `regions`: 优先使用亚洲区域服务器
- `maxDuration`: API函数最大执行时间
- `headers`: 缓存和CORS配置

### next.config.ts 优化

```typescript
const nextConfig: NextConfig = {
  output: 'standalone',
  experimental: {
    serverComponentsExternalPackages: ['geoip-lite']
  },
  poweredByHeader: false,
  compress: true
};
```

**优化重点**：
- `standalone`: 独立输出模式，减少冷启动时间
- `serverComponentsExternalPackages`: 外部包处理
- `poweredByHeader`: 移除X-Powered-By头

## 部署流程

### 方案一：GitHub 集成（推荐）

1. **连接GitHub仓库**
```bash
# 在Vercel Dashboard中导入GitHub仓库
# 或使用CLI连接
vercel link
```

2. **自动部署配置**
- 推送到main分支自动部署生产环境
- 推送到其他分支自动部署预览环境
- PR自动创建部署预览

3. **环境变量设置**
```bash
# 通过CLI设置
vercel env add NODE_ENV
vercel env add API_TIMEOUT

# 或在Dashboard中配置
```

### 方案二：CLI 直接部署

```bash
# 首次部署
vercel

# 生产部署
vercel --prod

# 强制重新部署
vercel --force
```

## 性能优化

### 1. 冷启动优化

```json
{
  "functions": {
    "app/api/**": {
      "maxDuration": 30,
      "memory": 1024
    }
  }
}
```

### 2. 缓存策略

```javascript
// API路由中设置缓存
export async function GET() {
  return new Response(data, {
    headers: {
      'Cache-Control': 'no-cache, no-store, must-revalidate'
    }
  });
}
```

### 3. 静态资源优化

```json
{
  "headers": [
    {
      "source": "/_next/static/(.*)",
      "headers": [
        {
          "key": "Cache-Control",
          "value": "public, max-age=31536000, immutable"
        }
      ]
    }
  ]
}
```

## 监控和调试

### 1. 实时日志监控

```bash
# 查看实时日志
vercel logs --follow

# 查看特定时间段日志
vercel logs --since=1h

# 查看特定函数日志
vercel logs | grep "speed-test"
```

### 2. 性能监控

```bash
# 性能测试脚本
./test-performance.sh

# 或手动测试
curl -w "@curl-format.txt" https://netfasttest.vercel.app/api/speed-test
```

### 3. 错误监控

集成Sentry进行错误监控：

```bash
# 安装Sentry
npm install @sentry/nextjs

# 环境变量
vercel env add SENTRY_DSN
```

## 故障排查

### 常见问题

#### 1. 部署失败
```bash
# 检查构建日志
vercel logs

# 本地验证构建
npm run build

# 清除缓存重试
vercel build --force
```

#### 2. API无法访问
```bash
# 检查路由配置
ls -la app/api/

# 测试API端点
curl https://netfasttest.vercel.app/api/speed-test

# 检查函数日志
vercel logs | grep "api"
```

#### 3. 网络连接问题

**问题表现**：
- `Connection reset by peer`
- `SSL connection timeout`
- 无法访问部署URL

**解决方案**：
```bash
# 1. 检查网络连通性
./vercel-deploy.sh test

# 2. 更换DNS
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf

# 3. 使用代理访问
export https_proxy=http://proxy:port

# 4. 检查防火墙设置
# 联系网络管理员或ISP
```

### 网络限制处理

如果遇到网络访问限制：

1. **使用VPN或代理**
```bash
# 配置代理
export HTTPS_PROXY=http://proxy:port
vercel deploy --prod
```

2. **更换部署区域**
```json
{
  "regions": ["sin1", "hnd1", "icn1"]
}
```

3. **使用替代平台**
- Azure Static Web Apps
- 阿里云ECS
- GitHub Pages

## 生产环境最佳实践

### 1. 安全配置

```json
{
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        {
          "key": "X-Frame-Options",
          "value": "DENY"
        },
        {
          "key": "X-Content-Type-Options",
          "value": "nosniff"
        },
        {
          "key": "Referrer-Policy",
          "value": "strict-origin-when-cross-origin"
        }
      ]
    }
  ]
}
```

### 2. 环境变量管理

```bash
# 生产环境变量
vercel env add NODE_ENV production
vercel env add API_TIMEOUT 30000

# 开发环境变量
vercel env add NODE_ENV development --environment development
```

### 3. 域名配置

```bash
# 添加自定义域名
vercel domains add yourdomain.com

# 配置DNS
# 添加CNAME记录: www -> cname.vercel-dns.com
```

### 4. 备份和回滚

```bash
# 查看部署历史
vercel list

# 回滚到指定版本
vercel rollback [deployment-url]

# 创建备份分支
git checkout -b backup-$(date +%Y%m%d)
git push origin backup-$(date +%Y%m%d)
```

## 替代方案

如果Vercel部署遇到持续问题，可选择：

### 1. Azure Static Web Apps
```bash
# 使用已准备的Azure脚本
./azure-quick-deploy.sh
```

### 2. 阿里云ECS
```bash
# 使用ECS自动部署脚本
./ecs-auto-deploy.sh
```

### 3. Netlify
```bash
# 安装Netlify CLI
npm install -g netlify-cli

# 部署到Netlify
netlify deploy --prod
```

## 支持和维护

### 日常维护

```bash
# 定期检查部署状态
vercel ls

# 监控性能指标
curl -w "@curl-format.txt" https://netfasttest.vercel.app/

# 更新依赖
npm update
vercel --prod
```

### 技术支持

- **Vercel文档**: https://vercel.com/docs
- **Next.js文档**: https://nextjs.org/docs
- **项目故障排查**: `VERCEL-TROUBLESHOOTING.md`

---

📚 **相关文档**
- [Azure部署指南](AZURE-DEPLOYMENT-GUIDE.md)
- [ECS部署指南](ECS-MANUAL-DEPLOYMENT.md)
- [Node.js版本指南](NODEJS-VERSION-GUIDE.md)
- [Vercel故障排查](VERCEL-TROUBLESHOOTING.md)
