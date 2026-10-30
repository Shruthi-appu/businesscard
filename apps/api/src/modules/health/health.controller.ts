import { Controller, Get, Inject, Res } from "@nestjs/common";
import { ApiOperation, ApiTags } from "@nestjs/swagger";
import type { Response } from "express";

import { HealthService } from "./health.service";

@ApiTags("health")
@Controller("health")
export class HealthController {
  constructor(@Inject(HealthService) private readonly health: HealthService) {}

  @Get()
  @ApiOperation({ summary: "Database, Redis, object storage, and queue health." })
  async getHealth(@Res({ passthrough: true }) res: Response) {
    const body = await this.health.check();
    res.status(body.status === "ok" ? 200 : 503);
    return body;
  }
}
