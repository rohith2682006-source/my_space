ALTER TABLE "files" ADD COLUMN "ai_search_enabled" BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX "files_ai_search_enabled_idx" ON "files"("ai_search_enabled");