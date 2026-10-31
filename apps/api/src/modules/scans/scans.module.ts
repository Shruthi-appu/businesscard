import { Module } from "@nestjs/common";

import { AuditModule } from "../audit/audit.module";
import { IdempotencyModule } from "../idempotency/idempotency.module";
import { ScansController } from "./scans.controller";
import { ScansService } from "./scans.service";

@Module({
  imports: [AuditModule, IdempotencyModule],
  controllers: [ScansController],
  providers: [ScansService],
})
export class ScansModule {}
