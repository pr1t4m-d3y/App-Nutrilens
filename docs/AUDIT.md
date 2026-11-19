# NutriLens audit: resume claims vs. this repo (`App-Nutrilens`)

Scope: **this repository only** (`pr1t4m-d3y/App-Nutrilens`, local checkout, 3 commits, 2026-04-17 to 2026-04-23).
Audit date: 2026-11-19. Everything below comes from code in this repo, its git history, GitHub's API for this repo, or a command run during this audit. Nothing is estimated. Where I could not measure something, the row says so and why.

> **Scope note.** This audit describes the repo at commit `2de80de`, before any change on `feat/fde-upgrade`. Code has since been written for several findings (see `docs/ROADMAP.md`). That code has never been compiled or run, so nothing below is marked as fixed.

What this repo is: a **Flutter/Dart app** (38 Dart files in `lib/`) with Android, iOS, web and desktop scaffolds. It has **no backend of its own**. It runs ML Kit OCR on the phone and calls Gemini and Groq directly over HTTPS.

## 1. Health check from a clean clone

| Check | Result | Evidence |
|---|---|---|
| Build (Android / web) | **Not run.** Flutter and Dart are not installed on this machine, and I did not install them without asking. A clean clone is **expected to fail**: `pubspec.yaml` lists `.env` as an asset, the repo ships no `.env` and no `.env.example`. I have not confirmed the actual error. | `pubspec.yaml` assets block; `ls -a` shows no `.env*` |
| Run | Not run (same reason). | n/a |
| Tests | **One test, and it would fail.** `test/widget_test.dart` is the unmodified "Counter increments" template. It looks for a `+` icon the app does not have, and `main.dart` needs `.env` loaded first. Judged by reading it, not by running it. | `test/widget_test.dart` |
| README | Exists, but is inaccurate in places (table in section 3). Its quickstart tells you to "set up your `.env`" without saying which keys. | `README.md` |
| CI | None. No `.github/` directory. | `ls -a` |
| Lint | `flutter_lints` is configured. No lint run recorded. | `analysis_options.yaml` |
| Hard-coded secrets in git history | **None found.** I scanned all 3 commits for Google, Groq and OpenAI/OpenRouter key shapes. This shows only that the committed history is clean. It is not a security review. | `git grep` over `git rev-list --all` |
| Secrets inside the shipped app | **Problem.** `.env` is bundled as an asset, and `ApiFallbackEngine` reads `GEMINI_KEY_1..3` and `GROQ_KEY_1..2` from it at runtime. Anything in an asset can be extracted from the APK or a web build. This breaks the rule "no API keys inside the Android app". | `pubspec.yaml`; `lib/services/api_fallback_engine.dart:14-20` |
| Auth | **Demo only.** Login accepts two hard-coded pairs (`User123/User123`, `Admin123/Admin123`) checked on the device. Firebase is initialised with `demo-api-key` / `demo-project`, and no `FirebaseAuth` or `Firestore` call exists anywhere in `lib/`. `firebase_auth` and `cloud_firestore` are dependencies that are never used. | `lib/screens/login_screen.dart:25-26`; `lib/main.dart:19-25`; grep for Firebase API use found only `firebase_core` |
| Persistence | Profile, scan history (capped at 50) and reminders are held in memory only. I found no SharedPreferences, file, SQLite or secure-storage use, so they are lost when the app restarts. | grep for persistence APIs found none |
| Web target | The Flutter web scaffold exists, but the on-device OCR plugin (`google_mlkit_text_recognition` 0.15.0) is **Android and iOS only** per pub.dev's platform tags. A web build from this repo has no OCR path today. | `pub.dev/api/packages/google_mlkit_text_recognition/score` returned `platform:android`, `platform:ios` |
| The "live link" | `https://bright-raindrop-a18cae.netlify.app/` returns HTTP 200, but it serves a **plain HTML page titled "NutriLens - Quality Over Quantity"**, not a Flutter build (no `flutter_bootstrap.js`). It is **not built from this repo**, so I cannot trace it to any code here. | `curl` during audit |
| GitHub Releases / distribution | No Releases in this repo. | `gh release list` returned nothing |

## 2. Claim-by-claim verification

Status key: **Verified**, **Partial**, **Missing**, **Can't verify**.

