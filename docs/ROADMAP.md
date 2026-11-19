# Roadmap

This is the single list of everything that remains. The code contains no placeholder, demo-only or "coming soon" paths for these items: a feature that is not built is not in the code.

## Ground rule for this branch

The code on `feat/fde-upgrade` was **written but never compiled, run or tested**. No toolchain was installed and no command was executed against it, so nothing in the repo is claimed to work or to pass. Item V1 is therefore the first thing to do; every other claim depends on it.

Each item lists what it **needs** and when it is **done**.

## A. Verify what is already written

| ID | Item | Needs | Done when |
|---|---|---|---|
| V1 | Run the toolchain over the new code and fix what breaks: `make backend-install backend-lint backend-test`, `flutter pub get` (this also regenerates `pubspec.lock`, which still lists the removed `flutter_dotenv` and `cloud_firestore`), `flutter analyze`, `flutter test`. | Python 3.12 or newer, Flutter SDK, permission to install them | Both CI jobs in `.github/workflows/ci.yml` pass on a pull request, and the test counts are recorded in the PR |
| V2 | Build a release APK from a clean clone with only `app_config.json` (no `.env`) and open it on a device | V1; an Android device or emulator | The app starts, a label scan completes on-device with cloud off |
| V3 | Pin the Flutter SDK version in CI and README | V1 (the version that builds cleanly) | `ci.yml` names an exact version instead of `channel: stable` |
| V4 | Check the assumptions I could not test: `genai.Client(enterprise=True, ...)` arguments for `google-genai` 3.6.1; `task_type` and `output_dimensionality` for `gemini-embedding-001`; that the default model IDs in `backend/nutrilens_api/config.py` exist in the chosen region; that pgvector can be enabled on the Cloud SQL version used; that `flask-limiter` accepts one `Limiter` across several `create_app` calls in tests | V1 and a GCP project | Each assumption is confirmed or the code is corrected, and the config comments name the date checked |
| V5 | Install the pre-commit hooks (`pre-commit install`) and run them once over the repo | V1 | Hooks pass, `gitleaks` reports no findings |

## B. Cloud deployment

| ID | Item | Needs | Done when |
|---|---|---|---|
| D1 | Set up the Firebase project: enable anonymous sign-in, register the Android app, restrict the API key to the app, fill `app_config.json` | GCP project ID, region, billing account | An install can obtain an ID token and `backend` accepts it |
| D2 | Create the budget alert, infrastructure and service with `deploy/00_budget.sh`, `10_infra.sh`, `20_deploy.sh` | Project ID, region, budget amount; a decision on Cloud SQL cost after reading current pricing for the tier in `10_infra.sh` | `GET /healthz` returns 200 and the Cloud Run URL is recorded in the README |
| D3 | Give the ingest job and the runtime separate database users (ingest writes, runtime only reads), add connection pooling, and move rate-limit counters to shared storage | D2 | The runtime user cannot write; the limiter limit holds across instances |
| D4 | Exercise `deploy/teardown.sh` once on a scratch project | D2 | Nothing from the project remains listed in the console |

## C. Regulation corpus and additive table

| ID | Item | Needs | Done when |
|---|---|---|---|
| R1 | Download the regulation documents unchanged from the official sites and complete `data/regulations/SOURCES.md` (title read from each document, version, URL, date, SHA-256, reuse terms) | Your approval to download, or the files from you | Every row of the download log is filled and every candidate in `SOURCES.md` is marked verified or dropped |
| R2 | Write `data/regulations/manifest.json` and run `python -m nutrilens_api.rag.ingest` | R1, D2, Vertex AI access | Chunks and embeddings are in the database; the command's per-document chunk counts are recorded |
| R3 | Author `data/additives.csv` from the regulation text, one row per additive, each with its `source_doc_id` and `source_locator` (the loader rejects rows without them) | R1 | `ingest --additives` loads it without errors |
| R4 | On-device additive table: export `data/additives.csv` to an app asset, add a Dart lookup and use it in the offline scan with the same citation text | R3 | A scan with no network flags a listed E-number and shows its citation |
| R5 | Tune `RETRIEVAL_MAX_DISTANCE` (currently an untuned default) on the eval set | E3 | The chosen value and the evidence are written in `config.py` and `ERROR_ANALYSIS.md` |

