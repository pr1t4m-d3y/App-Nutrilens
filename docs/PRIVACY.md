# Privacy and health-data handling

Two sections, kept separate on purpose: what the app does **today** (checked in the audit), and what the **target policy** is. The target is not implemented until the matching plan item (B3, F1, F2, F3) ships. This file must be updated, not trusted, when code changes.

## 1. Today (verified 2026-11-19)

| Question | Answer | Evidence |
|---|---|---|
| What personal data does the app hold? | Name, height, weight, age, BMI, goals, chronic conditions, allergies, skin sensitivities, medications, manual avoid list. | `lib/providers/user_profile_provider.dart` |
| Does it handle uploaded medical reports? | **No such feature exists.** Cameras and `image_picker` are used for food labels and medicine strips only. | grep of `lib/` |
| Where is the data stored? | In memory only. Lost when the app closes. Nothing is written to disk. | no persistence API found |
| What leaves the device? | OCR text of the label (not the image) **plus** BMI, goals, conditions, allergies, medications and avoid list, sent as plain text in a prompt to Google Gemini and Groq on every scan. | `smart_scan_service.dart` `_buildPrompt` |
| How is that call authenticated? | With API keys read from a `.env` file bundled inside the app. Anyone who unpacks the APK can read them. | `pubspec.yaml`, `api_fallback_engine.dart` |
| Encryption | TLS in transit only. Nothing at rest, because nothing is stored. | |
| User accounts | Hard-coded demo logins. No real identity. | `login_screen.dart` |
| Consent | None shown. | |
| Retention policy | None. Third-party model providers' own retention terms apply and are not reviewed here. | |
| Delete my data | No mechanism (nothing local to delete; nothing is known about provider-side copies). | |
| Logging | `debugPrint` of API errors. A red snackbar shows the first 120 characters of an exception text. Exception text from a provider can echo request content, so this is a leak risk, not a confirmed leak. | `api_fallback_engine.dart`, `processing_screen.dart` |

## 2. Target policy (not yet implemented)

| Area | Rule |
|---|---|
| Minimisation | Send the cloud only what the task needs: label text and coarse flags (for example "type 2 diabetes", "peanut allergy"). Never name, age, free-text notes, or the label image unless the user chooses the cloud OCR fallback for that scan. |
| Keys | No model keys in the app, ever. They live in Secret Manager and are read only by the Cloud Run service account. |
| Identity | Firebase anonymous auth. Each install gets a JWT; the API verifies it on every request. No email or phone needed. |
| Local storage | Profile stored encrypted on the device using the platform keystore. |
| Server storage | **None by default.** Requests are processed in memory. Only non-identifying operational metrics (latency, status code, token counts) are logged. |
| Log hygiene | Request bodies are never logged. Profile fields and label text are masked or omitted. Exception text is scrubbed before logging. |
| Consent | A first-run screen states what is sent to the cloud and why, and the cloud explanation can be switched off. The phone-only checks keep working with it off. |
| Delete my data | `DELETE /v1/me` and an in-app "delete everything" button. The endpoint exists even though the server stores nothing by default, so the guarantee is testable. |
| Retention | Local data: until the user deletes it or uninstalls. Server: none. Any future server-side storage requires a documented retention period before it ships. |
| Medical reports | **Decision pending** (plan Decision 5). Option (b), the recommendation: reports are never ingested, and this document says so. Option (a): a report goes to the API in memory, only allergies and active medicines are extracted and returned to the phone, and the file is discarded. A test must prove nothing from the report is persisted or logged. |
| Third-party processors | Vertex AI (Google Cloud) for model calls, under the project's own terms. Confirm the data-use terms for the chosen region and model in current Google Cloud documentation before launch, and record the result here. |
| Not medical advice | Every warning screen says the output is informational and not a substitute for a clinician. |

## 3. How each rule will be proven

Each target rule needs a test or a command whose output goes in the PR: a test that the request body sent to the cloud contains no name or age; a test that the log output contains no profile text; a test that `DELETE /v1/me` returns success and leaves nothing; a scan of the built APK showing no key strings.
