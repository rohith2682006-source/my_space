"""Query Intent Router for Spaces RAG.

Routes incoming user queries into one of four operational modes:
1. OVERVIEW: Directory-level questions, file listings, and whole-folder inventories.
   Answered directly using the folder manifest and per-file executive summaries.
2. DEEP_FACT: Specific factual questions looking for pinpoint details inside documents.
   Answered using vector / hybrid semantic chunk retrieval.
3. COMPARE: Cross-file comparison queries contrasting two or more documents/entities.
   Answered by retrieving chunks and summaries across multiple target files.
4. FULL_ANALYSIS: Comprehensive, multi-document synthesis or holistic audits across all files.
   Answered by combining the folder manifest with comprehensive chunk synthesis.
"""

from __future__ import annotations

import json
import logging
import re
from dataclasses import dataclass
from enum import Enum
from typing import Any, Optional

logger = logging.getLogger("spaces.ai.intent_router")


class QueryIntent(str, Enum):
    CHAT = "CHAT"
    OVERVIEW = "OVERVIEW"
    DEEP_FACT = "DEEP_FACT"
    COMPARE = "COMPARE"
    FULL_ANALYSIS = "FULL_ANALYSIS"
    DOCUMENT = "DOCUMENT"


@dataclass(frozen=True)
class IntentRouteResult:
    intent: QueryIntent
    confidence: float
    reason: str
    method: str = "heuristic"

    def to_dict(self) -> dict[str, Any]:
        return {
            "intent": self.intent.value,
            "confidence": self.confidence,
            "reason": self.reason,
            "method": self.method,
        }


# ============================================================================
# Heuristic Pattern Definitions
# ============================================================================

# 0. Conversational Chat & Greeting Patterns
_CHAT_PATTERNS = [
    re.compile(r"^\s*(hi|hii+|hello+|heyy*|hey\s+there|good\s+(morning|afternoon|evening)|howdy|sup|yo|hola)\b[!?.]*\s*$", re.IGNORECASE),
    re.compile(r"\b(how\s+are\s+you|who\s+are\s+you|what\s+(is\s+your\s+name|can\s+you\s+do)|tell\s+me\s+about\s+yourself)\b", re.IGNORECASE),
    re.compile(r"\b(thank\s+you|thanks|appreciate\s+it|good\s+job|bye|goodbye|see\s+you)\b", re.IGNORECASE),
]

# 1. Comparison Patterns
_COMPARE_PATTERNS = [
    re.compile(r"\b(compare|comparison|contrasting?)\b", re.IGNORECASE),
    re.compile(r"\b(differences?|diff)\s+(between|among)\b", re.IGNORECASE),
    re.compile(r"\bversus\b|\bvs\.?\b", re.IGNORECASE),
    re.compile(r"\bhow\s+does\s+.+\s+(compare\s+to|differ\s+from)\b", re.IGNORECASE),
    re.compile(r"\bwhat\s+(is|are)\s+the\s+differences?\s+between\b", re.IGNORECASE),
    re.compile(r"\bhow\s+do\s+.+\s+(differ|compare)\b", re.IGNORECASE),
    re.compile(r"\bsimilarities\s+and\s+differences\b", re.IGNORECASE),
]

# 2. Comprehensive Full Analysis Patterns
_FULL_ANALYSIS_PATTERNS = [
    re.compile(r"\b(full|in-depth|deep|exhaustive)\s+(analysis|audit|review|evaluation|investigation)\b", re.IGNORECASE),
    re.compile(r"\bcomprehensive\s+(analysis|synthesis|review|audit|assessment|breakdown|summary)\b", re.IGNORECASE),
    re.compile(r"\b(risk\s+analysis|gap\s+analysis|swot\s+analysis)\s+across\s+(all|the)\b", re.IGNORECASE),
    re.compile(r"\bextract\s+all\b.*(across|from)\s+(all|the)\s+(files|documents|policies|spaces)\b", re.IGNORECASE),
    re.compile(r"\b(synthesize|synthesis\s+of)\s+(all\s+|across\s+all\s+|the\s+)?(documents|files|information|data)\b", re.IGNORECASE),
    re.compile(r"\bholistic\s+(overview|synthesis|analysis|assessment)\b", re.IGNORECASE),
    re.compile(r"\bcomplete\s+compliance\s+audit\b", re.IGNORECASE),
]