## D. Evaluation

| ID | Item | Needs | Done when |
|---|---|---|---|
| E1 | 50 or more label photos from `evals/LABEL_CHECKLIST.md`, plus ground-truth JSON, reviewed by a person | Your photos, or approval to use Open Food Facts images with attribution | `load_labels` returns 50 or more reviewed labels |
| E2 | On-device OCR export: an integration test that runs ML Kit over the label images on a device and writes `evals/results/raw/mlkit_ocr.json` | E1, a device | `report.py` shows an ML Kit row |
| E3 | Run the evals (`flutter test test/eval`, `evals/run_cloud.py`, citation review, `evals/report.py`) and write `evals/ERROR_ANALYSIS.md` | E1, E2, D2, R2, a current ID token | `RESULTS.md` is generated and every false negative is discussed |
| E4 | Latency comparison of on-device, cloud warm and cloud cold on the same labels, and the re-measurement of the claimed latency reduction against a baseline you define | E3; your answer to what the baseline was | The comparison is in `RESULTS.md` |
| E5 | Intent classifier evaluation: a labelled test set of user queries for the 6 intents, and the re-measurement of the claimed mapping accuracy | The classifier's training data or a new labelled set; TensorFlow Lite tooling | A confusion matrix is generated from a documented test set |

## E. App size

| ID | Item | Needs | Done when |
|---|---|---|---|
| S1 | Measure `main` as the baseline and then this branch with `bash scripts/app_size.sh --label <name>` | V1 | `docs/size_log.csv` has both runs |
| S2 | Add ABI splitting, resource shrinking and a real release signing config in `android/app/build.gradle.kts`, then measure again | S1 | The log shows each change's effect on bytes |

## F. Product items not built

None of these exists in the code.

| ID | Item | Needs | Done when |
|---|---|---|---|
| P1 | Account sign-in and family profiles. The Google and phone sign-in buttons, the hard-coded demo logins, the demo data loaders and the "Add Family Member" action were removed because they did nothing real. The app now has a local profile and an anonymous cloud identity only | A decision on whether accounts are wanted; Firebase sign-in providers | Sign-in works on a device and a profile can be switched |
| P1b | Caloric intake chart. The chart on the Progress screen showed fixed numbers, so it was removed | A data source (for example nutrition values captured per scan) | The chart plots recorded values only |
| P2 | Medical-report import, only if users need it. The current design never ingests reports; if it is built, the report is processed in memory and discarded | Your decision | `docs/PRIVACY.md` and a test show nothing from a report is stored or logged |
| P3 | Offline food-medicine interaction notes from a short, sourced list, each with a citation | A reviewed source for each entry | Entries load from a data file and each shows its citation |
| P4 | Dose reminders that fire notifications (the reminder screen is an interface only) | A notification plugin and platform setup | A scheduled reminder fires on a device |
| P5 | Cited healthier alternatives (the earlier uncited suggestion was removed from the cloud flow) | R2 | Each suggestion carries a regulation or nutrition-source citation |
| P6 | Flutter web build: the on-device OCR plugin supports Android and iOS only, so web would use the cloud OCR path (`/v1/ocr-fallback`) | D2; a hosting choice | A web build scans a label through cloud OCR |
| P7 | Cloud OCR option in the Android scan screen for labels the on-device reader cannot read (the `CloudClient.ocrFallback` method exists; no screen calls it) | D2 | The user can choose cloud OCR for one scan, and the screen says the photo is sent |

## G. Housekeeping

| ID | Item | Needs | Done when |
|---|---|---|---|
| H1 | Remove the duplicate root `nlp/` folder (its files are byte-identical to `assets/nlp/`, which is the copy the app bundles) | A check that nothing references it | The folder is deleted and the build is unaffected |
| H2 | Retire the old root `PLAN.md` checklist and `NutriLens_App_Details.md` claims that no longer match the code | None | They match the code or are removed |
| H3 | Fill `docs/USER_FEEDBACK.md` and finish `RESUME_FACTS.md` section 3 from real measurements | S1, E3, evidence for the user count | No empty measured cell remains |
| H4 | Screenshots and a demo recording for the README | V2 | The README embeds them |
| H5 | Push the branch and open the pull request | Your go-ahead. I will not merge | A PR exists and CI has run |
