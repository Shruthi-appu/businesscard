import {
  Body,
  Controller,
  Get,
  HttpCode,
  Inject,
  Param,
  Patch,
  Post,
  Req,
  StreamableFile,
  UseGuards,
} from "@nestjs/common";
import { ApiBearerAuth, ApiOperation, ApiTags } from "@nestjs/swagger";
import {
  createDigitalCardRequestSchema,
  designPatchRequestSchema,
  exportCardRequestSchema,
  publishCardRequestSchema,
  type CreateDigitalCardRequest,
  type DesignPatchRequest,
  type ExportCardRequest,
  type PublishCardRequest,
} from "@softxu/contracts";
import { AccessAuthGuard } from "../../common/access-auth.guard";
import { CurrentUser } from "../../common/current-user";
import type { AccessPrincipal, RequestWithContext } from "../../common/request-context";
import { ZodValidationPipe } from "../../common/zod.pipe";
import { DigitalCardsService } from "./digital-cards.service";

@ApiTags("digital-cards")
@Controller()
export class DigitalCardsController {
  constructor(@Inject(DigitalCardsService) private readonly cards: DigitalCardsService) {}

  @Get("templates")
  @ApiOperation({ summary: "List versioned card templates." })
  templates() {
    return this.cards.templates();
  }

  @Post("digital-cards")
  @HttpCode(201)
  @ApiBearerAuth()
  @UseGuards(AccessAuthGuard)
  @ApiOperation({ summary: "Create a digital card from a template." })
  create(
    @CurrentUser() user: AccessPrincipal,
    @Body(new ZodValidationPipe(createDigitalCardRequestSchema)) body: CreateDigitalCardRequest,
    @Req() req: RequestWithContext,
  ) {
    return this.cards.create(user.id, body, req.requestId ?? "unknown");
  }

  @Get("digital-cards/:id")
  @ApiBearerAuth()
  @UseGuards(AccessAuthGuard)
  @ApiOperation({ summary: "Read a digital card the caller owns, including private fields." })
  getOne(@CurrentUser() user: AccessPrincipal, @Param("id") id: string) {
    return this.cards.getOwned(user.id, id);
  }

  @Patch("digital-cards/:id/design")
  @ApiBearerAuth()
  @UseGuards(AccessAuthGuard)
  @ApiOperation({ summary: "Update colours, type scale, images, and front or back copy." })
  patchDesign(
    @CurrentUser() user: AccessPrincipal,
    @Param("id") id: string,
    @Body(new ZodValidationPipe(designPatchRequestSchema)) body: DesignPatchRequest,
    @Req() req: RequestWithContext,
  ) {
    return this.cards.patchDesign(user.id, id, body, req.requestId ?? "unknown");
  }

  @Post("digital-cards/:id/publish")
  @ApiBearerAuth()
  @UseGuards(AccessAuthGuard)
  @ApiOperation({ summary: "Set the public slug and visibility." })
  publish(
    @CurrentUser() user: AccessPrincipal,
    @Param("id") id: string,
    @Body(new ZodValidationPipe(publishCardRequestSchema)) body: PublishCardRequest,
    @Req() req: RequestWithContext,
  ) {
    return this.cards.publish(user.id, id, body, req.requestId ?? "unknown");
  }

  @Post("digital-cards/:id/export")
  @ApiBearerAuth()
  @UseGuards(AccessAuthGuard)
  @ApiOperation({
    summary: "Export a published card as QR, PNG, PDF, or vCard. Public fields only.",
  })
  async export(
    @CurrentUser() user: AccessPrincipal,
    @Param("id") id: string,
    @Body(new ZodValidationPipe(exportCardRequestSchema)) body: ExportCardRequest,
    @Req() req: RequestWithContext,
  ): Promise<StreamableFile> {
    const file = await this.cards.export(user.id, id, body.format, req.requestId ?? "unknown");
    return new StreamableFile(file.body, {
      type: file.contentType,
      disposition: `attachment; filename="${file.filename}"`,
    });
  }
}
