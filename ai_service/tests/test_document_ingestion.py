import asyncio

from services.document_ingestion_service import DocumentIngestionService


class FakeEmbeddingService:
    async def embed_documents(self, texts: list[str]) -> list[list[float]]:
        return [[float(index), 1.0] for index, _ in enumerate(texts)]


def test_note_ingestion_creates_embedded_chunks_with_owner_metadata() -> None:
    service = DocumentIngestionService(FakeEmbeddingService())
    result = asyncio.run(
        service.ingest(
            file_id="file-id",
            space_id="space-id",
            owner_id="owner-id",
            file_name="Research.md",
            file_type="md",
            content=b"A note paragraph.\n\nAnother paragraph.",
        )
    )

    assert result.status == "READY"
    assert result.chunks
    assert result.chunks[0]["fileId"] == "file-id"
    assert result.chunks[0]["spaceId"] == "space-id"
    assert result.chunks[0]["ownerId"] == "owner-id"
    assert result.chunks[0]["embedding"] == [0.0, 1.0]