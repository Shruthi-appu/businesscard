import { Controller, Get, Param, Post, UseGuards } from "@nestjs/common";
import { ApiBearerAuth, ApiOperation, ApiTags } from "@nestjs/swagger";

import { notImplemented } from "../../common/api.exception";
import { AccessAuthGuard } from "../../common/access-auth.guard";

@ApiTags("assets")
@ApiBearerAuth()
@UseGuards(AccessAuthGuard)
@Controller("assets")
export class AssetsController {
  @Post("presign")
  @ApiOperation({ summary: "Presign a logo or avatar upload. Not available in this phase." })
  presign(): never {
    return notImplemented("Asset upload is not available yet");
  }

  @Get(":id/url")
  @ApiOperation({ summary: "Presign a download. Not available in this phase." })
  url(@Param("id") _id: string): never {
    return notImplemented("Asset download is not available yet");
  }
}
