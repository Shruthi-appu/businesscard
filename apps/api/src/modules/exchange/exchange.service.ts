import { createHash } from "crypto";

import { Inject, Injectable } from "@nestjs/common";
import type {
  ConsentExchangeRequest,
  CreateExchangeRequest,
  JoinExchangeRequest,
} from "@softxu/contracts";
import { Prisma } from "@prisma/client";

import { ApiException } from "../../common/api.exception";
import { EnvService } from "../../config/env.service";
import { PrismaService } from "../../prisma/prisma.service";
import { AuditService } from "../audit/audit.service";
import { RateLimitService } from "../auth/rate-limit.service";
import { IdempotencyService } from "../idempotency/idempotency.service";
import {
  BLE_NFC_UNAVAILABLE,
  EXCHANGE_TTL_SECONDS,
  exchangeQrPng,
  exchangeUrl,
  hashExchangeCode,
  newExchangeCode,
} from "./exchange-link";

const unavailable = "Exchange is temporarily unavailable";
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const sessionInclude = {
  participants: {
    include: {
      user: { include: { profile: true } },
      selectedCard: {
        include: {
          activeVersion: { include: { contacts: true, addresses: true, socialLinks: true } },
        },
      },
    },
  },
} satisfies Prisma.ExchangeSessionInclude;

type SessionRow = Prisma.ExchangeSessionGetPayload<{ include: typeof sessionInclude }>;

type VersionBits = {
  contacts: Array<{
    id: string;
    kind: string;
    label: string | null;
    valueRaw: string;
    valueNormalized: string | null;
    isPrimary: boolean;
    whatsappState: string;
  }>;
  addresses: Array<{ id: string; formattedAddress: string }>;
  socialLinks: Array<{ id: string; platform: string; url: string }>;
};

@Injectable()
export class ExchangeService {
  constructor(
    @Inject(PrismaService) private readonly prisma: PrismaService,
    @Inject(AuditService) private readonly audit: AuditService,
    @Inject(IdempotencyService) private readonly idempotency: IdempotencyService,
    @Inject(RateLimitService) private readonly rateLimit: RateLimitService,
    @Inject(EnvService) private readonly env: EnvService,
  ) {}

  async create(
    userId: string,
    input: CreateExchangeRequest,
    requestId: string,
    idempotencyKey?: string,
  ) {
    await this.limit(`exchange:create:${userId}`);
    if (input.method !== "qr" && input.method !== "link") {
      throw new ApiException(400, "validation_error", BLE_NFC_UNAVAILABLE);
    }
    const requestHash = hashBody(input);
    const key = cleanKey(idempotencyKey);
    if (key) {
      const prior = await this.replay(userId, key, requestHash);
      if (prior) return prior;
    }
    const card = await this.ownedCard(userId, input.cardId);
    const code = newExchangeCode();
    const expiresIn = input.expiresInSeconds ?? EXCHANGE_TTL_SECONDS;
    const session = await this.prisma.exchangeSession.create({
      data: {
        initiatorUserId: userId,
        status: "open",
        mode: input.mode,
        method: input.method,
        codeHash: hashExchangeCode(code),
        expiresAt: new Date(Date.now() + expiresIn * 1000),
        participants: {
          create: {
            userId,
            selectedCardId: card.id,
            consentStatus: "accepted",
            consentedAt: new Date(),
          },
        },
      },
    });
    const url = exchangeUrl(this.env.values.PUBLIC_WEB_ORIGIN, session.id, code);
    let qrPngBase64: string;
    try {
      qrPngBase64 = (await exchangeQrPng(url)).toString("base64");
    } catch {
      await this.prisma.exchangeSession.update({
        where: { id: session.id },
        data: { status: "failed" },
      });
      throw new ApiException(503, "service_unavailable", unavailable);
    }
    await this.audit.record({
      actorUserId: userId,
      action: "exchange.create",
      resourceType: "exchange_session",
      resourceId: session.id,
      requestId,
      metadata: { mode: input.mode, method: input.method },
    });
    const body = {
      id: session.id,
      url,
      expiresAt: session.expiresAt.toISOString(),
      qrPngBase64,
      mode: input.mode,
      method: input.method,
      status: "open" as const,
    };
    if (key) {
      await this.idempotency.remember({
        userId,
        key,
        requestHash,
        responseStatus: 201,
        responseBody: body,
      });
    }
    return body;
  }

