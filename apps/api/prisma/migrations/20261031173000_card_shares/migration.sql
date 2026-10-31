-- CreateTable
CREATE TABLE "card_snapshots" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "source_card_id" UUID NOT NULL,
    "source_version_id" UUID NOT NULL,
    "owner_user_id" UUID NOT NULL,
    "captured_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "payload" JSONB NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "card_snapshots_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "card_shares" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "card_id" UUID NOT NULL,
    "card_version_id" UUID NOT NULL,
    "sender_user_id" UUID NOT NULL,
    "token_hash" TEXT NOT NULL,
    "recipient_phone_hash" TEXT,
    "scope" JSONB NOT NULL,
    "pin_hash" TEXT,
    "expires_at" TIMESTAMPTZ NOT NULL,
    "revoked_at" TIMESTAMPTZ,
    "max_claims" INTEGER NOT NULL DEFAULT 1,
    "claim_count" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "card_shares_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "share_claims" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "share_id" UUID NOT NULL,
    "claimed_by_user_id" UUID,
    "wallet_entry_id" UUID,
    "claimed_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "share_claims_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "card_shares_token_hash_key" ON "card_shares"("token_hash");

-- CreateIndex
CREATE INDEX "card_shares_card_id_idx" ON "card_shares"("card_id");

-- CreateIndex
CREATE INDEX "card_shares_sender_user_id_idx" ON "card_shares"("sender_user_id");

-- CreateIndex
CREATE INDEX "share_claims_share_id_idx" ON "share_claims"("share_id");

-- CreateIndex
CREATE UNIQUE INDEX "share_claims_wallet_entry_id_key" ON "share_claims"("wallet_entry_id");

-- CreateIndex
CREATE INDEX "card_snapshots_owner_user_id_idx" ON "card_snapshots"("owner_user_id");

-- AddForeignKey
ALTER TABLE "card_snapshots" ADD CONSTRAINT "card_snapshots_source_card_id_fkey" FOREIGN KEY ("source_card_id") REFERENCES "business_cards"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "card_snapshots" ADD CONSTRAINT "card_snapshots_source_version_id_fkey" FOREIGN KEY ("source_version_id") REFERENCES "card_versions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "card_snapshots" ADD CONSTRAINT "card_snapshots_owner_user_id_fkey" FOREIGN KEY ("owner_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "card_shares" ADD CONSTRAINT "card_shares_card_id_fkey" FOREIGN KEY ("card_id") REFERENCES "business_cards"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "card_shares" ADD CONSTRAINT "card_shares_card_version_id_fkey" FOREIGN KEY ("card_version_id") REFERENCES "card_versions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "card_shares" ADD CONSTRAINT "card_shares_sender_user_id_fkey" FOREIGN KEY ("sender_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "share_claims" ADD CONSTRAINT "share_claims_share_id_fkey" FOREIGN KEY ("share_id") REFERENCES "card_shares"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "share_claims" ADD CONSTRAINT "share_claims_claimed_by_user_id_fkey" FOREIGN KEY ("claimed_by_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "share_claims" ADD CONSTRAINT "share_claims_wallet_entry_id_fkey" FOREIGN KEY ("wallet_entry_id") REFERENCES "wallet_entries"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "wallet_entries" ADD CONSTRAINT "wallet_entries_snapshot_id_fkey" FOREIGN KEY ("snapshot_id") REFERENCES "card_snapshots"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "wallet_entries" ADD CONSTRAINT "wallet_entries_share_id_fkey" FOREIGN KEY ("share_id") REFERENCES "card_shares"("id") ON DELETE SET NULL ON UPDATE CASCADE;
