# Specification: Folder & File RAG System with Realtime Streaming

## 1. Database Schema Specification

### 1.1 Model Modifications (`backend/prisma/schema.prisma`)

All new columns are added with defaults or marked nullable so existing records and both SQLite/PostgreSQL migrations run cleanly without data loss.

#### Model `File` Modifications
```prisma
model File {
  // --- Existing Columns ---
  id              String    @id @default(uuid())
  name            String
  originalName    String    @map("original_name")
  mimeType        String    @map("mime_type")
  extension       String
  size            BigInt
  storageKey      String    @unique @map("storage_key")
  thumbnailKey    String?   @map("thumbnail_key")
  checksum        String?
  spaceId         String    @map("space_id")
  uploadedBy      String    @map("uploaded_by")
  parentId        String?   @map("parent_id")
  category        String    @default("OTHER")
  isStarred       Boolean   @default(false) @map("is_starred")
  content         String?
  openedAt        DateTime? @map("opened_at")
  aiSearchEnabled Boolean   @default(false) @map("ai_search_enabled")
  indexStatus     String    @default("NOT_INDEXED") @map("index_status")
  indexError      String?   @map("index_error")
  createdAt       DateTime  @default(now()) @map("created_at")
  updatedAt       DateTime  @updatedAt @map("updated_at")
  deletedAt       DateTime? @map("deleted_at")
  trashedAt       DateTime? @map("trashed_at")

  // --- NEW COLUMNS FOR HIERARCHICAL RAG ---
  summary         String?   // Concise executive summary (<= 150 words)
  keywords        String    @default("[]") // JSON string array of up to 8 keywords, e.g. '["refund", "terms", "policy"]'
  pageCount       Int?      @map("page_count") // Total page/slide count if applicable
  extractedText   String?   @map("extracted_text") // Full extracted plain text cache for fast whole-document analysis

  // --- Relations ---
  space           Space            @relation(fields: [spaceId], references: [id], onDelete: Cascade)
  uploader        User             @relation(fields: [uploadedBy], references: [id])
  parent          File?            @relation("FileHierarchy", fields: [parentId], references: [id])
  children        File[]           @relation("FileHierarchy")
  versions        FileVersion[]
  tags            FileTag[]
  shareLinks      ShareLink[]
  permissions     FilePermission[]
  favorites       Favorite[]
  fileChunks      FileChunk[]
  chunks          Chunk[]
  fileIndexStatus FileIndexStatus?

  @@index([spaceId])
  @@index([uploadedBy])
  @@index([indexStatus])
  @@map("files")
}
```

#### Status Lifecycle State Machine
```
[UPLOADED] 
    │
    ▼
[EXTRACTING] (Text/OCR extraction)
    │
    ▼
[CHUNKING]   (Structural chunking)
    │
    ▼
[EMBEDDING]  (Vector generation via Gemini Embedding)
    │
    ▼
[SUMMARIZING] (Generating <=150-word summary & <=8 keywords)
    │
    ▼
[READY]      (Indexed and queryable)
    │
    └── (on error at any stage) ──► [FAILED] (Stores indexError reason)
```

---

## 2. API Specifications

### 2.1 Backend ➔ Python AI Microservice: Ingestion & Callback

#### `POST /documents/index` (Multipart Form)
* **Headers**: `Authorization: Bearer <AI_SERVICE_TOKEN>`
* **Fields**:
  - `file_id`: UUID
  - `space_id`: UUID
  - `owner_id`: UUID
  - `file_name`: String
  - `file_type`: String (`pdf`, `docx`, `txt`, etc.)
  - `file`: Binary file stream
* **Response (HTTP 202 Accepted)**:
  ```json
  {
    "file_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
    "status": "PROCESSING"
  }
  ```

#### `POST /api/v1/ai/internal/index-complete` (JSON Callback)
* **Headers**: `Authorization: Bearer <AI_SERVICE_TOKEN>`
* **Request Body**:
  ```json
  {
    "fileId": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
    "status": "READY",
    "error": null,
    "summary": "This document outlines the corporate employee refund and cancellation terms...",
    "keywords": ["refund", "policy", "reimbursement", "travel", "finance"],
    "pageCount": 4,
    "extractedText": "Full extracted document text...",
    "chunks": [
      {
        "id": "11111111-2222-3333-4444-555555555555",
        "fileId": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
        "spaceId": "aaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
        "ownerId": "uuuuuuu-vvvv-wwww-xxxx-yyyyyyyyyyyy",
        "content": "Section 4.1: Refunds are processed within 14 business days...",
        "prefixedContent": "File: refund_policy.pdf | Section 4.1: Refunds...",
        "location": "page 2",
        "embedding": [0.0123, -0.0456, ...],
        "pageNumber": 2,
        "chunkIndex": 0,
        "metadata": {
          "fileName": "refund_policy.pdf",
          "fileType": "pdf",
          "location": "page 2"
        }
      }
    ]
  }
  ```

---

### 2.2 Client ➔ Backend: Chat & Deep Search Streaming

