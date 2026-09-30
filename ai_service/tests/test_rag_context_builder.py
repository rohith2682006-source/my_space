from services.rag_context_builder import RAGContextBuilder


def _source(chunk_id: str, excerpt: str, page_number: int | None = 2) -> dict:
    return {
        "chunkId": chunk_id,
        "fileId": "file-1",
        "fileName": "Cloud.pdf",
        "spaceName": "Research",
        "pageNumber": page_number,
        "excerpt": excerpt,
    }


def test_context_deduplicates_duplicate_chunks_and_preserves_page_citations() -> None:
    builder = RAGContextBuilder(max_tokens=500)
    result = builder.build([_source("a", "Clouds scale."), _source("b", "Clouds scale.")])

    assert len(result.sources) == 1
    assert result.sources[0]["citationId"] == 1
    assert "Page: 2" in result.text
    assert "SOURCE [1]" in result.text


def test_context_does_not_exceed_configured_token_limit() -> None:
    builder = RAGContextBuilder(max_tokens=120)
    result = builder.build([_source("a", "cloud " * 1000)])

    assert result.tokens_used <= 120
    assert len(result.sources) == 1


def test_context_truncates_a_source_to_fit_the_budget() -> None:
    builder = RAGContextBuilder(max_tokens=100)
    result = builder.build([_source("a", "word " * 1000)])

    assert result.tokens_used <= 100
    assert len(result.sources[0]["excerpt"]) < len("word " * 1000)