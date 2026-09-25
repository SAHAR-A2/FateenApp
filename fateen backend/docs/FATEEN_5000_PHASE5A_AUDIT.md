# FATEEN 5,000-Product Ingestion — PHASE 5A AUDIT Report

**Phase**: PHASE_5A — AUDIT ONLY (read-only)
**Executed (UTC)**: 2026-09-15
**Database state touched**: none (every query was `SELECT` / file reads)
**Evidence artifact**: `docs/phase5a_audit.json`
**Verdict class**: `READ_ONLY_NO_WRITES`

---

## 1. Mission

FATEEN must grow its product catalog from the current baseline to **5,000
products** without ever sacrificing the established correctness contract
(no fabrication, deterministic pipelines, gated writes, provenance on every
row). Phase 5A is a **strictly read-only audit** that:

1. confirms the current live state (local + Supabase identical);
2. inventories the product sources that *already exist* in the project;
3. inspects the prior 2,000-product manifest (exists) and classifies every one
   of its candidates against the live database;
4. defines `VALID_PRODUCT` explicitly and computes the real gap to 5,000;
5. designs the deterministic `FATEEN_5000_MANIFEST` to be built lazily (Phase
   5A builds nothing and writes nothing);
6. records the quality gates, dup policy, batch/checkpoint design, energy and
   ingredient rules, and the hard-failure taxonomy that Phase 5B/5C must obey.

No schema migration, no RLS/ACL change, no data write, and no product
insert-or-update was performed for this audit.

---

## 2. Current live state (confirmed, read-only)

Supabase (`public`, pooler role) and the local Docker DB were both probed
read-only; **every count matches locally and in the cloud**:

| table                  | cloud | local |
|------------------------|------:|------:|
| products               | 1,331 | 1,331 |
| barcodes               | 1,329 | 1,329 |
| product_barcodes       | 1,329 | 1,329 |
| product_ingredients    |   818 |   818 |
| product_allergens      |    56 |    56 |
| product_nutrition_values| 2,226 | 2,226 |
| ingredients (vocab)    |   289 |   289 |
| allergens              |    11 |    11 |
| companies              |   113 |   113 |
| brands                 |    13 |    13 |

This is byte-identical to the Phase 2 `FATEEN_CLOUD_MIGRATION_FINAL_REPORT.md`
baseline. The 1,331 products include 7 legacy non-`FATEEN_%` rows (pre-existing
at Phase 4C) and the interleaved pilot rows. Candidates reach valid product
definition only through the identity gate (below).

### 2.1 Product composition (read-only deep-dive)

| facet | value |
|---|---|
| internal codes | 1,324 × `FATEEN_%` / 7 × other (legacy; 2 barcode-less test rows `test-app-role-001`, `PRIV_TEST_001`) |
| without live barcode | 2 (the two test rows above) |
| with barcode but **no name** | 174 (all `FATEEN_%`; barcodes exist, `name` NULL/empty) |
| barcode source linkage | 1,322 rows source_id NULL / 7 `FATEEN_TEST` (provenance gap — matches ADR §7: entity tables lack evidence_type) |
| confidence | 1,320 @ 0.5 / 11 @ 0.8 (OFF default 0.5, per 0045) |
| VALID depth | 1,155 valid; 110 with ingredients, 39 with allergens, 271 with nutrition, 7 with brand, 0 with category |
| nutrition types | ENERGY(274), CARBOHYDRATE(265), PROTEIN(258), TOTAL_FAT(258), SUGAR(247), SATURATED_FAT(243), FIBER(224), SALT(207), SODIUM(204), TRANS_FAT(46); **zero `energy-kj` rows committed** (energy contract held) |
| migrations | 51 applied, latest `0051_off_pilot_reference_ingredients.sql` |
| reference vocab | source_types: DATABASE, IMPORT, MANUFACTURER, REGULATORY, USER_SUBMITTED · priorities: MANUFACTURER=1, REGULATORY=2, DATABASE=3, TEST=99 |

Key consequence for the 5,000 plan: the **174 nameless-but-barcoded rows are
countable as `with_barcode` (1,329) but not as `VALID_PRODUCT`** — they need a
name before they can count toward the 5,000 target, and they must be handled by
provenance-safe gap-fill (source-derived), never invented.

