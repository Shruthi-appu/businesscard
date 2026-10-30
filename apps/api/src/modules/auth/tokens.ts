import { createHash, createHmac, randomBytes } from "crypto";

import { SignJWT } from "jose";

export function newRefreshToken(): string {
  return randomBytes(32).toString("base64url");
}

export function hashRefreshToken(token: string, secret: string): string {
  return createHmac("sha256", secret).update(token).digest("hex");
}

export function hashUserAgent(userAgent: string): string {
  return createHash("sha256").update(userAgent).digest("hex");
}

export async function signAccessToken(input: {
  userId: string;
  email: string | null;
  role: "user" | "admin";
  issuer: string;
  secret: Uint8Array;
  ttlSeconds: number;
}): Promise<string> {
  return new SignJWT({ role: input.role, email: input.email })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(input.userId)
    .setIssuer(input.issuer)
    .setAudience("user")
    .setJti(randomBytes(16).toString("hex"))
    .setIssuedAt()
    .setExpirationTime(`${input.ttlSeconds}s`)
    .sign(input.secret);
}
