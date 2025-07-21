import { getApiDocs } from "@/app/lib/swagger";
import { NextRequest, NextResponse } from "next/server";

// 判断是否为生产环境
const isProd = process.env.NODE_ENV === "production";

export async function GET(request: NextRequest) {
  if (isProd) {
    return NextResponse.json(
      {
        error: "Forbidden",
        message: "您没有权限访问此页面。",
      },
      { status: 403 }
    );
  }
  const doc = await getApiDocs();
  return NextResponse.json(doc);
}
