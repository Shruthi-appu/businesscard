import { Body, Controller, Get, HttpCode, Inject, Post, Req, Res } from "@nestjs/common";
import { ApiOkResponse, ApiOperation, ApiTags } from "@nestjs/swagger";
import {
  loginRequestSchema,
  oidcUnavailableCode,
  refreshRequestSchema,
  registerRequestSchema,
  type LoginRequest,
  type RefreshRequest,
  type RegisterRequest,
} from "@softxu/contracts";
import type { Response } from "express";

import { ApiException } from "../../common/api.exception";
import { clientIp, type RequestWithContext } from "../../common/request-context";
import { ZodValidationPipe } from "../../common/zod.pipe";
import { EnvService } from "../../config/env.service";
import { AuthService } from "./auth.service";
import { clearRefreshCookie, readRefreshToken, setRefreshCookie, userAgentOf } from "./cookies";
import { RateLimitService } from "./rate-limit.service";

@ApiTags("auth")
@Controller("auth")
export class AuthController {
  constructor(
    @Inject(AuthService) private readonly auth: AuthService,
    @Inject(EnvService) private readonly env: EnvService,
    @Inject(RateLimitService) private readonly rateLimit: RateLimitService,
  ) {}

  @Post("register")
  @HttpCode(201)
  @ApiOperation({ summary: "Create an account and a session" })
  async register(
    @Body(new ZodValidationPipe(registerRequestSchema)) body: RegisterRequest,
    @Req() req: RequestWithContext,
    @Res({ passthrough: true }) res: Response,
  ) {
    await this.limit("register", req);
    const session = await this.auth.register(body, this.context(req));
    setRefreshCookie(res, session.refreshToken, this.env.values);
    return session;
  }

  @Post("login")
  @HttpCode(200)
  @ApiOperation({ summary: "Sign in with email and password" })
  async login(
    @Body(new ZodValidationPipe(loginRequestSchema)) body: LoginRequest,
    @Req() req: RequestWithContext,
    @Res({ passthrough: true }) res: Response,
  ) {
    await this.limit("login", req);
    const session = await this.auth.login(body, this.context(req));
    setRefreshCookie(res, session.refreshToken, this.env.values);
    return session;
  }

  @Post("refresh")
  @HttpCode(200)
  @ApiOperation({ summary: "Rotate the refresh token and issue a new access token" })
  @ApiOkResponse({ description: "New session. Web clients may omit the body and send the cookie." })
  async refresh(
    @Body(new ZodValidationPipe(refreshRequestSchema)) body: RefreshRequest,
    @Req() req: RequestWithContext,
    @Res({ passthrough: true }) res: Response,
  ) {
    const session = await this.auth.refresh(
      readRefreshToken(req, body.refreshToken),
      this.context(req),
    );
    setRefreshCookie(res, session.refreshToken, this.env.values);
    return session;
  }

  @Post("logout")
  @HttpCode(204)
  @ApiOperation({ summary: "Revoke the presented refresh token" })
  async logout(
    @Body(new ZodValidationPipe(refreshRequestSchema)) body: RefreshRequest,
    @Req() req: RequestWithContext,
    @Res() res: Response,
  ): Promise<void> {
    await this.auth.logout(readRefreshToken(req, body.refreshToken), this.context(req));
    clearRefreshCookie(res, this.env.values);
    res.status(204).end();
  }

  @Get("oidc/start")
  @ApiOperation({ summary: "Start OIDC sign-in. Unavailable until a provider is configured." })
  oidcStart(): never {
    return this.oidcUnavailable();
  }

  @Get("oidc/callback")
  @ApiOperation({ summary: "OIDC callback. Unavailable until a provider is configured." })
  oidcCallback(): never {
    return this.oidcUnavailable();
  }

  private oidcUnavailable(): never {
    const code = oidcUnavailableCode(this.env.values.oidcConfigured);
    const title =
      code === "identity_provider_unconfigured"
        ? "Identity provider is not configured"
        : "OIDC sign-in is not available yet";
    throw new ApiException(501, code, title);
  }

  private context(req: RequestWithContext) {
    return { requestId: req.requestId ?? "unknown", userAgent: userAgentOf(req) };
  }

  private limit(action: "register" | "login", req: RequestWithContext): Promise<void> {
    return this.rateLimit.consume(
      `${action}:${clientIp(req)}`,
      this.env.values.RATE_LIMIT_AUTH_MAX,
      this.env.values.RATE_LIMIT_AUTH_WINDOW_SECONDS,
    );
  }
}
