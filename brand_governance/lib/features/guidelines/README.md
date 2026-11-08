# Brand guidelines

The Brand Guidelines screen stores a brand profile, description, tone of
voice, approved terminology, explicitly required brand terms, prohibited
words and phrases, and verified statements supplied by the user. List entries
are validated and can be added or removed before saving.

The local JSON schema remains backward compatible with earlier saved guideline
records that do not contain `requiredTerms`; those records load with an empty
required-term list. Persistence uses device-local `shared_preferences`, not
cloud or multi-user storage.
