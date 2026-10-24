import asyncio

from services.document_ingestion_service import DocumentIngestionService


class FakeEmbeddingService:
    async def embed_documents(self, texts: list[str], *args, **kwargs) -> list[list[float]]:
        return [[float(index), 1.0] for index, _ in enumerate(texts)]


def test_note_ingestion_creates_embedded_chunks_with_owner_metadata() -> None:
    service = DocumentIngestionService(FakeEmbeddingService())
    recorded_stages = []

    async def stage_cb(stage: str):
        recorded_stages.append(stage)

    result = asyncio.run(
        service.ingest(
            file_id="file-id",
            space_id="space-id",
            owner_id="owner-id",
            file_name="Research.md",
            file_type="md",
            content=b"A note paragraph.\n\nAnother paragraph.",
            on_stage=stage_cb,
        )
    )

    assert result.status == "READY"
    assert result.chunks
    assert result.chunks[0]["fileId"] == "file-id"
    assert result.chunks[0]["spaceId"] == "space-id"
    assert result.chunks[0]["embedding"] == [0.0, 1.0]
    assert recorded_stages == ["EXTRACTING", "CHUNKING", "EMBEDDING", "SUMMARIZING"]
    assert result.page_count == 1
    assert "A note paragraph." in (result.extracted_text or "")