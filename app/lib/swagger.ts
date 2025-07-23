import { createSwaggerSpec } from "next-swagger-doc";
import packageJson from "@/package.json";

export const getApiDocs = async () => {
  const spec = createSwaggerSpec({
    apiFolder: "app/api", // define api folder under app folder
    definition: {
      openapi: "3.0.0",
      info: {
        title: "NetFastTest API",
        version: packageJson.version,
      },
      components: {},
      security: [],
    },
  });
  return spec;
};
