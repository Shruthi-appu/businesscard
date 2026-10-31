export const MOCK_OCR_TEXT = [
  "Ada Lovelace",
  "Analytical Engines",
  "ada@analytical.example",
  "+14155550100",
  "https://analytical.example",
].join("\n");

export const FAIL_SCAN_BODY = Buffer.from("fail-this-scan");

const THUMBNAIL_PNG_BASE64 =
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==";

export const THUMBNAIL_PNG = Buffer.from(THUMBNAIL_PNG_BASE64, "base64");

export type DraftKind = "name" | "designation" | "company" | "phone" | "email" | "website";

export type DraftContact = {
  kind: DraftKind;
  value: string | null;
  source: "ocr";
};

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function extractGrounded(rawText: string): DraftContact[] {
  const lines = rawText
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0);
  const grounded = (value: string | undefined): string | null => {
    if (!value) return null;
    return rawText.includes(value) ? value : null;
  };
  const used = new Set<string>();
  const take = (predicate: (line: string) => boolean): string | null => {
    const line = lines.find((candidate) => !used.has(candidate) && predicate(candidate));
    if (!line) return null;
    used.add(line);
    return grounded(line);
  };
  const email = take((line) => EMAIL.test(line));
  const phone = take((line) => /^\+[1-9]\d{7,14}$/.test(line.replace(/[\s()-]/g, "")));
  const website = take((line) => /^https?:\/\//i.test(line));
  const name = take(() => true);
  const company = take(() => true);
  return [
    { kind: "name", value: name, source: "ocr" },
    { kind: "company", value: company, source: "ocr" },
    { kind: "email", value: email, source: "ocr" },
    { kind: "phone", value: phone, source: "ocr" },
    { kind: "website", value: website, source: "ocr" },
  ];
}
