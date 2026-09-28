-- =============================================================================
-- 0057: the API's runtime role can read every table the public API reads
--
-- On Cloud, row level security is enabled on the public tables and fateen_app
-- reads through "fateen_app_read_only" policies (17 tables at the migration).
-- A table added later with RLS on and no such policy is silently empty to the
-- API: the health thresholds (0055) or the printed ingredient lists (0056)
-- would read as "no rows", and every diabetes / blood-pressure check would
-- come back UNKNOWN.
--
-- For each catalog table the API reads, this grants SELECT to fateen_app and,
-- where RLS is on and fateen_app has no policy, adds the same read-only
-- policy the other tables have. Read access only; idempotent; a no-op where
-- the role does not exist (local and CI databases without it).
-- scripts/check_runtime_access.py verifies the result as fateen_app.
-- =============================================================================

BEGIN;

DO $$
DECLARE
    t text;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fateen_app') THEN
        RETURN;
    END IF;
    GRANT USAGE ON SCHEMA public TO fateen_app;
    FOREACH t IN ARRAY ARRAY[
        'products', 'product_translations', 'product_barcodes', 'barcodes', 'product_images', 'images',
        'product_allergens', 'allergens', 'product_nutrition_values', 'nutrition_types', 'units',
        'measurement_bases', 'product_ingredient_statements', 'product_categories', 'languages',
        'lifecycle_statuses', 'relationship_types', 'evidence_types', 'data_sources', 'health_conditions',
        'condition_nutrient_thresholds', 'product_ingredients', 'ingredients', 'health_flags',
        'product_health_flags', 'brands', 'companies'
    ]
    LOOP
        CONTINUE WHEN to_regclass('public.' || t) IS NULL;
        EXECUTE format('GRANT SELECT ON public.%I TO fateen_app', t);
        IF (SELECT relrowsecurity FROM pg_class WHERE oid = to_regclass('public.' || t))
           AND NOT EXISTS (
               SELECT 1 FROM pg_policies
               WHERE schemaname = 'public' AND tablename = t
                 AND 'fateen_app' = ANY (roles) AND cmd IN ('SELECT', 'ALL')
           )
        THEN
            EXECUTE format(
                'CREATE POLICY fateen_app_read_only ON public.%I FOR SELECT TO fateen_app USING (true)', t);
        END IF;
    END LOOP;
END $$;

COMMIT;

-- ROLLBACK (run only to undo): the grants and policies are read-only access
-- the API needs; drop a policy with
--   DROP POLICY fateen_app_read_only ON public.<table>;
