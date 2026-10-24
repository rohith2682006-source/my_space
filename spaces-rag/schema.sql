-- ============================================================================
-- Spaces RAG: PostgreSQL + pgvector Production Schema Migration
-- ============================================================================

-- Step 1: Enable the pgvector extension for dense vector embeddings
CREATE EXTENSION IF NOT EXISTS vector;

-- Step 2: Chunks table with 768-dimensional vector, HNSW and GIN indexes
CREATE TABLE IF NOT EXISTS chunks (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    space_id TEXT NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
    file_id TEXT NOT NULL REFERENCES files(id) ON DELETE CASCADE,
    file_name TEXT NOT NULL,
    location TEXT NOT NULL, -- e.g. "page 3", "slide 12", "image", "00:12:30"
    content TEXT NOT NULL,
    embedding vector(768) NOT NULL,
    embed_model TEXT NOT NULL DEFAULT 'text-embedding-004',
    tsv tsvector GENERATED ALWAYS AS (to_tsvector('english', coalesce(content, ''))) STORED,
    created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Fast Cosine Distance Vector Index (HNSW)
CREATE INDEX IF NOT EXISTS idx_chunks_embedding_hnsw 
    ON chunks USING hnsw (embedding vector_cosine_ops);

-- Full-Text Keyword Search Index (GIN)
CREATE INDEX IF NOT EXISTS idx_chunks_tsv_gin 
    ON chunks USING gin (tsv);

-- B-Tree indexes for fast space and file scoped isolation
CREATE INDEX IF NOT EXISTS idx_chunks_space_id 
    ON chunks (space_id);

CREATE INDEX IF NOT EXISTS idx_chunks_file_id 
    ON chunks (file_id);

-- Step 3: File Index Status table (pending, indexing, ready, failed + error & retry count)
CREATE TABLE IF NOT EXISTS file_index_status (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    file_id TEXT NOT NULL UNIQUE REFERENCES files(id) ON DELETE CASCADE,
    space_id TEXT NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending', -- pending, indexing, ready, failed
    error TEXT,
    retry_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_file_index_status_file_id ON file_index_status (file_id);
CREATE INDEX IF NOT EXISTS idx_file_index_status_space_id ON file_index_status (space_id);
CREATE INDEX IF NOT EXISTS idx_file_index_status_status ON file_index_status (status);

-- Step 4: AI Usage Log table (user, space, date, tokens, latency per stage)
CREATE TABLE IF NOT EXISTS ai_usage_log (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    space_id TEXT REFERENCES spaces(id) ON DELETE SET NULL,
    date TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    stage TEXT NOT NULL DEFAULT 'answer', -- rewrite, embed, search, rerank, answer
    input_tokens INTEGER NOT NULL DEFAULT 0,
    output_tokens INTEGER NOT NULL DEFAULT 0,
    latency_ms INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_ai_usage_log_user_id ON ai_usage_log (user_id);
CREATE INDEX IF NOT EXISTS idx_ai_usage_log_space_id ON ai_usage_log (space_id);
CREATE INDEX IF NOT EXISTS idx_ai_usage_log_date ON ai_usage_log (date);

-- Step 5: Answer Feedback table (thumbs up/down + question + chunk ids)
CREATE TABLE IF NOT EXISTS answer_feedback (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    space_id TEXT NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
    question TEXT NOT NULL,
    answer TEXT NOT NULL,
    rating TEXT NOT NULL, -- THUMBS_UP, THUMBS_DOWN
    chunk_ids JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_answer_feedback_user_id ON answer_feedback (user_id);
CREATE INDEX IF NOT EXISTS idx_answer_feedback_space_id ON answer_feedback (space_id);
CREATE INDEX IF NOT EXISTS idx_answer_feedback_created_at ON answer_feedback (created_at);
