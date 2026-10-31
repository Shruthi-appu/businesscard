-- AlterTable
ALTER TABLE "users" ADD COLUMN "deletion_scheduled_at" TIMESTAMPTZ,
ADD COLUMN "purged_at" TIMESTAMPTZ;

-- CreateEnum
CREATE TYPE "data_export_status" AS ENUM ('queued', 'ready', 'failed');

-- CreateTable
CREATE TABLE "data_exports" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "status" "data_export_status" NOT NULL DEFAULT 'queued',
    "storage_key" TEXT,
    "byte_size" INTEGER,
    "error_code" TEXT,
    "ready_at" TIMESTAMPTZ,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "data_exports_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "data_exports_user_id_created_at_idx" ON "data_exports"("user_id", "created_at");

-- AddForeignKey
ALTER TABLE "data_exports" ADD CONSTRAINT "data_exports_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