# 2.5 Single-Document Analysis & Review Patterns
_DOCUMENT_PATTERNS = [
    re.compile(r"\b(tell\s+me\s+about|what\s+is\s+in|what('?s|\s+is)\s+in|explain|summarize|walk\s*through|review|analyze|analyse|breakdown\s+of)\s+(this\s+|the\s+)?(file|document|presentation|deck|ppt|pptx|pdf|doc|docx|sheet|spreadsheet)\b", re.IGNORECASE),
    re.compile(r"\b(slide\s+by\s+slide|page\s+by\s+page|section\s+by\s+section|walkthrough)\b", re.IGNORECASE),
    re.compile(r"\bwhat\s+(is|does)\s+(this\s+|the\s+)?(file|document|deck|presentation|ppt|pptx|pdf|doc)\s+(about|say|cover|contain)\b", re.IGNORECASE),
    re.compile(r"\b(explain|summarize|review|analyze|analyse|read|inspect)\s+(this|the)\s+.*?\.(pptx?|pdf|docx?|txt|csv|xlsx?)\b", re.IGNORECASE),
    re.compile(r"\b(tell\s+me\s+about)\s+.*?\.(pptx?|pdf|docx?|txt|csv|xlsx?)\b", re.IGNORECASE),
    re.compile(r"\b(what\s+is\s+in)\s+.*?\.(pptx?|pdf|docx?|txt|csv|xlsx?)\b", re.IGNORECASE),
    re.compile(r"\b(explain|summarize|analyze|review)\s+(this|the)\s+(deck|pitch\s*deck|slides?|presentation)\b", re.IGNORECASE),
    re.compile(r"\bhow\s+does\s+(this\s+|the\s+)?(system|project|solution|pipeline|deck|file)\s+work\b", re.IGNORECASE),
]

# 3. Whole-Folder / Directory Overview Patterns
_OVERVIEW_PATTERNS = [
    re.compile(r"\btell\s+me\s+about\s+(the\s+|all\s+)?files\b", re.IGNORECASE),
    re.compile(r"\bwhat\s+(files|documents|items)\s+(are|do\s+we\s+have|exist|are\s+stored)\b", re.IGNORECASE),
    re.compile(r"\bwhat\s+does\s+this\s+(folder|space|directory)\s+contain\b", re.IGNORECASE),
    re.compile(r"\bwhat('?s|\s+is)\s+in\s+this\s+(folder|space|directory)\b", re.IGNORECASE),
    re.compile(r"\bwhat('?s|\s+is)\s+in\s+here\b", re.IGNORECASE),
    re.compile(r"\blist\s+(all\s+|the\s+)?(files|documents|contents)\b", re.IGNORECASE),
    re.compile(r"\b(show|give)\s+me\s+(all\s+|the\s+)?(files|documents)\b", re.IGNORECASE),
    re.compile(r"\bsummarize\s+(this\s+|the\s+)?(folder|space|directory)\b", re.IGNORECASE),
    re.compile(r"\b(folder|space|directory)\s+(summary|overview|inventory|catalog|breakdown)\b", re.IGNORECASE),
    re.compile(r"\bbreakdown\s+of\s+(the\s+|all\s+)?(files|documents)\b", re.IGNORECASE),
    re.compile(r"\b(table|inventory|list|catalog)\s+of\s+(files|documents|topics|contents)\b", re.IGNORECASE),
    re.compile(r"\bwhat\s+kind\s+of\s+(documents|files)\b", re.IGNORECASE),
    re.compile(r"\bwhat\s+topics\s+are\s+covered\s+in\s+this\s+(folder|space)\b", re.IGNORECASE),
    re.compile(r"\bgive\s+me\s+an\s+overview\s+of\s+this\s+(folder|space|directory)\b", re.IGNORECASE),
]

