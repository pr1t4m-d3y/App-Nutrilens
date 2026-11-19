# Forward Deployed Engineer requirements: where each shows up in this repo

This maps the requirements in `claude.md` (Google FDE Intern, Cloud Consulting) to concrete code. "Written" means the code exists in the repo. Nothing has been compiled, run or deployed, so "written" is not "works". Items that need data or inputs only the owner can supply are marked "needs input". Drishti already covers the rows marked "covered there" and they are not repeated here.

| Req | Requirement | Technology and skills shown | Where | State |
|---|---|---|---|---|
| R2 | Production AI on Google Cloud, concept to launch | Cloud Run, Cloud Build, Artifact Registry, Cloud SQL, Secret Manager, IAM service account, Vertex AI, Firebase Auth; reproducible scripts with teardown and a budget alert | `backend/Dockerfile`, `deploy/` | Written; not deployed (needs GCP project, region, budget). "Real users" is not claimed |
| R3 | Structured and unstructured data pipelines, vector DB and RAG | PDF and text ingestion, structure-aware chunking, Vertex AI embeddings, PostgreSQL with pgvector, structured additive table linked to chunks, hybrid exact-match plus vector retrieval, citation enforcement | `backend/nutrilens_api/rag/`, `explain.py` | Written; no regulation text ingested yet (needs input) |
| R4 | Multi-agent systems | n/a | n/a | Skipped by design, as `claude.md` allows; covered in Drishti |
| R6 | Tokens, cost per request, latency, tracing | Token counts and cost per call from model usage metadata with operator-supplied prices, per-stage latency (retrieval, generation), Cloud Trace correlation in structured logs | `llm.py`, `explain.py`, `routes.py`, `logging_utils.py` | Written. Kept light as `claude.md` asks |
| R9 | Secure APIs and pipelines, sensitive data | JWT verification with explicit issuer and audience checks, per-user rate limiting, strict request schemas, size limits, data minimisation, consent, encrypted on-device storage, delete endpoint, log masking, non-root container, least-privilege IAM, Secret Manager | `auth.py`, `schemas.py`, `limits.py`, `lib/services/` (consent, profile store, privacy), `docs/SECURITY.md`, `docs/PRIVACY.md` | Written; reviewed by reading only. Known gaps listed in `SECURITY.md` |
| R10 | Eval frameworks for accuracy, safety and latency | Real-photo label dataset format with human review gate; OCR error rate for on-device ML Kit and cloud Gemini; ingredient parsing; allergen precision and recall with every false negative listed; citation correctness by human review; API safety and prompt-injection cases; latency percentiles; cost per scan; generated report | `evals/`, `test/eval/`, `integration_test/` | Harness written; no labels, no results (needs input) |
| R11 | Field insights into features and reusable modules | Feedback-to-change-to-measurement log; app size script; the `rag` package and the eval harness as reusable modules | `docs/USER_FEEDBACK.md`, `scripts/app_size.sh`, `backend/nutrilens_api/rag/`, `evals/` | Templates and scripts written; measured cells empty until measured |
| n/a | Hybrid on-device and cloud design | Offline rules (allergens, avoid list, conditions, medicine list, additive table) on the phone; Vertex AI for hard-label OCR, cited explanations and regulation search; documented split with reasons | `lib/services/`, `backend/`, `docs/ARCHITECTURE.md` | Written. The on-device additive table works from an exported asset that does not exist until the regulation data is supplied |

## Scope items from `claude.md`

| Item in `claude.md` | State |
|---|---|
| Regulation RAG with citations (structure-aware chunking, Vertex embeddings, pgvector, additive table, hybrid retrieval, citation on every warning) | Pipeline written; real regulation files and `data/additives.csv` needed |
| Hybrid on-device and cloud, offline rules and compact additive table, Gemini vision OCR fallback, cited explanations and search, documented split | Written: offline rules, additive table reader and exporter, cloud OCR option on the scan screen, explain and search endpoints, `ARCHITECTURE.md` |
| Medical-report privacy (minimisation, encryption, consent, retention, delete endpoint, log masking, `PRIVACY.md`) | Written. Report import is deliberately not built (no such feature existed); `PRIVACY.md` says reports are never ingested |
| Cloud Run deploy (multi-stage, non-root, least-privilege service account, Secret Manager, JWT reviewed, rate limiting, scripts with teardown) | Written; JWT review in `SECURITY.md`; not deployed |
| Evals (50 labels, OCR on-device vs. Gemini, mapping accuracy, precision and recall, citation correctness, latency, cost, generated `RESULTS.md`, `ERROR_ANALYSIS.md`) | Harness and report generator written; labels and runs needed; `ERROR_ANALYSIS.md` is written by a person after a run |
| App size script | Written |
| Field feedback doc | Template written; evidence needed |
| Quality (pytest, unit tests for the rules engine, linting, pre-commit, GitHub Actions, Makefile) | Written; never run |
| README (pitch, Mermaid architecture, results table, quickstart, deploy steps, demo GIF) | README written. It quotes no results. Screenshots or a recording need a running app |

## What a reviewer should not be told yet

That anything is deployed, passes tests, has users, or meets a latency, accuracy or size figure. `docs/ROADMAP.md` lists what closes each gap.
