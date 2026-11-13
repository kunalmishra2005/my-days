# Brand guidelines

The Brand Guidelines screen stores a brand profile, description, tone of
voice, approved terminology, explicitly required brand terms, prohibited
words and phrases, and verified statements supplied by the user. List entries
are validated and can be added or removed before saving.

Production uses Supabase storage scoped to the resolved workspace. The
`guidelines` JSONB column contains the complete `BrandGuidelines.toJson()`
shape, and `brand_name` is also written to its dedicated database column.
Existing single rows are updated by their primary key. Since
`workspace_id` is not unique, the client intentionally does not insert a new
row when no guideline row exists and rejects ambiguous multiple rows.

`SharedPreferencesGuidelinesStorage` remains available for local tests/demo
use. Its account-scoped keys preserve local account separation; legacy
unscoped records are not automatically migrated or assigned.
