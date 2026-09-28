-- =============================================================================
-- 0056: reference rows the catalog loader needs
--
-- image_types was empty on Cloud, and images.image_type_id is NOT NULL, so no
-- product image could be stored and the consumer search (which requires one)
-- could show nothing. FRONT is the front-of-pack photo.
--
-- PRIMARY_IMAGE is the relationship of a product to its main photo
-- (product_images.relationship_type_id is NOT NULL and no existing type fits).
--
-- ALMARAI_WEBSITE records products read from almarai.com, the manufacturer's
-- own site (Almarai and its brands: L'usine, Alyoum, 7 Days, Nura, ...).
-- OPEN_FOOD_FACTS already exists on Cloud (0044); it is added here only
-- where missing.
--
-- product_ingredient_statements keeps the ingredient list exactly as printed
-- on the pack, per language. The app shows it, and an allergy check treats a
-- product with a statement as having allergen evidence: the loader derives
-- product_allergens from the statement itself, not only from the source's
-- own allergen tags.
--
-- Idempotent (NOT EXISTS, not ON CONFLICT: the history triggers would record
-- a skipped insert).
-- =============================================================================

BEGIN;

INSERT INTO public.image_types (code, name, description, display_order, status_id)
SELECT v.code, v.name, v.description, v.ord, s.id
FROM (VALUES
    ('FRONT', 'Front of pack', 'Photo of the front of the package', 1)
) AS v(code, name, description, ord)
JOIN public.lifecycle_statuses s ON s.code = 'ACTIVE'
WHERE NOT EXISTS (SELECT 1 FROM public.image_types t WHERE t.code = v.code);

INSERT INTO public.relationship_types (code, name, description, is_directional, display_order, status_id)
SELECT 'PRIMARY_IMAGE', 'Primary Image', 'Main photo shown for the product', true, 0, s.id
FROM public.lifecycle_statuses s
WHERE s.code = 'ACTIVE'
  AND NOT EXISTS (SELECT 1 FROM public.relationship_types WHERE code = 'PRIMARY_IMAGE');

INSERT INTO public.data_sources (code, name, description, source_type_id, priority_id, is_verified, status_id)
SELECT v.code, v.name, v.description, st.id, sp.id, v.verified, s.id
FROM (VALUES
    ('ALMARAI_WEBSITE', 'Almarai official website',
     'Product pages on almarai.com, published by the manufacturer', 'MANUFACTURER', true),
    ('OPEN_FOOD_FACTS', 'Open Food Facts',
     'Open Food Facts public product database.', 'DATABASE', false)
) AS v(code, name, description, kind, verified)
JOIN public.source_types st ON st.code = v.kind
JOIN public.source_priorities sp ON sp.code = v.kind
JOIN public.lifecycle_statuses s ON s.code = 'ACTIVE'
WHERE NOT EXISTS (SELECT 1 FROM public.data_sources d WHERE d.code = v.code);

CREATE TABLE IF NOT EXISTS public.product_ingredient_statements (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id    uuid NOT NULL REFERENCES public.products(id),
    language_code text NOT NULL CHECK (language_code IN ('ar', 'en')),
    statement     text NOT NULL CHECK (length(btrim(statement)) > 0),
    source_id     uuid REFERENCES public.data_sources(id),
    source_url    text,
    created_at    timestamptz NOT NULL DEFAULT now(),
    deleted_at    timestamptz,
    UNIQUE (product_id, language_code)
);

COMMENT ON TABLE public.product_ingredient_statements IS
    'Ingredient list as printed on the pack, per language (migration 0056).';

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fateen_app') THEN
        GRANT SELECT ON public.product_ingredient_statements TO fateen_app;
    END IF;
END $$;

COMMIT;
