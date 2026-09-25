-- =============================================================================
-- Fateen Data Agent — staging/review/evidence schema (dev database only).
-- -----------------------------------------------------------------------------
-- Everything the agent writes lives in the `agent` schema. The canonical
-- `public` schema (products, ingredients, allergens, ...) is NEVER modified by
-- the agent in DRY_RUN mode; promotion to `public` is an explicit, separate,
-- human-gated step (see docs/scaling.md).
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS agent;

-- ---------------------------------------------------------------------------
-- Input queue: products to process (batch feeds). Idempotent by barcode/name.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS agent.product_queue (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    product_key     text        NOT NULL,
    key_type        text        NOT NULL DEFAULT 'barcode',   -- barcode | name
    priority        integer     NOT NULL DEFAULT 0,
    context_json    jsonb       NOT NULL DEFAULT '{}'::jsonb,
    status          text        NOT NULL DEFAULT 'queued',    -- queued | processing | done | failed
    created_at      timestamptz NOT NULL DEFAULT now(),
    started_at      timestamptz NULL,
    finished_at     timestamptz NULL,
    CONSTRAINT product_queue_key_unique UNIQUE (product_key, key_type)
);

-- ---------------------------------------------------------------------------
-- Idempotency ledger: remembers every (product_key, key_type) already seen and
-- its terminal status, so re-runs never duplicate work.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS agent.processing_state (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    product_key     text        NOT NULL,
    key_type        text        NOT NULL,
    last_status     text        NOT NULL,
    attempts        integer     NOT NULL DEFAULT 1,
    processed_at    timestamptz NOT NULL DEFAULT now(),
    next_retry_at   timestamptz NULL,
    last_error      text        NULL,
    CONSTRAINT processing_state_key_unique UNIQUE (product_key, key_type)
);

-- ---------------------------------------------------------------------------
-- Raw staged findings: one row per (product, source) with the FULL raw payload.
-- Never guessed; always the verbatim output of a named source.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS agent.staged_findings (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id        uuid        NULL,
    product_key     text        NOT NULL,
    key_type        text        NOT NULL,
    source_name     text        NOT NULL,
    source_url      text        NULL,
    source_type     text        NOT NULL,           -- agent source taxonomy, e.g. manufacturer
    source_priority text        NOT NULL,           -- PRIMARY/SECONDARY/TERTIARY/COMMUNITY/UNVERIFIED
    retrieved_at    timestamptz NOT NULL DEFAULT now(),
    raw_json        jsonb       NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT staged_findings_unique UNIQUE (product_key, source_name, retrieved_at)
);

-- ---------------------------------------------------------------------------
-- Normalized candidate: the agent's best, evidence-backed view of one product.
-- status is the agent verification state (VERIFIED/NEEDS_REVIEW/CONFLICT/
-- UNRESOLVED/FAILED). ingredients/allergens/nutrition are normalized tokens,
-- every one of which must be traceable to evidence rows.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS agent.candidates (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    product_key     text        NOT NULL,
    key_type        text        NOT NULL,
    name            text        NULL,
    brand           text        NULL,
    company         text        NULL,
    package_size    text        NULL,
    barcode         text        NULL,
    ingredients_raw text        NULL,
    ingredients_json jsonb       NOT NULL DEFAULT '[]'::jsonb,
    allergens_json  jsonb       NOT NULL DEFAULT '[]'::jsonb,
    nutrition_json  jsonb       NOT NULL DEFAULT '{}'::jsonb,
    status          text        NOT NULL,
    confidence      numeric     NOT NULL DEFAULT 0,
    conflicts_json  jsonb       NOT NULL DEFAULT '[]'::jsonb,
    missing_data    jsonb       NOT NULL DEFAULT '[]'::jsonb,
    source_summary  jsonb       NOT NULL DEFAULT '{}'::jsonb,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT candidates_key_unique UNIQUE (product_key, key_type),
    CONSTRAINT candidates_confidence_check CHECK (confidence >= 0 AND confidence <= 1)
);

-- ---------------------------------------------------------------------------
-- Evidence: the auditability layer. One row per fact+source, e.g.
-- ("ingredient.milk", "milk", "https://official-site/...").
-- This answers "why does Fateen say this product contains allergen X?".
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS agent.evidence (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id    uuid        NULL,
    product_key     text        NOT NULL,
    key_type        text        NOT NULL,
    fact            text        NOT NULL,           -- e.g. ingredient.milk, allergen.milk, name, barcode
    value           text        NULL,
    source_name     text        NOT NULL,
    source_url      text        NULL,
    source_type     text        NOT NULL,
    source_priority text        NOT NULL,
    retrieved_at    timestamptz NOT NULL DEFAULT now(),
    confidence      numeric     NOT NULL DEFAULT 0,
    raw_excerpt     text        NULL,
    CONSTRAINT evidence_fact_source_unique UNIQUE (product_key, fact, source_name)
);

-- ---------------------------------------------------------------------------
-- Review queue: anything the agent cannot prove gets a task here with the full
-- context a human needs (sources checked, conflicts, missing data).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS agent.review_tasks (
    id                 uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    product_key        text        NOT NULL,
    key_type           text        NOT NULL,
    candidate_id       uuid        NULL,
    status             text        NOT NULL DEFAULT 'OPEN',   -- OPEN | IN_PROGRESS | RESOLVED
    problem            text        NOT NULL,                   -- NEEDS_REVIEW | CONFLICT | UNRESOLVED | FAILED
    reason             text        NULL,
    sources_checked    jsonb       NOT NULL DEFAULT '[]'::jsonb,
    conflicting_sources jsonb      NOT NULL DEFAULT '[]'::jsonb,
    missing_data       jsonb       NOT NULL DEFAULT '[]'::jsonb,
    suggested_action   text        NULL,
    created_at         timestamptz NOT NULL DEFAULT now(),
    resolved_at        timestamptz NULL,
    CONSTRAINT review_tasks_unique UNIQUE (product_key, problem)
);

-- ---------------------------------------------------------------------------
-- Batch runs + per-product outcomes for reporting.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS agent.batch_runs (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_label text        NOT NULL,
    total       integer     NOT NULL DEFAULT 0,
    verified    integer     NOT NULL DEFAULT 0,
    needs_review integer    NOT NULL DEFAULT 0,
    conflict    integer     NOT NULL DEFAULT 0,
    unresolved  integer     NOT NULL DEFAULT 0,
    failed      integer     NOT NULL DEFAULT 0,
    started_at  timestamptz NOT NULL DEFAULT now(),
    finished_at timestamptz NULL
);

CREATE TABLE IF NOT EXISTS agent.batch_items (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id    uuid        NULL,
    product_key text        NOT NULL,
    key_type    text        NOT NULL,
    status      text        NOT NULL,
    confidence  numeric     NOT NULL DEFAULT 0,
    detail      text        NULL,
    created_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT batch_items_key_unique UNIQUE (batch_id, product_key, key_type)
);

CREATE INDEX IF NOT EXISTS idx_candidates_status ON agent.candidates (status);
CREATE INDEX IF NOT EXISTS idx_evidence_product ON agent.evidence (product_key);
CREATE INDEX IF NOT EXISTS idx_review_status ON agent.review_tasks (status);
CREATE INDEX IF NOT EXISTS idx_queue_status ON agent.product_queue (status, priority);
CREATE INDEX IF NOT EXISTS idx_processing_key ON agent.processing_state (product_key, key_type);
