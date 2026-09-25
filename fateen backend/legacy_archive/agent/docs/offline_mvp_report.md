# Fateen Data Agent — Offline MVP Report (10 synthetic products)

**Date:** 2026-08-12
**Mode:** `FATEEN_LIVE_WEB=false` + `FATEEN_AGENT_DRY_RUN=true` (offline)
**Production writes:** 0 — the run used the in-memory repository; the
database was never written to, and no `public` schema was touched.

> IMPORTANT: all 10 products below are **synthetic test fixtures** for
> pipeline verification. They are NOT real, verified product facts and must
> never be treated as production data.

---

## Pipeline exercised

```
fixture (synthetic evidence)
→ extraction (evidence-backed facts)
→ normalization (ingredient split, Arabic/unicode handling)
→ matching + deduplication (canonical vocabulary; offline = transparent no-op)
→ source priority (best-evidence value selection)
→ conflict detection & resolution
→ validation (VerificationPolicy)
→ confidence (deterministic, weighted)
→ verification status (VERIFIED / NEEDS_REVIEW / CONFLICT / UNRESOLVED / FAILED)
→ review queue
→ report
```

## Results

| # | Product key  | Case                                     | Status       | Confidence | Reason |
|---|--------------|------------------------------------------|--------------|-----------|--------|
| 1 | 5901234123457 | Complete, matching sources                | VERIFIED     | 0.93       | — |
| 2 | 5901234123464 | Missing ingredients                       | NEEDS_REVIEW | 0.65       | Missing required evidence: ingredients |
| 3 | 5901234123471 | Conflicting ingredient data               | CONFLICT     | 0.45       | Unresolved conflict: openfoodfacts vs manufacturer_official on ingredients |
| 4 | 5901234123488 | Conflicting allergen data                 | CONFLICT     | 0.45       | Unresolved conflict: openfoodfacts vs manufacturer_official on allergens |
| 5 | 5901234123495 | Product not found                         | UNRESOLVED   | 0.00       | No source returned usable data |
| 6 | 5901234123501 | Arabic product data                       | VERIFIED     | 0.75       | — |
| 7 | 5901234123518 | English product data                      | VERIFIED     | 0.75       | — |
| 8 | 5901234123525 | Barcode mismatch                          | NEEDS_REVIEW | 0.75       | Barcode mismatch: sources report 5901234123532, query was 5901234123525 |
| 9 | 5901234123549 | Image/label evidence                      | VERIFIED     | 0.96       | — |
|10 | 5901234123556 | Multiple sources, different priorities    | VERIFIED     | 0.93       | — |

### Totals

```
Processed:    10
Verified:     5
Needs Review: 2
Conflicts:    2
Unresolved:   1
Failed:       0
```

Review queue produced for every non-verified product (5 tasks): 2
NEEDS_REVIEW, 2 source-conflict, 1 unresolved.

## How to reproduce

```powershell
# from the repo root
& .venv\Scripts\python.exe -m fateen_agent run --offline --all-fixtures --label offline_mvp --table
```

- `--offline` ⇒ fixtures only, no network, no DB writes (uses in-memory repo).
- `--all-fixtures` ⇒ runs every query defined in `tests/fixtures/products_10.json`.
- Report written to `output/offline_report_offline_mvp.json` (includes health snapshot, per-product reasons, review queue).

## Health check

```powershell
& .venv\Scripts\python.exe -m fateen_agent health
```

Reports: current mode (`live_web` / `dry_run`), database connectivity,
web connectivity (TCP probe, short timeout), enabled sources and their
availability, and key configuration (web-search/LLM keys present or not).

## Files added / modified for offline mode

Added:
- `src/fateen_agent/sources/fixture.py` — offline `FixtureSource`
- `src/fateen_agent/db/inmemory.py` — zero-write repository
- `src/fateen_agent/health.py` — health snapshot
- `tests/fixtures/products_10.json` — the 10 synthetic fixtures
- `tests/test_fixture_source.py` — offline pipeline tests (9 tests)

Modified:
- `src/fateen_agent/config.py` — `FATEEN_LIVE_WEB`, `FATEEN_FIXTURE_PATH`, `populate_by_name`
- `src/fateen_agent/sources/registry.py` — honor `live_web`
- `src/fateen_agent/sources/openfoodfacts.py` — non-blocking `health()`
- `src/fateen_agent/models.py` — `notes`, `canonical_ingredients`, `dedup_match`
- `src/fateen_agent/pipeline/orchestrator.py` — allergen-conflict detection,
  barcode-mismatch guard, matching/dedup canonicalization step
- `src/fateen_agent/review/queue.py` — surface candidate notes in reasons
- `src/fateen_agent/reporting/report.py` — rich per-product reasons
- `src/fateen_agent/cli.py` — `run --offline/--fixture/--all-fixtures`, `health`
- `.env`, `.env.example` — new settings documented

---

## Running the same 10 products against LIVE web sources

The offline path was added because this environment has no working HTTPS
egress. The production architecture still supports `FATEEN_LIVE_WEB=true`
with the real sources; the offline fixtures are **not** a replacement for
web research.

