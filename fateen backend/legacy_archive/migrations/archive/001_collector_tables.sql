-- FATEEN Data Collection & Market Coverage Agent
-- Migration 001: Collector tables
-- Date: 2026-08-18
-- Description: Company registry, scan orchestration, discovery, evidence, conflicts, coverage

BEGIN;

-- ============================================================
-- P01: COMPANY REGISTRY
-- ============================================================

CREATE TABLE IF NOT EXISTS public.companies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT UNIQUE NOT NULL,
    description TEXT,
    country TEXT NOT NULL DEFAULT 'SA',
    market TEXT NOT NULL DEFAULT 'packaged_food',
    website TEXT,
    logo_url TEXT,
    priority INTEGER NOT NULL DEFAULT 50,
    priority_score FLOAT,
    expected_product_count INTEGER,
    discovered_product_count INTEGER DEFAULT 0,
    verified_product_count INTEGER DEFAULT 0,
    failed_product_count INTEGER DEFAULT 0,
    conflict_count INTEGER DEFAULT 0,
    missing_data_count INTEGER DEFAULT 0,
    barcode_coverage_pct FLOAT,
    ingredient_coverage_pct FLOAT,
    allergen_coverage_pct FLOAT,
    nutrition_coverage_pct FLOAT,
    evidence_coverage_pct FLOAT,
    last_scan_at TIMESTAMPTZ,
    next_scan_at TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'pending',
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_companies_status ON public.companies(status);
CREATE INDEX IF NOT EXISTS idx_companies_priority ON public.companies(priority DESC);
CREATE INDEX IF NOT EXISTS idx_companies_country_market ON public.companies(country, market);
CREATE INDEX IF NOT EXISTS idx_companies_next_scan ON public.companies(next_scan_at);

-- ============================================================
-- P02: MARKET SCOPE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.markets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    code TEXT UNIQUE NOT NULL,
    country TEXT NOT NULL,
    description TEXT,
    category TEXT NOT NULL DEFAULT 'packaged_food',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.market_scopes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    market_id UUID NOT NULL REFERENCES public.markets(id),
    company_id UUID NOT NULL REFERENCES public.companies(id),
    priority INTEGER NOT NULL DEFAULT 50,
    expected_product_count INTEGER,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(market_id, company_id)
);

-- ============================================================
-- P05: SOURCE CONFIGURATION
-- ============================================================

CREATE TABLE IF NOT EXISTS public.source_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    code TEXT UNIQUE NOT NULL,
    source_type TEXT NOT NULL,
    authority_level INTEGER NOT NULL DEFAULT 50,
    reliability_score FLOAT NOT NULL DEFAULT 0.5,
    base_url TEXT,
    config JSONB DEFAULT '{}',
    rate_limit_per_minute INTEGER DEFAULT 60,
    timeout_seconds INTEGER DEFAULT 30,
    max_retries INTEGER DEFAULT 3,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- P04: PRODUCT DISCOVERY
-- ============================================================

CREATE TABLE IF NOT EXISTS public.discovery_candidates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id),
    scan_job_id UUID,
    name TEXT NOT NULL,
    brand TEXT,
    barcode TEXT,
    category TEXT,
    country TEXT,
    market TEXT,
    source_config_id UUID REFERENCES public.source_configs(id),
    source_url TEXT,
    source_reference TEXT,
    source_retrieved_at TIMESTAMPTZ,
    raw_data JSONB DEFAULT '{}',
    status TEXT NOT NULL DEFAULT 'discovered',
    normalized_name TEXT,
    normalized_brand TEXT,
    normalized_barcode TEXT,
    matched_product_id UUID,
    match_confidence FLOAT,
    validation_errors JSONB DEFAULT '[]',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_discovery_company ON public.discovery_candidates(company_id);
CREATE INDEX IF NOT EXISTS idx_discovery_status ON public.discovery_candidates(status);
CREATE INDEX IF NOT EXISTS idx_discovery_barcode ON public.discovery_candidates(barcode);
CREATE INDEX IF NOT EXISTS idx_discovery_scan_job ON public.discovery_candidates(scan_job_id);

-- ============================================================
-- P13: EVIDENCE SYSTEM
-- ============================================================

