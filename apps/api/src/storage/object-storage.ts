export type StoredObjectHead = {
  byteSize: number;
  checksumSha256: string | null;
};

export interface ObjectStorage {
  readonly kind: "mock" | "s3";
  health(): Promise<void>;
  putObject(input: { key: string; body: Buffer; contentType: string }): Promise<void>;
  headObject(key: string): Promise<StoredObjectHead | null>;
  presignPut(input: {
    key: string;
    contentType: string;
    expiresInSeconds: number;
  }): Promise<string>;
  presignGet(input: { key: string; expiresInSeconds: number }): Promise<string>;
}

export const OBJECT_STORAGE = Symbol("OBJECT_STORAGE");
