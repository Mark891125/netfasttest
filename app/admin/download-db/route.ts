import { NextRequest, NextResponse } from "next/server";
import path from "path";
import fs from "fs/promises";

// 简单账号密码，生产环境请使用更安全方式
const USERNAME = "cc";
const PASSWORD = "r8X2pQwZ"; // 8位随机数

/**
 * @swagger
 * /admin/download-db:
 *   get:
 *     summary: 下载 sqlite 数据库文件
 *     description: 需基础认证（账号 cc，密码 r8X2pQwZ），下载当前容器内的 dev.db 文件。
 *     tags:
 *       - 运维
 *     security:
 *       - basicAuth: []
 *     responses:
 *       200:
 *         description: 成功返回数据库文件
 *         content:
 *           application/octet-stream:
 *             schema:
 *               type: string
 *               format: binary
 *       401:
 *         description: 未授权
 *       404:
 *         description: 数据库文件未找到
 */
export async function GET(request: NextRequest) {
  // 基础认证校验
  const authHeader = request.headers.get("Authorization") || "";
  let isAuth = false;
  if (authHeader.startsWith("Basic ")) {
    const base64 = authHeader.replace("Basic ", "");
    console.log("base64:", base64);
    try {
      const [user, pass] = Buffer.from(base64, "base64").toString().split(":");
      if (user === USERNAME && pass === PASSWORD) {
        isAuth = true;
      }
    } catch {}
  }
  if (!isAuth) {
    return new NextResponse("Unauthorized", {
      status: 401,
      headers: {
        "WWW-Authenticate": 'Basic realm="db-download"',
      },
    });
  }

  const dbPath = path.resolve(process.cwd(), "prisma/dev.db");
  try {
    const fileBuffer = await fs.readFile(dbPath);
    return new NextResponse(fileBuffer, {
      status: 200,
      headers: {
        "Content-Type": "application/octet-stream",
        "Content-Disposition": 'attachment; filename="dev.db"',
      },
    });
  } catch (err) {
    return new NextResponse("Database file not found", { status: 404 });
  }
}
