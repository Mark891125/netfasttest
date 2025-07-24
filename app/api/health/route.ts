import { NextRequest, NextResponse } from "next/server";
import { format } from "date-fns";
import packageJson from "@/package.json";

export async function GET(request: NextRequest) {
  // 检查是否有 _l 参数
  const url = new URL(request.url);
  const logEnabled = url.searchParams.has("_l");

  const healthCheck = {
    version: packageJson.version,
    timestamp: format(new Date(), "yyyy-MM-dd HH:mm:ss"),
  };

  if (logEnabled) {
    console.log("健康检查", healthCheck);
  }

  return NextResponse.json({
    success: true,
    data: healthCheck,
  });
}
