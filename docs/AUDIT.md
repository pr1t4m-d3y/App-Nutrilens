# NutriLens audit: resume claims vs. what the repos contain

Audit date: 2026-11-19. Everything below was read from code, git history, GitHub's API or a command run during this audit.
Nothing here is estimated. Where I could not measure something, the row says so and says why.

## 0. Which repo is "NutriLens"?

Your GitHub has **three** NutriLens-related repos. The resume reads as if they are one project; they are not.

| Repo | Created | Commits | Contents | Role |
|---|---|---|---|---|
| `pr1t4m-d3y/NutriLens` | 2025-12-11 | 2 | Flask backend (`backend/app.py`, 1 file), plain HTML/JS/CSS web client, `medical_scanner.js` | **This is the "live web version".** Netlify serves this client. The client calls `https://nutrilens-tp7f.onrender.com`. |
| `pr1t4m-d3y/App-Nutrilens` (this checkout) | 2026-04-23 | 3 | Flutter/Dart app (38 Dart files, Android/iOS/web/desktop scaffolds), on-device ML Kit OCR, 376-row medicine DB, TFLite intent model. **No backend.** It calls Gemini and Groq directly from the phone. | The "Android app". |
| `pr1t4m-d3y/Maa_Ki_Aankh` (private) | 2025-11-09 | n/a | HTML/JS/CSS prototype | Not audited beyond its metadata. |

**Consequence:** the resume sentence "JWT-secured Flask REST API serving OCR payloads to web and Android clients" describes an architecture that does not exist in any repo. The Flask API serves only the web client. The Android app does not use the Flask API at all.

## 1. Clean-clone health check

| Check | Result | Evidence |
|---|---|---|
| Flutter/Android build from a clean clone | **Not run.** Flutter and Dart are not installed on this machine, and I did not install them without asking. A clean clone is **expected to fail**: `pubspec.yaml` lists `.env` as an asset, no `.env` ships in the repo, and there is no `.env.example`. I have not confirmed the failure message. | `pubspec.yaml` assets block; `ls -la .env*` found nothing |
| Flask backend | **Not run.** Static read only. Pinned in `requirements.txt` (Flask 3.1.2, gunicorn 21.2.0). `requirements.txt` is saved as **UTF-16**, which `pip install -r` cannot read on most setups. Treat as a likely install failure until it is re-encoded. | `file` reports "Unicode text, UTF-16, little-endian, with CRLF" |
| Web client | **Works.** `GET https://bright-raindrop-a18cae.netlify.app/` returned HTTP 200 in 0.90 s (40,072 bytes). | `curl` during audit |
| Live backend | `GET /` returns 404 (no root route, expected). `GET /api/smart-scan` returns 405 with `allow: POST, OPTIONS` and `access-control-allow-origin: *`, so the service is up. The first request after idle took **47.5 s** (Render free-tier cold start; one sample, not a benchmark). I did not send a scan request. | `curl -w` during audit |
| Tests | **None that work.** Flutter: `test/widget_test.dart` is the default "Counter increments" template and asserts a `+` icon that the app does not have, so it would fail (by inspection; not run). Flask repo: no tests. | `test/widget_test.dart` |
| README | Flutter repo has one, but it is **inaccurate** (see C4 and the table below). Web repo has none. | `README.md` |
| CI | None. No `.github/` in either repo. | `ls -a` |
| Lint | `flutter_lints` is configured. No lint run recorded. | `analysis_options.yaml` |
| Hard-coded secrets in git history | **None found** in either repo (pattern scan for Google, Groq and OpenAI/OpenRouter key shapes across all commits). This only proves the committed history is clean. It is not a security review. | `git grep` over `git rev-list --all` |
| Secrets inside the shipped app | **Problem.** `pubspec.yaml` bundles `.env` as an asset, and `ApiFallbackEngine` reads `GEMINI_KEY_1..3` and `GROQ_KEY_1..2` from it at runtime. Anything in an asset is extractable from the APK or from the Flutter web build. This breaks the rule "no API keys inside the Android app". | `pubspec.yaml`; `lib/services/api_fallback_engine.dart:14-20` |
| Auth | **Demo only.** Login accepts two hard-coded pairs (`User123/User123`, `Admin123/Admin123`) checked in the client. Firebase is initialised with `demo-api-key` / `demo-project`, and no `FirebaseAuth` or `Firestore` call exists anywhere in `lib/`. `firebase_auth` and `cloud_firestore` are dependencies that are never used. | `lib/screens/login_screen.dart:25-26`; `lib/main.dart:19-25`; `grep` found zero Firebase API uses |
| Backend hardening | `CORS(app, origins="*")`, no authentication on either endpoint, `app.run(debug=True)` in `__main__`, no rate limiting, no input-size limit on image upload. | `backend/app.py` |
| Persistence | Flutter: profile, history and reminders live in memory only (no SharedPreferences, file or DB use found), so they are lost on app restart. Web: profile in `localStorage`, unencrypted. | `grep` for persistence APIs found none; `script.js` |

