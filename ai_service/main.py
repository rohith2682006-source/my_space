import asyncio
import base64
import hashlib
import json
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
from fastapi.responses import StreamingResponse
from google import genai
from google.genai.errors import APIError


from schemas import (
    ChatRequest,
    ChatResponse,
    DeepSearchRequest,
    DeepSearchResponse,
    EmbeddingRequest,
    EmbeddingResponse,
    FolderManifest,
    IndexAccepted,
    IndexCallback,
    QueryRewriteRequest,
    QueryRewriteResponse,
    RAGStreamRequest,
    VisionRequest,
    VisionResponse,
)

from services.intent_router import IntentRouter, QueryIntent

from services.document_ingestion_service import DocumentIngestionService
from services.document_extraction import UnsupportedDocumentType, DocumentLimitExceeded
from services.embedding_service import EmbeddingService
from services.llm_service import CHAT_SYSTEM_PROMPT, LLMService
from services.rag_context_builder import RAGContextBuilder
from services.reranking import Reranker
from settings import (
    BACKEND_CALLBACK_URL,
    MAX_CONTEXT_TOKENS,
    MAX_INDEX_CONCURRENCY,
    MAX_INDEX_FILE_BYTES,
    TOP_K,
)



logging.basicConfig(level=os.environ.get("LOG_LEVEL", "INFO"))
logger = logging.getLogger("spaces.ai")

app = FastAPI(title="Spaces AI Service", version="2.0.0")

# ---------------------------------------------------------------------------
# Provider configuration
# ---------------------------------------------------------------------------

gemini_api_key = os.environ.get("GEMINI_API_KEY")
service_token = os.environ.get("AI_SERVICE_TOKEN", "")

# Gemini is used for embeddings/document indexing.
client = (
    genai.Client(
        api_key=gemini_api_key,
    )
    if gemini_api_key
    else None
)

embedding_service = EmbeddingService(client) if client else None

# Gemini is used for chat/RAG answers.
llm_service = LLMService() if gemini_api_key else None

ingestion_service = (
    DocumentIngestionService(embedding_service, client=client, llm_service=llm_service)
    if embedding_service
    else None
)

