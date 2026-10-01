import hashlib
import logging
import os
import secrets
from pathlib import PurePath
from time import perf_counter

import httpx
from fastapi import (
    BackgroundTasks,
    Depends,
    FastAPI,
    File,
    Form,
    Header,
    HTTPException,
    UploadFile,
)
from openai import APIError, AsyncOpenAI, AuthenticationError, RateLimitError

from schemas import (
    ChatRequest,
    ChatResponse,
    DeepSearchRequest,
    DeepSearchResponse,
    EmbeddingRequest,
    EmbeddingResponse,
    IndexAccepted,
    IndexCallback,
)
from services.document_ingestion_service import DocumentIngestionService
from services.document_extraction import UnsupportedDocumentType
from services.embedding_service import EmbeddingService
from services.llm_service import CHAT_SYSTEM_PROMPT, LLMService
from services.rag_context_builder import RAGContextBuilder
from services.reranking import Reranker
from settings import (
    BACKEND_CALLBACK_URL,
    MAX_CONTEXT_TOKENS,
    MAX_INDEX_FILE_BYTES,
    OPENAI_TIMEOUT_SECONDS,
    TOP_K,
)


logging.basicConfig(level=os.environ.get("LOG_LEVEL", "INFO"))
logger = logging.getLogger("spaces.ai")

app = FastAPI(title="Spaces AI Service", version="2.0.0")

# ---------------------------------------------------------------------------
# Provider configuration
# ---------------------------------------------------------------------------

openai_api_key = os.environ.get("OPENAI_API_KEY")
gemini_api_key = os.environ.get("GEMINI_API_KEY")
service_token = os.environ.get("AI_SERVICE_TOKEN", "")

# OpenAI is still used for embeddings/document indexing for now.
client = (
    AsyncOpenAI(
        api_key=openai_api_key,
        timeout=OPENAI_TIMEOUT_SECONDS,
    )
    if openai_api_key
    else None
)

embedding_service = EmbeddingService(client) if client else None

# Gemini is used for chat/RAG answers.
llm_service = LLMService() if gemini_api_key else None

ingestion_service = (
    DocumentIngestionService(embedding_service)
    if embedding_service
    else None
)

context_builder = RAGContextBuilder(MAX_CONTEXT_TOKENS)
reranker = Reranker()


# ---------------------------------------------------------------------------
# Authentication
# ---------------------------------------------------------------------------

async def verify_service_token(
    authorization: str | None = Header(default=None),
) -> None:
    if not service_token or not authorization:
        raise HTTPException(status_code=401, detail="Unauthorized")

    scheme, _, supplied_token = authorization.partition(" ")

    if (
        scheme.lower() != "bearer"
        or not secrets.compare_digest(supplied_token, service_token)
    ):
        raise HTTPException(status_code=401, detail="Unauthorized")


# ---------------------------------------------------------------------------
# Service requirements
# ---------------------------------------------------------------------------

def _require_llm_service() -> LLMService:
    if llm_service is None:
        raise HTTPException(
            status_code=503,
            detail="Gemini AI service is not configured",
        )

    return llm_service


def _require_embedding_services() -> tuple[
    EmbeddingService,
    DocumentIngestionService,
]:
    if embedding_service is None or ingestion_service is None:
        raise HTTPException(
            status_code=503,
            detail="Document embedding service is not configured",
        )

    return embedding_service, ingestion_service


# ---------------------------------------------------------------------------
# Backend callback
# ---------------------------------------------------------------------------

async def _send_index_callback(callback: IndexCallback) -> None:
    if not service_token:
        logger.error(
            "Document index callback skipped because the service token "
            "is not configured"
        )
        return

    try:
        async with httpx.AsyncClient(
            timeout=OPENAI_TIMEOUT_SECONDS
        ) as http_client:
            response = await http_client.post(
                BACKEND_CALLBACK_URL,
                headers={
                    "Authorization": f"Bearer {service_token}"
                },
                json=callback.model_dump(),
            )

            response.raise_for_status()

    except httpx.HTTPError:
        logger.exception(
            "Document index callback failed file_id=%s status=%s",
            callback.fileId,
            callback.status,
        )


# ---------------------------------------------------------------------------
# Background document indexing
# ---------------------------------------------------------------------------

