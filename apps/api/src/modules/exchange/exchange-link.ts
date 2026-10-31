import { createHash, randomBytes } from "crypto";

import QRCode from "qrcode";

export const EXCHANGE_TTL_SECONDS = 180;

export const BLE_NFC_UNAVAILABLE = "That transport is not available in this build. Use QR.";

export function newExchangeCode(): string {
  return randomBytes(32).toString("base64url");
}

export function hashExchangeCode(code: string): string {
  return createHash("sha256").update(code).digest("hex");
}

export function exchangeUrl(origin: string, sessionId: string, code: string): string {
  const base = origin.replace(/\/$/, "");
  return `${base}/exchange/${sessionId}?c=${encodeURIComponent(code)}`;
}

export async function exchangeQrPng(url: string): Promise<Buffer> {
  return QRCode.toBuffer(url, {
    type: "png",
    width: 280,
    margin: 1,
    errorCorrectionLevel: "M",
  });
}