#### `POST /api/v1/ai/deep-search/stream` & `POST /api/v1/ai/chat/stream`
* **Headers**:
  - `Authorization: Bearer <JWT_ACCESS_TOKEN>`
  - `Content-Type: application/json`
  - `Accept: text/event-stream`
* **Request Body**:
  ```json
  {
    "message": "tell me about the files in this folder",
    "history": [
      { "role": "user", "content": "hello" },
      { "role": "assistant", "content": "Hello! How can I assist you?" }
    ],
    "spaceIds": ["aaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"],
    "fileIds": []
  }
  ```

#### Backend Ownership Verification Rule:
1. Verify `req.user.userId`.
2. For each `spaceId` in `spaceIds`: Query database ensuring user is the Space owner or active member. Reject with `403 FORBIDDEN` if unauthorized.
3. For each `fileId` in `fileIds`: Query database ensuring file belongs to a space accessible to user. Reject with `403 FORBIDDEN` if unauthorized.
4. If `fileIds` is non-empty, `fileIds` takes precedence for chunk vector searches.

---

### 2.3 Backend ➔ Python Microservice: RAG Streaming Protocol

#### `POST /rag/answer/stream`
* **Request Body**:
  ```json
  {
    "message": "tell me about the files in this folder",
    "history": [],
    "folder_manifest": {
      "space_id": "aaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
      "space_name": "Rohith",
      "total_files": 3,
      "ready_files": 2,
      "indexing_files": 1,
      "failed_files": 0,
      "files": [
        {
          "id": "file-1",
          "name": "refund_policy.pdf",
          "type": "pdf",
          "size_bytes": 1048576,
          "updated_at": "2026-10-14T10:00:00.000Z",
          "status": "READY",
          "summary": "Describes employee travel and expense reimbursement guidelines.",
          "keywords": ["refund", "policy", "travel"],
          "page_count": 4
        },
        {
          "id": "file-2",
          "name": "q3_financial_strategy.pptx",
          "type": "pptx",
          "size_bytes": 2097152,
          "updated_at": "2026-10-14T11:00:00.000Z",
          "status": "READY",
          "summary": "Slide deck detailing Q3 revenue targets, OPEX cuts, and runway projections.",
          "keywords": ["finance", "revenue", "q3", "strategy"],
          "page_count": 18
        },
        {
          "id": "file-3",
          "name": "project_notes.txt",
          "type": "txt",
          "size_bytes": 4096,
          "updated_at": "2026-10-14T11:30:00.000Z",
          "status": "INDEXING",
          "summary": null,
          "keywords": [],
          "page_count": 1
        }
      ]
    },
    "sources": [ /* Filtered vector candidates from backend chunk search */ ]
  }
  ```

---

## 3. SSE Event Formats (Strict Chronological Order)

Every SSE stream follows this strict event delivery order:

```
[STATUS Event(s)] ──► [TEXT Token Events (repeated)] ──► [CITATIONS Event] ──► [DONE Event]
```

### Event Specification:

1. **Heartbeat** (emitted every 15 seconds if idle):
   ```
   : heartbeat
   ```

2. **Status Notification**:
   ```
   data: {"event": "status", "message": "Scanning 3 files in Rohith folder..."}
   ```
   ```
   data: {"event": "status", "message": "Synthesizing cross-document analysis (2 of 3 files ready)..."}
   ```

3. **Text Streaming Tokens**:
   ```
   data: {"text": "In "}
   data: {"text": "the **Rohith** "}
   data: {"text": "folder, "}
   ```

4. **Citations (Structured Sources)**:
   ```
   data: {
     "citations": [
       {
         "id": "cit-1",
         "file_id": "file-1",
         "file_name": "refund_policy.pdf",
         "space_id": "aaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
         "space_name": "Rohith",
         "page_number": 2,
         "location": "page 2",
         "excerpt": "Refunds are processed within 14 business days..."
       }
     ]
   }
   ```

5. **Done Event**:
   ```
   data: {
     "done": true,
     "search_metadata": {
       "mode": "OVERVIEW",
       "total_files": 3,
       "ready_files": 2,
       "chunks_used": 0,
       "llm_latency_ms": 412.5
     }
   }
   ```

6. **Error Event**:
   ```
   data: {
     "error": "The folder 'Rohith' currently contains 0 indexed documents. Please upload files to this space to begin.",
     "done": true
   }
   ```

---

## 4. Intent Routing Rules

The Python AI service selects **ONE** mode using deterministic keyword and structure rules first, calling Gemini with zero temperature only when rule confidence is below 0.85:

