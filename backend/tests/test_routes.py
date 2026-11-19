import json

import pytest

from conftest import AUTH, FakeAgents, FakeLlm, FakeRetriever, source

GOOD_JSON = json.dumps(
    {
        "ingredients": [
            {"name": "Sodium benzoate", "impact": "bad", "reason": "A reason.", "source_ids": ["S1"]}
        ]
    }
)
BODY = {"label_text": "Ingredients: sugar, palm oil, sodium benzoate (E211)"}


def test_healthz_needs_no_auth(make_client):
    response = make_client().get("/healthz")
    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}


def test_v1_requires_token(make_client):
    client = make_client()
    assert client.post("/v1/explain", json=BODY).status_code == 401
    assert client.post("/v1/explain", json=BODY, headers={"Authorization": "Bearer nope"}).status_code == 401
    assert client.post("/v1/explain", json=BODY, headers={"Authorization": "Basic abc"}).status_code == 401
    assert client.delete("/v1/me").status_code == 401


def test_explain_returns_cited_result(make_client):
    client = make_client(llm=FakeLlm(GOOD_JSON))
    response = client.post("/v1/explain", json=BODY, headers=AUTH)
    assert response.status_code == 200
    data = response.get_json()
    assert data["status"] == "ok"
    assert data["ingredients"][0]["citations"] == ["S1"]
    assert data["model"] == "fake-model"
    assert response.headers["Cache-Control"] == "no-store"


def test_explain_rejects_extra_fields_without_echoing_input(make_client):
    client = make_client()
    body = {"label_text": "SECRET-LABEL-CONTENT sugar", "name": "A Person"}
    response = client.post("/v1/explain", json=body, headers=AUTH)
    assert response.status_code == 400
    assert response.get_json()["error"] == "invalid_request"
    assert b"SECRET-LABEL-CONTENT" not in response.data
    assert b"A Person" not in response.data


def test_explain_upstream_failure_is_502_without_details(make_client):
    client = make_client(llm=FakeLlm(error=True))
    response = client.post("/v1/explain", json=BODY, headers=AUTH)
    assert response.status_code == 502
    assert response.get_json() == {"error": "upstream_unavailable"}


def test_explain_with_no_sources_says_so(make_client):
    client = make_client(llm=FakeLlm(GOOD_JSON), retriever=FakeRetriever([]))
    data = client.post("/v1/explain", json=BODY, headers=AUTH).get_json()
    assert data["status"] == "no_source_found"
    assert data["ingredients"] == []


def test_ocr_rejects_non_images(make_client):
    client = make_client()
    response = client.post("/v1/ocr-fallback", data=b"not an image", headers=AUTH)
    assert response.status_code == 415


def test_ocr_accepts_jpeg_bytes(make_client):
    client = make_client()
    response = client.post("/v1/ocr-fallback", data=b"\xff\xd8\xff\xe0" + b"0" * 32, headers=AUTH)
    assert response.status_code == 200
    assert response.get_json()["text"] == "Sugar, salt"


def test_delete_me_contract(make_client):
    response = make_client().delete("/v1/me", headers=AUTH)
    assert response.status_code == 200
    assert response.get_json() == {"status": "ok", "server_side_records": 0}


def test_unknown_route_is_json_404(make_client):
    response = make_client().get("/v1/unknown", headers=AUTH)
    assert response.status_code == 404
    assert response.get_json() == {"error": "not_found"}


def test_rate_limit_returns_429(make_client):
    client = make_client(rate_limit_per_minute=2)
    statuses = [client.delete("/v1/me", headers=AUTH).status_code for _ in range(3)]
    assert statuses == [200, 200, 429]
    assert client.delete("/v1/me", headers=AUTH).get_json() == {"error": "rate_limited"}


def test_source_helper_is_importable():
    assert source().chunk_id == "doc:0001"


def test_search_returns_verbatim_cited_chunks(make_client):
    client = make_client()
    response = client.post("/v1/search", json={"query": "sodium benzoate"}, headers=AUTH)
    assert response.status_code == 200
    data = response.get_json()
    assert data["status"] == "ok"
    assert data["results"][0] == {
        "id": "doc:0001",
        "title": "Test Regulation",
        "locator": "Annex II",
        "snippet": "test passage",
        "method": "exact",
    }


def test_search_with_no_hits_says_so(make_client):
    client = make_client(retriever=FakeRetriever([]))
    data = client.post("/v1/search", json={"query": "anything"}, headers=AUTH).get_json()
    assert data == {"status": "no_source_found", "results": []}


@pytest.mark.parametrize("body", [{"query": "ab"}, {"query": 5}, {"query": "okay", "x": 1}, []])
def test_search_rejects_bad_requests(make_client, body):
    response = make_client().post("/v1/search", json=body, headers=AUTH)
    assert response.status_code == 400


def test_search_requires_token(make_client):
    assert make_client().post("/v1/search", json={"query": "sodium"}).status_code == 401


def test_search_retrieval_failure_is_502(make_client):
    client = make_client(retriever=FakeRetriever(error=RuntimeError("db")))
    response = client.post("/v1/search", json={"query": "sodium"}, headers=AUTH)
    assert response.status_code == 502
    assert response.get_json() == {"error": "upstream_unavailable"}


# ---- /v1/analyze (multi-agent) ----------------------------------------------


def test_analyze_requires_token(make_client):
    assert make_client().post("/v1/analyze", json=BODY).status_code == 401


def test_analyze_returns_the_explain_shape_plus_agent_details(make_client):
    agents = FakeAgents()
    client = make_client(agents=agents)
    response = client.post("/v1/analyze", json=BODY, headers=AUTH)
    assert response.status_code == 200
    data = response.get_json()
    assert data["status"] == "ok"
    assert data["ingredients"][0]["citations"] == ["S1"]
    assert data["usage"] == {"input_tokens": 10, "output_tokens": 5}
    assert data["agents"]["searches"] == 3
    assert data["agents"]["unsupported_dropped"] == 2
    assert data["agents"]["uncited_dropped"] == 1
    assert data["agents"]["stages"][0]["agent"] == "ingredient_analyst"


def test_analyze_passes_a_hashed_user_key_not_the_uid(make_client):
    from nutrilens_api.logging_utils import hash_uid

    agents = FakeAgents()
    make_client(agents=agents).post("/v1/analyze", json=BODY, headers=AUTH)
    assert agents.calls[0][1] == hash_uid("user-1")


def test_analyze_rejects_extra_fields(make_client):
    body = {"label_text": "Ingredients: sugar, salt", "name": "A Person"}
    response = make_client().post("/v1/analyze", json=body, headers=AUTH)
    assert response.status_code == 400
    assert b"A Person" not in response.data


def test_analyze_upstream_failure_is_502(make_client):
    client = make_client(agents=FakeAgents(error=True))
    response = client.post("/v1/analyze", json=BODY, headers=AUTH)
    assert response.status_code == 502
    assert response.get_json() == {"error": "upstream_unavailable"}
