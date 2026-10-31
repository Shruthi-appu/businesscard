import { ApiException, type FieldError } from "../../common/api.exception";
import type { AddressInput, ContactInput, SocialInput } from "@softxu/contracts";

export type NormalizedContact = ContactInput & {
  valueRaw: string;
  valueNormalized: string | null;
};

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function normalizeContacts(contacts: ContactInput[]): NormalizedContact[] {
  const errors: FieldError[] = [];
  const normalized = contacts.map((contact, index) => {
    const valueRaw = contact.value.trim();
    let valueNormalized: string | null = null;
    if (contact.kind === "email") {
      const email = valueRaw.toLowerCase();
      if (!EMAIL.test(email)) {
        errors.push({ field: `contacts.${index}.value`, message: "Enter a valid email" });
      } else {
        valueNormalized = email;
      }
    } else if (contact.kind === "phone") {
      valueNormalized = normalizePhone(valueRaw);
    } else if (contact.kind === "website") {
      const url = normalizeUrl(valueRaw);
      if (!url) {
        errors.push({ field: `contacts.${index}.value`, message: "Enter an http or https URL" });
      } else {
        valueNormalized = url;
      }
    } else {
      valueNormalized = valueRaw.replace(/\s+/g, " ").toLowerCase();
    }
    return { ...contact, valueRaw, valueNormalized };
  });
  if (errors.length > 0) {
    throw new ApiException(400, "validation_error", "Validation failed", errors);
  }
  return normalized;
}

export function normalizePhone(value: string): string | null {
  const compact = value.replace(/[\s().-]/g, "");
  if (!/^\+[1-9]\d{7,14}$/.test(compact)) return null;
  return compact;
}

export function normalizeUrl(value: string): string | null {
  let parsed: URL;
  try {
    parsed = new URL(value);
  } catch {
    return null;
  }
  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") return null;
  if (parsed.username || parsed.password) return null;
  parsed.hash = "";
  parsed.hostname = parsed.hostname.toLowerCase();
  return parsed.toString();
}

export function normalizeSocials(socials: SocialInput[]): Array<SocialInput & { url: string }> {
  const errors: FieldError[] = [];
  const normalized = socials.map((social, index) => {
    const url = normalizeUrl(social.url);
    if (!url) {
      errors.push({ field: `socials.${index}.url`, message: "Enter an http or https URL" });
      return { ...social, url: social.url };
    }
    return { ...social, url };
  });
  if (errors.length > 0) {
    throw new ApiException(400, "validation_error", "Validation failed", errors);
  }
  return normalized;
}

export function normalizeAddresses(addresses: AddressInput[]): AddressInput[] {
  return addresses.map((address) => ({
    ...address,
    formattedAddress: address.formattedAddress.trim(),
  }));
}