context_builder = RAGContextBuilder(MAX_CONTEXT_TOKENS)
reranker = Reranker(client=client)
index_semaphore = asyncio.Semaphore(MAX_INDEX_CONCURRENCY)




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
            timeout=30
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
    async with index_semaphore:
        await _send_index_callback(
            IndexCallback(
                fileId=file_id,
                status="INDEXING",
            )
        )

        async def stage_callback(stage: str) -> None:
            await _send_index_callback(
                IndexCallback(
                    fileId=file_id,
                    status=stage,  # type: ignore[arg-type]
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
                on_stage=stage_callback,
            )

            await _send_index_callback(
                IndexCallback(
                    fileId=file_id,
                    status=result.status,  # type: ignore[arg-type]
                    error=result.message,
                    chunks=result.chunks,
                    summary=result.summary,
                    keywords=result.keywords or [],
                    pageCount=result.page_count,
                    extractedText=result.extracted_text,
                )
            )

        except DocumentLimitExceeded as limit_err:
            await _send_index_callback(
                IndexCallback(
                    fileId=file_id,
                    status="FAILED",
                    error=str(limit_err),
                )
            )

        except UnsupportedDocumentType as unsup_err:
            await _send_index_callback(
                IndexCallback(
                    fileId=file_id,
                    status="FAILED",
                    error=str(unsup_err),
                )
            )

        except APIError:
            logger.warning(
                "Index background Gemini API error"
            )

            await _send_index_callback(
                IndexCallback(
                    fileId=file_id,
                    status="FAILED",
                    error=(
                        "Gemini embedding service error or quota limit reached."
                    ),
                )
            )

        except Exception as err:
            logger.exception(
                "Document indexing failed file_id=%s",
                file_id,
            )

            await _send_index_callback(
                IndexCallback(
                    fileId=file_id,
                    status="FAILED",
                    error=f"Document indexing failed: {err}",
                )
            )



# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------

@app.get("/health")
async def health() -> dict[str, str]:
    return {
        "status": "healthy",
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

    except APIError as error:
        logger.warning("Gemini authentication error")

        raise HTTPException(
            status_code=401,
            detail=(
                "Gemini authentication failed. "
                "Please verify API key configuration."
            ),
        ) from error

    except APIError as error:
        logger.warning(
            "Gemini embedding rate/quota error"
        )

        raise HTTPException(
            status_code=429,
            detail=(
                "Gemini embedding rate or quota limit reached."
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

    allowed_extensions = {
        ".pdf",
        ".pptx",
        ".ppt",
        ".docx",
        ".doc",
        ".txt",
        ".md",
        ".markdown",
        ".csv",
        ".png",
        ".jpg",
        ".jpeg",
        ".webp",
        ".gif",
        ".mp4",
        ".webm",
        ".mov",
        ".mp3",
        ".wav",
        ".m4a",
    }

    if extension not in allowed_extensions:
        raise HTTPException(
            status_code=415,
            detail=f"Unsupported document type: {extension}",
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
        if request.imageBase64:
            image_bytes = base64.b64decode(request.imageBase64)
            answer = await llm.answer_vision(
                prompt=request.message,
                image_bytes=image_bytes,
                mime_type=request.imageMimeType or "image/jpeg",
                history=[
                    item.model_dump()
                    for item in request.history
                ],
            )
        else:
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


@app.post(
    "/chat/stream",
    dependencies=[Depends(verify_service_token)],
)
async def chat_stream(
    request: ChatRequest,
):
    llm = _require_llm_service()

    async def event_generator():
        try:
            if request.imageBase64:
                image_bytes = base64.b64decode(request.imageBase64)
                answer = await llm.answer_vision(
                    prompt=request.message,
                    image_bytes=image_bytes,
                    mime_type=request.imageMimeType or "image/jpeg",
                    history=[item.model_dump() for item in request.history],
                )
                yield f"data: {json.dumps({'text': answer})}\n\n"
                yield f"data: {json.dumps({'done': True, 'citations': []})}\n\n"
            else:
                async for token in llm.answer_stream(
                    question=request.message,
                    context="",
                    history=[item.model_dump() for item in request.history],
                    system_prompt=CHAT_SYSTEM_PROMPT,
                ):
                    yield f"data: {json.dumps({'text': token})}\n\n"
                yield f"data: {json.dumps({'done': True, 'citations': []})}\n\n"
        except Exception as error:
            logger.exception("Streaming chat failed: %s", error)
            yield f"data: {json.dumps({'error': 'AI streaming failed', 'done': True})}\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


# ---------------------------------------------------------------------------
# Vision AI Image Analyzer
# ---------------------------------------------------------------------------

@app.post(
    "/vision/analyze",
    response_model=VisionResponse,
    dependencies=[Depends(verify_service_token)],
)
async def vision_analyze(
    request: VisionRequest,
) -> VisionResponse:

    llm = _require_llm_service()

    try:
        image_bytes = base64.b64decode(request.imageBase64)
        answer = await llm.answer_vision(
            prompt=request.prompt,
            image_bytes=image_bytes,
            mime_type=request.imageMimeType,
            history=[
                item.model_dump()
                for item in request.history
            ],
        )

    except Exception as error:
        logger.exception(
            "Gemini Vision request failed error_type=%s",
            type(error).__name__,
        )

        raise HTTPException(
            status_code=502,
            detail="Vision AI request failed",
        ) from error

    return VisionResponse(
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

    sources = await reranker.rerank(
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
                "I couldn't find that in your files. Try rephrasing or make sure the relevant file is uploaded to this space."
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


# ---------------------------------------------------------------------------
# Query Rewrite
# ---------------------------------------------------------------------------

@app.post(
    "/rag/rewrite-query",
    response_model=QueryRewriteResponse,
    dependencies=[Depends(verify_service_token)],
)
async def rewrite_query(
    request: QueryRewriteRequest,
) -> QueryRewriteResponse:
    llm = _require_llm_service()
    rewritten = await llm.rewrite_query(
        question=request.message,
        history=[item.model_dump() for item in request.history],
    )
    return QueryRewriteResponse(query=rewritten)


# ---------------------------------------------------------------------------
# Streaming RAG Answer (SSE)
# ---------------------------------------------------------------------------

@app.post(
    "/rag/answer/stream",
    dependencies=[Depends(verify_service_token)],
)
async def stream_rag_answer_endpoint(
    request: RAGStreamRequest,
):
    llm = _require_llm_service()
    start_time = perf_counter()

    # 1. Resolve Intent
    router = IntentRouter(llm_service=llm)
    has_manifest = request.folder_manifest is not None
    file_count = request.folder_manifest.total_files if request.folder_manifest else 0

    if request.intent:
        try:
            intent = QueryIntent[request.intent.upper()]
        except KeyError:
            intent = QueryIntent.DEEP_FACT
    else:
        route_res = await router.route(
            query=request.message,
            has_folder_manifest=has_manifest,
            file_count=file_count,
        )
        intent = route_res.intent

    # 2. Rerank chunk sources if provided
    raw_sources = [item.model_dump() for item in request.sources]
    sources = []
    if raw_sources:
        if intent == QueryIntent.DOCUMENT:
            # Preserve all sequential chunks of the document without truncating to TOP_K
            sources = raw_sources
        elif intent in (QueryIntent.DEEP_FACT, QueryIntent.COMPARE, QueryIntent.FULL_ANALYSIS):
            sources = await reranker.rerank(raw_sources, request.message, TOP_K)
        else:
            sources = raw_sources

    manifest_dict = request.folder_manifest.model_dump() if request.folder_manifest else None

    # 3. Build Citations in advance
    citations = []
    if sources and intent in (QueryIntent.DEEP_FACT, QueryIntent.COMPARE, QueryIntent.FULL_ANALYSIS, QueryIntent.DOCUMENT):
        for idx, source in enumerate(sources[:20], 1):
            citations.append({
                "id": f"cit-{idx}",
                "file_id": source.get("fileId", ""),
                "file_name": source.get("fileName", "Untitled"),
                "space_id": source.get("spaceId", ""),
                "space_name": source.get("spaceName", "Space"),
                "page_number": source.get("pageNumber"),
                "location": source.get("location") or (f"page {source.get('pageNumber')}" if source.get("pageNumber") else None),
                "excerpt": source.get("excerpt", "")[:250],
            })
    elif intent == QueryIntent.OVERVIEW and manifest_dict:
        for idx, f in enumerate(manifest_dict.get("files", [])[:15], 1):
            citations.append({
                "id": f"file-{idx}",
                "file_id": f.get("id", ""),
                "file_name": f.get("name", "Untitled"),
                "space_id": manifest_dict.get("space_id", ""),
                "space_name": manifest_dict.get("space_name", "Folder"),
                "page_number": f.get("page_count"),
                "location": f"{f.get('page_count', 1)} pages" if f.get("page_count") else None,
                "excerpt": f.get("summary") or f"Document in {manifest_dict.get('space_name', 'folder')}",
            })

    async def event_generator():
        # SSE Event 1: Status notification
        folder_name = request.folder_manifest.space_name if request.folder_manifest else "folder"
        total_files = request.folder_manifest.total_files if request.folder_manifest else len(citations)
        ready_files = request.folder_manifest.ready_files if request.folder_manifest else len(citations)

        if intent == QueryIntent.CHAT:
            status_msg = "Thinking..."
        elif intent == QueryIntent.DOCUMENT:
            status_msg = "Analyzing document structure and content..."
        elif intent == QueryIntent.OVERVIEW:
            status_msg = f"Scanning {total_files} files in {folder_name} folder..."
        elif intent == QueryIntent.COMPARE:
            status_msg = f"Comparing documents across {folder_name}..."
        elif intent == QueryIntent.FULL_ANALYSIS:
            status_msg = f"Synthesizing cross-document analysis ({ready_files} of {total_files} files ready)..."
        else:
            status_msg = "Searching document passages..."

        yield f"data: {json.dumps({'event': 'status', 'message': status_msg})}\n\n"

        # SSE Event 2: Token stream
        try:
            async for token in llm.stream_rag_answer(
                question=request.message,
                history=[item.model_dump() for item in request.history],
                folder_manifest=manifest_dict,
                sources=sources,
                intent=intent.value,
            ):
                yield f"data: {json.dumps({'text': token})}\n\n"
        except Exception as err:
            logger.exception("Streaming RAG failed: %s", err)
            yield f"data: {json.dumps({'text': 'An error occurred while generating the response.'})}\n\n"

        # SSE Event 3: Structured Citations
        yield f"data: {json.dumps({'citations': citations})}\n\n"

        # SSE Event 4: Done Event with Search Metadata
        elapsed_ms = round((perf_counter() - start_time) * 1000, 1)
        done_payload = {
            "done": True,
            "search_metadata": {
                "mode": intent.value,
                "total_files": total_files,
                "ready_files": ready_files,
                "chunks_used": len(sources) if intent != QueryIntent.OVERVIEW else 0,
                "llm_latency_ms": elapsed_ms,
            },
        }
        yield f"data: {json.dumps(done_payload)}\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )