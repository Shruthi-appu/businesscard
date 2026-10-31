import { createHash, createHmac, randomBytes } from "crypto";

import { Inject, Injectable } from "@nestjs/common";
import type { ClaimShareRequest, CreateShareRequest } from "@softxu/contracts";
import { Prisma } from "@prisma/client";

import { ApiException } from "../../common/api.exception";
import { EnvService } from "../../config/env.service";
import { PrismaService } from "../../prisma/prisma.service";
import { hashPassword, verifyPassword } from "../auth/password";
import { RateLimitService } from "../auth/rate-limit.service";
import { AuditService } from "../audit/audit.service";
import { normalizePhone } from "../cards/normalize";
import { toVcard, type PublicCard } from "../digital-cards/render";
import { IdempotencyService } from "../idempotency/idempotency.service";
import { MessageSender } from "./message-sender";

const WEEK_SECONDS = 60 * 60 * 24 * 7;
const shareUnavailable = "Sharing is temporarily unavailable";

type VersionRow = Prisma.CardVersionGetPayload<{
  include: { contacts: true; addresses: true; socialLinks: true; card: true };
}>;

@Injectable()
export class SharesService {
  constructor(
    @Inject(PrismaService) private readonly prisma: PrismaService,
    @Inject(AuditService) private readonly audit: AuditService,
    @Inject(IdempotencyService) private readonly idempotency: IdempotencyService,
    @Inject(RateLimitService) private readonly rateLimit: RateLimitService,
    @Inject(EnvService) private readonly env: EnvService,
    @Inject(MessageSender) private readonly messages: MessageSender,
  ) {}

  async create(
    userId: string,
    cardId: string,
    input: CreateShareRequest,
    requestId: string,
    idempotencyKey?: string,
  ) {
    await this.rateLimit.consume(
      `share:create:${userId}`,
      this.env.values.RATE_LIMIT_SHARE_MAX,
      this.env.values.RATE_LIMIT_SHARE_WINDOW_SECONDS,
      shareUnavailable,
    );
    const requestHash = hashBody({ cardId, ...input });
    if (idempotencyKey) {
      const prior = await this.replay(userId, idempotencyKey, requestHash);
      if (prior) return prior;
    }
    const version = await this.ownedVersion(userId, cardId, input.versionId);
    const fieldIds = [...new Set(input.fieldIds)];
    project(version, fieldIds);
    const phone = input.recipientPhone ? normalizePhone(input.recipientPhone) : null;
    if (input.recipientPhone && !phone) {
      throw new ApiException(
        400,
        "validation_error",
        "Enter a phone number in international format",
      );
    }
    if (input.sendSms && !phone) {
      throw new ApiException(400, "validation_error", "Add a phone number before sending a text");
    }
    const token = randomBytes(32).toString("base64url");
    const expiresIn = input.expiresInSeconds ?? WEEK_SECONDS;
    const sms = input.sendSms && phone ? this.messages.send(phone, token) : "none";
    const share = await this.prisma.cardShare.create({
      data: {
        cardId,
        cardVersionId: version.id,
        senderUserId: userId,
        tokenHash: hashToken(token),
        recipientPhoneHash: phone ? this.phoneHash(phone) : null,
        scope: { fieldIds },
        pinHash: input.pin ? await hashPassword(input.pin) : null,
        expiresAt: new Date(Date.now() + expiresIn * 1000),
        maxClaims: 1,
      },
    });
    const entry = await this.prisma.walletEntry.findFirst({
      where: { userId, cardId, deletedAt: null, origin: "owned" },
    });
    if (entry) {
      await this.prisma.networkingEvent.create({
        data: {
          userId,
          walletEntryId: entry.id,
          eventType: "shared",
          metadata: { fieldCount: fieldIds.length },
        },
      });
    }
    await this.audit.record({
      actorUserId: userId,
      action: "share.create",
      resourceType: "card_share",
      resourceId: share.id,
      requestId,
      metadata: { fieldCount: fieldIds.length, pinSet: Boolean(input.pin), sms },
    });
    const body = {
      id: share.id,
      url: `${this.env.values.PUBLIC_WEB_ORIGIN.replace(/\/$/, "")}/s/${token}`,
      expiresAt: share.expiresAt.toISOString(),
      pinRequired: Boolean(input.pin),
      fieldCount: fieldIds.length,
      sms,
    };
    if (idempotencyKey) {
      await this.idempotency.remember({
        userId,
        key: idempotencyKey,
        requestHash,
        responseStatus: 201,
        responseBody: body,
      });
    }
    return body;
  }

