import { Module } from "@nestjs/common";

import { AuditModule } from "../audit/audit.module";
import { DigitalCardsController } from "./digital-cards.controller";
import { DigitalCardsService } from "./digital-cards.service";
import { PublicCardsController } from "./public-cards.controller";

@Module({
  imports: [AuditModule],
  controllers: [DigitalCardsController, PublicCardsController],
  providers: [DigitalCardsService],
})
export class DigitalCardsModule {}
