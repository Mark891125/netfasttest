import { NextRequest, NextResponse } from "next/server";
import { format } from "date-fns";
import { v4 as uuidv4 } from "uuid";

interface SpeedTestResult {
  id: string;
  timestamp: string;
  ip: string;
  location: string;
  country: string;
  city: string;
  responseTime: number;
  requestSize: number;
  userAgent: string;
}

// 测试外部网络连通性（通过Chanel和Google网站）
async function testExternalConnectivity(): Promise<boolean> {
  const testEndpoints = [
    "https://www.chanel.com/",
    "https://www.google.com/"
  ];

  console.log("开始测试外部网络连通性...");

  // 并发测试多个端点，任何一个成功即认为连通性正常
  const testPromises = testEndpoints.map(async (url) => {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 3000); // 3秒超时

      const response = await fetch(url, {
        method: "HEAD",
        signal: controller.signal,
        headers: {
          "User-Agent": "Mozilla/5.0 (compatible; NetFastTest/1.0)"
        }
      });

      clearTimeout(timeoutId);
      
      if (response.ok) {
        console.log(`外部网络连通性测试成功 - ${url}`);
        return true;
      }
      return false;
    } catch (error) {
      if (error instanceof Error) {
        if (error.name === 'AbortError') {
          console.warn(`外部网络连通性测试超时 - ${url}`);
        } else {
          console.warn(`外部网络连通性测试异常 - ${url}: ${error.message}`);
        }
      }
      return false;
    }
  });

  try {
    // 使用 Promise.any 只要有一个成功就返回 true
    await Promise.any(testPromises);
    return true;
  } catch (error) {
    console.error("所有外部网络连通性测试都失败");
    return false;
  }
}

// 两个主要的IP地理位置API配置
const IP_APIS = [
  {
    name: "ipapi.co",
    url: (ip: string) => `https://ipapi.co/${ip}/json/`,
    parseResponse: (data: any) => ({
      success: !data.error,
      country: data.country_name,
      region: data.region,
      city: data.city,
      message: data.reason
    })
  },
  {
    name: "ip-api.com",
    url: (ip: string) => `http://ip-api.com/json/${ip}?fields=status,country,regionName,city,lat,lon`,
    parseResponse: (data: any) => ({
      success: data.status === "success",
      country: data.country,
      region: data.regionName,
      city: data.city,
      message: data.message
    })
  }
];

// 基于IP段的简单地理位置推测（备用方案）
function getLocationFromIPPattern(ip: string) {
  const firstOctet = parseInt(ip.split('.')[0]);
  
  // 基于IP地址段的简单推测
  if (firstOctet >= 1 && firstOctet <= 126) {
    // A类地址段，多为亚太地区
    return {
      country: "亚太地区",
      region: "未知省份",
      city: "未知城市",
      location: "亚太地区（网络受限）",
    };
  } else if (firstOctet >= 128 && firstOctet <= 191) {
    // B类地址段，多为欧美地区
    return {
      country: "欧美地区",
      region: "未知州省",
      city: "未知城市",
      location: "欧美地区（网络受限）",
    };
  } else if (firstOctet >= 192 && firstOctet <= 223) {
    // C类地址段
    return {
      country: "其他地区",
      region: "未知区域",
      city: "未知城市",
      location: "其他地区（网络受限）",
    };
  } else {
    return {
      country: "未知",
      region: "网络受限",
      city: "无法查询",
      location: "网络连接受限，无法确定位置",
    };
  }
}

