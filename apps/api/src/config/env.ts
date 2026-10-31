import { selectQueueMode, selectStorageMode, swaggerEnabled } from "@softxu/contracts";
import { z } from "zod";

const envSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  PORT: z.coerce.number().int().positive().default(3001),
  DATABASE_URL: z.string().min(1),
  REDIS_URL: z.string().min(1),
  JWT_ACCESS_SECRET: z.string().min(16),
  JWT_REFRESH_SECRET: z.string().min(16),
  JWT_ISSUER: z.string().min(1).default("softxu"),
  PUBLIC_WEB_ORIGIN: z.string().url(),
  API_PUBLIC_ORIGIN: z.string().url(),
  COOKIE_SECURE: z.enum(["true", "false"]).default("false"),
  ACCESS_TOKEN_TTL_SECONDS: z.coerce.number().int().positive().default(900),
  REFRESH_TOKEN_TTL_SECONDS: z.coerce
    .number()
    .int()
    .positive()
    .default(60 * 60 * 24 * 30),
  RATE_LIMIT_AUTH_MAX: z.coerce.number().int().positive().default(10),
  RATE_LIMIT_AUTH_WINDOW_SECONDS: z.coerce.number().int().positive().default(60),
  RATE_LIMIT_SHARE_MAX: z.coerce.number().int().positive().default(30),
  RATE_LIMIT_SHARE_WINDOW_SECONDS: z.coerce.number().int().positive().default(60),
  RATE_LIMIT_EXCHANGE_MAX: z.coerce.number().int().positive().default(30),
  RATE_LIMIT_EXCHANGE_WINDOW_SECONDS: z.coerce.number().int().positive().default(60),
  RATE_LIMIT_PRESIGN_MAX: z.coerce.number().int().positive().default(60),
  RATE_LIMIT_PRESIGN_WINDOW_SECONDS: z.coerce.number().int().positive().default(60),
  ACCOUNT_DELETION_GRACE_SECONDS: z.coerce
    .number()
    .int()
    .positive()
    .default(60 * 60 * 24 * 7),
  OTEL_EXPORTER_OTLP_ENDPOINT: z.string().default(""),
  OTEL_EXPORTER_OTLP_HEADERS: z.string().default(""),
  SMS_PROVIDER: z.string().default(""),
  SMS_API_KEY: z.string().default(""),
  SMS_FROM: z.string().default(""),
  S3_ENDPOINT: z.string().default(""),
  S3_REGION: z.string().default("us-east-1"),
  S3_BUCKET: z.string().default(""),
  S3_ACCESS_KEY_ID: z.string().default(""),
  S3_SECRET_ACCESS_KEY: z.string().default(""),
  S3_FORCE_PATH_STYLE: z.enum(["true", "false"]).default("true"),
  SQS_ENDPOINT: z.string().default(""),
  SQS_REGION: z.string().default("us-east-1"),
  SQS_ACCESS_KEY_ID: z.string().default(""),
  SQS_SECRET_ACCESS_KEY: z.string().default(""),
  SQS_IMAGE_QUEUE_URL: z.string().default(""),
  SQS_OCR_QUEUE_URL: z.string().default(""),
  SQS_EXPORT_QUEUE_URL: z.string().default(""),
  SQS_IMAGE_DLQ_URL: z.string().default(""),
  SQS_OCR_DLQ_URL: z.string().default(""),
  SQS_EXPORT_DLQ_URL: z.string().default(""),
  OIDC_ISSUER: z.string().default(""),
  OIDC_CLIENT_ID: z.string().default(""),
  OIDC_CLIENT_SECRET: z.string().default(""),
  OIDC_REDIRECT_URI: z.string().default(""),
  WORKER_AUTH_TOKEN: z.string().default(""),
});

export type AppEnv = z.infer<typeof envSchema> & {
  cookieSecure: boolean;
  oidcConfigured: boolean;
  storageMode: ReturnType<typeof selectStorageMode>;
  queueMode: ReturnType<typeof selectQueueMode>;
  swaggerEnabled: boolean;
};

let cached: AppEnv | undefined;

export function resetEnvCache(): void {
  cached = undefined;
}

export function loadEnv(source: NodeJS.ProcessEnv = process.env): AppEnv {
  if (cached) return cached;
  const parsed = envSchema.parse(source);
  const oidcConfigured = Boolean(
    parsed.OIDC_ISSUER.trim() &&
    parsed.OIDC_CLIENT_ID.trim() &&
    parsed.OIDC_CLIENT_SECRET.trim() &&
    parsed.OIDC_REDIRECT_URI.trim(),
  );
  cached = {
    ...parsed,
    cookieSecure: parsed.COOKIE_SECURE === "true",
    oidcConfigured,
    storageMode: selectStorageMode({
      accessKeyId: parsed.S3_ACCESS_KEY_ID,
      secretAccessKey: parsed.S3_SECRET_ACCESS_KEY,
      bucket: parsed.S3_BUCKET,
    }),
    queueMode: selectQueueMode({
      endpoint: parsed.SQS_ENDPOINT,
      imageQueueUrl: parsed.SQS_IMAGE_QUEUE_URL,
      ocrQueueUrl: parsed.SQS_OCR_QUEUE_URL,
      exportQueueUrl: parsed.SQS_EXPORT_QUEUE_URL,
    }),
    swaggerEnabled: swaggerEnabled(parsed.NODE_ENV),
  };
  return cached;
}
