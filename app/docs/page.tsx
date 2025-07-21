import { redirect } from "next/navigation";
import { getApiDocs } from "../lib/swagger";
import ReactSwagger from "./swagger";
// 判断是否为生产环境
const isProd = process.env.NODE_ENV === "production";

export default async function IndexPage() {
  if (isProd) {
    redirect("/403");
  }
  const spec = await getApiDocs();
  return (
    <section className="container">
      <ReactSwagger spec={spec} />
    </section>
  );
}