  async get(userId: string, sessionId: string) {
    const session = await this.markExpired(await this.requireParticipant(userId, sessionId));
    const entry = await this.receivedEntry(userId, session.id);
    return this.toView(session, userId, entry?.id ?? null);
  }

  async join(userId: string, sessionId: string, input: JoinExchangeRequest) {
    await this.limit(`exchange:join:${userId}`);
    this.assertUuid(sessionId);
    const codeHash = hashExchangeCode(input.code);
    const outcome = await this.prisma.$transaction(async (tx) => {
      await lockSession(tx, sessionId);
      const session = await tx.exchangeSession.findUnique({
        where: { id: sessionId },
        include: { participants: true },
      });
      if (!session || session.codeHash !== codeHash) return "missing" as const;
      if (session.initiatorUserId === userId) return "self" as const;
      if (isPast(session) && (session.status === "open" || session.status === "joined")) {
        await tx.exchangeSession.update({
          where: { id: session.id },
          data: { status: "expired" },
        });
        return "expired" as const;
      }
      const existing = session.participants.some((participant) => participant.userId === userId);
      if (existing) return "ok" as const;
      if (session.status !== "open" || session.participants.length >= 2) {
        return session.status === "joined" ? ("full" as const) : ("finished" as const);
      }
      await tx.exchangeParticipant.create({
        data: { sessionId, userId, consentStatus: "pending" },
      });
      await tx.exchangeSession.update({
        where: { id: sessionId },
        data: { status: "joined" },
      });
      return "ok" as const;
    });
    if (outcome === "missing") throw new ApiException(404, "not_found", "Exchange was not found");
    if (outcome === "self") throw new ApiException(409, "conflict", "You started this exchange");
    if (outcome === "expired") throw new ApiException(410, "expired", "This exchange has expired");
    if (outcome === "full") {
      throw new ApiException(409, "conflict", "This exchange already has both people");
    }
    if (outcome === "finished") {
      throw new ApiException(409, "conflict", "This exchange is already finished");
    }
    return this.get(userId, sessionId);
  }

  async consent(userId: string, sessionId: string, input: ConsentExchangeRequest) {
    this.assertUuid(sessionId);
    const loaded = await this.markExpired(await this.requireParticipant(userId, sessionId));
    if (loaded.status === "expired") {
      throw new ApiException(410, "expired", "This exchange has expired");
    }
    if (loaded.status !== "open" && loaded.status !== "joined") {
      throw new ApiException(409, "conflict", "This exchange is already finished");
    }
    const self = loaded.participants.find((participant) => participant.userId === userId);
    if (!self) throw new ApiException(404, "not_found", "Exchange was not found");
    if (!input.accept) {
      await this.prisma.$transaction(async (tx) => {
        const updated = await tx.exchangeSession.updateMany({
          where: { id: sessionId, status: { in: ["open", "joined"] } },
          data: { status: "declined" },
        });
        if (updated.count !== 1) {
          throw new ApiException(409, "conflict", "This exchange is already finished");
        }
        await tx.exchangeParticipant.update({
          where: { id: self.id },
          data: { consentStatus: "declined", consentedAt: new Date() },
        });
      });
      return this.get(userId, sessionId);
    }
    let selectedCardId = self.selectedCardId;
    if (loaded.mode === "mutual" && loaded.initiatorUserId !== userId) {
      if (!input.cardId) {
        throw new ApiException(400, "validation_error", "Choose one of your cards");
      }
      const card = await this.ownedCard(userId, input.cardId);
      selectedCardId = card.id;
    }
    if (
      self.consentStatus === "accepted" &&
      self.selectedCardId === selectedCardId &&
      loaded.initiatorUserId === userId
    ) {
      return this.get(userId, sessionId);
    }
    await this.prisma.exchangeParticipant.update({
      where: { id: self.id },
      data: {
        consentStatus: "accepted",
        consentedAt: new Date(),
        selectedCardId,
      },
    });
    return this.get(userId, sessionId);
  }

