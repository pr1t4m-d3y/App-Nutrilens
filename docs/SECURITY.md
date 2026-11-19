# Security review

**Scope and method.** This is a review of the code by reading it. The service has not been run, deployed, scanned or penetration tested, so nothing here is evidence that a control works. It records what each control is designed to do, where it lives, and what is known to be missing.

## Assets and trust boundaries

| Asset | Where it lives | Boundary |
|---|---|---|
| Health profile (allergies, conditions, medicines, body measurements) | Phone, encrypted (`flutter_secure_storage`) | Leaves the device only as a minimised subset, only with consent |
| Label text, search text, label photos | In transit to the API, processed in memory | TLS to Cloud Run; not stored |
| Model access (Vertex AI) | Cloud Run service account | No API key anywhere; the app has none |
| Database password | Secret Manager, injected as an environment variable | Not in the image, repo or app |
| Regulation corpus | Cloud SQL | Public documents; low sensitivity |

## JWT review (`backend/nutrilens_api/auth.py`)

| Check | How |
|---|---|
| Token present and well-formed | `Authorization: Bearer <token>` required on every `/v1/` route; other schemes and empty tokens are rejected |
| Signature and expiry | `google.oauth2.id_token.verify_firebase_token`, which verifies against Google's published Firebase signing certificates |
| Audience | Passed to the library, and checked again explicitly: `aud` must equal the Firebase project ID |
| Issuer | Checked explicitly: `iss` must equal `https://securetoken.google.com/<project id>`. The library is not relied on for this |
| Subject | `sub` must be present; it becomes the user key for rate limiting and for the hashed id in logs |
| Failure behaviour | Any failure returns `401 {"error": "unauthorized"}` with no detail, and nothing from the token is logged |

Unit tests for these cases are written in `backend/tests/test_schemas_auth_logging.py` and `test_routes.py`. They have not been run.

**Limit of this design.** Anonymous sign-in is free and unlimited, so a JWT proves "some install of this Firebase project", not "a genuine copy of the app" and not "a distinct person".

## Threats and controls

| Threat | Control in code | Known gap |
|---|---|---|
| Calls without a valid identity | JWT required on `/v1/` | None known for this path |
| Abuse by minting many anonymous identities | Per-user rate limit; `--max-instances` and `--concurrency` in `deploy/20_deploy.sh`; budget alert | Limits are per user, so many identities defeat them. Counters are per instance. **Firebase App Check is not built** and would address this (roadmap D5) |
| Failed-auth floods | Rejected before any model or database work | No IP-level limit for requests that fail authentication |
| Oversize or malformed input | `MAX_CONTENT_LENGTH`, 64 KB cap on JSON bodies, length limits on label text, query and profile lists, image type checked from magic bytes | None known |
| Data minimisation bypass | The explain endpoint rejects any field other than label text and three short lists | The label text itself is free text and could contain personal data the user typed on a label |
| Prompt injection through label text | Label text is delimited and labelled as data in the prompt; model output is parsed as strict JSON; every returned entry must cite a retrieved source or it is dropped | A model can still repeat injected text inside a *cited* reason. `evals/run_safety.py` measures this; it is not assumed away |
| Uncited or invented claims | `enforce_citations` drops entries without a valid citation; empty retrieval returns "no source found" without calling the model | The citation proves the source was retrieved, not that it supports the claim. Citation correctness is measured by human review in the evals |
| Sensitive data in logs | Bodies are never logged; exceptions logged by type only; text masking for tokens, emails and long numbers; user id logged only as a 12-character hash | The masking patterns are heuristic |
| Secret leakage | No model keys exist; DB password from Secret Manager; `.gitignore` for local config; gitleaks in pre-commit | Pre-commit and gitleaks have not been run |
| Container compromise | Multi-stage image, non-root user (uid 10001), no build tools in the runtime image | Base image pinned by tag, not by digest |
| Over-privileged identity | Runtime service account has `aiplatform.user`, `cloudsql.client` and read access to one secret | The runtime and the ingest job share one database user; the runtime should be read-only (roadmap D3) |
| Lost or stolen phone | Profile encrypted with the platform keystore; Android backup disabled so keys and data are not restored elsewhere | No app-level lock screen or biometric gate |
| Cross-origin abuse | No CORS headers are sent; the API is for the mobile app | A web client would need an explicit CORS policy |

## Not built

- Firebase App Check (device and app attestation)
- IP-based throttling and a WAF (Cloud Armor)
- Shared rate-limit storage across instances
- Separate read-only database role for the runtime
- Alerting on error rate and latency (Cloud Monitoring)
- An external security test

Each appears in `docs/ROADMAP.md` with what it needs.
