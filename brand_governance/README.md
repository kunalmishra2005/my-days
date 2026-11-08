# MY DAY'S — Brand Governance

MY DAY'S is a local-first Flutter demo for reviewing brand content before
publication. It helps a team configure brand guidance, submit unchanged drafts,
inspect deterministic checks, record a human decision, and understand activity
from saved records. It never publishes content autonomously.

## Features

- **Brand guidelines:** profile, tone, approved and required terminology,
  prohibited phrases, and user-supplied verified facts.
- **Content submission:** local draft submission with a stable ID and creation
  timestamp; the submitted body is preserved.
- **Deterministic analysis:** whole-phrase prohibited-term matching, approved
  terminology advisories, required-term checks, limited formal-tone markers,
  conservative claim-pattern advisories, and configured verified-statement
  recognition.
- **Explainable results:** severity, matched source span, explanation,
  guideline reference, correction guidance, and human-verification flags.
- **Human review:** Approve, Request Changes, or Reject with reviewer, reason,
  comments, timestamp, and the analysis status used at decision time.
- **Review history and analytics:** search/filter/sort saved drafts and derive
  decision, risk, and activity metrics from records on this device.
- **AI integration boundary:** typed request/response models, response
  validation, timeout handling, an explicitly supplied test-fixture provider,
  and an Adaption Labs backend adapter seam. No live AI provider is configured.

## Technology and architecture

- Flutter Material 3 and Dart.
- Feature-based organization under `lib/features/`.
- Domain analysis is separate from widgets and provider integration.
- Local repositories use `shared_preferences`; no external charting or AI
  packages are required.
- Responsive navigation uses a desktop navigation rail and mobile navigation
  bar. Motion uses Flutter animation primitives and respects the operating
  system's reduced-motion preference for workspace page transitions.

## Setup and run

From `C:\my_days\brand_governance`:

```powershell
flutter pub get
flutter run -d chrome
```

For Android, open the project in an Android-enabled Flutter environment or run:

```powershell
flutter run
```

Quality checks:

```powershell
dart format lib test
flutter analyze
flutter test
flutter build web
flutter build apk --debug
```

## Storage, privacy, and security

Guidelines, submissions, and the latest review decision per submission are
stored locally on the current device using `shared_preferences`. This is demo
storage, not encrypted enterprise storage, cloud backup, authentication, or
multi-user collaboration. The app does not intentionally send content to a
network service. No API credentials are stored in the Flutter client.

The Adaption Labs integration can only be connected through an injected
`AdaptionReviewGateway`, intended to be implemented by a trusted backend
boundary. No API endpoint, model name, or credential flow has been assumed.
The production app defaults to an unconfigured provider and makes no external
AI requests. A test-fixture provider only returns a caller-supplied fixture and
is visibly labeled simulated.

## Analysis limitations

Deterministic analysis is limited to configured phrase rules and conservative
text-pattern heuristics. A detected number, superlative, or absolute phrase is
an advisory, not proof that a statement is unsupported, false, or misleading.
Tone checking only flags a small set of informal markers when Formal is
selected. Exact verified-statement matching does not verify facts, and failure
to find a configured statement does not make other statements false.

Historical analysis snapshots are not stored. History and analytics rerun the
engine using the current guidelines, so analysis metrics may change when those
guidelines change. Only the latest human decision per submission is retained.

## Documentation

- [Review history and analytics](lib/features/review_history/README.md)
- [Content review and AI boundary](lib/features/content_review/README.md)
- [Brand guideline setup](lib/features/guidelines/README.md)
- [Round 2 development summary](docs/ROUND_2_SUMMARY.md)
