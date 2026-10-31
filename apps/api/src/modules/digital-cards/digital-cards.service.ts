import { Inject, Injectable } from "@nestjs/common";
import type {
  CreateDigitalCardRequest,
  DesignPatchRequest,
  PublishCardRequest,
} from "@softxu/contracts";
import { Prisma } from "@prisma/client";

import { ApiException } from "../../common/api.exception";
import { EnvService } from "../../config/env.service";
import { PrismaService } from "../../prisma/prisma.service";
import type { JobQueue } from "../../queue/job-queue";
import { JOB_QUEUE } from "../../queue/job-queue";
import { AuditService } from "../audit/audit.service";
import { normalizeContacts } from "../cards/normalize";
import { buildPublicCard, renderExport, type DesignConfig, type PublicCard } from "./render";

const detailInclude = {
  activeVersion: { include: { contacts: true, addresses: true, socialLinks: true } },
} satisfies Prisma.BusinessCardInclude;

@Injectable()
export class DigitalCardsService {
  constructor(
    @Inject(PrismaService) private readonly prisma: PrismaService,
    @Inject(AuditService) private readonly audit: AuditService,
    @Inject(EnvService) private readonly env: EnvService,
    @Inject(JOB_QUEUE) private readonly queue: JobQueue,
  ) {}

  async templates() {
    const rows = await this.prisma.cardTemplate.findMany({
      orderBy: [{ key: "asc" }, { version: "asc" }],
    });
    return {
      items: rows.map((row) => ({
        key: row.key,
        version: row.version,
        name: row.name,
        layout: row.layout,
        allowedColors: stringList(row.allowedColors),
        allowedTypeScales: stringList(row.allowedTypeScales),
      })),
    };
  }

  async create(userId: string, input: CreateDigitalCardRequest, requestId: string) {
    const template = await this.latestTemplate(input.templateKey);
    const contacts = normalizeContacts(input.contacts).map((contact) => ({
      ...contact,
      isPublic: contact.isPublic ?? contact.kind !== "phone",
    }));
    const name = contacts.find((contact) => contact.kind === "name")?.valueRaw ?? input.title;
    const design = defaultDesign(template, name);
    const created = await this.prisma.$transaction(async (tx) => {
      const card = await tx.businessCard.create({
        data: {
          ownerUserId: userId,
          title: input.title,
          cardType: "created",
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
          designConfig: design,
          contacts: {
            create: contacts.map((contact) => ({
              kind: contact.kind,
              label: contact.label ?? null,
              valueRaw: contact.valueRaw,
              valueNormalized: contact.valueNormalized,
              whatsappState:
                contact.kind === "phone" ? (contact.whatsappState ?? "unknown") : "unknown",
              isPrimary: contact.isPrimary ?? false,
              isPublic: contact.isPublic,
              source: "user" as const,
              verifiedAt: new Date(),
            })),
          },
        },
      });
      await tx.businessCard.update({
        where: { id: card.id },
        data: { activeVersionId: version.id },
      });
      const entry = await tx.walletEntry.create({
        data: { userId, origin: "owned", cardId: card.id, source: "created" },
      });
      await tx.networkingEvent.create({
        data: {
          userId,
          walletEntryId: entry.id,
          eventType: "saved",
          metadata: { origin: "created" },
        },
      });
      return card.id;
    });
    await this.audit.record({
      actorUserId: userId,
      action: "card.create",
      resourceType: "business_card",
      resourceId: created,
      requestId,
      metadata: {
        cardType: "created",
        templateKey: template.key,
        templateVersion: template.version,
      },
    });
    return this.getOwned(userId, created);
  }

  async getOwned(userId: string, cardId: string) {
    const card = await this.owned(userId, cardId);
    const design = readDesign(card.activeVersion?.designConfig);
    return {
      id: card.id,
      title: card.title,
      visibility: card.visibility,
      slug: card.publicSlug,
      design,
      contacts: (card.activeVersion?.contacts ?? []).map((contact) => ({
        kind: contact.kind,
        value: contact.valueRaw,
        valueNormalized: contact.valueNormalized,
        isPublic: contact.isPublic,
      })),
    };
  }