## 3. `VALID_PRODUCT` definition and the true gap

`VALID_PRODUCT` is defined by the two identity-critical gates the ingestion
path already enforces (agent-contract items 1 + 2):

> A live `products` row (`deleted_at IS NULL`) that (a) is linked to at least
> one **live barcode** (`product_barcodes` + `barcodes`, both `deleted_at IS
> NULL`) — the sole admissible identity — and (b) carries a **non-empty
> `products.name`**. Bonus-field depth (ingredients, allergens, nutrition) does
> not gate validity; it is reported separately as completeness (coverage-model
> KPIs 4–6). Products are counted once.

Read-only SQL result (identical cloud/local):

| metric                      | count |
|-----------------------------|------:|
| live products total         | 1,331 |
| live barcodes (distinct)    | 1,329 |
| with barcode                | 1,329 |
| with name                   | 1,157 |
| **VALID_PRODUCT**           | **1,155** |

```
gap = 5,000 − current VALID_PRODUCT = 5,000 − 1,155 = 3,845
```

(Note: 2 live products lack any barcode and 174 lack a name; both are outside
`VALID_PRODUCT`.)

## 4. Source inventory — everything that already exists

Per `FATEEN_SOURCE_GOVERNANCE_ADR.md` (ADR-004, ACCEPTED 2026-09-12) and the
Phase 3/3.5 audits, the field-level authority ladder and current governance
posture are:

| authority class | examples today | governance | usable for 5,000? |
|---|---|---|---|
| `REGULATORY` | SFDA registered-food / FIRS open data | `BLOCKED` (credential gap; adapter disabled) | **No live data; report as BLOCKED/UNAVAILABLE** — nothing fabricated in its place |
| `MANUFACTURER` | Nadec product pages (structured) | `APPROVED_WITH_ATTRIBUTION` | Yes (structured; small catalog verified) |
| `RETAILER` | Danube, Tamimi, Panda, Carrefour KSA | `REVIEW_REQUIRED` | Discovery/evidence only; no product facts |
| `DATABASE` (aggregated) | Open Food Facts (Saudi subset) | `APPROVED` | Yes — primary breadth engine |
| `USER_SUBMITTED` / `OCR` | none approved | `never` | No primary values |

`data_sources` in the live DB holds exactly three rows (read-only query,
included in `phase5a_audit.json`): `COLLECTOR` (ACTIVE, verified),
`FATEEN_TEST` (ACTIVE, unverified), and `OPEN_FOOD_FACTS` (ACTIVE, unverified).
**Nadec and SFDA are not registered**; SFDA must be recorded as
`BLOCKED/UNAVAILABLE` (no credential path configured), matching the ADR.

**SFDA live posture (re-confirmed, read-only):** `SFDA_LIVE=BLOCKED_AUTH` —
`SFDA_ACCESS_TOKEN` and `SFDA_API_KEY` are **not** configured; the OAuth2
client-credential half is present (`SFDA_CONSUMER_KEY/SECRET/TOKEN_URL`)
but unauthenticated `/v2/Food` and `/v2/FIRS` routes are black-holed on the
production gateway, raising `SfdaAuthenticationRequired` before any network
call. Pipeline readiness is PASS (adapter + offline fixture + rollback-only DB
tests, 38 green) but **no live SFDA data can flow** without user-provided
credentials. Phase 5 will record SFDA candidates as `BLOCKED/UNAVAILABLE`;
nothing will be fabricated in their place.

Dominant measured breadth pool (Phase 3.5 audit, re-measurement pending at
run time per coverage model): **Open Food Facts Saudi subset ≈ 16,476 codes**
(verified live 2026-09-12 via `countries_tags_en=saudi-arabia`). OFF is the
only confirmed source with a large Saudi barcode pool today; Nadec is the only
structured manufacturer depth. OFF API reachability at audit time was
intermittent (two timed-out probes) — a run-time re-measurement of the live
pool is a Phase 5B preflight item, not a fabricatable constant.

## 5. Prior 2,000-product manifest — found and classified

