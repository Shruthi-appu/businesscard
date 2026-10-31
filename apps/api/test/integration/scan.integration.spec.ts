import { createHash } from "crypto";

import type { INestApplication } from "@nestjs/common";
import request from "supertest";

import { createApp } from "../../src/app.factory";
import { FAIL_SCAN_BODY } from "../../src/modules/scans/extract";
import { PrismaService } from "../../src/prisma/prisma.service";
import { RedisService } from "../../src/redis/redis.service";
import { OBJECT_STORAGE, type ObjectStorage } from "../../src/storage/object-storage";

async function register(app: INestApplication, email: string) {
  const response = await request(app.getHttpServer()).post("/v1/auth/register").send({
    email,
    password: "correct-horse",
    displayName: "Ada Lovelace",
  });
  return response.body as { accessToken: string; user: { id: string } };
}

async function uploadSide(
  app: INestApplication,
  token: string,
  scanId: string,
  side: "front" | "back",
  body: Buffer,
) {
  const checksumSha256 = createHash("sha256").update(body).digest("hex");
  const upload = await request(app.getHttpServer())
    .post(`/v1/scans/${scanId}/upload-url`)
    .set("Authorization", `Bearer ${token}`)
    .send({ side, mimeType: "image/jpeg", byteSize: body.byteLength, checksumSha256 });
  expect(upload.status).toBe(201);
  const stored = await request(app.getHttpServer())
    .post(`/v1/scans/${scanId}/objects/${upload.body.assetId}`)
    .set("Authorization", `Bearer ${token}`)
    .send({ bodyBase64: body.toString("base64") });
  expect(stored.status).toBe(201);
  const completed = await request(app.getHttpServer())
    .post(`/v1/scans/${scanId}/complete`)
    .set("Authorization", `Bearer ${token}`)
    .send({ assetId: upload.body.assetId, side });
  return { upload, completed, checksumSha256 };
}

describe("phase 3 scan pipeline", () => {
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

  it("reviews a fixture card and leaves the original bytes unchanged", async () => {
    const ada = await register(app, "ada-scan@example.com");
    const image = Buffer.from("fixture-card-image");
    const created = await request(app.getHttpServer())
      .post("/v1/scans")
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .set("Idempotency-Key", "scan-ada-1")
      .send({});
    expect(created.status).toBe(201);
    const front = await uploadSide(app, ada.accessToken, created.body.id, "front", image);
    expect(front.completed.body.status).toBe("queued");
    const back = await uploadSide(app, ada.accessToken, created.body.id, "back", image);
    expect(back.completed.body.status).toBe("needs_review");
    expect(
      back.completed.body.draft.find((row: { kind: string }) => row.kind === "email").value,
    ).toBe("ada@analytical.example");

    const storage = app.get<ObjectStorage>(OBJECT_STORAGE);
    const original = await prisma.cardAsset.findFirstOrThrow({
      where: { id: front.upload.body.assetId },
    });
    const bytes = await storage.getObject(original.s3Key);
    expect(
      createHash("sha256")
        .update(bytes ?? Buffer.alloc(0))
        .digest("hex"),
    ).toBe(front.checksumSha256);
    expect(bytes?.equals(image)).toBe(true);

    const saved = await request(app.getHttpServer())
      .post(`/v1/scans/${created.body.id}/confirm`)
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .send({
        version: back.completed.body.draftVersion,
        contacts: [
          { kind: "name", value: "Ada Lovelace", isPrimary: true },
          { kind: "email", value: "ada@analytical.example" },
        ],
      });
    expect(saved.status).toBe(201);
    const wallet = await request(app.getHttpServer())
      .get("/v1/cards?filter=scanned")
      .set("Authorization", `Bearer ${ada.accessToken}`);
    expect(wallet.body.items).toHaveLength(1);

    const other = await register(app, "bea-scan@example.com");
    const hidden = await request(app.getHttpServer())
      .get(`/v1/scans/${created.body.id}`)
      .set("Authorization", `Bearer ${other.accessToken}`);
    expect(hidden.status).toBe(404);
  });

  it("dead-letters a scan after three failures", async () => {
    const ada = await register(app, "ada-fail@example.com");
    const created = await request(app.getHttpServer())
      .post("/v1/scans")
      .set("Authorization", `Bearer ${ada.accessToken}`)
      .send({});
    await uploadSide(app, ada.accessToken, created.body.id, "front", FAIL_SCAN_BODY);
    const failed = await uploadSide(app, ada.accessToken, created.body.id, "back", FAIL_SCAN_BODY);
    expect(failed.completed.body.status).toBe("failed");
    expect(failed.completed.body.errorCode).toBe("ocr_failed");
    const second = await request(app.getHttpServer())
      .post(`/v1/scans/${created.body.id}/retry`)
      .set("Authorization", `Bearer ${ada.accessToken}`);
    expect(second.body.errorCode).toBe("ocr_failed");
    const third = await request(app.getHttpServer())
      .post(`/v1/scans/${created.body.id}/retry`)
      .set("Authorization", `Bearer ${ada.accessToken}`);
    expect(third.body.status).toBe("failed");
    expect(third.body.errorCode).toBe("dlq");
    const again = await request(app.getHttpServer())
      .post(`/v1/scans/${created.body.id}/retry`)
      .set("Authorization", `Bearer ${ada.accessToken}`);
    expect(again.status).toBe(409);
  });
});