## 2. Claim-by-claim verification

Status key: **Verified**, **Partial**, **Missing**, **Can't verify**.

| ID | Status | Evidence |
|---|---|---|
| **C1** Stack: Python, Flask, Java (Android), REST, JWT, OCR; web + Android; live link works | **Partial** | **Python/Flask/REST: yes**, in the web repo (`backend/app.py`, two POST endpoints). **Java: no.** The repo has zero `.java` files. The Android app is Flutter/Dart, and the only native file is the 1-file `MainActivity.kt` that the Flutter template generates. **JWT: no.** Neither repo contains `jwt`, `Authorization` verification or any token issue/verify code (the only `Authorization` header is the outgoing OpenRouter call). **OCR: yes**, but two different ways. Web: Gemini Vision on the server (EasyOCR is commented out). Android: Google ML Kit on-device. **Live link: works** (HTTP 200); backend cold-starts in ~47 s. |
| **C2** 40% lower verification latency with a JWT-secured Flask API serving real-time OCR payloads to web and Android | **Can't verify** (and the premise is partly false) | No benchmark, baseline, log or script exists. No JWT. The Android app never calls the Flask API. "Verification latency" has no definition in code. The only latency figure I observed is a 47.5 s Render cold start (one sample). **Needs your answer:** 40% lower than *what* baseline? See Questions. |
| **C3** 98% data-mapping accuracy, NLP turning natural-language dietary constraints into alternatives | **Can't verify** | No test set, labelled data, training notebook or eval script in either repo. The NLP is a TFLite intent classifier (`assets/nlp/chatbot_model.tflite`, 130,192 bytes) with **6 intents** (`label_map.json`: top-rated, worst, sugar-free, high-protein, palm-oil-free, vegan) that then filters a **200-product** JSON (`product.json`). The model's training data is not in the repo, so I cannot re-run or reproduce its accuracy. TFLite/TensorFlow is not installed here. "Healthier alternatives" come from the cloud LLM's `healthierSwap` field, not from this NLP. |
| **C4** Ingredient ordering per FSSAI norms; harmful-additive flags per EU guidelines | **Partial** (FSSAI heuristic) / **Missing** (EU) | `IndianWeightedScorer` weights ingredients by list position (3x for the first 3, 2x for the first half, 1x otherwise). Descending-order listing is a real labelling rule, but **the 3x/2x/1x multipliers and the penalty table are the author's own design, not taken from FSSAI text**, and nothing in the repo cites a regulation. The score is computed locally but shown only when the cloud call fails. **EU:** no EU regulation, E-number list or citation exists in the repo. `HealthBridge` hard-codes 10 additives with free-text "risk" strings (it labels one an "FSSAI hazard rating", unsourced), and that class is not called from anywhere in `lib/`. The LLM prompt asks the model to act as an "FSSAI Regulatory Expert (2026 Standards)", which is a prompt, not a data source. |
| **C5** Personalised warnings from allergies **and medicines**, working offline | **Partial** | **Allergies offline: yes in principle.** ML Kit OCR + `LocalScanner` regex run on-device with no network. **Medicines: no.** `LocalScanner.scanForThreats` takes only `userAllergies` and `userConditions`. `medications` is used only by `toMetadataMap()`, which goes into the **cloud** prompt. So there is no offline medicine-interaction check. Also the profile is not persisted (above), and the web client's local scan needs the **server** OCR first, so the web version is not offline at all. Bugs in the local engine: `local_scanner.dart:50` and `marketing_checker.dart:28` use `\$` inside Dart strings, so the UI shows the literal text `${match.group(0)} (High Glycemic)` and `$claim` / `$violator`. |
| **C6** Healthier alternatives, generic-medicine search by salt or brand, dose reminders, NLP search | **Partial** | **Healthier alternatives: yes** (cloud LLM `healthierSwap`). **Generic-medicine search by brand/composition: yes**, on-device and offline: `MedicineDbService` indexes `Brand_Name` and `Composition` over **376 rows** (109 + 141 + 126 across 3 xlsx batches; the JSON asset has 376). "Salt" maps to the `Composition` column. Caveat: 376 medicines is a small, curated sheet with no source or licence stated, and it returns the single best match only. **Dose reminders: UI only.** `medicine_reminder_screen.dart` (625 lines) has pickers and toggles, but `pubspec.yaml` has no notification or alarm package and the screens contain no scheduling call, so no reminder can fire. The README says "push notifications"; I found no code that sends one. **NLP search: yes** (6-intent classifier, see C3). |
| **C7** App size 70 MB → 46 MB after user feedback | **Can't verify** | No APK/AAB, no build output, no size log, and the git history has only 3 commits (2026-04-17 to 2026-04-23), so no before/after commits exist. Flutter is not installed, so I could not build one. What the repo does show: bundled assets are about 0.9 MB (`assets/` is 296 KB medicine DB + 440 KB NLP), so the size is dominated by Flutter engine, ML Kit and TFLite native libs, not by content. Two **unused** dependencies (`firebase_auth`, `cloud_firestore`) and a duplicate NLP asset folder (`nlp/` and `assets/nlp/` hold identical files) are size-relevant. Release build is **signed with debug keys** and uses no `--split-per-abi` config, so a fat APK is likely. If a 70 MB build existed it is not in any repo; it may be an earlier native build. |
| **C8** Removed redundant code, cut server load, added UI animations after feedback | **Partial** / **Can't verify the "after feedback" part** | Animations exist: `flutter_animate`, `lottie`, a liquid-glass nav bar, spring-physics widgets. But the history has no commit that removes code, no commit that reduces server calls, and no commit referencing feedback. "Reduced server load" is not evidenced: the Flutter app has no server, and the Flask repo has one `First commit` and one `Connected to live backend`. The one defensible load-related fact is the design: local checks run first, and the app calls the cloud with OCR text rather than images. |
| **C9** 200+ users | **Can't verify** | No analytics SDK, no real Firebase project, no Play Console reference, no GitHub Release in either repo. GitHub traffic (last 14 days): **0 page views** on both repos; stars 0 and 0; forks 0 and 1; clones 6 (5 unique) and 12 (9 unique), which includes you. The web client has no accounts, so the only possible sources are **Netlify analytics** (unique visitors), **Render request logs** (calls to `/api/smart-scan`), **Play Console / Firebase** if an Android build was ever distributed, or a Google Form / feedback sheet. Please check those before this stays on the resume. |
| **C10** How users' medical reports are handled | **Missing as a feature; handling is weak** | **There is no medical-report upload or parsing code in either repo.** `image_picker` is used only for label and medicine photos. What the apps do handle: the manually entered health profile (conditions, allergies, medications, BMI, age). Flutter: sent to Gemini/Groq in plain text on every scan, with keys in the app; not persisted. Web: stored unencrypted in `localStorage`, then POSTed to the Render API and on to Gemini/OpenRouter. In both: no consent screen, no retention policy, no delete-my-data path, no encryption beyond TLS, no PII masking in logs (the backend prints raw exception text to stdout, and the Flutter app prints API errors with `debugPrint` and shows the first 120 characters of an exception in a red snackbar). The README's "Firebase for secure user data" is **not implemented**. Where did users raise the report concern, and which build were they running? |