The prior milestone manifest **exists** and was located:

```
.../fateen_release_audit/pilot/inputs/pilot_2000_v1.json
manifest_id = pilot_2000_v1, version = 1, rows = 2,000
all rows: OPEN_FOOD_FACTS / REAL_CAPTURED / fixture=false
ordering deterministic by barcode; provenance + payload sha256 per row
```

`PHASE5_MANIFEST_NOT_FOUND` is therefore **not** reported; the manifest was
inspected and every row classified against the current live cloud barcode set
(read-only), cross-checked against the release ledger
(`pilot/artifacts/pilot_2000_v1/release_v1/batch_*_decisions.jsonl`):

| classification      | rows | meaning |
|---------------------|-----:|---------|
| `ALREADY_IN_DB`     | 1,220 | barcode bound to a product in the live cloud DB (prior committed rows) |
| `NEW_ELIGIBLE`      |     0 | written-eligible rows not present in DB (none: every non-present row was previously gated) |
| `REVIEW`            |   667 | previously `NO_WRITE`: **666** energy-kj reference-gate + **7** CRITICAL allergen/barcode |
| `EXPECTED_SKIP`     |   113 | previously `SKIPPED_PRODUCT_EXPECTED`: unresolvable ingredient-vocabulary tokens |
| `BLOCKED`           |     0 | |
| `INVALID/DUPLICATE` |     0 | |

Total prior committed = 1,220 (all "reused"; new products = 0), consistent
with the 1,331 current total. **The old 2000-manifest is exhausted as a source
of *new* products in its current form** — it adds nothing toward the 3,845 gap.
Its 780 non-present rows are precisely the review/skip populations whose gates
Phase 5 must re-evaluate (see §6).

### 5.1 The review population is mostly energy-gated

Of the 667 REVIEW rows, **666 (99.85%) carry the single reason**
`Nutrition type 'energy-kj' has no reference row (review required)`; the other
7 are CRITICAL allergen/barcode conflicts, of which 6 also carry the energy
reason. Under the new Phase 5 energy policy (§6.3) these rows are candidates
for re-grading to `NEW_ELIGIBLE` — a Phase 5B deterministic dry-run concern,
not an automatic count.

### 5.2 The skipped population is a vocabulary gap

The 113 `EXPECTED_SKIP` rows failed because an extracted ingredient token had
no exact `LOWER(name)` match in the 289-row `ingredients` vocabulary (e.g.
`concentrated orange juice`, `soybean oil`, `PASTEURIZED MILK AND CREAM`,
`Roasted peanuts`, foreign-language OCR fragments). This is a **vocabulary gap,
not fabricated data** — resolution must come from evidence-backed vocabulary
proposals via `app/batch/vocabulary.py`, never anonymous strings.

**Scale context (read-only, prior OFF corpus work):** the OFF multilingual
label corpus surfaced **4,631 distinct blocking tokens** (`off_pilot/tally2.txt`)
across bread/biscuits/snacks/toast/wafers/etc. (French `Ingrédients issus...`,
German `Invertzuckersirup`, Portuguese `Açúcar`, …). The 113 skip rows in the
2000 pilot are the tip of that gap; Phase 5B must scope vocabulary proposals
deterministically — term-by-term, evidence-backed — and re-run the dry runs
verbatim so this remains measurable, not inflated.

### 5.3 Prior determinism evidence re-verified (read-only)

The pilot's two dry runs (`run-01` / `run-02`) were byte-compared again:

| artifact      | SHA-256 (first 16) | identical |
|---------------|--------------------|-----------|
| accounting.json | `5FC2EE0AB72C108E` ×2 | **yes** |
| products.jsonl  | `F024D8C83CB87C64` ×2 | **yes** |
| review_export.jsonl | `B7AD3A611458CF9C` ×2 | **yes** |
| run_meta.json   | `6C94F201…` vs `30C56196…` | timestamps only (started/finished/probed) |

Both runs: 2,000 records, `PASS(COLLECTED)=1,333 / FAIL_REVIEW=667`,
`transaction_allowed=false`, `effective_dry_run=true`. `run_meta.json` differs
only by wall-clock probes — the pipeline outputs are byte-identical, confirming
the deterministic property Phase 5 must preserve.

