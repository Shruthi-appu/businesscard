import { Injectable } from "@nestjs/common";

import { loadEnv, type AppEnv } from "./env";

@Injectable()
export class EnvService {
  readonly values: AppEnv;

  constructor() {
    this.values = loadEnv();
  }

  get accessKey(): Uint8Array {
    return new TextEncoder().encode(this.values.JWT_ACCESS_SECRET);
  }
}