// 改进的IP地理位置查询函数，支持多个API和连通性测试
async function getLocationFromIP(ip: string) {
  // 标准化IP地址
  let cleanIp = ip;
  if (ip.startsWith("::ffff:")) {
    cleanIp = ip.substring(7); // 移除IPv6前缀
  }

  // 跳过私有IP和localhost
  if (
    cleanIp === "127.0.0.1" ||
    cleanIp === "::1" ||
    cleanIp.startsWith("192.168.") ||
    cleanIp.startsWith("10.") ||
    cleanIp.startsWith("172.")
  ) {
    return {
      country: "本地",
      region: "本地网络",
      city: "本地",
      location: "本地网络",
    };
  }

  // 首先测试外部网络连通性
  const hasConnectivity = await testExternalConnectivity();
  if (!hasConnectivity) {
    console.warn("外部网络连通性测试失败，使用基于IP段的简单推测");
    return getLocationFromIPPattern(cleanIp);
  }

  // 尝试多个API服务
  for (const api of IP_APIS) {
    try {
      console.log(`尝试使用 ${api.name} 查询IP地理位置...`);
      
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 8000); // 8秒超时
      
      const response = await fetch(api.url(cleanIp), {
        signal: controller.signal,
        headers: {
          "User-Agent": "Mozilla/5.0 (compatible; NetFastTest/1.0)"
        }
      });

      clearTimeout(timeoutId);

      // 处理速率限制
      if (response.status === 429) {
        const remainingRequests = response.headers.get("X-Rl") || "0";
        const resetTime = response.headers.get("X-Ttl") || "60";
        console.warn(`${api.name} 速率限制已达到 (HTTP 429) - IP: ${cleanIp}`);
        console.warn(`剩余请求数: ${remainingRequests}, 重置时间: ${resetTime}秒`);
        continue; // 尝试下一个API
      }

      if (!response.ok) {
        console.warn(`${api.name} HTTP错误: ${response.status}`);
        continue; // 尝试下一个API
      }

      const data = await response.json();
      const parsed = api.parseResponse(data);

      if (parsed.success && parsed.country) {
        console.log(`${api.name} 查询成功 - IP: ${cleanIp} -> ${parsed.country}, ${parsed.region}, ${parsed.city}`);
        return {
          country: parsed.country || "未知",
          region: parsed.region || "未知",
          city: parsed.city || "未知",
          location: `${parsed.country}, ${parsed.region}, ${parsed.city}`,
        };
      } else {
        console.warn(`${api.name} 查询失败: ${parsed.message || "未知错误"}`);
        continue; // 尝试下一个API
      }

    } catch (error) {
      if (error instanceof Error) {
        if (error.name === 'AbortError') {
          console.error(`${api.name} 查询超时 - IP: ${cleanIp}`);
        } else {
          console.error(`${api.name} 查询异常 - IP: ${cleanIp}, 错误: ${error.message}`);
        }
      }
      continue; // 尝试下一个API
    }
  }

  // 所有API都失败后的处理
  console.warn(`所有IP地理位置API都失败，使用默认值 - IP: ${cleanIp}`);
  return {
    country: "查询失败",
    region: "网络异常",
    city: "查询失败",
    location: "地理位置查询失败",
  };
}

interface SpeedTestResult {
  id: string;
  timestamp: string;
  ip: string;
  location: string;
  country: string;
  city: string;
  responseTime: number;
  requestSize: number;
  userAgent: string;
}

export async function POST(request: NextRequest) {
  const serverReceiveTime = Date.now();

  // 获取客户端IP
  const forwarded = request.headers.get("x-forwarded-for");
  const realIp = request.headers.get("x-real-ip");
  const clientIp = forwarded ? forwarded.split(",")[0] : realIp || "127.0.0.1";

  // 获取请求信息
  const userAgent = request.headers.get("user-agent") || "";
  const contentLength = request.headers.get("content-length") || "0";

  try {
    const requestBody = await request.json(); // 读取请求体
    const clientSendTime = requestBody.timestamp || serverReceiveTime; // 客户端发送时间戳

    let responseTime = serverReceiveTime - clientSendTime; // 网络传输时间

    // 防止负数响应时间（可能由于时间同步问题或时钟偏差）
    if (responseTime < 0) {
      console.warn(
        `检测到负数响应时间: ${responseTime}ms, 客户端时间: ${new Date(
          clientSendTime
        ).toISOString()}, 服务器时间: ${new Date(
          serverReceiveTime
        ).toISOString()}`
      );
      responseTime = Math.abs(responseTime); // 取绝对值，或者可以设为最小值如1ms
    }

    // 对于异常大的延迟也进行警告（可能是时钟问题）
    if (responseTime > 30000) {
      // 30秒
      console.warn(
        `检测到异常大的响应时间: ${responseTime}ms, 可能存在时钟同步问题`
      );
    }

    // 创建基础测试结果，先不包含地理位置信息
    const result: SpeedTestResult = {
      id: uuidv4(),
      timestamp: format(new Date(), "yyyy-MM-dd HH:mm:ss"),
      ip: clientIp,
      location: "本地网络", // 默认值，避免外部API调用
      country: "本地",
      city: "本地",
      responseTime: responseTime, // 这是准确的网络响应时间
      requestSize: parseInt(contentLength),
      userAgent,
    };

    // 只对非本地IP进行地理位置查询
    if (
      clientIp !== "127.0.0.1" &&
      !clientIp.startsWith("192.168.") &&
      !clientIp.startsWith("10.") &&
      !clientIp.startsWith("172.")
    ) {
      try {
        const geo = await getLocationFromIP(clientIp);
        result.location = geo.location;
        result.country = geo.country;
        result.city = geo.city;
      } catch {
        // 地理位置查询失败不影响响应时间测试
        console.log("地理位置查询失败，使用默认值");
      }
    }

    // 打印响应时间信息
    console.log(
      `[${result.timestamp}] IP: ${result.ip} | 位置: ${
        result.location
      } | 网络延迟: ${result.responseTime}ms | 大小: ${
        result.requestSize
      }bytes | 客户端发送时间: ${new Date(clientSendTime).toLocaleString()}`
    );

    return NextResponse.json({
      success: true,
      data: result,
    });
  } catch (error) {
    console.error("速度测试错误:", error);
    return NextResponse.json(
      { success: false, error: "测试失败" },
      { status: 500 }
    );
  }
}

