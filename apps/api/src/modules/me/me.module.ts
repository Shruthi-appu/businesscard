import { Module } from "@nestjs/common";

import { AuditModule } from "../audit/audit.module";
import { AuthModule } from "../auth/auth.module";
import { IdempotencyModule } from "../idempotency/idempotency.module";
import { AccountController, AdminJobsController } from "./account.controller";
import { AccountService } from "./account.service";
import { MeController } from "./me.controller";
import { MeService } from "./me.service";

@Module({
  imports: [AuditModule, AuthModule, IdempotencyModule],
  controllers: [MeController, AccountController, AdminJobsController],
  providers: [MeService, AccountService],
  exports: [AccountService],
})
export class MeModule {}
