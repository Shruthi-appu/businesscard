import { createHash } from "crypto";

import { Inject, Injectable } from "@nestjs/common";
import type {
  AddressInput,
  CreateCardRequest,
  ReplaceVersionRequest,
  SocialInput,
} from "@softxu/contracts";
import { Prisma } from "@prisma/client";

import { ApiException } from "../../common/api.exception";
import { PrismaService } from "../../prisma/prisma.service";
import { AuditService } from "../audit/audit.service";
import { IdempotencyService } from "../idempotency/idempotency.service";
import { normalizeAddresses, normalizeContacts, normalizeSocials } from "./normalize";

type ListQuery = {
  q?: string;
  filter?: "all" | "favourites" | "manual" | "created" | "scanned" | "received";
  cursor?: string;
  limit?: number;
};

const detailInclude = {
  activeVersion: {
    include: { contacts: true, addresses: true, socialLinks: true },
  },
} satisfies Prisma.BusinessCardInclude;

@Injectable()
export class CardsService {
  constructor(
    @Inject(PrismaService) private readonly prisma: PrismaService,
    @Inject(AuditService) private readonly audit: AuditService,
    @Inject(IdempotencyService) private readonly idempotency: IdempotencyService,
  ) {}

  async create(
    userId: string,
    input: CreateCardRequest,
    requestId: string,
    idempotencyKey?: string,
  ) {
    const requestHash = hashBody(input);
    if (idempotencyKey) {
      const prior = await this.replay(userId, idempotencyKey, requestHash);
      if (prior) return prior;
    }
    const contacts = normalizeContacts(input.contacts);
    const addresses = normalizeAddresses(input.addresses ?? []);
    const socials = normalizeSocials(input.socials ?? []);
    const duplicateWarnings = await this.duplicates(userId, contacts, null);

    const created = await this.prisma.$transaction(async (tx) => {
      const card = await tx.businessCard.create({
        data: {
          ownerUserId: userId,
          title: input.title,
          cardType: "manual",
          status: "active",
          visibility: "private",
        },
      });
      const version = await tx.cardVersion.create({
        data: {
          cardId: card.id,
          versionNumber: 1,
          createdByUserId: userId,
          verifiedAt: new Date(),
          contacts: { create: contactRows(contacts) },
          addresses: { create: addressRows(addresses) },
          socialLinks: { create: socialRows(socials) },
        },
      });
      const updated = await tx.businessCard.update({
        where: { id: card.id },
        data: { activeVersionId: version.id },
        include: detailInclude,
      });
      const entry = await tx.walletEntry.create({
        data: {
          userId,
          origin: "owned",
          cardId: card.id,
          source: "manual",
        },
      });
      await tx.networkingEvent.create({
        data: {
          userId,
          walletEntryId: entry.id,
          eventType: "saved",
          metadata: { origin: "owned" },
        },
      });
      return { card: updated, entry };
    });

    await this.audit.record({
      actorUserId: userId,
      action: "card.create",
      resourceType: "business_card",
      resourceId: created.card.id,
      requestId,
      metadata: { cardType: "manual" },
    });

    const body = this.present(created.card, created.entry, duplicateWarnings);
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

  async list(userId: string, query: ListQuery) {
    const limit = query.limit ?? 20;
    const cursor = decodeCursor(query.cursor);
    const q = query.q?.trim();
    const entries = await this.prisma.walletEntry.findMany({
      where: {
        userId,
        deletedAt: null,
        ...filterWhere(query.filter),
        ...(cursor
          ? {
              OR: [
                { savedAt: { lt: cursor.savedAt } },
                { savedAt: cursor.savedAt, id: { lt: cursor.id } },
              ],
            }
          : {}),
        ...(q
          ? {
              AND: [
                {
                  OR: [
                    { card: { title: { contains: q, mode: "insensitive" } } },
                    {
                      card: {
                        activeVersion: {
                          contacts: { some: { valueRaw: { contains: q, mode: "insensitive" } } },
                        },
                      },
                    },
                    { notes: { some: { body: { contains: q, mode: "insensitive" } } } },
                    { tags: { some: { tag: { name: { contains: q, mode: "insensitive" } } } } },
                  ],
                },
              ],
            }
          : {}),
      },
      include: { card: { include: { activeVersion: { include: { contacts: true } } } } },
      orderBy: [{ savedAt: "desc" }, { id: "desc" }],
      take: limit + 1,
    });
    const page = entries.slice(0, limit);
    const last = page.at(-1);
    return {
      items: page.map((entry) => ({
        id: entry.card?.id ?? entry.id,
        walletEntryId: entry.id,
        title: entry.card?.title ?? "Saved card",
        cardType: entry.card?.cardType ?? "manual",
        source: entry.source,
        isFavourite: entry.isFavourite,
        headline: primary(entry.card?.activeVersion?.contacts ?? [], "name"),
        company: primary(entry.card?.activeVersion?.contacts ?? [], "company"),
        savedAt: entry.savedAt.toISOString(),
      })),
      nextCursor:
        entries.length > limit && last ? `${last.savedAt.toISOString()}|${last.id}` : null,
    };
  }

  async get(userId: string, cardId: string) {
    const found = await this.owned(userId, cardId);
    const warnings = await this.duplicates(
      userId,
      (found.card.activeVersion?.contacts ?? []).map((contact) => ({
        kind: contact.kind,
        value: contact.valueRaw,
        valueRaw: contact.valueRaw,
        valueNormalized: contact.valueNormalized,
      })),
      cardId,
    );
    return this.present(found.card, found.entry, warnings);
  }

  async patchTitle(userId: string, cardId: string, title: string | undefined, requestId: string) {
    const found = await this.owned(userId, cardId);
    if (!title) return this.get(userId, cardId);
    await this.prisma.businessCard.update({
      where: { id: found.card.id },
      data: { title },
    });
    await this.audit.record({
      actorUserId: userId,
      action: "card.update",
      resourceType: "business_card",
      resourceId: cardId,
      requestId,
      metadata: {},
    });
    return this.get(userId, cardId);
  }

  async replaceVersion(
    userId: string,
    cardId: string,
    input: ReplaceVersionRequest,
    requestId: string,
  ) {
    const found = await this.owned(userId, cardId);
    const contacts = normalizeContacts(input.contacts);
    const addresses = normalizeAddresses(input.addresses ?? []);
    const socials = normalizeSocials(input.socials ?? []);
    const nextNumber = (found.card.activeVersion?.versionNumber ?? 0) + 1;
    const version = await this.prisma.cardVersion.create({
      data: {
        cardId,
        versionNumber: nextNumber,
        createdByUserId: userId,
        verifiedAt: new Date(),
        contacts: { create: contactRows(contacts) },
        addresses: { create: addressRows(addresses) },
        socialLinks: { create: socialRows(socials) },
      },
    });
    await this.prisma.businessCard.update({
      where: { id: cardId },
      data: { activeVersionId: version.id },
    });
    await this.audit.record({
      actorUserId: userId,
      action: "card.version",
      resourceType: "business_card",
      resourceId: cardId,
      requestId,
      metadata: { versionNumber: nextNumber },
    });
    return this.get(userId, cardId);
  }

  async setFavourite(userId: string, entryId: string, isFavourite: boolean) {
    await this.entry(userId, entryId);
    await this.prisma.walletEntry.update({ where: { id: entryId }, data: { isFavourite } });
    return { id: entryId, isFavourite };
  }

  async addTag(userId: string, entryId: string, name: string) {
    await this.entry(userId, entryId);
    const trimmed = name.trim();
    const tag = await this.prisma.cardTag.upsert({
      where: { userId_name: { userId, name: trimmed } },
      update: {},
      create: { userId, name: trimmed },
    });
    await this.prisma.cardTagLink.upsert({
      where: { walletEntryId_tagId: { walletEntryId: entryId, tagId: tag.id } },
      update: {},
      create: { walletEntryId: entryId, tagId: tag.id },
    });
    return { id: tag.id, name: tag.name };
  }

  async removeTag(userId: string, entryId: string, tagId: string) {
    await this.entry(userId, entryId);
    await this.prisma.cardTagLink.deleteMany({ where: { walletEntryId: entryId, tagId } });
  }

  async addNote(userId: string, entryId: string, body: string) {
    await this.entry(userId, entryId);
    const note = await this.prisma.contactNote.create({
      data: { userId, walletEntryId: entryId, body: body.trim() },
    });
    await this.prisma.networkingEvent.create({
      data: {
        userId,
        walletEntryId: entryId,
        eventType: "note",
        metadata: {},
      },
    });
    return { id: note.id, body: note.body, createdAt: note.createdAt.toISOString() };
  }

  async addReminder(userId: string, entryId: string, remindAt: string, note?: string) {
    await this.entry(userId, entryId);
    const when = new Date(remindAt);
    if (Number.isNaN(when.getTime())) {
      throw new ApiException(400, "validation_error", "Validation failed", [
        { field: "remindAt", message: "Enter a valid date" },
      ]);
    }
    const reminder = await this.prisma.reminder.create({
      data: { userId, walletEntryId: entryId, remindAt: when, note: note?.trim() || null },
    });
    await this.prisma.networkingEvent.create({
      data: {
        userId,
        walletEntryId: entryId,
        eventType: "reminder_set",
        metadata: {},
      },
    });
    return {
      id: reminder.id,
      remindAt: reminder.remindAt.toISOString(),
      status: reminder.status,
      note: reminder.note,
    };
  }

  async patchReminder(userId: string, entryId: string, reminderId: string, status: string) {
    await this.entry(userId, entryId);
    if (status !== "scheduled" && status !== "done" && status !== "cancelled") {
      throw new ApiException(400, "validation_error", "Validation failed", [
        { field: "status", message: "Status is not recognised" },
      ]);
    }
    const updated = await this.prisma.reminder.updateMany({
      where: { id: reminderId, walletEntryId: entryId, userId },
      data: { status },
    });
    if (updated.count === 0) {
      throw new ApiException(404, "not_found", "Reminder was not found");
    }
    return { id: reminderId, status };
  }

  async history(userId: string, entryId: string) {
    await this.entry(userId, entryId);
    const events = await this.prisma.networkingEvent.findMany({
      where: { walletEntryId: entryId, userId },
      orderBy: { occurredAt: "desc" },
    });
    return {
      items: events.map((event) => ({
        id: event.id,
        eventType: event.eventType,
        occurredAt: event.occurredAt.toISOString(),
      })),
    };
  }

  async softDelete(userId: string, entryId: string, requestId: string) {
    const entry = await this.entry(userId, entryId);
    await this.prisma.walletEntry.update({
      where: { id: entryId },
      data: { deletedAt: new Date() },
    });
    if (entry.cardId) {
      await this.prisma.businessCard.updateMany({
        where: { id: entry.cardId, ownerUserId: userId },
        data: { status: "archived" },
      });
    }
    await this.audit.record({
      actorUserId: userId,
      action: "wallet.delete",
      resourceType: "wallet_entry",
      resourceId: entryId,
      requestId,
      metadata: {},
    });
  }

  private async owned(userId: string, cardId: string) {
    const entry = await this.prisma.walletEntry.findFirst({
      where: { userId, cardId, deletedAt: null, origin: "owned" },
      include: { card: { include: detailInclude }, tags: { include: { tag: true } } },
    });
    if (!entry?.card || entry.card.ownerUserId !== userId) {
      throw new ApiException(404, "not_found", "Card was not found");
    }
    return { entry, card: entry.card };
  }

  private async entry(userId: string, entryId: string) {
    const entry = await this.prisma.walletEntry.findFirst({
      where: { id: entryId, userId, deletedAt: null },
    });
    if (!entry) throw new ApiException(404, "not_found", "Wallet entry was not found");
    return entry;
  }

  private async duplicates(
    userId: string,
    contacts: Array<{ kind: string; valueNormalized: string | null }>,
    exceptCardId: string | null,
  ) {
    const keys = contacts.filter(
      (contact) =>
        (contact.kind === "email" || contact.kind === "phone") && contact.valueNormalized,
    );
    if (keys.length === 0) return [];
    const matches = await this.prisma.cardContact.findMany({
      where: {
        OR: keys.map((contact) => ({
          kind: contact.kind as "email" | "phone",
          valueNormalized: contact.valueNormalized,
        })),
        version: {
          activeFor: {
            ownerUserId: userId,
            ...(exceptCardId ? { id: { not: exceptCardId } } : {}),
            walletEntries: { some: { userId, deletedAt: null } },
          },
        },
      },
      select: {
        kind: true,
        valueNormalized: true,
        version: { select: { activeFor: { select: { id: true } } } },
      },
    });
    return matches
      .filter((match) => match.valueNormalized && match.version.activeFor)
      .map((match) => ({
        cardId: match.version.activeFor!.id,
        kind: match.kind as "email" | "phone",
        valueNormalized: match.valueNormalized!,
      }));
  }

  private present(
    card: Prisma.BusinessCardGetPayload<{ include: typeof detailInclude }>,
    entry: {
      id: string;
      isFavourite: boolean;
      source: string;
      savedAt: Date;
      tags?: Array<{ tag: { id: string; name: string } }>;
    },
    duplicateWarnings: Array<{ cardId: string; kind: "email" | "phone"; valueNormalized: string }>,
  ) {
    const version = card.activeVersion;
    return {
      id: card.id,
      walletEntryId: entry.id,
      title: card.title,
      cardType: card.cardType,
      status: card.status,
      visibility: card.visibility,
      source: entry.source,
      isFavourite: entry.isFavourite,
      savedAt: entry.savedAt.toISOString(),
      versionNumber: version?.versionNumber ?? 1,
      contacts: (version?.contacts ?? []).map((contact) => ({
        id: contact.id,
        kind: contact.kind,
        label: contact.label,
        value: contact.valueRaw,
        valueNormalized: contact.valueNormalized,
        isPublic: contact.isPublic,
        isPrimary: contact.isPrimary,
        whatsappState: contact.whatsappState,
        source: contact.source,
      })),
      addresses: (version?.addresses ?? []).map((address) => ({
        id: address.id,
        formattedAddress: address.formattedAddress,
        isPublic: address.isPublic,
      })),
      socials: (version?.socialLinks ?? []).map((social) => ({
        id: social.id,
        platform: social.platform,
        url: social.url,
        isPublic: social.isPublic,
      })),
      tags: (entry.tags ?? []).map((link) => ({ id: link.tag.id, name: link.tag.name })),
      duplicateWarnings,
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

function contactRows(contacts: ReturnType<typeof normalizeContacts>) {
  return contacts.map((contact) => ({
    kind: contact.kind,
    label: contact.label ?? null,
    valueRaw: contact.valueRaw,
    valueNormalized: contact.valueNormalized,
    whatsappState: contact.kind === "phone" ? (contact.whatsappState ?? "unknown") : "unknown",
    isPrimary: contact.isPrimary ?? false,
    isPublic: contact.isPublic ?? false,
    source: "user" as const,
    verifiedAt: new Date(),
  }));
}

function addressRows(addresses: AddressInput[]) {
  return addresses.map((address) => ({
    formattedAddress: address.formattedAddress,
    isPublic: address.isPublic ?? false,
    source: "user" as const,
    verifiedAt: new Date(),
  }));
}

function socialRows(socials: Array<SocialInput & { url: string }>) {
  return socials.map((social) => ({
    platform: social.platform,
    url: social.url,
    isPublic: social.isPublic ?? false,
    source: "user" as const,
    verifiedAt: new Date(),
  }));
}

function primary(
  contacts: Array<{ kind: string; valueRaw: string; isPrimary: boolean }>,
  kind: string,
): string | null {
  const matches = contacts.filter((contact) => contact.kind === kind);
  return (matches.find((contact) => contact.isPrimary) ?? matches[0])?.valueRaw ?? null;
}

function filterWhere(filter: ListQuery["filter"]): Prisma.WalletEntryWhereInput {
  if (filter === "favourites") return { isFavourite: true };
  if (filter === "manual") return { source: "manual" };
  if (filter === "created") return { source: "created" };
  if (filter === "scanned") return { source: "scanned" };
  if (filter === "received") return { origin: "received" };
  return {};
}

function decodeCursor(cursor: string | undefined): { savedAt: Date; id: string } | null {
  if (!cursor) return null;
  const separator = cursor.lastIndexOf("|");
  if (separator <= 0) return null;
  const savedAt = new Date(cursor.slice(0, separator));
  const id = cursor.slice(separator + 1);
  if (Number.isNaN(savedAt.getTime()) || !id) return null;
  return { savedAt, id };
}

function hashBody(value: unknown): string {
  return createHash("sha256").update(JSON.stringify(value)).digest("hex");
}
