import tiktoken

from services.chunking import chunk_page_text, normalize_text


def test_paragraphs_are_grouped_and_page_metadata_is_preserved() -> None:
    chunks = chunk_page_text(
        "First paragraph.\n\nSecond paragraph.",
        chunk_size=40,
        overlap=5,
        page_number=12,
    )

    assert len(chunks) == 1
    assert chunks[0][0] == 12
    assert "First paragraph." in chunks[0][1]
    assert "Second paragraph." in chunks[0][1]


def test_long_paragraphs_respect_token_limit_without_duplicate_tail() -> None:
    text = " ".join(f"term{index}" for index in range(300))
    chunks = chunk_page_text(text, chunk_size=80, overlap=12, page_number=3)
    encoding = tiktoken.get_encoding("cl100k_base")

    assert len(chunks) > 1
    assert len({chunk for _, chunk in chunks}) == len(chunks)
    assert all(page == 3 for page, _ in chunks)
    assert all(len(encoding.encode(chunk)) <= 80 for _, chunk in chunks)


def test_normalization_preserves_paragraph_boundaries() -> None:
    assert normalize_text("  first\r\n\r\n\tsecond  ") == "first\n\nsecond"