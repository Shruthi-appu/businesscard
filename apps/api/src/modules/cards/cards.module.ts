import { Module } from "@nestjs/common";

import { AuditModule } from "../audit/audit.module";
import { IdempotencyModule } from "../idempotency/idempotency.module";
import { CardsController } from "./cards.controller";
import { CardsService } from "./cards.service";
import { WalletController } from "./wallet.controller";

@Module({
  imports: [AuditModule, IdempotencyModule],
  controllers: [CardsController, WalletController],
  providers: [CardsService],
})
export class CardsModule {}
