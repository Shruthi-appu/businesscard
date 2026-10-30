import { Inject, Injectable } from "@nestjs/common";
import type { HealthResponse } from "@softxu/contracts";

import { JOB_QUEUE, type JobQueue } from "../../queue/job-queue";
import { PrismaService } from "../../prisma/prisma.service";
import { RedisService } from "../../redis/redis.service";
import { OBJECT_STORAGE, type ObjectStorage } from "../../storage/object-storage";

@Injectable()
export class HealthService {
  constructor(
    @Inject(PrismaService) private readonly prisma: PrismaService,
    @Inject(RedisService) private readonly redis: RedisService,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorage,
    @Inject(JOB_QUEUE) private readonly queue: JobQueue,
  ) {}

  async check(): Promise<HealthResponse> {
    const checks: HealthResponse["checks"] = {
      database: "ok",
      redis: "ok",
      storage: "ok",
      queue: "ok",
    };
    try {
      await this.prisma.$queryRaw`SELECT 1`;
    } catch {
      checks.database = "error";
    }
    try {
      await this.redis.ping();
    } catch {
      checks.redis = "error";
    }
    try {
      await this.storage.health();
    } catch {
      checks.storage = "error";
    }
    try {
      await this.queue.health();
    } catch {
      checks.queue = "error";
    }
    const status = Object.values(checks).every((value) => value === "ok") ? "ok" : "degraded";
    return { status, checks, storage: this.storage.kind, queue: this.queue.kind };
  }
}