  async complete(userId: string, sessionId: string, requestId: string, idempotencyKey?: string) {
    this.assertUuid(sessionId);
    const requestHash = hashBody({ sessionId, action: "complete" });
    const key = cleanKey(idempotencyKey);
    if (key) {
      const prior = await this.replay(userId, key, requestHash);
      if (prior) return prior;
    }
    const member = await this.prisma.exchangeParticipant.findFirst({
      where: { sessionId, userId },
    });
    if (!member) throw new ApiException(404, "not_found", "Exchange was not found");
    const outcome = await this.prisma.$transaction(async (tx) => {
      await lockSession(tx, sessionId);
      const session = await tx.exchangeSession.findUnique({
        where: { id: sessionId },
        include: { participants: true },
      });
      if (!session || !session.participants.some((participant) => participant.userId === userId)) {
        throw new ApiException(404, "not_found", "Exchange was not found");
      }
      if (isPast(session) && (session.status === "open" || session.status === "joined")) {
        await tx.exchangeSession.update({
          where: { id: session.id },
          data: { status: "expired" },
        });
        return { kind: "expired" as const };
      }
      if (session.status === "accepted") {
        return {
          kind: "done" as const,
          body: callerResult(userId, await this.entriesByUser(tx, sessionId)),
          wrote: false,
          mode: session.mode,
          method: session.method,
        };
      }
      if (session.status === "expired") {
        throw new ApiException(410, "expired", "This exchange has expired");
      }
      if (session.status !== "joined") {
        throw new ApiException(
          409,
          "conflict",
          session.status === "declined"
            ? "This exchange was declined"
            : "Waiting for the other person",
        );
      }
      const initiator = session.participants.find(
        (participant) => participant.userId === session.initiatorUserId,
      );
      const recipient = session.participants.find(
        (participant) => participant.userId !== session.initiatorUserId,
      );
      const ready =
        initiator?.consentStatus === "accepted" &&
        Boolean(initiator.selectedCardId) &&
        recipient?.consentStatus === "accepted" &&
        (session.mode === "one_way" || Boolean(recipient?.selectedCardId));
      if (!ready || !initiator?.selectedCardId || !recipient) {
        throw new ApiException(409, "conflict", "Waiting for the other person");
      }
      const source = session.method === "link" ? "received_link" : "received_qr";
      if (session.method !== "link" && session.method !== "qr") {
        throw new ApiException(400, "validation_error", BLE_NFC_UNAVAILABLE);
      }
      const claimed = await tx.exchangeSession.updateMany({
        where: { id: sessionId, status: "joined", expiresAt: { gt: new Date() } },
        data: { status: "accepted", acceptedAt: new Date() },
      });
      if (claimed.count !== 1) {
        const again = await tx.exchangeSession.findUnique({ where: { id: sessionId } });
        if (again?.status === "accepted") {
          return {
            kind: "done" as const,
            body: callerResult(userId, await this.entriesByUser(tx, sessionId)),
            wrote: false,
            mode: session.mode,
            method: session.method,
          };
        }
        throw new ApiException(409, "conflict", "Waiting for the other person");
      }
      const entries = new Map<string, string>();
      entries.set(
        recipient.userId,
        await this.writeReceived(
          tx,
          recipient.userId,
          initiator.userId,
          initiator.selectedCardId,
          sessionId,
          source,
          session.mode,
        ),
      );
      if (session.mode === "one_way") {
        await this.noteOwnedExchange(tx, initiator.userId, initiator.selectedCardId, session.mode);
      } else if (recipient.selectedCardId) {
        entries.set(
          initiator.userId,
          await this.writeReceived(
            tx,
            initiator.userId,
            recipient.userId,
            recipient.selectedCardId,
            sessionId,
            source,
            session.mode,
          ),
        );
      }
      return {
        kind: "done" as const,
        body: callerResult(userId, entries),
        wrote: true,
        mode: session.mode,
        method: session.method,
      };
    });
    if (outcome.kind === "expired") {
      throw new ApiException(410, "expired", "This exchange has expired");
    }
    if (outcome.wrote) {
      await this.audit.record({
        actorUserId: userId,
        action: "exchange.complete",
        resourceType: "exchange_session",
        resourceId: sessionId,
        requestId,
        metadata: { mode: outcome.mode, method: outcome.method },
      });
    }
    if (key) {
      await this.idempotency.remember({
        userId,
        key,
        requestHash,
        responseStatus: 200,
        responseBody: outcome.body,
      });
    }
    return outcome.body;
  }

