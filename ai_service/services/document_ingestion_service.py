from dataclasses import dataclass
import logging
from time import perf_counter
from typing import Any
from uuid import uuid4

from services.chunking import chunk_pages
from services.document_extraction import extract_document
from services.embedding_service import EmbeddingService
from settings import CHUNK_OVERLAP, CHUNK_SIZE, MAX_CHUNKS_PER_DOCUMENT


logger = logging.getLogger("spaces.ai.ingestion")


@dataclass(frozen=True)
class IngestionResult:
    status: str
    chunks: list[dict[str, Any]]
    message: str | None = None


class DocumentIngestionService:
    def __init__(self, embedding_service: EmbeddingService) -> None:
        self._embedding_service = embedding_service

    async def ingest(
        self,
        *,
        file_id: str,
        space_id: str,
        owner_id: str,
        file_name: str,
        file_type: str,
        content: bytes,
    ) -> IngestionResult:
        extraction_started = perf_counter()
        extracted = extract_document(file_name, content)
        extraction_ms = (perf_counter() - extraction_started) * 1000
        if extracted.status != "READY":
            message = (
                "This PDF has no extractable text. OCR is required."
                if extracted.status == "OCR_REQUIRED"
                else "The document is empty or contains no extractable text."
            )
            return IngestionResult(status=extracted.status, chunks=[], message=message)

        chunks = chunk_pages(extracted.pages, chunk_size=CHUNK_SIZE, overlap=CHUNK_OVERLAP)
        if not chunks:
            return IngestionResult(status="FAILED", chunks=[], message="No text chunks were created.")
        if len(chunks) > MAX_CHUNKS_PER_DOCUMENT:
            return IngestionResult(status="FAILED", chunks=[], message="The document exceeds the indexing chunk limit.")

        embedding_started = perf_counter()
        vectors = await self._embedding_service.embed_documents([text for _, text in chunks])
        embedding_ms = (perf_counter() - embedding_started) * 1000
        logger.info(
            "document_indexed file_id=%s chunks=%s extraction_ms=%.1f embedding_ms=%.1f",
            file_id,
            len(chunks),
            extraction_ms,
            embedding_ms,
        )
        indexed_chunks: list[dict[str, Any]] = []
        for chunk_index, ((page_number, text), embedding) in enumerate(zip(chunks, vectors, strict=True)):
            indexed_chunks.append(
                {
                    "id": str(uuid4()),
                    "fileId": file_id,
                    "spaceId": space_id,
                    "ownerId": owner_id,
                    "content": text,
                    "embedding": embedding,
                    "metadata": {
                        "fileName": file_name,
                        "fileType": file_type,
                    },
                    "pageNumber": page_number,
                    "chunkIndex": chunk_index,
                }
            )

        return IngestionResult(status="READY", chunks=indexed_chunks)