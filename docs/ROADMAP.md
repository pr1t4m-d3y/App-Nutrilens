# Roadmap

This is the single list of everything that remains. The code contains no placeholder, demo-only or stubbed paths for these items: a feature that is not built is not in the code.

## Ground rule for this branch

The code in this repository was **written but never compiled, run or tested**. No toolchain was installed and no command was executed against it, so nothing in the repo is claimed to work or to pass. Item V1 is therefore the first thing to do; every other claim depends on it.

Each item lists what it **needs** and when it is **done**.

## A. Verify what is already written

| ID | Item | Needs | Done when |
|---|---|---|---|
| V1 | Run the toolchain over the new code and fix what breaks: `make backend-install backend-lint backend-test`, `flutter pub get` (this also regenerates `pubspec.lock`, which still lists the removed `flutter_dotenv` and `cloud_firestore`), `flutter analyze`, `flutter test`. | Python 3.12 or newer, Flutter SDK, permission to install them | Both CI jobs in `.github/workflows/ci.yml` pass on a pull request, and the test counts are recorded in the PR |
| V2 | Build a release APK from a clean clone with only `app_config.json` (no `.env`) and open it on a device | V1; an Android device or emulator | The app starts, a label scan completes on-device with cloud off |
| V3 | Confirm the app builds and runs on the Flutter version CI uses (3.50.0), and keep the README prerequisite in step | V1 | `flutter run` succeeds on that version and CI stays green |
| V4 | Check the assumptions that could not be tested: `genai.Client(enterprise=True, ...)` arguments for `google-genai` 2.34.0; `task_type` and `output_dimensionality` for `gemini-embedding-001`; that the default model IDs in `backend/nutrilens_api/config.py` exist in the chosen region; that pgvector can be enabled on the Cloud SQL version used; that `flask-limiter` accepts one `Limiter` across several `create_app` calls in tests | V1 and a GCP project | Each assumption is confirmed or the code is corrected, and the config comments name the date checked |
| V5 | Install the pre-commit hooks (`pre-commit install`) and run them once over the repo | V1 | Hooks pass, `gitleaks` reports no findings |
| M1 | Confirm the ADK integration assumptions listed at the end of `docs/MULTI_AGENT.md` against ADK 1.39.1 (runner and session signatures, instruction functions bypassing templating, Vertex environment variables, `generate_content_config` with tools, event fields, container memory) | V1, a GCP project | `backend/tests/test_agents.py` passes, one real `/v1/analyze` call returns, and the doc's assumptions list is marked confirmed or corrected |

## B. Cloud deployment

| ID | Item | Needs | Done when |
|---|---|---|---|
| D1 | Set up the Firebase project: enable anonymous sign-in, register the Android app, restrict the API key to the app, fill `app_config.json` | GCP project ID, region, billing account | An install can obtain an ID token and `backend` accepts it |
| D2 | Create the budget alert, infrastructure and service with `deploy/00_budget.sh`, `10_infra.sh`, `20_deploy.sh` | Project ID, region, budget amount; a decision on Cloud SQL cost after reading current pricing for the tier in `10_infra.sh` | `GET /healthz` returns 200 and the Cloud Run URL is recorded in the README |
| D3 | Give the ingest job and the runtime separate database users (ingest writes, runtime only reads), add connection pooling, and move rate-limit counters to shared storage | D2 | The runtime user cannot write; the limiter limit holds across instances |
| D4 | Exercise `deploy/teardown.sh` once on a scratch project | D2 | Nothing from the project remains listed in the console |
| D5 | Firebase App Check, so the API can tell a genuine app install from a script holding an anonymous token (see `docs/SECURITY.md`) | D1 | The backend rejects requests without a valid App Check token |
| D6 | Cloud Monitoring alerts on error rate and latency, and an IP-level throttle for requests that fail authentication | D2 | An alert fires on a forced failure in a scratch project |

## C. Regulation corpus and additive table

