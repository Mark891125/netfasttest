import { NextRequest, NextResponse } from "next/server";
import { format } from "date-fns";
import { v4 as uuidv4 } from "uuid";

interface SpeedTestResult {
  id: string;
  timestamp: string;
  receptionTime: number;
  returnTime: number;
  ip: string;
  location?: string;
}

function getRequestClientIP(request: NextRequest): string {
  // 获取客户端IP
  const forwarded = request.headers.get("x-forwarded-for");
  const realIp = request.headers.get("x-real-ip");
  let clientIp = forwarded ? forwarded.split(",")[0] : realIp || "127.0.0.1";

  if (clientIp.startsWith("::ffff:")) {
    clientIp = clientIp.substring(7); // 去掉IPv6格式的前缀
  }

  if (clientIp.indexOf(":")) {
    // 去掉IPv6格式的前缀
    clientIp = clientIp.split(":")[0];
  }
  // return "220.12.41.11";
  return clientIp;
}
async function getIPLocation(ip: string): Promise<string> {
  let location = "";
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 3000); // 3秒超时

    const locationResponse = await fetch(
      `http://opendata.baidu.com/api.php?query=${ip}&resource_id=6006&oe=utf8`,
      {
        signal: controller.signal,
      }
    );

    clearTimeout(timeoutId); // 清除超时定时器

    if (locationResponse.ok) {
      const locationData = await locationResponse.json();
      if (locationData.data && locationData.data.length > 0) {
        const locationInfo = locationData.data[0];
        location = locationInfo.location || "";
      }
    }
    return location;
  } catch (error) {
    console.warn("获取IP归属地失败:", error);
    return "";
  }
}

export async function POST(request: NextRequest) {
  let clientIp = getRequestClientIP(request);
  const receptionTime = Date.now();
  // 获取请求信息
  const userAgent = request.headers.get("user-agent") || "";

  try {
    const requestBody = await request.json(); // 读取请求体
    const clientSendTime = requestBody.timestamp; // 客户端发送时间戳

    // 检测IP归属地
    let location = "";
    if (
      clientIp == "127.0.0.1" ||
      clientIp.startsWith("::1") ||
      clientIp.startsWith("192.168.") ||
      clientIp.startsWith("10.") ||
      clientIp.startsWith("172.")
    ) {
      location = "本地网络";
    } else {
      location = await getIPLocation(clientIp);
    }
    // 创建基础测试结果，先不包含地理位置信息
    const result: SpeedTestResult = {
      id: uuidv4(),
      timestamp: format(new Date(), "yyyy-MM-dd HH:mm:ss"),
      returnTime: Date.now(),
      receptionTime,
      ip: clientIp,
      location,
    };
    // 打印响应时间信息
    console.log(
      `[${result.timestamp}] IP: ${result.ip}  | 
      延迟: ${receptionTime - clientSendTime}ms |
      位置: ${result.location || "未知"} |
      代理: ${userAgent} |        
      时间: ${new Date(clientSendTime).toLocaleString()}`
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
  let clientIp = getRequestClientIP(request);

  // 获取客户端发送时间戳
  const url = new URL(request.url);
  const clientSendTime = url.searchParams.get("_t");
  const clientSendTimeMs = clientSendTime
    ? parseInt(clientSendTime)
    : Date.now();

  // 打印到标准输出
  console.log(
    `[${format(
      new Date(),
      "yyyy-MM-dd HH:mm:ss"
    )}] GET IP: ${clientIp} ｜ 发送时间: ${new Date(
      clientSendTimeMs
    ).toLocaleString()}`
  );

  return NextResponse.json({
    success: true,
    data: {
      ip: clientIp,
      receptionTime: clientSendTimeMs,
      returnTime: Date.now(),
    },
  });
}
