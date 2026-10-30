import {
  GetObjectCommand,
  HeadBucketCommand,
  HeadObjectCommand,
  PutObjectCommand,
  S3Client,
} from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { createHash } from "crypto";

import type { AppEnv } from "../config/env";
import type { ObjectStorage, StoredObjectHead } from "./object-storage";

export class S3ObjectStorage implements ObjectStorage {
  readonly kind = "s3" as const;
  private readonly client: S3Client;
  private readonly bucket: string;

  constructor(env: AppEnv) {
    this.bucket = env.S3_BUCKET;
    this.client = new S3Client({
      region: env.S3_REGION,
      endpoint: env.S3_ENDPOINT.trim() ? env.S3_ENDPOINT : undefined,
      forcePathStyle: env.S3_FORCE_PATH_STYLE === "true",
      credentials: {
        accessKeyId: env.S3_ACCESS_KEY_ID,
        secretAccessKey: env.S3_SECRET_ACCESS_KEY,
      },
    });
  }

  async health(): Promise<void> {
    await this.client.send(new HeadBucketCommand({ Bucket: this.bucket }));
  }

  async putObject(input: { key: string; body: Buffer; contentType: string }): Promise<void> {
    const checksum = createHash("sha256").update(input.body).digest("hex");
    await this.client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: input.key,
        Body: input.body,
        ContentType: input.contentType,
        Metadata: { checksumsha256: checksum },
      }),
    );
  }

  async headObject(key: string): Promise<StoredObjectHead | null> {
    try {
      const head = await this.client.send(new HeadObjectCommand({ Bucket: this.bucket, Key: key }));
      return {
        byteSize: head.ContentLength ?? 0,
        checksumSha256: head.Metadata?.checksumsha256 ?? null,
      };
    } catch (error) {
      if (isNotFound(error)) return null;
      throw error;
    }
  }

  async presignPut(input: {
    key: string;
    contentType: string;
    expiresInSeconds: number;
  }): Promise<string> {
    return getSignedUrl(
      this.client,
      new PutObjectCommand({ Bucket: this.bucket, Key: input.key, ContentType: input.contentType }),
      { expiresIn: input.expiresInSeconds },
    );
  }

  async presignGet(input: { key: string; expiresInSeconds: number }): Promise<string> {
    return getSignedUrl(
      this.client,
      new GetObjectCommand({ Bucket: this.bucket, Key: input.key }),
      {
        expiresIn: input.expiresInSeconds,
      },
    );
  }
}

function isNotFound(error: unknown): boolean {
  if (!error || typeof error !== "object") return false;
  const name = "name" in error ? String(error.name) : "";
  const status =
    "$metadata" in error
      ? (error.$metadata as { httpStatusCode?: number }).httpStatusCode
      : undefined;
  return name === "NotFound" || name === "NoSuchKey" || status === 404;
}