  private async limit(bucket: string) {
    await this.rateLimit.consume(
      bucket,
      this.env.values.RATE_LIMIT_EXCHANGE_MAX,
      this.env.values.RATE_LIMIT_EXCHANGE_WINDOW_SECONDS,
      unavailable,
    );
  }

  private assertUuid(sessionId: string) {
    if (!UUID.test(sessionId)) throw new ApiException(404, "not_found", "Exchange was not found");
  }

  private async requireParticipant(userId: string, sessionId: string) {
    this.assertUuid(sessionId);
    const session = await this.prisma.exchangeSession.findUnique({
      where: { id: sessionId },
      include: sessionInclude,
    });
    if (!session || !session.participants.some((participant) => participant.userId === userId)) {
      throw new ApiException(404, "not_found", "Exchange was not found");
    }
    return session;
  }

  private async markExpired(session: SessionRow): Promise<SessionRow> {
    if (!isPast(session) || (session.status !== "open" && session.status !== "joined")) {
      return session;
    }
    await this.prisma.exchangeSession.update({
      where: { id: session.id },
      data: { status: "expired" },
    });
    return { ...session, status: "expired" };
  }

  private async ownedCard(userId: string, cardId: string) {
    const card = await this.prisma.businessCard.findFirst({
      where: { id: cardId, ownerUserId: userId, status: "active", activeVersionId: { not: null } },
    });
    if (!card) throw new ApiException(404, "not_found", "Card was not found");
    return card;
  }

  private async receivedEntry(userId: string, sessionId: string) {
    return this.prisma.walletEntry.findFirst({
      where: { userId, exchangeSessionId: sessionId, origin: "received", deletedAt: null },
    });
  }

  private async entriesByUser(tx: Prisma.TransactionClient, sessionId: string) {
    const entries = await tx.walletEntry.findMany({
      where: { exchangeSessionId: sessionId, origin: "received", deletedAt: null },
    });
    return new Map(entries.map((entry) => [entry.userId, entry.id]));
  }

  private async writeReceived(
    tx: Prisma.TransactionClient,
    recipientUserId: string,
    giverUserId: string,
    cardId: string,
    sessionId: string,
    source: "received_qr" | "received_link",
    mode: "one_way" | "mutual",
  ) {
    const card = await tx.businessCard.findFirst({
      where: { id: cardId, ownerUserId: giverUserId, status: "active" },
      include: {
        activeVersion: { include: { contacts: true, addresses: true, socialLinks: true } },
      },
    });
    if (!card?.activeVersion) {
      throw new ApiException(409, "conflict", "That card is no longer available");
    }
    const snapshot = await tx.cardSnapshot.create({
      data: {
        sourceCardId: card.id,
        sourceVersionId: card.activeVersion.id,
        ownerUserId: recipientUserId,
        payload: payloadOf(card.title, card.activeVersion),
      },
    });
    const entry = await tx.walletEntry.create({
      data: {
        userId: recipientUserId,
        origin: "received",
        snapshotId: snapshot.id,
        source,
        exchangeSessionId: sessionId,
      },
    });
    await tx.networkingEvent.create({
      data: {
        userId: recipientUserId,
        walletEntryId: entry.id,
        eventType: "exchanged",
        metadata: { mode },
      },
    });
    return entry.id;
  }

