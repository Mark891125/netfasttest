# Azure部署配置说明文档

## 📋 概述

此文档包含了Azure Web App部署网络速度测试应用的完整配置和文件说明。

## 🗂 文件结构

```
netfasttest/
├── app/                           # Next.js应用源码
├── public/                        # 静态资源
├── azure-quick-deploy.sh          # 快速部署脚本
├── azure-full-deploy.sh           # 完整部署脚本
├── azure-troubleshoot.sh          # 故障排除工具
├── azure-test.sh                  # 健康检查和测试工具
├── AZURE-CHECKLIST.md            # 部署前准备清单
├── next.config.azure.js          # Azure优化的Next.js配置
├── package.azure.json            # Azure优化的依赖配置
├── web.config                     # IIS/Azure Web App配置
├── staticwebapp.config.json      # Azure Static Web Apps配置（备选）
├── Dockerfile                     # Docker容器配置（备选）
├── .env.template                  # 环境变量模板
└── package.json                   # 原始依赖配置
```

## 🚀 部署选项

### 选项1: Azure Web App (推荐)
使用Azure App Service部署Node.js应用。

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

### 选项2: Azure Static Web Apps
适用于静态化的Next.js应用。

1. 设置配置文件: `staticwebapp.config.json`
2. 通过GitHub Actions自动部署
3. 适合轻量级应用

### 选项3: Azure Container Instances
使用Docker容器部署。

```bash
# 构建镜像
docker build -t netfasttest .

# 推送到Azure Container Registry
az acr build --registry myregistry --image netfasttest .

# 部署到Container Instances
az container create \
  --resource-group myResourceGroup \
  --name netfasttest \
  --image myregistry.azurecr.io/netfasttest
```

## ⚙️ 配置文件说明

### next.config.azure.js
Azure Web App优化的Next.js配置:
- `output: 'standalone'` - 生成独立服务器
- 安全头部配置
- 图片优化禁用（Azure兼容性）
- 环境变量映射

### package.azure.json
Azure生产环境优化的依赖配置:
- 移除开发依赖
- 添加Azure特定脚本
- 设置Node.js引擎版本
- 配置浏览器兼容性

### web.config
IIS/Azure Web App配置:
- 重写规则
- 压缩设置
- 安全头部
- 错误页面
- iisnode配置

### .env.template
环境变量模板:
- Azure服务配置
- Application Insights
- API密钥
- 性能参数

## 🛠 部署后管理

### 健康检查
```bash
chmod +x azure-test.sh
./azure-test.sh myapp.azurewebsites.net all
```

### 故障排除
```bash
chmod +x azure-troubleshoot.sh
./azure-troubleshoot.sh
```

### 监控和日志
```bash
# 查看实时日志
az webapp log tail --resource-group myResourceGroup --name myapp

# 下载日志文件
az webapp log download --resource-group myResourceGroup --name myapp
```

## 📊 性能优化

### 自动扩缩
```bash
# 设置自动扩缩规则
az monitor autoscale create \
  --resource-group myResourceGroup \
  --name myapp-autoscale \
  --resource /subscriptions/xxx/resourceGroups/myResourceGroup/providers/Microsoft.Web/serverFarms/myplan \
  --min-count 1 \
  --max-count 5
```

### CDN配置
```bash
# 创建CDN配置文件
az cdn profile create \
  --resource-group myResourceGroup \
  --name myapp-cdn \
  --sku Standard_Microsoft

# 创建CDN端点
az cdn endpoint create \
  --resource-group myResourceGroup \
  --name myapp-endpoint \
  --profile-name myapp-cdn \
  --origin myapp.azurewebsites.net
```

## 🔒 安全配置

### SSL证书
- 使用Azure托管证书（免费）
- 或上传自定义SSL证书
- 强制HTTPS重定向

### 访问限制
```bash
# 设置IP访问限制
az webapp config access-restriction add \
  --resource-group myResourceGroup \
  --name myapp \
  --rule-name "Allow-Office" \
  --action Allow \
  --ip-address 203.0.113.0/24 \
  --priority 100
```

### 应用程序网关
配置Azure Application Gateway实现:
- Web应用防火墙 (WAF)
- 负载均衡
- SSL终止

## 📈 监控和警报

### Application Insights
```bash
# 启用Application Insights
az monitor app-insights component create \
  --app myapp-insights \
  --location "East US" \
  --resource-group myResourceGroup
```

### 自定义警报
```bash
# CPU使用率警报
az monitor metrics alert create \
  --name "High CPU Alert" \
  --resource-group myResourceGroup \
  --condition "avg Percentage CPU > 80" \
  --description "Alert when CPU usage is high"
```

## 🔄 CI/CD集成

### GitHub Actions
创建 `.github/workflows/azure-deploy.yml`:
```yaml
name: Deploy to Azure Web App

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: Setup Node.js
      uses: actions/setup-node@v2
      with:
        node-version: '18'
    - name: Deploy to Azure Web App
      uses: azure/webapps-deploy@v2
      with:
        app-name: 'myapp'
        publish-profile: ${{ secrets.AZURE_WEBAPP_PUBLISH_PROFILE }}
```

### Azure DevOps
配置Azure Pipelines进行自动化部署。

## 🆘 常见问题

### 应用无法启动
1. 检查Node.js版本设置
2. 验证启动命令配置
3. 查看应用日志
4. 确认依赖安装

### 性能问题
1. 启用压缩
2. 配置CDN
3. 优化图片资源
4. 使用缓存策略

### API错误
1. 检查环境变量配置
2. 验证CORS设置
3. 确认API路由配置
4. 测试网络连接

## 📞 支持和帮助

- Azure文档: https://docs.microsoft.com/azure/app-service/
- Next.js部署指南: https://nextjs.org/docs/deployment
- 故障排除工具: `./azure-troubleshoot.sh`
- 健康检查工具: `./azure-test.sh`

## 📝 维护建议

1. 定期更新依赖包
2. 监控应用性能指标
3. 备份重要配置
4. 测试部署流程
5. 更新安全配置
