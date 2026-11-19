# Resume facts for NutriLens

**Status: draft, before any build.** Section 1 can be said in an interview today. Section 2 lists claims to remove or reword. Section 3 is empty on purpose and fills in only from real runs. Evidence is as of 2026-11-19 on branch `feat/fde-upgrade` (see `docs/AUDIT.md` for detail).

## 1. Verified today (safe to say)

| Fact | Proof (file or command) |
|---|---|
| Cross-platform **Flutter/Dart** app; `lib/` has 38 Dart files | `git ls-files 'lib/*.dart' \| wc -l` returns 38 |
| **On-device OCR** of food labels and medicine packs using Google ML Kit | `lib/screens/scan_screen.dart:74`, `medicine_scan_screen.dart:74` |
| **Local-first scan flow:** an on-device regex check for 7 allergen groups plus hidden sugars runs while the cloud request is in flight, and triggers an alert and haptic buzz if it matches | `lib/services/local_scanner.dart`, `lib/screens/processing_screen.dart:67-100` |
| **Offline generic-medicine lookup** by brand or composition over a **376-row** curated dataset, indexed in memory | `lib/services/medicine_db_service.dart`; `assets/medicine_db.json` has 376 entries |
| **On-device TFLite intent classifier** (6 intents) that filters a 200-product catalogue | `assets/nlp/label_map.json`; `lib/services/nutri_nlu_service.dart` |
| **Cloud LLM fallback chain** of 5 nodes (Gemini and Groq) with a 30 s timeout per node | `lib/services/api_fallback_engine.dart` |
| A **marketing-claim checker** for 6 claim phrases, and an ingredient-position-weighted scoring heuristic | `lib/services/marketing_checker.dart`, `indian_weighted_scorer.dart` (the weights are my own design, not from regulation) |
| UI built with animation libraries (`flutter_animate`, `lottie`) and a custom glass nav bar | `pubspec.yaml`; `lib/widgets/liquid_glass_nav_bar.dart` |

Honest framing to use: "built a Flutter app that does OCR and allergen checks on-device and uses a cloud LLM for deeper analysis." Do not call the cloud part a backend you built.

## 2. Claims to remove or reword

| Resume claim | Verdict | Suggested wording (or action) |
|---|---|---|
| Java (Android) | False for this repo. No Java; the Android app is Flutter/Dart. | "Flutter/Dart (Android)". |
| Flask, REST APIs, JWT | Not in this repo. | Remove now. Re-add "Flask REST API on Cloud Run with JWT auth" **only after** plan items F2 and B4 ship and their tests pass. |
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
