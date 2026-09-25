-- =============================================================================
-- Reference seed data for the Fateen Data Agent (dev database only).
-- Populates governed reference vocabulary the agent's provenance/conflict
-- model depends on. Idempotent: safe to re-run.
-- =============================================================================
-- NOTE: run against the DEV database (fateen_agent_dev), never production.

BEGIN;

-- ---------------------------------------------------------------------------
-- source_priorities: trust scale used in conflict resolution.
-- Higher rank wins conflicts. Bounded 1..99.
-- ---------------------------------------------------------------------------
INSERT INTO public.source_priorities (code, name, rank, description, status_id)
SELECT v.code, v.name, v.rank, v.description, (SELECT id FROM public.lifecycle_statuses WHERE code = 'ACTIVE')
FROM (VALUES
    ('PRIMARY',        'Primary Official', 90, 'Official manufacturer site, product label/PDF, regulatory authority statement.', NULL),
    ('SECONDARY',      'Secondary Database', 70, 'Trusted open/regulated food databases (e.g. Open Food Facts, national registries).', NULL),
    ('TERTIARY',       'Tertiary Web', 50, 'Additional trustworthy web sources used to corroborate, never as sole primary.', NULL),
    ('COMMUNITY',      'Community Submitted', 30, 'User/community-submitted records (low trust, high review need).', NULL),
    ('UNVERIFIED',     'Unverified', 10, 'Unknown or unverified source; never sufficient for VERIFIED alone.', NULL)
) AS v(code, name, rank, description, status_id)
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- data_sources: canonical concrete sources the agent can reference.
-- is_verified = institutionally trusted, may bypass per-record human review.
-- ---------------------------------------------------------------------------
INSERT INTO public.data_sources (code, name, description, source_type_id, priority_id, is_verified, status_id)
SELECT
    v.code,
    v.name,
    v.description,
    st.id,
    sp.id,
    v.is_verified,
    (SELECT id FROM public.lifecycle_statuses WHERE code = 'ACTIVE')
FROM (VALUES
    ('openfoodfacts',        'Open Food Facts',        'Open, community-maintained global food product database (bulk source).', 'DATABASE', 'SECONDARY', true),
    ('manufacturer_official','Manufacturer Official Site', 'Official company website / official product page (primary source).', 'MANUFACTURER', 'PRIMARY', true),
    ('regulatory_authority', 'Regulatory Authority',   'Official food-safety/regulatory authority statement.', 'REGULATORY', 'PRIMARY', true),
    ('web_research',         'Web Research',           'Best-effort web research (search + fetched pages), tertiary corroboration.', 'IMPORT', 'TERTIARY', false),
    ('product_label',        'Product Label / PDF',    'Official label image or ingredient/nutrition PDF supplied by the manufacturer.', 'MANUFACTURER', 'PRIMARY', true)
) AS v(code, name, description, source_type_code, priority_code, is_verified)
JOIN public.source_types st ON st.code = v.source_type_code
JOIN public.source_priorities sp ON sp.code = v.priority_code
ON CONFLICT (code) DO NOTHING;

COMMIT;
