import { NextRequest, NextResponse } from 'next/server';
import { format } from 'date-fns';
import { v4 as uuidv4 } from 'uuid';

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

// 简单的IP地理位置查询函数
async function getLocationFromIP(ip: string) {
  try {
    // 标准化IP地址
    let cleanIp = ip;
    if (ip.startsWith('::ffff:')) {
      cleanIp = ip.substring(7); // 移除IPv6前缀
    }
    
    // 跳过私有IP和localhost
    if (cleanIp === '127.0.0.1' || cleanIp === '::1' || cleanIp.startsWith('192.168.') || cleanIp.startsWith('10.') || cleanIp.startsWith('172.')) {
      return {
        country: '本地',
        region: '本地网络',
        city: '本地',
        location: '本地网络'
      };
    }

    // 使用免费的IP地理位置API
    const response = await fetch(`http://ip-api.com/json/${cleanIp}?fields=status,country,regionName,city,lat,lon`);
    
    if (response.ok) {
      const data = await response.json();
      if (data.status === 'success') {
        return {
          country: data.country || '未知',
          region: data.regionName || '未知',
          city: data.city || '未知',
          location: `${data.country}, ${data.regionName}, ${data.city}`
        };
      }
    }
  } catch (error) {
    console.error('IP地理位置查询失败:', error);
  }
  
  // 回退到默认值
  return {
    country: '未知',
    region: '未知',
    city: '未知',
    location: '未知位置'
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
  const forwarded = request.headers.get('x-forwarded-for');
  const realIp = request.headers.get('x-real-ip');
  const clientIp = forwarded ? forwarded.split(',')[0] : realIp || '127.0.0.1';
  
  // 获取请求信息
  const userAgent = request.headers.get('user-agent') || '';
  const contentLength = request.headers.get('content-length') || '0';
  
  try {
    const requestBody = await request.json(); // 读取请求体
    const clientSendTime = requestBody.timestamp || serverReceiveTime; // 客户端发送时间戳
    
    let responseTime = serverReceiveTime - clientSendTime; // 网络传输时间
    
    // 防止负数响应时间（可能由于时间同步问题或时钟偏差）
    if (responseTime < 0) {
      console.warn(`检测到负数响应时间: ${responseTime}ms, 客户端时间: ${new Date(clientSendTime).toISOString()}, 服务器时间: ${new Date(serverReceiveTime).toISOString()}`);
      responseTime = Math.abs(responseTime); // 取绝对值，或者可以设为最小值如1ms
    }
    
    // 对于异常大的延迟也进行警告（可能是时钟问题）
    if (responseTime > 30000) { // 30秒
      console.warn(`检测到异常大的响应时间: ${responseTime}ms, 可能存在时钟同步问题`);
    }
    
    // 创建基础测试结果，先不包含地理位置信息
    const result: SpeedTestResult = {
      id: uuidv4(),
      timestamp: format(new Date(), 'yyyy-MM-dd HH:mm:ss'),
      ip: clientIp,
      location: '本地网络', // 默认值，避免外部API调用
      country: '本地',
      city: '本地',
      responseTime: responseTime, // 这是准确的网络响应时间
      requestSize: parseInt(contentLength),
      userAgent
    };
    
    // 只对非本地IP进行地理位置查询
    if (clientIp !== '127.0.0.1' && !clientIp.startsWith('192.168.') && !clientIp.startsWith('10.') && !clientIp.startsWith('172.')) {
      try {
        const geo = await getLocationFromIP(clientIp);
        result.location = geo.location;
        result.country = geo.country;
        result.city = geo.city;
      } catch {
        // 地理位置查询失败不影响响应时间测试
        console.log('地理位置查询失败，使用默认值');
      }
    }
    
    // 打印响应时间信息
    console.log(`[${result.timestamp}] IP: ${result.ip} | 位置: ${result.location} | 网络延迟: ${result.responseTime}ms | 大小: ${result.requestSize}bytes | 客户端发送时间: ${new Date(clientSendTime).toLocaleString()}`);
    
    return NextResponse.json({
      success: true,
      data: result
    });
    
  } catch (error) {
    console.error('速度测试错误:', error);
    return NextResponse.json(
      { success: false, error: '测试失败' },
      { status: 500 }
    );
  }
}

export async function GET(request: NextRequest) {
  const serverReceiveTime = Date.now();
  
  // 获取客户端IP
  const forwarded = request.headers.get('x-forwarded-for');
  const realIp = request.headers.get('x-real-ip');
  const clientIp = forwarded ? forwarded.split(',')[0] : realIp || '127.0.0.1';
  
  // 从查询参数获取客户端发送时间戳
  const url = new URL(request.url);
  const clientSendTime = parseInt(url.searchParams.get('timestamp') || serverReceiveTime.toString());
  
  // 检查是否是获取服务器时间的请求
  if (url.searchParams.get('action') === 'get-server-time') {
    return NextResponse.json({
      success: true,
      data: {
        serverTime: serverReceiveTime,
        timestamp: format(new Date(), 'yyyy-MM-dd HH:mm:ss')
      }
    });
  }
  
  let responseTime = serverReceiveTime - clientSendTime; // 网络传输延迟
  
  // 防止负数响应时间
  if (responseTime < 0) {
    console.warn(`GET请求检测到负数响应时间: ${responseTime}ms`);
    responseTime = Math.abs(responseTime);
  }
  
  // 默认地理位置信息
  let location = '本地网络';
  
  // 只对非本地IP进行地理位置查询
  if (clientIp !== '127.0.0.1' && !clientIp.startsWith('192.168.') && !clientIp.startsWith('10.') && !clientIp.startsWith('172.')) {
    try {
      const geo = await getLocationFromIP(clientIp);
      location = geo.location;
    } catch {
      location = '未知位置';
    }
  }
  
  // 打印到标准输出
  console.log(`[${format(new Date(), 'yyyy-MM-dd HH:mm:ss')}] GET IP: ${clientIp} | 位置: ${location} | 网络延迟: ${responseTime}ms | 客户端发送时间: ${new Date(clientSendTime).toLocaleString()}`);
  
  return NextResponse.json({
    success: true,
    data: {
      ip: clientIp,
      location: location,
      responseTime: responseTime,
      timestamp: format(new Date(), 'yyyy-MM-dd HH:mm:ss')
    }
  });
}