  async list(userId: string, cardId: string) {
    await this.ownedCard(userId, cardId);
    const shares = await this.prisma.cardShare.findMany({
      where: { cardId, senderUserId: userId },
      orderBy: { createdAt: "desc" },
    });
    return {
      items: shares.map((share) => ({
        id: share.id,
        expiresAt: share.expiresAt.toISOString(),
        revokedAt: share.revokedAt?.toISOString() ?? null,
        claimCount: share.claimCount,
        maxClaims: share.maxClaims,
        pinRequired: Boolean(share.pinHash),
        fieldCount: readFieldIds(share.scope).length,
        createdAt: share.createdAt.toISOString(),
      })),
    };
  }

  async revoke(userId: string, shareId: string, requestId: string) {
    const share = await this.prisma.cardShare.findFirst({
      where: { id: shareId, senderUserId: userId },
    });
    if (!share) throw new ApiException(404, "not_found", "Share was not found");
    if (!share.revokedAt) {
      await this.prisma.cardShare.update({
        where: { id: share.id },
        data: { revokedAt: new Date() },
      });
      await this.audit.record({
        actorUserId: userId,
        action: "share.revoke",
        resourceType: "card_share",
        resourceId: share.id,
        requestId,
        metadata: {},
      });
    }
    const fresh = await this.prisma.cardShare.findUniqueOrThrow({ where: { id: share.id } });
    return { id: fresh.id, revokedAt: fresh.revokedAt?.toISOString() ?? null };
  }

  async preview(token: string, pin?: string) {
    const share = await this.findToken(token);
    const gate = await this.open(share, pin, "optional");
    if (gate === "locked") {
      return {
        pinRequired: true,
        expiresAt: share.expiresAt.toISOString(),
        senderName: senderName(share.sender.profile?.displayName),
      };
    }
    return {
      pinRequired: false,
      expiresAt: share.expiresAt.toISOString(),
      senderName: senderName(share.sender.profile?.displayName),
      ...publicView(project(share.version, readFieldIds(share.scope))),
    };
  }

  async vcard(token: string, pin?: string): Promise<{ body: Buffer; filename: string }> {
    const share = await this.findToken(token);
    await this.open(share, pin, "required");
    const view = publicView(project(share.version, readFieldIds(share.scope)));
    const card: PublicCard = {
      slug: "share",
      title: view.title,
      templateKey: "classic",
      templateVersion: 1,
      layout: "classic",
      color: "#1c1915",
      typeScale: "md",
      frontHeadline: view.contacts.find((contact) => contact.kind === "name")?.value ?? view.title,
      frontSubline: "",
      backNote: "",
      publicUrl: "",
      contacts: view.contacts,
      addresses: view.addresses,
      socials: view.socials,
    };
    return { body: Buffer.from(toVcard(card), "utf8"), filename: "card.vcf" };
  }

  async claim(userId: string, token: string, input: ClaimShareRequest, requestId: string) {
    await this.rateLimit.consume(
      `share:claim:${userId}`,
      this.env.values.RATE_LIMIT_SHARE_MAX,
      this.env.values.RATE_LIMIT_SHARE_WINDOW_SECONDS,
      shareUnavailable,
    );
    const share = await this.findToken(token);
    if (share.senderUserId === userId) {
      throw new ApiException(409, "conflict", "You already keep this card");
    }
    await this.open(share, input.pin, "required");
    const view = project(share.version, readFieldIds(share.scope));
    const walletEntryId = await this.prisma.$transaction(async (tx) => {
      const bumped = await tx.cardShare.updateMany({
        where: {
          id: share.id,
          revokedAt: null,
          expiresAt: { gt: new Date() },
          claimCount: { lt: share.maxClaims },
        },
        data: { claimCount: { increment: 1 } },
      });
      if (bumped.count !== 1) {
        throw new ApiException(410, "share_unavailable", "This share link is no longer available");
      }
      const snapshot = await tx.cardSnapshot.create({
        data: {
          sourceCardId: share.cardId,
          sourceVersionId: share.cardVersionId,
          ownerUserId: userId,
          payload: {
            title: view.title,
            contacts: view.contacts,
            addresses: view.addresses,
            socials: view.socials,
          },
        },
      });
      const entry = await tx.walletEntry.create({
        data: {
          userId,
          origin: "received",
          snapshotId: snapshot.id,
          source: "received_link",
          shareId: share.id,
        },
      });
      await tx.shareClaim.create({
        data: {
          shareId: share.id,
          claimedByUserId: userId,
          walletEntryId: entry.id,
        },
      });
      await tx.networkingEvent.create({
        data: {
          userId,
          walletEntryId: entry.id,
          eventType: "saved",
          metadata: { origin: "share" },
        },
      });
      return entry.id;
    });
    await this.audit.record({
      actorUserId: userId,
      action: "share.claim",
      resourceType: "card_share",
      resourceId: share.id,
      requestId,
      metadata: { fieldCount: readFieldIds(share.scope).length },
    });
    return { walletEntryId };
  }

