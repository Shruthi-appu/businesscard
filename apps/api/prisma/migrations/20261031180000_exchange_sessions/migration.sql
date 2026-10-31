-- CreateEnum
CREATE TYPE "exchange_status" AS ENUM ('open', 'joined', 'accepted', 'declined', 'expired', 'failed');

-- CreateEnum
CREATE TYPE "exchange_mode" AS ENUM ('one_way', 'mutual');

-- CreateEnum
CREATE TYPE "exchange_method" AS ENUM ('qr', 'ble', 'nfc', 'link');

-- CreateEnum
CREATE TYPE "exchange_consent" AS ENUM ('pending', 'accepted', 'declined');

-- CreateTable
CREATE TABLE "exchange_sessions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "initiator_user_id" UUID NOT NULL,
    "status" "exchange_status" NOT NULL DEFAULT 'open',
    "mode" "exchange_mode" NOT NULL,
    "method" "exchange_method" NOT NULL,
    "code_hash" TEXT NOT NULL,
    "expires_at" TIMESTAMPTZ NOT NULL,
    "accepted_at" TIMESTAMPTZ,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "exchange_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "exchange_participants" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "session_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "selected_card_id" UUID,
    "consent_status" "exchange_consent" NOT NULL DEFAULT 'pending',
    "consented_at" TIMESTAMPTZ,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "exchange_participants_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "exchange_sessions_code_hash_key" ON "exchange_sessions"("code_hash");

-- CreateIndex
CREATE INDEX "exchange_sessions_code_hash_expires_at_idx" ON "exchange_sessions"("code_hash", "expires_at");

-- CreateIndex
CREATE UNIQUE INDEX "exchange_participants_session_id_user_id_key" ON "exchange_participants"("session_id", "user_id");

-- CreateIndex
CREATE INDEX "exchange_participants_user_id_idx" ON "exchange_participants"("user_id");

-- AddForeignKey
ALTER TABLE "exchange_sessions" ADD CONSTRAINT "exchange_sessions_initiator_user_id_fkey" FOREIGN KEY ("initiator_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "exchange_participants" ADD CONSTRAINT "exchange_participants_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "exchange_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "exchange_participants" ADD CONSTRAINT "exchange_participants_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "exchange_participants" ADD CONSTRAINT "exchange_participants_selected_card_id_fkey" FOREIGN KEY ("selected_card_id") REFERENCES "business_cards"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "wallet_entries" ADD CONSTRAINT "wallet_entries_exchange_session_id_fkey" FOREIGN KEY ("exchange_session_id") REFERENCES "exchange_sessions"("id") ON DELETE SET NULL ON UPDATE CASCADE;
