# Open Questions — Foundation Reference Domain (Mission 02)

This document records reference domains that were deliberately **not** built in
Mission 02, together with the reason and the open decision each needs.

Rule (user directive): if a reference domain is uncertain, stop and document it
here instead of inventing a structure.

## 1. `review_statuses` — not built

Approved decision: this would duplicate the `approval_status` ENUM
(`pending_review, in_review, changes_requested, approved, rejected, cancelled`)
and the `review_decision` ENUM (`approved, rejected, changes_requested,
escalated`). Under `ADR-001`/`ADR-007` a concept is modeled **either** as
business knowledge (lookup table) **or** as immutable internal state (ENUM) —
never both.

- Status: **closed** — intentionally omitted; `approval_status`/`review_decision`
  are authoritative.
- No further action unless the review milestone finds a business (user-facing,
  translatable, governable) review status that the ENUMs cannot express.

## 2. `workflow_states` — not built

Approved decision: workflow progress is internal, immutable system state and is
already covered by the review/approval ENUMs (`approval_status`, `review_tier`,
`review_decision`, `candidate_status`). A separate `workflow_states` lookup table
would duplicate those ENUMs (`ADR-001`/`ADR-007`).

- Status: **closed** — intentionally omitted; workflow ENUMs are authoritative.
- If a workflow milestone later needs governed (translated, ordered, versioned)
  workflow stages visible to end users, revisit here before inventing a table.

## 3. `confidence_bands` — not built

Approved decision: `confidence_band` (`very_low, low, medium, high, very_high`)
is an ENUM derived from a numeric `confidence_score` (`ADR-007`). A table for it
would duplicate the ENUM and add nothing.

- Status: **closed** — intentionally omitted; `confidence_band` ENUM +
  numeric `confidence_score` are authoritative.
- The discretization function (score → band) is defined by the confidence
  milestone, not by a table.

## 4. Reference seeds — not yet written

The 22 lookup tables are built, but their governed seed rows (regions, countries,
units, categories, allergen types, nutrition types, authorities, roles,
permissions, audit event classes, ...) are Phase 8 seed work. No seed rows are
invented in Mission 02.

- Status: **open** — waiting on Phase 8 (seed milestone) and the approved
  source-of-truth vocabulary for each registry.

## 5. Region hierarchy — flat by design

`regions` is built flat (no parent, no region_type). If the expansion phases
require nested regions or region types, that is a schema change to be approved
through the normal ADR process.

- Status: **open** — needs a product decision before any future change.

# Open Questions — Relationship & Junction Tables (Mission 04)

The complete list with rationale lives in `docs/mission04_report.md`. Summary:

1. **`company_brands` / `brand_products` — not created.** The approved Mission 03
   schema already encodes these as direct FKs (`brands.company_id` NOT NULL,
   `products.brand_id`). Junction tables would duplicate canonical information and
   contradict the single-owner rule. Confirmation needed that the direct-FK form is
   final.
2. **`product_categories` / `ingredient_categories` — not created.** Both names are
   already governed taxonomy lookup tables (Mission 02); products FK to
   `product_categories` directly. A many-to-many classification model would be a
   redesign requiring an ADR.
3. **`product_images` / `product_barcodes` — closed by ECR-001.** Built as
   Mission 04-style relationship tables with immutable history (migrations
   `0032`–`0037`); see `docs/ecr001_report.md`.
4. **`entity_relationships` endpoint integrity — closed by ECR-001.** The
   `validate_entity_relationship_endpoints()` trigger (migration `0037`) rejects
   edges whose subject or object does not exist at the storage layer.
5. **Nutrition fact basis — closed by ECR-001.** `measurement_bases` lookup +
   NULLable `product_nutrition_values.measurement_basis_id` + extended natural
   key (migration `0034`); seed codes pending Phase 8.
6. **Unit-dimension consistency** for facts (mass vs. volume) is not yet validated
   cross-table.
7. **`ingredient_aliases.language_id`** nullability (language-neutral vs. always
   scoped) needs confirmation.

# Open Questions — Version History & Audit Infrastructure (Mission 05)

The complete list with rationale lives in `docs/mission05_report.md`. Summary:

1. **`categories_history` — split in two.** The work order asked for one history
   table for "categories"; it was delivered as `product_categories_history` +
   `ingredient_categories_history` because the canonical schema (Mission 02) has
   two distinct category tables with different columns. A single polymorphic
   history table would have duplicated the mandated per-entity history column set.
2. **`audit_log` vs `audit_events` — denormalized feed + normalized details.**
   The requirement listed audit fields per event; the design stores the full
   self-contained event in `audit_log` (readable narrative) and one
   normalized row per version in `audit_events`, so a single feed entry can
   carry several version transitions. Confirm this split is acceptable.
3. **`actor`/`changed_by`/`approved_by` — UUID, no FK.** The auth/identity service
   does not exist yet, so these are NULL-able UUIDs with no FK (same ruling as
   ADR-005 for `created_by`/`updated_by`). Any new FK target would require a
   service or an `auth_principals` table — future ADR.
4. **IP / user-agent — nullable placeholders.** `audit_context` stores
   `ip_address inet` and `user_agent text`, both NULL-able; filling them in is the
   application layer's job and they are optional until then.
