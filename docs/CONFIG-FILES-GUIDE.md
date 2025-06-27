# 配置文件说明

## 重要概念

### 生产配置 vs 模板配置

```
项目根目录/
├── vercel.json              ← Vercel实际读取的配置文件
├── next.config.ts           ← Next.js实际读取的配置文件
├── package.json             ← npm实际读取的配置文件
└── docs/
    └── templates/
        ├── vercel.simple.json    ← 备用模板（简化版）
        ├── vercel.minimal.json   ← 备用模板（最小化）
        └── .env.template         ← 环境变量模板
```

## 配置文件关系

### 当前生产配置（根目录）
- **`vercel.json`** - Vercel部署时实际读取的配置（免费计划优化）
  ```json
  {
    "functions": {
      "app/api/speed-test/route.ts": {
        "maxDuration": 30
      }
    }
  }
  ```

### 免费计划限制

⚠️ **Vercel免费计划不支持的功能**：
- ❌ 多区域部署 (`"regions": [...]`)
- ❌ 自定义域名
- ❌ 高级缓存配置
- ❌ 服务器端配置

✅ **免费计划支持的功能**：
- ✅ Serverless Functions（API路由）
- ✅ 静态文件托管
- ✅ 自动SSL证书
- ✅ 函数超时配置（maxDuration）
- ✅ 自动区域选择（Vercel会选择最佳区域）

### 备用模板（docs/templates/）

#### `vercel.simple.json` - 简化版配置
- 移除了headers配置
- 只保留核心功能配置
- 适用于：配置冲突时的快速修复

#### `vercel.minimal.json` - 最小化配置
- 只包含functions配置
- 让Vercel自动选择regions
- 适用于：网络问题或region错误时

## 使用场景

### 1. 正常情况
直接使用根目录的 `vercel.json`

### 2. 配置出错时
```bash
# 如果遇到regions错误，使用最小化配置
cp docs/templates/vercel.minimal.json vercel.json

# 如果遇到headers冲突，使用简化配置  
cp docs/templates/vercel.simple.json vercel.json
```

### 3. 自定义配置
```bash
# 从模板开始自定义
cp docs/templates/vercel.simple.json vercel.json
# 然后编辑 vercel.json 文件
```

## 重要提醒

⚠️ **只有根目录的配置文件会被读取**
- Vercel只会读取根目录的 `vercel.json`
- Next.js只会读取根目录的 `next.config.ts`
- docs/templates/ 中的文件只是备用模板

✅ **正确做法**
```bash
# ❌ 错误：移动生产配置到docs
mv vercel.json docs/

# ✅ 正确：只移动模板文件到docs  
mv vercel.simple.json docs/templates/
```

## 故障排查步骤

1. **检查配置文件位置**
   ```bash
   ls -la vercel.json          # 必须存在
   ls -la next.config.ts       # 必须存在
   ```

2. **验证配置语法**
   ```bash
   jq empty vercel.json        # 检查JSON语法
   ```

3. **使用备用配置**
   ```bash
   # 如果当前配置有问题
   cp docs/templates/vercel.minimal.json vercel.json
   ```

4. **恢复原配置**
   ```bash
   git checkout vercel.json    # 从git恢复
   ```
