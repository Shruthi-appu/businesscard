import "reflect-metadata";

import { resolve } from "path";

import { config } from "dotenv";

import { createApp } from "./app.factory";
import { EnvService } from "./config/env.service";

config({ path: resolve(__dirname, "../../../.env"), override: false });
config({ path: resolve(__dirname, "../.env"), override: false });

async function main(): Promise<void> {
  const app = await createApp();
  const env = app.get(EnvService);
  await app.listen(env.values.PORT, "0.0.0.0");
}

void main();
