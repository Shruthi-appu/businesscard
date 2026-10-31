CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- CreateEnum
CREATE TYPE "card_type" AS ENUM ('scanned', 'created', 'manual');

-- CreateEnum
CREATE TYPE "card_status" AS ENUM ('draft', 'active', 'archived');

-- CreateEnum
CREATE TYPE "card_visibility" AS ENUM ('private', 'unlisted', 'public');

-- CreateEnum
CREATE TYPE "contact_kind" AS ENUM ('name', 'designation', 'company', 'phone', 'email', 'website');

-- CreateEnum
CREATE TYPE "whatsapp_state" AS ENUM ('unknown', 'yes', 'no');

-- CreateEnum
CREATE TYPE "field_source" AS ENUM ('ocr', 'user');

-- CreateEnum
CREATE TYPE "wallet_origin" AS ENUM ('owned', 'received');

-- CreateEnum
CREATE TYPE "wallet_source" AS ENUM ('scanned', 'created', 'received_qr', 'received_nearby', 'received_nfc', 'received_sms', 'received_link', 'received_email', 'manual');

-- CreateEnum
CREATE TYPE "reminder_status" AS ENUM ('scheduled', 'done', 'cancelled');

-- CreateEnum
CREATE TYPE "history_event_type" AS ENUM ('saved', 'exchanged', 'shared', 'note', 'reminder_set', 'exported');

-- CreateTable
CREATE TABLE "business_cards" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "owner_user_id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "card_type" "card_type" NOT NULL,
    "status" "card_status" NOT NULL DEFAULT 'active',
    "visibility" "card_visibility" NOT NULL DEFAULT 'private',
    "public_slug" TEXT,
    "active_version_id" UUID,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "business_cards_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "card_versions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "card_id" UUID NOT NULL,
    "version_number" INTEGER NOT NULL,
    "design_config" JSONB,
    "verified_at" TIMESTAMPTZ,
    "created_by_user_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "card_versions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "card_contacts" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "card_version_id" UUID NOT NULL,
    "kind" "contact_kind" NOT NULL,
    "label" TEXT,
    "value_raw" TEXT NOT NULL,
    "value_normalized" TEXT,
    "whatsapp_state" "whatsapp_state" NOT NULL DEFAULT 'unknown',
    "is_primary" BOOLEAN NOT NULL DEFAULT false,
    "is_public" BOOLEAN NOT NULL DEFAULT false,
    "confidence" DECIMAL(5,4),
    "source" "field_source" NOT NULL DEFAULT 'user',
    "verified_at" TIMESTAMPTZ,
    "ocr_span" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "card_contacts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "card_social_links" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "card_version_id" UUID NOT NULL,
    "platform" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "is_public" BOOLEAN NOT NULL DEFAULT false,
    "confidence" DECIMAL(5,4),
    "source" "field_source" NOT NULL DEFAULT 'user',
    "verified_at" TIMESTAMPTZ,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "card_social_links_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "card_addresses" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "card_version_id" UUID NOT NULL,
    "formatted_address" TEXT NOT NULL,
    "latitude" DECIMAL(9,6),
    "longitude" DECIMAL(9,6),
    "is_public" BOOLEAN NOT NULL DEFAULT false,
    "confidence" DECIMAL(5,4),
    "source" "field_source" NOT NULL DEFAULT 'user',
    "verified_at" TIMESTAMPTZ,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "card_addresses_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "card_tags" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "card_tags_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "wallet_entries" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "origin" "wallet_origin" NOT NULL,
    "card_id" UUID,
    "snapshot_id" UUID,
    "source" "wallet_source" NOT NULL,
    "exchange_session_id" UUID,
    "share_id" UUID,
    "is_favourite" BOOLEAN NOT NULL DEFAULT false,
    "saved_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deleted_at" TIMESTAMPTZ,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "wallet_entries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "card_tag_links" (
    "wallet_entry_id" UUID NOT NULL,
    "tag_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "card_tag_links_pkey" PRIMARY KEY ("wallet_entry_id","tag_id")
);

-- CreateTable
CREATE TABLE "contact_notes" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "wallet_entry_id" UUID NOT NULL,
    "body" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "contact_notes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "reminders" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "wallet_entry_id" UUID NOT NULL,
    "remind_at" TIMESTAMPTZ NOT NULL,
    "status" "reminder_status" NOT NULL DEFAULT 'scheduled',
    "note" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "reminders_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "networking_events" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "wallet_entry_id" UUID NOT NULL,
    "event_type" "history_event_type" NOT NULL,
    "occurred_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "metadata" JSONB NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "networking_events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "business_cards_public_slug_key" ON "business_cards"("public_slug");

