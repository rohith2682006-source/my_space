from collections.abc import Sequence

from google import genai
from google.genai import types

from settings import EMBEDDING_MODEL


class EmbeddingService:
    def __init__(self, client: genai.Client, model: str = EMBEDDING_MODEL) -> None:
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
            contents = [
                {"role": "user", "parts": [{"text": t}]} for t in batch
            ]
            
            response = await self._client.aio.models.embed_content(
                model=self._model,
                contents=contents,
                config=types.EmbedContentConfig(output_dimensionality=1536)
            )
            
            vectors.extend([list(item.values) for item in response.embeddings])

        if len(vectors) != len(texts):
            raise RuntimeError("Embedding provider returned an incomplete batch")
        return vectors