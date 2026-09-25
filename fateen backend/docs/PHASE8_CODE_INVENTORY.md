# Phase 8 — Code Inventory

**Date:** 2026-08-18
**Status:** IN PROGRESS
**Rule:** No DB modifications, no real collection, no LLM calls to production

---

## Summary

| Category | Files | Lines | Status |
|----------|-------|-------|--------|
| App source (`app/`) | 57 | 5,256 | 49 usable, 8 incomplete |
| Tests (`tests/`) | 17 | 3,307 | 172 pass / 16 fail (collector) |
| Root scripts | 8 | 1,308 | Diagnostic/verification only |
| Docs (root `*.md`) | 5 | 1,570 | Historical reports |
| Docs (`docs/`) | 9 | — | Schema + recovery docs |
| Migrations | 3 | — | Baseline + 2 collector |
| Config | 4 | — | docker-compose, Dockerfile, .env, .gitignore |
| **TOTAL** | **103** | **~11,441** | — |

---

## File Categorization

### A — Existing, Usable, DB-Aligned

These files work correctly against the live DB and can be kept as-is.

| File | Lines | DB Tables Used |
|------|-------|----------------|
| `app/core/config.py` | 60 | — |
| `app/db/connection.py` | 12 | — |
| `app/db/health.py` | 10 | sys queries |
| `app/main.py` | 146 | via services |
| `app/api/products.py` | 29 | via service |
| `app/api/product_details.py` | 33 | via service |
| `app/api/scan.py` | 231 | via repos |
| `app/api/companies.py` | 194 | via repos |
| `app/api/ingestion.py` | 119 | via agent |
| `app/api/enrichment.py` | 131 | via LLM |
| `app/agent/validators.py` | 26 | — |
| `app/agent/normalizers.py` | 13 | — |
| `app/agent/models.py` | 77 | — |
| `app/agent/confidence.py` | 57 | — |
| `app/agent/ingestion.py` | 476 | 14 tables |
| `app/agent/cli.py` | 110 | — |
| `app/llm/client.py` | 143 | — |
| `app/llm/extractor.py` | 144 | — |
| `app/llm/prompts.py` | 55 | — |
| `app/schemas/product.py` | 13 | — |
| `app/schemas/product_details.py` | 49 | — |
| `app/schemas/company.py` | 54 | — |
| `app/schemas/scan.py` | 38 | — |
| `app/repositories/company_repository.py` | 292 | 4 tables |
| `app/repositories/barcode_repository.py` | 95 | 9 tables |
| `app/repositories/scan_repository.py` | 235 | 2 tables |
| `app/repositories/discovery_repository.py` | 179 | 1 table |
| `app/repositories/product_repository.py` | 10 | 1 table |
| `app/services/barcode_service.py` | 38 | 6 tables |
| `app/services/product_details_service.py` | 160 | 12 tables |
| `app/services/database_service.py` | 7 | — |

**Total A-class files:** 31 | ~3,496 lines

---

### B — Incomplete / Partially Working

These files exist and have logic, but have known test failures or gaps.

| File | Lines | Issue | Failure Count |
|------|-------|-------|---------------|
| `app/collector/orchestrator.py` | 724 | Collector pipeline incomplete — 16 test failures in `test_collector.py` | 16 |
| `app/collector/sources.py` | 91 | DB writes to `evidence_records` — schema mismatch possible | 0 (untested) |
| `app/collector/halal.py` | 170 | Writes to `halal_evidence` — limited coverage | 0 (untested) |
| `app/collector/health_conditions.py` | 375 | Complex rule engine — fragile operator logic | 0 (untested) |
| `app/collector/reporting.py` | 268 | Report generation — reads scan_jobs | 0 (untested) |
| `app/collector/prioritization.py` | 135 | Company scoring — reads/writes companies | 0 (untested) |
| `app/collector/units.py` | 107 | Unit conversion engine — reads unit_conversions | 0 (untested) |
| `app/collector/coverage.py` | 263 | Coverage calculation — writes coverage_snapshots | 0 (untested) |

**Total B-class files:** 8 | ~2,133 lines

---

### C — Conflicting / Dual Definitions

| Issue | Files | Description |
|-------|-------|-------------|
| Two migration strategies | `001_collector_tables.sql` vs `002_collector_tables.sql` | 001 was NOT applied; 002 was applied (out of order). Different table names (`conflicts` vs `data_conflicts`). |
| `.env` vs `docker-compose.yml` | `.env` uses `fateen_dev_password`, `docker-compose.yml` uses `fateen` | Credential inconsistency |

---

### D — Duplicate / Redundant

| File | Duplicate Of | Description |
|------|-------------|-------------|
| `check_db.py` | `check_schema.py` | Subsumed by deeper schema check |
| `run_migration.py` | `run_migration2.py` | Both do the same thing for different files |
| `cleanup_migration.py` | (ad hoc) | Drops tables created by wrong migration |
| Root `*.md` reports | `docs/` | Historical snapshots, not canonical |

---

### E — Dead / Orphaned Code

| File | Lines | Description |
|------|-------|-------------|
| `app/models/__init__.py` | 0 | Empty package — no models defined here |
| `README.md` | 0 | Empty file |
| `verify_phase2.py` | 779 | Outdated verification (30 steps, references old test counts) |
| `verify_checklist.py` | 147 | Outdated (20-point checklist, pre-collector) |
| `deep_schema.py` | 141 | Diagnostic only — not part of app |
| `check_db.py` | 27 | Diagnostic only — not part of app |
| `check_schema.py` | 85 | Diagnostic only — not part of app |
| `cleanup_migration.py` | 34 | One-time fix script |
| `run_migration.py` | 46 | One-time migration runner |
| `run_migration2.py` | 49 | One-time migration runner |

