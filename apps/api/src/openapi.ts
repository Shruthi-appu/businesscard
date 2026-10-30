import "reflect-metadata";

import { writeFileSync } from "fs";
import { resolve } from "path";

import { config } from "dotenv";
import { SwaggerModule } from "@nestjs/swagger";

import { createApp } from "./app.factory";
import { swaggerConfig } from "./swagger";

config({ path: resolve(__dirname, "../../../.env"), override: false });

async function main(): Promise<void> {
  const app = await createApp();
  const document = SwaggerModule.createDocument(app, swaggerConfig());
  const target = resolve(__dirname, "../openapi.json");
  writeFileSync(target, `${JSON.stringify(document, null, 2)}\n`);
  await app.close();
}

main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
