import { Controller, Get, Inject, Patch, UseGuards } from "@nestjs/common";
import { ApiBearerAuth, ApiOperation, ApiTags } from "@nestjs/swagger";

import { notImplemented } from "../../common/api.exception";
import { AccessAuthGuard } from "../../common/access-auth.guard";
import { CurrentUser } from "../../common/current-user";
import type { AccessPrincipal } from "../../common/request-context";
import { MeService } from "./me.service";

@ApiTags("me")
@ApiBearerAuth()
@Controller()
export class MeController {
  constructor(@Inject(MeService) private readonly me: MeService) {}

  @Get("me")
  @UseGuards(AccessAuthGuard)
  @ApiOperation({ summary: "The signed-in user. The id always comes from the access token." })
  getMe(@CurrentUser() user: AccessPrincipal) {
    return this.me.get(user.id);
  }

  @Patch("me")
  @UseGuards(AccessAuthGuard)
  @ApiOperation({ summary: "Profile update is a later phase." })
  patchMe(): never {
    return notImplemented("Profile update is not available yet");
  }
}
