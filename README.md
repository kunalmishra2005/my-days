# MY DAY'S repositories

This repository contains two separate Flutter applications:

1. The original personal-memory prototype at the repository root.
2. The CodeNexus Round 3 Brand Governance app in
   [`brand_governance/`](brand_governance/).

## Brand Governance judge demo

The Brand Governance app includes a fictional, local-only judge workspace. From
the app folder, run:

```powershell
cd brand_governance
flutter pub get
flutter run -d chrome
```

Choose **Explore sample workspace**. The local demo needs no credentials and
does not connect to Supabase. It uses fictional sample data only. With
`SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` provided, the app instead uses
Supabase Auth and its RLS-protected cloud adapters. Never use a service-role
key in the Flutter client.

The cloud adapters are not a claim of fully completed cloud setup: workspace
creation and initial guideline creation are deliberately blocked where the
verified schema cannot guarantee safe, duplicate-resistant operations.
Historical analysis snapshots and audit events are not persisted. No live
Adaption Labs AI integration is configured.

See the [Brand Governance README](brand_governance/README.md) for judge access,
setup, feature list, architecture, status of the three locally documented
Round 3 recommendations, limitations, and submission checklist.

## Repository scope

The Brand Governance app's source, tests, docs, and platform configuration
live under `brand_governance/`. The original root app remains under `lib/`.