# 4. Deep Fact Inquiries
_DEEP_FACT_PATTERNS = [
    re.compile(r"\bwhat\s+is\s+the\s+(amount|total|price|cost|date|deadline|clause|rate|salary|fee|address|phone|email|term|version|id|number|limit|threshold)\b", re.IGNORECASE),
    re.compile(r"\bwho\s+(signed|authored|sent|approved|managed|is\s+the\s+(author|owner|signer|contact))\b", re.IGNORECASE),
    re.compile(r"\bwhen\s+(does|did|will|is|was)\b", re.IGNORECASE),
    re.compile(r"\bwhere\s+(is|are|can\s+i\s+find)\b", re.IGNORECASE),
    re.compile(r"\bhow\s+much\b|\bhow\s+many\b", re.IGNORECASE),
    re.compile(r"\b(find|locate|extract)\s+the\s+(section|paragraph|clause|table|formula)\b", re.IGNORECASE),
    re.compile(r"\binvoice\s*#?\s*\d+", re.IGNORECASE),
    re.compile(r"\bsection\s+\d+(\.\d+)*\b", re.IGNORECASE),
    re.compile(r"\bpage\s+\d+\b", re.IGNORECASE),
]


# ============================================================================
# Intent Router Class
# ============================================================================

class IntentRouter:
    """Classifies user queries into RAG operational modes."""

    def __init__(self, llm_service: Optional[Any] = None) -> None:
        self._llm = llm_service

    def classify_heuristic(
        self,
        query: str,
        has_folder_manifest: bool = False,
        file_count: int = 0,
    ) -> IntentRouteResult:
        """Deterministically classifies query intent using regex heuristics.
        
        Zero latency, highly accurate for standard user workflows.
        """
        cleaned = " ".join(query.strip().split())
        if not cleaned:
            return IntentRouteResult(
                intent=QueryIntent.OVERVIEW if has_folder_manifest else QueryIntent.DEEP_FACT,
                confidence=0.5,
                reason="Empty query defaulted based on folder manifest presence",
                method="heuristic",
            )

        # 0. Check for CHAT / greeting / conversational intent
        for pat in _CHAT_PATTERNS:
            if pat.search(cleaned):
                return IntentRouteResult(
                    intent=QueryIntent.CHAT,
                    confidence=0.98,
                    reason=f"Matched conversational chat pattern: {pat.pattern}",
                    method="heuristic",
                )

        # 1. Check for COMPARE intent first (often contains specific file names or 'vs')
        for pat in _COMPARE_PATTERNS:
            if pat.search(cleaned):
                return IntentRouteResult(
                    intent=QueryIntent.COMPARE,
                    confidence=0.95,
                    reason=f"Matched comparison pattern: {pat.pattern}",
                    method="heuristic",
                )

        # 2. Check for FULL_ANALYSIS intent
        for pat in _FULL_ANALYSIS_PATTERNS:
            if pat.search(cleaned):
                return IntentRouteResult(
                    intent=QueryIntent.FULL_ANALYSIS,
                    confidence=0.92,
                    reason=f"Matched full analysis pattern: {pat.pattern}",
                    method="heuristic",
                )

        # 2.5 Check for DOCUMENT analysis / walkthrough intent
        for pat in _DOCUMENT_PATTERNS:
            if pat.search(cleaned):
                return IntentRouteResult(
                    intent=QueryIntent.DOCUMENT,
                    confidence=0.96,
                    reason=f"Matched document analysis pattern: {pat.pattern}",
                    method="heuristic",
                )

        # Check if query directly references a single file with extension (e.g., 'Emergency Detect.pptx')
        if re.search(r"\b[\w\-_\.]+\.(pptx?|pdf|docx?|txt|csv|xlsx?)\b", cleaned, re.IGNORECASE):
            return IntentRouteResult(
                intent=QueryIntent.DOCUMENT,
                confidence=0.92,
                reason="Query explicitly references a document filename",
                method="heuristic",
            )

        # 3. Check for OVERVIEW intent
        for pat in _OVERVIEW_PATTERNS:
            if pat.search(cleaned):
                return IntentRouteResult(
                    intent=QueryIntent.OVERVIEW,
                    confidence=0.96,
                    reason=f"Matched overview pattern: {pat.pattern}",
                    method="heuristic",
                )

        # 4. Contextual short queries when folder manifest is explicitly attached
        lower = cleaned.lower().rstrip("?.!")
        if has_folder_manifest:
            short_overview_prompts = {
                "what's here",
                "whats here",
                "what is here",
                "what do we have",
                "what do we have here",
                "overview",
                "summary",
                "summarize",
                "files",
                "documents",
                "folder contents",
                "contents",
                "inventory",
                "what are these files",
                "explain this folder",
                "describe this folder",
            }
            if lower in short_overview_prompts:
                return IntentRouteResult(
                    intent=QueryIntent.OVERVIEW,
                    confidence=0.94,
                    reason="Matched short directory inquiry with folder manifest attached",
                    method="heuristic",
                )

        # 5. Check for DEEP_FACT patterns
        for pat in _DEEP_FACT_PATTERNS:
            if pat.search(cleaned):
                return IntentRouteResult(
                    intent=QueryIntent.DEEP_FACT,
                    confidence=0.90,
                    reason=f"Matched deep fact pattern: {pat.pattern}",
                    method="heuristic",
                )

        # 6. Default fallback
        # If question contains words like 'folder' or 'space' or 'files' in a general sense:
        if re.search(r"\b(folder|space|files|documents)\b", cleaned, re.IGNORECASE) and has_folder_manifest:
            return IntentRouteResult(
                intent=QueryIntent.OVERVIEW,
                confidence=0.75,
                reason="Query mentions folder/files in context of attached manifest",
                method="heuristic",
            )

        # If no folder or documents are attached, default to CHAT rather than DEEP_FACT
        if not has_folder_manifest and file_count == 0:
            return IntentRouteResult(
                intent=QueryIntent.CHAT,
                confidence=0.85,
                reason="No folder or files attached, defaulting to conversational chat",
                method="heuristic",
            )

        # Default to DEEP_FACT as targeted chunk retrieval answers specific questions best
        return IntentRouteResult(
            intent=QueryIntent.DEEP_FACT,
            confidence=0.70,
            reason="Defaulted to deep fact retrieval for content question",
            method="heuristic",
        )

    async def route(
        self,
        query: str,
        has_folder_manifest: bool = False,
        file_count: int = 0,
        use_llm_fallback: bool = False,
    ) -> IntentRouteResult:
        """Routes query with heuristic first, optionally using LLM for low confidence."""
        res = self.classify_heuristic(query, has_folder_manifest, file_count)

        if not use_llm_fallback or res.confidence >= 0.85 or not self._llm:
            return res

        # LLM fallback for ambiguous queries
        try:
            return await self._route_with_llm(query, has_folder_manifest, file_count)
        except Exception as e:
            logger.warning("LLM intent routing failed (%s), using heuristic result: %s", e, res)
            return res

    async def _route_with_llm(
        self,
        query: str,
        has_folder_manifest: bool,
        file_count: int,
    ) -> IntentRouteResult:
        """Uses fast LLM classification for ambiguous queries."""
        prompt = (
            "You are a query intent classifier for a document workspace.\n"
            f"User Query: \"{query}\"\n"
            f"Folder Manifest Attached: {has_folder_manifest} ({file_count} files)\n\n"
            "Classify this query into EXACTLY ONE of the following 5 intents:\n"
            "- OVERVIEW: Inquiries asking what files exist, summaries of the folder, directory listings, or high-level file topics.\n"
            "- DOCUMENT: Inquiries asking to explain, summarize, walk through, review, or analyze a single file, deck, presentation, or report.\n"
            "- DEEP_FACT: Specific questions looking for pinpoint facts, dates, numbers, clauses, or details inside documents.\n"
            "- COMPARE: Questions comparing or contrasting two or more files, versions, or entities.\n"
            "- FULL_ANALYSIS: Deep cross-document analysis, risk audits, or comprehensive synthesis across all documents.\n\n"
            "Return JSON ONLY in this format:\n"
            "{\"intent\": \"OVERVIEW\" | \"DOCUMENT\" | \"DEEP_FACT\" | \"COMPARE\" | \"FULL_ANALYSIS\", \"confidence\": 0.95, \"reason\": \"explanation\"}"
        )

        resp = await self._llm._generate_with_fallback(
            prompt=prompt,
            system_prompt="You are an intent classification system. Output valid JSON only.",
        )
        raw = resp.text.strip()
        if raw.startswith("```"):
            raw = re.sub(r"^```(?:json)?\n?", "", raw)
            raw = re.sub(r"\n?```$", "", raw)

        data = json.loads(raw)
        intent_str = str(data.get("intent", "DEEP_FACT")).upper()
        intent = QueryIntent[intent_str] if intent_str in QueryIntent.__members__ else QueryIntent.DEEP_FACT
        confidence = float(data.get("confidence", 0.9))
        reason = str(data.get("reason", "Classified by LLM"))

        return IntentRouteResult(
            intent=intent,
            confidence=confidence,
            reason=reason,
            method="llm",
        )
