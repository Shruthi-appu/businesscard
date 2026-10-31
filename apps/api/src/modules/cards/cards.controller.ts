import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  Inject,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from "@nestjs/common";
import { ApiBearerAuth, ApiOperation, ApiTags } from "@nestjs/swagger";
import {
  cardListQuerySchema,
  createCardRequestSchema,
  patchCardRequestSchema,
  replaceVersionRequestSchema,
  type CreateCardRequest,
  type PatchCardRequest,
  type ReplaceVersionRequest,
} from "@softxu/contracts";

import { AccessAuthGuard } from "../../common/access-auth.guard";
import { CurrentUser } from "../../common/current-user";
import type { AccessPrincipal, RequestWithContext } from "../../common/request-context";
import { ZodValidationPipe } from "../../common/zod.pipe";
import { CardsService } from "./cards.service";

@ApiTags("cards")
@ApiBearerAuth()
@UseGuards(AccessAuthGuard)
@Controller("cards")
export class CardsController {
  constructor(@Inject(CardsService) private readonly cards: CardsService) {}

  @Get()
  @ApiOperation({ summary: "Search and list the caller's wallet." })
  list(
    @CurrentUser() user: AccessPrincipal,
    @Query(new ZodValidationPipe(cardListQuerySchema))
    query: {
      q?: string;
      filter?: "all" | "favourites" | "manual" | "created" | "scanned" | "received";
      cursor?: string;
      limit?: number;
    },
  ) {
    return this.cards.list(user.id, query);
  }

  @Post()
  @HttpCode(201)
  @ApiOperation({ summary: "Create a manual card in the caller's wallet." })
  create(
    @CurrentUser() user: AccessPrincipal,
    @Body(new ZodValidationPipe(createCardRequestSchema)) body: CreateCardRequest,
    @Req() req: RequestWithContext,
    @Headers("idempotency-key") idempotencyKey?: string,
  ) {
    return this.cards.create(user.id, body, req.requestId ?? "unknown", idempotencyKey);
  }

  @Get(":id")
  @ApiOperation({ summary: "Read one card the caller owns." })
  getOne(@CurrentUser() user: AccessPrincipal, @Param("id") id: string) {
    return this.cards.get(user.id, id);
  }

  @Patch(":id")
  @ApiOperation({ summary: "Rename a card the caller owns." })
  patch(
    @CurrentUser() user: AccessPrincipal,
    @Param("id") id: string,
    @Body(new ZodValidationPipe(patchCardRequestSchema)) body: PatchCardRequest,
    @Req() req: RequestWithContext,
  ) {
    return this.cards.patchTitle(user.id, id, body.title, req.requestId ?? "unknown");
  }

  @Post(":id/versions")
  @HttpCode(201)
  @ApiOperation({ summary: "Save a new version of the caller's card." })
  replaceVersion(
    @CurrentUser() user: AccessPrincipal,
    @Param("id") id: string,
    @Body(new ZodValidationPipe(replaceVersionRequestSchema)) body: ReplaceVersionRequest,
    @Req() req: RequestWithContext,
  ) {
    return this.cards.replaceVersion(user.id, id, body, req.requestId ?? "unknown");
  }
}
