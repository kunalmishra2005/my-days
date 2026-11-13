# MY DAY'S — Brand Governance

MY DAY'S is a Flutter brand-governance review app. It helps reviewers configure
brand guidance, preserve submitted drafts, inspect explainable deterministic
checks, record a human review, and explore review history. It never publishes
content automatically.

## Judge demo access

The fastest way to explore the fictional judge demo is to run the app with no
Supabase compile-time values:

```powershell
cd C:\my_days\brand_governance
flutter pub get
flutter run -d chrome
```

Select **Explore sample workspace** on the landing screen. This local demo
provides fictional Northstar Community guidelines, sample submissions,
deterministic analysis, and one sample decision. It requires no account and
uses no developer credentials. Its records stay in browser/device
SharedPreferences under a fixed demo-only local identity. They are not cloud
records, are not protected by Supabase RLS, and must not contain real or
sensitive data. Sign out to return to the landing screen.

If exactly one Supabase compile-time value is provided, the app displays a
configuration error instead of silently switching to demo mode. With both
values configured, the app uses Supabase authentication and cloud adapters;
the signed-out landing screen also offers the separate local sample demo.
There is no provisioned judge cloud account or credential in this repository.
Do not invent or share credentials for the judges.

### Optional restricted judge cloud account

If cloud review is required, an authorized project administrator must manually
prepare it before distributing access:

1. Create a dedicated fictional judge user in Supabase Auth; do not reuse a
   developer/personal account.
2. Provision exactly the intended workspace and membership through an
   administrator-controlled, server-side process. The Flutter app cannot
   safely perform this multi-request provisioning.
3. Assign only the approved reviewer-level permissions, confirm RLS denies
   access to other workspaces, and ensure the workspace already has exactly
   one guideline row before judges try to edit guidelines.
4. Sign in with the ordinary judge account and test the complete journey
   against the actual hosted project. Never share a service-role key or embed
   it in the app.
5. Send any judge credentials separately through an approved private channel;
   this repository intentionally contains no demo cloud credentials.

## Supabase setup

Use the project URL and **publishable** key from the Supabase project settings.
Never use a service-role key in Flutter. Example (PowerShell):

```powershell
flutter run -d chrome `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

The existing production database and RLS policies are expected; this app does
not create or migrate database objects. An authorized administrator must
provision a workspace and membership for each account through an approved,
safe process before that account can use the cloud workspace. Then the app
verifies membership and workspace access through the authenticated client.
Accounts with no membership or ambiguous workspace membership receive an
actionable error and retry/sign-out options.

### Cloud persistence status

The app has authenticated-client adapters for `workspaces`,
`workspace_members`, `brand_guidelines`, `content_submissions`, and
`review_decisions`. These adapters and their mapping behavior are covered by
injected fake-gateway tests; a live production Supabase connection has not
been verified as part of this source-only implementation.

Safe operations and limitations:

- Workspace lookup verifies the current authenticated user's membership and
  loads only the matching accessible workspace.
- Client-side workspace creation is disabled. Workspace and membership
  inserts require multiple requests and the verified schema provides no
  atomic provisioning operation, so a failed/interleaved operation could
  create an orphan or duplicate.
- Existing single guideline rows can be updated by their primary key. First
  guideline creation is disabled because `brand_guidelines.workspace_id` has
  no unique constraint or safe atomic create operation. Multiple rows are
  reported as an ambiguity.
- Submissions use workspace scope, stable submission UUIDs, original body
  text, and the authenticated user as `submitted_by`.
- Review decisions are inserted as new history rows. The authenticated user
  supplies `reviewer_id`; existing `notes` stores the reviewer metadata.
- `analysis_snapshots` and `audit_events` are not written. Cloud errors do not
  silently fall back to local storage.

These client-side membership checks improve clarity but do not replace RLS.
No database schema, policy, trigger, or function is changed by the app.

## Features

- **Guidelines:** brand name/description, tone, custom tone, approved and
  required terms, prohibited phrases, and user-provided verified facts.
- **Submissions:** local demo drafts or workspace-scoped Supabase records.
  Draft text is retained unchanged.