-- CreateIndex
CREATE UNIQUE INDEX "business_cards_active_version_id_key" ON "business_cards"("active_version_id");

-- CreateIndex
CREATE INDEX "business_cards_owner_user_id_updated_at_idx" ON "business_cards"("owner_user_id", "updated_at");

-- CreateIndex
CREATE UNIQUE INDEX "card_versions_card_id_version_number_key" ON "card_versions"("card_id", "version_number");

-- CreateIndex
CREATE INDEX "card_contacts_value_normalized_idx" ON "card_contacts"("value_normalized");

-- CreateIndex
CREATE UNIQUE INDEX "card_tags_user_id_name_key" ON "card_tags"("user_id", "name");

-- CreateIndex
CREATE INDEX "wallet_entries_user_id_saved_at_idx" ON "wallet_entries"("user_id", "saved_at");

-- CreateIndex
CREATE INDEX "wallet_entries_user_id_is_favourite_idx" ON "wallet_entries"("user_id", "is_favourite");

-- CreateIndex
CREATE INDEX "contact_notes_wallet_entry_id_idx" ON "contact_notes"("wallet_entry_id");

-- CreateIndex
CREATE INDEX "reminders_status_remind_at_idx" ON "reminders"("status", "remind_at");

-- CreateIndex
CREATE INDEX "networking_events_wallet_entry_id_occurred_at_idx" ON "networking_events"("wallet_entry_id", "occurred_at");

-- AddForeignKey
ALTER TABLE "business_cards" ADD CONSTRAINT "business_cards_owner_user_id_fkey" FOREIGN KEY ("owner_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "business_cards" ADD CONSTRAINT "business_cards_active_version_id_fkey" FOREIGN KEY ("active_version_id") REFERENCES "card_versions"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "card_versions" ADD CONSTRAINT "card_versions_card_id_fkey" FOREIGN KEY ("card_id") REFERENCES "business_cards"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "card_contacts" ADD CONSTRAINT "card_contacts_card_version_id_fkey" FOREIGN KEY ("card_version_id") REFERENCES "card_versions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "card_social_links" ADD CONSTRAINT "card_social_links_card_version_id_fkey" FOREIGN KEY ("card_version_id") REFERENCES "card_versions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "card_addresses" ADD CONSTRAINT "card_addresses_card_version_id_fkey" FOREIGN KEY ("card_version_id") REFERENCES "card_versions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "card_tags" ADD CONSTRAINT "card_tags_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "wallet_entries" ADD CONSTRAINT "wallet_entries_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "wallet_entries" ADD CONSTRAINT "wallet_entries_card_id_fkey" FOREIGN KEY ("card_id") REFERENCES "business_cards"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "card_tag_links" ADD CONSTRAINT "card_tag_links_wallet_entry_id_fkey" FOREIGN KEY ("wallet_entry_id") REFERENCES "wallet_entries"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "card_tag_links" ADD CONSTRAINT "card_tag_links_tag_id_fkey" FOREIGN KEY ("tag_id") REFERENCES "card_tags"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "contact_notes" ADD CONSTRAINT "contact_notes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "contact_notes" ADD CONSTRAINT "contact_notes_wallet_entry_id_fkey" FOREIGN KEY ("wallet_entry_id") REFERENCES "wallet_entries"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reminders" ADD CONSTRAINT "reminders_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reminders" ADD CONSTRAINT "reminders_wallet_entry_id_fkey" FOREIGN KEY ("wallet_entry_id") REFERENCES "wallet_entries"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "networking_events" ADD CONSTRAINT "networking_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "networking_events" ADD CONSTRAINT "networking_events_wallet_entry_id_fkey" FOREIGN KEY ("wallet_entry_id") REFERENCES "wallet_entries"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- An owned entry points at a card. A received entry points at a snapshot. Exactly one.
ALTER TABLE "wallet_entries" ADD CONSTRAINT "wallet_entries_origin_target_chk" CHECK (
  (origin = 'owned' AND card_id IS NOT NULL AND snapshot_id IS NULL)
  OR
  (origin = 'received' AND card_id IS NULL AND snapshot_id IS NOT NULL)
);

CREATE INDEX "wallet_entries_user_saved_active_idx" ON "wallet_entries" ("user_id", "saved_at" DESC) WHERE "deleted_at" IS NULL;
CREATE INDEX "wallet_entries_user_favourite_idx" ON "wallet_entries" ("user_id") WHERE "is_favourite" AND "deleted_at" IS NULL;
CREATE INDEX "card_contacts_value_raw_trgm" ON "card_contacts" USING gin ("value_raw" gin_trgm_ops);
