import { Inject, Injectable } from "@nestjs/common";
import { Prisma } from "@prisma/client";

import { ApiException } from "../../common/api.exception";
import { PrismaService } from "../../prisma/prisma.service";

@Injectable()
export class IdempotencyService {
  constructor(@Inject(PrismaService) private readonly prisma: PrismaService) {}

  async remember(input: {
    userId: string;
    key: string;
    requestHash: string;
    responseStatus: number;
    responseBody: Prisma.InputJsonValue;
  }) {
    try {
      return await this.prisma.idempotencyKey.create({ data: input });
    } catch (error) {
      if (!(error instanceof Prisma.PrismaClientKnownRequestError) || error.code !== "P2002") {
        throw error;
      }
      const existing = await this.prisma.idempotencyKey.findUnique({
        where: { userId_key: { userId: input.userId, key: input.key } },
      });
      if (!existing || existing.requestHash !== input.requestHash) {
        throw new ApiException(
          409,
          "conflict",
          "Idempotency key was reused with a different request",
        );
      }
      return existing;
    }
  }
}
