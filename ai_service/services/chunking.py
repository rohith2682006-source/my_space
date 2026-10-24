import re
import unicodedata
from collections.abc import Iterable
from settings import CHUNK_SIZE_WORDS, CHUNK_OVERLAP_WORDS


def normalize_text(text: str) -> str:
    if not text:
        return ""
    text = unicodedata.normalize("NFKC", text)
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"[\t\f\v ]+", " ", text)
    text = re.sub(r" *\n *", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return "\n\n".join(part.strip() for part in text.split("\n\n") if part.strip())


def _split_into_atomic_blocks(text: str) -> list[str]:
    """
    Splits text into paragraphs, tables, or code blocks that must not be split internally.
    """
    lines = text.split("\n")
    blocks: list[str] = []
    current_block: list[str] = []
    in_code_block = False
    in_table = False

    for line in lines:
        stripped = line.strip()

        # Code block fence
        if stripped.startswith("```"):
            current_block.append(line)
            if in_code_block:
                # Closing fence
                blocks.append("\n".join(current_block))
                current_block = []
                in_code_block = False
            else:
                # Opening fence
                in_code_block = True
            continue

        if in_code_block:
            current_block.append(line)
            continue

        # Table row
        is_table_row = stripped.startswith("|") and stripped.endswith("|")
        if is_table_row:
            in_table = True
            current_block.append(line)
            continue
        elif in_table:
            # End of table
            blocks.append("\n".join(current_block))
            current_block = []
            in_table = False

        # Regular empty line separating paragraphs
        if not stripped:
            if current_block:
                blocks.append("\n".join(current_block))
                current_block = []
            continue

        current_block.append(line)

    if current_block:
        blocks.append("\n".join(current_block))

    return [b.strip() for b in blocks if b.strip()]


def chunk_structural_text(
    text: str,
    location: str,
    file_name: str,
    *,
    chunk_size_words: int = CHUNK_SIZE_WORDS,
    overlap_words: int = CHUNK_OVERLAP_WORDS,
) -> list[dict]:
    """
    Chunks text by structural blocks (~350 words, 50 word overlap),
    keeping tables and code blocks intact, and prefixes every chunk
    with 'File: <file_name> | <location>'.
    """
    normalized = normalize_text(text)
    if not normalized:
        return []

    blocks = _split_into_atomic_blocks(normalized)
    if not blocks:
        return []

    chunks_data: list[dict] = []
    current_words: list[str] = []
    current_text_parts: list[str] = []

    for block in blocks:
        block_words = block.split()
        block_word_count = len(block_words)

        # If block alone exceeds chunk size (e.g. huge table or long paragraph),
        # keep it as its own chunk if it's a table/code block, or split on sentence boundaries
        if block_word_count > chunk_size_words:
            # Flush existing accumulator
            if current_text_parts:
                content = "\n\n".join(current_text_parts)
                prefixed = f"File: {file_name} | {location}\n\n{content}"
                chunks_data.append({
                    "location": location,
                    "content": content,
                    "prefixed_content": prefixed,
                })
                # Keep overlap words
                overlap_slice = current_words[-overlap_words:] if overlap_words > 0 else []
                current_words = list(overlap_slice)
                current_text_parts = [" ".join(overlap_slice)] if overlap_slice else []

            # If it's a table or code, keep intact as a single dedicated chunk
            if block.startswith("```") or (block.startswith("|") and "|" in block[1:]):
                prefixed = f"File: {file_name} | {location}\n\n{block}"
                chunks_data.append({
                    "location": location,
                    "content": block,
                    "prefixed_content": prefixed,
                })
            else:
                # Split large regular text by word windows
                start = 0
                while start < len(block_words):
                    end = start + chunk_size_words
                    sub_words = block_words[start:end]
                    sub_content = " ".join(sub_words)
                    prefixed = f"File: {file_name} | {location}\n\n{sub_content}"
                    chunks_data.append({
                        "location": location,
                        "content": sub_content,
                        "prefixed_content": prefixed,
                    })
                    if end >= len(block_words):
                        break
                    start = end - overlap_words
            continue

        # Check if adding this block exceeds target chunk size
        if len(current_words) + block_word_count > chunk_size_words and current_text_parts:
            content = "\n\n".join(current_text_parts)
            prefixed = f"File: {file_name} | {location}\n\n{content}"
            chunks_data.append({
                "location": location,
                "content": content,
                "prefixed_content": prefixed,
            })
            # Overlap
            overlap_slice = current_words[-overlap_words:] if overlap_words > 0 else []
            current_words = list(overlap_slice) + block_words
            current_text_parts = ([" ".join(overlap_slice)] if overlap_slice else []) + [block]
        else:
            current_words.extend(block_words)
            current_text_parts.append(block)

    if current_text_parts:
        content = "\n\n".join(current_text_parts)
        prefixed = f"File: {file_name} | {location}\n\n{content}"
        chunks_data.append({
            "location": location,
            "content": content,
            "prefixed_content": prefixed,
        })

    return chunks_data