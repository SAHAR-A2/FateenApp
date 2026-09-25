# PHASE 5B — DRY RUN REPORT (fateen_5000_v1)

**Phase:** `PHASE_5B_DRY_RUN`
**Verdict class:** READ_ONLY / DRY RUN ONLY — zero DB writes
**Manifest:** `pilot/inputs/fateen_5000_v1.json`
**Runs:** DRY RUN #1 (`run-01`), DRY RUN #2 (`run-02`)
**Date:** 2026-09-15

---

## 1. Input construction

| Step | Result |
|---|---|
| Captured records scanned (6 sort dirs × 10 pages) | 5,998 rows scanned |
| Distinct valid 13-digit EAN-13 codes in records | **3,198** |
| Existing payload files (`off2000/payloads/`) | 2,000 |
| New payloads materialized from records only | 1,198 |
| Total `off5000/payloads/{barcode}.json` | **3,198** |
| Manifest rows | **3,198** |
| Gap to 5,000 (SOURCE_CAPACITY shortfall) | **1,802** |

Payload materialization is deterministic: distinct codes sorted by barcode ascending;
existing payload bytes copied verbatim; record-only payloads serialized with
`sort_keys=True`. A `payload_sha256` map is embedded in the manifest `meta`.

**OFF live capture:** attempted (bounded, deterministic pagination). TCP 443 open but
HTTP requests to `world.openfoodfacts.org/api/v2/search` and `/api/v2/product/…`
timed out (>60 s). **OFF HTTP UNAVAILABLE this run → SOURCE_CAPACITY declared at
3,198 codes; the 1,802-code gap is NOT filled with fabricated/fixture data.**

## 2. Re-grade of the old 2,000 (no re-fetch)

Uses `phase5a_audit.json` → `classification_detail` directly. No source re-fetch;
re-grade follows the Q6.3 energy policy via the **offline vocabulary path**
(`PilotRunner(conn=None)` — `energy-kj` is a KNOWN_NUTRITION_TYPE; no DB reference
row was created or modified).

| Old class | Count | After re-grade |
|---|---|---|
| ALREADY_IN_DB | 1,220 | → **DUPLICATE** (1,220) |
| REVIEW | 667 | → **660 re-graded ELIGIBLE** (energy-kj only) + **7 remain REVIEW** (`en:nuts` allergen ambiguity) |
| EXPECTED_SKIP | 113 | → **EXPECTED_SKIP** (113, vocabulary-gap; preserved) |

## 3. Dry runs

Both runs executed with `dry_run=True`, `conn=None`, `AGENT_DRY_RUN=true`,
`writes_attempted=0`, `writes_committed=0`.

| | DRY RUN #1 | DRY RUN #2 |
|---|---|---|
| run dir | `…/fateen_5000_v1/run-01` | `…/fateen_5000_v1/run-02` |
| processed | 3,198 | 3,198 |
| by_gate_status | PASS 3,169 / FAIL_REVIEW 29 | PASS 3,169 / FAIL_REVIEW 29 |
| by_pipeline_status | COLLECTED 3,169 / REVIEW_REQUIRED 29 | COLLECTED 3,169 / REVIEW_REQUIRED 29 |
| by_source | OPEN_FOOD_FACTS 3,198 | OPEN_FOOD_FACTS 3,198 |
| environment | db UNAVAILABLE / http PARTIAL_REACHABLE | db UNAVAILABLE / http PARTIAL_REACHABLE |

## 4. Determinism (byte-level)

| Artifact | SHA-256 #1 | SHA-256 #2 | Identical |
|---|---|---|---|
| products.jsonl | `e0095d6549ea3b74c8cb0d2d62be4dc615150f906351e1c3b39bad27e706abbd` | same | ✅ |
| review_export.jsonl | `809b024920c5c2d48c1e137d30819c3973c24e5d44f414eefd54ebe14c3e7709` | same | ✅ |
| accounting.json | `ab887fd61f0b9f1199bcf65403e9729d27cc47fcad17ae3f466d2c6a1a11c950` | same | ✅ |
| run_meta.json | differs ONLY in `run_id`, `output_dir`, `started_at`, `finished_at`, `wall_seconds`, `environment.probed_at` | | ✅ (excluded) |

**Verdict: DETERMINISTIC.** All data artifacts byte-identical (SHA-256 equal).
`run_meta` differences are exclusively the sequential run id and auto-generated
timestamps, exactly the fields the user approved to exclude.

## 5. Classification tallies

```
PASS_ELIGIBLE   1,836   (660 re-graded from old REVIEW + 1,176 new captured, gate PASS)
REVIEW             29   (all 'en:nuts' REVIEW_REQUIRED allergen ambiguity; 7 old + 22 new)
BLOCKED             0
EXPECTED_SKIP     113   (vocabulary-gap, preserved from prior classification)
DUPLICATE       1,220   (already in live DB per 5A audit)
ERROR               0
──────────────────────
total           3,198
```

Top REVIEW reason: `CRITICAL review item present (en:nuts / allergen ambiguity)` × 29 — enforced by the design rule "`en:nuts` stays REVIEW_REQUIRED and never maps anywhere". No gate was relaxed.

## 6. Metrics vs 5,000 target

| Metric | Value |
|---|---|
| Candidates discovered | 3,198 |
| Candidates eligible | 1,836 |
| Expected new valid products | 1,836 |
| Expected final valid products | 1,155 + 1,836 = **2,991** |
| Remaining gap to 5,000 | **2,009** |

## 7. SOURCE_CAPACITY

- **3,198 REAL_CAPTURED codes** exist on disk (this run's ceiling without live capture).
- **1,802-code shortfall** → OFF HTTP unreachable this run; NADEC catalog unavailable; SFDA `BLOCKED_AUTH` (no credential path). Gap is **not** padded with weak/fabricated rows.
- To close 2,009 to target requires Phase 5C-stage work: live OFF capture (when reachable) and/or NADEC structured rows, plus SFDA credential path.

## 8. Limitations (explicit)

1. **DB unreachable** (`127.0.0.1:5432` password auth failed). The 1,198 newly-materialized codes were **not** deduplicated against the live `public.products` set. `PASS_ELIGIBLE=1,836` includes codes whose DB absence is unverified; a read-only barcode-membership check must run before any 5C write.
2. **OFF live HTTP unreachable** at run time; SOURCE_CAPACITY is 3,198, not an attempted live pool re-measure.
3. Energy-kj re-grade used the offline vocabulary path (`conn=None`); no DB `nutrition_types` reference row was created/updated — consistent with the last verified DB state.

## 9. Files

- `pilot/inputs/fateen_5000_v1.json` — manifest (3,198 rows, `payload_sha256` embedded).
- `pilot/inputs/fixtures/off5000/payloads/{barcode}.json` — 3,198 payload files.
- `pilot/artifacts/fateen_5000_v1/run-01/`, `run-02/` — products.jsonl, review_export.jsonl, accounting.json, run_meta.json.
- `pilot/artifacts/fateen_5000_v1/dry_run_determinism.json`.
- `pilot/artifacts/fateen_5000_v1/fateen_5000_classification_detail.json` — per-row 6-class classification for all 3,198 rows.
- `pilot/artifacts/fateen_5000_v1/phase5b_dry_run_report.json` — machine-readable report.

**STOP.** DRY RUN #2 is complete. **PHASE 5C must not start without explicit user approval.**