import { createHash, randomUUID } from "crypto";

import { Inject, Injectable } from "@nestjs/common";
import type { ContactInput } from "@softxu/contracts";
import { Prisma } from "@prisma/client";

import { ApiException } from "../../common/api.exception";
import { PrismaService } from "../../prisma/prisma.service";
import type { JobQueue } from "../../queue/job-queue";
import { JOB_QUEUE } from "../../queue/job-queue";
import type { ObjectStorage } from "../../storage/object-storage";
import { OBJECT_STORAGE } from "../../storage/object-storage";
import { AuditService } from "../audit/audit.service";
import { RateLimitService } from "../auth/rate-limit.service";
import { normalizeContacts } from "../cards/normalize";
import { IdempotencyService } from "../idempotency/idempotency.service";
import { EnvService } from "../../config/env.service";
import { extractGrounded, FAIL_SCAN_BODY, MOCK_OCR_TEXT, THUMBNAIL_PNG } from "./extract";

const MAX_BYTES = 20 * 1024 * 1024;
const ATTEMPT_LIMIT = 3;

type SideName = "front" | "back";

@Injectable()
export class ScansService {
  constructor(
    @Inject(PrismaService) private readonly prisma: PrismaService,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorage,
    @Inject(JOB_QUEUE) private readonly queue: JobQueue,
    @Inject(AuditService) private readonly audit: AuditService,
    @Inject(IdempotencyService) private readonly idempotency: IdempotencyService,
    @Inject(EnvService) private readonly env: EnvService,
    @Inject(RateLimitService) private readonly rateLimit: RateLimitService,
  ) {}

  async create(userId: string, requestId: string, idempotencyKey?: string) {
    const requestHash = createHash("sha256").update("scan").digest("hex");
    if (idempotencyKey) {
      const prior = await this.replay(userId, idempotencyKey, requestHash);
      if (prior) return prior;
    }
    const created = await this.prisma.$transaction(async (tx) => {
      const card = await tx.businessCard.create({
        data: {
          ownerUserId: userId,
          title: "Scanned card",
          cardType: "scanned",
          status: "draft",
          visibility: "private",
        },
      });
      return tx.ocrJob.create({
        data: { cardId: card.id, ownerUserId: userId, status: "queued" },
      });
    });
    await this.audit.record({
      actorUserId: userId,
      action: "scan.create",
      resourceType: "ocr_job",
      resourceId: created.id,
      requestId,
      metadata: {},
    });
    const body = await this.view(userId, created.id);
    if (idempotencyKey) {
      await this.idempotency.remember({
        userId,
        key: idempotencyKey,
        requestHash,
        responseStatus: 201,
        responseBody: body as Prisma.InputJsonValue,
      });
    }
    return body;
  }

  async uploadUrl(
    userId: string,
    scanId: string,
    input: {
      side: SideName;
      mimeType: "image/jpeg" | "image/png";
      byteSize: number;
      checksumSha256: string;
    },
  ) {
    await this.rateLimit.consume(
      `presign:${userId}`,
      this.env.values.RATE_LIMIT_PRESIGN_MAX,
      this.env.values.RATE_LIMIT_PRESIGN_WINDOW_SECONDS,
      "Uploads are temporarily unavailable",
    );
    const job = await this.job(userId, scanId);
    if (job.status === "completed" || job.status === "cancelled") {
      throw new ApiException(409, "conflict", "This scan is already finished");
    }
    if (input.byteSize > MAX_BYTES) {
      throw new ApiException(400, "validation_error", "Validation failed", [
        { field: "byteSize", message: "Images must be 20 MB or smaller" },
      ]);
    }
    const assetId = randomUUID();
    const key = `originals/${userId}/${assetId}`;
    await this.prisma.cardAsset.create({
      data: {
        id: assetId,
        ownerUserId: userId,
        s3Key: key,
        assetType: "original",
        status: "pending",
        mimeType: input.mimeType,
        byteSize: input.byteSize,
        checksumSha256: input.checksumSha256,
      },
    });
    const uploadUrl =
      this.storage.kind === "mock"
        ? `${this.env.values.API_PUBLIC_ORIGIN}/v1/scans/${job.id}/objects/${assetId}`
        : await this.storage.presignPut({
            key,
            contentType: input.mimeType,
            expiresInSeconds: 300,
          });
    return {
      assetId,
      side: input.side,
      uploadUrl,
      method: this.storage.kind === "mock" ? "POST" : "PUT",
    };
  }

  async storeBytes(userId: string, scanId: string, assetId: string, bodyBase64: string) {
    const asset = await this.pendingOriginal(userId, scanId, assetId);
    const body = Buffer.from(bodyBase64, "base64");
    if (body.byteLength === 0 || body.byteLength > MAX_BYTES) {
      throw new ApiException(400, "validation_error", "Validation failed", [
        { field: "bodyBase64", message: "Upload the image bytes" },
      ]);
    }
    await this.storage.putObject({ key: asset.s3Key, body, contentType: asset.mimeType });
    return { assetId, stored: false };
  }

