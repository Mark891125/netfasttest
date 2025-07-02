import { NextRequest, NextResponse } from "next/server";
import { format } from "date-fns";
import { v4 as uuidv4 } from "uuid";

interface SpeedTestResult {
  id: string;
  timestamp: string;
  ip: string;
  responseTime: number;
  requestSize: number;
  userAgent: string;
}

interface SpeedTestResult {
  id: string;
  timestamp: string;
  ip: string;
  responseTime: number;
  requestSize: number;
  userAgent: string;
}

export async function POST(request: NextRequest) {
  const serverReceiveTime = Date.now();

  // 获取客户端IP
  const forwarded = request.headers.get("x-forwarded-for");
  const realIp = request.headers.get("x-real-ip");
  let clientIp = forwarded ? forwarded.split(",")[0] : realIp || "127.0.0.1";
  if (clientIp.startsWith("::ffff:")) {
    // 去掉IPv6格式的前缀
    clientIp = clientIp.substring(7);
  }
  if (clientIp.indexOf(":")) {
    // 去掉IPv6格式的前缀
    clientIp = clientIp.split(":")[0];
  }

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
      responseTime: responseTime, // 这是准确的网络响应时间
      requestSize: parseInt(contentLength),
      userAgent,
    };
    // 打印响应时间信息
    console.log(
      `[${result.timestamp}] IP: ${result.ip}  | 网络延迟: ${
        result.responseTime
      }ms |  客户端发送时间: ${new Date(clientSendTime).toLocaleString()}`
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
  // 获取客户端IP
  const forwarded = request.headers.get("x-forwarded-for");
  const realIp = request.headers.get("x-real-ip");
  let clientIp = forwarded ? forwarded.split(",")[0] : realIp || "127.0.0.1";

  if (clientIp.startsWith("::ffff:")) {
    clientIp = clientIp.substring(7); // 去掉IPv6格式的前缀
  }
  // 打印到标准输出
  console.log(
    `[${format(new Date(), "yyyy-MM-dd HH:mm:ss")}] GET IP: ${clientIp} }`
  );

  return NextResponse.json({
    success: true,
    data: {
      ip: clientIp,
      timestamp: Date.now(),
    },
  });
}
