import { Global, Module } from "@nestjs/common";

import { AccessAuthGuard } from "./common/access-auth.guard";
import { EnvService } from "./config/env.service";
import { createJobQueue } from "./queue/create-job-queue";
import { JOB_QUEUE } from "./queue/job-queue";
import { PrismaService } from "./prisma/prisma.service";
import { RedisService } from "./redis/redis.service";
import { createObjectStorage } from "./storage/create-object-storage";
import { OBJECT_STORAGE } from "./storage/object-storage";

@Global()
@Module({
  providers: [
    EnvService,
    PrismaService,
    RedisService,
    AccessAuthGuard,
    {
      provide: OBJECT_STORAGE,
      inject: [EnvService],
      useFactory: (env: EnvService) => createObjectStorage(env.values),
    },
    {
      provide: JOB_QUEUE,
      inject: [EnvService],
      useFactory: (env: EnvService) => createJobQueue(env.values),
    },
  ],
  exports: [EnvService, PrismaService, RedisService, AccessAuthGuard, OBJECT_STORAGE, JOB_QUEUE],
})
export class CoreModule {}
