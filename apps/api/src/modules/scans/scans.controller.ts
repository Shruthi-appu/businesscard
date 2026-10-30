import { Controller, Get, Param, Post, UseGuards } from "@nestjs/common";
import { ApiBearerAuth, ApiOperation, ApiTags } from "@nestjs/swagger";

import { notImplemented } from "../../common/api.exception";
import { AccessAuthGuard } from "../../common/access-auth.guard";

@ApiTags("scans")
@ApiBearerAuth()
@UseGuards(AccessAuthGuard)
@Controller("scans")
export class ScansController {
  @Post()
  @ApiOperation({ summary: "Start a scan. Not available in this phase." })
  create(): never {
    return notImplemented("Scanning is not available yet");
  }

  @Get(":id")
  @ApiOperation({ summary: "Scan job status. Not available in this phase." })
  getOne(@Param("id") _id: string): never {
    return notImplemented("Scan status is not available yet");
  }
}
