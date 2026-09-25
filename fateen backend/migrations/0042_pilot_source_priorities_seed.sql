-- Migration 0042: Seed source_priorities + COLLECTOR data_sources (pilot hardening)
--
-- Part 1: source_priorities. The pipeline (orchestrator provenance lookup) and the
-- new product-creation code require a data_sources row coded COLLECTOR. That row
-- needs a priority (DATABASE) and a source_type (DATABASE). This migration seeds
-- the DATABASE priority used by it.
--
-- No fabricated values: only the ranks required by the adopted source policy
-- (MANUFACTURER=1, REGULATORY=2, DATABASE=3 -- the code compares against the
-- relative order, only DATABASE is consumed today by COLLECTOR).
--
-- Idempotent: guarded inserts only (NOT EXISTS); never updates existing rows.
-- No DROP/TRUNCATE/DELETE anywhere.

BEGIN;

INSERT INTO public.source_priorities
    (id, code, name, rank, description, status_id, version_number, created_at, updated_at)
SELECT gen_random_uuid(), 'DATABASE', 'Database Source', 3,
       'Rank 3: aggregated database/list source (lowest relative authority adopted).',
       (SELECT id FROM public.lifecycle_statuses WHERE code = 'ACTIVE' AND deleted_at IS NULL LIMIT 1),
       1, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM public.source_priorities WHERE code = 'DATABASE');

INSERT INTO public.source_priorities
    (id, code, name, rank, description, status_id, version_number, created_at, updated_at)
SELECT gen_random_uuid(), 'MANUFACTURER', 'Manufacturer Source', 1,
       'Rank 1: manufacturer-declared source (highest relative authority adopted).',
       (SELECT id FROM public.lifecycle_statuses WHERE code = 'ACTIVE' AND deleted_at IS NULL LIMIT 1),
       1, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM public.source_priorities WHERE code = 'MANUFACTURER');

INSERT INTO public.source_priorities
    (id, code, name, rank, description, status_id, version_number, created_at, updated_at)
SELECT gen_random_uuid(), 'REGULATORY', 'Regulatory Source', 2,
       'Rank 2: government/regulatory listing source (adopted).',
       (SELECT id FROM public.lifecycle_statuses WHERE code = 'ACTIVE' AND deleted_at IS NULL LIMIT 1),
       1, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM public.source_priorities WHERE code = 'REGULATORY');

-- Part 2: COLLECTOR data_sources row (agent-owned ingestion identity).
-- Uses ONLY existing reference rows: source_type DATABASE, priority DATABASE,
-- lifecycle status ACTIVE. Idempotent and additive.

INSERT INTO public.data_sources
    (id, code, name, description, source_type_id, priority_id, country_id,
     is_verified, status_id, version_number, created_at, updated_at)
SELECT gen_random_uuid(), 'COLLECTOR', 'Fateen Collection Pipeline',
       'Internal collection pipeline (agent ingestion for the pilot).',
       st.id, sp.id, NULL, TRUE,
       (SELECT id FROM public.lifecycle_statuses WHERE code = 'ACTIVE' AND deleted_at IS NULL LIMIT 1),
       1, NOW(), NOW()
FROM public.source_types st
JOIN public.source_priorities sp ON sp.code = 'DATABASE'
WHERE st.code = 'DATABASE'
  AND NOT EXISTS (SELECT 1 FROM public.data_sources WHERE code = 'COLLECTOR');

-- Register migration (idempotent ledger, same pattern as 002).
INSERT INTO public.schema_migrations (version, checksum, applied_at)
VALUES ('0042_pilot_source_priorities_seed', 'fateen-pilot-0042-v1', NOW())
ON CONFLICT (version) DO NOTHING;

COMMIT;