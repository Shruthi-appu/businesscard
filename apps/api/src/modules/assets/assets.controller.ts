import { Body, Controller, Get, HttpCode, Inject, Param, Post, UseGuards } from "@nestjs/common";
import { ApiBearerAuth, ApiOperation, ApiTags } from "@nestjs/swagger";
import { z } from "zod";

import { AccessAuthGuard } from "../../common/access-auth.guard";
import { CurrentUser } from "../../common/current-user";
import type { AccessPrincipal } from "../../common/request-context";
import { ZodValidationPipe } from "../../common/zod.pipe";
import { AssetsService } from "./assets.service";

const presignSchema = z.object({
  purpose: z.enum(["logo", "avatar"]),
  mimeType: z.enum(["image/jpeg", "image/png"]),
  byteSize: z
    .number()
    .int()
    .positive()
    .max(20 * 1024 * 1024),
  checksumSha256: z.string().regex(/^[a-f0-9]{64}$/),
});
const bytesSchema = z.object({ bodyBase64: z.string().min(1) });

@ApiTags("assets")
@ApiBearerAuth()
@UseGuards(AccessAuthGuard)
@Controller("assets")
export class AssetsController {
  constructor(@Inject(AssetsService) private readonly assets: AssetsService) {}

  @Post("presign")
  @ApiOperation({ summary: "Start a logo or avatar upload." })
  presign(
    @CurrentUser() user: AccessPrincipal,
    @Body(new ZodValidationPipe(presignSchema)) body: z.infer<typeof presignSchema>,
  ) {
    return this.assets.presign(user.id, body);
  }

  @Post(":id/bytes")
  @HttpCode(200)
  @ApiOperation({ summary: "Store logo or avatar bytes when storage is in memory." })
  storeBytes(
    @CurrentUser() user: AccessPrincipal,
    @Param("id") id: string,
    @Body(new ZodValidationPipe(bytesSchema)) body: z.infer<typeof bytesSchema>,
  ) {
    return this.assets.storeBytes(user.id, id, body.bodyBase64);
  }

  @Post(":id/complete")
  @ApiOperation({ summary: "Verify the logo or avatar checksum." })
  complete(@CurrentUser() user: AccessPrincipal, @Param("id") id: string) {
    return this.assets.complete(user.id, id);
  }

  @Get(":id/url")
  @ApiOperation({ summary: "Return a 60-second download URL for the caller's asset." })
  url(@CurrentUser() user: AccessPrincipal, @Param("id") id: string) {
    return this.assets.url(user.id, id);
  }
}
