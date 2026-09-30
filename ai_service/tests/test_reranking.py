from services.reranking import Reranker


def test_reranker_boosts_exact_terms_and_keeps_best_candidate_first() -> None:
    results = Reranker().rerank(
        [
            {"chunkId": "semantic", "excerpt": "Resources scale dynamically.", "score": 0.8},
            {"chunkId": "lexical", "excerpt": "Cloud budget forecast and expenses.", "score": 0.75},
        ],
        "cloud budget",
        limit=2,
    )

    assert [result["chunkId"] for result in results] == ["lexical", "semantic"]