from collections.abc import Sequence
from typing import Any


class Reranker:
    def rerank(self, candidates: Sequence[dict[str, Any]], query: str, limit: int) -> list[dict[str, Any]]:
        terms = {term.casefold() for term in query.split() if len(term) > 2}
        scored = []
        for candidate in candidates:
            content = str(candidate.get("excerpt", "")).casefold()
            lexical_score = sum(term in content for term in terms) / max(len(terms), 1)
            base_score = float(candidate.get("score", 0.0))
            candidate = dict(candidate)
            candidate["score"] = min(1.0, base_score * 0.9 + lexical_score * 0.1)
            scored.append(candidate)
        return sorted(scored, key=lambda item: item["score"], reverse=True)[:limit]