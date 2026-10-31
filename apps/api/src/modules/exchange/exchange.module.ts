import { Module } from "@nestjs/common";

import { AuditModule } from "../audit/audit.module";
import { AuthModule } from "../auth/auth.module";
import { IdempotencyModule } from "../idempotency/idempotency.module";
import { ExchangeController } from "./exchange.controller";
import { ExchangeService } from "./exchange.service";

@Module({
  imports: [AuditModule, AuthModule, IdempotencyModule],
  controllers: [ExchangeController],
  providers: [ExchangeService],
})
export class ExchangeModule {}
