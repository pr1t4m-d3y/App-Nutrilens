# Resume facts for NutriLens

**Status: draft. Code for several rewritten claims now exists on `feat/fde-upgrade` but has never been compiled or run, so none of it is claimable as working.** Section 1 can be said in an interview today. Section 2 lists claims to remove or reword. Section 3 is empty on purpose and fills in only from real runs. Evidence is as of 2026-11-19 on branch `feat/fde-upgrade` (see `docs/AUDIT.md` for detail).

## 1. Verified today (safe to say)

| Fact | Proof (file or command) |
|---|---|
| Cross-platform **Flutter/Dart** app; `lib/` has 38 Dart files | `git ls-files 'lib/*.dart' \| wc -l` returns 38 |
| **On-device OCR** of food labels and medicine packs using Google ML Kit | `lib/screens/scan_screen.dart:74`, `medicine_scan_screen.dart:74` |
| **On-device allergen check:** a regex check for 7 allergen groups plus hidden sugars triggers an alert and haptic buzz on a match (verified at `2de80de`, where it ran alongside the cloud request; on this branch it runs first and the cloud call is optional, which is written but not run) | `lib/services/local_scanner.dart`, `lib/screens/processing_screen.dart` |
| **Offline generic-medicine lookup** by brand or composition over a **376-row** curated dataset, indexed in memory | `lib/services/medicine_db_service.dart`; `assets/medicine_db.json` has 376 entries |
| **On-device TFLite intent classifier** (6 intents) that filters a 200-product catalogue | `assets/nlp/label_map.json`; `lib/services/nutri_nlu_service.dart` |
| **Cloud LLM fallback chain** of 5 nodes (Gemini and Groq) with a 30 s timeout per node. This was true at `2de80de`; the file was deleted on this branch and replaced by the backend, so describe it as past work | `git show 2de80de:lib/services/api_fallback_engine.dart` |
| A **marketing-claim checker** for 6 claim phrases, and an ingredient-position-weighted scoring heuristic | `lib/services/marketing_checker.dart`, `indian_weighted_scorer.dart` (the weights are my own design, not from regulation) |
| UI built with animation libraries (`flutter_animate`, `lottie`) and a custom glass nav bar | `pubspec.yaml`; `lib/widgets/liquid_glass_nav_bar.dart` |

Honest framing to use: "built a Flutter app that does OCR and allergen checks on-device and uses a cloud LLM for deeper analysis." Do not call the cloud part a backend you built.

## 1b. Written on this branch but not run (do not say it works)

You can truthfully say you wrote these. You cannot say they work, pass or are deployed until the roadmap item in the last column closes.

| Written | Roadmap item that makes it claimable |
|---|---|
| Flask API with Firebase ID-token (JWT) verification, rate limiting and request validation | V1 (tests run), D2 (deployed) |
| Retrieval pipeline: structure-aware chunker, pgvector store, hybrid E-number + vector search, citation enforcement | V1, R2 (ingested real text) |
| Dockerfile (multi-stage, non-root) and Cloud Run / Cloud SQL / Secret Manager deploy and teardown scripts | D2, D4 |
| On-device medicine-vs-profile check, encrypted profile storage, consent dialog, delete-all-data action | V1, V2 |
| Eval harness: metrics, label loader, cloud runner, safety cases, on-device OCR export, generated report | E3 |
| Regulation search endpoint and screen; cloud OCR option on the scan screen; on-device additive table reader and exporter | V1, D2, R2, R3 |
| JWT verification with explicit issuer and audience checks; code-reading security review (`docs/SECURITY.md`) | V1, D2 |
| Unit tests (Python and Dart), CI workflow, pre-commit config, Makefile | V1, V5 |

## 2. Claims to remove or reword

| Resume claim | Verdict | Suggested wording (or action) |
|---|---|---|
| Java (Android) | False for this repo. No Java; the Android app is Flutter/Dart. | "Flutter/Dart (Android)". |
| Flask, REST APIs, JWT | Not in this repo. | Remove now. Re-add "Flask REST API on Cloud Run with JWT auth" **only after** ROADMAP V1 and D2 close (tests executed, service deployed). |
| 40% lower verification latency | No baseline, no benchmark, no such API. | Remove. Re-add only if plan item R1 measures a defined baseline. |
| 98% data-mapping accuracy | No test set or method found. | Remove. Replace with the measured figure from plan item R2, with the test set size. |
| FSSAI-compliant ordering | The weights are an unsourced heuristic. | After plan item B1: "flags checked against named FSSAI and EU regulations with citations". Until then: "position-weighted ingredient scoring". |
| EU-guideline additive flags | Nothing EU-sourced exists. | Remove until B1 ships. |
| Personalised warnings from allergies **and medicines**, offline | Medicines are not checked offline. Profile is not saved. | Until F3 ships: "offline allergen checks". |
| Dose reminders | UI only; no notifications fire. | "medicine reminder interface" or remove. |
| Healthier alternatives | Cloud model suggestion, not a curated engine. | "AI-generated healthier alternatives". |
| App size 70 MB to 46 MB | No builds or history to support it. | Remove unless you have the builds. Otherwise quote plan item R3's measured before/after. |
| Removed redundant code, reduced server load after feedback | No commits show it; this repo has no server. | Remove, or tie to specific commits that exist. |
| 200+ users | No evidence found (0 GitHub views in 14 days). | Keep only with a source (store console, form, analytics export). State what "user" means. |
| Handles users' medical reports | No such feature. | Remove, or see plan Decision 5. |
| Firebase for secure data (README) | Unused, demo config. | Remove from README now. |

## 3. Pending measurements (empty until a run produces them)

| Metric | Source | Value | Date | Commit |
|---|---|---|---|---|
| Release APK / AAB size, before and after | `scripts/app_size.sh` | | | |
| Ingredient-mapping accuracy | `evals/results/RESULTS.md` | | | |
| OCR error rate, ML Kit vs. Gemini | `evals/results/RESULTS.md` | | | |
| Allergen detection precision and recall; missed allergens listed | `evals/results/RESULTS.md` | | | |
| Citation correctness | `evals/results/RESULTS.md` | | | |
| Latency p50 / p95: on-device, cloud warm, cloud cold | `evals/results/RESULTS.md` | | | |
| Cost per scan | `evals/results/RESULTS.md` | | | |
| Cloud Run URL | `deploy/` output | | | |
| Test count and coverage | CI run | | | |

## 4. Rule for interviews

If you cannot point to a file or a command output for a number, do not say the number. "I measured X on N labels, here is the script" is a stronger answer than a bigger number you cannot reproduce.