CREATE TABLE IF NOT EXISTS public.evidence_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    entity_name TEXT,
    source_config_id UUID REFERENCES public.source_configs(id),
    evidence_type_code TEXT NOT NULL,
    raw_value TEXT,
    normalized_value TEXT,
    confidence FLOAT NOT NULL DEFAULT 0.5,
    retrieved_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_evidence_entity ON public.evidence_records(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_evidence_source ON public.evidence_records(source_config_id);

-- ============================================================
-- P14: CONFLICT DETECTION
-- ============================================================

CREATE TABLE IF NOT EXISTS public.conflicts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    entity_name TEXT,
    field_name TEXT NOT NULL,
    value_a TEXT NOT NULL,
    value_b TEXT NOT NULL,
    source_a_id UUID,
    source_b_id UUID,
    confidence_a FLOAT,
    confidence_b FLOAT,
    resolution TEXT DEFAULT 'unresolved',
    resolution_note TEXT,
    resolved_by TEXT,
    resolved_at TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'detected',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_conflicts_entity ON public.conflicts(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_conflicts_status ON public.conflicts(status);
CREATE INDEX IF NOT EXISTS idx_conflicts_resolution ON public.conflicts(resolution);

-- ============================================================
-- P21: HALAL STATUS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.halal_evidence (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES public.products(id),
    status TEXT NOT NULL DEFAULT 'UNKNOWN',
    confidence FLOAT NOT NULL DEFAULT 0.0,
    source_config_id UUID REFERENCES public.source_configs(id),
    evidence_type TEXT,
    authority TEXT,
    reasoning TEXT,
    raw_evidence TEXT,
    retrieved_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_halal_product ON public.halal_evidence(product_id);
CREATE INDEX IF NOT EXISTS idx_halal_current ON public.halal_evidence(product_id, is_current);

-- ============================================================
-- P22/P25: HEALTH CONDITIONS (disease-agnostic)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.health_conditions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    code TEXT UNIQUE NOT NULL,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.condition_nutrition_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    condition_id UUID NOT NULL REFERENCES public.health_conditions(id),
    nutrition_type_code TEXT NOT NULL,
    operator TEXT NOT NULL,
    threshold_value FLOAT NOT NULL,
    unit_code TEXT NOT NULL,
    severity TEXT NOT NULL DEFAULT 'warning',
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.product_health_evaluations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES public.products(id),
    condition_id UUID NOT NULL REFERENCES public.health_conditions(id),
    evaluation_result TEXT NOT NULL,
    evidence JSONB DEFAULT '[]',
    evaluated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_health_eval_product ON public.product_health_evaluations(product_id);
CREATE INDEX IF NOT EXISTS idx_health_eval_condition ON public.product_health_evaluations(condition_id);

-- ============================================================
-- P08: INGREDIENT ALIASES
-- ============================================================

CREATE TABLE IF NOT EXISTS public.ingredient_aliases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ingredient_id UUID NOT NULL REFERENCES public.ingredients(id),
    alias TEXT NOT NULL,
    language TEXT NOT NULL DEFAULT 'en',
    source TEXT,
    is_preferred BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_ingredient_alias_unique ON public.ingredient_aliases(ingredient_id, alias, language);
CREATE INDEX IF NOT EXISTS idx_ingredient_alias_lookup ON public.ingredient_aliases(alias);

-- ============================================================
-- P11: UNIT CONVERSIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.unit_conversions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_unit_id UUID NOT NULL REFERENCES public.units(id),
    to_unit_id UUID NOT NULL REFERENCES public.units(id),
    conversion_factor FLOAT NOT NULL,
    measurement_type TEXT NOT NULL,
    is_exact BOOLEAN NOT NULL DEFAULT TRUE,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(from_unit_id, to_unit_id)
);

CREATE INDEX IF NOT EXISTS idx_unit_conv_from ON public.unit_conversions(from_unit_id);

-- ============================================================
-- P27/P29/P30: SCAN JOBS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.scan_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id),
    scan_type TEXT NOT NULL DEFAULT 'full',
    status TEXT NOT NULL DEFAULT 'pending',
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,
    duration_seconds FLOAT,
    products_discovered INTEGER DEFAULT 0,
    products_processed INTEGER DEFAULT 0,
    products_accepted INTEGER DEFAULT 0,
    products_rejected INTEGER DEFAULT 0,
    products_needs_review INTEGER DEFAULT 0,
    products_created INTEGER DEFAULT 0,
    products_updated INTEGER DEFAULT 0,
    products_unchanged INTEGER DEFAULT 0,
    conflicts_detected INTEGER DEFAULT 0,
    errors_count INTEGER DEFAULT 0,
    coverage_pct FLOAT,
    error_log JSONB DEFAULT '[]',
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_scan_jobs_company ON public.scan_jobs(company_id);
CREATE INDEX IF NOT EXISTS idx_scan_jobs_status ON public.scan_jobs(status);

CREATE TABLE IF NOT EXISTS public.scan_job_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scan_job_id UUID NOT NULL REFERENCES public.scan_jobs(id),
    candidate_id UUID REFERENCES public.discovery_candidates(id),
    product_id UUID REFERENCES public.products(id),
    barcode TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    action TEXT,
    error_message TEXT,
    processed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_scan_job_items_job ON public.scan_job_items(scan_job_id);
CREATE INDEX IF NOT EXISTS idx_scan_job_items_status ON public.scan_job_items(status);

-- ============================================================
-- P28: COVERAGE SNAPSHOTS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.coverage_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id),
    scan_job_id UUID REFERENCES public.scan_jobs(id),
    total_products INTEGER NOT NULL DEFAULT 0,
    products_with_barcode INTEGER NOT NULL DEFAULT 0,
    products_with_ingredients INTEGER NOT NULL DEFAULT 0,
    products_with_allergens INTEGER NOT NULL DEFAULT 0,
    products_with_nutrition INTEGER NOT NULL DEFAULT 0,
    products_with_evidence INTEGER NOT NULL DEFAULT 0,
    products_with_halal INTEGER NOT NULL DEFAULT 0,
    barcode_coverage_pct FLOAT,
    ingredient_coverage_pct FLOAT,
    allergen_coverage_pct FLOAT,
    nutrition_coverage_pct FLOAT,
    evidence_coverage_pct FLOAT,
    halal_coverage_pct FLOAT,
    overall_coverage_pct FLOAT,
    snapshot_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_coverage_company ON public.coverage_snapshots(company_id);

-- ============================================================
-- P26: DATA VERSIONING (extend existing pattern)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.data_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    version_number INTEGER NOT NULL DEFAULT 1,
    data_snapshot JSONB NOT NULL,
    source_config_id UUID REFERENCES public.source_configs(id),
    change_summary TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_data_versions_entity ON public.data_versions(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_data_versions_number ON public.data_versions(entity_type, entity_id, version_number);

COMMIT;
