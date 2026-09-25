-- Migration 003: Pilot safety constraints
-- Adds CHECK constraints on status columns to prevent invalid states.

BEGIN;

ALTER TABLE public.scan_jobs
    ADD CONSTRAINT chk_scan_jobs_status
    CHECK (status IN ('pending', 'in_progress', 'completed', 'partial', 'failed', 'blocked'));

ALTER TABLE public.scan_job_items
    ADD CONSTRAINT chk_scan_job_items_status
    CHECK (status IN ('pending', 'processed', 'validation_failed', 'ingestion_failed', 'needs_review'));

ALTER TABLE public.scan_job_items
    ADD CONSTRAINT chk_scan_job_items_action
    CHECK (action IN ('accepted', 'rejected', 'needs_review'));

ALTER TABLE public.discovery_candidates
    ADD CONSTRAINT chk_discovery_candidates_status
    CHECK (status IN (
        'discovered', 'enriched', 'normalized', 'pending_review',
        'approved', 'merged', 'discarded', 'validation_failed',
        'matched', 'new', 'ingestion_failed'
    ));

ALTER TABLE public.data_conflicts
    ADD CONSTRAINT chk_data_conflicts_resolution
    CHECK (resolution IN ('unresolved', 'resolved', 'needs_review', 'dismissed'));

ALTER TABLE public.data_conflicts
    ADD CONSTRAINT chk_data_conflicts_status
    CHECK (status IN ('detected', 'acknowledged', 'resolved', 'dismissed'));

COMMIT;
