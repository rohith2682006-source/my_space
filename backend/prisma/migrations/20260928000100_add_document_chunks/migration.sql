ALTER TABLE "files" ADD COLUMN "index_status" TEXT NOT NULL DEFAULT 'NOT_INDEXED';
ALTER TABLE "files" ADD COLUMN "index_error" TEXT;

CREATE TABLE "file_chunks" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "file_id" TEXT NOT NULL,
    "space_id" TEXT NOT NULL,
    "owner_id" TEXT NOT NULL,
    "content" TEXT NOT NULL,
    "embedding" TEXT NOT NULL,
    "metadata" TEXT NOT NULL DEFAULT '{}',
    "page_number" INTEGER,
    "chunk_index" INTEGER NOT NULL,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "file_chunks_file_id_fkey"
      FOREIGN KEY ("file_id") REFERENCES "files" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "file_chunks_file_id_chunk_index_key"
  ON "file_chunks"("file_id", "chunk_index");
CREATE INDEX "file_chunks_file_id_idx" ON "file_chunks"("file_id");
CREATE INDEX "file_chunks_space_id_owner_id_idx" ON "file_chunks"("space_id", "owner_id");