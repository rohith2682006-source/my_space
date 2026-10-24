"""20-Question Golden Test Suite for Spaces RAG Intent Router.

Asserts deterministic classification accuracy across all 4 operational modes:
- OVERVIEW
- DEEP_FACT
- COMPARE
- FULL_ANALYSIS
"""

import asyncio
from unittest.mock import AsyncMock

import pytest

from services.intent_router import IntentRouter, QueryIntent


# 20 Golden Evaluation Queries with Expected Ground Truth Intent
GOLDEN_EVAL_DATASET = [
    # --- Category 1: OVERVIEW (Directory & Folder Listings) ---
    ("tell me about the files in this folder", QueryIntent.OVERVIEW, True),
    ("what documents do we have in this space?", QueryIntent.OVERVIEW, True),
    ("list all files and their topics", QueryIntent.OVERVIEW, True),
    ("summarize this folder", QueryIntent.OVERVIEW, True),
    ("what does this folder contain?", QueryIntent.OVERVIEW, True),
    ("give me a breakdown of the files in Rohith directory", QueryIntent.OVERVIEW, True),

    # --- Category 2: DEEP_FACT (Pinpoint Retrieval) ---
    ("what is the total amount due on invoice #1024?", QueryIntent.DEEP_FACT, False),
    ("when does the non-disclosure agreement expire?", QueryIntent.DEEP_FACT, False),
    ("who signed the contract on page 4?", QueryIntent.DEEP_FACT, False),
    ("what is the interest rate mentioned in section 3.2?", QueryIntent.DEEP_FACT, False),
    ("where is the headquarters address located in the company bylaws?", QueryIntent.DEEP_FACT, False),
    ("how much was spent on travel expenses in March?", QueryIntent.DEEP_FACT, False),

    # --- Category 3: COMPARE (Cross-Document Comparison) ---
    ("compare Q1 and Q2 financial performance metrics", QueryIntent.COMPARE, False),
    ("what are the differences between standard_contract.pdf and revised_contract.pdf?", QueryIntent.COMPARE, False),
    ("how does the privacy policy compare to the GDPR requirements doc?", QueryIntent.COMPARE, False),
    ("contrast the marketing strategy in 2025 vs 2026", QueryIntent.COMPARE, False),

    # --- Category 4: FULL_ANALYSIS (Holistic Cross-Document Synthesis) ---
    ("conduct a comprehensive risk analysis across all uploaded policies", QueryIntent.FULL_ANALYSIS, True),
    ("extract all action items, deadlines, and responsibilities across all files", QueryIntent.FULL_ANALYSIS, True),
    ("provide an in-depth audit of security vulnerabilities across all technical documents", QueryIntent.FULL_ANALYSIS, True),
    ("synthesize all documents to formulate a unified product roadmap", QueryIntent.FULL_ANALYSIS, True),
]


@pytest.mark.parametrize("query,expected_intent,has_manifest", GOLDEN_EVAL_DATASET)
def test_20_question_golden_dataset(query: str, expected_intent: QueryIntent, has_manifest: bool):
    router = IntentRouter()
    result = router.classify_heuristic(query, has_folder_manifest=has_manifest, file_count=5 if has_manifest else 0)
    assert result.intent == expected_intent, (
        f"Failed on query: '{query}'\n"
        f"Expected: {expected_intent.value}, Got: {result.intent.value} (Reason: {result.reason})"
    )
    assert result.confidence >= 0.85, f"Confidence too low ({result.confidence}) for query: '{query}'"


def test_short_queries_with_folder_manifest():
    router = IntentRouter()
    queries = [
        "what's here",
        "what is here",
        "what do we have here",
        "overview",
        "folder contents",
        "inventory",
        "summarize",
    ]
    for q in queries:
        res = router.classify_heuristic(q, has_folder_manifest=True, file_count=3)
        assert res.intent == QueryIntent.OVERVIEW, f"Expected OVERVIEW for '{q}', got {res.intent}"


def test_empty_query_fallback():
    router = IntentRouter()
    res_manifest = router.classify_heuristic("", has_folder_manifest=True)
    assert res_manifest.intent == QueryIntent.OVERVIEW

    res_no_manifest = router.classify_heuristic("   ", has_folder_manifest=False)
    assert res_no_manifest.intent == QueryIntent.DEEP_FACT


def test_async_route_with_llm_fallback():
    class FakeLLM:
        def __init__(self):
            self._generate_with_fallback = AsyncMock()

    class FakeResp:
        def __init__(self, text: str):
            self.text = text

    fake_llm = FakeLLM()
    fake_llm._generate_with_fallback.return_value = FakeResp(
        '{"intent": "COMPARE", "confidence": 0.98, "reason": "User is contrasting two models"}'
    )

    router = IntentRouter(llm_service=fake_llm)
    # Ambiguous prompt with low heuristic confidence
    result = asyncio.run(
        router.route(
            query="Alpha or Beta for production?",
            has_folder_manifest=False,
            use_llm_fallback=True,
        )
    )

    assert result.intent == QueryIntent.COMPARE
    assert result.method == "llm"
    assert result.confidence == 0.98
