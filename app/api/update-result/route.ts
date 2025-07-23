import { NextRequest, NextResponse } from "next/server";
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

/**
 * @swagger
 * /api/update-result:
 *   post:
 *     summary: 上传测速结果
 *     tags:
 *       - SpeedTest
 *     description: 接收 speed-test 接口测试结果的 id 和网络延迟。
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *                 - id
 *                 - delay
 *             properties:
 *               id:
 *                 type: string
 *                 description: SpeedTestResult 的唯一标识
 *               delay:
 *                 type: integer
 *                 description: 网络延迟（毫秒）
 *     responses:
 *       200:
 *         description: 上传结果
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 message:
 *                   type: string
 *       400:
 *         description: 请求参数错误或无效ID
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 message:
 *                   type: string
 *       500:
 *         description: 服务器内部错误
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 message:
 *                   type: string
 */
export async function POST(request: NextRequest) {
  try {
    const body = await request.json();

    const { id, delay } = body;
    if (id === undefined || delay === undefined) {
      return NextResponse.json(
        { success: false, message: "缺少必要参数" },
        { status: 400 }
      );
    }
    // 检查结果是否存在
    const testResult = await prisma.testResult.findUnique({
      where: { id },
    });
    if (testResult === null) {
      return NextResponse.json(
        { success: false, message: "无效的ID" },
        { status: 400 }
      );
    } else {
      testResult.delay = delay; // 更新延迟
      await prisma.testResult.update({
        where: { id },
        data: { delay },
      });

      console.log(`[上传结果] id: ${id}, 网络延迟: ${delay}ms`);
      return NextResponse.json({
        success: true,
        message: "上传测速结果成功",
      });
    }
  } catch (error) {
    const err = error as Error;
    if (err.name === "SyntaxError" || err.message?.includes("JSON")) {
      return NextResponse.json(
        { success: false, message: "请求体不是合法 JSON 格式" },
        { status: 400 }
      );
    } else {
      console.error("上传测速结果失败:", error);
      return NextResponse.json(
        { success: false, message: "保存失败" },
        { status: 500 }
      );
    }
  }
}
