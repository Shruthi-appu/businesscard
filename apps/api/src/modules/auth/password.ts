import { randomBytes } from "crypto";

import { argon2id, hash, verify, type HashOptions } from "argon2";

const options: HashOptions = {
  type: argon2id,
  memoryCost: 19456,
  timeCost: 2,
  parallelism: 1,
};

export async function hashPassword(password: string): Promise<string> {
  return hash(password, { ...options, raw: false });
}

export async function verifyPassword(password: string, passwordHash: string): Promise<boolean> {
  try {
    return await verify(passwordHash, password);
  } catch {
    return false;
  }
}

export function newPlaceholderSecret(): string {
  return randomBytes(32).toString("hex");
}
