# 部署文档和脚本目录

## 目录结构

```
docs/
├── deployment/           # 部署指南和故障排查文档
│   ├── AZURE-DEPLOYMENT-GUIDE.md
│   ├── ECS-MANUAL-DEPLOYMENT.md
│   ├── VERCEL-DEPLOYMENT-GUIDE.md
│   ├── ECS-TROUBLESHOOTING.md
│   └── VERCEL-TROUBLESHOOTING.md
├── scripts/             # 部署和管理脚本
│   ├── azure-quick-deploy.sh
│   ├── azure-full-deploy.sh
│   ├── azure-test.sh
│   ├── azure-troubleshoot.sh
│   ├── vercel-deploy.sh
│   ├── vercel-precheck.sh
│   └── test-vercel-performance.sh
└── templates/           # 配置文件模板
    ├── vercel.minimal.json
    ├── vercel.simple.json
    ├── .env.vercel
    ├── .env.template
    ├── package.azure.json
    └── next.config.azure.js
```

## 重要说明

### 配置文件分类

#### 生产配置文件（必须在根目录）
以下文件是部署平台**直接读取**的，必须保留在项目根目录：

- `vercel.json` - Vercel实际读取的部署配置
- `next.config.ts` - Next.js实际读取的构建配置  
- `package.json` - npm/部署平台读取的依赖配置
- `.vercelignore` - Vercel读取的忽略文件

#### 模板配置文件（docs/templates/）
以下是**备用模板**，供故障排查或自定义使用：

- `vercel.minimal.json` - 最小化Vercel配置模板
- `vercel.simple.json` - 简化版Vercel配置模板  
- `.env.template` - 环境变量模板
- `package.azure.json` - Azure部署专用package.json
- `next.config.azure.js` - Azure部署专用Next.js配置

### 配置文件使用方式

```bash
# 正常情况：使用根目录配置
vercel --prod

# 故障排查：切换到备用配置
cp docs/templates/vercel.minimal.json vercel.json
vercel --prod

# 恢复原配置
git checkout vercel.json
```

⚠️ **重要**: 只有根目录的配置文件会被部署平台读取，docs/templates/ 中的文件只是备用模板。

### Vercel配置说明

**重要**: `vercel.json` 配置文件必须位于项目根目录，Vercel才能正确读取。

当前根目录的 `vercel.json` 配置：
```json
{
  "functions": {
    "app/api/speed-test/route.ts": {
      "maxDuration": 30
    }
  },
  "regions": [
    "hkg1",
    "sin1"
  ]
}
```

## 快速部署指南

### 1. Vercel部署

**部署前检查**:
```bash
# 运行部署前检查
chmod +x docs/scripts/vercel-precheck.sh
./docs/scripts/vercel-precheck.sh
```

**一键部署**:
```bash
# 使用部署脚本
chmod +x docs/scripts/vercel-deploy.sh
./docs/scripts/vercel-deploy.sh
```

**性能测试**:
```bash
# 部署后测试
chmod +x docs/scripts/test-vercel-performance.sh
./docs/scripts/test-vercel-performance.sh
```

### 2. Azure部署

**快速部署**:
```bash
chmod +x docs/scripts/azure-quick-deploy.sh
./docs/scripts/azure-quick-deploy.sh
```

**完整部署**:
```bash
chmod +x docs/scripts/azure-full-deploy.sh
./docs/scripts/azure-full-deploy.sh
```

### 3. 配置模板使用

#### 故障排查时切换配置
```bash
# 如果遇到region错误，使用最小化配置
cp docs/templates/vercel.minimal.json vercel.json

# 如果遇到headers冲突，使用简化配置
cp docs/templates/vercel.simple.json vercel.json

# 恢复原配置
git checkout vercel.json
```

#### 自定义配置
```bash
# 从模板开始自定义
cp docs/templates/vercel.simple.json vercel.json
# 然后编辑根目录的 vercel.json 文件
```

## 故障排查

- **Vercel问题**: 查看 [docs/deployment/VERCEL-TROUBLESHOOTING.md](deployment/VERCEL-TROUBLESHOOTING.md)
- **Azure问题**: 查看 [docs/deployment/AZURE-DEPLOYMENT-GUIDE.md](deployment/AZURE-DEPLOYMENT-GUIDE.md)
- **ECS问题**: 查看 [docs/deployment/ECS-TROUBLESHOOTING.md](deployment/ECS-TROUBLESHOOTING.md)

## 注意事项

1. **配置文件位置**: 部署平台的配置文件（如vercel.json）必须在根目录
2. **脚本权限**: 执行脚本前需要添加执行权限 `chmod +x`
3. **网络问题**: 如果Vercel无法访问，可选择Azure或ECS部署方案
4. **Node.js版本**: 建议使用Node.js 20 LTS
