# Tables

Base `CREATE TABLE` statements, one file per table. `01_lifecycle_statuses.sql`
is first: it is the shared status authority every other lookup table references.

Every lookup table carries the governance capability set (`ADR-001`, `ADR-007`,
`ADR-008`): UUID primary key (except `lifecycle_statuses`, the single BIGINT
identity exception), unique `citext` `code`, `status_id bigint NOT NULL`
referencing `lifecycle_statuses(id)` (authoritative ACTIVE/DEPRECATED/ARCHIVED
lifecycle), `version_number` (governance version counter,
`CHECK (version_number > 0)`), `created_at` / `updated_at` / `deleted_at` audit
columns, and `set_updated_at()` trigger. Actor columns (`*_by`) are deferred to
the audit milestone (`ADR-005`); `status` ENUM columns belong to governed
entities, not reference tables. `is_active` is never stored — only a
computed/view-layer convenience derived from `status_id`.

Cross-table foreign keys and table-level `CHECK` constraints are added in
`03-constraints/`.

Mission 07 media/barcode tables (`60`–`64`) follow the same conventions, plus a
verification vocabulary; Mission 08 search tables (`65`–`68`, `*_search_index`)
are **derived read models**: a logical `{entity}_id` with `UNIQUE` and **no
foreign key**, normalized searchable text, `search_tokens`, `language_codes`,
`search_rank >= 0`, and `generated_at` — no `status_id`, `version_number`, audit
trio, or triggers (disposable and rebuildable; see `docs/mission08_report.md`).