| Mode | Trigger Rules | Context Fed to LLM | Target Response Style |
| :--- | :--- | :--- | :--- |
| **`OVERVIEW`** | Query contains: *"tell me about the files"*, *"what is in this folder"*, *"summarize this folder"*, *"list documents"*, *"overview of files"*, *"what files do I have"*. | Folder manifest metadata + all file summaries (no raw chunk text needed). | Executive directory overview: list of files, primary topics, and readiness status. |
| **`DEEP_FACT`** | Query seeks specific facts, figures, clauses, policies, or questions without folder-wide summary terms (e.g. *"What is the refund turnaround time?"*). | Top semantic chunks retrieved via vector search scoped to selected Space/Files. | Direct, grounded answer citing specific `[File Name > Page X]` citations. |
| **`COMPARE`** | Query contains *"compare"*, *"difference between"*, *"versus"*, *"vs"* and names or implies multiple files. | Top semantic chunks from each named file. | Side-by-side or comparative analysis with citations from both files. |
| **`FULL_ANALYSIS`** | Query explicitly says *"analyse the entire folder"*, *"complete audit of all files"*, *"deep analysis of every document"*. | All file summaries + full extracted text of ready files (parallel chunk synthesis). | Comprehensive cross-document synthesis covering key themes, risks, and unified summary. |

### Partial Readiness and Empty Folder Fallback Rules:
- **Empty Folder**: If `ready_files == 0` and `indexing_files == 0`:  
  *Immediate response*: `"The folder '<space_name>' currently contains 0 indexed documents. Please upload files to this space to begin."*
- **Partially Ready Folder**: If `ready_files < total_files`:  
  *Mandatory prefix*: `"Note: <ready_files> of <total_files> files are ready (<indexing_files> still indexing). Answering based on available documents:\n\n..."*

---

## 5. Error Codes & Client Messages

| HTTP Code | Error Code | Client Toast / Display Message | Description |
| :--- | :--- | :--- | :--- |
| 400 | `INVALID_INPUT` | *"Please enter a valid message or attach a file."* | Empty query or invalid parameters. |
| 401 | `UNAUTHORIZED` | *"Session expired. Refreshing..."* | Access token expired (auto-refreshed via refresh token). |
| 403 | `ACCESS_DENIED` | *"You do not have permission to access one or more selected folders or files."* | Attempt to query folders/files belonging to another user. |
| 404 | `SPACE_NOT_FOUND` | *"Selected folder no longer exists."* | Space ID deleted or moved. |
| 413 | `FILE_TOO_LARGE` | *"Document exceeds the maximum 50MB indexing limit."* | File rejected during upload/indexing. |
| 415 | `UNSUPPORTED_TYPE` | *"File format not supported for AI indexing."* | Extension not in supported index list. |
| 429 | `AI_RATE_LIMITED` | *"AI service is busy. Please try again in a few moments."* | Gemini API quota or rate limit hit. |
| 503 | `AI_UNAVAILABLE` | *"AI service is temporarily unavailable. Please verify API configuration."* | Python service or Gemini offline. |
| 504 | `AI_TIMEOUT` | *"The analysis took too long. Please try a more specific question."* | Upstream request timed out (>60s). |

---

## 6. Golden Test Folder Specification

A deterministic test suite with 5 test documents:

1. `refund_policy.pdf`: Multi-page PDF detailing a 14-day refund window, $50 cancellation fee, and travel expense rules.
2. `architecture_strategy.docx`: Word document outlining system microservices and database migration strategy.
3. `release_notes.txt`: Plaintext changelog detailing v1.0, v1.1, and v1.2 updates.
4. `empty_document.txt`: A 0-byte text file.
5. `corrupted_file.pdf`: A file with a `.pdf` extension containing random non-PDF byte noise.

### 10 Benchmark Evaluation Questions & Expected Router Outputs:
1. *"In this folder tell me about the files"* ➔ **Mode**: `OVERVIEW` | **Expected**: List of files + summary of refund policy, architecture, and release notes. Mentions corrupt/empty file state.
2. *"What files are in this space?"* ➔ **Mode**: `OVERVIEW` | **Expected**: Directory inventory.
3. *"What is the refund turnaround time?"* ➔ **Mode**: `DEEP_FACT` | **Expected**: "14 business days" citing `[refund_policy.pdf > page 2]`.
4. *"What is the cancellation fee?"* ➔ **Mode**: `DEEP_FACT` | **Expected**: "$50" citing `[refund_policy.pdf > page 3]`.
5. *"Compare the refund policy with the architecture strategy"* ➔ **Mode**: `COMPARE` | **Expected**: Differentiates financial vs. technical focus.
6. *"Analyse the entire folder and give all details"* ➔ **Mode**: `FULL_ANALYSIS` | **Expected**: Comprehensive multi-file synthesis.
7. *"What changes were made in version 1.1?"* ➔ **Mode**: `DEEP_FACT` | **Expected**: Release notes v1.1 bullet points citing `[release_notes.txt]`.
8. *"What is inside empty_document.txt?"* ➔ **Mode**: `DEEP_FACT` | **Expected**: Notes that the file is empty or contains no text.
9. *"Why did corrupted_file.pdf fail?"* ➔ **Mode**: `OVERVIEW` | **Expected**: Identifies parsing error during extraction.
10. *"Summarize everything in this project"* ➔ **Mode**: `OVERVIEW` | **Expected**: High-level cross-document synopsis.
