# Plan: NutriLens for the Google FDE role

Status: **draft, awaiting your approval. Nothing in this plan has been built, deployed or pushed.**
Basis: `docs/AUDIT.md`. Effort: S (under 1 day), M (1-3 days), L (3+ days). Impact is for the FDE application.

## Recommended shape

- **Target repo:** `App-Nutrilens` (this checkout, branch `feat/fde-upgrade`). It already holds the on-device pieces (ML Kit OCR, local rules, medicine DB). Add a `backend/` Flask service. Flask keeps the resume's "Python, Flask, REST" line true.
- **Leave alone:** the `NutriLens` web repo, the Netlify site and the Render backend. The live link keeps working. Re-pointing the web client at Cloud Run is an optional follow-up PR in that repo, after you approve.
- **Architecture:**
  - *On the phone (offline-capable):* ML Kit OCR, allergen and additive rules, local medicine DB and an encrypted local profile. Warnings never depend on the network.
  - *On Cloud Run (online):* JWT-verified Flask API, Vertex AI Gemini for hard-label OCR and cited explanations, Vertex AI embeddings and pgvector for regulation retrieval. The backend stores nothing about the user by default.
  - *Why the split:* latency, privacy (health data stays local unless needed), cost (the cloud is called only when it adds value) and reliability (works without signal). I will write this up with measured numbers, not adjectives.
- **Auth:** Firebase anonymous auth gives each install a real JWT. Flask verifies it against Google's public keys. This also replaces the demo login and the `demo-project` Firebase config, which the audit found unused. Rate limiting sits on top.

## Items by bucket

### 1. Fix (a claim is broken and it matters)

| # | Item | Effort | Impact | Why |
|---|---|---|---|---|
| F1 | Remove `.env` from the app bundle; move all model keys server-side; add `.env.example`; scan diffs before every commit | M | High | Keys in the APK break your own rule and are the first thing a security reviewer finds (AUDIT §1). |
| F2 | JWT-verified API with rate limits and input-size limits; replace demo login | M | High | Makes the "JWT-secured Flask API" claim true. Strong R9 evidence. |
| F3 | Local engine correctness: fix the `\$` string bugs, add **medicines** to the offline check, persist the profile in encrypted storage | M | High | C5 is only half true today (AUDIT C5). |
| F4 | Fix the Flutter build from a clean clone (asset list, README quickstart) and replace the template widget test | S | Med | A reviewer must be able to build it. |

### 2. Build (FDE opportunity from Step 2)

| # | Item | Effort | Impact | Notes |
|---|---|---|---|---|
| B1 | **Regulation RAG with citations.** Real FSSAI and EU texts in `data/regulations/` with `SOURCES.md` (I will not write or paraphrase regulation text myself). Structure-aware chunking that keeps regulation and article numbers and E-numbers; Vertex AI embeddings; pgvector on Cloud SQL; structured additive table (E-number, synonyms, limits, allergen tags) linked to chunks; hybrid exact-match + vector retrieval. Every warning carries a citation, and the API returns "no source found" rather than an uncited claim. | L | High | Different domain from Drishti's finance RAG. Candidate sources (titles and URLs to be confirmed on the official sites before use): FSS (Labelling and Display) Regulations 2020, FSS (Food Products Standards and Food Additives) Regulations 2011, Regulation (EC) No 1333/2008, Regulation (EU) No 1129/2011 (additive list), Regulation (EU) No 1169/2011 (allergen labelling). |
| B2 | **Hybrid on-device engine**: compact additive and allergen table generated from the same structured table as B1, so the phone and cloud agree; Dart unit tests for the rules engine; offline mode proven by a test with the network disabled | M | High | The "offline rules on the phone + AI in the cloud" story. |
| B3 | **Privacy and health-data handling**: minimise what leaves the device (send flags such as "type 2 diabetes", not name, age or free text), consent screen, encrypted local storage, **zero server-side retention by default**, `DELETE /v1/me` endpoint, PII masking in logs, `docs/PRIVACY.md` | M | High | Answers C10 and R9. |
| B4 | **Cloud Run deploy**: multi-stage Dockerfile, non-root user, least-privilege service account, Secret Manager, Cloud SQL connector, rate limiting, reproducible `deploy/` scripts with a teardown script, budget alert | M | High | Needs your project ID, region and budget first. |
| B5 | **Evals on real labels**: `evals/labels/` (50+ photos), harness, generated `evals/results/RESULTS.md`, hand-written `evals/ERROR_ANALYSIS.md`. Metrics: OCR accuracy (ML Kit vs. Gemini), ingredient-mapping accuracy, allergen/medicine **precision and recall** with false negatives listed separately, citation correctness, latency (offline vs. cloud), cost per scan | L | High | Real inputs, real failure cases. |
| B6 | **Quality**: pytest (backend), `flutter test` (rules engine), linting, pre-commit, GitHub Actions CI, `Makefile` | M | Med | Resume says "Android unit tests"; the real tool here is Dart `flutter test`. |
| B7 | **README** with pitch, screenshots, Mermaid architecture, results table, a 10-minute quickstart and deploy steps; `docs/USER_FEEDBACK.md` | S | Med | |

### 3. Re-measure (numbers I cannot verify today)

