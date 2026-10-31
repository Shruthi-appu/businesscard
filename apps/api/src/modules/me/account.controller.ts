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
import { deleteAccountRequestSchema, type DeleteAccountRequest } from "@softxu/contracts";

import { ApiException } from "../../common/api.exception";
import { AccessAuthGuard } from "../../common/access-auth.guard";
import { CurrentUser } from "../../common/current-user";
import type { AccessPrincipal, RequestWithContext } from "../../common/request-context";
import { ZodValidationPipe } from "../../common/zod.pipe";
import { AccountService } from "./account.service";

@ApiTags("me")
@ApiBearerAuth()
@UseGuards(AccessAuthGuard)
@Controller()
export class AccountController {
  constructor(@Inject(AccountService) private readonly account: AccountService) {}

  @Post("me/export")
  @HttpCode(200)
  @ApiOperation({
    summary: "Build a JSON export of the signed-in account and return when it is ready.",
  })
  exportAccount(
    @CurrentUser() user: AccessPrincipal,
    @Req() req: RequestWithContext,
    @Headers("idempotency-key") idempotencyKey?: string,
  ) {
    return this.account.export(user.id, req.requestId ?? "unknown", idempotencyKey);
  }

  @Get("me/exports/:id")
  @ApiOperation({ summary: "Export status for the signed-in account. No file bytes." })
  exportStatus(@CurrentUser() user: AccessPrincipal, @Param("id") id: string) {
    return this.account.metadata(user.id, id);
  }

  @Get("me/exports/:id/file")
  @ApiOperation({ summary: "Download the signed-in account's export JSON." })
  async exportFile(@CurrentUser() user: AccessPrincipal, @Param("id") id: string) {
    const body = await this.account.file(user.id, id);
    return new StreamableFile(body, {
      type: "application/json",
      disposition: 'attachment; filename="softxu-export.json"',
    });
  }

  @Post("me/delete")
  @HttpCode(200)
  @ApiOperation({
    summary:
      "Schedule account deletion. Sign-in stops immediately. The record is scrubbed after the grace period.",
  })
  deleteAccount(
    @CurrentUser() user: AccessPrincipal,
    @Body(new ZodValidationPipe(deleteAccountRequestSchema)) _body: DeleteAccountRequest,
    @Req() req: RequestWithContext,
    @Headers("idempotency-key") idempotencyKey?: string,
  ) {
    return this.account.scheduleDeletion(user.id, req.requestId ?? "unknown", idempotencyKey);
  }
}

@ApiTags("admin")
@ApiBearerAuth()
@UseGuards(AccessAuthGuard)
@Controller()
export class AdminJobsController {
  constructor(@Inject(AccountService) private readonly account: AccountService) {}

  @Get("admin/jobs")
  @ApiOperation({ summary: "Job status counts for an admin. No card payloads." })
  jobs(@CurrentUser() user: AccessPrincipal) {
    if (user.role !== "admin") {
      throw new ApiException(403, "forbidden", "You do not have access to admin tools.");
    }
    return this.account.jobCounts();
  }
}
