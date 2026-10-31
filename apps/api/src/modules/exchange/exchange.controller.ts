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
  UseGuards,
} from "@nestjs/common";
import { ApiBearerAuth, ApiOperation, ApiTags } from "@nestjs/swagger";
import {
  consentExchangeRequestSchema,
  createExchangeRequestSchema,
  joinExchangeRequestSchema,
  type ConsentExchangeRequest,
  type CreateExchangeRequest,
  type JoinExchangeRequest,
} from "@softxu/contracts";

import { AccessAuthGuard } from "../../common/access-auth.guard";
import { CurrentUser } from "../../common/current-user";
import type { AccessPrincipal, RequestWithContext } from "../../common/request-context";
import { ZodValidationPipe } from "../../common/zod.pipe";
import { ExchangeService } from "./exchange.service";

@ApiTags("exchange")
@ApiBearerAuth()
@UseGuards(AccessAuthGuard)
@Controller("exchange-sessions")
export class ExchangeController {
  constructor(@Inject(ExchangeService) private readonly exchange: ExchangeService) {}

  @Post()
  @HttpCode(201)
  @ApiOperation({ summary: "Open a QR or link exchange. BLE and NFC are not available." })
  create(
    @CurrentUser() user: AccessPrincipal,
    @Body(new ZodValidationPipe(createExchangeRequestSchema)) body: CreateExchangeRequest,
    @Req() req: RequestWithContext,
    @Headers("idempotency-key") idempotencyKey?: string,
  ) {
    return this.exchange.create(user.id, body, req.requestId ?? "unknown", idempotencyKey);
  }

  @Get(":id")
  @ApiOperation({ summary: "Read an exchange the caller has joined." })
  getOne(@CurrentUser() user: AccessPrincipal, @Param("id") id: string) {
    return this.exchange.get(user.id, id);
  }

  @Post(":id/join")
  @HttpCode(200)
  @ApiOperation({ summary: "Join an exchange with its one-time code." })
  join(
    @CurrentUser() user: AccessPrincipal,
    @Param("id") id: string,
    @Body(new ZodValidationPipe(joinExchangeRequestSchema)) body: JoinExchangeRequest,
  ) {
    return this.exchange.join(user.id, id, body);
  }

  @Post(":id/consent")
  @HttpCode(200)
  @ApiOperation({ summary: "Accept or decline an exchange." })
  consent(
    @CurrentUser() user: AccessPrincipal,
    @Param("id") id: string,
    @Body(new ZodValidationPipe(consentExchangeRequestSchema)) body: ConsentExchangeRequest,
  ) {
    return this.exchange.consent(user.id, id, body);
  }

  @Post(":id/complete")
  @HttpCode(200)
  @ApiOperation({ summary: "Save the offered cards after the required consents." })
  complete(
    @CurrentUser() user: AccessPrincipal,
    @Param("id") id: string,
    @Req() req: RequestWithContext,
    @Headers("idempotency-key") idempotencyKey?: string,
  ) {
    return this.exchange.complete(user.id, id, req.requestId ?? "unknown", idempotencyKey);
  }
}
