import { Inject, Injectable } from "@nestjs/common";
import { Prisma } from "@prisma/client";

import { PrismaService } from "../../prisma/prisma.service";

const BLOCKED = /password|token|secret|otp|authorization|cookie/i;

export function sanitizeAuditMetadata(
  input: Record<string, unknown>,
): Record<string, string | number | boolean | null> {
  const output: Record<string, string | number | boolean | null> = {};
  for (const [key, value] of Object.entries(input)) {
    if (BLOCKED.test(key)) continue;
    if (
      typeof value === "string" ||
      typeof value === "number" ||
      typeof value === "boolean" ||
      value === null
    ) {
      output[key] = value;
    }
  }
  return output;
}

@Injectable()
export class AuditService {
  constructor(@Inject(PrismaService) private readonly prisma: PrismaService) {}

  async record(input: {
    actorUserId: string | null;
    action: string;
    resourceType: string;
    resourceId: string | null;
    requestId: string | null;
    metadata: Record<string, unknown>;
  }): Promise<void> {
    const metadata = sanitizeAuditMetadata(input.metadata);
    await this.prisma.auditLog.create({
      data: {
        actorUserId: input.actorUserId,
        action: input.action,
        resourceType: input.resourceType,
        resourceId: input.resourceId,
        requestId: input.requestId,
        metadata: metadata as Prisma.InputJsonValue,
      },
    });
  }
}
