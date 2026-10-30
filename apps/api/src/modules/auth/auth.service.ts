import { Inject, Injectable } from "@nestjs/common";
import { Prisma } from "@prisma/client";
import type { AuthResponse, LoginRequest, RegisterRequest } from "@softxu/contracts";

import { ApiException } from "../../common/api.exception";
import { EnvService } from "../../config/env.service";
import { PrismaService } from "../../prisma/prisma.service";
import { AuditService } from "../audit/audit.service";
import { hashPassword, newPlaceholderSecret, verifyPassword } from "./password";
import { hashRefreshToken, hashUserAgent, newRefreshToken, signAccessToken } from "./tokens";

type UserWithProfile = Prisma.UserGetPayload<{ include: { profile: true } }>;

type RequestContext = {
  requestId: string;
  userAgent?: string;
};

@Injectable()
export class AuthService {
  private placeholderHash: Promise<string> | null = null;

  constructor(
    @Inject(PrismaService) private readonly prisma: PrismaService,
    @Inject(EnvService) private readonly env: EnvService,
    @Inject(AuditService) private readonly audit: AuditService,
  ) {}

  async register(input: RegisterRequest, context: RequestContext): Promise<AuthResponse> {
    const passwordHash = await hashPassword(input.password);
    let user: UserWithProfile;
    try {
      user = await this.prisma.user.create({
        data: {
          email: input.email,
          passwordHash,
          profile: { create: { displayName: input.displayName } },
        },
        include: { profile: true },
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002") {
        throw new ApiException(409, "conflict", "An account with that email already exists");
      }
      throw error;
    }
    const session = await this.issue(user, context);
    await this.audit.record({
      actorUserId: user.id,
      action: "auth.register",
      resourceType: "user",
      resourceId: user.id,
      requestId: context.requestId,
      metadata: { method: "password", result: "success" },
    });
    return session;
  }

  async login(input: LoginRequest, context: RequestContext): Promise<AuthResponse> {
    const user = await this.prisma.user.findUnique({
      where: { email: input.email },
      include: { profile: true },
    });
    const hash = user?.passwordHash ?? (await this.placeholder());
    const matches = await verifyPassword(input.password, hash);
    if (!user || !user.passwordHash || !matches) {
      await this.audit.record({
        actorUserId: user?.id ?? null,
        action: "auth.login_failed",
        resourceType: "user",
        resourceId: user?.id ?? null,
        requestId: context.requestId,
        metadata: { method: "password", result: "denied" },
      });
      throw new ApiException(401, "unauthenticated", "Invalid email or password");
    }
    if (user.status !== "active") {
      throw new ApiException(403, "forbidden", "Account is not active");
    }
    const session = await this.issue(user, context);
    await this.audit.record({
      actorUserId: user.id,
      action: "auth.login",
      resourceType: "user",
      resourceId: user.id,
      requestId: context.requestId,
      metadata: { method: "password", result: "success" },
    });
    return session;
  }

  async refresh(rawToken: string, context: RequestContext): Promise<AuthResponse> {
    if (!rawToken) {
      throw new ApiException(401, "unauthenticated", "Authentication required");
    }
    const tokenHash = hashRefreshToken(rawToken, this.env.values.JWT_REFRESH_SECRET);
    const existing = await this.prisma.refreshToken.findUnique({
      where: { tokenHash },
      include: { user: { include: { profile: true } } },
    });
    if (!existing) {
      throw new ApiException(401, "unauthenticated", "Authentication required");
    }
    if (existing.revokedAt) {
      await this.prisma.refreshToken.updateMany({
        where: { userId: existing.userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
      await this.audit.record({
        actorUserId: existing.userId,
        action: "auth.refresh_reuse",
        resourceType: "refresh_token",
        resourceId: existing.id,
        requestId: context.requestId,
        metadata: { result: "denied" },
      });
      throw new ApiException(401, "unauthenticated", "Authentication required");
    }
    if (existing.expiresAt.getTime() <= Date.now()) {
      throw new ApiException(401, "expired", "Session expired");
    }
    if (existing.user.status !== "active") {
      throw new ApiException(403, "forbidden", "Account is not active");
    }
    const session = await this.issue(existing.user, context, existing.id);
    await this.audit.record({
      actorUserId: existing.userId,
      action: "auth.refresh",
      resourceType: "refresh_token",
      resourceId: existing.id,
      requestId: context.requestId,
      metadata: { result: "success" },
    });
    return session;
  }

  async logout(rawToken: string, context: RequestContext): Promise<void> {
    if (!rawToken) return;
    const tokenHash = hashRefreshToken(rawToken, this.env.values.JWT_REFRESH_SECRET);
    const existing = await this.prisma.refreshToken.findUnique({ where: { tokenHash } });
    if (!existing || existing.revokedAt) return;
    await this.prisma.refreshToken.update({
      where: { id: existing.id },
      data: { revokedAt: new Date() },
    });
    await this.audit.record({
      actorUserId: existing.userId,
      action: "auth.logout",
      resourceType: "refresh_token",
      resourceId: existing.id,
      requestId: context.requestId,
      metadata: { result: "success" },
    });
  }

  private async issue(
    user: UserWithProfile,
    context: RequestContext,
    replaceId?: string,
  ): Promise<AuthResponse> {
    const refreshToken = newRefreshToken();
    const tokenHash = hashRefreshToken(refreshToken, this.env.values.JWT_REFRESH_SECRET);
    const expiresAt = new Date(Date.now() + this.env.values.REFRESH_TOKEN_TTL_SECONDS * 1000);
    await this.prisma.$transaction(async (tx) => {
      const created = await tx.refreshToken.create({
        data: {
          userId: user.id,
          tokenHash,
          expiresAt,
          userAgentHash: context.userAgent ? hashUserAgent(context.userAgent) : null,
        },
      });
      if (replaceId) {
        await tx.refreshToken.update({
          where: { id: replaceId },
          data: { revokedAt: new Date(), replacedById: created.id },
        });
      }
    });
    const accessToken = await signAccessToken({
      userId: user.id,
      email: user.email,
      role: user.role,
      issuer: this.env.values.JWT_ISSUER,
      secret: this.env.accessKey,
      ttlSeconds: this.env.values.ACCESS_TOKEN_TTL_SECONDS,
    });
    return {
      tokenType: "Bearer",
      accessToken,
      expiresIn: this.env.values.ACCESS_TOKEN_TTL_SECONDS,
      refreshToken,
      user: {
        id: user.id,
        email: user.email,
        displayName: user.profile?.displayName ?? "Member",
        role: user.role,
      },
    };
  }

  private placeholder(): Promise<string> {
    this.placeholderHash ??= hashPassword(newPlaceholderSecret());
    return this.placeholderHash;
  }
}