**Total E-class files:** 10 | ~1,258 lines

---

### F — Missing (DB Tables Without Code)

These DB tables exist and have seed data but no corresponding code module.

| Table | Why Needed |
|-------|-----------|
| `product_categories` | Category classification for products |
| `product_category_assignments` | Product-to-category mapping |
| `product_translations` | Arabic/English product names |
| `brand_translations` | Arabic/English brand names |
| `product_packaging` | Packaging details (material, weight) |
| `product_images` / `entity_media` | Product photos |
| `search_index` / `search_suggestions` | Full-text search with pg_trgm |
| `schema_migrations` | Migration tracking (managed by 002 migration) |
| `countries` | Country reference data |
| `languages` | Language reference data |
| `verification_statuses` | Entity verification workflow |
| `approval_statuses` | Entity approval workflow |
| `translation_statuses` | Translation workflow |
| `review_tiers` / `review_decisions` | Content review |
| `ecr_threads` / `ecr_messages` / `ecr_references` | External change requests |
| `entity_versions` / `version_changes` / `version_relationships` | Versioning/audit |
| `barcode_history` | Barcode scan history (51 rows exist) |
| `product_barcodes_history` | Product-barcode history (largest table: 72KB) |
| `product_ingredients_history` | Ingredient history |
| `product_allergens_history` | Allergen history |
| `product_health_flags` / `health_flags` | Health flags (referenced in product_details_service) |
| `product_health_evaluations` | Health evaluation results (referenced in health_conditions.py) |
| `ingredient_aliases` | Ingredient name aliases |
| `ingredient_allergens` | Ingredient-to-allergen mapping |
| `coverage_snapshots` | Coverage history snapshots |

**Total F-class gaps:** ~27 tables without full code support

---

## Test Inventory

### Passing Tests (172)

| File | Tests | Type |
|------|-------|------|
| `test_agent_confidence.py` | 13 | Pure logic |
| `test_agent_ingestion.py` | 12 | Mock DB |
| `test_agent_normalizers.py` | 9 | Pure logic |
| `test_agent_validators.py` | 16 | Pure logic |
| `test_api_ingestion.py` | 9 | Mock DB |
| `test_blockers.py` | 27 | Mixed (real DB + mock) |
| `test_cors.py` | 3 | Client fixture |
| `test_docs.py` | 6 | Client fixture |
| `test_health.py` | 3 | Mock DB |
| `test_llm.py` | 16 | Mock LLM |
| `test_product_details.py` | 4 | Mock DB |
| `test_products.py` | 4 | Mock DB |
| `test_schemas.py` | 10 | Pure logic |
| `test_integration.py` | 38 | Real DB |
| **TOTAL PASS** | **170** | |

### Failing Tests (16) — All in `test_collector.py`

| Class | Tests | Issue |
|-------|-------|-------|
| `TestP05SourceResolution` | 3/5 | `get_source_by_code` returns None |
| `TestP06RetrievalNoHang` | 5/7 | Network timeout handling |
| `TestP13Evidence` | 0/1 | Evidence record creation fails |
| `TestP14ConflictDetection` | 3/4 | Conflict detection schema mismatch |
| `TestP15Deduplication` | 3/4 | Dedup query issues |
| `TestP17DryRun` | 0/1 | Dry-run safety check fails |
| **TOTAL FAIL** | **16** | |

### Test Coverage by Category

| Category | Tests | % of Total |
|----------|-------|-----------|
| Pure logic (no DB/LLM) | 48 | 21% |
| Mock DB | 38 | 17% |
| Mock LLM | 16 | 7% |
| Real DB (integration) | 82 | 36% |
| Client fixture (API) | 43 | 19% |
| **TOTAL** | **227** | 100% |

---

## Architecture Layers

```
┌─────────────────────────────────────────────────────┐
│  API Layer (app/api/)         6 routers, 519 lines  │
│  Validates input, delegates to services/repos        │
├─────────────────────────────────────────────────────┤
│  Services (app/services/)     3 files, 205 lines    │
│  Business logic, DB queries via repositories         │
├─────────────────────────────────────────────────────┤
│  Repositories (app/repositories/)  5 files, 811 lines│
│  Data access, SQL queries                            │
├─────────────────────────────────────────────────────┤
│  Agent (app/agent/)           7 files, 859 lines     │
│  Ingestion engine, confidence, validation            │
├─────────────────────────────────────────────────────┤
│  Collector (app/collector/)  17 files, 3,668 lines   │
│  Data collection pipeline (LARGEST module)           │
├─────────────────────────────────────────────────────┤
│  LLM (app/llm/)              4 files, 346 lines      │
│  LLM client, extraction, prompts (NEVER writes DB)   │
├─────────────────────────────────────────────────────┤
│  DB (app/db/)                2 files, 22 lines        │
│  Connection management, health check                 │
├─────────────────────────────────────────────────────┤
│  Core (app/core/)            1 file, 60 lines        │
│  Settings, configuration                             │
└─────────────────────────────────────────────────────┘
```

---

## Key Metrics

- **Total app source:** 57 files, 5,256 lines
- **Total tests:** 17 files, 227 functions, 3,307 lines
- **Total scripts:** 8 files, 1,308 lines
- **Total docs:** 14 files, ~3,000 lines
- **DB tables in code:** 28 of 85 (33%)
- **DB tables without code:** 57 (67%)
- **Test pass rate:** 172/227 (75.8%)
- **Largest module:** `collector/` (3,668 lines, 69% of app code)
