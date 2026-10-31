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

export const deleteAccountRequestSchema = z.object({
  confirm: z.literal(true),
});

const contactKindSchema = z.enum(["name", "designation", "company", "phone", "email", "website"]);

export const contactInputSchema = z.object({
  kind: contactKindSchema,
  label: z.string().trim().max(40).optional(),
  value: z.string().trim().min(1).max(300),
  isPublic: z.boolean().optional(),
  isPrimary: z.boolean().optional(),
  whatsappState: z.enum(["unknown", "yes", "no"]).optional(),
});

export const addressInputSchema = z.object({
  formattedAddress: z.string().trim().min(1).max(400),
  isPublic: z.boolean().optional(),
});

export const socialInputSchema = z.object({
  platform: z.string().trim().min(1).max(40),
  url: z.string().trim().min(1).max(500),
  isPublic: z.boolean().optional(),
});

export const createCardRequestSchema = z.object({
  title: z.string().trim().min(1).max(120),
  contacts: z.array(contactInputSchema).min(1).max(30),
  addresses: z.array(addressInputSchema).max(5).optional(),
  socials: z.array(socialInputSchema).max(10).optional(),
});

export const replaceVersionRequestSchema = z.object({
  contacts: z.array(contactInputSchema).min(1).max(30),
  addresses: z.array(addressInputSchema).max(5).optional(),
  socials: z.array(socialInputSchema).max(10).optional(),
});

export const patchCardRequestSchema = z.object({
  title: z.string().trim().min(1).max(120).optional(),
});

export const slugSchema = z
  .string()
  .trim()
  .toLowerCase()
  .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/)
  .min(3)
  .max(40);

export const createDigitalCardRequestSchema = z.object({
  title: z.string().trim().min(1).max(120),
  templateKey: z.string().trim().min(1).max(40),
  contacts: z.array(contactInputSchema).min(1).max(30),
});

export const designPatchRequestSchema = z.object({
  color: z
    .string()
    .trim()
    .regex(/^#[0-9a-fA-F]{6}$/),
  typeScale: z.enum(["sm", "md", "lg"]),
  logoAssetId: z.uuid().nullable().optional(),
  photoAssetId: z.uuid().nullable().optional(),
  frontHeadline: z.string().trim().max(80).optional(),
  frontSubline: z.string().trim().max(120).optional(),
  backNote: z.string().trim().max(400).optional(),
});

export const publishCardRequestSchema = z.object({
  slug: slugSchema,
  visibility: z.enum(["public", "unlisted"]),
});

export const exportCardRequestSchema = z.object({
  format: z.enum(["qr", "png", "pdf", "vcf"]),
});

export const createShareRequestSchema = z.object({
  versionId: z.uuid(),
  fieldIds: z.array(z.uuid()).min(1).max(40),
  expiresInSeconds: z
    .number()
    .int()
    .min(60)
    .max(60 * 60 * 24 * 30)
    .optional(),
  recipientPhone: z.string().trim().min(8).max(20).optional(),
  pin: z
    .string()
    .regex(/^\d{4,8}$/)
    .optional(),
  sendSms: z.boolean().optional(),
});

export const claimShareRequestSchema = z.object({
  consent: z.literal(true),
  pin: z
    .string()
    .regex(/^\d{4,8}$/)
    .optional(),
});

export const createExchangeRequestSchema = z.object({
  cardId: z.uuid(),
  mode: z.enum(["one_way", "mutual"]),
  method: z.enum(["qr", "ble", "nfc", "link"]),
  expiresInSeconds: z.number().int().min(30).max(600).optional(),
});

export const joinExchangeRequestSchema = z.object({
  code: z.string().trim().min(8).max(80),
});

export const consentExchangeRequestSchema = z.object({
  accept: z.boolean(),
  cardId: z.uuid().optional(),
});

export const cardListQuerySchema = z.object({
  q: z.string().trim().max(120).optional(),
  filter: z.enum(["all", "favourites", "manual", "created", "scanned", "received"]).optional(),
  cursor: z.string().max(200).optional(),
  limit: z.coerce.number().int().min(1).max(50).optional(),
});

export const cardListItemSchema = z.object({
  id: z.uuid(),
  walletEntryId: z.uuid(),
  title: z.string(),
  cardType: z.enum(["scanned", "created", "manual"]),
  source: z.string(),
  isFavourite: z.boolean(),
  headline: z.string().nullable(),
  company: z.string().nullable(),
  savedAt: z.string(),
});

export const cardListResponseSchema = z.object({
  items: z.array(cardListItemSchema),
  nextCursor: z.string().nullable(),
});

export const duplicateWarningSchema = z.object({
  cardId: z.uuid(),
  kind: z.enum(["phone", "email"]),
  valueNormalized: z.string(),
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
export type DeleteAccountRequest = z.infer<typeof deleteAccountRequestSchema>;
export type CardListResponse = z.infer<typeof cardListResponseSchema>;
export type CreateCardRequest = z.infer<typeof createCardRequestSchema>;
export type ReplaceVersionRequest = z.infer<typeof replaceVersionRequestSchema>;
export type PatchCardRequest = z.infer<typeof patchCardRequestSchema>;
export type CreateDigitalCardRequest = z.infer<typeof createDigitalCardRequestSchema>;
export type DesignPatchRequest = z.infer<typeof designPatchRequestSchema>;
export type PublishCardRequest = z.infer<typeof publishCardRequestSchema>;
export type ExportCardRequest = z.infer<typeof exportCardRequestSchema>;
export type CreateShareRequest = z.infer<typeof createShareRequestSchema>;
export type ClaimShareRequest = z.infer<typeof claimShareRequestSchema>;
export type CreateExchangeRequest = z.infer<typeof createExchangeRequestSchema>;
export type JoinExchangeRequest = z.infer<typeof joinExchangeRequestSchema>;
export type ConsentExchangeRequest = z.infer<typeof consentExchangeRequestSchema>;
export type ContactInput = z.infer<typeof contactInputSchema>;
export type AddressInput = z.infer<typeof addressInputSchema>;
export type SocialInput = z.infer<typeof socialInputSchema>;
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
