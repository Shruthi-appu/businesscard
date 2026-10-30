import { createHash } from "crypto";

import type { ObjectStorage, StoredObjectHead } from "./object-storage";

type Stored = { body: Buffer; contentType: string; checksumSha256: string };

export class MockObjectStorage implements ObjectStorage {
  readonly kind = "mock" as const;
  private readonly objects = new Map<string, Stored>();

  async health(): Promise<void> {
    return;
  }

  async putObject(input: { key: string; body: Buffer; contentType: string }): Promise<void> {
    this.objects.set(input.key, {
      body: Buffer.from(input.body),
      contentType: input.contentType,
      checksumSha256: createHash("sha256").update(input.body).digest("hex"),
    });
  }

  async headObject(key: string): Promise<StoredObjectHead | null> {
    const stored = this.objects.get(key);
    if (!stored) return null;
    return { byteSize: stored.body.byteLength, checksumSha256: stored.checksumSha256 };
  }

  async presignPut(input: {
    key: string;
    contentType: string;
    expiresInSeconds: number;
  }): Promise<string> {
    return `memory://softxu/${encodeURIComponent(input.key)}?method=PUT&expires=${input.expiresInSeconds}&type=${encodeURIComponent(input.contentType)}`;
  }

  async presignGet(input: { key: string; expiresInSeconds: number }): Promise<string> {
    return `memory://softxu/${encodeURIComponent(input.key)}?method=GET&expires=${input.expiresInSeconds}`;
  }
}
