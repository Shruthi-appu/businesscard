import type { INestApplication } from "@nestjs/common";
import { SignJWT } from "jose";
import request from "supertest";

import { ApiException } from "../../src/common/api.exception";
import { createApp } from "../../src/app.factory";
import { EnvService } from "../../src/config/env.service";
import { IdempotencyService } from "../../src/modules/idempotency/idempotency.service";
import { PrismaService } from "../../src/prisma/prisma.service";
import { RedisService } from "../../src/redis/redis.service";

type AuthBody = {
  accessToken: string;
  refreshToken: string;
  user: { id: string; email: string; displayName: string; role: string };
};

async function register(
  app: INestApplication,
  email: string,
  displayName = "Ada Lovelace",
): Promise<request.Response> {
  return request(app.getHttpServer()).post("/v1/auth/register").send({
    email,
    password: "correct-horse",
    displayName,
    role: "admin",
  });
}

describe("phase 1 auth and empty wallet", () => {
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

  it("migrates the foundation tables", async () => {
    const rows = await prisma.$queryRaw<{ table_name: string }[]>`
      SELECT table_name FROM information_schema.tables
      WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
    `;
    const names = rows.map((row) => row.table_name);
    expect(names).toEqual(
      expect.arrayContaining([
        "users",
        "user_profiles",
        "refresh_tokens",
        "audit_logs",
        "idempotency_keys",
      ]),
    );
    const emailType = await prisma.$queryRaw<{ udt_name: string }[]>`
      SELECT udt_name FROM information_schema.columns
      WHERE table_name = 'users' AND column_name = 'email'
    `;
    expect(emailType[0]?.udt_name).toBe("citext");
  });

  it("registers, signs in, and opens an empty wallet", async () => {
    const created = await register(app, "Ada@Example.com");
    expect(created.status).toBe(201);
    expect(created.headers["content-type"]).toContain("application/json");
    const cookie = created.headers["set-cookie"];
    expect(String(cookie)).toContain("softxu_refresh=");
    expect(String(cookie).toLowerCase()).toContain("httponly");
    const body = created.body as AuthBody;
    expect(body.user.role).toBe("user");
    expect(body.user.email).toBe("ada@example.com");
    expect(body.user.displayName).toBe("Ada Lovelace");
    expect(body.accessToken.includes("correct-horse")).toBe(false);

    const stored = await prisma.user.findUnique({ where: { email: "ada@example.com" } });
    expect(stored?.passwordHash?.startsWith("$argon2id$")).toBe(true);
    expect(stored?.passwordHash).not.toContain("correct-horse");
    const tokens = await prisma.refreshToken.findMany();
    expect(tokens.some((token) => token.tokenHash === body.refreshToken)).toBe(false);

    const audits = await prisma.auditLog.findMany();
    expect(JSON.stringify(audits)).not.toContain("correct-horse");
    expect(audits.map((row) => row.action)).toContain("auth.register");

    const me = await request(app.getHttpServer())
      .get("/v1/me?userId=someone-else")
      .set("Authorization", `Bearer ${body.accessToken}`);
    expect(me.status).toBe(200);
    expect(me.body).toMatchObject({ id: body.user.id, email: "ada@example.com", role: "user" });

    const cards = await request(app.getHttpServer())
      .get("/v1/cards")
      .set("Authorization", `Bearer ${body.accessToken}`);
    expect(cards.status).toBe(200);
    expect(cards.body).toEqual({ items: [], nextCursor: null });

    const login = await request(app.getHttpServer())
      .post("/v1/auth/login")
      .send({ email: "ADA@example.com", password: "correct-horse" });
    expect(login.status).toBe(200);
    expect(login.body.user.id).toBe(body.user.id);
  });

  it("rejects duplicate email, bad input, and a wrong password", async () => {
    await register(app, "one@example.com");
    const duplicate = await register(app, "one@example.com", "Other");
    expect(duplicate.status).toBe(409);
    expect(duplicate.headers["content-type"]).toContain("application/problem+json");
    expect(duplicate.body.code).toBe("conflict");

    const invalid = await request(app.getHttpServer()).post("/v1/auth/register").send({
      email: "not-an-email",
      password: "short",
      displayName: "",
    });
    expect(invalid.status).toBe(400);
    expect(invalid.body.code).toBe("validation_error");
    expect(invalid.body.errors.length).toBeGreaterThan(0);

    const wrong = await request(app.getHttpServer())
      .post("/v1/auth/login")
      .send({ email: "one@example.com", password: "not-the-password" });
    expect(wrong.status).toBe(401);
    expect(wrong.body.code).toBe("unauthenticated");

    const missing = await request(app.getHttpServer())
      .post("/v1/auth/login")
      .send({ email: "missing@example.com", password: "correct-horse" });
    expect(missing.status).toBe(401);
    expect(missing.body.title).toBe(wrong.body.title);
  });

  it("rotates refresh tokens, detects reuse, and logs out", async () => {
    const created = await register(app, "refresh@example.com");
    const first = created.body as AuthBody;
    const rotated = await request(app.getHttpServer())
      .post("/v1/auth/refresh")
      .send({ refreshToken: first.refreshToken });
    expect(rotated.status).toBe(200);
    const second = rotated.body as AuthBody;
    expect(second.refreshToken).not.toBe(first.refreshToken);
    expect(second.accessToken).not.toBe(first.accessToken);

    const reused = await request(app.getHttpServer())
      .post("/v1/auth/refresh")
      .send({ refreshToken: first.refreshToken });
    expect(reused.status).toBe(401);

    const afterReuse = await request(app.getHttpServer())
      .post("/v1/auth/refresh")
      .send({ refreshToken: second.refreshToken });
    expect(afterReuse.status).toBe(401);

    const again = await register(app, "logout@example.com");
    const cookie = again.headers["set-cookie"];
    const loggedOut = await request(app.getHttpServer())
      .post("/v1/auth/logout")
      .set("Cookie", cookie);
    expect(loggedOut.status).toBe(204);
    const refreshed = await request(app.getHttpServer())
      .post("/v1/auth/refresh")
      .send({ refreshToken: (again.body as AuthBody).refreshToken });
    expect(refreshed.status).toBe(401);
  });

  it("rejects an expired refresh token", async () => {
    const created = await register(app, "expired@example.com");
    await prisma.refreshToken.updateMany({ data: { expiresAt: new Date(0) } });
    const refreshed = await request(app.getHttpServer())
      .post("/v1/auth/refresh")
      .send({ refreshToken: (created.body as AuthBody).refreshToken });
    expect(refreshed.status).toBe(401);
    expect(refreshed.body.code).toBe("expired");
  });

  it("does not let user B read user A", async () => {
    const userA = await register(app, "a@example.com", "User A");
    const userB = await register(app, "b@example.com", "User B");
    const me = await request(app.getHttpServer())
      .get("/v1/me")
      .set("Authorization", `Bearer ${(userB.body as AuthBody).accessToken}`);
    expect(me.status).toBe(200);
    expect(me.body.email).toBe("b@example.com");
    expect(me.body.id).toBe((userB.body as AuthBody).user.id);
    expect(JSON.stringify(me.body)).not.toContain("a@example.com");
    expect(JSON.stringify(me.body)).not.toContain((userA.body as AuthBody).user.id);

    const missingUser = await request(app.getHttpServer())
      .get(`/v1/users/${(userA.body as AuthBody).user.id}`)
      .set("Authorization", `Bearer ${(userB.body as AuthBody).accessToken}`);
    expect(missingUser.status).toBe(404);
    expect(missingUser.body.code).toBe("not_found");

    const cards = await request(app.getHttpServer())
      .get("/v1/cards")
      .set("Authorization", `Bearer ${(userB.body as AuthBody).accessToken}`);
    expect(cards.body).toEqual({ items: [], nextCursor: null });
  });

  it("rejects missing, worker, and disabled callers", async () => {
    const anonymous = await request(app.getHttpServer()).get("/v1/me");
    expect(anonymous.status).toBe(401);
    expect(anonymous.body.code).toBe("unauthenticated");

    const env = app.get(EnvService);
    const workerJwt = await new SignJWT({ role: "user" })
      .setProtectedHeader({ alg: "HS256" })
      .setSubject("00000000-0000-4000-8000-000000000099")
      .setIssuer(env.values.JWT_ISSUER)
      .setAudience("worker")
      .setExpirationTime("5m")
      .sign(env.accessKey);
    const worker = await request(app.getHttpServer())
      .get("/v1/me")
      .set("Authorization", `Bearer ${workerJwt}`);
    expect(worker.status).toBe(401);

    const serviceToken = await request(app.getHttpServer())
      .get("/v1/cards")
      .set("Authorization", `Bearer ${env.values.WORKER_AUTH_TOKEN}`);
    expect(serviceToken.status).toBe(401);

    const created = await register(app, "disabled@example.com");
    await prisma.user.update({
      where: { id: (created.body as AuthBody).user.id },
      data: { status: "disabled" },
    });
    const me = await request(app.getHttpServer())
      .get("/v1/me")
      .set("Authorization", `Bearer ${(created.body as AuthBody).accessToken}`);
    expect(me.status).toBe(403);
    expect(me.body.code).toBe("forbidden");
    const login = await request(app.getHttpServer())
      .post("/v1/auth/login")
      .send({ email: "disabled@example.com", password: "correct-horse" });
    expect(login.status).toBe(403);
  });

  it("returns 501 from unfinished modules and unconfigured OIDC", async () => {
    const created = await register(app, "skeleton@example.com");
    const token = (created.body as AuthBody).accessToken;
    const routes: Array<[string, string]> = [["patch", "/v1/me"]];
    for (const [method, path] of routes) {
      const agent = request(app.getHttpServer());
      const call =
        method === "post"
          ? agent.post(path)
          : method === "patch"
            ? agent.patch(path)
            : agent.get(path);
      const response = await call.set("Authorization", `Bearer ${token}`).send({});
      expect(response.status).toBe(501);
      expect(response.body.code).toBe("not_implemented");
    }
    const emptyAsset = await request(app.getHttpServer())
      .post("/v1/assets/presign")
      .set("Authorization", `Bearer ${token}`)
      .send({});
    expect(emptyAsset.status).toBe(400);
    expect(emptyAsset.body.code).toBe("validation_error");
    const emptyShare = await request(app.getHttpServer())
      .post("/v1/cards/00000000-0000-4000-8000-000000000001/shares")
      .set("Authorization", `Bearer ${token}`)
      .send({});
    expect(emptyShare.status).toBe(400);
    expect(emptyShare.body.code).toBe("validation_error");
    const emptyExchange = await request(app.getHttpServer())
      .post("/v1/exchange-sessions")
      .set("Authorization", `Bearer ${token}`)
      .send({});
    expect(emptyExchange.status).toBe(400);
    expect(emptyExchange.body.code).toBe("validation_error");
    const emptyCard = await request(app.getHttpServer())
      .post("/v1/cards")
      .set("Authorization", `Bearer ${token}`)
      .send({});
    expect(emptyCard.status).toBe(400);
    expect(emptyCard.body.code).toBe("validation_error");
    const missingCard = await request(app.getHttpServer())
      .get("/v1/cards/00000000-0000-4000-8000-000000000001")
      .set("Authorization", `Bearer ${token}`);
    expect(missingCard.status).toBe(404);
    expect(missingCard.body.code).toBe("not_found");
    const oidc = await request(app.getHttpServer()).get("/v1/auth/oidc/start");
    expect(oidc.status).toBe(501);
    expect(oidc.body.code).toBe("identity_provider_unconfigured");
    const callback = await request(app.getHttpServer()).get("/v1/auth/oidc/callback");
    expect(callback.body.code).toBe("identity_provider_unconfigured");
  });

  it("reports healthy mock storage and queue", async () => {
    const health = await request(app.getHttpServer()).get("/health");
    expect(health.status).toBe(200);
    expect(health.body).toMatchObject({
      status: "ok",
      checks: { database: "ok", redis: "ok", storage: "ok", queue: "ok" },
      storage: "mock",
      queue: "mock",
    });
    const docs = await request(app.getHttpServer()).get("/docs");
    expect(docs.status).toBe(200);
    expect(docs.headers["content-type"]).toContain("text/html");
    const spec = await request(app.getHttpServer()).get("/docs-json");
    expect(spec.body.paths["/v1/auth/register"]).toBeTruthy();
    expect(spec.body.paths["/v1/cards"]).toBeTruthy();
  });

  it("keeps idempotency keys unique per user", async () => {
    const created = await register(app, "idem@example.com");
    const userId = (created.body as AuthBody).user.id;
    const idempotency = app.get(IdempotencyService);
    await idempotency.remember({
      userId,
      key: "card-1",
      requestHash: "hash-a",
      responseStatus: 201,
      responseBody: { ok: true },
    });
    const same = await idempotency.remember({
      userId,
      key: "card-1",
      requestHash: "hash-a",
      responseStatus: 201,
      responseBody: { ok: true },
    });
    expect(same.responseStatus).toBe(201);
    try {
      await idempotency.remember({
        userId,
        key: "card-1",
        requestHash: "hash-b",
        responseStatus: 201,
        responseBody: { ok: false },
      });
      throw new Error("expected conflict");
    } catch (error) {
      expect(error).toBeInstanceOf(ApiException);
      expect((error as ApiException).getStatus()).toBe(409);
    }
  });

  it("answers unknown routes with a problem document", async () => {
    const response = await request(app.getHttpServer()).get("/v1/does-not-exist");
    expect(response.status).toBe(404);
    expect(response.body.code).toBe("not_found");
    expect(response.headers["content-type"]).toContain("application/problem+json");
    expect(response.headers["x-request-id"]).toBeTruthy();
  });
});
