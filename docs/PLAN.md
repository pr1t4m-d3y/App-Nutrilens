# Plan: NutriLens for the Google FDE role

Status: **draft, awaiting your approval. Nothing below has been built, deployed or pushed.**
Scope: this repo only (`App-Nutrilens`, branch `feat/fde-upgrade`). Basis: `docs/AUDIT.md`.
Effort: S (under 1 day), M (1-3 days), L (3+ days). Impact is for the FDE application.

Supporting docs written alongside this plan:

| Doc | Purpose |
|---|---|
| `docs/ARCHITECTURE.md` | Target hybrid design: what runs on the phone vs. Cloud Run, and why |
| `docs/PRIVACY.md` | Current data handling (facts) and the target policy (not yet implemented) |
| `docs/USER_FEEDBACK.md` | Template; every effect field stays empty until measured |
| `data/regulations/SOURCES.md` | Candidate FSSAI / EU sources, none downloaded yet |
| `evals/README.md`, `evals/LABEL_CHECKLIST.md` | Eval method, metric definitions, and the photo checklist for you |
| `RESUME_FACTS.md` | What is verified today, and what to reword or remove |

## The shape of the work

This repo has no backend, keys inside the app and a demo login (AUDIT §1). So the plan is to **add a small Flask service on Cloud Run, move every model call behind it, and keep the safety-critical checks on the phone.**

- **On the phone, no network needed:** ML Kit OCR, allergen and additive rules, medicine lookup, encrypted local profile.
- **On Cloud Run:** a JWT-verified Flask API, Vertex AI Gemini (hard-label OCR and cited explanations), Vertex AI embeddings and pgvector (regulation retrieval).
- **Auth:** Firebase anonymous auth gives each install a real JWT. Flask verifies it against Google's public keys. This replaces the demo login and the unused `demo-project` Firebase config.
- **Web:** the ML Kit plugin is Android/iOS only, so a Flutter web build must use the cloud OCR path. That makes web a clean demonstration of the hybrid design (see item B8, optional).

Flask is kept so the resume's "Python, Flask, REST" becomes true. Details are in `docs/ARCHITECTURE.md`.

## Items by bucket

### 1. Fix (broken, and it matters for FDE)

| # | Item | Effort | Impact | Why |
|---|---|---|---|---|
| F1 | Remove `.env` from the app bundle; move all model keys server-side; add `.env.example`; scan every diff for secrets before commit | M | High | Keys in the APK break your own rule and a reviewer will find it first. |
| F2 | JWT-verified API with rate limiting and request-size limits; replace the demo login with Firebase anonymous auth | M | High | Makes "JWT-secured Flask API" true. Strong R9 evidence. |
| F3 | Local engine: fix the `\$` string bugs; add **medicines** to the offline check; persist the profile in encrypted storage | M | High | C5 is half true today. |
| F4 | Make a clean clone build (asset list, README quickstart) and replace the template widget test | S | Med | A reviewer must be able to run it. |

### 2. Build (FDE opportunity from AUDIT §4)

| # | Item | Effort | Impact | Notes |
|---|---|---|---|---|
| B1 | **Regulation RAG with citations.** Real FSSAI and EU texts in `data/regulations/`, sources in `SOURCES.md`. I will not write or paraphrase regulation text myself. Structure-aware chunking that keeps regulation and article numbers and E-numbers; Vertex AI embeddings; pgvector on Cloud SQL; a structured additive table (E-number, synonyms, limits, allergen tags) linked to the chunks; hybrid exact-match plus vector retrieval. Every warning carries a citation. If nothing is retrieved, the API says "no source found" instead of making a claim. | L | High | Different domain from Drishti's finance RAG. |
| B2 | **Hybrid on-device engine.** Compact additive and allergen table generated from the same structured table as B1, so phone and cloud agree. Dart unit tests for the rules engine. A test proves warnings work with the network off. | M | High | The "offline rules + cloud AI" story. |
| B3 | **Health-data privacy.** Send flags such as "type 2 diabetes", not name, age or free text. Consent screen. Encrypted local storage. **No server-side storage of user data by default.** `DELETE /v1/me`. PII masking in logs. | M | High | Answers C10 and R9. See `PRIVACY.md`. |
| B4 | **Cloud Run deploy.** Multi-stage Dockerfile, non-root user, least-privilege service account, Secret Manager, Cloud SQL connector, rate limiting, reproducible `deploy/` scripts with a teardown script, budget alert set first. | M | High | Needs your project ID, region and budget. |
| B5 | **Evals on real labels.** `evals/labels/` with 50+ photos; harness; generated `evals/results/RESULTS.md` (never hand-written); `evals/ERROR_ANALYSIS.md`. Metrics: OCR accuracy (ML Kit vs. Gemini), ingredient-mapping accuracy, allergen/medicine **precision and recall** (false negatives listed separately), citation correctness, latency (offline vs. cloud), cost per scan. | L | High | See `evals/README.md`. |
| B6 | **Quality.** pytest for the backend, `flutter test` for the rules engine, linting, pre-commit, GitHub Actions CI, `Makefile`. | M | Med | The real unit-test tool here is Dart's `flutter test`. |
| B7 | **README** (pitch, screenshots, Mermaid architecture, results table, 10-minute quickstart, deploy steps). | S | Med | Filled with measured numbers only. |
| B8 | *Optional:* Flutter web build using the cloud OCR path, hosted somewhere you choose. | M | Low-Med | Makes the "web + Android" claim true from this repo. Skip if you prefer to reword to "Android". |

