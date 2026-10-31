import { Module } from "@nestjs/common";

import { AuditModule } from "../audit/audit.module";
import { AuthController } from "./auth.controller";
import { AuthService } from "./auth.service";
import { RateLimitService } from "./rate-limit.service";

@Module({
  imports: [AuditModule],
  controllers: [AuthController],
  providers: [AuthService, RateLimitService],
  exports: [RateLimitService],
})
export class AuthModule {}
