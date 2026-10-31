import type { IncomingMessage } from "http";
import { inflateRawSync, inflateSync } from "node:zlib";

import type { INestApplication } from "@nestjs/common";
import request from "supertest";

import { createApp } from "../../src/app.factory";
import { PrismaService } from "../../src/prisma/prisma.service";
import { RedisService } from "../../src/redis/redis.service";

const phone = "+14155550199";

function pdfPlaintext(body: Buffer): string {
  const chunks = [body.toString("latin1")];
  const marker = Buffer.from("stream");
  const endMarker = Buffer.from("endstream");
  let offset = 0;
  while (offset < body.length) {
    const start = body.indexOf(marker, offset);
    if (start < 0) break;
    let dataStart = start + marker.length;
    if (body[dataStart] === 0x0d) dataStart += 1;
    if (body[dataStart] === 0x0a) dataStart += 1;
    const end = body.indexOf(endMarker, dataStart);
    if (end < 0) break;
    let dataEnd = end;
    if (dataEnd > dataStart && body[dataEnd - 1] === 0x0a) dataEnd -= 1;
    if (dataEnd > dataStart && body[dataEnd - 1] === 0x0d) dataEnd -= 1;
    const slice = body.subarray(dataStart, dataEnd);
    for (const inflate of [inflateSync, inflateRawSync]) {
      try {
        chunks.push(inflate(slice).toString("latin1"));
        break;
      } catch {
        // A neighbouring stream may use the other deflate wrapper.
      }
    }
    offset = end + endMarker.length;
  }
  return chunks.join("\n").replace(/<([0-9A-Fa-f\s]+)>/g, (literal, hex: string) => {
    const clean = hex.replace(/\s/g, "");
    if (clean.length < 2 || clean.length % 2 !== 0) return literal;
    return Buffer.from(clean, "hex").toString("latin1");
  });
}

function binary(
  res: IncomingMessage | string,
  callback?: (error: Error | null, body: Buffer) => void,
) {
  if (typeof res === "string") {
    callback?.(null, Buffer.from(res));
    return;
  }
  const chunks: Buffer[] = [];
  res.on("data", (chunk: Buffer) => chunks.push(Buffer.from(chunk)));
  res.on("end", () => callback?.(null, Buffer.concat(chunks)));
}

async function register(app: INestApplication, email: string) {
  const response = await request(app.getHttpServer()).post("/v1/auth/register").send({
    email,
    password: "correct-horse",
    displayName: "Ada Lovelace",
  });
  return response.body as { accessToken: string; user: { id: string } };
}

describe("phase 4 digital cards", () => {
  let app: INestApplication;
  let prisma: PrismaService;

  beforeAll(async () => {
    app = await createApp();
    prisma = app.get(PrismaService);
    await app.get(RedisService).flushdb();
  });

  beforeEach(async () => {
    await prisma.$executeRawUnsafe(
      `TRUNCATE TABLE "idempotency_keys", "audit_logs", "refresh_tokens", "user_profiles", "users" RESTART IDENTITY CASCADE`,
    );
  });

  afterAll(async () => {
    await app.close();
  });

  it("publishes a card whose private phone stays off the public page and the vCard", async () => {
    const templates = await request(app.getHttpServer()).get("/v1/templates");
    expect(templates.status).toBe(200);
    expect(templates.body.items.map((item: { key: string }) => item.key).sort()).toEqual([
      "classic",
      "split",
    ]);

    const ada = await register(app, "ada-digital@example.com");
    const created = await request(app.getHttpServer())
      .post("/v1/digital-cards")
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .send({
        title: "Ada",
        templateKey: "classic",
        contacts: [
          { kind: "name", value: "Ada Lovelace", isPrimary: true, isPublic: true },
          { kind: "email", value: "ada@analytical.example", isPublic: true },
          { kind: "phone", value: phone, isPublic: false },
        ],
      });
    expect(created.status).toBe(201);
    expect(
      created.body.contacts.find((row: { kind: string }) => row.kind === "phone").isPublic,
    ).toBe(false);

    const designed = await request(app.getHttpServer())
      .patch(`/v1/digital-cards/${created.body.id}/design`)
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .send({
        color: "#1c1915",
        typeScale: "lg",
        frontHeadline: "Ada Lovelace",
        frontSubline: "Engineer",
        backNote: "Analytical engines",
      });
    expect(designed.status).toBe(200);
    expect(designed.body.design.color).toBe("#1c1915");
    expect(designed.body.design.typeScale).toBe("lg");

    const rejected = await request(app.getHttpServer())
      .patch(`/v1/digital-cards/${created.body.id}/design`)
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .send({ color: "#ffffff", typeScale: "md" });
    expect(rejected.status).toBe(400);

    const hidden = await request(app.getHttpServer()).get("/v1/public/cards/ada-lovelace");
    expect(hidden.status).toBe(404);

    const published = await request(app.getHttpServer())
      .post(`/v1/digital-cards/${created.body.id}/publish`)
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .send({ slug: "ada-lovelace", visibility: "public" });
    expect(published.status).toBe(201);

    const other = await register(app, "bea-digital@example.com");
    const denied = await request(app.getHttpServer())
      .get(`/v1/digital-cards/${created.body.id}`)
      .set("Authorization", `Bearer ${other.accessToken}`);
    expect(denied.status).toBe(404);

    const publicCard = await request(app.getHttpServer()).get("/v1/public/cards/ada-lovelace");
    expect(publicCard.status).toBe(200);
    expect(JSON.stringify(publicCard.body)).not.toContain(phone);
    expect(publicCard.body.contacts.map((row: { kind: string }) => row.kind)).toEqual([
      "name",
      "email",
    ]);
    expect(publicCard.body.publicUrl).toBe("http://localhost:3000/c/ada-lovelace");

    const vcard = await request(app.getHttpServer())
      .post(`/v1/digital-cards/${created.body.id}/export`)
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .buffer(true)
      .parse(binary)
      .send({ format: "vcf" });
    expect(vcard.status).toBe(201);
    expect(vcard.body.toString("utf8")).toContain("EMAIL:ada@analytical.example");
    expect(vcard.body.toString("utf8")).not.toContain(phone);

    const pdf = await request(app.getHttpServer())
      .post(`/v1/digital-cards/${created.body.id}/export`)
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .buffer(true)
      .parse(binary)
      .send({ format: "pdf" });
    expect(pdf.status).toBe(201);
    const pdfText = pdfPlaintext(pdf.body);
    expect(pdfText).toContain("ada@analytical.example");
    expect(pdfText).not.toContain(phone);

    const qr = await request(app.getHttpServer())
      .post(`/v1/digital-cards/${created.body.id}/export`)
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .buffer(true)
      .parse(binary)
      .send({ format: "qr" });
    expect(qr.status).toBe(201);
    expect(qr.body.subarray(0, 4).toString("hex")).toBe("89504e47");
    expect(qr.body.toString("latin1")).not.toContain(phone);
  });
});