- **Deterministic analysis:** phrase matching, limited tone markers,
  conservative claim-pattern advisories, and configured verified-statement
  recognition.
- **Explainability:** findings include severity, matched source span where
  available, guideline reference, explanation, suggested correction, and
  human-verification flags.
- **Human review:** Approve, Request Changes, or Reject; cloud decisions are
  appended rather than replacing prior decisions.
- **Review history and analytics:** search/filter/sort current records and
  derive metrics. Analysis is recomputed using current guidelines.
- **Responsive navigation:** desktop navigation rail and mobile navigation
  bar.
- **AI boundary:** typed request/response and validation interfaces, fixture
  provider for tests, and an Adaption Labs integration seam.

## Architecture

- Flutter Material 3 / Dart; feature-oriented source under `lib/features/`.
- `AuthenticationService` abstracts Supabase Auth and local judge-demo auth.
- Workspace/data repositories use injected abstractions; production storage
  uses the authenticated Supabase client and RLS.
- `SharedPreferences` adapters remain for tests and explicitly local demo
  flows, partitioned by a local demo/account ID.
- Domain analysis and models are separate from screens and storage adapters.
- `analysis_snapshots` are not persisted; the analytics screen reruns the
  deterministic engine against currently saved guidelines.

## Round 2 source and the three Round 3 recommendations

The local [Round 2 development summary](docs/ROUND_2_SUMMARY.md) documents
these three Round 3 improvement **recommendations**:

| # | Recommendation recorded in the local Round 2 summary | Current status |
|---|---|---|
| 1 | Secure backend: authenticated workspace access, encrypted persistence, tenant isolation, consent/retention controls, and append-only decision/analysis audit trail | **Partial.** Authenticated workspace-scoped adapters and RLS use are implemented, but safe provisioning is blocked, client-side encryption/consent/retention controls are absent, and analysis/audit event persistence is not implemented. |
| 2 | Confirm Adaption Labs details and integrate through a backend with validation, observability, rate limits, privacy safeguards, and human-reviewed evaluation | **Blocked / not connected.** Provider endpoint, contract, credentials, and backend details are unavailable. No live AI request is made or claimed. |
| 3 | Expand brand-rule coverage and analytics with historical snapshots, workload/turnaround views, accessible visualizations, and mobile/desktop usability testing | **Partial.** Existing deterministic rules, derived analytics, responsive UI, and the judge flow exist. Historical snapshots, workload/turnaround analytics, richer rules, and formal usability testing are outstanding. |

This repository contains the local summary, not an independently verifiable
copy of the official Round 2 submission or judging agreement. Therefore it
cannot establish that these recommendations were the exact three commitments
submitted to CodeNexus. Confirm them against the official submission before
describing them as binding commitments.

## AI, privacy, and analysis limitations

No live Adaption Labs provider is configured; analysis is deterministic. A
test fixture is not live AI. Heuristic findings are advisories and do not
establish that a claim is true, false, or misleading. The app does not
autonomously publish or approve content. Local demo data is fictional and
not encrypted or synchronized.

## Validation

Run from this directory:

```powershell
dart format lib test
flutter analyze
flutter test
flutter build web
```

Latest local validation for this source state:

- `dart format lib test` — passed.
- `flutter analyze` — passed with no issues.
- `flutter test` — passed, 92 tests. Repository/fake-gateway tests do not
  verify a live Supabase service.
- `flutter build web` — passed. A successful build is not a deployed project
  URL.

## Final submission checklist

- [ ] Working deployed project URL — not present or verified in this repository.
- [ ] Public source repository — [GitHub repository](https://github.com/kunalmishra2005/my-days)
  is reachable, but current uncommitted worktree changes are not published.
- [ ] Product PDF — no PDF submission artifact is present in this project.
- [x] Feature list — documented above.
- [x] Technical architecture — documented above.
- [x] Three Round 3 recommendations and implementation status — documented
  above; official-submission match is unverified.
- [x] Testing details — recorded above; no live Supabase or deployment test is
  claimed.
- [x] Product roadmap — the remaining portions of the three recommendations
  above are the roadmap.

Do not submit fictional URLs, credentials, test results, AI integration, or
cloud capabilities as verified facts.