export async function GET(request: NextRequest) {
  const serverReceiveTime = Date.now();

  // 获取客户端IP
  const forwarded = request.headers.get("x-forwarded-for");
  const realIp = request.headers.get("x-real-ip");
  const clientIp = forwarded ? forwarded.split(",")[0] : realIp || "127.0.0.1";

  // 从查询参数获取客户端发送时间戳
  const url = new URL(request.url);
  const clientSendTime = parseInt(
    url.searchParams.get("timestamp") || serverReceiveTime.toString()
  );

  // 检查是否是获取服务器时间的请求
  if (url.searchParams.get("action") === "get-server-time") {
    return NextResponse.json({
      success: true,
      data: {
        serverTime: serverReceiveTime,
        timestamp: format(new Date(), "yyyy-MM-dd HH:mm:ss"),
      },
    });
  }

  // 检查是否是健康检查请求
  if (url.searchParams.get("action") === "health-check") {
    console.log("开始执行健康检查...");
    
    interface ServiceStatus {
      name: string;
      status: string;
      response_time: number;
      error: string | null;
    }
    
    const healthCheck = {
      server: {
        status: "ok",
        timestamp: format(new Date(), "yyyy-MM-dd HH:mm:ss"),
        serverTime: serverReceiveTime
      },
      connectivity: {
        external: false,
        tested_at: format(new Date(), "yyyy-MM-dd HH:mm:ss")
      },
      ip_services: {
        available: 0,
        total: IP_APIS.length,
        details: [] as ServiceStatus[]
      }
    };

    // 测试外部连通性
    try {
      healthCheck.connectivity.external = await testExternalConnectivity();
    } catch (error) {
      console.error("健康检查 - 外部连通性测试失败:", error);
    }

    // 测试IP地理位置服务
    if (healthCheck.connectivity.external) {
      console.log("测试IP地理位置服务可用性...");
      const testIP = "8.8.8.8"; // 使用Google DNS作为测试IP
      
      for (const api of IP_APIS) {
        const serviceStatus: ServiceStatus = {
          name: api.name,
          status: "unknown",
          response_time: 0,
          error: null
        };

        try {
          const startTime = Date.now();
          const controller = new AbortController();
          const timeoutId = setTimeout(() => controller.abort(), 5000);

          const response = await fetch(api.url(testIP), {
            signal: controller.signal,
            headers: {
              "User-Agent": "Mozilla/5.0 (compatible; NetFastTest-HealthCheck/1.0)"
            }
          });

          clearTimeout(timeoutId);
          serviceStatus.response_time = Date.now() - startTime;

          if (response.ok) {
            const data = await response.json();
            const parsed = api.parseResponse(data);
            
            if (parsed.success) {
              serviceStatus.status = "available";
              healthCheck.ip_services.available++;
            } else {
              serviceStatus.status = "error";
              serviceStatus.error = parsed.message || "API返回错误";
            }
          } else {
            serviceStatus.status = "http_error";
            serviceStatus.error = `HTTP ${response.status}`;
          }
        } catch (error) {
          serviceStatus.status = "failed";
          if (error instanceof Error) {
            serviceStatus.error = error.name === 'AbortError' ? "timeout" : error.message;
          }
        }

        healthCheck.ip_services.details.push(serviceStatus);
      }
    }

    return NextResponse.json({
      success: true,
      data: healthCheck
    });
  }

  let responseTime = serverReceiveTime - clientSendTime; // 网络传输延迟

  // 防止负数响应时间
  if (responseTime < 0) {
    console.warn(`GET请求检测到负数响应时间: ${responseTime}ms`);
    responseTime = Math.abs(responseTime);
  }

  // 默认地理位置信息
  let location = "本地网络";

  // 只对非本地IP进行地理位置查询
  if (
    clientIp !== "127.0.0.1" &&
    !clientIp.startsWith("192.168.") &&
    !clientIp.startsWith("10.") &&
    !clientIp.startsWith("172.")
  ) {
    try {
      const geo = await getLocationFromIP(clientIp);
      location = geo.location;
    } catch {
      location = "未知位置";
    }
  }

  // 打印到标准输出
  console.log(
    `[${format(
      new Date(),
      "yyyy-MM-dd HH:mm:ss"
    )}] GET IP: ${clientIp} | 位置: ${location} | 网络延迟: ${responseTime}ms | 客户端发送时间: ${new Date(
      clientSendTime
    ).toLocaleString()}`
  );

  return NextResponse.json({
    success: true,
    data: {
      ip: clientIp,
      location: location,
      responseTime: responseTime,
      timestamp: format(new Date(), "yyyy-MM-dd HH:mm:ss"),
    },
  });
}
