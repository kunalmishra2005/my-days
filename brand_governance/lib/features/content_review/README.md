# Content review

Submissions retain their title, type, original body, unique ID, and UTC
creation timestamp. Local storage does not rewrite a draft during analysis or
human review.

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
their name and reason; comments are optional. The latest decision is stored
locally with a timestamp and the analysis status at decision time. No content
is published automatically.

## AI integration readiness

`ai/` contains typed review request/finding/response models with structured
JSON and source-offset validation; an `AiReviewProvider` contract; timeout
handling; a fixture-only mock provider; and an `AdaptionLabsReviewProvider`
that requires an injected `AdaptionReviewGateway`. No endpoint, model name,
credential, or real provider connection is configured. The default UI clearly
reports AI review as unavailable, and deterministic analysis works without it.
AI findings are rendered separately and remain advisory to a human reviewer.

All data and decisions remain in local demo storage. This is not a cloud,
authenticated, encrypted collaboration or audit-history system.
