# ADR-005 — Audit Columns on Foundation Tables

**Status:** Accepted (Foundation Layer), amended for versioning (`ADR-007`)
**Date:** Foundation Layer milestone

## Context

The approved architecture lists `created_by`, `updated_by`, `reviewed_by`,
`approved_by` "where applicable". Foundation lookup tables are governed data
maintained by the future governance/audit milestone, whose `users` and audit
tables do not yet exist.

## Decision

- Foundation lookup tables carry `created_at`, `updated_at`, `deleted_at`
  (maintained by the database, `updated_at` via `set_updated_at()` triggers).
- **Actor columns (`*_by`) are NOT added to lookup tables in the Foundation
  Layer.** They will arrive with the audit milestone as part of the dedicated
  audit trail, where they can reference the real `users` table without creating
  forward foreign keys or phantom UUID columns now.
- **Amended (`ADR-007`):** lookup tables DO carry `version_number
  integer NOT NULL DEFAULT 1` (with `CHECK (version_number > 0)`) as the
  governance version counter required by the architecture authority.
- **Amended (`ADR-008`):** lookup tables DO carry `status_id
  BIGINT NOT NULL REFERENCES lifecycle_statuses(id)` as the authoritative,
  non-destructive lifecycle field (ACTIVE/DEPRECATED/ARCHIVED). `source_id` and
  `confidence_score` remain intentionally absent from lookup tables: lookup rows
  are not provenance-tracked facts. They apply to governed entities (products,
  ingredients, ...) in later milestones.

## Consequences

- No forward foreign keys to non-existent tables; no columns with unenforceable
  semantics.
- Lookup-table change history is captured from the moment the audit milestone
  lands, and the audit layer records actor + before/after values for the existing
  `created_at`/`updated_at`/`deleted_at` timeline.
- This decision applies to the Foundation Layer only; the audit milestone will
  specify actor columns for governed entities per the approved architecture.
