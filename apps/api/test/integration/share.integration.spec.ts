import type { IncomingMessage } from "http";

import type { INestApplication } from "@nestjs/common";
import request from "supertest";

import { createApp } from "../../src/app.factory";
import { PrismaService } from "../../src/prisma/prisma.service";
import { RedisService } from "../../src/redis/redis.service";

const phone = "+14155550198";

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

describe("phase 5 remote sharing", () => {
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

  it("shares only the chosen fields, then lets a recipient save a copy", async () => {
    const ada = await register(app, "ada-share@example.com");
    const created = await request(app.getHttpServer())
      .post("/v1/cards")
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .send({
        title: "Ada",
        contacts: [
          { kind: "name", value: "Ada Lovelace", isPrimary: true },
          { kind: "email", value: "ada@analytical.example" },
          { kind: "phone", value: phone },
        ],
      });
    expect(created.status).toBe(201);
    const name = created.body.contacts.find((row: { kind: string }) => row.kind === "name");
    const email = created.body.contacts.find((row: { kind: string }) => row.kind === "email");
    const hidden = created.body.contacts.find((row: { kind: string }) => row.kind === "phone");

    const share = await request(app.getHttpServer())
      .post(`/v1/cards/${created.body.id}/shares`)
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .set("Idempotency-Key", "share-ada-1")
      .send({
        versionId: created.body.versionId,
        fieldIds: [name.id, email.id],
        pin: "2468",
        expiresInSeconds: 3600,
        recipientPhone: "+14155550100",
        sendSms: true,
      });
    expect(share.status).toBe(201);
    expect(share.body.sms).toBe("mock");
    expect(share.body.url).toContain("/s/");
    const token = String(share.body.url).split("/s/")[1];
    expect(token.length).toBeGreaterThan(20);

    const replay = await request(app.getHttpServer())
      .post(`/v1/cards/${created.body.id}/shares`)
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .set("Idempotency-Key", "share-ada-1")
      .send({
        versionId: created.body.versionId,
        fieldIds: [name.id, email.id],
        pin: "2468",
        expiresInSeconds: 3600,
        recipientPhone: "+14155550100",
        sendSms: true,
      });
    expect(replay.status).toBe(201);
    expect(replay.body.url).toBe(share.body.url);
    const listed = await request(app.getHttpServer())
      .get(`/v1/cards/${created.body.id}/shares`)
      .set("Authorization", `Bearer ${ada.accessToken}`);
    expect(listed.body.items).toHaveLength(1);

    const locked = await request(app.getHttpServer()).get(`/v1/public/shares/${token}`);
    expect(locked.status).toBe(200);
    expect(locked.body.pinRequired).toBe(true);
    expect(JSON.stringify(locked.body)).not.toContain(phone);
    expect(JSON.stringify(locked.body)).not.toContain("ada@analytical.example");

    const wrong = await request(app.getHttpServer())
      .get(`/v1/public/shares/${token}`)
      .set("x-share-pin", "0000");
    expect(wrong.status).toBe(401);
    expect(JSON.stringify(wrong.body)).not.toContain(phone);

    const opened = await request(app.getHttpServer())
      .get(`/v1/public/shares/${token}`)
      .set("x-share-pin", "2468");
    expect(opened.status).toBe(200);
    expect(JSON.stringify(opened.body)).toContain("ada@analytical.example");
    expect(JSON.stringify(opened.body)).not.toContain(phone);
    expect(opened.body.contacts.map((row: { kind: string }) => row.kind).sort()).toEqual([
      "email",
      "name",
    ]);

    const vcard = await request(app.getHttpServer())
      .get(`/v1/public/shares/${token}/vcard`)
      .set("x-share-pin", "2468")
      .buffer(true)
      .parse(binary);
    expect(vcard.status).toBe(200);
    expect(vcard.body.toString("utf8")).toContain("EMAIL:ada@analytical.example");
    expect(vcard.body.toString("utf8")).not.toContain(phone);
    expect(vcard.body.toString("utf8")).not.toContain("TEL:");

    const bea = await register(app, "bea-share@example.com");
    const denied = await request(app.getHttpServer())
      .get(`/v1/cards/${created.body.id}/shares`)
      .set("Authorization", `Bearer ${bea.accessToken}`);
    expect(denied.status).toBe(404);
    const refused = await request(app.getHttpServer())
      .post(`/v1/public/shares/${token}/claim`)
      .set("Authorization", `Bearer ${bea.accessToken}`)
      .send({});
    expect(refused.status).toBe(400);

    const claimed = await request(app.getHttpServer())
      .post(`/v1/public/shares/${token}/claim`)
      .set("Authorization", `Bearer ${bea.accessToken}`)
      .send({ consent: true, pin: "2468" });
    expect(claimed.status).toBe(201);

    const again = await request(app.getHttpServer())
      .post(`/v1/public/shares/${token}/claim`)
      .set("Authorization", `Bearer ${bea.accessToken}`)
      .send({ consent: true, pin: "2468" });
    expect(again.status).toBe(410);

    const wallet = await request(app.getHttpServer())
      .get("/v1/cards")
      .query({ filter: "received" })
      .set("Authorization", `Bearer ${bea.accessToken}`);
    expect(wallet.status).toBe(200);
    expect(JSON.stringify(wallet.body)).not.toContain(phone);
    expect(wallet.body.items[0].headline).toBe("Ada Lovelace");

    const copy = await request(app.getHttpServer())
      .get(`/v1/cards/${claimed.body.walletEntryId}`)
      .set("Authorization", `Bearer ${bea.accessToken}`);
    expect(copy.status).toBe(200);
    expect(copy.body.readOnly).toBe(true);
    expect(JSON.stringify(copy.body)).toContain("ada@analytical.example");
    expect(JSON.stringify(copy.body)).not.toContain(phone);
    expect(hidden.id).toEqual(expect.any(String));

    const second = await request(app.getHttpServer())
      .post(`/v1/cards/${created.body.id}/shares`)
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .send({
        versionId: created.body.versionId,
        fieldIds: [email.id],
        expiresInSeconds: 3600,
      });
    expect(second.status).toBe(201);
    const secondToken = String(second.body.url).split("/s/")[1];
    const revoked = await request(app.getHttpServer())
      .post(`/v1/shares/${second.body.id}/revoke`)
      .set("Authorization", `Bearer ${ada.accessToken}`);
    expect(revoked.status).toBe(200);
    const afterRevoke = await request(app.getHttpServer()).get(`/v1/public/shares/${secondToken}`);
    expect(afterRevoke.status).toBe(410);

    const third = await request(app.getHttpServer())
      .post(`/v1/cards/${created.body.id}/shares`)
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .send({
        versionId: created.body.versionId,
        fieldIds: [email.id],
        expiresInSeconds: 3600,
      });
    await prisma.cardShare.update({
      where: { id: third.body.id },
      data: { expiresAt: new Date(Date.now() - 1000) },
    });
    const thirdToken = String(third.body.url).split("/s/")[1];
    const expired = await request(app.getHttpServer()).get(`/v1/public/shares/${thirdToken}`);
    expect(expired.status).toBe(410);
  });
});
