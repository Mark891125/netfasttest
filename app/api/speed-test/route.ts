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

  // 去掉端口号（如 222.71.52.132:60783 -> 222.71.52.132）
  if (clientIp.includes(":") && !clientIp.includes("::")) {
    clientIp = clientIp.split(":")[0];
  }
  if (clientIp.startsWith("::ffff:")) {
    clientIp = clientIp.substring(7); // 去掉IPv6格式的前缀
  }

  return clientIp;
}
function matchIPByRule(ip: string, rule: string): boolean {
  try {
    return new RegExp(rule).test(ip);
  } catch {
    return false;
  }
}
async function getIPLocation(ip: string): Promise<string> {
  let location = "";
  const segmentDict = [
    {
      location: "未知网络",
      rule: "^[0-9a-fA-F:]{2,}$", // 匹配所有IPv6地址（只要包含冒号且长度大于2）
    },
    {
      location: "本地网络",
      rule: "^127\\.0\\.0\\.1$",
    },
    {
      location: "本地网络",
      rule: "^::1$",
    },
    {
      location: "本地网络",
      rule: "^192\\.168\\.[0-9]{1,3}\\.[0-9]{1,3}$",
    },
    {
      location: "本地网络",
      rule: "^10\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}$",
    },
    {
      location: "本地网络",
      rule: "^172\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}$",
    },
    {
      location: "Premium Node (Beijing 4)",
      rule: "^120\\.136\\.21\\.[0-9]{1,3}$",
    },
    {
      location: "Premium Node (Beijing 4)",
      rule: "^202\\.57\\.204\\.[0-9]{1,3}$",
    },
    {
      location: "Premium Node (Beijing 4)",
      rule: "^202\\.57\\.205\\.[0-9]{1,3}$",
    },

    {
      location: "Shanghai II",
      rule: "^140\\.210\\.(152|153)\\.[0-9]{1,3}$",
    },
    {
      location: "Beijing III",
      rule: "^220\\.243\\.(154|155)\\.[0-9]{1,3}$",
    },
    {
      location: "Hong Kong III",
      rule: "^202\\.57\\.(205|206)\\.[0-9]{1,3}$",
    },
    {
      location: "Hong Kong III",
      rule: "^165\\.225\\.(234|235)\\.[0-9]{1,3}$",
    },
    {
      location: "Hong Kong III",
      rule: "^136\\.226\\.(228|229)\\.[0-9]{1,3}$",
    },
    {
      location: "Hong Kong III",
      rule: "^167\\.103\\.(0|1)\\.[0-9]{1,3}$",
    },
  ];
  // 优先匹配字典表
  for (const seg of segmentDict) {
    if (matchIPByRule(ip, seg.rule)) {
      return seg.location;
    }
  }

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

// @Swagger

/**
 * @swagger
 * /api/speed-test:
 *   post:
 *     summary: 网络测速接口
 *     tags:
 *       - SpeedTest
 *     description: 客户端发送时间戳，服务端返回延迟、IP归属地等信息。
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               timestamp:
 *                 type: integer
 *                 description: 客户端发送的时间戳（毫秒）
 *     responses:
 *       200:
 *         description: 测试结果
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                     timestamp:
 *                       type: string
 *                     receptionTime:
 *                       type: integer
 *                     returnTime:
 *                       type: integer
 *                     ip:
 *                       type: string
 *                     location:
 *                       type: string
 */
export async function POST(request: NextRequest) {
  let clientIp = getRequestClientIP(request);
  const receptionTime = Date.now();
  // 获取请求信息
  const userAgent = request.headers.get("user-agent") || "";

  try {
    const requestBody = await request.json(); // 读取请求体
    const clientSendTime = requestBody.timestamp; // 客户端发送时间戳

    // 检测IP归属地
    const location = await getIPLocation(clientIp);

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