| ID | Item | Needs | Done when |
|---|---|---|---|
| R1 | Download the regulation documents unchanged from the official sites and complete `data/regulations/SOURCES.md` (title read from each document, version, URL, date, SHA-256, reuse terms) | Permission to download, or the files supplied | Every row of the download log is filled and every candidate in `SOURCES.md` is marked verified or dropped |
| R2 | Write `data/regulations/manifest.json` and run `python -m nutrilens_api.rag.ingest` | R1, D2, Vertex AI access | Chunks and embeddings are in the database; the command's per-document chunk counts are recorded |
| R3 | Author `data/additives.csv` from the regulation text, one row per additive, each with its `source_doc_id` and `source_locator` (the loader rejects rows without them) | R1 | `ingest --additives` loads it without errors |
| R4 | On-device additive table: the exporter (`make export-additives`), the Dart reader and the scan integration are written. What remains is the data and the export | R3 | `assets/additives/additives.json` exists and a scan with no network flags a listed E-number with its citation |
| R5 | Tune `RETRIEVAL_MAX_DISTANCE` (currently an untuned default) on the eval set | E3 | The chosen value and the evidence are written in `config.py` and `ERROR_ANALYSIS.md` |

## D. Evaluation

| ID | Item | Needs | Done when |
|---|---|---|---|
| E1 | 50 or more label photos from `evals/LABEL_CHECKLIST.md`, plus ground-truth JSON, reviewed by a person | Label photos, or approval to use Open Food Facts images with attribution | `load_labels` returns 50 or more reviewed labels |
| E2 | On-device OCR export: `integration_test/ocr_export_test.dart` is written. It has to be run on a device with the label images pushed (steps are in the file header) | E1, an Android device | `evals/results/raw/mlkit_ocr.json` exists and `report.py` shows an ML Kit row |
| E3 | Run the evals (`flutter test test/eval`, `evals/run_cloud.py`, `evals/run_safety.py`, citation review, `evals/report.py`) and write `evals/ERROR_ANALYSIS.md` | E1, E2, D2, R2, a current ID token | `RESULTS.md` is generated and every false negative is discussed |
| E4 | Latency comparison of on-device, cloud warm and cloud cold on the same labels, and a latency comparison against a defined baseline | E3; a decision on what the baseline is | The comparison is in `RESULTS.md` |
| E5 | Intent classifier evaluation: a labelled test set of user queries for the 6 intents, and a measurement of its accuracy | The classifier's training data or a new labelled set; TensorFlow Lite tooling | A confusion matrix is generated from a documented test set |
| E6 | Compare `/v1/explain` and `/v1/analyze` on the same labels (`run_cloud.py --endpoint explain` and `--endpoint analyze`, both citation sheets reviewed) and apply the decision rule in `docs/MULTI_AGENT.md` | E1, E3, D2, M1 | `RESULTS.md` shows both pipelines and the default for the app is set by the rule |
| E7 | Per-model prices so multi-agent cost is not an upper bound | E3 | The report applies a price per model |

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
| P2 | Medical-report import, only if users need it. The current design never ingests reports; if it is built, the report is processed in memory and discarded | A decision on scope | `docs/PRIVACY.md` and a test show nothing from a report is stored or logged |
| P3 | Offline food-medicine interaction notes from a short, sourced list, each with a citation | A reviewed source for each entry | Entries load from a data file and each shows its citation |
| P4 | Dose reminders that fire notifications (the reminder screen is an interface only) | A notification plugin and platform setup | A scheduled reminder fires on a device |
| P5 | Cited healthier alternatives (the earlier uncited suggestion was removed from the cloud flow) | R2 | Each suggestion carries a regulation or nutrition-source citation |
| P6 | Flutter web build: the on-device OCR plugin supports Android and iOS only, so web would use the cloud OCR path (`/v1/ocr-fallback`) | D2; a hosting choice | A web build scans a label through cloud OCR |

## G. Housekeeping

| ID | Item | Needs | Done when |
|---|---|---|---|
| H4 | Screenshots and a demo recording for the README | V2 | The README embeds them |
