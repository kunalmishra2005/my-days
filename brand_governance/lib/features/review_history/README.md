# Review history and analytics

In production, Review History loads content submissions and append-only
human-review decisions from the active Supabase workspace. Search, decision
and analysis-status filters, and sorting operate on those loaded records.
Selecting a record opens the existing Analysis Results screen.

The Analytics dashboard calculates submission, decision, pending-review,
critical/high/medium/low finding, and seven-day activity metrics from the
currently loaded submissions and decisions. Analysis findings are recomputed
using the current guidelines. The app does not save `analysis_snapshots`, so
guideline changes can alter analysis metrics; these metrics are not a
historical record of the analysis performed at submission time.

Cloud decisions are append-only. The local demo adapter remains device-local
and keeps only the latest decision per submission. Analytics and review
history do not implement `audit_events`, multi-workspace selection, or
automated publishing. Human reviewers retain the final approval decision.
