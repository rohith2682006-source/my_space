import os
from dotenv import load_dotenv

load_dotenv()


def _int_setting(name: str, default: int, minimum: int = 1) -> int:
    value = int(os.environ.get(name, str(default)))

    if value < minimum:
        raise ValueError(f"{name} must be at least {minimum}")

    return value


# ---------------------------------------------------------------------------
# AI Models
# ---------------------------------------------------------------------------

# Gemini is now used for normal AI chat and RAG answers.
LLM_MODEL = os.environ.get(
    "LLM_MODEL",
    "gemini-2.5-flash",
)

# Gemini is now used for embeddings/indexing as well.
EMBEDDING_MODEL = os.environ.get(
    "EMBEDDING_MODEL",
    "gemini-embedding-2",
)


# ---------------------------------------------------------------------------
# Document Processing
# ---------------------------------------------------------------------------

CHUNK_SIZE = _int_setting(
    "CHUNK_SIZE",
    800,
)

CHUNK_OVERLAP = _int_setting(
    "CHUNK_OVERLAP",
    120,
    minimum=0,
)

TOP_K = _int_setting(
    "TOP_K",
    8,
)

MAX_CONTEXT_TOKENS = _int_setting(
    "MAX_CONTEXT_TOKENS",
    8000,
)

MAX_INDEX_FILE_BYTES = _int_setting(
    "MAX_INDEX_FILE_BYTES",
    25_000_000,
)

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


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

if CHUNK_OVERLAP >= CHUNK_SIZE:
    raise ValueError(
        "CHUNK_OVERLAP must be smaller than CHUNK_SIZE"
    )