  async patchDesign(userId: string, cardId: string, input: DesignPatchRequest, requestId: string) {
    const card = await this.owned(userId, cardId);
    const current = readDesign(card.activeVersion?.designConfig);
    const template = await this.template(current.templateKey, current.templateVersion);
    const color = input.color.toLowerCase();
    if (!stringList(template.allowedColors).includes(color)) {
      throw new ApiException(400, "validation_error", "Validation failed", [
        { field: "color", message: "Choose a colour from this template" },
      ]);
    }
    if (!stringList(template.allowedTypeScales).includes(input.typeScale)) {
      throw new ApiException(400, "validation_error", "Validation failed", [
        { field: "typeScale", message: "Choose a type scale from this template" },
      ]);
    }
    if (input.logoAssetId) await this.ownedAsset(userId, input.logoAssetId);
    if (input.photoAssetId) await this.ownedAsset(userId, input.photoAssetId);
    const next: DesignConfig = {
      ...current,
      color,
      typeScale: input.typeScale,
      logoAssetId: input.logoAssetId === undefined ? current.logoAssetId : input.logoAssetId,
      photoAssetId: input.photoAssetId === undefined ? current.photoAssetId : input.photoAssetId,
      frontHeadline: input.frontHeadline ?? current.frontHeadline,
      frontSubline: input.frontSubline ?? current.frontSubline,
      backNote: input.backNote ?? current.backNote,
    };
    const versionId = card.activeVersion?.id;
    if (!versionId) throw new ApiException(404, "not_found", "Card was not found");
    await this.prisma.cardVersion.update({
      where: { id: versionId },
      data: { designConfig: next },
    });
    await this.audit.record({
      actorUserId: userId,
      action: "card.design",
      resourceType: "business_card",
      resourceId: cardId,
      requestId,
      metadata: { templateKey: current.templateKey, templateVersion: current.templateVersion },
    });
    return this.getOwned(userId, cardId);
  }

