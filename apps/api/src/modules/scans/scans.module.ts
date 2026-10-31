import { Module } from "@nestjs/common";

import { AuditModule } from "../audit/audit.module";
import { AuthModule } from "../auth/auth.module";
import { IdempotencyModule } from "../idempotency/idempotency.module";
import { ScansController } from "./scans.controller";
import { ScansService } from "./scans.service";

@Module({
  imports: [AuditModule, AuthModule, IdempotencyModule],
  controllers: [ScansController],
  providers: [ScansService],
})
export class ScansModule {}