### README and docs vs. code

| README / docs says | Code says |
|---|---|
| "Google Gemini 3.0 Flash, OpenAI GPT-4o, DeepSeek V3 (4+1+1)" | Chain is `gemini-2.0-flash` x3 keys and Groq `llama-3.1-70b-versatile` x2 keys (5 nodes). No OpenAI, no DeepSeek (DeepSeek only in the *web* backend via OpenRouter). Both of these model names should be checked against current vendor deprecation lists before any rebuild. |
| "Firebase for secure data" | Unused; demo config. |
| "Push notifications" for reminders | No notification code. |
| "Flutter 3.27+ with Impeller" | `pubspec.yaml` requires Dart `^3.7.2`; Flutter version is not pinned. |
| `PLAN.md` | A checklist with every box unchecked, including items that are built. Stale. |

## 3. What NutriLens can add for the FDE role (Step 2, adjusted after the audit)

Drishti already covers multi-agent ADK, finance RAG, tracing and evals on Cloud Run. NutriLens should show *different* evidence: **a hybrid on-device + cloud product, health-data security, and evals on real inputs.** The audit changes the original table in four ways:

1. **R9 (secure APIs, sensitive data) is the biggest gap and the biggest story.** Today there is no auth, keys ship in the app and CORS is `*`. A documented before/after hardening is real FDE evidence.
2. **R11 (field feedback → shipped change → measured effect) cannot lean on C7/C8/C9 as written.** None is evidenced. I would rebuild the story from measurements that can be taken now (APK size per build, scan latency, what leaves the device).
3. **The hybrid architecture partly exists.** ML Kit OCR + local regex + cloud LLM is already the shape. The work is to make it correct (medicines, E-number table, bugs), tested and documented, not to invent it.
4. **Real users (R2) is unproven.** Do not claim it until C9 evidence exists.

