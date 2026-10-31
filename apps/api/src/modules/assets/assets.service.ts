import { createHash, randomUUID } from "crypto";

import { Inject, Injectable } from "@nestjs/common";

import { ApiException } from "../../common/api.exception";
import { EnvService } from "../../config/env.service";
import { PrismaService } from "../../prisma/prisma.service";
import type { ObjectStorage } from "../../storage/object-storage";
import { OBJECT_STORAGE } from "../../storage/object-storage";

const MAX_BYTES = 20 * 1024 * 1024;

@Injectable()
export class AssetsService {
  constructor(
    @Inject(PrismaService) private readonly prisma: PrismaService,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorage,
    @Inject(EnvService) private readonly env: EnvService,
  ) {}

  async presign(
    userId: string,
    input: {
      purpose: "logo" | "avatar";
      mimeType: "image/jpeg" | "image/png";
      byteSize: number;
      checksumSha256: string;
    },
  ) {
    if (input.byteSize > MAX_BYTES) {
      throw new ApiException(400, "validation_error", "Validation failed", [
        { field: "byteSize", message: "Images must be 20 MB or smaller" },
      ]);
    }
    const assetId = randomUUID();
    const key = `${input.purpose}/${userId}/${assetId}`;
    await this.prisma.cardAsset.create({
      data: {
        id: assetId,
        ownerUserId: userId,
        s3Key: key,
        assetType: input.purpose,
        status: "pending",
        mimeType: input.mimeType,
        byteSize: input.byteSize,
        checksumSha256: input.checksumSha256,
      },
    });
    const uploadUrl =
      this.storage.kind === "mock"
        ? `${this.env.values.API_PUBLIC_ORIGIN}/v1/assets/${assetId}/bytes`
        : await this.storage.presignPut({
            key,
            contentType: input.mimeType,
            expiresInSeconds: 300,
          });
    return { assetId, uploadUrl, method: this.storage.kind === "mock" ? "POST" : "PUT" };
  }

  async storeBytes(userId: string, assetId: string, bodyBase64: string) {
    const asset = await this.owned(userId, assetId);
    if (asset.status !== "pending")
      throw new ApiException(409, "conflict", "This file is already stored");
    const body = Buffer.from(bodyBase64, "base64");
    await this.storage.putObject({ key: asset.s3Key, body, contentType: asset.mimeType });
    return { assetId };
  }

  async complete(userId: string, assetId: string) {
    const asset = await this.owned(userId, assetId);
    const body = await this.storage.getObject(asset.s3Key);
    if (!body) {
      throw new ApiException(400, "validation_error", "Validation failed", [
        { field: "assetId", message: "Upload the image before completing" },
      ]);
    }
    const checksum = createHash("sha256").update(body).digest("hex");
    if (checksum !== asset.checksumSha256 || body.byteLength !== asset.byteSize) {
      throw new ApiException(400, "validation_error", "Validation failed", [
        {
          field: "checksumSha256",
          message: "The uploaded file does not match the declared checksum",
        },
      ]);
    }
    await this.prisma.cardAsset.update({ where: { id: asset.id }, data: { status: "stored" } });
    if (asset.assetType === "avatar") {
      await this.prisma.userProfile.update({
        where: { userId },
        data: { avatarAssetId: asset.id },
      });
    }
    return { assetId, status: "stored" };
  }

  async url(userId: string, assetId: string) {
    const asset = await this.owned(userId, assetId);
    if (asset.status !== "stored") throw new ApiException(404, "not_found", "Asset was not found");
    const downloadUrl = await this.storage.presignGet({ key: asset.s3Key, expiresInSeconds: 60 });
    return { assetId, downloadUrl, expiresInSeconds: 60 };
  }

  private async owned(userId: string, assetId: string) {
    const asset = await this.prisma.cardAsset.findFirst({
      where: { id: assetId, ownerUserId: userId },
    });
    if (!asset) throw new ApiException(404, "not_found", "Asset was not found");
    return asset;
  }
}
