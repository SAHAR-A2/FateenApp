-- FATEEN Data Collection Agent - Migration 002
-- Add collection-specific columns to existing companies table
-- Create truly new tables only

BEGIN;

-- ============================================================
-- P01: Extend existing companies table with collection metadata
-- ============================================================

ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS slug TEXT;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS priority INTEGER NOT NULL DEFAULT 50;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS priority_score FLOAT;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS expected_product_count INTEGER;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS discovered_product_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS verified_product_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS failed_product_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS conflict_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS missing_data_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS barcode_coverage_pct FLOAT;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS ingredient_coverage_pct FLOAT;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS allergen_coverage_pct FLOAT;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS nutrition_coverage_pct FLOAT;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS evidence_coverage_pct FLOAT;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS last_scan_at TIMESTAMPTZ;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS next_scan_at TIMESTAMPTZ;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS country TEXT NOT NULL DEFAULT 'SA';
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS market TEXT NOT NULL DEFAULT 'packaged_food';
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS scan_status TEXT NOT NULL DEFAULT 'pending';
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}';

-- Set slugs for existing companies
UPDATE public.companies SET slug = LOWER(internal_code) WHERE slug IS NULL;

-- ============================================================
-- P04: Product Discovery Candidates
-- ============================================================

CREATE TABLE IF NOT EXISTS public.discovery_candidates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id),
    scan_job_id UUID,
    name TEXT NOT NULL,
    brand TEXT,
    barcode TEXT,
    category TEXT,
    country TEXT NOT NULL DEFAULT 'SA',
    market TEXT NOT NULL DEFAULT 'packaged_food',
    source_url TEXT,
    source_reference TEXT,
    source_retrieved_at TIMESTAMPTZ,
    raw_data JSONB DEFAULT '{}',
    status TEXT NOT NULL DEFAULT 'discovered',
    normalized_name TEXT,
    normalized_brand TEXT,
    normalized_barcode TEXT,
    matched_product_id UUID REFERENCES public.products(id),
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
-- P14: Conflict Detection
-- ============================================================

