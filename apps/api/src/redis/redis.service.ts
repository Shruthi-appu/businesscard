import { Inject, Injectable, OnModuleDestroy } from "@nestjs/common";
import Redis from "ioredis";

import { EnvService } from "../config/env.service";

@Injectable()
export class RedisService implements OnModuleDestroy {
  readonly client: Redis;

  constructor(@Inject(EnvService) env: EnvService) {
    this.client = new Redis(env.values.REDIS_URL, {
      lazyConnect: true,
      maxRetriesPerRequest: 1,
      enableOfflineQueue: false,
      connectTimeout: 2000,
      retryStrategy: () => null,
    });
  }

  private async connect(): Promise<void> {
    if (this.client.status === "wait") {
      await this.client.connect();
    }
  }

  async ping(): Promise<string> {
    await this.connect();
    return this.client.ping();
  }

  async incr(key: string, windowSeconds: number): Promise<number> {
    await this.connect();
    const count = await this.client.incr(key);
    if (count === 1) {
      await this.client.expire(key, windowSeconds);
    }
    return count;
  }

  async flushdb(): Promise<void> {
    await this.connect();
    await this.client.flushdb();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.client.status === "wait" || this.client.status === "end") return;
    await this.client.quit().catch(() => undefined);
  }
}
