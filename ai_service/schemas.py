from typing import Literal

from pydantic import BaseModel, Field

from settings import MAX_CONVERSATION_MESSAGES, TOP_K


class ChatMessage(BaseModel):
    role: Literal["user", "assistant"]
    content: str = Field(min_length=1, max_length=4000)


class ChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=4000)
    history: list[ChatMessage] = Field(default_factory=list, max_length=MAX_CONVERSATION_MESSAGES)
    imageBase64: str | None = None
    imageMimeType: str | None = None


class ChatResponse(BaseModel):
    reply: str


class QueryRewriteRequest(BaseModel):
    message: str = Field(min_length=1, max_length=4000)
    history: list[ChatMessage] = Field(default_factory=list, max_length=MAX_CONVERSATION_MESSAGES)


class QueryRewriteResponse(BaseModel):
    query: str



class VisionRequest(BaseModel):
    prompt: str = Field(
        default="Analyze this image in detail and describe what you see, including key objects, scene details, and any visible text.",
        max_length=4000,
    )
    imageBase64: str
    imageMimeType: str = "image/jpeg"
    history: list[ChatMessage] = Field(default_factory=list, max_length=MAX_CONVERSATION_MESSAGES)


class VisionResponse(BaseModel):
    reply: str


class SearchChunk(BaseModel):
    chunkId: str
    documentId: str
    fileId: str
    spaceId: str
    fileName: str = Field(max_length=255)
    fileType: str = Field(max_length=16)
    spaceName: str = Field(max_length=255)
    updatedAt: str
    excerpt: str = Field(min_length=1, max_length=3200)
    pageNumber: int | None = Field(default=None, ge=1)
    location: str | None = None
    chunkIndex: int = Field(default=0, ge=0)
    score: float = Field(default=1.0, ge=0, le=1)


class DeepSearchRequest(BaseModel):
    message: str = Field(min_length=1, max_length=4000)
    history: list[ChatMessage] = Field(default_factory=list, max_length=MAX_CONVERSATION_MESSAGES)
    sources: list[SearchChunk] = Field(min_length=1, max_length=TOP_K)


class Citation(BaseModel):
    id: int
    document_id: str
    file_id: str
    space_id: str
    file_name: str
    file_type: str
    space_name: str
    updated_at: str
    page_number: int | None
    chunk_id: str
    excerpt: str


class DeepSearchResponse(BaseModel):
    answer: str
    citations: list[Citation]
    search_metadata: dict[str, int | float]


class IndexedChunk(BaseModel):
    id: str
    fileId: str
    spaceId: str
    ownerId: str
    content: str = Field(min_length=1, max_length=12000)
    prefixedContent: str | None = None
    location: str | None = None
    embedding: list[float] = Field(min_length=1, max_length=8192)
    metadata: dict[str, str]
    pageNumber: int | None = Field(default=None, ge=1)
    chunkIndex: int = Field(ge=0)


class IndexCallback(BaseModel):
    fileId: str
    status: Literal[
        "UPLOADED",
        "EXTRACTING",
        "CHUNKING",
        "EMBEDDING",
        "SUMMARIZING",
        "INDEXING",
        "READY",
        "FAILED",
        "OCR_REQUIRED",
    ]
    error: str | None = Field(default=None, max_length=1000)
    summary: str | None = None
    keywords: list[str] = Field(default_factory=list)
    pageCount: int | None = None
    extractedText: str | None = None
    chunks: list[IndexedChunk] = Field(default_factory=list, max_length=1000)



class IndexAccepted(BaseModel):
    file_id: str
    status: Literal["PROCESSING"]


class EmbeddingRequest(BaseModel):
    text: str = Field(min_length=1, max_length=4000)


class EmbeddingResponse(BaseModel):
    embedding: list[float]


class FolderManifestFile(BaseModel):
    id: str
    name: str
    type: str
    size_bytes: int = 0
    updated_at: str | None = None
    status: str = "READY"
    summary: str | None = None
    keywords: list[str] = Field(default_factory=list)
    page_count: int | None = None


class FolderManifest(BaseModel):
    space_id: str
    space_name: str
    total_files: int = 0
    ready_files: int = 0
    indexing_files: int = 0
    failed_files: int = 0
    files: list[FolderManifestFile] = Field(default_factory=list)


class RAGStreamRequest(BaseModel):
    message: str = Field(min_length=1, max_length=4000)
    history: list[ChatMessage] = Field(default_factory=list, max_length=MAX_CONVERSATION_MESSAGES)
    folder_manifest: FolderManifest | None = None
    sources: list[SearchChunk] = Field(default_factory=list, max_length=100)
    intent: str | None = None