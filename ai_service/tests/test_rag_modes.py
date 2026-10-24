"""Tests for Multi-Mode RAG Streaming and Synthesis in ai_service.

Verifies:
1. Context construction across OVERVIEW, DEEP_FACT, COMPARE, and FULL_ANALYSIS modes.
2. Token generation from stream_rag_answer.
3. Complete SSE stream delivery sequence: status -> text tokens -> citations -> done.
"""

import asyncio
import json
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from services.llm_service import (
    LLMService,
    get_master_prompt,
)


def test_build_rag_mode_context_overview():
    service = LLMService.__new__(LLMService)
    manifest = {
        "space_id": "space-1",
        "space_name": "Finance Space",
        "total_files": 2,
        "ready_files": 2,
        "indexing_files": 0,
        "failed_files": 0,
        "files": [
            {
                "id": "f1",
                "name": "q1_earnings.pdf",
                "type": "pdf",
                "size_bytes": 1048576,
                "status": "READY",
                "summary": "Q1 revenue reached 10M with 15% profit margin.",
                "keywords": ["finance", "earnings"],
                "page_count": 5,
            },
            {
                "id": "f2",
                "name": "tax_strategy.docx",
                "type": "docx",
                "size_bytes": 524288,
                "status": "READY",
                "summary": "Outlines corporate tax deduction methods.",
                "keywords": ["tax", "corporate"],
                "page_count": 2,
            },
        ],
    }

    system_prompt, user_content = service._build_rag_mode_context(
        intent="OVERVIEW",
        question="what files are in this folder?",
        folder_manifest=manifest,
        sources=[],
    )

    assert system_prompt == get_master_prompt()
    assert "[MODE HINT: OVERVIEW]" in user_content
    assert "Finance Space" in user_content
    assert "q1_earnings.pdf" in user_content
    assert "tax_strategy.docx" in user_content
    assert "10M with 15% profit margin" in user_content


def test_build_rag_mode_context_document():
    service = LLMService.__new__(LLMService)
    sources = [
        {
            "fileId": "file-123",
            "fileName": "Emergency_Detect.pptx",
            "pageNumber": 1,
            "chunkIndex": 0,
            "excerpt": "AI Smart Accident Detection & Emergency Alert System",
        },
        {
            "fileId": "file-123",
            "fileName": "Emergency_Detect.pptx",
            "pageNumber": 2,
            "chunkIndex": 1,
            "excerpt": "Problem Statement: Delayed emergency response leads to preventable fatalities.",
        },
    ]

    system_prompt, user_content = service._build_rag_mode_context(
        intent="DOCUMENT",
        question="explain this ppt",
        folder_manifest=None,
        sources=sources,
    )

    assert system_prompt == get_master_prompt()
    assert "[MODE HINT: DOCUMENT]" in user_content
    assert "Emergency_Detect.pptx" in user_content
    assert "[[file-123|1]]" in user_content
    assert "[[file-123|2]]" in user_content
    assert "DOCUMENT rules" in user_content


def test_build_rag_mode_context_deep_fact():
    service = LLMService.__new__(LLMService)
    sources = [
        {
            "fileId": "f-inv",
            "fileName": "invoice_1024.pdf",
            "spaceName": "Accounting",
            "pageNumber": 1,
            "excerpt": "Total Amount Due: $1,450.00 payable upon receipt.",
        }
    ]

    system_prompt, user_content = service._build_rag_mode_context(
        intent="DEEP_FACT",
        question="what is the total amount due?",
        folder_manifest=None,
        sources=sources,
    )

    assert system_prompt == get_master_prompt()
    assert "[MODE HINT: QUICK]" in user_content
    assert "invoice_1024.pdf" in user_content
    assert "Total Amount Due: $1,450.00" in user_content


def test_build_rag_mode_context_compare():
    service = LLMService.__new__(LLMService)
    sources = [
        {
            "fileName": "v1_spec.txt",
            "excerpt": "Architecture uses monolith approach.",
        },
        {
            "fileName": "v2_spec.txt",
            "excerpt": "Architecture migrated to microservices.",
        },
    ]

    system_prompt, user_content = service._build_rag_mode_context(
        intent="COMPARE",
        question="compare v1 and v2 architecture",
        folder_manifest=None,
        sources=sources,
    )

    assert system_prompt == get_master_prompt()
    assert "[MODE HINT: COMPARE]" in user_content
    assert "v1_spec.txt" in user_content
    assert "v2_spec.txt" in user_content
    assert "monolith" in user_content
    assert "microservices" in user_content


