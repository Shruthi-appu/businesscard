import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  Inject,
  Param,
  Post,
  Req,
  StreamableFile,
  UseGuards,
} from "@nestjs/common";
import { ApiBearerAuth, ApiOperation, ApiTags } from "@nestjs/swagger";
import {
  claimShareRequestSchema,
  createShareRequestSchema,
  type ClaimShareRequest,
  type CreateShareRequest,
} from "@softxu/contracts";

import { AccessAuthGuard } from "../../common/access-auth.guard";
import { CurrentUser } from "../../common/current-user";
import type { AccessPrincipal, RequestWithContext } from "../../common/request-context";
import { ZodValidationPipe } from "../../common/zod.pipe";
import { SharesService } from "./shares.service";

@ApiTags("shares")
@Controller()
export class SharesController {
  constructor(@Inject(SharesService) private readonly shares: SharesService) {}

  @Post("cards/:id/shares")
  @HttpCode(201)
  @UseGuards(AccessAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: "Create a scoped share link for one card version." })
  create(
    @CurrentUser() user: AccessPrincipal,
    @Param("id") id: string,
    @Body(new ZodValidationPipe(createShareRequestSchema)) body: CreateShareRequest,
    @Req() req: RequestWithContext,
    @Headers("idempotency-key") idempotencyKey?: string,
  ) {
    return this.shares.create(user.id, id, body, req.requestId ?? "unknown", idempotencyKey);
  }

  @Get("cards/:id/shares")
  @UseGuards(AccessAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: "List share links for a card the caller owns." })
  list(@CurrentUser() user: AccessPrincipal, @Param("id") id: string) {
    return this.shares.list(user.id, id);
  }

  @Post("shares/:id/revoke")
  @HttpCode(200)
  @UseGuards(AccessAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: "Revoke a share link." })
  revoke(
    @CurrentUser() user: AccessPrincipal,
    @Param("id") id: string,
    @Req() req: RequestWithContext,
  ) {
    return this.shares.revoke(user.id, id, req.requestId ?? "unknown");
  }

  @Get("public/shares/:token/vcard")
  @ApiOperation({ summary: "Download a vCard of the fields included in a share." })
  async vcard(
    @Param("token") token: string,
    @Headers("x-share-pin") pin?: string,
  ): Promise<StreamableFile> {
    const file = await this.shares.vcard(token, pin);
    return new StreamableFile(file.body, {
      type: "text/vcard; charset=utf-8",
      disposition: `attachment; filename="${file.filename}"`,
    });
  }

  @Get("public/shares/:token")
  @ApiOperation({ summary: "Preview the fields included in a share link." })
  preview(@Param("token") token: string, @Headers("x-share-pin") pin?: string) {
    return this.shares.preview(token, pin);
  }

  @Post("public/shares/:token/claim")
  @HttpCode(201)
  @UseGuards(AccessAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: "Save the shared fields into the caller's wallet after consent." })
  claim(
    @CurrentUser() user: AccessPrincipal,
    @Param("token") token: string,
    @Body(new ZodValidationPipe(claimShareRequestSchema)) body: ClaimShareRequest,
    @Req() req: RequestWithContext,
  ) {
    return this.shares.claim(user.id, token, body, req.requestId ?? "unknown");
  }
}
