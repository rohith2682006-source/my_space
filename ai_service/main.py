import hashlib
import logging
import os
import secrets
from pathlib import PurePath
from time import perf_counter

import httpx
from fastapi import BackgroundTasks, Depends, FastAPI, File, Form, Header, HTTPException, UploadFile
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
openai_api_key = os.environ.get("OPENAI_API_KEY")
service_token = os.environ.get("AI_SERVICE_TOKEN", "")
client = (
    AsyncOpenAI(api_key=openai_api_key, timeout=OPENAI_TIMEOUT_SECONDS)
    if openai_api_key
    else None
)
embedding_service = EmbeddingService(client) if client else None
llm_service = LLMService(client) if client else None
ingestion_service = DocumentIngestionService(embedding_service) if embedding_service else None
context_builder = RAGContextBuilder(MAX_CONTEXT_TOKENS)
reranker = Reranker()


_NO_CREDIT_CODES = frozenset({
    "credit_balance_exhausted",
    "insufficient_quota",
    "billing_not_active",
})


def _raise_openai_rate_error(error: RateLimitError) -> None:
    """Convert an OpenAI RateLimitError to the correct HTTP status code.

    - 402 Payment Required: account has no credits / billing not set up.
    - 429 Too Many Requests: genuine per-minute or per-day rate limit.
    """
    body = getattr(error, "body", None) or {}
    code = body.get("code") if isinstance(body, dict) else None
    logger.warning("OpenAI rate/quota error code=%s", code)

    if code in _NO_CREDIT_CODES:
        raise HTTPException(
            status_code=402,
            detail=(
                "Your OpenAI account has no credits remaining. "
                "Please add billing at https://platform.openai.com/settings/organization/billing/"
            ),
        )
    raise HTTPException(
        status_code=429,
        detail="AI provider rate limit reached. Please try again in a moment.",
    )


async def verify_service_token(authorization: str | None = Header(default=None)) -> None:
    if not service_token or not authorization:
        raise HTTPException(status_code=401, detail="Unauthorized")

    scheme, _, supplied_token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not secrets.compare_digest(supplied_token, service_token):
        raise HTTPException(status_code=401, detail="Unauthorized")


def _require_ai_services() -> tuple[EmbeddingService, LLMService, DocumentIngestionService]:
    if client is None or embedding_service is None or llm_service is None or ingestion_service is None:
        raise HTTPException(status_code=503, detail="AI service is not configured")
    return embedding_service, llm_service, ingestion_service


async def _send_index_callback(callback: IndexCallback) -> None:
    if not service_token:
        logger.error("Document index callback skipped because the service token is not configured")
        return
    try:
        async with httpx.AsyncClient(timeout=OPENAI_TIMEOUT_SECONDS) as http_client:
            response = await http_client.post(
                BACKEND_CALLBACK_URL,
                headers={"Authorization": f"Bearer {service_token}"},
                json=callback.model_dump(),
            )
            response.raise_for_status()
    except httpx.HTTPError:
        logger.exception(
            "Document index callback failed file_id=%s status=%s",
            callback.fileId,
            callback.status,
        )


async def _index_in_background(
    *,
    file_id: str,
    space_id: str,
    owner_id: str,
    file_name: str,
    file_type: str,
    content: bytes,
) -> None:
    await _send_index_callback(IndexCallback(fileId=file_id, status="INDEXING"))
    try:
        _, _, document_ingestion = _require_ai_services()
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
                error="Unsupported document type. Supported types are PDF, TXT, and Markdown.",
            )
        )
    except AuthenticationError:
        logger.warning("Index background auth error: invalid API key")
        await _send_index_callback(
            IndexCallback(fileId=file_id, status="FAILED", error="OpenAI authentication failed. Invalid API credentials.")
        )
    except RateLimitError as error:
        body = getattr(error, "body", None) or {}
        code = body.get("code") if isinstance(body, dict) else None
        msg = (
            "OpenAI credits exhausted. Please add billing at https://platform.openai.com/settings/organization/billing/"
            if code in _NO_CREDIT_CODES
            else "AI provider rate limit reached. Please try again shortly."
        )
        logger.warning("Index background rate/quota error: code=%s", code)
        await _send_index_callback(
            IndexCallback(fileId=file_id, status="FAILED", error=msg)
        )
    except Exception:
        logger.exception("Document indexing failed file_id=%s", file_id)
        await _send_index_callback(
            IndexCallback(fileId=file_id, status="FAILED", error="Document indexing failed.")
        )


@app.get("/health")
async def health() -> dict[str, str]:
    has_key = bool(openai_api_key)
    return {
        "status": "healthy",
        "openai_configured": str(has_key).lower(),
    }


