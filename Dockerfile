# 使用官方 Node.js 镜像作为基础镜像
FROM node:20-alpine AS base

# 安装依赖阶段
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

# 复制 package files
COPY package.json package-lock.json* ./
# 安装所有依赖（包括 devDependencies，构建时需要）
RUN npm ci

# 构建阶段
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# 删除 Swagger 文档相关文件（生产环境不包含）
# RUN rm -rf app/docs

# 设置环境变量
ENV NEXT_TELEMETRY_DISABLED 1

# 构建应用
RUN npm run build

# 生产依赖阶段
FROM base AS prod-deps
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev && npm cache clean --force

# 运行阶段
FROM base AS runner
WORKDIR /app

ENV NODE_ENV production
ENV NEXT_TELEMETRY_DISABLED 1

# 安装 SSH 服务器（Azure App Service 要求）
RUN apk add --no-cache openssh
# 创建 SSH 配置目录
RUN mkdir -p /etc/ssh
# 复制 SSH 配置文件
COPY sshd_config /etc/ssh/
# 设置 SSH 主机密钥
RUN ssh-keygen -A
# 设置 root 密码为 Docker!（Azure App Service 要求）
RUN echo "root:Docker!" | chpasswd

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 --shell /bin/sh nextjs

# 复制 standalone 应用（包含自己的 node_modules 和 server.js）
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./

# 复制静态文件
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder --chown=nextjs:nodejs /app/public ./public

EXPOSE 80 2222

ENV PORT 80
ENV HOSTNAME "0.0.0.0"

# 保持 root 用户，启动 SSH 服务后以 nextjs 用户运行应用
CMD ["/bin/sh", "-c", "/usr/sbin/sshd -D & exec su nextjs -c 'node server.js'"]