| ID | Status | Evidence |
|---|---|---|
| **C1** Stack: Python, Flask, Java (Android), REST, JWT, OCR; web + Android; live link works | **Partial** (OCR, Android) / **Missing** (the rest) | **Python / Flask / REST API / JWT: none in this repo.** There are no `.py` files, no server code and no token code. **Java: none.** The only native source is the one-file `MainActivity.kt` that the Flutter template generates. The app is **Dart/Flutter**. **OCR: yes**, Google ML Kit on-device (`scan_screen.dart:74`, `medicine_scan_screen.dart:74`). **Android client: yes** (builds from the Flutter `android/` scaffold, not built here). **Web client: not usable from this repo** (no ML Kit on web). **Live link:** works, but is not this repo's code. |
| **C2** 40% lower verification latency with a JWT-secured Flask REST API serving real-time OCR payloads to web and Android | **Missing / Can't verify** | This repo has no Flask API and no JWT. OCR never leaves the phone. Only the extracted text goes to the model APIs. No benchmark, baseline, log or script exists, and "verification latency" is not defined anywhere in code. |
| **C3** 98% data-mapping accuracy, NLP turning natural-language dietary constraints into alternatives | **Can't verify** | No test set, labelled data, training notebook or eval script. What exists: a TFLite intent classifier (`assets/nlp/chatbot_model.tflite`, 130,192 bytes) with **6 intents** (`label_map.json`: top-rated, worst, sugar-free, high-protein, palm-oil-free, vegan) that filters a **200-product** JSON (`product.json`). Its training data is not in the repo and TensorFlow is not installed here, so I cannot reproduce any accuracy. "Healthier alternatives" come from the cloud model's `healthierSwap` field, not from this NLP. |
| **C4** Ingredient ordering per FSSAI norms; harmful-additive flags per EU guidelines | **Partial** (FSSAI heuristic) / **Missing** (EU) | `IndianWeightedScorer` weights ingredients by list position: 3x for the first 3, 2x for the first half, 1x otherwise. Descending-order listing is a real labelling convention, but **the multipliers and the penalty table are the author's own design, and nothing in the repo cites a regulation.** The score is computed locally but shown only when the cloud call fails (`processing_screen.dart:82`, `:145`). **EU:** no EU regulation, E-number list or citation. `HealthBridge` hard-codes 10 additives with free-text risk strings (one says "FSSAI hazard rating", unsourced) and **is not called from anywhere** in `lib/`. The prompt asks the model to act as an "FSSAI Regulatory Expert (2026 Standards)", which is a prompt, not a data source. |
| **C5** Personalised warnings from allergies **and medicines**, working offline | **Partial** | **Allergies: yes, offline.** ML Kit OCR plus `LocalScanner` regex run with no network. **Medicines: no.** `scanForThreats` takes only `userAllergies` and `userConditions`. `medications` appears only in `toMetadataMap()`, which feeds the **cloud** prompt. Also, the profile is not persisted, so it must be re-entered each launch. Bugs: `local_scanner.dart:50` and `marketing_checker.dart:28` use `\$` in Dart strings, so users see the literal text `${match.group(0)} (High Glycemic)` and `$claim` / `$violator`. |
| **C6** Healthier alternatives, generic-medicine search by salt or brand, dose reminders, NLP search | **Partial** | **Alternatives: yes** (cloud `healthierSwap`). **Generic search by brand / composition: yes**, on-device and offline: `MedicineDbService` indexes `Brand_Name` and `Composition` over **376 rows** (109 + 141 + 126 in the 3 xlsx files; the JSON asset also has 376). "Salt" maps to `Composition`. Caveats: no data source or licence is stated, and it returns the single best match. **Dose reminders: UI only.** `medicine_reminder_screen.dart` has pickers and toggles, but `pubspec.yaml` has no notification or alarm package and no scheduling call exists, so no reminder can fire. The README says "push notifications". **NLP search: yes** (6-intent classifier, see C3). |
| **C7** App size 70 MB → 46 MB after user feedback | **Can't verify** | No APK/AAB or size log exists, and the history has only 3 commits, so there are no before/after commits. Flutter is not installed, so I could not build one. What the repo does show: bundled assets are about 0.9 MB (296 KB medicine DB + 440 KB `assets/nlp`), so size is dominated by the Flutter engine, ML Kit and TFLite native libraries. Size-relevant findings: two **unused** dependencies (`firebase_auth`, `cloud_firestore`), a **duplicate** NLP folder at the repo root (`nlp/` matches `assets/nlp/` byte for byte for the four shared files; only `assets/nlp/` is bundled, so the duplicate does not add to app size), a release build **signed with debug keys**, and no `--split-per-abi` config. |
| **C8** Removed redundant code, reduced server load, added UI animations after feedback | **Partial / Can't verify "after feedback"** | Animations exist: `flutter_animate`, `lottie`, a liquid-glass nav bar, spring-physics widgets. The 3 commits contain no code removal, no change in server calls, and no reference to feedback. "Server load" does not apply to this repo (no server). One defensible design fact: local checks run first, and only OCR **text** (never the image) goes to the cloud. |
| **C9** 200+ users | **Can't verify** | No analytics SDK, no real Firebase project, no Play Console reference, no Releases. GitHub traffic for this repo, last 14 days: **0 page views**, 0 stars, 1 fork, 12 clones (9 unique, which includes you). Where evidence could exist: Play Console or Firebase App Distribution (if a build was ever distributed), a feedback form or sheet, or the logs and analytics of whatever service the live link uses. |
| **C10** How users' medical reports are handled | **Missing as a feature; handling is weak** | **There is no medical-report upload or parsing code in this repo.** `image_picker` is used only for label and medicine photos. What the app does handle is the manually entered health profile (conditions, allergies, medications, BMI, age, goals). That profile is sent in plain text to Gemini and Groq on every scan, using keys stored in the app. It is not saved to disk. There is no consent screen, retention policy, delete-my-data path, PII masking or encryption beyond TLS. The app prints API errors with `debugPrint` and shows the first 120 characters of an exception in a red snackbar. The README's "Firebase for secure user data" is **not implemented**. |

