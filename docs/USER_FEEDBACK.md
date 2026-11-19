# User feedback → shipped change → measured effect

**Status: template. Every "measured effect" cell is empty on purpose.** Nothing in this repo records user feedback, a build before a change, or a size or latency figure from before a change (AUDIT C7, C8, C9). I will not fill these cells from memory or from the resume. Each one is filled only from a command output, a log or a source you give me, with the date.

How to use: for each piece of feedback, give the source (who said it, where, when), what changed, which commit, and how the effect was measured.

| # | Feedback (as received) | Source and date | Change shipped | Commit | Metric | Before | After | How measured | Status |
|---|---|---|---|---|---|---|---|---|---|
| 1 | "App is too large" | *you to supply* | `cloud_firestore` and `flutter_dotenv` removed from `pubspec.yaml` (written, not yet measured); ABI split and resource shrink (roadmap S2, not built) | *pending* | Release APK / AAB size (MB) | *measure on current `main`* | *measure on branch* | `scripts/app_size.sh` output | Not started |
| 2 | "Too dependent on AI" | *you to supply* | Phone rules cover allergens, the avoid list, condition rules and the user's medicine list without the network (plan B2, F3). The on-device additive table is not built (roadmap R4) | *pending* | Share of eval labels where a correct warning appears with the network off | *measure* | *measure* | `evals/results/RESULTS.md` | Not started |
| 3 | "Worried about medical-report privacy" | *you to supply* | Data minimisation, consent, encrypted local storage, delete endpoint (plan B3) | *pending* | Fields sent to the cloud per scan, before vs. after | *measure: at `2de80de` the prompt included 6 profile fields (BMI, goals, conditions, allergies, medications, avoid list; see `git show 2de80de:lib/services/smart_scan_service.dart`, `_buildPrompt`)* | *measure* | A test that captures the outgoing request | Not started |
| 4 | *(add others, e.g. animations)* | | | | | | | | |

Notes:
- Row 3's "before" is a count read from the code at `2de80de`: the prompt includes BMI, goals, conditions, allergies, medications and the avoid list. It will be re-counted by a test, not copied from here.
- If the original 70 MB and 46 MB builds exist, put them in row 1 with their source. If not, row 1 reports only what `scripts/app_size.sh` measures from now on.
