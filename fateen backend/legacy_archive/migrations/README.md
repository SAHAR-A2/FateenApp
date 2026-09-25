# Migrations

Versioned, ordered, immutable SQL migration files, applied with `psql`.

**Convention:** `NNNN_description.sql`, strictly ascending, never modified after
deployment. The file prefix defines global execution order.

**Generated:** Migration files are assembled from the canonical `schema/` tree by
`scripts/build_migrations.ps1` (`ADR-004`). Never hand-edit a migration; edit the
schema source and regenerate.

**Applied:** by `scripts/migrate.ps1`, each migration inside one transaction and
recorded in the `schema_migrations` ledger (version, MD5 checksum, applied_at).
Re-running is safe: applied migrations are skipped, and a checksum mismatch on an
applied migration aborts the run.

| Migration | Scope                                              | Schema sources |
| --------- | -------------------------------------------------- | -------------- |
| `0001`    | Extensions (`pgcrypto`, `citext`, `pg_trgm`)       | `00-extensions` |
| `0002`    | Enumerations (10 enum types)                       | `01-enums`    |
| `0003`    | Lookup tables (12 tables)                          | `02-tables`   |
| `0004`    | Constraints (foreign keys, table-level CHECKs)     | `03-constraints` |
| `0005`    | Indexes (FK indexes, partial unique)               | `04-indexes`  |
| `0006`    | Functions and triggers (`set_updated_at`)          | `06-functions`, `07-triggers` |
| `0007`    | Seed: lifecycle statuses (ACTIVE/DEPRECATED/ARCHIVED) | `seed/00-system` |
| `0008`    | Mission 02 reference tables (10 tables)            | `02-tables`   |
| `0009`    | Mission 02 reference constraints (status_id + parent_id FKs) | `03-constraints` |
| `0010`    | Mission 02 reference indexes                        | `04-indexes`  |
| `0011`    | Mission 02 reference `set_updated_at` triggers      | `07-triggers` |
| `0012`    | Mission 03 core entity tables (6 entities + 8 translations) | `02-tables` |
| `0013`    | Mission 03 core entity constraints (33 FKs)         | `03-constraints` |
| `0014`    | Mission 03 core entity indexes (FK indexes)         | `04-indexes`  |
| `0015`    | Mission 03 core entity `set_updated_at` triggers    | `07-triggers` |
| `0016`    | Mission 04 relationship tables (8 junction tables)  | `02-tables`   |
| `0017`    | Mission 04 relationship constraints (48 FKs)        | `03-constraints` |
| `0018`    | Mission 04 relationship indexes (FK indexes)        | `04-indexes`  |
| `0019`    | Mission 04 relationship `set_updated_at` triggers   | `07-triggers` |
| `0020`    | Mission 05 history tables (9 `*_history` tables)    | `02-tables`   |
| `0021`    | Mission 05 audit tables (6: context/change_sets/feed/events/versions/metadata) | `02-tables` |
| `0022`    | Mission 05 history & audit constraints (62 FKs)      | `03-constraints` |
| `0023`    | Mission 05 history & audit indexes (FK indexes)      | `04-indexes`  |
| `0024`    | Mission 05 triggers (immutability + `set_updated_at`) | `06-functions`, `07-triggers` |
| `0025`    | Mission 07 media & barcode tables (`verification_statuses`, `images`, `barcodes`) | `02-tables` |
| `0026`    | Mission 07 media & barcode history tables (`images_history`, `barcodes_history`) | `02-tables` |
| `0027`    | Mission 07 media & barcode constraints (25 FKs)        | `03-constraints` |
| `0028`    | Mission 07 media & barcode indexes (FK indexes)        | `04-indexes` |
| `0029`    | Mission 07 triggers (immutability + `set_updated_at`)  | `07-triggers` |
| `0030`    | Mission 08 search tables (4 `*_search_index`, derived read models, no FKs) | `02-tables` |
| `0031`    | Mission 08 search indexes (pg_trgm GIN + token GIN + rank) | `04-indexes` |
| `0032`    | ECR-001 tables (`measurement_bases`, `product_images`, `product_barcodes`) | `02-tables` |
| `0033`    | ECR-001 history tables (`product_images_history`, `product_barcodes_history`) | `02-tables` |
| `0034`    | ECR-001 constraints (measurement-basis FK + natural-key extension; product-media FKs) | `03-constraints` |
| `0035`    | ECR-001 indexes (FK-supporting indexes) | `04-indexes` |
| `0036`    | ECR-001 functions (`capture_entity_history`, `validate_entity_relationship_endpoints`) | `06-functions` |
| `0037`    | ECR-001 triggers (capture, endpoint validation, `set_updated_at`, immutability) | `07-triggers` |
| `0038+`   | Seeds (Phase 8, not yet written)                      | `seed/`       |

**Mission 09 (Database Foundation Finalization) added no migrations** and
certified the chain `0001`–`0031` (contiguous numbering, byte-identical
regeneration, no gaps/duplicates; 47/47 validation PASS). **ECR-001 (Closing
Five Certification Blockers)** then extended the chain additively to `0037`
with `0032`–`0037` (see `docs/ecr001_report.md`); no existing migration was
modified, so the Mission 09 certification of `0001`–`0031` remains intact. The
validator now runs **55/55 PASS**. See `docs/database_certification_report.md`
and `docs/ecr001_report.md`.

Immutable shipped history is kept in `archive/`.