## 6. Deterministic `FATEEN_5000_MANIFEST` design (built in 5B, not 5A)

The new manifest is intentionally **not created during this audit**. Its design
(locking the deterministic, byte-identical-on-rerun property unless sources
change) is fixed here for review before any capture/ingestion work begins.

### 6.1 Identity and structure

- `manifest_id: fateen_5000_v1`, `version: 1`.
- Row schema (superset of pilot_2000_v1): `pilot_id` (`f5k_00001`…), `source`,
  `identity.barcode` (EAN-13 only), `availability` (`REAL_CAPTURED`),
  `fixture=false`, `fixture_path`, `raw_payload_sha256`, `product_name`,
  `brand`, `category`, `provenance` (source, record_kind, captured_from,
  capture_file, captured_at_utc, source_url), and an `expected` block declaring
  the precomputed classification.
- Single manifest per source-layer; **row ordering deterministic by barcode
  (ascending)** — identical bytes on re-run absent source changes.

### 6.2 Candidate sourcing (existing sources only) — priority order

1. **Re-grade (re-classify, not re-fetch): the old 2,000 rows** — 780 rows
   (667 REVIEW + 113 EXPECTED_SKIP) re-graded under the policies below. Reuses
   the existing captured payloads; zero new network capture.
2. **Open Food Facts Saudi subset (APPROVED)** — extend with real captures of
   previously-unused codes (≥ residual of the ~16,476 verified pool, measured
   live at run time). Deterministic pagination/ordering rules fixed in 5B;
   allowlist of permitted endpoints only (`/search`, `/product/{barcode}.json`),
   no scraping, rate-limit friendly.
3. **Nadec (APPROVED_WITH_ATTRIBUTION)** — structured manufacturer rows with
   URL attribution; registers a `NADEC` `data_sources` row **via a gated,
   proposed migration only** if 5B determines the schema permits it; otherwise
   provenance carried on link rows as the ADR specifies.
4. **SFDA** — record as `BLOCKED/UNAVAILABLE` with reason (no credential path);
   **no fake SFDA API/auth, no invented regulatory numbers**.
5. Retailers — not eligible for product facts until upgraded from
   `REVIEW_REQUIRED`.

### 6.3 Energy / nutrition policy (fixed for 5B/5C)

- **`energy-kj` missing reference row is NOT a full reject.** Allowed: re-grading
  the row into REVIEW **or** gating it as a *non-blocking* completeness item when
  the rest of the core fields pass, exactly as the ADR/agent contract allow —
  never a blocker on its own. The decision is made once, deterministically.
- **No fabricated kJ→kcal conversion.** The kJ value stays verbatim in raw
  provenance; if a FATEEN `nutrition_types` reference row is absent the value
  is not silently stored as any other type.
- **No zero placeholders.** Absent amount ⇒ no `product_nutrition_values` row
  and field status `MISSING` (the `amount_value NOT NULL` constraint is
  respected: a row is only written when a real value exists).

### 6.4 Ingredients — mandatory resolver

- Every ingredient token resolves through `app/batch/vocabulary.py`
  (`resolve_ingredient_token`, exact `LOWER(name)` grammar + the (unwired today)
  alias/translation surfaces).
- No auto-creation of ingredient rows for mere name appearance; no untrusted
  synonyms; no Arabic→English mapping without documented evidence; unresolved
  tokens stay verbatim and surface as `REVIEW_REQUIRED`/`EXPECTED_SKIP` — they
  are never invented or dropped.

### 6.5 Allergen safety

- No "safe"/"contains-no-X" claim from absence alone. Only explicitly declared
  allergens create `product_allergens` rows; `en:nuts` and ambiguous tags stay
  `REVIEW_REQUIRED`; “may contain” is evidence metadata, never a declaration.

### 6.6 Dup policy (checked before any INSERT)

1. barcode / GTIN exact match → ALREADY_IN_DB (reuse, never re-create);
2. normalized product identity;
3. source product ID (OFF code / Nadec id);
4. manufacturer + (normalized) name against canonical identity.
`ON CONFLICT DO NOTHING` is **not** used to hide issues; unexpected constraint
violations are surfaced as real errors.

