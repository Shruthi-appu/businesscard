import { resetEnvCache } from "../src/config/env";

process.env.NODE_ENV = "test";
process.env.JWT_ISSUER ??= "softxu-test";
process.env.PUBLIC_WEB_ORIGIN ??= "http://localhost:3000";
process.env.API_PUBLIC_ORIGIN ??= "http://localhost:3001";
process.env.COOKIE_SECURE ??= "false";
process.env.RATE_LIMIT_AUTH_MAX ??= "10000";
process.env.RATE_LIMIT_AUTH_WINDOW_SECONDS ??= "60";
process.env.RATE_LIMIT_SHARE_MAX ??= "10000";
process.env.RATE_LIMIT_SHARE_WINDOW_SECONDS ??= "60";
process.env.SMS_PROVIDER ??= "mock";
process.env.SMS_API_KEY ??= "";
process.env.S3_ACCESS_KEY_ID ??= "";
process.env.S3_SECRET_ACCESS_KEY ??= "";
process.env.S3_BUCKET ??= "";
process.env.SQS_ENDPOINT ??= "";
process.env.WORKER_AUTH_TOKEN ??= "phase1-test-worker-token";

function required(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} is required for integration tests. Do not commit credentials.`);
  }
  return value;
}

const databaseUrl = required("DATABASE_URL");
if (!databaseUrl.includes("test")) {
  throw new Error("DATABASE_URL must point at a test database");
}
const redisUrl = required("REDIS_URL");
if (!redisUrl.endsWith("/1")) {
  throw new Error("REDIS_URL for tests must use database index 1");
}
required("JWT_ACCESS_SECRET");
required("JWT_REFRESH_SECRET");
resetEnvCache();
