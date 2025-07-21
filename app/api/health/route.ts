import { NextRequest, NextResponse } from "next/server";
import { format } from "date-fns";

// 定义连通性测试结果的接口
interface ConnectivityTestResult {
  url: string;
  success: boolean;
  responseTime?: number;
  error?: string;
}

// 测试外部网络连通性（通过百度和Google网站）
async function testExternalConnectivity(): Promise<{
  allSuccess: boolean;
  results: ConnectivityTestResult[];
}> {
  const testEndpoints = [
    "https://opendata.baidu.com/",
    "https://www.baidu.com/",
  ];
  const results: ConnectivityTestResult[] = [];

  // console.log("开始测试外部网络连通性...");

  // 测试所有端点并收集结果
  const testPromises = testEndpoints.map(async (url) => {
    const startTime = Date.now();
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 3000); // 3秒超时

      const response = await fetch(url, {
        method: "HEAD",
        signal: controller.signal,
        headers: {
          "User-Agent": "Mozilla/5.0 (compatible; NetFastTest/1.0)",
        },
      });

      clearTimeout(timeoutId);
      const responseTime = Date.now() - startTime;

      if (response.ok) {
        // console.log(`外部网络连通性测试成功 - ${url} (${responseTime}ms)`);
        results.push({
          url,
          success: true,
          responseTime,
        });
        return true;
      } else {
        // console.warn(`外部网络连通性测试失败 - ${url} (HTTP ${response.status})`);
        results.push({
          url,
          success: false,
          responseTime,
          error: `HTTP status: ${response.status}`,
        });
        return false;
      }
    } catch (error) {
      const responseTime = Date.now() - startTime;
      let errorMessage = "未知错误";

      if (error instanceof Error) {
        if (error.name === "AbortError") {
          // console.warn(`外部网络连通性测试超时 - ${url}`);
          errorMessage = "请求超时";
        } else {
          // console.warn(`外部网络连通性测试异常 - ${url}: ${error.message}`);
          errorMessage = error.message;
        }
      }

      results.push({
        url,
        success: false,
        responseTime,
        error: errorMessage,
      });
      return false;
    }
  });

  // 等待所有测试完成
  const testResults = await Promise.all(testPromises);
  const allSuccess = testResults.every((result) => result === true);

  // console.log(`外部网络连通性测试完成，全部成功: ${allSuccess}`);

  return {
    allSuccess,
    results,
  };
}
export async function GET(request: NextRequest) {
  // 检查是否有 _l 参数
  const url = new URL(request.url);
  const logEnabled = url.searchParams.has("_l");

  const healthCheck = {
    server: {
      status: "ok",
      timestamp: format(new Date(), "yyyy-MM-dd HH:mm:ss"),
    },
    connectivity: {
      external: false,
      result: [] as ConnectivityTestResult[],
      timestamp: format(new Date(), "yyyy-MM-dd HH:mm:ss"),
    },
  };

  // 测试外部连通性
  try {
    const connectivityTest = await testExternalConnectivity();
    healthCheck.connectivity.external = connectivityTest.allSuccess;
    healthCheck.connectivity.result = connectivityTest.results;
  } catch (error) {
    console.error("健康检查 - 外部连通性测试失败:", error);
  }
  if (logEnabled) {
    console.log("健康检查", healthCheck);
  }

  return NextResponse.json({
    success: true,
    data: healthCheck,
  });
}
