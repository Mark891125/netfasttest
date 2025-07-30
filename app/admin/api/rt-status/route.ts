import { NextRequest, NextResponse } from "next/server";
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

export async function GET(request: NextRequest) {
  try {
    const rtInterval = 30 * 60 * 1000; // 30分钟
    const now = Date.now();
    const startTime = new Date(now - rtInterval);

    // 查询所有店铺
    const stores = await prisma.store.findMany();
    // 使用原生 SQL 查询每个店铺最新30条（30分钟内）测试数据
    // 以PostgreSQL为例，使用窗口函数
    const rawResults: [] = await prisma.$queryRawUnsafe(
      `
      SELECT *
      FROM (
        SELECT *,
          ROW_NUMBER() OVER (PARTITION BY "storeID" ORDER BY "clientTime" DESC) as rn
        FROM "testResult"
        WHERE "clientTime" >= $1
      ) t
      WHERE t.rn <= 10
      ORDER BY "storeID" ASC, "clientTime" DESC
    `,
      startTime
    );

    const safeResults = rawResults.map((row: any) => {
      const obj: any = {};
      for (const key in row) {
        obj[key] =
          typeof row[key] === "bigint" ? row[key].toString() : row[key];
      }
      return obj;
    });

    // 按店铺分组
    const grouped = stores.map((store) => ({
      storeCode: store.id,
      storeName: store.name,
      testResult: safeResults.filter((r) => r.storeID === store.code),
      storeLatitude: store?.latitude || null,
      storeLongitude: store?.longitude || null,
    }));

    return NextResponse.json({ results: grouped });
  } catch (err) {
    console.error("Error fetching rt-status:", err);
    return new NextResponse("Internal Server Error", { status: 500 });
  }
}