  async publish(userId: string, cardId: string, input: PublishCardRequest, requestId: string) {
    await this.owned(userId, cardId);
    try {
      await this.prisma.businessCard.update({
        where: { id: cardId },
        data: { publicSlug: input.slug, visibility: input.visibility },
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002") {
        throw new ApiException(409, "conflict", "That public link is already in use");
      }
      throw error;
    }
    await this.audit.record({
      actorUserId: userId,
      action: "card.publish",
      resourceType: "business_card",
      resourceId: cardId,
      requestId,
      metadata: { visibility: input.visibility },
    });
    return this.getOwned(userId, cardId);
  }

  async export(
    userId: string,
    cardId: string,
    format: "qr" | "png" | "pdf" | "vcf",
    requestId: string,
  ) {
    const card = await this.owned(userId, cardId);
    const view = this.publicView(card);
    if (!view) throw new ApiException(409, "conflict", "Publish the card before exporting");
    if (format === "png" || format === "pdf") {
      await this.queue.send("export", { cardId, format });
    }
    await this.audit.record({
      actorUserId: userId,
      action: "card.export",
      resourceType: "business_card",
      resourceId: cardId,
      requestId,
      metadata: { format },
    });
    return renderExport(format, view);
  }

  async publicBySlug(slug: string): Promise<PublicCard> {
    const card = await this.prisma.businessCard.findFirst({
      where: {
        publicSlug: slug,
        status: "active",
        visibility: { in: ["public", "unlisted"] },
        cardType: "created",
      },
      include: detailInclude,
    });
    const view = card ? this.publicView(card) : null;
    if (!view) throw new ApiException(404, "not_found", "Card was not found");
    return view;
  }

  private publicView(
    card: Prisma.BusinessCardGetPayload<{ include: typeof detailInclude }>,
  ): PublicCard | null {
    if (!card.publicSlug || (card.visibility !== "public" && card.visibility !== "unlisted"))
      return null;
    const design = readDesign(card.activeVersion?.designConfig);
    return buildPublicCard({
      slug: card.publicSlug,
      title: card.title,
      layout: design.templateKey === "split" ? "split" : "classic",
      design,
      origin: this.env.values.PUBLIC_WEB_ORIGIN,
      contacts: (card.activeVersion?.contacts ?? []).map((contact) => ({
        kind: contact.kind,
        value: contact.valueRaw,
        valueNormalized: contact.valueNormalized,
        isPublic: contact.isPublic,
      })),
      addresses: (card.activeVersion?.addresses ?? []).map((address) => ({
        formattedAddress: address.formattedAddress,
        isPublic: address.isPublic,
      })),
      socials: (card.activeVersion?.socialLinks ?? []).map((social) => ({
        platform: social.platform,
        url: social.url,
        isPublic: social.isPublic,
      })),
    });
  }

  private async owned(userId: string, cardId: string) {
    const card = await this.prisma.businessCard.findFirst({
      where: { id: cardId, ownerUserId: userId, cardType: "created" },
      include: detailInclude,
    });
    if (!card?.activeVersion) throw new ApiException(404, "not_found", "Card was not found");
    return card;
  }

  private async ownedAsset(userId: string, assetId: string) {
    const asset = await this.prisma.cardAsset.findFirst({
      where: { id: assetId, ownerUserId: userId, status: "stored" },
    });
    if (!asset) throw new ApiException(404, "not_found", "Image was not found");
    return asset;
  }

  private async latestTemplate(key: string) {
    const template = await this.prisma.cardTemplate.findFirst({
      where: { key },
      orderBy: { version: "desc" },
    });
    if (!template) {
      throw new ApiException(400, "validation_error", "Validation failed", [
        { field: "templateKey", message: "Choose a template" },
      ]);
    }
    return template;
  }

  private async template(key: string, version: number) {
    const template = await this.prisma.cardTemplate.findUnique({
      where: { key_version: { key, version } },
    });
    if (!template)
      throw new ApiException(409, "conflict", "This template version is no longer available");
    return template;
  }
}

function stringList(value: Prisma.JsonValue): string[] {
  if (!Array.isArray(value)) return [];
  return value.filter((item): item is string => typeof item === "string");
}

function defaultDesign(
  template: {
    key: string;
    version: number;
    allowedColors: Prisma.JsonValue;
    allowedTypeScales: Prisma.JsonValue;
  },
  headline: string,
): DesignConfig {
  const colors = stringList(template.allowedColors);
  const scales = stringList(template.allowedTypeScales);
  const typeScale = scales.includes("md")
    ? "md"
    : scales[0] === "sm" || scales[0] === "lg"
      ? scales[0]
      : "md";
  return {
    templateKey: template.key,
    templateVersion: template.version,
    color: (colors[0] ?? "#0f6e56").toLowerCase(),
    typeScale,
    logoAssetId: null,
    photoAssetId: null,
    frontHeadline: headline,
    frontSubline: "",
    backNote: "",
  };
}

function readDesign(value: Prisma.JsonValue | null | undefined): DesignConfig {
  const record = value && typeof value === "object" && !Array.isArray(value) ? value : {};
  const typeScale =
    record.typeScale === "sm" || record.typeScale === "lg" || record.typeScale === "md"
      ? record.typeScale
      : "md";
  return {
    templateKey: typeof record.templateKey === "string" ? record.templateKey : "classic",
    templateVersion: typeof record.templateVersion === "number" ? record.templateVersion : 1,
    color: typeof record.color === "string" ? record.color : "#0f6e56",
    typeScale,
    logoAssetId: typeof record.logoAssetId === "string" ? record.logoAssetId : null,
    photoAssetId: typeof record.photoAssetId === "string" ? record.photoAssetId : null,
    frontHeadline: typeof record.frontHeadline === "string" ? record.frontHeadline : "",
    frontSubline: typeof record.frontSubline === "string" ? record.frontSubline : "",
    backNote: typeof record.backNote === "string" ? record.backNote : "",
  };
}