CREATE TABLE IF NOT EXISTS public.data_conflicts (
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

CREATE INDEX IF NOT EXISTS idx_conflicts_entity ON public.data_conflicts(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_conflicts_status ON public.data_conflicts(status);
CREATE INDEX IF NOT EXISTS idx_conflicts_resolution ON public.data_conflicts(resolution);

-- ============================================================
-- P21: Halal Status Evidence
-- ============================================================

CREATE TABLE IF NOT EXISTS public.halal_evidence (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES public.products(id),
    status TEXT NOT NULL DEFAULT 'UNKNOWN',
    confidence FLOAT NOT NULL DEFAULT 0.0,
    source_config_id UUID,
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
-- P22/P25: Health Conditions (disease-agnostic)
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
-- P11: Unit Conversions
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
-- P27/P29/P30: Scan Jobs
-- ============================================================

CREATE TABLE IF NOT EXISTS public.scan_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id),
    scan_type TEXT NOT NULL DEFAULT 'full',
    status TEXT NOT NULL DEFAULT 'pending',
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,
    duration_seconds FLOAT,
    products_discovered INTEGER NOT NULL DEFAULT 0,
    products_processed INTEGER NOT NULL DEFAULT 0,
    products_accepted INTEGER NOT NULL DEFAULT 0,
    products_rejected INTEGER NOT NULL DEFAULT 0,
    products_needs_review INTEGER NOT NULL DEFAULT 0,
    products_created INTEGER NOT NULL DEFAULT 0,
    products_updated INTEGER NOT NULL DEFAULT 0,
    products_unchanged INTEGER NOT NULL DEFAULT 0,
    conflicts_detected INTEGER NOT NULL DEFAULT 0,
    errors_count INTEGER NOT NULL DEFAULT 0,
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
-- P28: Coverage Snapshots
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
-- P26: Data Versions
-- ============================================================

CREATE TABLE IF NOT EXISTS public.data_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    version_number INTEGER NOT NULL DEFAULT 1,
    data_snapshot JSONB NOT NULL,
    source_config_id UUID,
    change_summary TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_data_versions_entity ON public.data_versions(entity_type, entity_id);

-- ============================================================
-- Seed Health Conditions (P23/P24)
-- ============================================================

INSERT INTO public.health_conditions (name, code, description) VALUES
('Diabetes', 'DIABETES', 'Sugar and carbohydrate monitoring for diabetic patients'),
('Hypertension', 'HYPERTENSION', 'Sodium and fat monitoring for hypertension patients'),
('Celiac Disease', 'CELIAC', 'Gluten monitoring for celiac patients'),
('Nut Allergy', 'NUT_ALLERGY', 'Tree nut and peanut allergen monitoring'),
('Lactose Intolerance', 'LACTOSE', 'Lactose and dairy monitoring'),
('Heart Disease', 'HEART_DISEASE', 'Fat, sodium, and cholesterol monitoring'),
('Obesity', 'OBESITY', 'Calorie and sugar monitoring')
ON CONFLICT (code) DO NOTHING;

-- Seed Diabetes rules
INSERT INTO public.condition_nutrition_rules (condition_id, nutrition_type_code, operator, threshold_value, unit_code, severity, description)
SELECT hc.id, 'SUGAR', '>', 15.0, 'G', 'warning', 'High sugar content - warning for diabetics'
FROM public.health_conditions hc WHERE hc.code = 'DIABETES'
AND NOT EXISTS (SELECT 1 FROM public.condition_nutrition_rules WHERE condition_id = hc.id);

INSERT INTO public.condition_nutrition_rules (condition_id, nutrition_type_code, operator, threshold_value, unit_code, severity, description)
SELECT hc.id, 'CARBOHYDRATE', '>', 30.0, 'G', 'warning', 'High carbohydrate content - monitor for diabetics'
FROM public.health_conditions hc WHERE hc.code = 'DIABETES'
AND NOT EXISTS (SELECT 1 FROM public.condition_nutrition_rules WHERE condition_id = hc.id AND nutrition_type_code = 'CARBOHYDRATE');

-- Seed Hypertension rules
INSERT INTO public.condition_nutrition_rules (condition_id, nutrition_type_code, operator, threshold_value, unit_code, severity, description)
SELECT hc.id, 'SODIUM', '>', 600.0, 'MG', 'warning', 'High sodium content - warning for hypertension'
FROM public.health_conditions hc WHERE hc.code = 'HYPERTENSION'
AND NOT EXISTS (SELECT 1 FROM public.condition_nutrition_rules WHERE condition_id = hc.id);

INSERT INTO public.condition_nutrition_rules (condition_id, nutrition_type_code, operator, threshold_value, unit_code, severity, description)
SELECT hc.id, 'TOTAL_FAT', '>', 20.0, 'G', 'warning', 'High fat content - monitor for heart health'
FROM public.health_conditions hc WHERE hc.code = 'HYPERTENSION'
AND NOT EXISTS (SELECT 1 FROM public.condition_nutrition_rules WHERE condition_id = hc.id AND nutrition_type_code = 'TOTAL_FAT');

-- Seed Heart Disease rules
INSERT INTO public.condition_nutrition_rules (condition_id, nutrition_type_code, operator, threshold_value, unit_code, severity, description)
SELECT hc.id, 'SATURATED_FAT', '>', 5.0, 'G', 'warning', 'High saturated fat - warning for heart disease'
FROM public.health_conditions hc WHERE hc.code = 'HEART_DISEASE'
AND NOT EXISTS (SELECT 1 FROM public.condition_nutrition_rules WHERE condition_id = hc.id);

INSERT INTO public.condition_nutrition_rules (condition_id, nutrition_type_code, operator, threshold_value, unit_code, severity, description)
SELECT hc.id, 'SODIUM', '>', 400.0, 'MG', 'warning', 'High sodium - warning for heart disease'
FROM public.health_conditions hc WHERE hc.code = 'HEART_DISEASE'
AND NOT EXISTS (SELECT 1 FROM public.condition_nutrition_rules WHERE condition_id = hc.id AND nutrition_type_code = 'SODIUM');

-- Seed Celiac rules
INSERT INTO public.condition_nutrition_rules (condition_id, nutrition_type_code, operator, threshold_value, unit_code, severity, description)
SELECT hc.id, 'FIBER', '>', 3.0, 'G', 'info', 'May contain gluten - check ingredient list'
FROM public.health_conditions hc WHERE hc.code = 'CELIAC'
AND NOT EXISTS (SELECT 1 FROM public.condition_nutrition_rules WHERE condition_id = hc.id);

-- Seed Nut Allergy rules (flag for allergen)
INSERT INTO public.condition_nutrition_rules (condition_id, nutrition_type_code, operator, threshold_value, unit_code, severity, description)
SELECT hc.id, 'PROTEIN', '>', 5.0, 'G', 'info', 'May contain nuts - check allergen declarations'
FROM public.health_conditions hc WHERE hc.code = 'NUT_ALLERGY'
AND NOT EXISTS (SELECT 1 FROM public.condition_nutrition_rules WHERE condition_id = hc.id);

-- Seed Unit Conversions (P11) - Mass
INSERT INTO public.unit_conversions (from_unit_id, to_unit_id, conversion_factor, measurement_type, is_exact, notes)
SELECT u1.id, u2.id, 0.001, 'mass', true, '1 mg = 0.001 g'
FROM public.units u1, public.units u2
WHERE u1.code = 'MG' AND u2.code = 'G'
AND NOT EXISTS (SELECT 1 FROM public.unit_conversions WHERE from_unit_id = u1.id AND to_unit_id = u2.id);

INSERT INTO public.unit_conversions (from_unit_id, to_unit_id, conversion_factor, measurement_type, is_exact, notes)
SELECT u1.id, u2.id, 1000.0, 'mass', true, '1 kg = 1000 g'
FROM public.units u1, public.units u2
WHERE u1.code = 'KG' AND u2.code = 'G'
AND NOT EXISTS (SELECT 1 FROM public.unit_conversions WHERE from_unit_id = u1.id AND to_unit_id = u2.id);

INSERT INTO public.unit_conversions (from_unit_id, to_unit_id, conversion_factor, measurement_type, is_exact, notes)
SELECT u1.id, u2.id, 1000.0, 'mass', true, '1000 g = 1 kg'
FROM public.units u1, public.units u2
WHERE u1.code = 'G' AND u2.code = 'KG'
AND NOT EXISTS (SELECT 1 FROM public.unit_conversions WHERE from_unit_id = u1.id AND to_unit_id = u2.id);

INSERT INTO public.unit_conversions (from_unit_id, to_unit_id, conversion_factor, measurement_type, is_exact, notes)
SELECT u1.id, u2.id, 0.001, 'mass', true, '1 mg = 0.000001 kg'
FROM public.units u1, public.units u2
WHERE u1.code = 'MG' AND u2.code = 'KG'
AND NOT EXISTS (SELECT 1 FROM public.unit_conversions WHERE from_unit_id = u1.id AND to_unit_id = u2.id);

-- Seed Unit Conversions - Volume
INSERT INTO public.unit_conversions (from_unit_id, to_unit_id, conversion_factor, measurement_type, is_exact, notes)
SELECT u1.id, u2.id, 0.001, 'volume', true, '1 ml = 0.001 L'
FROM public.units u1, public.units u2
WHERE u1.code = 'ML' AND u2.code = 'L'
AND NOT EXISTS (SELECT 1 FROM public.unit_conversions WHERE from_unit_id = u1.id AND to_unit_id = u2.id);

INSERT INTO public.unit_conversions (from_unit_id, to_unit_id, conversion_factor, measurement_type, is_exact, notes)
SELECT u1.id, u2.id, 1000.0, 'volume', true, '1 L = 1000 ml'
FROM public.units u1, public.units u2
WHERE u1.code = 'L' AND u2.code = 'ML'
AND NOT EXISTS (SELECT 1 FROM public.unit_conversions WHERE from_unit_id = u1.id AND to_unit_id = u2.id);

-- Register migration
INSERT INTO public.schema_migrations (version, checksum) VALUES
('002_collector_tables', 'fateen-collector-v1')
ON CONFLICT (version) DO NOTHING;

COMMIT;