5. **`entity_versions` polymorphism** — `history_table`/`history_row_id` carry no
   FK (they point at any of the 9 history tables); same precedent as
   `entity_relationships` subject/object.
6. **Authz on history/audit writes** — there is no trigger preventing `INSERT`
   into history/audit tables (only UPDATE/DELETE are blocked on history). Who is
   allowed to write audit rows is deferred to the app/service layer.

# Open Questions — Canonical Media & Barcode Domain (Mission 07)

The complete list with rationale lives in `docs/mission07_report.md`. Summary:

1. **Mission 06 scope gap — resolved by ECR-001.** The image/barcode
   relationship tables (`product_images`, `product_barcodes`) and their immutable
   relationship history are now built (migrations `0032`–`0037`). The
   search-index portion was closed by Mission 08.
2. **Verification seed values** — the exact `verification_statuses` codes (e.g.
   unverified / verified / failed) require the Phase 8 approved vocabulary; no
   seed rows are invented in Mission 07.
3. **`content_hash` vs `checksum`** — the images content fingerprint is
   `content_hash`; Mission 05 history `checksum` stays reserved for history-row
   tamper-evidence. Confirmation that this naming split is acceptable.
4. **Live apply** — no PostgreSQL is available in this environment; migrations
   `0025`–`0029` are static-validated (38/38 PASS) but must be executed in
   CI/review to confirm execution.

# Open Questions — Search Layer (Mission 08)

The complete list with rationale lives in `docs/mission08_report.md`. Summary:

1. **Population/synchronization** — the four `*_search_index` tables are empty
   until the population (or search/API) milestone implements the rebuild job; no
   database-side synchronization triggers were invented (mission rule).
2. **Search normalization rules** — Arabic normalization, accent folding,
   transliteration, and the `search_tokens` tokenizer are not defined here; the
   schema stores the normalized result.
3. **Live apply** — no PostgreSQL is available in this environment; migrations
   `0030`–`0031` are static-validated (44/44 PASS) but must be executed in
   CI/review to confirm execution.

# Open Questions — Database Foundation Finalization (Mission 09)

The complete certification lives in `docs/mission09_report.md`,
`docs/database_certification_report.md`, and `docs/architecture_summary.md`.
Summary — Mission 09 added no schema, migrations, seeds, or modules; all
remaining items are carried forward unchanged from prior missions plus one
consolidated operational item:

1. **Live apply (consolidated, highest priority)** — no PostgreSQL is available
   in this environment; migrations `0001`–`0037` are static-certified (55/55
   PASS, byte-identical regeneration) but have **never been executed** against a
   real PostgreSQL 13+ instance. Recommended mitigation: a CI job that
   provisions a disposable instance, applies the chain, and records results.
   This is the single outstanding item before production reliance.
2. **Mission 06 scope gap — closed by ECR-001.** `product_images` /
   `product_barcodes` relationship tables and their immutable relationship
   history are now built (migrations `0032`–`0037`); see `docs/ecr001_report.md`.
3. **Verification seed values — carried forward.** `verification_statuses`
   codes pending Phase 8 vocabulary. Same for `measurement_bases` seed codes
   (`per_100g` / `per_serving` / `per_package` are canonical but unseeded).
4. **`content_hash` vs `checksum` naming split — carried forward.**
5. **Search normalization/population rules — carried forward** (population
   milestone).
6. **Performance recommendations** (partitioning, BRIN, archive, materialized
   views, sharding, search/storage tuning) are **documented only** in
   `docs/architecture_summary.md` (Part 4) — none are applied, per the
   certification-only rule.

# Open Questions — ECR-001 (Closing Five Certification Blockers)

The complete report lives in `docs/ecr001_report.md`. ECR-001 closed the five
audit blockers additively; the items it intentionally did **not** change are
carried forward:

1. **Live apply** — no PostgreSQL is available in this environment; the ECR-001
   migrations `0032`–`0037` are static-validated (55/55 PASS) but must be
   executed in CI/review to confirm execution, along with `0001`–`0031`.
2. **`change_set_id` / `change_reason` population** — `capture_entity_history()`
   inserts history rows with NULL `change_set_id`/`change_reason` and computes
   `change_type` heuristically; the application/server layer supplies the
   session context (`set_config`) and change-set grouping in the population
   milestone.
3. **Actors** — `changed_by`/`approved_by` stay NULL until an auth service (or
   `auth_principals`) exists (ADR-005 precedent); the function maps
   `created_by`/`updated_by`/`approved_by` when present.
4. **`measurement_bases` seeds** — canonical codes (`per_100g`, `per_serving`,
   `per_package`) are documented but not seeded (Phase 8 governed vocabulary);
   `product_nutrition_values` keeps working with NULL basis until then.
5. **Endpoint-type coverage** — `validate_entity_relationship_endpoints()`
   validates the six canonical core entity types (the CHECK-constrained set).
   If the entity-type CHECK later gains a type whose table is not one of the
   six, the validator function must be extended in the same change.
6. **Snapshot/entity-field parity** — `capture_entity_history()` copies entity
   columns that exist (possibly renamed) in the history table; a future
   governed column added only to the history table would not be snapshot-filled
   automatically (none exist today).
