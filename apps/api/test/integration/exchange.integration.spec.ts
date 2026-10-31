import type { INestApplication } from "@nestjs/common";
import request from "supertest";

import { createApp } from "../../src/app.factory";
import { PrismaService } from "../../src/prisma/prisma.service";
import { RedisService } from "../../src/redis/redis.service";

const phone = "+14155550197";

async function register(app: INestApplication, email: string, displayName: string) {
  const response = await request(app.getHttpServer()).post("/v1/auth/register").send({
    email,
    password: "correct-horse",
    displayName,
  });
  return response.body as { accessToken: string; user: { id: string } };
}

async function createCard(
  app: INestApplication,
  token: string,
  title: string,
  contacts: Array<{ kind: string; value: string }>,
) {
  const response = await request(app.getHttpServer())
    .post("/v1/cards")
    .set("Authorization", `Bearer ${token}`)
    .send({ title, contacts });
  expect(response.status).toBe(201);
  return response.body as { id: string };
}

function codeFrom(url: string): string {
  return new URL(url).searchParams.get("c") ?? "";
}

describe("phase 6 QR exchange", () => {
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

  it("copies a card one way only after the recipient accepts", async () => {
    const ada = await register(app, "ada-exchange@example.com", "Ada Lovelace");
    const grace = await register(app, "grace-exchange@example.com", "Grace Hopper");
    const card = await createCard(app, ada.accessToken, "Ada", [
      { kind: "name", value: "Ada Lovelace" },
      { kind: "phone", value: phone },
    ]);
    const opened = await request(app.getHttpServer())
      .post("/v1/exchange-sessions")
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .set("Idempotency-Key", "exchange-ada-1")
      .send({ cardId: card.id, mode: "one_way", method: "qr" });
    expect(opened.status).toBe(201);
    const code = codeFrom(opened.body.url as string);
    expect(opened.body.url).toContain(`/exchange/${opened.body.id}?c=`);
    expect(JSON.stringify(opened.body)).not.toContain(phone);
    const png = Buffer.from(opened.body.qrPngBase64 as string, "base64");
    expect(png.subarray(0, 4).toString("hex")).toBe("89504e47");
    expect(png.toString("latin1")).not.toContain(phone);
    const replay = await request(app.getHttpServer())
      .post("/v1/exchange-sessions")
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .set("Idempotency-Key", "exchange-ada-1")
      .send({ cardId: card.id, mode: "one_way", method: "qr" });
    expect(replay.body.url).toBe(opened.body.url);

    const hidden = await request(app.getHttpServer())
      .get(`/v1/exchange-sessions/${opened.body.id}`)
      .set("Authorization", `Bearer ${ada.accessToken}`);
    expect(hidden.status).toBe(200);
    expect(JSON.stringify(hidden.body)).not.toContain(code);
    expect(JSON.stringify(hidden.body)).not.toContain(phone);

    const stranger = await request(app.getHttpServer())
      .get(`/v1/exchange-sessions/${opened.body.id}`)
      .set("Authorization", `Bearer ${grace.accessToken}`);
    expect(stranger.status).toBe(404);

    const wrong = await request(app.getHttpServer())
      .post(`/v1/exchange-sessions/${opened.body.id}/join`)
      .set("Authorization", `Bearer ${grace.accessToken}`)
      .send({ code: "not-the-real-code" });
    expect(wrong.status).toBe(404);

    const self = await request(app.getHttpServer())
      .post(`/v1/exchange-sessions/${opened.body.id}/join`)
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .send({ code });
    expect(self.status).toBe(409);

    const joined = await request(app.getHttpServer())
      .post(`/v1/exchange-sessions/${opened.body.id}/join`)
      .set("Authorization", `Bearer ${grace.accessToken}`)
      .send({ code });
    expect(joined.status).toBe(200);
    expect(joined.body.peer.displayName).toBe("Ada Lovelace");
    expect(JSON.stringify(joined.body.peer.card)).toContain(phone);
    expect(JSON.stringify(joined.body)).not.toContain(code);

    const early = await request(app.getHttpServer())
      .post(`/v1/exchange-sessions/${opened.body.id}/complete`)
      .set("Authorization", `Bearer ${grace.accessToken}`)
      .set("Idempotency-Key", "exchange-complete-1");
    expect(early.status).toBe(409);
    expect(await prisma.cardSnapshot.count()).toBe(0);

    const accepted = await request(app.getHttpServer())
      .post(`/v1/exchange-sessions/${opened.body.id}/consent`)
      .set("Authorization", `Bearer ${grace.accessToken}`)
      .send({ accept: true });
    expect(accepted.status).toBe(200);
    expect(accepted.body.yourConsent).toBe("accepted");

    const done = await request(app.getHttpServer())
      .post(`/v1/exchange-sessions/${opened.body.id}/complete`)
      .set("Authorization", `Bearer ${grace.accessToken}`)
      .set("Idempotency-Key", "exchange-complete-1");
    expect(done.status).toBe(200);
    expect(done.body.receivedWalletEntryId).toEqual(expect.any(String));
    const again = await request(app.getHttpServer())
      .post(`/v1/exchange-sessions/${opened.body.id}/complete`)
      .set("Authorization", `Bearer ${grace.accessToken}`)
      .set("Idempotency-Key", "exchange-complete-1");
    expect(again.body.receivedWalletEntryId).toBe(done.body.receivedWalletEntryId);
    expect(await prisma.cardSnapshot.count()).toBe(1);
    const saved = await request(app.getHttpServer())
      .get(`/v1/cards/${done.body.receivedWalletEntryId}`)
      .set("Authorization", `Bearer ${grace.accessToken}`);
    expect(saved.status).toBe(200);
    expect(JSON.stringify(saved.body)).toContain(phone);
    expect(saved.body.readOnly).toBe(true);
    const adaReceived = await prisma.walletEntry.count({
      where: { userId: ada.user.id, origin: "received" },
    });
    expect(adaReceived).toBe(0);
    const audits = await prisma.auditLog.findMany({
      where: { action: { in: ["exchange.create", "exchange.complete"] } },
    });
    const auditText = JSON.stringify(audits);
    expect(auditText).not.toContain(phone);
    expect(auditText).not.toContain(code);
    expect(
      await prisma.networkingEvent.count({ where: { eventType: "exchanged" } }),
    ).toBeGreaterThan(0);

    const ida = await register(app, "ida-exchange@example.com", "Ida");
    const third = await request(app.getHttpServer())
      .post(`/v1/exchange-sessions/${opened.body.id}/join`)
      .set("Authorization", `Bearer ${ida.accessToken}`)
      .send({ code });
    expect(third.status).toBe(409);
    const outsider = await request(app.getHttpServer())
      .get(`/v1/exchange-sessions/${opened.body.id}`)
      .set("Authorization", `Bearer ${ida.accessToken}`);
    expect(outsider.status).toBe(404);
  });

  it("writes nothing when the recipient declines", async () => {
    const ada = await register(app, "ada-decline@example.com", "Ada Lovelace");
    const grace = await register(app, "grace-decline@example.com", "Grace Hopper");
    const card = await createCard(app, ada.accessToken, "Ada", [
      { kind: "email", value: "ada@analytical.example" },
    ]);
    const opened = await request(app.getHttpServer())
      .post("/v1/exchange-sessions")
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .send({ cardId: card.id, mode: "one_way", method: "link" });
    const code = codeFrom(opened.body.url as string);
    await request(app.getHttpServer())
      .post(`/v1/exchange-sessions/${opened.body.id}/join`)
      .set("Authorization", `Bearer ${grace.accessToken}`)
      .send({ code });
    const declined = await request(app.getHttpServer())
      .post(`/v1/exchange-sessions/${opened.body.id}/consent`)
      .set("Authorization", `Bearer ${grace.accessToken}`)
      .send({ accept: false });
    expect(declined.status).toBe(200);
    expect(declined.body.status).toBe("declined");
    expect(JSON.stringify(declined.body)).not.toContain("ada@analytical.example");
    const finished = await request(app.getHttpServer())
      .post(`/v1/exchange-sessions/${opened.body.id}/complete`)
      .set("Authorization", `Bearer ${grace.accessToken}`);
    expect(finished.status).toBe(409);
    expect(await prisma.cardSnapshot.count()).toBe(0);
  });

  it("waits for both consents before a mutual exchange", async () => {
    const ada = await register(app, "ada-mutual@example.com", "Ada Lovelace");
    const grace = await register(app, "grace-mutual@example.com", "Grace Hopper");
    const adaCard = await createCard(app, ada.accessToken, "Ada", [
      { kind: "phone", value: phone },
    ]);
    const graceCard = await createCard(app, grace.accessToken, "Grace", [
      { kind: "email", value: "grace@navy.example" },
    ]);
    const opened = await request(app.getHttpServer())
      .post("/v1/exchange-sessions")
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .send({ cardId: adaCard.id, mode: "mutual", method: "qr" });
    const code = codeFrom(opened.body.url as string);
    await request(app.getHttpServer())
      .post(`/v1/exchange-sessions/${opened.body.id}/join`)
      .set("Authorization", `Bearer ${grace.accessToken}`)
      .send({ code });
    const missingCard = await request(app.getHttpServer())
      .post(`/v1/exchange-sessions/${opened.body.id}/consent`)
      .set("Authorization", `Bearer ${grace.accessToken}`)
      .send({ accept: true });
    expect(missingCard.status).toBe(400);
    const early = await request(app.getHttpServer())
      .post(`/v1/exchange-sessions/${opened.body.id}/complete`)
      .set("Authorization", `Bearer ${ada.accessToken}`);
    expect(early.status).toBe(409);
    expect(await prisma.cardSnapshot.count()).toBe(0);
    const accepted = await request(app.getHttpServer())
      .post(`/v1/exchange-sessions/${opened.body.id}/consent`)
      .set("Authorization", `Bearer ${grace.accessToken}`)
      .send({ accept: true, cardId: graceCard.id });
    expect(accepted.status).toBe(200);
    const done = await request(app.getHttpServer())
      .post(`/v1/exchange-sessions/${opened.body.id}/complete`)
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .set("Idempotency-Key", "mutual-complete");
    expect(done.status).toBe(200);
    expect(done.body.receivedWalletEntryId).toEqual(expect.any(String));
    expect(await prisma.cardSnapshot.count()).toBe(2);
    const adaCopy = await request(app.getHttpServer())
      .get(`/v1/cards/${done.body.receivedWalletEntryId}`)
      .set("Authorization", `Bearer ${ada.accessToken}`);
    expect(JSON.stringify(adaCopy.body)).toContain("grace@navy.example");
    expect(JSON.stringify(adaCopy.body)).not.toContain(phone);
    const graceEntry = await prisma.walletEntry.findFirst({
      where: { userId: grace.user.id, origin: "received" },
    });
    const graceCopy = await request(app.getHttpServer())
      .get(`/v1/cards/${graceEntry?.id}`)
      .set("Authorization", `Bearer ${grace.accessToken}`);
    expect(JSON.stringify(graceCopy.body)).toContain(phone);
  });

  it("expires without writing a snapshot", async () => {
    const ada = await register(app, "ada-expire@example.com", "Ada Lovelace");
    const grace = await register(app, "grace-expire@example.com", "Grace Hopper");
    const card = await createCard(app, ada.accessToken, "Ada", [
      { kind: "email", value: "ada@analytical.example" },
    ]);
    const opened = await request(app.getHttpServer())
      .post("/v1/exchange-sessions")
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .send({ cardId: card.id, mode: "one_way", method: "qr", expiresInSeconds: 30 });
    await prisma.exchangeSession.update({
      where: { id: opened.body.id as string },
      data: { expiresAt: new Date(Date.now() - 1000) },
    });
    const joined = await request(app.getHttpServer())
      .post(`/v1/exchange-sessions/${opened.body.id}/join`)
      .set("Authorization", `Bearer ${grace.accessToken}`)
      .send({ code: codeFrom(opened.body.url as string) });
    expect(joined.status).toBe(410);
    expect(joined.body.code).toBe("expired");
    expect(await prisma.cardSnapshot.count()).toBe(0);
    expect(await prisma.exchangeParticipant.count({ where: { userId: grace.user.id } })).toBe(0);
  });

  it("rejects BLE and NFC in this build", async () => {
    const ada = await register(app, "ada-radio@example.com", "Ada Lovelace");
    const card = await createCard(app, ada.accessToken, "Ada", [
      { kind: "name", value: "Ada Lovelace" },
    ]);
    const ble = await request(app.getHttpServer())
      .post("/v1/exchange-sessions")
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .send({ cardId: card.id, mode: "one_way", method: "ble" });
    expect(ble.status).toBe(400);
    expect(ble.body.title).toContain("Use QR");
    expect(await prisma.exchangeSession.count()).toBe(0);
  });
});
