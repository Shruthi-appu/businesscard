import { createHash } from "crypto";

import { Inject, Injectable, Logger } from "@nestjs/common";

import { ApiException } from "../../common/api.exception";
import { EnvService } from "../../config/env.service";
import { PrismaService } from "../../prisma/prisma.service";
import type { JobQueue } from "../../queue/job-queue";
import { JOB_QUEUE } from "../../queue/job-queue";
import type { ObjectStorage } from "../../storage/object-storage";
import { OBJECT_STORAGE } from "../../storage/object-storage";
import { AuditService } from "../audit/audit.service";
import { RateLimitService } from "../auth/rate-limit.service";
import { IdempotencyService } from "../idempotency/idempotency.service";

const accountUnavailable = "Account actions are temporarily unavailable";

type ExportBody = {
  id: string;
  status: "ready";
};

type DeleteBody = {
  status: "pending_deletion";
  deletionScheduledAt: string;
  graceSeconds: number;
};

@Injectable()
export class AccountService {
  private readonly logger = new Logger(AccountService.name);

  constructor(
    @Inject(PrismaService) private readonly prisma: PrismaService,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorage,
    @Inject(JOB_QUEUE) private readonly queue: JobQueue,
    @Inject(AuditService) private readonly audit: AuditService,
    @Inject(IdempotencyService) private readonly idempotency: IdempotencyService,
    @Inject(RateLimitService) private readonly rateLimit: RateLimitService,
    @Inject(EnvService) private readonly env: EnvService,
  ) {}

  async export(userId: string, requestId: string, idempotencyKey?: string): Promise<ExportBody> {
    await this.rateLimit.consume(
      `account:export:${userId}`,
      this.env.values.RATE_LIMIT_PRESIGN_MAX,
      this.env.values.RATE_LIMIT_PRESIGN_WINDOW_SECONDS,
      accountUnavailable,
    );
    const requestHash = hashBody({ action: "account_export" });
    if (idempotencyKey) {
      const prior = await this.replay<ExportBody>(userId, idempotencyKey, requestHash);
      if (prior) return prior;
    }
    const row = await this.prisma.dataExport.create({
      data: { userId, status: "queued" },
    });
    await this.queue.send("export", { kind: "account_export", exportId: row.id });
    const payload = await this.payload(userId);
    const bytes = Buffer.from(JSON.stringify(payload));
    const key = `exports/${userId}/${row.id}.json`;
    try {
      await this.storage.putObject({ key, body: bytes, contentType: "application/json" });
    } catch {
      await this.prisma.dataExport.update({
        where: { id: row.id },
        data: { status: "failed", errorCode: "storage_unavailable" },
      });
      throw new ApiException(503, "service_unavailable", "Export is temporarily unavailable");
    }
    await this.prisma.dataExport.update({
      where: { id: row.id },
      data: {
        status: "ready",
        storageKey: key,
        byteSize: bytes.byteLength,
        readyAt: new Date(),
      },
    });
    await this.audit.record({
      actorUserId: userId,
      action: "account.export",
      resourceType: "data_export",
      resourceId: row.id,
      requestId,
      metadata: { byteSize: bytes.byteLength },
    });
    const body: ExportBody = { id: row.id, status: "ready" };
    if (idempotencyKey) {
      await this.idempotency.remember({
        userId,
        key: idempotencyKey,
        requestHash,
        responseStatus: 200,
        responseBody: body,
      });
    }
    return body;
  }

  async metadata(userId: string, exportId: string) {
    const row = await this.owned(userId, exportId);
    return {
      id: row.id,
      status: row.status,
      byteSize: row.byteSize,
      readyAt: row.readyAt ? row.readyAt.toISOString() : null,
    };
  }

  async file(userId: string, exportId: string): Promise<Buffer> {
    const row = await this.owned(userId, exportId);
    if (row.status !== "ready" || !row.storageKey) {
      throw new ApiException(409, "conflict", "This export is not ready");
    }
    const body = await this.storage.getObject(row.storageKey);
    if (!body) throw new ApiException(404, "not_found", "Export file was not found");
    return body;
  }