@app.post(
    "/embeddings",
    response_model=EmbeddingResponse,
    dependencies=[Depends(verify_service_token)],
)
async def embed_query(request: EmbeddingRequest) -> EmbeddingResponse:
    embedder, _, _ = _require_ai_services()
    started = perf_counter()
    try:
        vector = await embedder.embed_text(request.text)
    except AuthenticationError as error:
        logger.warning("OpenAI authentication error")
        raise HTTPException(
            status_code=401,
            detail="OpenAI authentication failed. Please verify API key configuration.",
        ) from error
    except RateLimitError as error:
        _raise_openai_rate_error(error)
    except APIError as error:
        logger.warning("Query embedding failed error_type=%s", type(error).__name__)
        raise HTTPException(status_code=502, detail="Query embedding failed") from error
    elapsed_ms = (perf_counter() - started) * 1000
    query_hash = hashlib.sha256(request.text.encode("utf-8")).hexdigest()[:12]
    logger.info("query_embedding query_hash=%s latency_ms=%.1f", query_hash, elapsed_ms)
    return EmbeddingResponse(embedding=vector)  # type: ignore[return-value]


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
    _require_ai_services()
    if not service_token:
        raise HTTPException(status_code=503, detail="AI service is not configured")
    safe_name = PurePath(file_name).name
    if not safe_name or safe_name != file_name or len(safe_name) > 255:
        raise HTTPException(status_code=400, detail="Invalid file name")

    content = await file.read(MAX_INDEX_FILE_BYTES + 1)
    if len(content) > MAX_INDEX_FILE_BYTES:
        raise HTTPException(status_code=413, detail="Document exceeds the indexing size limit")
    if not content:
        raise HTTPException(status_code=400, detail="Document is empty")

    extension = PurePath(safe_name).suffix.lower()
    if extension not in {".pdf", ".txt", ".md", ".markdown"}:
        raise HTTPException(status_code=415, detail="Unsupported document type")
    if file_type.lower().lstrip(".") != extension.lstrip("."):
        raise HTTPException(status_code=400, detail="File type does not match its name")

    background_tasks.add_task(
        _index_in_background,
        file_id=file_id,
        space_id=space_id,
        owner_id=owner_id,
        file_name=safe_name,
        file_type=extension.lstrip("."),
        content=content,
    )
    return IndexAccepted(file_id=file_id, status="PROCESSING")


@app.post("/chat", response_model=ChatResponse, dependencies=[Depends(verify_service_token)])
async def chat(request: ChatRequest) -> ChatResponse:
    _, llm, _ = _require_ai_services()
    try:
        answer = await llm.answer(
            question=request.message,
            context="",
            history=[item.model_dump() for item in request.history],
            system_prompt=CHAT_SYSTEM_PROMPT,
        )
    except AuthenticationError as error:
        logger.warning("OpenAI authentication error")
        raise HTTPException(
            status_code=401,
            detail="OpenAI authentication failed. Please verify API key configuration.",
        ) from error
    except RateLimitError as error:
        _raise_openai_rate_error(error)
    except APIError as error:
        logger.warning("Chat completion failed error_type=%s", type(error).__name__)
        raise HTTPException(status_code=502, detail="AI provider request failed") from error
    return ChatResponse(reply=answer)  # type: ignore[return-value]


@app.post(
    "/rag/answer",
    response_model=DeepSearchResponse,
    dependencies=[Depends(verify_service_token)],
)
async def answer_from_sources(request: DeepSearchRequest) -> DeepSearchResponse:
    _, llm, _ = _require_ai_services()
    sources = reranker.rerank(
        [item.model_dump() for item in request.sources],
        request.message,
        TOP_K,
    )
    built_context = context_builder.build(sources)
    if not built_context.sources:
        return DeepSearchResponse(
            answer="I couldn't find enough relevant information in your accessible documents to answer this question.",
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
            history=[item.model_dump() for item in request.history],
        )
    except AuthenticationError as error:
        logger.warning("OpenAI authentication error")
        raise HTTPException(
            status_code=401,
            detail="OpenAI authentication failed. Please verify API key configuration.",
        ) from error
    except RateLimitError as error:
        _raise_openai_rate_error(error)
    except APIError as error:
        logger.warning("RAG completion failed error_type=%s", type(error).__name__)
        raise HTTPException(status_code=502, detail="AI provider request failed") from error

    elapsed_ms = (perf_counter() - started) * 1000
    query_hash = hashlib.sha256(request.message.encode("utf-8")).hexdigest()[:12]
    logger.info(
        "rag_answer query_hash=%s chunks_retrieved=%s chunks_used=%s source_ids=%s scores=%s context_tokens=%s llm_latency_ms=%.1f",
        query_hash,
        len(sources),
        len(built_context.sources),
        [source["chunkId"] for source in built_context.sources],
        [round(float(source.get("score", 0)), 4) for source in built_context.sources],
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
        answer=answer,  # type: ignore[arg-type]
        citations=citations,
        search_metadata={
            "chunks_retrieved": len(sources),
            "chunks_used": len(built_context.sources),
            "context_tokens": built_context.tokens_used,
            "llm_latency_ms": round(elapsed_ms, 1),
        },
    )