# Content review

Submissions retain their title, type, original body, unique ID, and UTC
creation timestamp. Production saves and loads submissions from the active
Supabase workspace using the authenticated user's ID and verified table
columns. The local SharedPreferences adapter remains available for local
tests/demo use.

## Deterministic analysis

The domain engine checks case-insensitive whole phrases against prohibited,
approved, and required terms; recognizes exact configured verified statements;
and applies narrow heuristics for selected Formal-tone markers and potentially
unsupported or absolute claims. Findings include severity, source offsets
where text was matched, a guideline reference, explanation, optional
correction, and whether a human should verify the concern.

Pattern matches are review prompts, not factual verdicts. The engine cannot
independently verify claims, infer nuanced tone, or establish complete brand
compliance. Missing a configured verified statement does not prove that other
claims are false.

## Human review

Reviewers explicitly choose Approve, Request Changes, or Reject and provide
their name and reason; comments are optional. Production writes a new
`review_decisions` row for each decision and sets `reviewer_id` from the
authenticated session. Decision details are encoded in the existing `notes`
text column. The local adapter continues to keep only the latest decision per
submission. No content is published automatically.

## AI integration readiness

`ai/` contains typed review request/finding/response models with structured
JSON and source-offset validation; an `AiReviewProvider` contract; timeout
handling; a fixture-only mock provider; and an `AdaptionLabsReviewProvider`
that requires an injected `AdaptionReviewGateway`. No endpoint, model name,
credential, or real provider connection is configured. The default UI reports
AI review as unavailable, and deterministic analysis works without it. AI
findings are advisory to a human reviewer.

Cloud access is restricted by workspace membership and RLS. Cloud and network
errors are surfaced; the production cloud adapter does not fall back to local
storage.
