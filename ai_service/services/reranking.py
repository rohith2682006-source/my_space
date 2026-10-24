from collections.abc import Sequence
import json
import logging
import re
from typing import Any

from google import genai
from google.genai import types

from settings import LLM_MODEL

logger = logging.getLogger("spaces.ai.reranking")


class Reranker:
    def __init__(self, client: genai.Client | None = None) -> None:
        self._client = client

    async def rerank(
        self,
        candidates: Sequence[dict[str, Any]],
        query: str,
        limit: int = 5,
    ) -> list[dict[str, Any]]:
        if not candidates:
            return []

        if len(candidates) <= limit:
            return list(candidates)

        top_candidates = list(candidates)[:10]

        # Attempt Gemini LLM Reranker if client is available
        if self._client:
            try:
                candidate_prompts = []
                for idx, c in enumerate(top_candidates):
                    excerpt = str(c.get("excerpt", ""))[:400]
                    file_name = c.get("fileName", "doc")
                    candidate_prompts.append(f"[{idx}] (File: {file_name}) {excerpt}")

                prompt = (
                    f"Question: {query}\n\n"
                    "Evaluate the relevance of each excerpt to answering the question above. "
                    "Rate each on a scale from 0 to 10, where 10 is directly answers the question.\n"
                    "Output ONLY a JSON array of objects with 'index' and 'score', e.g. [{\"index\": 0, \"score\": 9.5}].\n\n"
                    "Excerpts:\n" + "\n\n".join(candidate_prompts)
                )

                response = await self._client.aio.models.generate_content(
                    model=LLM_MODEL,
                    contents=[prompt],
                    config=types.GenerateContentConfig(
                        temperature=0.0,
                        max_output_tokens=300,
                        thinking_config=types.ThinkingConfig(thinking_budget=0),
                    ),
                )

                raw_text = (response.text or "").strip()
                match = re.search(r"\[.*\]", raw_text, re.DOTALL)
                if match:
                    scores_list = json.loads(match.group())
                    scored_candidates = []
                    for item in scores_list:
                        idx = item.get("index")
                        llm_score = float(item.get("score", 0)) / 10.0
                        if idx is not None and 0 <= idx < len(top_candidates):
                            cand = dict(top_candidates[idx])
                            cand["score"] = cand.get("score", 0.0) * 0.3 + llm_score * 0.7
                            scored_candidates.append(cand)

                    if scored_candidates:
                        scored_candidates.sort(key=lambda x: x["score"], reverse=True)
                        return scored_candidates[:limit]
            except Exception as err:
                logger.warning("Gemini rerank fallback to lexical scoring: %s", err)

        # Lexical scoring fallback
        terms = {term.casefold() for term in query.split() if len(term) > 2}
        scored = []
        for candidate in top_candidates:
            content = str(candidate.get("excerpt", "")).casefold()
            lexical_score = sum(term in content for term in terms) / max(len(terms), 1)
            base_score = float(candidate.get("score", 0.0))
            cand = dict(candidate)
            cand["score"] = min(1.0, base_score * 0.7 + lexical_score * 0.3)
            scored.append(cand)

        return sorted(scored, key=lambda item: item["score"], reverse=True)[:limit]