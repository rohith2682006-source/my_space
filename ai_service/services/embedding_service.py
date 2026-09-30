from collections.abc import Sequence

from openai import AsyncOpenAI

from settings import EMBEDDING_MODEL, OPENAI_TIMEOUT_SECONDS


class EmbeddingService:
    def __init__(self, client: AsyncOpenAI, model: str = EMBEDDING_MODEL) -> None:
        self._client = client
        self._model = model

    async def embed_text(self, text: str) -> list[float]:
        vectors = await self.embed_documents([text])
        return vectors[0]

    async def embed_documents(self, texts: Sequence[str]) -> list[list[float]]:
        if not texts:
            return []

        vectors: list[list[float]] = []
        for offset in range(0, len(texts), 64):
            batch = texts[offset : offset + 64]
            response = await self._client.embeddings.create(
                model=self._model,
                input=list(batch),
                timeout=OPENAI_TIMEOUT_SECONDS,
            )
            ordered = sorted(response.data, key=lambda item: item.index)
            vectors.extend([item.embedding for item in ordered])

        if len(vectors) != len(texts):
            raise RuntimeError("Embedding provider returned an incomplete batch")
        return vectors