| Req | Requirement | Drishti covers? | NutriLens opportunity (adjusted) |
|---|---|---|---|
| R2 | Production AI on Google Cloud, concept to launch | Yes | A second Cloud Run service with a real mobile and web client. **Users only if C9 produces evidence.** |
| R3 | Structured + unstructured pipelines, vector DB + RAG | Yes (finance) | Cited RAG over FSSAI, EU additive and allergen rules plus a structured additive table. |
| R4 | Multi-agent (ADK, ReAct) | Yes | **Skip.** A single retrieval-then-generate path is the right design here. |
| R6 | Tokens/sec, cost, state, tracing | Yes | Cost per scan and latency only, logged per request. |
| R9 | Secure APIs/pipelines, enterprise data | Partly | Auth'd API, keys moved server-side, PII/PHI minimisation, consent, retention, delete endpoint, log masking. |
| R10 | Eval frameworks (accuracy, safety, latency) | Yes | Evals on real label photos: OCR, detection **recall** (false negatives reported separately), citation correctness. |
| R11 | Field insights → features | Partly | `USER_FEEDBACK.md` built from measurable changes only. |
| n/a | Hybrid on-device + cloud design | No | Offline rules engine on the phone, Vertex AI in the cloud, written up with the trade-offs. |

## 4. Questions the audit could not answer

These affect the plan (see `PLAN.md`, section "Decisions I need from you").

1. Which repo should the PR target, and which one carries the resume story?
2. C2: what was the 40% measured against?
3. C3: what exactly was 98% accurate, on what data, and where is the test set?
4. C7: do you still have the 70 MB and 46 MB builds, or Play Console / Firebase App Distribution numbers?
5. C9: do you have Netlify, Render, Play Console or form data behind "200+ users"?
6. C10: where did users raise medical-report privacy, and was there a report feature in a build I can't see?
