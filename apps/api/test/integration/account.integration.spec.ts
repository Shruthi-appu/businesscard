import type { INestApplication } from "@nestjs/common";
import request from "supertest";

import { createApp } from "../../src/app.factory";
import { PrismaService } from "../../src/prisma/prisma.service";
import { JOB_QUEUE } from "../../src/queue/job-queue";
import { RedisService } from "../../src/redis/redis.service";

const PHONE = "+14155550195";
const NOTE = "Met at the exhibition";

type AuthBody = { accessToken: string; user: { id: string; email: string } };

async function register(app: INestApplication, email: string): Promise<AuthBody> {
  const response = await request(app.getHttpServer()).post("/v1/auth/register").send({
    email,
    password: "correct-horse",
    displayName: "Ada Lovelace",
  });
  expect(response.status).toBe(201);
  return response.body as AuthBody;
}

describe("phase 7 account lifecycle", () => {
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

  it("exports the caller's cards and hides secrets and other accounts", async () => {
    const ada = await register(app, "ada.phase7@example.com");
    const bob = await register(app, "bob.phase7@example.com");
    const created = await request(app.getHttpServer())
      .post("/v1/cards")
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .send({
        title: "Analytical Engine",
        contacts: [
          { kind: "name", value: "Ada Lovelace", isPrimary: true },
          { kind: "email", value: "ada.card@example.com" },
          { kind: "phone", value: PHONE },
        ],
        addresses: [{ formattedAddress: "12 Engine Court" }],
      });
    expect(created.status).toBe(201);
    const noted = await request(app.getHttpServer())
      .post(`/v1/wallet/entries/${created.body.walletEntryId}/notes`)
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .send({ body: NOTE });
    expect(noted.status).toBe(201);
    await request(app.getHttpServer())
      .post("/v1/cards")
      .set("Authorization", `Bearer ${bob.accessToken}`)
      .send({
        title: "Bob Secret Title",
        contacts: [{ kind: "email", value: "bob.secret@example.com" }],
      });

    const exported = await request(app.getHttpServer())
      .post("/v1/me/export")
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .set("Idempotency-Key", "export-ada-1");
    expect(exported.status).toBe(200);
    expect(exported.body).toMatchObject({ id: expect.any(String), status: "ready" });
    const replay = await request(app.getHttpServer())
      .post("/v1/me/export")
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .set("Idempotency-Key", "export-ada-1");
    expect(replay.status).toBe(200);
    expect(replay.body.id).toBe(exported.body.id);

    const file = await request(app.getHttpServer())
      .get(`/v1/me/exports/${exported.body.id}/file`)
      .set("Authorization", `Bearer ${ada.accessToken}`);
    expect(file.status).toBe(200);
    expect(file.headers["content-type"]).toContain("application/json");
    expect(file.headers["content-disposition"]).toContain("attachment");
    const text = file.text;
    expect(text).toContain(PHONE);
    expect(text).toContain("ada.card@example.com");
    expect(text).toContain(NOTE);
    expect(text).toContain("12 Engine Court");
    expect(text).not.toContain("passwordHash");
    expect(text).not.toContain("argon2");
    expect(text).not.toContain("correct-horse");
    expect(text).not.toContain("Bob Secret Title");
    expect(text).not.toContain("bob.secret@example.com");

    const stolen = await request(app.getHttpServer())
      .get(`/v1/me/exports/${exported.body.id}/file`)
      .set("Authorization", `Bearer ${bob.accessToken}`);
    expect(stolen.status).toBe(404);

    const audits = await prisma.auditLog.findMany({ where: { action: "account.export" } });
    expect(JSON.stringify(audits)).not.toContain(PHONE);
    expect(JSON.stringify(audits)).not.toContain(NOTE);
    const queue = app.get(JOB_QUEUE) as {
      messages: Array<{ queue: string; body: { kind?: string; exportId?: string } }>;
    };
    expect(
      queue.messages.some(
        (message) =>
          message.queue === "export" &&
          message.body.kind === "account_export" &&
          message.body.exportId === exported.body.id,
      ),
    ).toBe(true);
  });

  it("schedules deletion, blocks sign-in, and scrubs after the grace time", async () => {
    const ada = await register(app, "ada.delete@example.com");
    const bob = await register(app, "bob.keep@example.com");
    const created = await request(app.getHttpServer())
      .post("/v1/cards")
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .send({
        title: "Analytical Engine",
        contacts: [{ kind: "phone", value: PHONE, isPrimary: true }],
      });
    expect(created.status).toBe(201);
    const versionId = created.body.versionId as string;
    const snapshot = await prisma.cardSnapshot.create({
      data: {
        sourceCardId: created.body.id,
        sourceVersionId: versionId,
        ownerUserId: bob.user.id,
        payload: {
          title: "Analytical Engine",
          contacts: [{ kind: "phone", value: PHONE }],
          addresses: [],
          socials: [],
        },
      },
    });

    const empty = await request(app.getHttpServer())
      .post("/v1/me/delete")
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .send({});
    expect(empty.status).toBe(400);
    expect(empty.body.code).toBe("validation_error");

    const scheduled = await request(app.getHttpServer())
      .post("/v1/me/delete")
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .set("Idempotency-Key", "delete-ada-1")
      .send({ confirm: true });
    expect(scheduled.status).toBe(200);
    expect(scheduled.body.status).toBe("pending_deletion");
    expect(scheduled.body.graceSeconds).toBeGreaterThan(0);

    const again = await request(app.getHttpServer())
      .post("/v1/me/delete")
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .send({ confirm: true });
    expect(again.status).toBe(403);

    const login = await request(app.getHttpServer())
      .post("/v1/auth/login")
      .send({ email: "ada.delete@example.com", password: "correct-horse" });
    expect(login.status).toBe(403);

    const stillThere = await prisma.cardContact.count({
      where: { version: { card: { ownerUserId: ada.user.id } } },
    });
    expect(stillThere).toBeGreaterThan(0);

    await prisma.user.update({
      where: { id: ada.user.id },
      data: { deletionScheduledAt: new Date(Date.now() - 60_000) },
    });
    const admin = await register(app, "admin.phase7@example.com");
    await prisma.user.update({ where: { id: admin.user.id }, data: { role: "admin" } });
    const jobs = await request(app.getHttpServer())
      .get("/v1/admin/jobs")
      .set("Authorization", `Bearer ${admin.accessToken}`);
    expect(jobs.status).toBe(200);
    expect(jobs.body.pendingDeletion).toEqual(expect.any(Number));
    expect(jobs.body.ocr).toEqual(expect.any(Object));
    expect(jobs.body.exports).toEqual(expect.any(Object));
    expect(JSON.stringify(jobs.body)).not.toContain(PHONE);
    expect(JSON.stringify(jobs.body)).not.toContain("ada.delete@example.com");

    const purged = await prisma.user.findUnique({ where: { id: ada.user.id } });
    expect(purged?.email).toBeNull();
    expect(purged?.status).toBe("disabled");
    expect(purged?.purgedAt).not.toBeNull();
    expect(purged?.passwordHash).toBeNull();
    const contacts = await prisma.cardContact.count({
      where: { version: { card: { ownerUserId: ada.user.id } } },
    });
    expect(contacts).toBe(0);
    const card = await prisma.businessCard.findUnique({ where: { id: created.body.id } });
    expect(card?.title).toBe("Deleted card");
    expect(card?.publicSlug).toBeNull();
    const kept = await prisma.cardSnapshot.findUnique({ where: { id: snapshot.id } });
    expect(JSON.stringify(kept?.payload)).toContain(PHONE);
    const audits = await prisma.auditLog.findMany({
      where: { action: { in: ["account.delete.schedule", "account.delete.purge"] } },
    });
    expect(audits.map((row) => row.action)).toEqual(
      expect.arrayContaining(["account.delete.schedule", "account.delete.purge"]),
    );
    expect(JSON.stringify(audits)).not.toContain(PHONE);
    expect(JSON.stringify(audits)).not.toContain("correct-horse");
  });

  it("rejects admin job counts for a normal account and still presigns an upload", async () => {
    const ada = await register(app, "ada.jobs@example.com");
    const denied = await request(app.getHttpServer())
      .get("/v1/admin/jobs")
      .set("Authorization", `Bearer ${ada.accessToken}`);
    expect(denied.status).toBe(403);
    expect(denied.body.code).toBe("forbidden");

    const presign = await request(app.getHttpServer())
      .post("/v1/assets/presign")
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .send({
        purpose: "logo",
        mimeType: "image/png",
        byteSize: 32,
        checksumSha256: "ab".repeat(32),
      });
    expect(presign.status).toBe(201);
    expect(presign.body.uploadUrl).toEqual(expect.any(String));
  });
});
