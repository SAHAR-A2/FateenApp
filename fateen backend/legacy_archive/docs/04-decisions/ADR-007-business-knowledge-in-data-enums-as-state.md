# ADR-007 — Business Knowledge Lives in Data; ENUMs Are Implementation State Only

**Status:** Accepted (Architecture Authority decision — supersedes earlier ambiguity)
**Date:** Foundation Layer milestone (refactor)

## Context

An Architecture Authority ruling established the standing rule for the entire
Fateen database:

> - If a value is expected to evolve over time (additions, deprecation,
>   translations, metadata, governance, versioning), it MUST be a lookup table.
> - ENUMs are allowed ONLY for internal immutable technical states that will
>   never require governance, translation, or expansion.
> - Business knowledge belongs in data. Application mechanics belong in code.
> - Future additions must never require `ALTER TYPE`.

## Decision

1. **Lookup tables only** (no ENUM) for: `languages`, `barcode_types`,
   `image_types`, `relationship_types`, `source_types`, `source_priorities`,
   and — as a result of this ruling — `health_flag_types` (the previous
   `health_flag_type` ENUM was removed; health-flag classes are governed,
   translatable business vocabulary).
2. **ENUMs are restricted to immutable internal system state.** The surviving
   ten enums are each individually justified as such in their file headers:
   `entity_status`, `approval_status`, `review_tier`, `review_decision`,
   `version_status`, `confidence_band`, `translation_status`,
   `candidate_status`, `update_type`, `unit_dimension`.
3. Applications reference lookup tables **by foreign key** to their UUID primary
   keys — never by ENUM and never by string.
4. Lookup tables carry the governance capability set: UUID PK, unique `code`,
   `status_id` referencing `lifecycle_statuses` (authoritative
   ACTIVE/DEPRECATED/ARCHIVED lifecycle, `ADR-008`), `version_number`
   (versioning), `created_at`/`updated_at`/`deleted_at` (audit), canonical
   `name` with Arabic/English translations arriving with the i18n milestone, and
   FK attachment points for future review/governance tables. `is_active` is not
   stored; it is only ever a computed/view-layer convenience derived from
   `status_id`.

## Consequences

- Adding a language, relationship type, source type, or health-flag class is a
  governed **data insert**, never a schema migration.
- No `ALTER TYPE ... ADD VALUE` is ever required for business vocabulary.
- Any future milestone that needs a new classification MUST add a lookup table
  (or extend an existing one) unless the value is provably immutable
  implementation state, and this ADR must be referenced.
- The enum inventory is 10. The removed `health_flag_type` ENUM is fully
  replaced by the `health_flag_types` table.
