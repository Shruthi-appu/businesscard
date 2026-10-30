import { z } from "zod";

const emailSchema = z.string().trim().toLowerCase().email();

export const registerRequestSchema = z.object({
  email: emailSchema,
  password: z.string().min(8).max(128),
  displayName: z
    .string()
    .trim()
    .min(1)
    .max(80)
    .refine(
      (value) => {
        for (const char of value) {
          const code = char.codePointAt(0) ?? 0;
          if (code <= 0x1f || code === 0x7f) return false;
        }
        return true;
      },
      {
        message: "Display name contains invalid characters",
      },
    ),
});

export const loginRequestSchema = z.object({
  email: emailSchema,
  password: z.string().min(1).max(128),
});

export const refreshRequestSchema = z.object({
  refreshToken: z.string().min(20).max(500).optional(),
});

export const authUserSchema = z.object({
  id: z.uuid(),
  email: z.string().nullable(),
  displayName: z.string(),
  role: z.enum(["user", "admin"]),
});

export const authResponseSchema = z.object({
  tokenType: z.literal("Bearer"),
  accessToken: z.string().min(1),
  expiresIn: z.number().int().positive(),
  refreshToken: z.string().min(1),
  user: authUserSchema,
});

export const meResponseSchema = z.object({
  id: z.uuid(),
  email: z.string().nullable(),
  phoneE164: z.string().nullable(),
  displayName: z.string(),
  locale: z.string().nullable(),
  countryCode: z.string().nullable(),
  role: z.enum(["user", "admin"]),
  status: z.enum(["active", "disabled", "pending_deletion"]),
});

/** Phase 1 always returns an empty list. Later phases widen `items`. */
export const cardListResponseSchema = z.object({
  items: z.array(z.object({ id: z.uuid() })).max(0),
  nextCursor: z.null(),
});

export const fieldErrorSchema = z.object({
  field: z.string(),
  message: z.string(),
});

export const problemSchema = z.object({
  type: z.string(),
  title: z.string(),
  status: z.number().int(),
  code: z.string(),
  requestId: z.string().optional(),
  errors: z.array(fieldErrorSchema).optional(),
});

export const healthResponseSchema = z.object({
  status: z.enum(["ok", "degraded"]),
  checks: z.object({
    database: z.enum(["ok", "error"]),
    redis: z.enum(["ok", "error"]),
    storage: z.enum(["ok", "error"]),
    queue: z.enum(["ok", "error"]),
  }),
  storage: z.enum(["mock", "s3"]),
  queue: z.enum(["mock", "sqs"]),
});

export type RegisterRequest = z.infer<typeof registerRequestSchema>;
export type LoginRequest = z.infer<typeof loginRequestSchema>;
export type RefreshRequest = z.infer<typeof refreshRequestSchema>;
export type AuthUser = z.infer<typeof authUserSchema>;
export type AuthResponse = z.infer<typeof authResponseSchema>;
export type MeResponse = z.infer<typeof meResponseSchema>;
export type CardListResponse = z.infer<typeof cardListResponseSchema>;
export type Problem = z.infer<typeof problemSchema>;
export type HealthResponse = z.infer<typeof healthResponseSchema>;

export function oidcUnavailableCode(
  configured: boolean,
): "identity_provider_unconfigured" | "not_implemented" {
  return configured ? "not_implemented" : "identity_provider_unconfigured";
}

export function selectStorageMode(input: {
  accessKeyId: string;
  secretAccessKey: string;
  bucket: string;
}): "mock" | "s3" {
  if (!input.accessKeyId.trim() || !input.secretAccessKey.trim() || !input.bucket.trim()) {
    return "mock";
  }
  return "s3";
}

export function selectQueueMode(input: {
  endpoint: string;
  imageQueueUrl: string;
  ocrQueueUrl: string;
  exportQueueUrl: string;
}): "mock" | "sqs" {
  if (
    !input.endpoint.trim() ||
    !input.imageQueueUrl.trim() ||
    !input.ocrQueueUrl.trim() ||
    !input.exportQueueUrl.trim()
  ) {
    return "mock";
  }
  return "sqs";
}

export function swaggerEnabled(nodeEnv: string): boolean {
  return nodeEnv !== "production";
}
