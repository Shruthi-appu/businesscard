import { Inject, Injectable } from "@nestjs/common";
import type { MeResponse } from "@softxu/contracts";

import { ApiException } from "../../common/api.exception";
import { PrismaService } from "../../prisma/prisma.service";

@Injectable()
export class MeService {
  constructor(@Inject(PrismaService) private readonly prisma: PrismaService) {}

  async get(userId: string): Promise<MeResponse> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { profile: true },
    });
    if (!user) {
      throw new ApiException(401, "unauthenticated", "Authentication required");
    }
    return {
      id: user.id,
      email: user.email,
      phoneE164: user.phoneE164,
      displayName: user.profile?.displayName ?? "Member",
      locale: user.profile?.locale ?? null,
      countryCode: user.profile?.countryCode ?? null,
      role: user.role,
      status: user.status,
    };
  }
}
