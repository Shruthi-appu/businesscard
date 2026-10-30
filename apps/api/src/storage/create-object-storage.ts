import type { AppEnv } from "../config/env";
import { MockObjectStorage } from "./mock-object-storage";
import type { ObjectStorage } from "./object-storage";
import { S3ObjectStorage } from "./s3-object-storage";

export function createObjectStorage(env: AppEnv): ObjectStorage {
  if (env.storageMode === "mock") return new MockObjectStorage();
  return new S3ObjectStorage(env);
}