## 3. README and docs vs. code

| README / docs says | Code says |
|---|---|
| "Google Gemini 3.0 Flash, OpenAI GPT-4o, DeepSeek V3 (4+1+1)" | Chain is `gemini-2.0-flash` with 3 keys and Groq `llama-3.1-70b-versatile` with 2 keys (5 nodes). No OpenAI, no DeepSeek. Both model names should be checked against current vendor deprecation lists before any rebuild. |
| "Firebase for secure data" | Unused; demo config. |
| "Push notifications" for reminders | No notification code. |
| "Flutter 3.27+ with Impeller" | `pubspec.yaml` requires Dart `^3.7.2`; Flutter itself is not pinned. |
| Root `PLAN.md` | An old checklist with every box unchecked, including items that are built. Stale. |

## 4. What NutriLens can add for the FDE role

Drishti already covers multi-agent ADK, finance RAG, tracing and evals on Cloud Run. This repo should show **different** evidence.

| Req | Requirement | Drishti covers? | NutriLens opportunity (adjusted by the audit) |
|---|---|---|---|
| R2 | Production AI on Google Cloud | Yes | A second Cloud Run service behind a real mobile client. **Real users only if C9 produces evidence.** |
| R3 | Structured + unstructured pipelines, vector DB + RAG | Yes (finance) | Cited RAG over FSSAI, EU additive and allergen rules, plus a structured additive table. |
| R4 | Multi-agent (ADK, ReAct) | Yes | **Skip.** Retrieve-then-generate is the right design here. |
| R6 | Tokens/sec, cost, state, tracing | Yes | Cost per scan and latency only. |
| R9 | Secure APIs, enterprise data | Partly | **Biggest gap and biggest story:** today there is no backend, keys ship in the app and the login is a demo. Build an authenticated API and handle health data properly, with a documented before/after. |
| R10 | Eval frameworks | Yes | Evals on real label photos: OCR, detection recall, citation correctness. |
| R11 | Field insights → features | Partly | Cannot lean on C7/C8/C9 as written. Rebuild the story from measurements that can be taken now (APK size, latency, what leaves the device). |
| n/a | Hybrid on-device + cloud | No | **Partly exists already** (ML Kit + local rules + cloud model). The work is to make it correct (medicines, additive table, the string bugs), tested and documented. |

## 5. Open questions (only you can answer)

1. C2: what was the 40% measured against, and with what system? (This repo has no such API.)
2. C3: what exactly was 98% accurate, on what data, and where is the test set?
3. C7: do the 70 MB and 46 MB builds, or Play Console / Firebase numbers, still exist?
4. C9: where does "200+" come from?
5. C10: where did users raise the medical-report concern, and in which build?
6. Is the live Netlify page something you own and want connected to this project, or unrelated?