## 7. Execution contract for 5B/5C (carried forward)

- **Phase 5B (dry runs #1 & #2)**: deterministic; byte-identical outputs;
  zero DB writes; emits `PHASE_5_5000_DRY_RUN_PASS` only when both runs match
  and classifications are stable.
- **Phase 5C execution** begins only after `PHASE_5_5000_DRY_RUN_PASS`.
  - batch size **50**; each batch = one transaction, per-product savepoints;
  - checkpoint `fateen_5000_checkpoint.json`: manifest hash, source versions,
    last batch index, committed/reused/skipped/review/blocked tallies,
    timestamps, pipeline version; resumable after failed batch 47 without
    duplicates; idempotent (re-run ⇒ `new_products=0`);
  - **cloud-first verification after every batch** (Supabase counts + FK +
    checksum subset); local mirror is secondary, never the source of truth;
  - HARD_FAILURE taxonomy (connection / transaction / schema mismatch / FK /
    constraint / source-integrity) **stops the batch**; data-isolatable
    failures route to EXPECTED_SKIP or REVIEW; no partial batch commit;
  - `fateen_app` stays read-only; no RLS/ACL changes, no migrations without a
    separate gated proposal;
  - final verification gates: products ≥ 5,000; `VALID_PRODUCT` identity gate
    intact; dup canonical identities = 0; orphan FKs = 0; invalid barcodes = 0
    (or documented); provenance/ingredient/allergen/nutrition integrity;
    idempotency re-run zero-delta.

## 8. Recommendations gated on this audit

1. **Re-grade, don’t re-fetch, the 780 old-manifest rows** first (energy policy
   + vocabulary) — cheapest deterministic path into the gap.
2. Add evidence-backed vocabulary proposals for the ≤113 skipped tokens via
   `app/batch/vocabulary.py` (report-only per design) before Phase 5B.
3. Register/confirm source governance rows (`NADEC`) through a **gated,
   additive migration proposal** if needed — never silently.
4. Measure the live OFF Saudi pool at Phase 5B preflight (re-run of the
   coverage-model denominator).
5. Handle the **174 nameless-but-barcoded rows** deterministically as a
   provenance-safe gap-fill item (source-derived names only), so they can
   return to `VALID_PRODUCT` — or record them explicitly outside the count.
6. Confirmed by file scan: **no `fateen_5000` manifest exists anywhere in the
   project or the release-audit repo** — `fateen_5000_v1` is a new artifact to
   be built in Phase 5B, never a resurrection.

## 9. Verdict

**PHASE_5A: AUDIT_COMPLETE — READ_ONLY_NO_WRITES**

- Current baseline confirmed identical local/cloud (products=1,331; all 10
  table counts).
- Composition deep-dive: 1,324 `FATEEN_%` / 7 legacy; 2 barcode-less test rows;
  174 nameless-but-barcoded; VALID depth 110/39/271 (ingredients/allergens/
  nutrition).
- Prior 2,000-manifest found and fully classified (1,220 ALREADY_IN_DB /
  667 REVIEW / 113 EXPECTED_SKIP; 0 NEW_ELIGIBLE as-is); **determinism of the
  two prior dry runs re-verified byte-identical** (outputs identical; only
  run_meta timestamps differ).
- `VALID_PRODUCT` defined; **gap to 5,000 = 3,845**.
- Sources audited: OFF (APPROVED, ~16,476 SA codes, re-measure at run time),
  Nadec (unregistered; needs gated migration), SFDA (BLOCKED_AUTH — recorded
  BLOCKED/UNAVAILABLE), retailers REVIEW_REQUIRED.
- Vocabulary gap quantified: 4,631 distinct blocking tokens in OFF corpus;
  113 skip rows are its documented tip.
- Deterministic FATEEN_5000_MANIFEST designed (built in 5B, not now).
- Zero writes, zero migrations, zero RLS/ACL changes performed.

**STOP — awaiting review before any Phase 5B capture, vocabulary, or dry-run
work begins.**