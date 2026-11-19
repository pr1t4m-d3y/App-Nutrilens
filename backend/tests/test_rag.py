import json

import pytest

from nutrilens_api.rag.additives import AdditiveFileError, load_additives
from nutrilens_api.rag.chunker import MAX_CHARS, Chunk, chunk_document
from nutrilens_api.rag.enumbers import extract_e_numbers
from nutrilens_api.rag.ingest import ManifestError, load_manifest

HEADER = "e_number,name,synonyms,category,allergen_tags,limits_note,source_doc_id,source_locator\n"


def test_extract_e_numbers_normalises_and_dedupes():
    text = "Contains E211, INS 330 and e160a; again E211 and E160A."
    assert extract_e_numbers(text) == ["E211", "E330", "E160a"]


def test_extract_e_numbers_ignores_plain_words():
    assert extract_e_numbers("Intro line with insulin and the letter E.") == []


def test_chunker_keeps_locators_and_e_numbers():
    text = (
        "Intro line before headings E211 appears here.\n\n"
        "Article 3\nSome text about the article.\n\n"
        "ANNEX II\nEntry E 330 and INS 211 listed.\n"
    )
    chunks = chunk_document("doc", text)
    assert [c.locator for c in chunks] == ["Preamble", "Article 3", "Annex II"]
    assert [c.chunk_id for c in chunks] == ["doc:0000", "doc:0001", "doc:0002"]
    assert chunks[0].e_numbers == ("E211",)
    assert chunks[2].e_numbers == ("E330", "E211")


def test_chunker_splits_long_sections_but_keeps_locator():
    paragraph = ("lorem " * 80).strip()
    text = "Article 1\n" + "\n\n".join([paragraph] * 8)
    chunks = chunk_document("doc", text)
    assert len(chunks) >= 2
    assert all(c.locator == "Article 1" for c in chunks)
    assert all(len(c.text) <= MAX_CHARS for c in chunks)


def test_chunker_returns_nothing_for_empty_text():
    assert chunk_document("doc", "  \n\n ") == []


def write_csv(tmp_path, rows: str):
    path = tmp_path / "additives.csv"
    path.write_text(HEADER + rows, encoding="utf-8")
    return path


CHUNKS = [Chunk("doc1", 0, "Annex II", "text", ("E211",))]


def test_load_additives_links_chunks(tmp_path):
    path = write_csv(tmp_path, "E211,Name,a|b,preservative,,a limit note,doc1,Annex II\n")
    records = load_additives(path, {"doc1"}, CHUNKS)
    assert records[0].e_number == "E211"
    assert records[0].synonyms == ("a", "b")
    assert records[0].chunk_ids == ("doc1:0000",)


@pytest.mark.parametrize(
    "row",
    [
        "E211,Name,,preservative,,note,,Annex II\n",
        "E211,Name,,preservative,,note,unknown,Annex II\n",
        "not-a-code,Name,,preservative,,note,doc1,Annex II\n",
        "E211,Name,,preservative,,note,doc1,Annex II\nE211,Name,,preservative,,note,doc1,Annex II\n",
    ],
)
def test_load_additives_rejects_uncited_or_bad_rows(tmp_path, row):
    with pytest.raises(AdditiveFileError):
        load_additives(write_csv(tmp_path, row), {"doc1"}, CHUNKS)


def test_load_additives_requires_all_columns(tmp_path):
    path = tmp_path / "a.csv"
    path.write_text("e_number,name\nE211,x\n", encoding="utf-8")
    with pytest.raises(AdditiveFileError):
        load_additives(path, {"doc1"}, CHUNKS)


def test_load_manifest_validates_entries(tmp_path):
    good = [{"id": "a", "title": "t", "issuer": "i", "version": "v", "source_url": "u", "file": "f.pdf"}]
    path = tmp_path / "manifest.json"
    path.write_text(json.dumps(good), encoding="utf-8")
    assert load_manifest(path)[0]["id"] == "a"

    path.write_text(json.dumps([{"id": "a"}]), encoding="utf-8")
    with pytest.raises(ManifestError):
        load_manifest(path)

    path.write_text(json.dumps(good + good), encoding="utf-8")
    with pytest.raises(ManifestError):
        load_manifest(path)
