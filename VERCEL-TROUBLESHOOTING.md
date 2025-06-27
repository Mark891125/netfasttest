# Vercel 部署排查指南

## 问题排查清单

### 1. 网络连接问题
```bash
# 检查域名解析
nslookup netfasttest.vercel.app

# 检查HTTP状态
curl -I https://netfasttest.vercel.app/

# 测试API端点
curl -X GET https://netfasttest.vercel.app/api/speed-test

# 使用不同DNS测试
curl -I --dns-servers 8.8.8.8 https://netfasttest.vercel.app/
```

### 2. Vercel配置检查

#### 必需文件检查
- [x] `vercel.json` - Vercel配置文件
- [x] `next.config.ts` - Next.js配置
- [x] `package.json` - 依赖和脚本
- [ ] `.vercelignore` - 部署忽略文件（可选）

#### 关键配置项
```json
{
  "version": 2,
  "regions": ["hkg1", "sin1", "nrt1", "icn1"],
  "functions": {
    "app/api/speed-test/route.ts": {
      "maxDuration": 30
    }
  }
}
```

### 3. 部署状态检查

#### Vercel CLI 检查
```bash
# 安装Vercel CLI
npm i -g vercel

# 登录
vercel login

# 检查部署状态
vercel ls

# 查看部署日志
vercel logs netfasttest

# 重新部署
vercel --prod
```

#### GitHub集成检查
1. 检查GitHub Actions状态
2. 确认Vercel GitHub App权限
3. 检查构建日志

### 4. 常见问题及解决方案

#### 问题1: Connection reset by peer
**原因**: 
- 网络防火墙阻挡
- ISP限制
- Vercel服务区域问题

**解决方案**:
```bash
# 更换DNS
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf

# 使用代理测试
curl --proxy http://proxy:port https://netfasttest.vercel.app/

# 尝试不同区域
# 在vercel.json中调整regions配置
```

#### 问题2: 404 Not Found
**原因**:
- 路由配置错误
- 构建失败
- API路径不匹配

**解决方案**:
```bash
# 检查构建输出
vercel logs --follow

# 本地测试
npm run build
npm run start

# 检查API路由
ls -la app/api/
```

#### 问题3: 500 Internal Server Error
**原因**:
- 依赖包问题
- 环境变量缺失
- 函数超时

**解决方案**:
```bash
# 检查依赖
npm audit

# 设置环境变量
vercel env add CUSTOM_VAR

# 调整函数超时
# 在vercel.json中设置maxDuration
```

#### 问题4: 配置冲突错误
**错误信息**: 
- `The functions property cannot be used in conjunction with the builds property`
- `Cannot use both builds and functions in vercel.json`

**原因**:
- 在vercel.json中同时使用了`builds`和`functions`属性
- Vercel v2不允许同时使用这两个属性

**解决方案**:
```bash
# 1. 移除builds属性（推荐）
# Vercel会自动检测Next.js项目
{
  "functions": {
    "app/api/speed-test/route.ts": {
      "maxDuration": 30
    }
  },
  "regions": ["hkg1", "sin1", "nrt1", "icn1"]
}

# 2. 或者使用最简配置
cp vercel.simple.json vercel.json

# 3. 验证配置语法
jq empty vercel.json
```

#### 问题5: API路由不工作
**原因**:
- App Router vs Pages Router混淆
- TypeScript配置问题
- 导出函数错误

**解决方案**:
1. 确认使用App Router: `app/api/route.ts`
2. 检查导出函数:
```typescript
export async function GET(request: NextRequest) {
  // API逻辑
}
```

### 5. 性能优化

#### 冷启动优化
```json
{
  "functions": {
    "app/api/**": {
      "maxDuration": 30,
      "memory": 512
    }
  }
}
```

#### 缓存策略
```json
{
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

### 6. 监控和调试

#### 实时日志
```bash
# 查看实时日志
vercel logs --follow

# 查看特定函数日志
vercel logs --since=1h | grep "speed-test"
```

#### 性能监控
```bash
# 检查函数执行时间
curl -w "@curl-format.txt" https://netfasttest.vercel.app/api/speed-test

# curl-format.txt 内容:
#      time_namelookup:  %{time_namelookup}\n
#         time_connect:  %{time_connect}\n
#      time_appconnect:  %{time_appconnect}\n
#     time_pretransfer:  %{time_pretransfer}\n
#        time_redirect:  %{time_redirect}\n
#   time_starttransfer:  %{time_starttransfer}\n
#                     --------\n
#           time_total:  %{time_total}\n
```

### 7. 故障恢复步骤

#### 快速恢复
```bash
# 1. 回滚到上一个版本
vercel rollback

# 2. 强制重新部署
vercel --force

# 3. 清除缓存重新部署
vercel build --force && vercel deploy --prod
```

#### 完整重建
```bash
# 1. 删除当前项目
vercel remove netfasttest

# 2. 重新初始化
vercel init

# 3. 重新部署
vercel --prod
```

## 当前问题分析

根据测试结果：
- DNS解析正常：`netfasttest.vercel.app -> 108.160.170.43`
- HTTP连接失败：`Connection reset by peer`

**可能原因**：
1. 网络防火墙/ISP限制访问Vercel
2. Vercel在当前区域的服务问题
3. SSL/TLS握手失败

**建议解决步骤**：
1. 使用VPN或代理测试访问
2. 检查Vercel Status页面
3. 尝试不同的Vercel区域配置
4. 联系网络服务提供商确认是否有限制

## 替代方案

如果Vercel访问持续有问题，可以考虑：
1. 使用Azure Static Web Apps（已准备完毕）
2. 使用阿里云ECS（已准备完毕）  
3. 使用Netlify作为备选
4. 使用GitHub Pages + API服务分离部署