  private async noteOwnedExchange(
    tx: Prisma.TransactionClient,
    userId: string,
    cardId: string,
    mode: "one_way" | "mutual",
  ) {
    const owned = await tx.walletEntry.findFirst({
      where: { userId, cardId, origin: "owned", deletedAt: null },
    });
    if (!owned) return;
    await tx.networkingEvent.create({
      data: {
        userId,
        walletEntryId: owned.id,
        eventType: "exchanged",
        metadata: { mode },
      },
    });
  }

  private toView(session: SessionRow, userId: string, receivedWalletEntryId: string | null) {
    const self = session.participants.find((participant) => participant.userId === userId);
    const peer = session.participants.find((participant) => participant.userId !== userId);
    const showOffer = session.status === "open" || session.status === "joined";
    const offered = showOffer ? peer?.selectedCard : null;
    return {
      id: session.id,
      status: session.status,
      mode: session.mode,
      method: session.method,
      expiresAt: session.expiresAt.toISOString(),
      role: session.initiatorUserId === userId ? ("initiator" as const) : ("recipient" as const),
      yourConsent: self?.consentStatus ?? "pending",
      yourCardId: self?.selectedCardId ?? null,
      peerConsent: peer?.consentStatus ?? null,
      peer:
        showOffer && peer
          ? {
              displayName: displayName(peer.user.profile?.displayName),
              card: offered?.activeVersion
                ? previewCard(offered.title, offered.activeVersion)
                : null,
            }
          : null,
      receivedWalletEntryId,
    };
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

function callerResult(userId: string, entries: Map<string, string>) {
  return { status: "accepted" as const, receivedWalletEntryId: entries.get(userId) ?? null };
}

function isPast(session: { expiresAt: Date }): boolean {
  return session.expiresAt.getTime() <= Date.now();
}

function cleanKey(key: string | undefined): string | undefined {
  const trimmed = key?.trim();
  return trimmed ? trimmed : undefined;
}

function hashBody(value: unknown): string {
  return createHash("sha256").update(JSON.stringify(value)).digest("hex");
}

function displayName(name: string | null | undefined): string {
  const trimmed = name?.trim();
  return trimmed && trimmed.length > 0 ? trimmed : "Someone";
}

function payloadOf(title: string, version: VersionBits): Prisma.InputJsonValue {
  return {
    title,
    contacts: version.contacts.map((contact) => ({
      id: contact.id,
      kind: contact.kind,
      label: contact.label,
      value: contact.valueRaw,
      valueNormalized: contact.valueNormalized,
      isPrimary: contact.isPrimary,
      whatsappState: contact.whatsappState,
    })),
    addresses: version.addresses.map((address) => ({
      id: address.id,
      formattedAddress: address.formattedAddress,
    })),
    socials: version.socialLinks.map((social) => ({
      id: social.id,
      platform: social.platform,
      url: social.url,
    })),
  };
}

function previewCard(title: string, version: VersionBits) {
  return {
    title,
    contacts: version.contacts.map((contact) => ({
      kind: contact.kind,
      label: contact.label,
      value: contact.valueRaw,
    })),
    addresses: version.addresses.map((address) => ({
      formattedAddress: address.formattedAddress,
    })),
    socials: version.socialLinks.map((social) => ({
      platform: social.platform,
      url: social.url,
    })),
  };
}

async function lockSession(tx: Prisma.TransactionClient, sessionId: string) {
  await tx.$queryRaw`SELECT id FROM exchange_sessions WHERE id = CAST(${sessionId} AS uuid) FOR UPDATE`;
}
