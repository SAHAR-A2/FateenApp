-- =============================================================================
-- 0054: product_completeness view (review queue, read-only)
--
-- A product that lacks a field is kept and reviewed, not dropped. This view
-- reports per product which fields are still missing so the review queue,
-- the future source orchestrator and dashboards all read one definition:
--
--   barcode            active (effective-dated, non-deleted) product barcode
--   name_ar / name_en  approved translation in that language
--   ingredients        at least one active ingredient relationship
--   allergen_evidence  an ingredient list OR at least one allergen row;
--                      without either, an allergy check cannot be answered
--   nutrition          at least one active nutrition value
--   image              active product image
--
-- barcode, names and image match the consumer search display rules in
-- app/repositories/product_repository.py; allergen_evidence matches the
-- INSUFFICIENT_DATA rule in app/services/compatibility_service.py.
--
-- Additive only: one view, no table or data change. security_invoker keeps
-- the caller's own privileges and RLS on the underlying tables.
-- =============================================================================

BEGIN;

CREATE OR REPLACE VIEW public.product_completeness
WITH (security_invoker = true) AS
WITH facts AS (
    SELECT
        p.id AS product_id,
        p.internal_code,
        p.name,
        p.confidence_level,
        p.created_at,
        EXISTS (
            SELECT 1 FROM public.product_barcodes pb
            JOIN public.barcodes b ON b.id = pb.barcode_id
            WHERE pb.product_id = p.id
              AND pb.deleted_at IS NULL AND b.deleted_at IS NULL
              AND (pb.effective_from IS NULL OR pb.effective_from <= NOW())
              AND (pb.effective_to IS NULL OR pb.effective_to > NOW())
        ) AS has_barcode,
        EXISTS (
            SELECT 1 FROM public.product_translations pt
            JOIN public.languages l ON l.id = pt.language_id
            WHERE pt.product_id = p.id AND l.code = 'ar'
              AND pt.deleted_at IS NULL AND l.deleted_at IS NULL
              AND pt.translation_status = 'approved'
        ) AS has_name_ar,
        EXISTS (
            SELECT 1 FROM public.product_translations pt
            JOIN public.languages l ON l.id = pt.language_id
            WHERE pt.product_id = p.id AND l.code = 'en'
              AND pt.deleted_at IS NULL AND l.deleted_at IS NULL
              AND pt.translation_status = 'approved'
        ) AS has_name_en,
        EXISTS (
            SELECT 1 FROM public.product_ingredients pi
            WHERE pi.product_id = p.id AND pi.deleted_at IS NULL
              AND (pi.effective_from IS NULL OR pi.effective_from <= NOW())
              AND (pi.effective_to IS NULL OR pi.effective_to > NOW())
        ) AS has_ingredients,
        EXISTS (
            SELECT 1 FROM public.product_allergens pa
            WHERE pa.product_id = p.id AND pa.deleted_at IS NULL
              AND (pa.effective_from IS NULL OR pa.effective_from <= NOW())
              AND (pa.effective_to IS NULL OR pa.effective_to > NOW())
        ) AS has_allergens,
        EXISTS (
            SELECT 1 FROM public.product_nutrition_values pnv
            WHERE pnv.product_id = p.id AND pnv.deleted_at IS NULL
              AND (pnv.effective_from IS NULL OR pnv.effective_from <= NOW())
              AND (pnv.effective_to IS NULL OR pnv.effective_to > NOW())
        ) AS has_nutrition,
        EXISTS (
            SELECT 1 FROM public.product_images pim
            JOIN public.images i ON i.id = pim.image_id
            WHERE pim.product_id = p.id
              AND pim.deleted_at IS NULL AND i.deleted_at IS NULL
              AND (pim.effective_from IS NULL OR pim.effective_from <= NOW())
              AND (pim.effective_to IS NULL OR pim.effective_to > NOW())
        ) AS has_image
    FROM public.products p
    WHERE p.deleted_at IS NULL
)
SELECT
    f.*,
    array_remove(ARRAY[
        CASE WHEN NOT f.has_barcode THEN 'barcode' END,
        CASE WHEN NOT f.has_name_ar THEN 'name_ar' END,
        CASE WHEN NOT f.has_name_en THEN 'name_en' END,
        CASE WHEN NOT f.has_ingredients THEN 'ingredients' END,
        CASE WHEN NOT (f.has_ingredients OR f.has_allergens) THEN 'allergen_evidence' END,
        CASE WHEN NOT f.has_nutrition THEN 'nutrition' END,
        CASE WHEN NOT f.has_image THEN 'image' END
    ], NULL)::text[] AS missing_fields
FROM facts f;

COMMENT ON VIEW public.product_completeness IS
    'Per-product missing fields for the review queue (migration 0054).';

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fateen_app') THEN
        GRANT SELECT ON public.product_completeness TO fateen_app;
    END IF;
END $$;

COMMIT;

-- ROLLBACK (run only to undo): DROP VIEW public.product_completeness;
