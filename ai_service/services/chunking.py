import re
import unicodedata
from collections.abc import Iterable


def normalize_text(text: str) -> str:
    text = unicodedata.normalize("NFKC", text)
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"[\t\f\v ]+", " ", text)
    text = re.sub(r" *\n *", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return "\n\n".join(part.strip() for part in text.split("\n\n") if part.strip())


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

    # Character based approximation: 1 token ~ 4 chars
    chunk_size_chars = chunk_size * 4
    overlap_chars = overlap * 4

    chunks: list[tuple[int | None, str]] = []
    
    start = 0
    while start < len(normalized):
        end = start + chunk_size_chars
        # Try to find a natural break point (e.g. newline or space) if we are in the middle of a word
        if end < len(normalized):
            # Look backwards up to 100 chars for a newline
            break_point = normalized.rfind('\n', start, end)
            if break_point != -1 and break_point > start + chunk_size_chars // 2:
                end = break_point + 1
            else:
                # Look backwards for a space
                break_point = normalized.rfind(' ', start, end)
                if break_point != -1 and break_point > start + chunk_size_chars // 2:
                    end = break_point + 1
        
        chunk_text = normalized[start:end].strip()
        if chunk_text:
            chunks.append((page_number, chunk_text))
            
        if end >= len(normalized):
            break
            
        start = end - overlap_chars
        # Prevent infinite loop if overlap is too big
        if start <= chunks[-1][0] if chunks else 0:
            start = end

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