import re
import unicodedata
from collections.abc import Iterable

import tiktoken


def normalize_text(text: str) -> str:
    text = unicodedata.normalize("NFKC", text)
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"[\t\f\v ]+", " ", text)
    text = re.sub(r" *\n *", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return "\n\n".join(part.strip() for part in text.split("\n\n") if part.strip())


def _encoding() -> tiktoken.Encoding:
    return tiktoken.get_encoding("cl100k_base")


def chunk_page_text(
    text: str,
    *,
    chunk_size: int,
    overlap: int,
    page_number: int | None = None,
) -> list[tuple[int | None, str]]:
    normalized = normalize_text(text)
    if not normalized:
        return []
    if chunk_size < 1 or overlap < 0 or overlap >= chunk_size:
        raise ValueError("Require chunk_size > overlap >= 0")

    encoding = _encoding()
    separator = encoding.encode("\n\n")
    current: list[int] = []
    chunks: list[tuple[int | None, str]] = []
    step = chunk_size - overlap

    def emit(token_ids: list[int]) -> None:
        content = encoding.decode(token_ids).strip()
        if content:
            chunks.append((page_number, content))

    paragraphs = normalized.split("\n\n")
    for paragraph_index, paragraph in enumerate(paragraphs):
        paragraph_tokens = encoding.encode(paragraph)
        if len(paragraph_tokens) > chunk_size:
            if current:
                emit(current)
                current = []
            start = 0
            while start < len(paragraph_tokens):
                window = paragraph_tokens[start : start + chunk_size]
                emit(window)
                if start + chunk_size >= len(paragraph_tokens):
                    break
                start += step
            current = (
                paragraph_tokens[-overlap:]
                if overlap and paragraph_index < len(paragraphs) - 1
                else []
            )
            continue

        addition = (separator if current else []) + paragraph_tokens
        if current and len(current) + len(addition) > chunk_size:
            emit(current)
            current = current[-overlap:] if overlap else []
            if len(current) + len(separator) + len(paragraph_tokens) > chunk_size:
                current = []
            addition = (separator if current else []) + paragraph_tokens
        current.extend(addition)

    if current:
        emit(current)

    return chunks


def chunk_pages(
    pages: Iterable[tuple[int | None, str]], *, chunk_size: int, overlap: int
) -> list[tuple[int | None, str]]:
    chunks: list[tuple[int | None, str]] = []
    for page_number, text in pages:
        chunks.extend(
            chunk_page_text(
                text,
                chunk_size=chunk_size,
                overlap=overlap,
                page_number=page_number,
            )
        )
    return chunks