async def _index_in_background(
    *,
    file_id: str,
    space_id: str,
    owner_id: str,
    file_name: str,
    file_type: str,
    content: bytes,
) -> None:
    await _send_index_callback(
        IndexCallback(
            fileId=file_id,
            status="INDEXING",
        )
    )

    try:
        _, document_ingestion = _require_embedding_services()

        result = await document_ingestion.ingest(
            file_id=file_id,
            space_id=space_id,
            owner_id=owner_id,
            file_name=file_name,
            file_type=file_type,
            content=content,
        )

        await _send_index_callback(
            IndexCallback(
                fileId=file_id,
                status=result.status,  # type: ignore[arg-type]
                error=result.message,
                chunks=result.chunks,
            )
        )

    except UnsupportedDocumentType:
        await _send_index_callback(
            IndexCallback(
                fileId=file_id,
                status="FAILED",
                error=(
                    "Unsupported document type. Supported types are "
                    "PDF, TXT, and Markdown."
                ),
            )
        )

    except AuthenticationError:
        logger.warning(
            "Index background auth error: invalid OpenAI API key"
        )

        await _send_index_callback(
            IndexCallback(
                fileId=file_id,
                status="FAILED",
                error=(
                    "OpenAI authentication failed. "
                    "Invalid API credentials."
                ),
            )
        )

    except RateLimitError:
        logger.warning(
            "Index background OpenAI rate/quota error"
        )

        await _send_index_callback(
            IndexCallback(
                fileId=file_id,
                status="FAILED",
                error=(
                    "OpenAI embedding service rate or quota limit "
                    "was reached."
                ),
            )
        )

    except Exception:
        logger.exception(
            "Document indexing failed file_id=%s",
            file_id,
        )

        await _send_index_callback(
            IndexCallback(
                fileId=file_id,
                status="FAILED",
                error="Document indexing failed.",
            )
        )


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------

@app.get("/health")
async def health() -> dict[str, str]:
    return {
        "status": "healthy",
        "openai_configured": str(bool(openai_api_key)).lower(),
        "gemini_configured": str(bool(gemini_api_key)).lower(),
    }


# ---------------------------------------------------------------------------
# Embeddings
# ---------------------------------------------------------------------------

@app.post(
    "/embeddings",
    response_model=EmbeddingResponse,
    dependencies=[Depends(verify_service_token)],
)
async def embed_query(
    request: EmbeddingRequest,
) -> EmbeddingResponse:
    embedder, _ = _require_embedding_services()

    started = perf_counter()

    try:
        vector = await embedder.embed_text(request.text)

    except AuthenticationError as error:
        logger.warning("OpenAI authentication error")

        raise HTTPException(
            status_code=401,
            detail=(
                "OpenAI authentication failed. "
                "Please verify API key configuration."
            ),
        ) from error

    except RateLimitError as error:
        logger.warning(
            "OpenAI embedding rate/quota error"
        )

        raise HTTPException(
            status_code=429,
            detail=(
                "OpenAI embedding rate or quota limit reached."
            ),
        ) from error

    except APIError as error:
        logger.warning(
            "Query embedding failed error_type=%s",
            type(error).__name__,
        )

        raise HTTPException(
            status_code=502,
            detail="Query embedding failed",
        ) from error

    elapsed_ms = (perf_counter() - started) * 1000

    query_hash = hashlib.sha256(
        request.text.encode("utf-8")
    ).hexdigest()[:12]

    logger.info(
        "query_embedding query_hash=%s latency_ms=%.1f",
        query_hash,
        elapsed_ms,
    )

    return EmbeddingResponse(
        embedding=vector
    )


# ---------------------------------------------------------------------------
# Document indexing
# ---------------------------------------------------------------------------

@app.post(
    "/documents/index",
    response_model=IndexAccepted,
    status_code=202,
    dependencies=[Depends(verify_service_token)],
)
async def index_document(
    background_tasks: BackgroundTasks,
    file_id: str = Form(...),
    space_id: str = Form(...),
    owner_id: str = Form(...),
    file_name: str = Form(...),
    file_type: str = Form(...),
    file: UploadFile = File(...),
) -> IndexAccepted:

    _require_embedding_services()

    if not service_token:
        raise HTTPException(
            status_code=503,
            detail="AI service is not configured",
        )

    safe_name = PurePath(file_name).name

    if (
        not safe_name
        or safe_name != file_name
        or len(safe_name) > 255
    ):
        raise HTTPException(
            status_code=400,
            detail="Invalid file name",
        )

    content = await file.read(
        MAX_INDEX_FILE_BYTES + 1
    )

    if len(content) > MAX_INDEX_FILE_BYTES:
        raise HTTPException(
            status_code=413,
            detail="Document exceeds the indexing size limit",
        )

    if not content:
        raise HTTPException(
            status_code=400,
            detail="Document is empty",
        )

    extension = PurePath(
        safe_name
    ).suffix.lower()

    if extension not in {
        ".pdf",
        ".txt",
        ".md",
        ".markdown",
    }:
        raise HTTPException(
            status_code=415,
            detail="Unsupported document type",
        )

    if (
        file_type.lower().lstrip(".")
        != extension.lstrip(".")
    ):
        raise HTTPException(
            status_code=400,
            detail="File type does not match its name",
        )

    background_tasks.add_task(
        _index_in_background,
        file_id=file_id,
        space_id=space_id,
        owner_id=owner_id,
        file_name=safe_name,
        file_type=extension.lstrip("."),
        content=content,
    )

    return IndexAccepted(
        file_id=file_id,
        status="PROCESSING",
    )


