from typing import Literal

from pydantic import BaseModel, Field

from settings import MAX_CONVERSATION_MESSAGES, TOP_K


class ChatMessage(BaseModel):
    role: Literal["user", "assistant"]
    content: str = Field(min_length=1, max_length=4000)


class ChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=4000)
    history: list[ChatMessage] = Field(default_factory=list, max_length=MAX_CONVERSATION_MESSAGES)


class ChatResponse(BaseModel):
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
    chunkIndex: int = Field(ge=0)
    score: float = Field(ge=0, le=1)


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
    content: str = Field(min_length=1, max_length=3200)
    embedding: list[float] = Field(min_length=1, max_length=8192)
    metadata: dict[str, str]
    pageNumber: int | None = Field(default=None, ge=1)
    chunkIndex: int = Field(ge=0)


class IndexCallback(BaseModel):
    fileId: str
    status: Literal["INDEXING", "READY", "FAILED", "OCR_REQUIRED"]
    error: str | None = Field(default=None, max_length=500)
    chunks: list[IndexedChunk] = Field(default_factory=list, max_length=500)


class IndexAccepted(BaseModel):
    file_id: str
    status: Literal["PROCESSING"]


class EmbeddingRequest(BaseModel):
    text: str = Field(min_length=1, max_length=4000)


class EmbeddingResponse(BaseModel):
    embedding: list[float]