import { Controller, Get, Param, Post, UseGuards } from "@nestjs/common";
import { ApiBearerAuth, ApiOperation, ApiTags } from "@nestjs/swagger";

import { notImplemented } from "../../common/api.exception";
import { AccessAuthGuard } from "../../common/access-auth.guard";

@ApiTags("exchange")
@ApiBearerAuth()
@UseGuards(AccessAuthGuard)
@Controller("exchange-sessions")
export class ExchangeController {
  @Post()
  @ApiOperation({ summary: "Open an exchange session. Not available in this phase." })
  create(): never {
    return notImplemented("Exchange is not available yet");
  }

  @Get(":id")
  @ApiOperation({ summary: "Read an exchange session. Not available in this phase." })
  getOne(@Param("id") _id: string): never {
    return notImplemented("Exchange is not available yet");
  }

  @Post(":id/join")
  @ApiOperation({ summary: "Join an exchange session. Not available in this phase." })
  join(@Param("id") _id: string): never {
    return notImplemented("Exchange is not available yet");
  }

  @Post(":id/consent")
  @ApiOperation({ summary: "Consent to an exchange. Not available in this phase." })
  consent(@Param("id") _id: string): never {
    return notImplemented("Exchange is not available yet");
  }

  @Post(":id/complete")
  @ApiOperation({ summary: "Complete an exchange. Not available in this phase." })
  complete(@Param("id") _id: string): never {
    return notImplemented("Exchange is not available yet");
  }
}
