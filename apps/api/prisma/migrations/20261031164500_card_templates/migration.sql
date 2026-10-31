-- CreateTable
CREATE TABLE "card_templates" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "key" TEXT NOT NULL,
    "version" INTEGER NOT NULL,
    "name" TEXT NOT NULL,
    "layout" TEXT NOT NULL,
    "allowed_colors" JSONB NOT NULL,
    "allowed_type_scales" JSONB NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "card_templates_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "card_templates_key_version_key" ON "card_templates"("key", "version");

INSERT INTO "card_templates" ("key", "version", "name", "layout", "allowed_colors", "allowed_type_scales")
VALUES
    ('classic', 1, 'Classic', 'classic', '["#0f6e56","#1c1915","#8c2f2f"]', '["sm","md","lg"]'),
    ('split', 1, 'Split', 'split', '["#143d59","#0f6e56","#1c1915"]', '["sm","md","lg"]');