# ---------------------------------------------------------------------------
# Gemini Chat
# ---------------------------------------------------------------------------

@app.post(
    "/chat",
    response_model=ChatResponse,
    dependencies=[Depends(verify_service_token)],
)
async def chat(
    request: ChatRequest,
) -> ChatResponse:

    llm = _require_llm_service()

    try:
        answer = await llm.answer(
            question=request.message,
            context="",
            history=[
                item.model_dump()
                for item in request.history
            ],
            system_prompt=CHAT_SYSTEM_PROMPT,
        )

    except Exception as error:
        logger.exception(
            "Gemini chat request failed error_type=%s",
            type(error).__name__,
        )

        raise HTTPException(
            status_code=502,
            detail="Gemini AI request failed",
        ) from error

    return ChatResponse(
        reply=answer
    )


# ---------------------------------------------------------------------------
# Gemini RAG answer
# ---------------------------------------------------------------------------

@app.post(
    "/rag/answer",
    response_model=DeepSearchResponse,
    dependencies=[Depends(verify_service_token)],
)
async def answer_from_sources(
    request: DeepSearchRequest,
) -> DeepSearchResponse:

    llm = _require_llm_service()

    sources = reranker.rerank(
        [
            item.model_dump()
            for item in request.sources
        ],
        request.message,
        TOP_K,
    )

    built_context = context_builder.build(
        sources
    )

    if not built_context.sources:
        return DeepSearchResponse(
            answer=(
                "I couldn't find enough relevant information "
                "in your accessible documents to answer this question."
            ),
            citations=[],
            search_metadata={
                "chunks_retrieved": len(sources),
                "chunks_used": 0,
                "context_tokens": 0,
            },
        )

    started = perf_counter()

    try:
        answer = await llm.answer(
            question=request.message,
            context=built_context.text,
            history=[
                item.model_dump()
                for item in request.history
            ],
        )

    except Exception as error:
        logger.exception(
            "Gemini RAG request failed error_type=%s",
            type(error).__name__,
        )

        raise HTTPException(
            status_code=502,
            detail="Gemini AI request failed",
        ) from error

    elapsed_ms = (
        perf_counter() - started
    ) * 1000

    query_hash = hashlib.sha256(
        request.message.encode("utf-8")
    ).hexdigest()[:12]

    logger.info(
        "rag_answer query_hash=%s "
        "chunks_retrieved=%s "
        "chunks_used=%s "
        "source_ids=%s "
        "scores=%s "
        "context_tokens=%s "
        "llm_latency_ms=%.1f",
        query_hash,
        len(sources),
        len(built_context.sources),
        [
            source["chunkId"]
            for source in built_context.sources
        ],
        [
            round(
                float(source.get("score", 0)),
                4,
            )
            for source in built_context.sources
        ],
        built_context.tokens_used,
        elapsed_ms,
    )

    citations = [
        {
            "id": source["citationId"],
            "document_id": source["documentId"],
            "file_id": source["fileId"],
            "space_id": source["spaceId"],
            "file_name": source["fileName"],
            "file_type": source["fileType"],
            "space_name": source["spaceName"],
            "updated_at": source["updatedAt"],
            "page_number": source.get("pageNumber"),
            "chunk_id": source["chunkId"],
            "excerpt": source["excerpt"],
        }
        for source in built_context.sources
    ]

    return DeepSearchResponse(
        answer=answer,
        citations=citations,
        search_metadata={
            "chunks_retrieved": len(sources),
            "chunks_used": len(built_context.sources),
            "context_tokens": built_context.tokens_used,
            "llm_latency_ms": round(
                elapsed_ms,
                1,
            ),
        },
    )