  async complete(userId: string, scanId: string, assetId: string, side: SideName) {
    const asset = await this.pendingOriginal(userId, scanId, assetId);
    const before = await this.storage.getObject(asset.s3Key);
    if (!before) {
      throw new ApiException(400, "validation_error", "Validation failed", [
        { field: "assetId", message: "Upload the image before completing" },
      ]);
    }
    const checksum = createHash("sha256").update(before).digest("hex");
    if (checksum !== asset.checksumSha256 || before.byteLength !== asset.byteSize) {
      throw new ApiException(400, "validation_error", "Validation failed", [
        {
          field: "checksumSha256",
          message: "The uploaded file does not match the declared checksum",
        },
      ]);
    }
    await this.prisma.cardAsset.update({ where: { id: asset.id }, data: { status: "stored" } });
    await this.prisma.cardSide.upsert({
      where: { cardId_side: { cardId: (await this.job(userId, scanId)).cardId, side } },
      update: { originalAssetId: asset.id },
      create: { cardId: (await this.job(userId, scanId)).cardId, side, originalAssetId: asset.id },
    });
    const job = await this.job(userId, scanId);
    const sides = await this.prisma.cardSide.findMany({ where: { cardId: job.cardId } });
    const ready =
      sides.some((row) => row.side === "front") && sides.some((row) => row.side === "back");
    if (ready && job.status !== "completed") await this.process(userId, scanId);
    return this.view(userId, scanId);
  }

  async retry(userId: string, scanId: string) {
    const job = await this.job(userId, scanId);
    if (job.errorCode === "dlq") {
      throw new ApiException(409, "conflict", "This scan is in the dead letter queue");
    }
    if (job.status !== "failed") {
      throw new ApiException(409, "conflict", "Only a failed scan can be retried");
    }
    await this.process(userId, scanId);
    return this.view(userId, scanId);
  }

  async confirm(
    userId: string,
    scanId: string,
    input: { version: number; contacts: ContactInput[] },
    requestId: string,
  ) {
    const job = await this.job(userId, scanId);
    if (job.status !== "needs_review") {
      throw new ApiException(409, "conflict", "This scan is not ready to save");
    }
    if (input.version !== job.draftVersion) {
      throw new ApiException(
        409,
        "conflict",
        "This scan was saved somewhere else. Reload and try again",
      );
    }
    const contacts = normalizeContacts(input.contacts);
    const saved = await this.prisma.$transaction(async (tx) => {
      const locked = await tx.ocrJob.updateMany({
        where: {
          id: job.id,
          ownerUserId: userId,
          status: "needs_review",
          draftVersion: input.version,
        },
        data: { status: "completed", completedAt: new Date(), draftVersion: { increment: 1 } },
      });
      if (locked.count === 0) {
        throw new ApiException(
          409,
          "conflict",
          "This scan was saved somewhere else. Reload and try again",
        );
      }
      const version = await tx.cardVersion.create({
        data: {
          cardId: job.cardId,
          versionNumber: 1,
          createdByUserId: userId,
          verifiedAt: new Date(),
          contacts: {
            create: contacts.map((contact) => ({
              kind: contact.kind,
              label: contact.label ?? null,
              valueRaw: contact.valueRaw,
              valueNormalized: contact.valueNormalized,
              whatsappState:
                contact.kind === "phone" ? (contact.whatsappState ?? "unknown") : "unknown",
              isPrimary: contact.isPrimary ?? false,
              isPublic: false,
              source: "user" as const,
              verifiedAt: new Date(),
            })),
          },
        },
      });
      await tx.businessCard.update({
        where: { id: job.cardId },
        data: { activeVersionId: version.id, status: "active", title: titleFrom(contacts) },
      });
      const entry = await tx.walletEntry.create({
        data: { userId, origin: "owned", cardId: job.cardId, source: "scanned" },
      });
      await tx.networkingEvent.create({
        data: { userId, walletEntryId: entry.id, eventType: "saved", metadata: { origin: "scan" } },
      });
      return { cardId: job.cardId, walletEntryId: entry.id };
    });
    await this.audit.record({
      actorUserId: userId,
      action: "scan.confirm",
      resourceType: "business_card",
      resourceId: saved.cardId,
      requestId,
      metadata: {},
    });
    return saved;
  }

  async view(userId: string, scanId: string) {
    const job = await this.job(userId, scanId);
    const sides = await this.prisma.cardSide.findMany({
      where: { cardId: job.cardId },
      select: { side: true, originalAssetId: true },
    });
    const results = await this.prisma.ocrResult.findMany({
      where: { ocrJobId: job.id },
      select: { side: true, structuredResult: true },
    });
    const waiting =
      job.status === "queued" ||
      job.status === "processing_image" ||
      job.status === "processing_ocr";
    return {
      id: job.id,
      cardId: job.cardId,
      status: job.status,
      attempt: job.attempt,
      errorCode: job.errorCode,
      draftVersion: job.draftVersion,
      retryAfterSeconds: waiting ? 2 : null,
      sides: {
        front: sides.some((side) => side.side === "front"),
        back: sides.some((side) => side.side === "back"),
      },
      draft: results[0] ? results[0].structuredResult : null,
    };
  }

