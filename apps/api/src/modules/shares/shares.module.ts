import { Module } from "@nestjs/common";

import { AuditModule } from "../audit/audit.module";
import { AuthModule } from "../auth/auth.module";
import { IdempotencyModule } from "../idempotency/idempotency.module";
import { MessageSender } from "./message-sender";
import { SharesController } from "./shares.controller";
import { SharesService } from "./shares.service";

@Module({
  imports: [AuditModule, AuthModule, IdempotencyModule],
  controllers: [SharesController],
  providers: [SharesService, MessageSender],
})
export class SharesModule {}
