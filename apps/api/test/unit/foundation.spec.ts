import { createHmac } from "crypto";

import {
  cardListResponseSchema,
  loginRequestSchema,
  oidcUnavailableCode,
  registerRequestSchema,
  selectQueueMode,
  selectStorageMode,
  swaggerEnabled,
} from "@softxu/contracts";

import { ApiException } from "../../src/common/api.exception";
import { sanitizeAuditMetadata } from "../../src/modules/audit/audit.service";
import { hashPassword, verifyPassword } from "../../src/modules/auth/password";
import { normalizeContacts, normalizeUrl } from "../../src/modules/cards/normalize";
import { RateLimitService } from "../../src/modules/auth/rate-limit.service";
import { hashRefreshToken, newRefreshToken } from "../../src/modules/auth/tokens";
import { createJobQueue } from "../../src/queue/create-job-queue";
import { MockJobQueue } from "../../src/queue/mock-job-queue";
import type { AppEnv } from "../../src/config/env";
import { createObjectStorage } from "../../src/storage/create-object-storage";
import { MockObjectStorage } from "../../src/storage/mock-object-storage";
import { S3ObjectStorage } from "../../src/storage/s3-object-storage";

describe("contracts", () => {
  it("strips unknown keys and lowercases email", () => {
    const parsed = registerRequestSchema.parse({
      email: "Person@Example.com",
      password: "correct-horse",
      displayName: "  Ada  ",
      role: "admin",
    });
    expect(parsed).toEqual({
      email: "person@example.com",
      password: "correct-horse",
      displayName: "Ada",
    });
  });

  it("rejects a short password and a bad email", () => {
    expect(
      registerRequestSchema.safeParse({ email: "nope", password: "short", displayName: "A" })
        .success,
    ).toBe(false);
    expect(loginRequestSchema.safeParse({ email: "a@b.co", password: "" }).success).toBe(false);
  });

  it("accepts an empty wallet and a card list item", () => {
    expect(cardListResponseSchema.safeParse({ items: [], nextCursor: null }).success).toBe(true);
    expect(
      cardListResponseSchema.safeParse({
        items: [
          {
            id: "00000000-0000-4000-8000-000000000001",
            walletEntryId: "00000000-0000-4000-8000-000000000002",
            title: "Ada",
            cardType: "manual",
            source: "manual",
            isFavourite: false,
            headline: "Ada Lovelace",
            company: null,
            savedAt: "2026-10-31T00:00:00.000Z",
          },
        ],
        nextCursor: null,
      }).success,
    ).toBe(true);
  });

  it("selects mock adapters when credentials are empty", () => {
    expect(selectStorageMode({ accessKeyId: "", secretAccessKey: "x", bucket: "softxu" })).toBe(
      "mock",
    );
    expect(
      selectStorageMode({ accessKeyId: "key", secretAccessKey: "secret", bucket: "softxu" }),
    ).toBe("s3");
    expect(
      selectQueueMode({ endpoint: "", imageQueueUrl: "q", ocrQueueUrl: "q", exportQueueUrl: "q" }),
    ).toBe("mock");
    expect(
      selectQueueMode({
        endpoint: "http://localhost:9324",
        imageQueueUrl: "http://localhost/image",
        ocrQueueUrl: "http://localhost/ocr",
        exportQueueUrl: "http://localhost/export",
      }),
    ).toBe("sqs");
  });

  it("keeps Swagger off in production", () => {
    expect(swaggerEnabled("production")).toBe(false);
    expect(swaggerEnabled("development")).toBe(true);
    expect(swaggerEnabled("test")).toBe(true);
  });

  it("names the OIDC failure", () => {
    expect(oidcUnavailableCode(false)).toBe("identity_provider_unconfigured");
    expect(oidcUnavailableCode(true)).toBe("not_implemented");
  });
});

