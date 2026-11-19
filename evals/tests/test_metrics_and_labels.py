import json

import pytest
from labels_io import LabelError, load_labels
from metrics import (
    cer,
    cost,
    edit_distance,
    latency_summary,
    normalize,
    percentile,
    precision_recall,
    wer,
)


def test_normalize_collapses_case_and_space():
    assert normalize("  Sugar,\n  SALT ") == "sugar, salt"


def test_edit_distance_known_values():
    assert edit_distance("kitten", "sitting") == 3
    assert edit_distance("", "abc") == 3
    assert edit_distance("same", "same") == 0
    assert edit_distance(["a", "b"], ["a", "c"]) == 1


def test_cer_and_wer():
    assert cer("abc", "abd") == pytest.approx(1 / 3)
    assert wer("a b c", "a x c") == pytest.approx(1 / 3)
    assert cer("", "") == 0.0
    assert cer("", "x") == 1.0
    assert cer("Sugar", "  sugar ") == 0.0


def test_precision_recall():
    assert precision_recall(8, 2, 2) == (0.8, 0.8)
    assert precision_recall(0, 0, 0) == (None, None)
    assert precision_recall(0, 3, 0) == (0.0, None)


def test_percentile_interpolates():
    assert percentile([1, 2, 3, 4], 50) == 2.5
    assert percentile([1, 2, 3, 4], 95) == pytest.approx(3.85)
    assert percentile([7], 95) == 7.0
    with pytest.raises(ValueError):
        percentile([], 50)


def test_latency_summary():
    summary = latency_summary([1.0, 2.0, 3.0, 4.0])
    assert summary["n"] == 4
    assert summary["p50"] == 2.5
    assert summary["mean"] == 2.5
    assert (summary["min"], summary["max"]) == (1.0, 4.0)


def test_cost():
    assert cost(1_000_000, 500_000, 1.0, 2.0) == pytest.approx(2.0)


def write_label(directory, name, **overrides):
    label = {
        "id": name,
        "source": "photographed",
        "ingredients_text": "Sugar, salt",
        "ingredients": ["sugar", "salt"],
        "allergen_groups": [],
        "reviewed_by": "Reviewer",
    }
    label.update(overrides)
    (directory / f"{name}.json").write_text(json.dumps(label), encoding="utf-8")


def test_load_labels_missing_directory_is_empty(tmp_path):
    result = load_labels(tmp_path / "nope")
    assert result.labels == [] and result.unreviewed == []


def test_load_labels_excludes_unreviewed(tmp_path):
    write_label(tmp_path, "lbl_001")
    write_label(tmp_path, "lbl_002", reviewed_by="")
    (tmp_path / "lbl_001.jpg").write_bytes(b"x")
    result = load_labels(tmp_path)
    assert [label.id for label in result.labels] == ["lbl_001"]
    assert result.labels[0].image is not None
    assert result.unreviewed == ["lbl_002.json"]


def test_load_labels_reports_every_problem(tmp_path):
    write_label(tmp_path, "lbl_001", allergen_groups=["dust"])
    write_label(tmp_path, "lbl_002", source="web")
    with pytest.raises(LabelError) as error:
        load_labels(tmp_path)
    message = str(error.value)
    assert "lbl_001.json" in message and "lbl_002.json" in message
