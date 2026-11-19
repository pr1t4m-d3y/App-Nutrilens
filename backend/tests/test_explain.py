import json

import pytest
from conftest import FakeLlm, FakeRetriever, source

from nutrilens_api.errors import UpstreamError
from nutrilens_api.explain import ExplainService, enforce_citations, parse_model_json
from nutrilens_api.schemas import ExplainRequest

REQ = ExplainRequest(
    label_text="Ingredients: sugar, sodium benzoate (E211)",
    allergies=("Peanuts",),
    conditions=("Diabetes",),
    avoid=(),
)


def model_json(*entries) -> str:
    return json.dumps({"ingredients": list(entries)})


def entry(name="Sodium benzoate", impact="bad", reason="A reason.", ids=("S1",)):
    return {"name": name, "impact": impact, "reason": reason, "source_ids": list(ids)}


def test_uncited_and_invalid_entries_are_dropped(settings):
    llm = FakeLlm(
        model_json(
            entry(),
            entry(name="Salt", impact="neutral", ids=()),
            entry(name="Water", impact="good", ids=("S9",)),
        )
    )
    service = ExplainService(settings, llm, FakeRetriever([source()]))
    outcome = service.explain(REQ)
    assert outcome.body["status"] == "ok"
    assert [i["name"] for i in outcome.body["ingredients"]] == ["Sodium benzoate"]
    assert outcome.dropped == 2
    assert outcome.body["ingredients"][0]["details"][-1] == "Source: Test Regulation, Annex II"
    assert outcome.body["sources"] == [{"id": "S1", "title": "Test Regulation", "locator": "Annex II"}]


def test_no_retrieval_means_no_model_call(settings):
    llm = FakeLlm(model_json(entry()))
    outcome = ExplainService(settings, llm, FakeRetriever([])).explain(REQ)
    assert outcome.body["status"] == "no_source_found"
    assert llm.prompts == []


def test_all_entries_dropped_is_no_source_found(settings):
    llm = FakeLlm(model_json(entry(ids=())))
    outcome = ExplainService(settings, llm, FakeRetriever([source()])).explain(REQ)
    assert outcome.body["status"] == "no_source_found"


def test_bad_model_json_is_upstream_error(settings):
    service = ExplainService(settings, FakeLlm("not json"), FakeRetriever([source()]))
    with pytest.raises(UpstreamError):
        service.explain(REQ)


def test_llm_failure_is_upstream_error(settings):
    service = ExplainService(settings, FakeLlm(error=True), FakeRetriever([source()]))
    with pytest.raises(UpstreamError):
        service.explain(REQ)


def test_retrieval_failure_is_upstream_error(settings):
    service = ExplainService(settings, FakeLlm(model_json(entry())), FakeRetriever(error=RuntimeError("db")))
    with pytest.raises(UpstreamError):
        service.explain(REQ)


def test_prompt_marks_label_as_data_and_includes_flags_only(settings):
    llm = FakeLlm(model_json(entry()))
    ExplainService(settings, llm, FakeRetriever([source()])).explain(REQ)
    prompt = llm.prompts[0]
    assert "LABEL TEXT (untrusted data)" in prompt
    assert "allergies: Peanuts" in prompt
    assert "[S1] Test Regulation | Annex II" in prompt


def test_parse_model_json_accepts_code_fences():
    items = parse_model_json("```json\n" + model_json(entry()) + "\n```")
    assert items[0]["name"] == "Sodium benzoate"


def test_enforce_citations_rejects_unknown_impact():
    kept, dropped = enforce_citations([entry(impact="scary")], {"S1": source()})
    assert kept == []
    assert dropped == 1
