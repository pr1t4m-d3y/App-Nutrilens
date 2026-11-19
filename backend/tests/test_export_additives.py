import json

import pytest

from nutrilens_api.rag.additive_rows import AdditiveFileError, parse_rows
from nutrilens_api.rag.export_additives import build_entries, main

HEADER = "e_number,name,synonyms,category,allergen_tags,limits_note,source_doc_id,source_locator\n"
ROW = "E999,Test additive,testadd|t-add,test category,sulphites,test note,doc1,Annex II\n"


def manifest(tmp_path):
    path = tmp_path / "manifest.json"
    path.write_text(
        json.dumps(
            [{"id": "doc1", "title": "Test Regulation", "issuer": "i", "version": "v", "source_url": "u", "file": "f.txt"}]
        ),
        encoding="utf-8",
    )
    return path


def test_parse_rows_returns_typed_rows(tmp_path):
    csv_path = tmp_path / "a.csv"
    csv_path.write_text(HEADER + ROW, encoding="utf-8")
    rows = parse_rows(csv_path, {"doc1"})
    assert rows[0].e_number == "E999"
    assert rows[0].synonyms == ("testadd", "t-add")
    assert rows[0].allergen_tags == ("sulphites",)


def test_parse_rows_rejects_uncited_row(tmp_path):
    csv_path = tmp_path / "a.csv"
    csv_path.write_text(HEADER + "E999,Test,,cat,,note,,Annex II\n", encoding="utf-8")
    with pytest.raises(AdditiveFileError):
        parse_rows(csv_path, {"doc1"})


def test_export_builds_citation_from_manifest_title(tmp_path):
    csv_path = tmp_path / "a.csv"
    csv_path.write_text(HEADER + ROW, encoding="utf-8")
    out = tmp_path / "out" / "additives.json"
    code = main(["--csv", str(csv_path), "--manifest", str(manifest(tmp_path)), "--out", str(out)])
    assert code == 0
    entries = json.loads(out.read_text(encoding="utf-8"))
    assert entries[0]["citation"] == "Test Regulation, Annex II"
    assert entries[0]["allergen_tags"] == ["sulphites"]


def test_exported_keys_are_exactly_what_the_dart_reader_expects(tmp_path):
    csv_path = tmp_path / "a.csv"
    csv_path.write_text(HEADER + ROW, encoding="utf-8")
    rows = parse_rows(csv_path, {"doc1"})
    entry = build_entries(rows, {"doc1": "Test Regulation"})[0]
    assert set(entry) == {
        "e_number",
        "name",
        "synonyms",
        "category",
        "allergen_tags",
        "limits_note",
        "citation",
    }
