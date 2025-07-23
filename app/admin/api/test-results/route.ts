import { NextRequest, NextResponse } from "next/server";
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

/**
 * @swagger
 * /admin/api/test-results:
 *   get:
 *     summary: 获取测试结果列表
 *     description: 获取数据库中的所有测试结果。
 *     tags:
 *       - 运维
 *     responses:
 *       200:
 *         description: 成功返回测试结果列表
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 type: object
 *       500:
 *         description: 服务器内部错误
 */
export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const keyword = searchParams.get("keyword")?.trim() || "";
    const date = searchParams.get("date")?.trim() || "";

    // 构建 where 条件
    const where: any = {};
    if (keyword) {
      where.OR = [
        { storeID: { contains: keyword } },
        { ip: { contains: keyword } },
        { location: { contains: keyword } },
      ];
    }
    if (date) {
      // 只支持 YYYY-MM-DD 格式
      const start = new Date(date + "T00:00:00.000Z");
      const end = new Date(date + "T23:59:59.999Z");
      // 以 clientTime 为主
      where.clientTime = {
        gte: start,
        lte: end,
      };
    }

    // 解析分页参数
    const page = Math.max(1, parseInt(searchParams.get("page") || "1", 10));
    const pageSize = Math.max(1, Math.min(200, parseInt(searchParams.get("pageSize") || "20", 10)));

    // 查询总数
    const total = await prisma.testResult.count({ where });

    // 查询分页数据
    const results = await prisma.testResult.findMany({
      where,
      orderBy: [
        { clientTime: "desc" },
        { id: "desc" }
      ],
      skip: (page - 1) * pageSize,
      take: pageSize,
    });

    return NextResponse.json({
      total,
      page,
      pageSize,
      results,
    });
  } catch (err) {
    console.error("Error fetching test results:", err);
    return new NextResponse("Internal Server Error", { status: 500 });
  }
}
