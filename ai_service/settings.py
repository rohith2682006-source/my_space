import os
from dotenv import load_dotenv

load_dotenv()


def _int_setting(name: str, default: int, minimum: int = 1) -> int:
    value = int(os.environ.get(name, str(default)))

    if value < minimum:
        raise ValueError(f"{name} must be at least {minimum}")

    return value


# ---------------------------------------------------------------------------
# Feature Flag
# ---------------------------------------------------------------------------

RAG_ENABLED = os.environ.get("RAG_ENABLED", "true").lower() in ("true", "1", "yes")

# ---------------------------------------------------------------------------
# AI Models
# ---------------------------------------------------------------------------

# Use the latest alias for the chat model as required
LLM_MODEL = os.environ.get(
    "LLM_MODEL",
    "gemini-3.5-flash",
)

LLM_FALLBACK_MODELS = [
    model.strip()
    for model in os.environ.get(
        "LLM_FALLBACK_MODELS",
        "gemini-3.5-flash,gemini-3.1-flash-lite,gemini-3.5-flash-lite,gemini-3.8-flash,gemini-flash-latest",
    ).split(",")
    if model.strip()
]

# Gemini embedding model (768 dimensions)
EMBEDDING_MODEL = os.environ.get(
    "EMBEDDING_MODEL",
    "gemini-embedding-2",
)
EMBEDDING_DIMENSIONS = _int_setting("EMBEDDING_DIMENSIONS", 768)
EMBEDDING_BATCH_SIZE = _int_setting("EMBEDDING_BATCH_SIZE", 100)

# ---------------------------------------------------------------------------
# Document Processing & RAG Limits
# ---------------------------------------------------------------------------

CHUNK_SIZE_WORDS = _int_setting("CHUNK_SIZE_WORDS", 350)
CHUNK_OVERLAP_WORDS = _int_setting("CHUNK_OVERLAP_WORDS", 50, minimum=0)

MAX_PDF_PAGES = _int_setting("MAX_PDF_PAGES", 100)
MAX_VIDEO_MINUTES = _int_setting("MAX_VIDEO_MINUTES", 30)
MAX_INDEX_FILE_BYTES = _int_setting("MAX_INDEX_FILE_BYTES", 50_000_000)
MAX_INDEX_CONCURRENCY = _int_setting("MAX_INDEX_CONCURRENCY", 2)

TOP_K = _int_setting("TOP_K", 5)
DISTANCE_CUTOFF = float(os.environ.get("DISTANCE_CUTOFF", "0.25"))

MAX_CONTEXT_TOKENS = _int_setting("MAX_CONTEXT_TOKENS", 8000)
MAX_CHUNKS_PER_DOCUMENT = _int_setting("MAX_CHUNKS_PER_DOCUMENT", 1000)

MAX_CONVERSATION_MESSAGES = _int_setting(
    "MAX_CONVERSATION_MESSAGES",
    12,
)

MAX_CHUNKS_PER_DOCUMENT = _int_setting(
    "MAX_CHUNKS_PER_DOCUMENT",
    500,
)


# ---------------------------------------------------------------------------
# AI Response Settings
# ---------------------------------------------------------------------------

MAX_RESPONSE_TOKENS = _int_setting(
    "MAX_RESPONSE_TOKENS",
    900,
)

OPENAI_TIMEOUT_SECONDS = _int_setting(
    "OPENAI_TIMEOUT_SECONDS",
    45,
)

MAX_HISTORY_TOKENS = _int_setting(
    "MAX_HISTORY_TOKENS",
    3000,
)


# ---------------------------------------------------------------------------
# Backend Callback
# ---------------------------------------------------------------------------

BACKEND_CALLBACK_URL = os.environ.get(
    "BACKEND_CALLBACK_URL",
    "http://127.0.0.1:3000/api/v1/ai/internal/index-complete",
)


CHUNK_SIZE = CHUNK_SIZE_WORDS
CHUNK_OVERLAP = CHUNK_OVERLAP_WORDS

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

if CHUNK_OVERLAP_WORDS >= CHUNK_SIZE_WORDS:
    raise ValueError(
        "CHUNK_OVERLAP_WORDS must be smaller than CHUNK_SIZE_WORDS"
    )