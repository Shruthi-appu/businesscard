import { Controller, Get, Param, Post, UseGuards } from "@nestjs/common";
import { ApiBearerAuth, ApiOperation, ApiTags } from "@nestjs/swagger";

import { notImplemented } from "../../common/api.exception";
import { AccessAuthGuard } from "../../common/access-auth.guard";

@ApiTags("shares")
@Controller()
export class SharesController {
  @Post("cards/:id/shares")
  @UseGuards(AccessAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: "Create a share link. Not available in this phase." })
  create(@Param("id") _id: string): never {
    return notImplemented("Sharing is not available yet");
  }

  @Get("cards/:id/shares")
  @UseGuards(AccessAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: "List share links. Not available in this phase." })
  list(@Param("id") _id: string): never {
    return notImplemented("Sharing is not available yet");
  }

  @Post("shares/:id/revoke")
  @UseGuards(AccessAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: "Revoke a share link. Not available in this phase." })
  revoke(@Param("id") _id: string): never {
    return notImplemented("Sharing is not available yet");
  }

  @Get("public/shares/:token")
  @ApiOperation({ summary: "Public share preview. Not available in this phase." })
  preview(@Param("token") _token: string): never {
    return notImplemented("Sharing is not available yet");
  }

  @Post("public/shares/:token/claim")
  @UseGuards(AccessAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: "Claim a share into the wallet. Not available in this phase." })
  claim(@Param("token") _token: string): never {
    return notImplemented("Sharing is not available yet");
  }
}
