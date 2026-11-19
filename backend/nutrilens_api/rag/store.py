"""PostgreSQL + pgvector storage for regulation documents, chunks and the
structured additive table.

The corpus is small (a handful of regulations), so vector search is an exact
scan with no approximate index. That keeps results deterministic and avoids a
dependency on a specific pgvector version.
"""

from __future__ import annotations

from collections.abc import Iterator, Sequence
from contextlib import contextmanager
from dataclasses import dataclass

import psycopg
from pgvector import Vector
from pgvector.psycopg import register_vector

from .chunker import Chunk


@dataclass(frozen=True)
class DocumentRecord:
    doc_id: str
    title: str
    issuer: str
    version: str
    source_url: str
    sha256: str


@dataclass(frozen=True)
class AdditiveRecord:
    e_number: str
    name: str
    synonyms: tuple[str, ...]
    category: str
    allergen_tags: tuple[str, ...]
    limits_note: str
    source_doc_id: str
    source_locator: str
    chunk_ids: tuple[str, ...]


@dataclass(frozen=True)
class StoredChunk:
    chunk_id: str
    doc_id: str
    doc_title: str
    locator: str
    text: str
    distance: float | None = None


def schema_statements(embedding_dim: int) -> list[str]:
    dim = int(embedding_dim)
    return [
        """CREATE TABLE IF NOT EXISTS documents (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            issuer TEXT NOT NULL,
            version TEXT NOT NULL,
            source_url TEXT NOT NULL,
            sha256 TEXT NOT NULL
        )""",
        f"""CREATE TABLE IF NOT EXISTS chunks (
            id TEXT PRIMARY KEY,
            doc_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
            locator TEXT NOT NULL,
            text TEXT NOT NULL,
            e_numbers TEXT[] NOT NULL DEFAULT '{{}}',
            embedding vector({dim}) NOT NULL
        )""",
        "CREATE INDEX IF NOT EXISTS chunks_e_numbers_idx ON chunks USING gin (e_numbers)",
        """CREATE TABLE IF NOT EXISTS additives (
            e_number TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            synonyms TEXT[] NOT NULL DEFAULT '{}',
            category TEXT NOT NULL,
            allergen_tags TEXT[] NOT NULL DEFAULT '{}',
            limits_note TEXT NOT NULL,
            source_doc_id TEXT NOT NULL REFERENCES documents(id),
            source_locator TEXT NOT NULL,
            chunk_ids TEXT[] NOT NULL DEFAULT '{}'
        )""",
    ]


class Store:
    def __init__(self, conninfo: str, embedding_dim: int):
        self._conninfo = conninfo
        self._dim = int(embedding_dim)

    @contextmanager
    def _connect(self, register: bool = True) -> Iterator[psycopg.Connection]:
        # The connection context manager commits on success and rolls back on error.
        with psycopg.connect(self._conninfo) as conn:
            if register:
                register_vector(conn)
            yield conn

    def init_schema(self) -> None:
        # The extension must exist before the vector type can be registered.
        with self._connect(register=False) as conn:
            conn.execute("CREATE EXTENSION IF NOT EXISTS vector")
            for statement in schema_statements(self._dim):
                conn.execute(statement)

    def upsert_document(self, doc: DocumentRecord) -> None:
        with self._connect() as conn:
            conn.execute(
                """INSERT INTO documents (id, title, issuer, version, source_url, sha256)
                   VALUES (%s, %s, %s, %s, %s, %s)
                   ON CONFLICT (id) DO UPDATE SET
                     title = EXCLUDED.title, issuer = EXCLUDED.issuer,
                     version = EXCLUDED.version, source_url = EXCLUDED.source_url,
                     sha256 = EXCLUDED.sha256""",
                (doc.doc_id, doc.title, doc.issuer, doc.version, doc.source_url, doc.sha256),
            )

    def replace_chunks(self, doc_id: str, rows: Sequence[tuple[Chunk, list[float]]]) -> None:
        with self._connect() as conn:
            conn.execute("DELETE FROM chunks WHERE doc_id = %s", (doc_id,))
            with conn.cursor() as cur:
                cur.executemany(
                    """INSERT INTO chunks (id, doc_id, locator, text, e_numbers, embedding)
                       VALUES (%s, %s, %s, %s, %s, %s)""",
                    [
                        (
                            chunk.chunk_id,
                            chunk.doc_id,
                            chunk.locator,
                            chunk.text,
                            list(chunk.e_numbers),
                            Vector(vector),
                        )
                        for chunk, vector in rows
                    ],
                )

    def upsert_additives(self, rows: Sequence[AdditiveRecord]) -> None:
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.executemany(
                    """INSERT INTO additives (e_number, name, synonyms, category, allergen_tags,
                                              limits_note, source_doc_id, source_locator, chunk_ids)
                       VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                       ON CONFLICT (e_number) DO UPDATE SET
                         name = EXCLUDED.name, synonyms = EXCLUDED.synonyms,
                         category = EXCLUDED.category, allergen_tags = EXCLUDED.allergen_tags,
                         limits_note = EXCLUDED.limits_note, source_doc_id = EXCLUDED.source_doc_id,
                         source_locator = EXCLUDED.source_locator, chunk_ids = EXCLUDED.chunk_ids""",
                    [
                        (
                            r.e_number,
                            r.name,
                            list(r.synonyms),
                            r.category,
                            list(r.allergen_tags),
                            r.limits_note,
                            r.source_doc_id,
                            r.source_locator,
                            list(r.chunk_ids),
                        )
                        for r in rows
                    ],
                )

    def search_vector(self, embedding: list[float], limit: int) -> list[StoredChunk]:
        with self._connect() as conn:
            rows = conn.execute(
                """SELECT c.id, c.doc_id, d.title, c.locator, c.text,
                          c.embedding <=> %(q)s AS distance
                   FROM chunks c JOIN documents d ON d.id = c.doc_id
                   ORDER BY c.embedding <=> %(q)s
                   LIMIT %(k)s""",
                {"q": Vector(embedding), "k": int(limit)},
            ).fetchall()
        return [StoredChunk(r[0], r[1], r[2], r[3], r[4], float(r[5])) for r in rows]

    def chunks_for_e_numbers(self, codes: Sequence[str], limit: int) -> list[StoredChunk]:
        if not codes:
            return []
        with self._connect() as conn:
            rows = conn.execute(
                """SELECT c.id, c.doc_id, d.title, c.locator, c.text
                   FROM chunks c JOIN documents d ON d.id = c.doc_id
                   WHERE c.e_numbers && %(codes)s::text[]
                   ORDER BY c.id
                   LIMIT %(k)s""",
                {"codes": list(codes), "k": int(limit)},
            ).fetchall()
        return [StoredChunk(r[0], r[1], r[2], r[3], r[4]) for r in rows]
