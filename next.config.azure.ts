import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Azure App Service 配置 - 不使用 standalone
  // output: 'standalone', // 在 Azure 中暂时禁用

  // 外部包配置 (Next.js 15+)
  serverExternalPackages: ['geoip-lite'],
  
  // 性能优化
  poweredByHeader: false,
  compress: true,
  
  // 头部配置
  async headers() {
    return [
      {
        source: '/api/:path*',
        headers: [
          {
            key: 'Cache-Control',
            value: 'no-cache, no-store, must-revalidate',
          },
          {
            key: 'Access-Control-Allow-Origin',
            value: '*',
          },
          {
            key: 'Access-Control-Allow-Methods',
            value: 'GET, POST, OPTIONS',
          },
          {
            key: 'Access-Control-Allow-Headers',
            value: 'Content-Type, Authorization',
          },
        ],
      },
    ]
  },
};

export default nextConfig;
