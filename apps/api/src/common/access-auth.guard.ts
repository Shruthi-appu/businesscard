import { CanActivate, ExecutionContext, Inject, Injectable } from "@nestjs/common";
import { jwtVerify } from "jose";

import { EnvService } from "../config/env.service";
import { PrismaService } from "../prisma/prisma.service";
import { ApiException } from "./api.exception";
import { headerValue, type RequestWithContext } from "./request-context";

@Injectable()
export class AccessAuthGuard implements CanActivate {
  constructor(
    @Inject(EnvService) private readonly env: EnvService,
    @Inject(PrismaService) private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<RequestWithContext>();
    const header = headerValue(request.headers.authorization);
    if (!header?.startsWith("Bearer ")) {
      throw new ApiException(401, "unauthenticated", "Authentication required");
    }
    const token = header.slice("Bearer ".length).trim();
    if (
      !token ||
      (this.env.values.WORKER_AUTH_TOKEN && token === this.env.values.WORKER_AUTH_TOKEN)
    ) {
      throw new ApiException(401, "unauthenticated", "Authentication required");
    }

    let userId: string;
    try {
      const { payload } = await jwtVerify(token, this.env.accessKey, {
        issuer: this.env.values.JWT_ISSUER,
        audience: "user",
      });
      if (!payload.sub || (payload.role !== "user" && payload.role !== "admin")) {
        throw new ApiException(401, "unauthenticated", "Authentication required");
      }
      userId = payload.sub;
    } catch (error) {
      if (error instanceof ApiException) throw error;
      throw new ApiException(401, "unauthenticated", "Authentication required");
    }

    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new ApiException(401, "unauthenticated", "Authentication required");
    }
    if (user.status !== "active") {
      throw new ApiException(403, "forbidden", "Account is not active");
    }
    request.user = { id: user.id, role: user.role, email: user.email };
    return true;
  }
}
