from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class BuiltContext:
    text: str
    sources: list[dict[str, Any]]
    tokens_used: int


class RAGContextBuilder:
    def __init__(self, max_tokens: int) -> None:
        self._max_tokens = max_tokens

    def build(self, candidates: list[dict[str, Any]]) -> BuiltContext:
        selected: list[dict[str, Any]] = []
        sections: list[str] = []
        seen: set[tuple[str, int | None, str]] = set()
        tokens_used = 0

        for candidate in candidates:
            excerpt = str(candidate.get("excerpt", "")).strip()
            key = (
                str(candidate.get("fileId", "")),
                candidate.get("pageNumber"),
                " ".join(excerpt.split()).casefold(),
            )
            if not excerpt or key in seen:
                continue
            seen.add(key)

            citation_id = len(selected) + 1
            page = candidate.get("pageNumber")
            page_label = f"\nPage: {page}" if page is not None else ""
            header = (
                f"SOURCE [{citation_id}]\n"
                f"File: {candidate.get('fileName', 'Untitled')}\n"
                f"Space: {candidate.get('spaceName', 'Space')}"
                f"{page_label}\nContent:\n"
            )
            
            # Approximate token count: 1 token ~ 4 chars
            header_tokens = len(header) // 4
            remaining = self._max_tokens - tokens_used - header_tokens
            if remaining <= 0:
                break

            excerpt_tokens = len(excerpt) // 4
            if excerpt_tokens > remaining:
                # truncate string
                excerpt = excerpt[:remaining * 4].strip()
                excerpt_tokens = len(excerpt) // 4
                
            if not excerpt:
                break

            section = f"{header}{excerpt}"
            section_tokens = header_tokens + excerpt_tokens
            if section_tokens > self._max_tokens - tokens_used:
                break

            source = dict(candidate)
            source["citationId"] = citation_id
            source["excerpt"] = excerpt
            selected.append(source)
            sections.append(section)
            tokens_used += section_tokens

        return BuiltContext(text="\n\n".join(sections), sources=selected, tokens_used=tokens_used)