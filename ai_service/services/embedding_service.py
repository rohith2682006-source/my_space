import asyncio
from collections.abc import Sequence
import logging
import random

from google import genai
from google.genai import types

from settings import EMBEDDING_BATCH_SIZE, EMBEDDING_DIMENSIONS, EMBEDDING_MODEL

logger = logging.getLogger("spaces.ai.embedding")


class EmbeddingService:
    def __init__(
        self,
        client: genai.Client,
        model: str = EMBEDDING_MODEL,
        dimensions: int = EMBEDDING_DIMENSIONS,
    ) -> None:
        self._client = client
        self._model = model
        self._dimensions = dimensions

    async def embed_text(
        self,
        text: str,
        task_type: str = "RETRIEVAL_DOCUMENT",
    ) -> list[float]:
        vectors = await self.embed_documents([text], task_type=task_type)
        return vectors[0]

    async def embed_query(self, query: str) -> list[float]:
        return await self.embed_text(query, task_type="RETRIEVAL_QUERY")

    async def embed_documents(
        self,
        texts: Sequence[str],
        task_type: str = "RETRIEVAL_DOCUMENT",
    ) -> list[list[float]]:
        if not texts:
            return []

        vectors: list[list[float]] = []
        batch_size = max(1, min(EMBEDDING_BATCH_SIZE, 100))

        for offset in range(0, len(texts), batch_size):
            batch = texts[offset : offset + batch_size]
            contents = [{"parts": [{"text": t}]} for t in batch]

            # Exponential backoff retry
            max_attempts = 4
            delay = 1.0
            last_err: Exception | None = None

            for attempt in range(1, max_attempts + 1):
                try:
                    response = await self._client.aio.models.embed_content(
                        model=self._model,
                        contents=contents,
                        config=types.EmbedContentConfig(
                            output_dimensionality=self._dimensions,
                            task_type=task_type,
                        ),
                    )
                    vectors.extend([list(item.values) for item in response.embeddings])
                    break
                except Exception as err:
                    last_err = err
                    logger.warning(
                        "Embedding API attempt %d/%d failed: %s",
                        attempt,
                        max_attempts,
                        err,
                    )
                    if attempt == max_attempts:
                        raise RuntimeError(
                            f"Embedding batch failed after {max_attempts} attempts: {last_err}"
                        ) from last_err
                    await asyncio.sleep(delay + random.uniform(0.1, 0.5))
                    delay *= 2

        if len(vectors) != len(texts):
            raise RuntimeError(
                f"Embedding provider returned {len(vectors)} vectors for {len(texts)} inputs"
            )
        return vectors