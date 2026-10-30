import { Module } from "@nestjs/common";

import { CoreModule } from "./core.module";
import { AssetsModule } from "./modules/assets/assets.module";
import { AuditModule } from "./modules/audit/audit.module";
import { AuthModule } from "./modules/auth/auth.module";
import { CardsModule } from "./modules/cards/cards.module";
import { ExchangeModule } from "./modules/exchange/exchange.module";
import { HealthModule } from "./modules/health/health.module";
import { IdempotencyModule } from "./modules/idempotency/idempotency.module";
import { MeModule } from "./modules/me/me.module";
import { ScansModule } from "./modules/scans/scans.module";
import { SharesModule } from "./modules/shares/shares.module";

@Module({
  imports: [
    CoreModule,
    AuditModule,
    IdempotencyModule,
    AuthModule,
    MeModule,
    CardsModule,
    AssetsModule,
    ScansModule,
    SharesModule,
    ExchangeModule,
    HealthModule,
  ],
})
export class AppModule {}
