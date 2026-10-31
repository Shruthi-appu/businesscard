import { PDFDocument, StandardFonts, rgb } from "pdf-lib";
import { PNG } from "pngjs";
import QRCode from "qrcode";

export type PublicContact = {
  kind: string;
  value: string;
  href: string | null;
};

export type PublicCard = {
  slug: string;
  title: string;
  templateKey: string;
  templateVersion: number;
  layout: string;
  color: string;
  typeScale: "sm" | "md" | "lg";
  frontHeadline: string;
  frontSubline: string;
  backNote: string;
  publicUrl: string;
  contacts: PublicContact[];
  addresses: string[];
  socials: Array<{ platform: string; url: string }>;
};

export type DesignConfig = {
  templateKey: string;
  templateVersion: number;
  color: string;
  typeScale: "sm" | "md" | "lg";
  logoAssetId: string | null;
  photoAssetId: string | null;
  frontHeadline: string;
  frontSubline: string;
  backNote: string;
};

type SourceContact = {
  kind: string;
  value: string;
  valueNormalized: string | null;
  isPublic: boolean;
};

export function qrPayload(origin: string, slug: string): string {
  return `${origin.replace(/\/$/, "")}/c/${slug}`;
}

export function buildPublicCard(input: {
  slug: string;
  title: string;
  layout: string;
  design: DesignConfig;
  origin: string;
  contacts: SourceContact[];
  addresses: Array<{ formattedAddress: string; isPublic: boolean }>;
  socials: Array<{ platform: string; url: string; isPublic: boolean }>;
}): PublicCard {
  const contacts = input.contacts
    .filter((contact) => contact.isPublic)
    .map((contact) => ({
      kind: contact.kind,
      value: contact.value,
      href: publicHref(contact),
    }));
  return {
    slug: input.slug,
    title: input.title,
    templateKey: input.design.templateKey,
    templateVersion: input.design.templateVersion,
    layout: input.layout,
    color: input.design.color,
    typeScale: input.design.typeScale,
    frontHeadline: input.design.frontHeadline,
    frontSubline: input.design.frontSubline,
    backNote: input.design.backNote,
    publicUrl: qrPayload(input.origin, input.slug),
    contacts,
    addresses: input.addresses
      .filter((address) => address.isPublic)
      .map((address) => address.formattedAddress),
    socials: input.socials
      .filter((social) => social.isPublic && /^https?:\/\//i.test(social.url))
      .map((social) => ({ platform: social.platform, url: social.url })),
  };
}

export function toVcard(card: PublicCard): string {
  const lines = ["BEGIN:VCARD", "VERSION:3.0"];
  const name =
    card.contacts.find((contact) => contact.kind === "name")?.value || card.frontHeadline;
  if (name) lines.push(`FN:${escapeVcard(name)}`);
  for (const contact of card.contacts) {
    if (contact.kind === "email") lines.push(`EMAIL:${escapeVcard(contact.value)}`);
    if (contact.kind === "phone") lines.push(`TEL:${escapeVcard(contact.value)}`);
    if (contact.kind === "website" && contact.href) lines.push(`URL:${escapeVcard(contact.href)}`);
    if (contact.kind === "company") lines.push(`ORG:${escapeVcard(contact.value)}`);
    if (contact.kind === "designation") lines.push(`TITLE:${escapeVcard(contact.value)}`);
  }
  for (const address of card.addresses) lines.push(`ADR:${escapeVcard(address)}`);
  lines.push("END:VCARD");
  return `${lines.join("\r\n")}\r\n`;
}

export async function renderExport(
  format: "qr" | "png" | "pdf" | "vcf",
  card: PublicCard,
): Promise<{ body: Buffer; contentType: string; filename: string }> {
  const stem = card.slug;
  if (format === "vcf") {
    return {
      body: Buffer.from(toVcard(card), "utf8"),
      contentType: "text/vcard; charset=utf-8",
      filename: `${stem}.vcf`,
    };
  }
  if (format === "qr") {
    const body = await QRCode.toBuffer(card.publicUrl, {
      type: "png",
      width: 256,
      margin: 1,
      errorCorrectionLevel: "M",
    });
    return { body, contentType: "image/png", filename: `${stem}-qr.png` };
  }
  if (format === "pdf") {
    return { body: await cardPdf(card), contentType: "application/pdf", filename: `${stem}.pdf` };
  }
  return {
    body: await cardPng(card.color, card.publicUrl),
    contentType: "image/png",
    filename: `${stem}.png`,
  };
}

function publicHref(contact: SourceContact): string | null {
  if (!contact.isPublic) return null;
  if (contact.kind === "email") return `mailto:${contact.value}`;
  if (contact.kind === "phone" && contact.valueNormalized) return `tel:${contact.valueNormalized}`;
  if (
    contact.kind === "website" &&
    contact.valueNormalized &&
    /^https?:\/\//i.test(contact.valueNormalized)
  ) {
    return contact.valueNormalized;
  }
  return null;
}

function escapeVcard(value: string): string {
  return value
    .replace(/\\/g, "\\\\")
    .replace(/\n/g, "\\n")
    .replace(/,/g, "\\,")
    .replace(/;/g, "\\;");
}

function hexRgb(color: string): { r: number; g: number; b: number } {
  return {
    r: Number.parseInt(color.slice(1, 3), 16),
    g: Number.parseInt(color.slice(3, 5), 16),
    b: Number.parseInt(color.slice(5, 7), 16),
  };
}

function pdfText(value: string): string {
  return value.replace(/[^\x20-\x7E]/g, "").slice(0, 90);
}

async function cardPdf(card: PublicCard): Promise<Buffer> {
  const doc = await PDFDocument.create();
  const page = doc.addPage([420, 280]);
  const font = await doc.embedFont(StandardFonts.Helvetica);
  const color = hexRgb(card.color);
  page.drawRectangle({
    x: 0,
    y: 0,
    width: 420,
    height: 280,
    color: rgb(color.r / 255, color.g / 255, color.b / 255),
  });
  const size = card.typeScale === "lg" ? 22 : card.typeScale === "sm" ? 14 : 18;
  const lines = [
    card.frontHeadline,
    card.frontSubline,
    ...card.contacts.map((contact) => contact.value),
    ...card.addresses,
    card.backNote,
    card.publicUrl,
  ].filter((line) => line.trim().length > 0);
  let y = 230;
  for (const [index, line] of lines.entries()) {
    page.drawText(pdfText(line), {
      x: 24,
      y,
      size: index === 0 ? size : 12,
      font,
      color: rgb(1, 1, 1),
    });
    y -= 22;
  }
  return Buffer.from(await doc.save());
}

async function cardPng(color: string, url: string): Promise<Buffer> {
  const qr = PNG.sync.read(
    await QRCode.toBuffer(url, { type: "png", width: 160, margin: 1, errorCorrectionLevel: "M" }),
  );
  const width = 640;
  const height = 400;
  const image = new PNG({ width, height });
  const fill = hexRgb(color);
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const index = (width * y + x) << 2;
      image.data[index] = fill.r;
      image.data[index + 1] = fill.g;
      image.data[index + 2] = fill.b;
      image.data[index + 3] = 255;
    }
  }
  const originX = width - qr.width - 24;
  const originY = height - qr.height - 24;
  for (let y = 0; y < qr.height; y += 1) {
    for (let x = 0; x < qr.width; x += 1) {
      const src = (qr.width * y + x) << 2;
      const dst = (width * (originY + y) + (originX + x)) << 2;
      image.data[dst] = qr.data[src] ?? 0;
      image.data[dst + 1] = qr.data[src + 1] ?? 0;
      image.data[dst + 2] = qr.data[src + 2] ?? 0;
      image.data[dst + 3] = 255;
    }
  }
  return PNG.sync.write(image);
}
