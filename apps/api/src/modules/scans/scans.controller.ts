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
  Res,
  UseGuards,
} from "@nestjs/common";
import { ApiBearerAuth, ApiOperation, ApiTags } from "@nestjs/swagger";
import { contactInputSchema } from "@softxu/contracts";
import type { Response } from "express";
import { z } from "zod";

import { AccessAuthGuard } from "../../common/access-auth.guard";
import { CurrentUser } from "../../common/current-user";
import type { AccessPrincipal, RequestWithContext } from "../../common/request-context";
import { ZodValidationPipe } from "../../common/zod.pipe";
import { ScansService } from "./scans.service";

const uploadSchema = z.object({
  side: z.enum(["front", "back"]),
  mimeType: z.enum(["image/jpeg", "image/png"]),
  byteSize: z
    .number()
    .int()
    .positive()
    .max(20 * 1024 * 1024),
  checksumSha256: z.string().regex(/^[a-f0-9]{64}$/),
});
const bytesSchema = z.object({ bodyBase64: z.string().min(1) });
const completeSchema = z.object({
  assetId: z.uuid(),
  side: z.enum(["front", "back"]),
});
const confirmSchema = z.object({
  version: z.number().int().positive(),
  contacts: z.array(contactInputSchema).min(1).max(30),
});

@ApiTags("scans")
@ApiBearerAuth()
@UseGuards(AccessAuthGuard)
@Controller("scans")
export class ScansController {
  constructor(@Inject(ScansService) private readonly scans: ScansService) {}

  @Post()
  @HttpCode(201)
  @ApiOperation({ summary: "Start a scanned card and an OCR job." })
  create(
    @CurrentUser() user: AccessPrincipal,
    @Req() req: RequestWithContext,
    @Headers("idempotency-key") idempotencyKey?: string,
  ) {
    return this.scans.create(user.id, req.requestId ?? "unknown", idempotencyKey);
  }

  @Post(":id/upload-url")
  @ApiOperation({ summary: "Create a pending original and a five-minute upload URL." })
  uploadUrl(
    @CurrentUser() user: AccessPrincipal,
    @Param("id") id: string,
    @Body(new ZodValidationPipe(uploadSchema)) body: z.infer<typeof uploadSchema>,
  ) {
    return this.scans.uploadUrl(user.id, id, body);
  }

  @Post(":id/objects/:assetId")
  @ApiOperation({ summary: "Store bytes when storage is the in-memory adapter." })
  storeBytes(
    @CurrentUser() user: AccessPrincipal,
    @Param("id") id: string,
    @Param("assetId") assetId: string,
    @Body(new ZodValidationPipe(bytesSchema)) body: z.infer<typeof bytesSchema>,
  ) {
    return this.scans.storeBytes(user.id, id, assetId, body.bodyBase64);
  }

  @Post(":id/complete")
  @ApiOperation({ summary: "Verify the original checksum and continue the scan." })
  complete(
    @CurrentUser() user: AccessPrincipal,
    @Param("id") id: string,
    @Body(new ZodValidationPipe(completeSchema)) body: z.infer<typeof completeSchema>,
  ) {
    return this.scans.complete(user.id, id, body.assetId, body.side);
  }

  @Get(":id")
  @ApiOperation({ summary: "Scan status. Poll with Retry-After while the job is running." })
  async getOne(
    @CurrentUser() user: AccessPrincipal,
    @Param("id") id: string,
    @Res({ passthrough: true }) res: Response,
  ) {
    const body = await this.scans.view(user.id, id);
    if (body.retryAfterSeconds) res.setHeader("Retry-After", String(body.retryAfterSeconds));
    return body;
  }

  @Post(":id/retry")
  @ApiOperation({ summary: "Retry a failed scan. A dead-lettered scan stays failed." })
  retry(@CurrentUser() user: AccessPrincipal, @Param("id") id: string) {
    return this.scans.retry(user.id, id);
  }

  @Post(":id/confirm")
  @HttpCode(201)
  @ApiOperation({ summary: "Save the corrected draft as the card's first version." })
  confirm(
    @CurrentUser() user: AccessPrincipal,
    @Param("id") id: string,
    @Body(new ZodValidationPipe(confirmSchema)) body: z.infer<typeof confirmSchema>,
    @Req() req: RequestWithContext,
  ) {
    return this.scans.confirm(user.id, id, body, req.requestId ?? "unknown");
  }
}
