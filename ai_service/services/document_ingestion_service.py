from dataclasses import dataclass
import logging
import re
from time import perf_counter
from typing import Any
from uuid import uuid4

from google import genai

from services.chunking import chunk_structural_text
from services.document_extraction import extract_document
from services.embedding_service import EmbeddingService
from settings import (
    CHUNK_OVERLAP_WORDS,
    CHUNK_SIZE_WORDS,
    MAX_CHUNKS_PER_DOCUMENT,
)

logger = logging.getLogger("spaces.ai.ingestion")


@dataclass(frozen=True)
class IngestionResult:
    status: str
    chunks: list[dict[str, Any]]
    message: str | None = None
    summary: str | None = None
    keywords: list[str] | None = None
    page_count: int | None = None
    extracted_text: str | None = None


def _parse_page_number(location: str) -> int | None:
    match = re.search(r"(?:page|slide)\s+(\d+)", location, re.IGNORECASE)
    if match:
        try:
            return int(match.group(1))
        except ValueError:
            return None
    return None


class DocumentIngestionService:
    def __init__(
        self,
        embedding_service: EmbeddingService,
        client: genai.Client | None = None,
        llm_service: Any | None = None,
    ) -> None:
        self._embedding_service = embedding_service
        self._client = client
        self._llm_service = llm_service

    async def ingest(
        self,
        *,
        file_id: str,
        space_id: str,
        owner_id: str,
        file_name: str,
        file_type: str,
        content: bytes,
        on_stage: Any | None = None,
    ) -> IngestionResult:
        if on_stage:
            await on_stage("EXTRACTING")

        extraction_started = perf_counter()
        try:
            extracted = await extract_document(
                file_name=file_name,
                content=content,
                client=self._client,
            )
        except Exception as exc:
            logger.exception("Document extraction failed for file %s", file_name)
            return IngestionResult(
                status="FAILED",
                chunks=[],
                message=str(exc),
            )

        extraction_ms = (perf_counter() - extraction_started) * 1000

        if extracted.status != "READY" or not extracted.units:
            return IngestionResult(
                status=extracted.status if extracted.status != "READY" else "FAILED",
                chunks=[],
                message=extracted.error or "The document is empty or contains no extractable text.",
            )

        if on_stage:
            await on_stage("CHUNKING")

        # Chunk all units structurally
        raw_chunks: list[dict[str, str]] = []
        for unit in extracted.units:
            unit_chunks = chunk_structural_text(
                text=unit.content,
                location=unit.location,
                file_name=file_name,
                chunk_size_words=CHUNK_SIZE_WORDS,
                overlap_words=CHUNK_OVERLAP_WORDS,
            )
            raw_chunks.extend(unit_chunks)

        if not raw_chunks:
            return IngestionResult(
                status="FAILED",
                chunks=[],
                message="No text chunks could be generated from document.",
            )

        if len(raw_chunks) > MAX_CHUNKS_PER_DOCUMENT:
            raw_chunks = raw_chunks[:MAX_CHUNKS_PER_DOCUMENT]
            logger.warning(
                "Document %s exceeded MAX_CHUNKS_PER_DOCUMENT; truncated to %d chunks",
                file_name,
                MAX_CHUNKS_PER_DOCUMENT,
            )

        if on_stage:
            await on_stage("EMBEDDING")

        # Generate embeddings using prefixed_content with RETRIEVAL_DOCUMENT
        texts_to_embed = [c["prefixed_content"] for c in raw_chunks]
        embedding_started = perf_counter()
        vectors = await self._embedding_service.embed_documents(
            texts_to_embed,
            task_type="RETRIEVAL_DOCUMENT",
        )
        embedding_ms = (perf_counter() - embedding_started) * 1000

        logger.info(
            "document_indexed file_id=%s chunks=%s extraction_ms=%.1f embedding_ms=%.1f",
            file_id,
            len(raw_chunks),
            extraction_ms,
            embedding_ms,
        )

        indexed_chunks: list[dict[str, Any]] = []
        max_page = 0
        for chunk_index, (chunk_data, embedding) in enumerate(zip(raw_chunks, vectors, strict=True)):
            page_num = _parse_page_number(chunk_data["location"])
            if page_num and page_num > max_page:
                max_page = page_num
            indexed_chunks.append(
                {
                    "id": str(uuid4()),
                    "fileId": file_id,
                    "spaceId": space_id,
                    "ownerId": owner_id,
                    "content": chunk_data["content"],
                    "prefixedContent": chunk_data["prefixed_content"],
                    "location": chunk_data["location"],
                    "embedding": embedding,
                    "metadata": {
                        "fileName": file_name,
                        "fileType": file_type,
                        "location": chunk_data["location"],
                    },
                    "pageNumber": page_num,
                    "chunkIndex": chunk_index,
                }
            )

        full_extracted = "\n\n".join(u.content for u in extracted.units)
        page_count = max_page if max_page > 0 else (len(extracted.units) if file_type in ("pdf", "pptx") else 1)

        summary = None
        keywords: list[str] = []

        if on_stage:
            await on_stage("SUMMARIZING")

        if self._llm_service:
            try:
                summary, keywords = await self._llm_service.summarize_document(
                    file_name=file_name,
                    text=full_extracted,
                )
            except Exception as sum_err:
                logger.warning("Summarization error for file %s: %s", file_name, sum_err)

        return IngestionResult(
            status="READY",
            chunks=indexed_chunks,
            summary=summary,
            keywords=keywords,
            page_count=page_count,
            extracted_text=full_extracted,
        )