describe("manual card fields", () => {
  it("normalises email and rejects a script URL", () => {
    const contacts = normalizeContacts([
      { kind: "email", value: "Ada@Example.com" },
      { kind: "phone", value: "+1 (415) 555-0100" },
    ]);
    expect(contacts[0]?.valueNormalized).toBe("ada@example.com");
    expect(contacts[1]?.valueNormalized).toBe("+14155550100");
    expect(normalizeUrl("javascript:alert(1)")).toBeNull();
    expect(normalizeUrl("https://User:pass@Example.com/path")).toBeNull();
  });
});

describe("passwords and refresh tokens", () => {
  it("hashes passwords with argon2id", async () => {
    const hash = await hashPassword("correct-horse");
    expect(hash.startsWith("$argon2id$")).toBe(true);
    expect(hash).not.toContain("correct-horse");
    expect(await verifyPassword("correct-horse", hash)).toBe(true);
    expect(await verifyPassword("wrong-horse", hash)).toBe(false);
  });

  it("stores an HMAC of the refresh token", () => {
    const secret = "test-refresh-secret-value";
    const token = newRefreshToken();
    const hash = hashRefreshToken(token, secret);
    expect(hash).not.toBe(token);
    expect(hash).toBe(createHmac("sha256", secret).update(token).digest("hex"));
    expect(hashRefreshToken(newRefreshToken(), secret)).not.toBe(hash);
  });
});

describe("audit metadata", () => {
  it("drops secrets and non-scalar values", () => {
    expect(
      sanitizeAuditMetadata({
        method: "password",
        password: "correct-horse",
        refreshToken: "raw",
        nested: { secret: "no" },
        result: "success",
      }),
    ).toEqual({ method: "password", result: "success" });
  });
});

describe("rate limit", () => {
  function service(incr: () => Promise<number>): RateLimitService {
    return new RateLimitService({ incr } as unknown as RateLimitService["redis"]);
  }

  it("fails closed when the counter is unavailable", async () => {
    const limiter = service(async () => {
      throw new Error("redis down");
    });
    await expect(limiter.consume("register:1", 10, 60)).rejects.toBeInstanceOf(ApiException);
    try {
      await limiter.consume("register:1", 10, 60);
    } catch (error) {
      expect(error).toBeInstanceOf(ApiException);
      expect((error as ApiException).getStatus()).toBe(503);
      expect((error as ApiException).getResponse()).toMatchObject({ code: "service_unavailable" });
    }
  });

  it("rejects when the window is exhausted", async () => {
    const limiter = service(async () => 11);
    try {
      await limiter.consume("login:1", 10, 60);
      throw new Error("expected rate limit");
    } catch (error) {
      expect(error).toBeInstanceOf(ApiException);
      expect((error as ApiException).getStatus()).toBe(429);
    }
  });
});

describe("storage and queue adapters", () => {
  it("uses the mock storage and queue when selected", async () => {
    const storage = createObjectStorage({ storageMode: "mock" } as AppEnv);
    expect(storage).toBeInstanceOf(MockObjectStorage);
    await storage.putObject({
      key: "originals/u/a",
      body: Buffer.from("card"),
      contentType: "image/png",
    });
    const head = await storage.headObject("originals/u/a");
    expect(head?.byteSize).toBe(4);
    expect(head?.checksumSha256).toHaveLength(64);

    const queue = createJobQueue({ queueMode: "mock" } as AppEnv);
    expect(queue).toBeInstanceOf(MockJobQueue);
    await queue.send("image-processing", { jobId: "1" });
    expect((queue as MockJobQueue).messages).toHaveLength(1);
  });

  it("signs a local S3 URL without calling the network", async () => {
    const storage = new S3ObjectStorage({
      S3_BUCKET: "softxu",
      S3_REGION: "us-east-1",
      S3_ENDPOINT: "http://127.0.0.1:9",
      S3_FORCE_PATH_STYLE: "true",
      S3_ACCESS_KEY_ID: "local-test",
      S3_SECRET_ACCESS_KEY: "local-test-secret",
    } as AppEnv);
    const url = await storage.presignPut({
      key: "originals/user/asset",
      contentType: "image/jpeg",
      expiresInSeconds: 60,
    });
    expect(url).toContain("originals/user/asset");
    expect(url.startsWith("http://127.0.0.1:9/")).toBe(true);
  });
});