| # | Item | Effort | Impact | Method |
|---|---|---|---|---|
| R1 | **C2 latency**: benchmark scan latency, p50 and p95 over a stated number of runs: on-device only, Cloud Run warm, Cloud Run cold, and the existing Render service (cold and warm). The "40%" is reported only if it falls out of a baseline you can name. | M | High | Needs your answer on what the 40% compared (Question 4). |
| R2 | **C3 accuracy**: define it first (ingredient text to canonical ingredient or additive, and intent classification), then measure on the B5 label set and a documented intent test set. Report the real figure whether or not it is 98%. | M | High | Question 5. |
| R3 | **C7 size**: `scripts/app_size.sh` reports APK/AAB size per build. Before/after on things that can be changed now: unused `firebase_auth`/`cloud_firestore`, duplicate NLP assets, `--split-per-abi`, resource shrinking. | S | Med | Needs Flutter and the Android SDK (Question 3). The historical 70 to 46 MB stays "as reported by you" unless you have the old builds. |
| R4 | **C9 users**: not code. Pull Netlify analytics, Render logs, Play Console or form data. | S | High | Yours to supply (Question 6). |

### 4. Skip (missing, not needed for FDE; recommend rewording)

- **Real dose-reminder notifications.** Today it is a UI with no scheduling. Not an FDE signal. *Reword* to "medicine reminder interface".
- **Multi-agent / ReAct.** Drishti covers it and this product does not need it.
- **OpenAI and DeepSeek fallbacks ("4+1+1").** Neither exists in the Flutter code. The new backend uses Vertex AI Gemini with a lighter-model retry. *Reword*, do not rebuild.
- **Medicine-to-medicine interaction engine.** Clinical content I cannot source or validate. See Decision 7 for the narrow version I would do.
- **Re-pointing the Netlify web client** as part of this PR. Optional follow-up.

### 5. Reword (inaccurate as written)

Final wording is set in `RESUME_FACTS.md` after measurement. Direction now:

| Current claim | Direction |
|---|---|
| "Java (Android)" | "Flutter/Dart (Android, web)", plus Python/Flask for the API. |
| "JWT-secured Flask REST API" | Keep only after F2 ships and is tested. |
| "40% lower verification latency" | Remove unless R1 yields a defined, measured baseline. |
| "98% data-mapping accuracy" | Remove unless R2 reproduces it; otherwise quote the measured figure and the test set. |
| "FSSAI ordering, EU flags" | Keep after B1: "cited against" named regulations. |
| "Warnings from allergies and medicines, offline" | Keep after F3 and B2. |
| "App size 70 MB to 46 MB" | Keep only with build artifacts or Play Console data; otherwise quote R3's measured before/after. |
| "200+ users" | Keep only with a source (R4). |
| "Handles users' medical reports" | Depends on Decision 6. |

## Build order

If time runs short the cut line is after step 5, as you specified (RAG + evals, then Cloud Run, then privacy).

1. Scaffold: remove `.env` asset, `.env.example`, `backend/` skeleton, Makefile, pytest, lint, CI (F1, F4, part of B6)
2. Regulation corpus, additive table and RAG (B1)
3. Label set, eval harness, latency and accuracy measurement (B5, R1, R2)
4. JWT, rate limits, Cloud Run deploy and teardown (F2, B4)
5. Privacy, consent, delete endpoint, log masking (B3)
6. On-device engine, medicine offline check, encrypted profile (F3, B2)
7. Size script (R3), `USER_FEEDBACK.md`, README, `RESUME_FACTS.md` (B7)
8. Push branch, open PR. **I will not merge.**

## Decisions I need from you

**Blocking (I cannot start the matching step without them):**

1. **Target repo:** approve `App-Nutrilens` as the base, with the web/Render repo untouched?
2. **GCP:** project ID, region and budget cap. I suggest `asia-south1` (Mumbai) for latency from Bengaluru, subject to Vertex AI model availability there, which I will check in the current docs. Cloud SQL is the main fixed cost. I will price it from current pricing and show you before creating anything, and set the budget alert first. Should it be a separate Cloud SQL instance, or a separate database on Drishti's instance to save money?
3. **Tooling downloads:** may I install the Flutter SDK and Android command-line tools (large downloads) so I can run builds, tests and the size script? Otherwise you run those commands and paste the output.
4. **Regulation files:** may I download them from the official sites (I will list file names, sizes and URLs for your yes first), or will you?
5. **Label photos:** only 7 label images exist (`NutriLens/Training Database`). I need 50+. Either you photograph them from a checklist I write, or I also pull images from Open Food Facts (open licence, with attribution). Ground truth would be transcribed by me and **reviewed by you**, and RESULTS.md will say so.
6. **Medical reports:** no report feature exists in any repo. Choose (a) build a small one (photo or PDF goes to Cloud Run in memory, only allergies and medicines are extracted, the report is discarded), or (b) do not build it, document that reports are never ingested, and reword C10. I recommend (b) unless users really did upload reports in a build I cannot see.
7. **Offline medicine check scope:** I would include only a short, sourced list of well-documented food-drug interactions, each with a citation, labelled informational. Do you want that, or only exact "medicine on your list" matching?

**Evidence only you have (answers go straight into the audit):** what the 40% (C2) and 98% (C3) were measured against; whether the 70 MB and 46 MB builds survive (C7); the source of "200+ users" (C9); where users raised the report concern (C10).

## Not decided yet

- Gemini model and embedding model names, and region availability: I will take these from current Vertex AI documentation when I start, and pin versions. The Groq and `gemini-2.0-flash` names in the current code should be checked against vendor deprecation notices first.
- Total cost: unknown until Decision 2 and current pricing.
