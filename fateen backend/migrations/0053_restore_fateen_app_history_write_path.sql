-- =============================================================================
-- 0053: Restore fateen_app privileges on the entity-HISTORY tables (Phase 12D).
--
-- Discovered during the Phase 12D canary (real write as fateen_app + forced
-- rollback): products/barcodes/product_barcodes carry a BEFORE/AFTER trigger
-- capture_entity_history(), an INVOKER PL/pgSQL function (search_path=public)
-- whose dynamic EXECUTE performs:
--    1) SELECT id FROM <entity>_history WHERE original_entity_id = ... ORDER BY
--       version_number DESC LIMIT 1   (previous_version_id chain lookup)
--    2) INSERT INTO <entity>_history (...) SELECT ... jsonb_populate_record(...)
-- Therefore fateen_app needs SELECT and INSERT on the history table of every
-- entity the write path can insert/update. 0052 granted only the base tables,
-- so the first real INSERT failed with:
--    InsufficientPrivilege: permission denied for table products_history
--
-- Affected history tables (write-path reachable):
--   * products          -> products_history         (INSERT always)
--   * barcodes          -> barcodes_history         (INSERT always)
--   * product_barcodes  -> product_barcodes_history (INSERT always)
--   * brands            -> brands_history           (INSERT only when the
--                                                    candidate carries
--                                                    company_id; not exercised
--                                                    by the current pilot, but
--                                                    part of the real writer)
-- product_ingredients / product_allergens / product_nutrition_values have NO
-- history trigger (only set_updated_at, which writes nothing outside the base
-- table), so no history grants are needed for them.
--
-- Principles preserved from 0052:
--   * MINIMUM surface: only SELECT (chain lookup) + INSERT (version mint) on
--     the history tables. NO UPDATE/DELETE on history, ever.
--   * NO schema change; RLS on the base tables stays enforced
--     (fateen_app.rolbypassrls=false; history tables are un-RLS'd, owned by
--     postgres, so RLS does not apply to them at all).
--   * Transactional: single BEGIN/COMMIT; apply exactly ONCE and record in the
--     migration ledger (version '0053_restore_fateen_app_history_write_path').
--   * NOT auto-applied; rollback script embedded below as comments only.
-- =============================================================================

BEGIN;

GRANT SELECT, INSERT ON public.products_history TO fateen_app;
GRANT SELECT, INSERT ON public.barcodes_history TO fateen_app;
GRANT SELECT, INSERT ON public.product_barcodes_history TO fateen_app;
GRANT SELECT, INSERT ON public.brands_history TO fateen_app;

COMMIT;

-- =============================================================================
-- ROLLBACK / REVERT (do NOT run with this migration; run only to undo it)
-- =============================================================================
-- BEGIN;
-- REVOKE SELECT, INSERT ON public.products_history FROM fateen_app;
-- REVOKE SELECT, INSERT ON public.barcodes_history FROM fateen_app;
-- REVOKE SELECT, INSERT ON public.product_barcodes_history FROM fateen_app;
-- REVOKE SELECT, INSERT ON public.brands_history FROM fateen_app;
-- COMMIT;
-- After: the next history-triggered INSERT as fateen_app fails again with
-- "permission denied for table products_history" (Phase 12D discovery state).
-- =============================================================================

-- =============================================================================
-- VALIDATION QUERIES (run AFTER applying, as fateen_app)
-- =============================================================================
-- 1) Grants now visible:
--   SELECT table_name, privilege_type FROM information_schema.table_privileges
--   WHERE grantee='fateen_app' AND table_schema='public'
--     AND table_name IN ('products_history','barcodes_history',
--       'product_barcodes_history','brands_history')
--   ORDER BY table_name, privilege_type;
--   Expect SELECT + INSERT on all four rows; no UPDATE/DELETE.
--
-- 2) Base-table state unchanged from 0052:
--   SELECT has_table_privilege('fateen_app','products','INSERT')    = true
--   SELECT has_table_privilege('fateen_app','products','DELETE')    = false
--   SELECT has_table_privilege('fateen_app','ingredients','INSERT') = false
--
-- 3) Full end-to-end proof = Phase 12D canary: a real fateen_app INSERT on the
--   frozen-764 subset now succeeds through products -> products_history,
--   barcodes -> barcodes_history, product_barcodes -> product_barcodes_history
--   (brands skipped without company_id), then the connection is forcibly
--   rolled back and net deltas verify to ZERO.
-- =============================================================================