  private async ownedCard(userId: string, cardId: string) {
    const card = await this.prisma.businessCard.findFirst({
      where: { id: cardId, ownerUserId: userId, status: "active" },
    });
    if (!card) throw new ApiException(404, "not_found", "Card was not found");
    return card;
  }

  private async ownedVersion(userId: string, cardId: string, versionId: string) {
    await this.ownedCard(userId, cardId);
    const version = await this.prisma.cardVersion.findFirst({
      where: { id: versionId, cardId },
      include: { contacts: true, addresses: true, socialLinks: true, card: true },
    });
    if (!version) throw new ApiException(404, "not_found", "Card was not found");
    return version;
  }

  private async findToken(token: string) {
    const share = await this.prisma.cardShare.findUnique({
      where: { tokenHash: hashToken(token) },
      include: {
        version: { include: { contacts: true, addresses: true, socialLinks: true, card: true } },
        sender: { include: { profile: true } },
      },
    });
    if (!share) throw new ApiException(404, "not_found", "Share was not found");
    if (
      share.revokedAt ||
      share.expiresAt.getTime() <= Date.now() ||
      share.claimCount >= share.maxClaims
    ) {
      throw new ApiException(410, "share_unavailable", "This share link is no longer available");
    }
    return share;
  }

  private async open(
    share: { tokenHash: string; pinHash: string | null },
    pin: string | undefined,
    mode: "optional" | "required",
  ): Promise<"open" | "locked"> {
    if (!share.pinHash) return "open";
    if (!pin) {
      if (mode === "optional") return "locked";
      throw new ApiException(401, "unauthenticated", "Enter the PIN for this share");
    }
    await this.rateLimit.consume(
      `share:pin:${share.tokenHash.slice(0, 16)}`,
      this.env.values.RATE_LIMIT_SHARE_MAX,
      this.env.values.RATE_LIMIT_SHARE_WINDOW_SECONDS,
      shareUnavailable,
    );
    const matches = await verifyPassword(pin, share.pinHash);
    if (!matches) throw new ApiException(401, "unauthenticated", "That PIN is not correct");
    return "open";
  }

  private phoneHash(phone: string): string {
    return createHmac("sha256", this.env.values.JWT_REFRESH_SECRET).update(phone).digest("hex");
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

function hashToken(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

function hashBody(value: unknown): string {
  return createHash("sha256").update(JSON.stringify(value)).digest("hex");
}

function readFieldIds(scope: Prisma.JsonValue): string[] {
  if (!scope || typeof scope !== "object" || Array.isArray(scope)) return [];
  const ids = (scope as { fieldIds?: unknown }).fieldIds;
  if (!Array.isArray(ids)) return [];
  return ids.filter((id): id is string => typeof id === "string");
}

function senderName(displayName: string | null | undefined): string {
  const name = displayName?.trim();
  return name && name.length > 0 ? name : "Someone";
}

function project(version: VersionRow, fieldIds: string[]) {
  const ids = new Set(fieldIds);
  const contacts = version.contacts.filter((contact) => ids.has(contact.id));
  const addresses = version.addresses.filter((address) => ids.has(address.id));
  const socials = version.socialLinks.filter((social) => ids.has(social.id));
  if (contacts.length + addresses.length + socials.length !== ids.size) {
    throw new ApiException(400, "validation_error", "Choose fields from this card");
  }
  return {
    title: version.card.title,
    contacts: contacts.map((contact) => ({
      id: contact.id,
      kind: contact.kind,
      label: contact.label,
      value: contact.valueRaw,
      valueNormalized: contact.valueNormalized,
      isPrimary: contact.isPrimary,
      whatsappState: contact.whatsappState,
    })),
    addresses: addresses.map((address) => ({
      id: address.id,
      formattedAddress: address.formattedAddress,
    })),
    socials: socials
      .filter((social) => /^https?:\/\//i.test(social.url))
      .map((social) => ({ id: social.id, platform: social.platform, url: social.url })),
  };
}

function publicView(view: ReturnType<typeof project>) {
  return {
    title: view.title,
    contacts: view.contacts.map((contact) => ({
      kind: contact.kind,
      value: contact.value,
      href: contactHref(contact.kind, contact.value, contact.valueNormalized),
    })),
    addresses: view.addresses.map((address) => address.formattedAddress),
    socials: view.socials.map((social) => ({ platform: social.platform, url: social.url })),
  };
}

function contactHref(kind: string, value: string, normalized: string | null): string | null {
  if (kind === "email") return `mailto:${value}`;
  if (kind === "phone" && normalized) return `tel:${normalized}`;
  if (kind === "website" && normalized && /^https?:\/\//i.test(normalized)) return normalized;
  return null;
}