### Environment requirements

1. **Working HTTPS egress** (the agent must reach `world.openfoodfacts.org`
   and, for the manufacturer source, its web-search provider).
2. **A web-search provider API key** (optional but recommended; supported:
   `tavily` or `serper`) so `manufacturer_official` (PRIMARY) is enabled.
   Without it the agent degrades gracefully to Open Food Facts only.
3. **PostgreSQL dev database** with the `agent` schema applied
   (`fateen-agent setup`) — used when `dry_run=false`; the run stays in
   `agent.*` and never writes to `public` unless an explicit, human-gated
   promotion is enabled.
4. Python >= 3.10 with `pip install -r requirements.txt` (or the existing
   `.venv`).

### Configuration

```dotenv
FATEEN_LIVE_WEB=true
FATEEN_AGENT_DRY_RUN=true
FATEEN_WEB_SEARCH_PROVIDER=tavily            # or: serper
FATEEN_WEB_SEARCH_API_KEY=<your-key>
# LLM optional — extractor/normalizer assistant only, never a source of truth:
# FATEEN_LLM_PROVIDER=openai_compatible
# FATEEN_LLM_API_KEY=...
# FATEEN_LLM_BASE_URL=...
# FATEEN_LLM_MODEL=...
```

### To run the same 10 barcodes live

Create a query file (one barcode per line) — the fixture barcodes are
synthetic and will NOT exist in Open Food Facts, so for a live run replace
them with real barcodes (e.g. `data/sample_products.csv` with real GTINs):

```powershell
& .venv\Scripts\python.exe -m fateen_agent run data\sample_products.csv --label live_mvp --table
```

(Remove `--offline` and drop `--all-fixtures`; the CSV path supplies queries.
The run will hit OFF and, with a search key, the official manufacturer pages,
then write results to the `agent` schema and produce the same report shape.)

### Verification before/after a live run

- `fateen-agent health` → database OK, web TCP probe OK, `openfoodfacts`
  (and `manufacturer_official` if key present) enabled.
- Compare report statuses/reasons against `tests/fixtures/products_10.json`
  expectations — the pipeline logic is identical online and offline.
- Re-run `pytest` (`81 passed`) to confirm no regressions.

---

## Appendix B — Ingredient / allergen / health-flag canonicalization

Added 2026-08-13. After merging raw evidence, the orchestrator now maps every
raw ingredient token (as written by manufacturers, in English or Arabic) to a
**canonical ingredient** from the governed vocabulary, then derives normalized
**allergens** and **health flags** (sugar / salt / chronic-disease markers) from
the vocabulary joins — each derivation backed by `canonical_id` + match method
+ score, never invented.

### Data model (`CandidateProduct`)

- `ingredient_matches` — `[{token, canonical_id, canonical_name, method, score}]`
  (`method` ∈ `alias_exact | exact | similarity | token_overlap`).
- `unmatched_ingredients` — raw tokens with no canonical mapping (kept for human
  review; never silently dropped).
- `derived_allergens` / `derived_health_flags` — `[{code, name}]` from the
  ingredient→allergen / ingredient→health-flag joins.
- `canonical_ingredients` — positional mirror: canonical name when matched,
  raw token otherwise (so an empty vocabulary is a transparent no-op).

### Repository interface

- `load_ingredient_allergens()` — `ingredient_id → allergens` via
  `public.ingredient_allergens`.
- `load_ingredient_health_flags()` — `ingredient_id → health_flags` via
  `public.ingredient_health_flags`.
- In-memory equivalents in `InMemoryRepository`; seeded by
  `load_vocabulary(path)` from `tests/fixtures/vocabulary.json`
  (16 canonical ingredients, 9 aliases incl. Arabic, 3 allergen links,
  6 health-flag links — all synthetic).

### Reproduce

```powershell
& .venv\Scripts\python.exe -m fateen_agent run --offline --all-fixtures --table
# vocabulary banner appears; report now includes per-product:
#   ingredient_matches, unmatched_ingredients, derived_allergens, derived_health_flags
```

Expected derivations (see `tests/test_canonicalization.py`, `15 tests`):

| Fixture case | Derived allergens | Derived health flags |
|---|---|---|
| 5901234123556 (oat biscuits) | `gluten` (wheat flour) | high_sugar, high_salt, chronic_diabetes_risk, chronic_cardiovascular_risk |
| 5901234123488 (dark chocolate) | `soy` (soy lecithin) | high_sugar, chronic_diabetes_risk |
| 5901234123549 (peanut butter) | `peanuts` (roasted peanuts) | high_salt, chronic_cardiovascular_risk |
| 5901234123501 (Arabic) | — | all four (سكر / ملح via Arabic aliases) |

Unknown tokens (e.g. `Aqua-fanta`) land in `unmatched_ingredients`; all 10
fixture cases have zero unmatched tokens. Allergen *conflicts* between sources
remain `CONFLICT` — derivation never auto-resolves a disagreement.