  async scheduleDeletion(
    userId: string,
    requestId: string,
    idempotencyKey?: string,
  ): Promise<DeleteBody> {
    await this.rateLimit.consume(
      `account:delete:${userId}`,
      this.env.values.RATE_LIMIT_PRESIGN_MAX,
      this.env.values.RATE_LIMIT_PRESIGN_WINDOW_SECONDS,
      accountUnavailable,
    );
    const requestHash = hashBody({ action: "account_delete", confirm: true });
    if (idempotencyKey) {
      const prior = await this.replay<DeleteBody>(userId, idempotencyKey, requestHash);
      if (prior) return prior;
    }
    const graceSeconds = this.env.values.ACCOUNT_DELETION_GRACE_SECONDS;
    const deletionScheduledAt = new Date(Date.now() + graceSeconds * 1000);
    const revokedAt = new Date();
    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: userId },
        data: { status: "pending_deletion", deletionScheduledAt },
      }),
      this.prisma.refreshToken.updateMany({
        where: { userId, revokedAt: null },
        data: { revokedAt },
      }),
    ]);
    await this.audit.record({
      actorUserId: userId,
      action: "account.delete.schedule",
      resourceType: "user",
      resourceId: userId,
      requestId,
      metadata: { graceSeconds },
    });
    const body: DeleteBody = {
      status: "pending_deletion",
      deletionScheduledAt: deletionScheduledAt.toISOString(),
      graceSeconds,
    };
    if (idempotencyKey) {
      await this.idempotency.remember({
        userId,
        key: idempotencyKey,
        requestHash,
        responseStatus: 200,
        responseBody: body,
      });
    }
    return body;
  }

  async jobCounts() {
    const purged = await this.purgeDue();
    const [ocrRows, exportRows, pendingDeletion] = await Promise.all([
      this.prisma.ocrJob.groupBy({ by: ["status"], _count: { _all: true } }),
      this.prisma.dataExport.groupBy({ by: ["status"], _count: { _all: true } }),
      this.prisma.user.count({ where: { status: "pending_deletion", purgedAt: null } }),
    ]);
    return {
      ocr: countMap(ocrRows),
      exports: countMap(exportRows),
      pendingDeletion,
      purged,
    };
  }

  async purgeDue(): Promise<number> {
    const due = await this.prisma.user.findMany({
      where: {
        status: "pending_deletion",
        purgedAt: null,
        deletionScheduledAt: { lte: new Date() },
      },
      select: { id: true },
    });
    let purged = 0;
    for (const user of due) {
      try {
        await this.purgeOne(user.id);
        purged += 1;
      } catch {
        this.logger.error(`account purge failed userId=${user.id}`);
      }
    }
    return purged;
  }

  private async purgeOne(userId: string): Promise<void> {
    const now = new Date();
    await this.prisma.$transaction(async (tx) => {
      await tx.cardShare.updateMany({
        where: { senderUserId: userId, revokedAt: null },
        data: { revokedAt: now, pinHash: null, recipientPhoneHash: null },
      });
      await tx.walletEntry.deleteMany({ where: { userId } });
      await tx.cardSnapshot.deleteMany({ where: { ownerUserId: userId } });
      const versions = await tx.cardVersion.findMany({
        where: { card: { ownerUserId: userId } },
        select: { id: true },
      });
      const versionIds = versions.map((version) => version.id);
      if (versionIds.length > 0) {
        await tx.cardContact.deleteMany({ where: { cardVersionId: { in: versionIds } } });
        await tx.cardAddress.deleteMany({ where: { cardVersionId: { in: versionIds } } });
        await tx.cardSocialLink.deleteMany({ where: { cardVersionId: { in: versionIds } } });
      }
      const jobs = await tx.ocrJob.findMany({
        where: { ownerUserId: userId },
        select: { id: true },
      });
      const jobIds = jobs.map((job) => job.id);
      if (jobIds.length > 0) {
        await tx.ocrResult.deleteMany({ where: { ocrJobId: { in: jobIds } } });
      }
      await tx.idempotencyKey.deleteMany({ where: { userId } });
      await tx.dataExport.deleteMany({ where: { userId } });
      await tx.businessCard.updateMany({
        where: { ownerUserId: userId },
        data: {
          title: "Deleted card",
          publicSlug: null,
          visibility: "private",
          status: "archived",
        },
      });
      await tx.userProfile.updateMany({
        where: { userId },
        data: { displayName: "Deleted account" },
      });
      await tx.refreshToken.updateMany({
        where: { userId, revokedAt: null },
        data: { revokedAt: now },
      });
      await tx.user.update({
        where: { id: userId },
        data: {
          email: null,
          phoneE164: null,
          passwordHash: null,
          identityProvider: null,
          identitySubject: null,
          status: "disabled",
          purgedAt: now,
        },
      });
      await tx.auditLog.create({
        data: {
          actorUserId: userId,
          action: "account.delete.purge",
          resourceType: "user",
          resourceId: userId,
          metadata: {},
        },
      });
    });
  }

  private async payload(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        profile: true,
        cards: {
          include: {
            activeVersion: { include: { contacts: true, addresses: true, socialLinks: true } },
          },
        },
        snapshots: true,
        notes: true,
      },
    });
    if (!user) throw new ApiException(401, "unauthenticated", "Authentication required");
    return {
      profile: {
        displayName: user.profile?.displayName ?? "Member",
        email: user.email,
        locale: user.profile?.locale ?? null,
        countryCode: user.profile?.countryCode ?? null,
      },
      cards: user.cards.map((card) => ({
        title: card.title,
        contacts: (card.activeVersion?.contacts ?? []).map((contact) => ({
          kind: contact.kind,
          value: contact.valueRaw,
        })),
        addresses: (card.activeVersion?.addresses ?? []).map((address) => ({
          formattedAddress: address.formattedAddress,
        })),
        socials: (card.activeVersion?.socialLinks ?? []).map((social) => ({
          platform: social.platform,
          url: social.url,
        })),
      })),
      received: user.snapshots.map((snapshot) => snapshot.payload),
      notes: user.notes.map((note) => ({ body: note.body })),
    };
  }

  private async owned(userId: string, exportId: string) {
    const row = await this.prisma.dataExport.findFirst({ where: { id: exportId, userId } });
    if (!row) throw new ApiException(404, "not_found", "Export was not found");
    return row;
  }

  private async replay<T>(userId: string, key: string, requestHash: string): Promise<T | null> {
    const existing = await this.prisma.idempotencyKey.findUnique({
      where: { userId_key: { userId, key } },
    });
    if (!existing) return null;
    if (existing.requestHash !== requestHash) {
      throw new ApiException(
        409,
        "conflict",
        "Idempotency key was reused with a different request",
      );
    }
    return existing.responseBody as T;
  }
}

function hashBody(value: unknown): string {
  return createHash("sha256").update(JSON.stringify(value)).digest("hex");
}

function countMap(rows: { status: string; _count: { _all: number } }[]): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const row of rows) counts[row.status] = row._count._all;
  return counts;
}