  private async process(userId: string, scanId: string) {
    const job = await this.job(userId, scanId);
    const nextAttempt = job.attempt + 1;
    await this.prisma.ocrJob.update({
      where: { id: job.id },
      data: {
        status: "processing_image",
        attempt: nextAttempt,
        startedAt: job.startedAt ?? new Date(),
        errorCode: null,
      },
    });
    await this.queue.send("image-processing", { scanId: job.id, attempt: nextAttempt });
    const sides = await this.prisma.cardSide.findMany({
      where: { cardId: job.cardId },
      include: { originalAsset: true },
    });
    try {
      for (const side of sides) {
        const original = await this.storage.getObject(side.originalAsset.s3Key);
        if (!original) throw new Error("missing_original");
        if (original.equals(FAIL_SCAN_BODY)) throw new Error("ocr_failed");
        const before = createHash("sha256").update(original).digest("hex");
        const enhancedId = randomUUID();
        const thumbId = randomUUID();
        const enhancedKey = `enhanced/${userId}/${enhancedId}`;
        const thumbKey = `thumbnails/${userId}/${thumbId}`;
        await this.storage.putObject({
          key: enhancedKey,
          body: Buffer.from(original),
          contentType: side.originalAsset.mimeType,
        });
        await this.storage.putObject({
          key: thumbKey,
          body: THUMBNAIL_PNG,
          contentType: "image/png",
        });
        const after = await this.storage.getObject(side.originalAsset.s3Key);
        const afterHash = after ? createHash("sha256").update(after).digest("hex") : "";
        if (afterHash !== before) throw new Error("original_mutated");
        await this.prisma.cardAsset.createMany({
          data: [
            {
              id: enhancedId,
              ownerUserId: userId,
              s3Key: enhancedKey,
              assetType: "enhanced",
              status: "stored",
              mimeType: side.originalAsset.mimeType,
              byteSize: original.byteLength,
              checksumSha256: before,
            },
            {
              id: thumbId,
              ownerUserId: userId,
              s3Key: thumbKey,
              assetType: "thumbnail",
              status: "stored",
              mimeType: "image/png",
              byteSize: THUMBNAIL_PNG.byteLength,
              checksumSha256: createHash("sha256").update(THUMBNAIL_PNG).digest("hex"),
            },
          ],
        });
        await this.prisma.cardSide.update({
          where: { id: side.id },
          data: {
            enhancedAssetId: enhancedId,
            thumbnailAssetId: thumbId,
            cropQuad: { fullFrame: true },
          },
        });
        const draft = extractGrounded(MOCK_OCR_TEXT);
        await this.prisma.ocrResult.upsert({
          where: { ocrJobId_side: { ocrJobId: job.id, side: side.side } },
          update: {
            rawText: MOCK_OCR_TEXT,
            structuredResult: draft,
            blocks: [],
            confidence: { provider: "mock-ocr-v1" },
          },
          create: {
            ocrJobId: job.id,
            side: side.side,
            rawText: MOCK_OCR_TEXT,
            blocks: [],
            structuredResult: draft,
            confidence: { provider: "mock-ocr-v1" },
          },
        });
      }
      await this.queue.send("ocr-extraction", { scanId: job.id, attempt: nextAttempt });
      await this.prisma.ocrJob.update({
        where: { id: job.id },
        data: { status: "needs_review", errorCode: null },
      });
    } catch {
      const dlq = nextAttempt >= ATTEMPT_LIMIT;
      await this.prisma.ocrJob.update({
        where: { id: job.id },
        data: { status: "failed", errorCode: dlq ? "dlq" : "ocr_failed" },
      });
      if (dlq)
        await this.queue.send("ocr-extraction", {
          scanId: job.id,
          dlq: true,
          attempt: nextAttempt,
        });
    }
  }

  private async pendingOriginal(userId: string, scanId: string, assetId: string) {
    await this.job(userId, scanId);
    const asset = await this.prisma.cardAsset.findFirst({
      where: { id: assetId, ownerUserId: userId, assetType: "original", status: "pending" },
    });
    if (!asset) throw new ApiException(404, "not_found", "Upload was not found");
    return asset;
  }

  private async job(userId: string, scanId: string) {
    const job = await this.prisma.ocrJob.findFirst({ where: { id: scanId, ownerUserId: userId } });
    if (!job) throw new ApiException(404, "not_found", "Scan was not found");
    return job;
  }

  private async replay(userId: string, key: string, requestHash: string) {
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
    return existing.responseBody;
  }
}

function titleFrom(contacts: Array<{ kind: string; valueRaw: string }>): string {
  return contacts.find((contact) => contact.kind === "name")?.valueRaw ?? "Scanned card";
}
