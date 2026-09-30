from fastapi.testclient import TestClient

import main


client = TestClient(main.app)


def test_health_is_available_without_internal_token() -> None:
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}


def test_embedding_endpoint_rejects_missing_service_token() -> None:
    response = client.post("/embeddings", json={"text": "private query"})

    assert response.status_code == 401


def test_rag_endpoint_rejects_missing_service_token() -> None:
    response = client.post(
        "/rag/answer",
        json={
            "message": "Question",
            "history": [],
            "sources": [
                {
                    "chunkId": "chunk-1",
                    "documentId": "file-1",
                    "fileId": "file-1",
                    "spaceId": "space-1",
                    "fileName": "note.md",
                    "fileType": "md",
                    "spaceName": "Research",
                    "excerpt": "Accessible excerpt.",
                    "pageNumber": None,
                    "chunkIndex": 0,
                    "score": 0.8,
                }
            ],
        },
    )

    assert response.status_code == 401


def test_index_endpoint_rejects_missing_service_token() -> None:
    response = client.post("/documents/index", data={"file_id": "id"})

    assert response.status_code == 401


def test_embedding_endpoint_returns_configuration_error_without_openai_key(
    monkeypatch,
) -> None:
    monkeypatch.setattr(main, "service_token", "test-service-token")
    monkeypatch.setattr(main, "client", None)
    response = client.post(
        "/embeddings",
        headers={"Authorization": "Bearer test-service-token"},
        json={"text": "test query"},
    )

    assert response.status_code == 503
    assert response.json()["detail"] == "AI service is not configured"