-- CreateEnum
CREATE TYPE "asset_type" AS ENUM ('original', 'enhanced', 'thumbnail', 'logo', 'avatar', 'export');

-- CreateEnum
CREATE TYPE "asset_status" AS ENUM ('pending', 'stored');

-- CreateEnum
CREATE TYPE "card_side_name" AS ENUM ('front', 'back');

-- CreateEnum
CREATE TYPE "ocr_job_status" AS ENUM ('queued', 'processing_image', 'processing_ocr', 'needs_review', 'completed', 'failed', 'cancelled');

-- CreateTable
CREATE TABLE "card_assets" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "owner_user_id" UUID NOT NULL,
    "s3_key" TEXT NOT NULL,
    "asset_type" "asset_type" NOT NULL,
    "status" "asset_status" NOT NULL DEFAULT 'pending',
    "mime_type" TEXT NOT NULL,
    "byte_size" INTEGER NOT NULL,
    "checksum_sha256" TEXT NOT NULL,
    "width" INTEGER,
    "height" INTEGER,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "card_assets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "card_sides" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "card_id" UUID NOT NULL,
    "side" "card_side_name" NOT NULL,
    "original_asset_id" UUID NOT NULL,
    "enhanced_asset_id" UUID,
    "thumbnail_asset_id" UUID,
    "crop_quad" JSONB,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "card_sides_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ocr_jobs" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "card_id" UUID NOT NULL,
    "owner_user_id" UUID NOT NULL,
    "status" "ocr_job_status" NOT NULL DEFAULT 'queued',
    "image_provider" TEXT NOT NULL DEFAULT 'mock-image-v1',
    "ocr_provider" TEXT NOT NULL DEFAULT 'mock-ocr-v1',
    "extractor_provider" TEXT NOT NULL DEFAULT 'grounded-v1',
    "attempt" INTEGER NOT NULL DEFAULT 0,
    "draft_version" INTEGER NOT NULL DEFAULT 1,
    "error_code" TEXT,
    "started_at" TIMESTAMPTZ,
    "completed_at" TIMESTAMPTZ,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "ocr_jobs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ocr_results" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "ocr_job_id" UUID NOT NULL,
    "side" "card_side_name" NOT NULL,
    "raw_text" TEXT NOT NULL,
    "blocks" JSONB NOT NULL,
    "structured_result" JSONB NOT NULL,
    "confidence" JSONB NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "ocr_results_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "card_assets_s3_key_key" ON "card_assets"("s3_key");

-- CreateIndex
CREATE INDEX "card_assets_owner_user_id_idx" ON "card_assets"("owner_user_id");

-- CreateIndex
CREATE UNIQUE INDEX "card_sides_card_id_side_key" ON "card_sides"("card_id", "side");

-- CreateIndex
CREATE INDEX "ocr_jobs_status_created_at_idx" ON "ocr_jobs"("status", "created_at");

-- CreateIndex
CREATE INDEX "ocr_jobs_owner_user_id_idx" ON "ocr_jobs"("owner_user_id");

-- CreateIndex
CREATE UNIQUE INDEX "ocr_results_ocr_job_id_side_key" ON "ocr_results"("ocr_job_id", "side");

-- AddForeignKey
ALTER TABLE "user_profiles" ADD CONSTRAINT "user_profiles_avatar_asset_id_fkey" FOREIGN KEY ("avatar_asset_id") REFERENCES "card_assets"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "card_assets" ADD CONSTRAINT "card_assets_owner_user_id_fkey" FOREIGN KEY ("owner_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "card_sides" ADD CONSTRAINT "card_sides_card_id_fkey" FOREIGN KEY ("card_id") REFERENCES "business_cards"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "card_sides" ADD CONSTRAINT "card_sides_original_asset_id_fkey" FOREIGN KEY ("original_asset_id") REFERENCES "card_assets"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "card_sides" ADD CONSTRAINT "card_sides_enhanced_asset_id_fkey" FOREIGN KEY ("enhanced_asset_id") REFERENCES "card_assets"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "card_sides" ADD CONSTRAINT "card_sides_thumbnail_asset_id_fkey" FOREIGN KEY ("thumbnail_asset_id") REFERENCES "card_assets"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ocr_jobs" ADD CONSTRAINT "ocr_jobs_card_id_fkey" FOREIGN KEY ("card_id") REFERENCES "business_cards"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ocr_jobs" ADD CONSTRAINT "ocr_jobs_owner_user_id_fkey" FOREIGN KEY ("owner_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ocr_results" ADD CONSTRAINT "ocr_results_ocr_job_id_fkey" FOREIGN KEY ("ocr_job_id") REFERENCES "ocr_jobs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