### 3. Re-measure (numbers I cannot verify today)

| # | Item | Effort | Impact | Method |
|---|---|---|---|---|
| R1 | **C2 latency.** p50 and p95 scan latency over a stated number of runs: on-device only; Cloud Run warm; Cloud Run cold; each on the same label set. A percentage is reported only if it comes from a baseline you can name. | M | High | Needs your answer to AUDIT Q1. |
| R2 | **C3 accuracy.** Define it first (ingredient text to canonical ingredient/additive; intent classification), then measure on the B5 label set and a documented intent test set. Report the real figure whether or not it is 98%. | M | High | AUDIT Q2. |
| R3 | **C7 size.** `scripts/app_size.sh` reports APK/AAB size per build. Before/after on changes that can be made now: remove unused `firebase_auth`/`cloud_firestore`, remove the duplicate NLP folder, `--split-per-abi`, resource shrinking. | S | Med | Needs Flutter and the Android SDK. The historical 70 to 46 MB stays "as reported by you" unless the old builds exist. |
| R4 | **C9 users.** Not code. You collect the evidence. | S | High | AUDIT Q4. |

### 4. Skip (missing, not needed for FDE; reword instead)

- **Real dose-reminder notifications.** Today it is UI with no scheduling. Reword to "medicine reminder interface".
- **Multi-agent / ReAct.** Drishti covers it.
- **The "4+1+1" OpenAI/DeepSeek fallbacks.** They do not exist in the code. The new backend uses Vertex AI Gemini with a lighter-model retry. Reword, do not rebuild.
- **Medicine-to-medicine interaction engine.** Clinical content I cannot source or validate (see Decision 6 for the narrow version).

### 5. Reword

Final wording is set in `RESUME_FACTS.md` after measurement. Direction:

| Current claim | Direction |
|---|---|
| "Java (Android)" | "Flutter/Dart (Android)", plus Python/Flask for the API once built. |
| "JWT-secured Flask REST API" | Keep only after F2 ships and is tested. |
| "40% lower verification latency" | Remove unless R1 gives a defined, measured baseline. |
| "98% data-mapping accuracy" | Remove unless R2 reproduces it; otherwise quote the measured figure and test set. |
| "FSSAI ordering / EU flags" | Keep after B1 as "cited against named regulations". |
| "Warnings from allergies and medicines, offline" | Keep after F3 and B2. |
| "70 MB to 46 MB" | Keep only with build artifacts; otherwise quote R3's measured before/after. |
| "200+ users" | Keep only with a source. |
| "Handles users' medical reports" | Depends on Decision 5. |

## Build order

If time runs short, the cut line is after step 5 (RAG + evals, then Cloud Run, then privacy), as you specified.

1. Scaffold: drop `.env` asset, `.env.example`, `backend/` skeleton, Makefile, pytest, lint, CI (F1, F4, part of B6)
2. Regulation corpus, additive table, RAG (B1)
3. Label set, eval harness, latency and accuracy runs (B5, R1, R2)
4. JWT, rate limits, Cloud Run deploy and teardown (F2, B4)
5. Privacy, consent, delete endpoint, log masking (B3)
6. On-device engine, offline medicine check, encrypted profile (F3, B2)
7. Size script (R3), `USER_FEEDBACK.md`, README, `RESUME_FACTS.md`, optional web (B7, B8)
8. Push the branch and open the PR. **I will not merge.**

## Decisions I need from you

Already settled: the target repo is `App-Nutrilens`.

1. **GCP:** project ID, region and budget cap. I suggest `asia-south1` (Mumbai) for latency from Bengaluru, subject to Vertex AI model availability, which I will check in current docs. Cloud SQL is the main fixed cost; I will price it from current pricing and show you before creating anything, and set the budget alert first. Separate Cloud SQL instance, or a separate database on Drishti's instance to save money?
2. **Tooling:** may I install the Flutter SDK and Android command-line tools (large downloads) to run builds, tests and the size script? Otherwise you run the commands and paste the output.
3. **Regulation files:** may I download them from the official sites (I will list names, sizes and URLs first), or will you?
4. **Label photos:** this repo has none. I need 50+. Either you photograph them from `evals/LABEL_CHECKLIST.md`, or I also pull images from Open Food Facts (open licence, with attribution). Ground truth is transcribed by me and **reviewed by you**, and `RESULTS.md` will state that.
5. **Medical reports:** no such feature exists. Option (a): build a small one (photo or PDF goes to Cloud Run in memory, only allergies and medicines are extracted, the report is discarded). Option (b): do not build it, document that reports are never ingested, and reword C10. I recommend (b) unless users really did upload reports in a build I cannot see.
6. **Offline medicine check scope:** only a short, sourced list of well-documented food-drug interactions, each with a citation and labelled informational, or only exact "medicine on your list" matching?
7. **Web (B8):** build it, or reword the resume to "Android"?

**Evidence only you have:** AUDIT open questions 1 to 6.

## Not decided yet

- Gemini and embedding model names and region availability: taken from current Vertex AI documentation at build time, with versions pinned. The Groq and `gemini-2.0-flash` names in today's code should be checked against vendor deprecation notices.
- Total cost: unknown until Decision 1 and current pricing.
