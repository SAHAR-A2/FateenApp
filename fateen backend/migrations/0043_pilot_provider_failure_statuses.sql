-- Migration 0043: Extend pilot status CHECK constraints to cover provider
-- failure outcomes written by _record_provider_failure.
--
-- Current CHECKs (003) reject these values, so a live LLM provider failure
-- causes an integrity exception instead of the intended retryable record:
--   scan_job_items.status      = 'provider_failed'   (written by the pipeline)
--   scan_job_items.action      = 'retryable'         (written by the pipeline)
--   discovery_candidates.status = 'retryable'        (written by the pipeline)
--
-- Additive only: the new allowed values are appended to the existing sets;
-- all previously-valid values stay valid. No data is deleted or rewritten.
-- Idempotent: each constraint is only re-created when it lacks the new value.

BEGIN;

DO $$
DECLARE
    _def text;
BEGIN
    SELECT pg_get_constraintdef(oid) INTO _def
    FROM pg_constraint
    WHERE conname = 'chk_scan_job_items_status'
      AND conrelid = 'public.scan_job_items'::regclass;

    IF _def IS NULL OR POSITION('provider_failed' IN _def) = 0 THEN
        ALTER TABLE public.scan_job_items
            DROP CONSTRAINT IF EXISTS chk_scan_job_items_status;
        ALTER TABLE public.scan_job_items
            ADD CONSTRAINT chk_scan_job_items_status
            CHECK (status IN (
                'pending', 'processed', 'validation_failed',
                'ingestion_failed', 'needs_review', 'provider_failed'
            ));
    END IF;
END $$;

DO $$
DECLARE
    _def text;
BEGIN
    SELECT pg_get_constraintdef(oid) INTO _def
    FROM pg_constraint
    WHERE conname = 'chk_scan_job_items_action'
      AND conrelid = 'public.scan_job_items'::regclass;

    IF _def IS NULL OR POSITION('retryable' IN _def) = 0 THEN
        ALTER TABLE public.scan_job_items
            DROP CONSTRAINT IF EXISTS chk_scan_job_items_action;
        ALTER TABLE public.scan_job_items
            ADD CONSTRAINT chk_scan_job_items_action
            CHECK (action IN ('accepted', 'rejected', 'needs_review', 'retryable'));
    END IF;
END $$;

DO $$
DECLARE
    _def text;
BEGIN
    SELECT pg_get_constraintdef(oid) INTO _def
    FROM pg_constraint
    WHERE conname = 'chk_discovery_candidates_status'
      AND conrelid = 'public.discovery_candidates'::regclass;

    IF _def IS NULL OR POSITION('retryable' IN _def) = 0 THEN
        ALTER TABLE public.discovery_candidates
            DROP CONSTRAINT IF EXISTS chk_discovery_candidates_status;
        ALTER TABLE public.discovery_candidates
            ADD CONSTRAINT chk_discovery_candidates_status
            CHECK (status IN (
                'discovered', 'enriched', 'normalized', 'pending_review',
                'approved', 'merged', 'discarded', 'validation_failed',
                'matched', 'new', 'ingestion_failed', 'retryable'
            ));
    END IF;
END $$;

-- Register migration (idempotent ledger).
INSERT INTO public.schema_migrations (version, checksum, applied_at)
VALUES ('0043_pilot_provider_failure_statuses', 'fateen-pilot-0043-v1', NOW())
ON CONFLICT (version) DO NOTHING;

COMMIT;