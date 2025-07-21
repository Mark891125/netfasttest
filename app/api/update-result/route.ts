import { NextRequest, NextResponse } from "next/server";
/**
 * @swagger
 * /api/update-result:
 *   post:
 *     summary: 上传测速结果
 *     tags:
 *       - SpeedTest
 *     description: 接收 speed-test 接口的测试结果 id 和网络延迟，临时输出到控制台。
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
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
 */
export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { id, delay } = body;
    // 临时存储逻辑：输出到控制台
    console.log(`[上传测速结果] id: ${id}, 网络延迟: ${delay}ms`);
    return NextResponse.json({
      success: true,
      message: "测速结果已保存（控制台输出）",
    });
  } catch (error) {
    console.error("上传测速结果失败:", error);
    return NextResponse.json(
      { success: false, message: "保存失败" },
      { status: 500 }
    );
  }
}
