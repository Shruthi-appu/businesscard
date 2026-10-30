import { Controller, Get, Param, Patch, Post, UseGuards } from "@nestjs/common";
import { ApiBearerAuth, ApiOperation, ApiTags } from "@nestjs/swagger";

import { notImplemented } from "../../common/api.exception";
import { AccessAuthGuard } from "../../common/access-auth.guard";

@ApiTags("cards")
@ApiBearerAuth()
@UseGuards(AccessAuthGuard)
@Controller("cards")
export class CardsController {
  @Get()
  @ApiOperation({ summary: "List the caller's cards. Phase 1 returns an empty wallet." })
  list() {
    return { items: [], nextCursor: null };
  }

  @Post()
  @ApiOperation({ summary: "Create a card. Not available in this phase." })
  create(): never {
    return notImplemented("Creating cards is not available yet");
  }

  @Get(":id")
  @ApiOperation({ summary: "Read one card. Not available in this phase." })
  getOne(@Param("id") _id: string): never {
    return notImplemented("Card detail is not available yet");
  }

  @Patch(":id")
  @ApiOperation({ summary: "Update a card. Not available in this phase." })
  patch(@Param("id") _id: string): never {
    return notImplemented("Card update is not available yet");
  }
}
