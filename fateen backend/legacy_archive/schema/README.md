# Schema

Canonical, decomposed DDL — the single source of truth. One file per object,
ordered by creation dependency. Migrations are generated from this tree by
`scripts/build_migrations.ps1` (`ADR-004`).

| Folder              | Content                                              | Migration |
| ------------------- | ---------------------------------------------------- | --------- |
| `00-extensions/`    | `CREATE EXTENSION` statements                        | 0001      |
| `01-enums/`         | `CREATE TYPE ... AS ENUM` (10 types, one per file)   | 0002      |
| `02-tables/`        | `CREATE TABLE` with inline PK / UNIQUE / CHECK (73 tables) | 0003, 0008, 0012, 0016, 0020, 0021, 0025, 0026, 0030, 0032, 0033 |
| `03-constraints/`   | Cross-table `FOREIGN KEY` and table-level `CHECK` via `ALTER TABLE` | 0004, 0009, 0013, 0017, 0022, 0027, 0034 |
| `04-indexes/`       | `CREATE INDEX` (FK indexes, partial unique, search indexes) | 0005, 0010, 0014, 0018, 0023, 0028, 0031, 0035 |
| `05-views/`         | `CREATE VIEW` (empty until a milestone needs views)  | —         |
| `06-functions/`     | Stored functions (`set_updated_at()`, `prevent_history_mutation()`, `capture_entity_history()`, `validate_entity_relationship_endpoints()`) | 0006, 0024, 0036 |
| `07-triggers/`      | Trigger definitions                                  | 0006, 0011, 0015, 0019, 0024, 0029, 0037 |

**Conventions:** plural table names, singular FK columns, `snake_case`, UUID
primary keys (`gen_random_uuid()`; `lifecycle_statuses` is the single BIGINT
identity exception), `status_id` lifecycle (`lifecycle_statuses`),
`version_number`, `created_at`/`updated_at`/`deleted_at`, `ON DELETE RESTRICT`
everywhere. ENUMs are limited to immutable system state; governed business
vocabulary is a lookup table (`ADR-001`, `ADR-007`, `ADR-008`). Canonical core
entities carry `internal_code`, `source_id`, `confidence_level`,
`verified_at`/`approved_at`/`deprecated_at` and actor columns; translation
tables carry `translation_status` and `UNIQUE ({entity}_id, language_id)`;
relationship/junction tables carry `relationship_type_id`, `source_id`,
`evidence_type_id`, `confidence_level`, `effective_from`/`effective_to`,
`verified_at`/`approved_at`, `status_id`, and a composite UNIQUE. History tables
carry the full version column set (`original_entity_id`, `version_number`,
`previous_version_id`, `change_set_id`, `change_type`, `changed_by`,
`approved_by`, `source_id`, `confidence_level`, `effective_from`/`effective_to`/
`superseded_at`, `snapshot_hash`, `checksum`, `version_status`), mirror the
canonical snapshot, and are INSERT-only (guarded by `prevent_history_mutation()`
triggers; they carry no `updated_at`/`deleted_at` by design). Audit tables
follow the audit-trio layout. Mission 07 canonical entities (`images`,
`barcodes`) carry a natural-key UNIQUE (`storage_uri`/`content_hash`,
`barcode`), the lifecycle `status_id`, and — for `barcodes` — an independent
`verification_status_id` → `verification_statuses` lookup (governed, not an
ENUM); the content fingerprint is `content_hash` (Mission 05 history `checksum`
is reserved for history-row tamper-evidence). Mission 08 search tables
(`*_search_index`) are **derived read models**: a logical `{entity}_id` with
UNIQUE and **no foreign key**, normalized `search_name`/`search_text`,
`search_tokens text[]`, `language_codes citext[]`, `search_rank numeric >= 0`,
and `generated_at`; no `status_id`/`version_number`/audit trio, no triggers
(fully rebuildable; `pg_trgm` GIN search indexes in `04-indexes`). ECR-001
additions: `product_media`, `product_media_roles`, `media_product_roles`,
`measurement_bases` (+ history for `product_media` and `measurement_bases`),
`validate_entity_relationship_endpoints()` guarding the 6 canonical
relationship endpoints, and `capture_entity_history()` maintaining the
version chain. Full rules:
`docs/03-conventions/sql_conventions.md`.

**Note:** DDL targets the `public` schema (`ADR-002`).

**Workflow:** edit files here → run `scripts/build_migrations.ps1` → review the
generated migration diff → commit. Never hand-edit `migrations/`.
