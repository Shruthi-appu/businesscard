import type { INestApplication } from "@nestjs/common";
import request from "supertest";

import { createApp } from "../../src/app.factory";
import { PrismaService } from "../../src/prisma/prisma.service";
import { RedisService } from "../../src/redis/redis.service";

async function register(app: INestApplication, email: string) {
  const response = await request(app.getHttpServer()).post("/v1/auth/register").send({
    email,
    password: "correct-horse",
    displayName: "Ada Lovelace",
  });
  return response.body as { accessToken: string; user: { id: string } };
}

describe("phase 2 manual wallet", () => {
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

  it("creates, searches, and hides another user's card", async () => {
    const ada = await register(app, "ada-wallet@example.com");
    const created = await request(app.getHttpServer())
      .post("/v1/cards")
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .set("Idempotency-Key", "card-ada-1")
      .send({
        title: "Analytical Engine",
        contacts: [
          { kind: "name", value: "Ada Lovelace", isPrimary: true },
          { kind: "email", value: "ada@analytical.example" },
          { kind: "phone", value: "+14155550100", whatsappState: "yes" },
          { kind: "company", value: "Analytical Engines" },
        ],
      });
    expect(created.status).toBe(201);
    expect(created.body.duplicateWarnings).toEqual([]);
    expect(
      created.body.contacts.find((row: { kind: string }) => row.kind === "email").valueNormalized,
    ).toBe("ada@analytical.example");

    const replay = await request(app.getHttpServer())
      .post("/v1/cards")
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .set("Idempotency-Key", "card-ada-1")
      .send({
        title: "Analytical Engine",
        contacts: [
          { kind: "name", value: "Ada Lovelace", isPrimary: true },
          { kind: "email", value: "ada@analytical.example" },
          { kind: "phone", value: "+14155550100", whatsappState: "yes" },
          { kind: "company", value: "Analytical Engines" },
        ],
      });
    expect(replay.status).toBe(201);
    expect(replay.body.id).toBe(created.body.id);

    const duplicate = await request(app.getHttpServer())
      .post("/v1/cards")
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .send({
        title: "Second copy",
        contacts: [{ kind: "email", value: "ADA@analytical.example" }],
      });
    expect(duplicate.status).toBe(201);
    expect(duplicate.body.duplicateWarnings).toEqual([
      {
        cardId: created.body.id,
        kind: "email",
        valueNormalized: "ada@analytical.example",
      },
    ]);

    const search = await request(app.getHttpServer())
      .get("/v1/cards")
      .query({ q: "analytical", filter: "manual" })
      .set("Authorization", `Bearer ${ada.accessToken}`);
    expect(search.status).toBe(200);
    expect(search.body.items.map((item: { title: string }) => item.title)).toEqual(
      expect.arrayContaining(["Analytical Engine", "Second copy"]),
    );

    const favourite = await request(app.getHttpServer())
      .post(`/v1/wallet/entries/${created.body.walletEntryId}/favourite`)
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .send({ isFavourite: true });
    expect(favourite.status).toBe(200);
    const favourites = await request(app.getHttpServer())
      .get("/v1/cards")
      .query({ filter: "favourites" })
      .set("Authorization", `Bearer ${ada.accessToken}`);
    expect(favourites.body.items).toHaveLength(1);

    const tag = await request(app.getHttpServer())
      .post(`/v1/wallet/entries/${created.body.walletEntryId}/tags`)
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .send({ name: "conference" });
    expect(tag.status).toBe(201);
    const tagged = await request(app.getHttpServer())
      .get("/v1/cards")
      .query({ q: "conference" })
      .set("Authorization", `Bearer ${ada.accessToken}`);
    expect(tagged.body.items.map((item: { id: string }) => item.id)).toContain(created.body.id);

    const grace = await register(app, "grace-wallet@example.com");
    const denied = await request(app.getHttpServer())
      .get(`/v1/cards/${created.body.id}`)
      .set("Authorization", `Bearer ${grace.accessToken}`);
    expect(denied.status).toBe(404);
    expect(denied.body.code).toBe("not_found");

    const invalid = await request(app.getHttpServer())
      .post("/v1/cards")
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .send({
        title: "Bad",
        contacts: [{ kind: "website", value: "javascript:alert(1)" }],
      });
    expect(invalid.status).toBe(400);
    expect(invalid.body.code).toBe("validation_error");
  });
});