def test_build_rag_mode_context_full_analysis():
    service = LLMService.__new__(LLMService)
    manifest = {
        "space_name": "Compliance",
        "files": [{"name": "gdpr_policy.pdf", "status": "READY", "summary": "European data privacy compliance rules."}],
    }
    sources = [
        {
            "fileName": "gdpr_policy.pdf",
            "pageNumber": 3,
            "excerpt": "Article 17: Right to erasure must be honored within 30 days.",
        }
    ]

    system_prompt, user_content = service._build_rag_mode_context(
        intent="FULL_ANALYSIS",
        question="provide a full compliance audit",
        folder_manifest=manifest,
        sources=sources,
    )

    assert system_prompt == get_master_prompt()
    assert "[MODE HINT: FOLDER ANALYSIS]" in user_content
    assert "Compliance" in user_content
    assert "Right to erasure" in user_content


def test_stream_rag_answer_yields_tokens():
    service = LLMService.__new__(LLMService)
    service._bounded_history = MagicMock(return_value=[])

    async def fake_stream(*args, **kwargs):
        for token in ["This ", "folder ", "contains ", "financial ", "reports."]:
            yield token

    service._generate_stream_with_fallback = fake_stream

    async def run_test():
        tokens = []
        async for t in service.stream_rag_answer(
            question="summarize folder",
            history=[],
            folder_manifest={"space_name": "Test Space", "total_files": 1, "files": []},
            sources=[],
            intent="OVERVIEW",
        ):
            tokens.append(t)
        return tokens

    result = asyncio.run(run_test())
    assert result == ["This ", "folder ", "contains ", "financial ", "reports."]


def test_post_rag_answer_stream_sse_protocol():
    """Validates FastAPI /rag/answer/stream endpoint adheres strictly to SSE contract."""
    from main import app

    client = TestClient(app)

    async def fake_tokens(*args, **kwargs):
        for chunk in ["In ", "this ", "folder..."]:
            yield chunk

    payload = {
        "message": "tell me about the files in this folder",
        "history": [],
        "folder_manifest": {
            "space_id": "space-test-id",
            "space_name": "Project Alpha",
            "total_files": 1,
            "ready_files": 1,
            "indexing_files": 0,
            "failed_files": 0,
            "files": [
                {
                    "id": "f-1",
                    "name": "readme.md",
                    "type": "md",
                    "size_bytes": 1024,
                    "status": "READY",
                    "summary": "Project Alpha description.",
                    "keywords": ["alpha", "readme"],
                    "page_count": 1,
                }
            ],
        },
        "sources": [],
    }

    with patch("main.service_token", "test-token"):
        with patch("main._require_llm_service") as mock_req:
            mock_llm = MagicMock()
            mock_llm.stream_rag_answer = fake_tokens
            mock_req.return_value = mock_llm

            resp = client.post(
                "/rag/answer/stream",
                json=payload,
                headers={"Authorization": "Bearer test-token"},
            )

            assert resp.status_code == 200
            assert resp.headers["content-type"].startswith("text/event-stream")

            lines = [line.strip() for line in resp.text.split("\n") if line.strip()]
            data_events = [json.loads(line[len("data: "):]) for line in lines if line.startswith("data: ")]

            # Verify Event 1: Status
            assert data_events[0].get("event") == "status"
            assert "Scanning 1 files in Project Alpha folder" in data_events[0].get("message")

            # Verify Event 2: Tokens
            token_events = [e for e in data_events if "text" in e]
            assert "".join(e["text"] for e in token_events) == "In this folder..."

            # Verify Event 3: Citations
            citations_events = [e for e in data_events if "citations" in e]
            assert len(citations_events) == 1
            assert len(citations_events[0]["citations"]) == 1
            assert citations_events[0]["citations"][0]["file_name"] == "readme.md"

            # Verify Event 4: Done with Search Metadata
            done_events = [e for e in data_events if e.get("done") is True]
            assert len(done_events) == 1
            assert done_events[0]["search_metadata"]["mode"] == "OVERVIEW"
            assert done_events[0]["search_metadata"]["total_files"] == 1
