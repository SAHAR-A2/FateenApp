-- =============================================================================
-- 0055: complete allergen vocabulary, cited nutrition thresholds
--
-- Allergens. The Flutter app offers the 14 major allergens of Regulation
-- (EU) No 1169/2011 Annex II (lib/data/allergy_options.dart). The table
-- had 10-11 of them, so a user allergic to gluten, molluscs, celery, lupin
-- or sulphites always got UNKNOWN. SHELLFISH already means crustaceans.
--
-- Health rules. The old rules were proxies with no medical basis (fibre
-- > 3 g meant "may contain gluten", protein > 5 g meant "may contain
-- nuts") and ignored whether a value was per 100 g, per 100 ml or per
-- serving. They are replaced by the UK
-- Food Standards Agency front-of-pack "high" thresholds (Guide to creating
-- a front of pack nutrition label, 2016):
--
--                         food, per 100 g    drink, per 100 ml
--     total sugars            > 22.5 g            > 11.25 g
--     saturated fat           > 5 g               > 2.5 g
--     salt                    > 1.5 g             > 0.75 g
--       as sodium (salt/2.5)  > 600 mg            > 300 mg
--
-- The thresholds live in a new table, condition_nutrient_thresholds, which
-- names the measurement basis of each rule. The old table is left as it is
-- and is no longer read. It cannot simply gain a column: the reference seed
-- (scripts/export_reference_seed.py) loads it before this migration runs.
-- Gluten, nut and lactose are checked through allergens, not nutrition.
-- Every statement is idempotent, so a database rebuilt from a seed exported
-- after this migration ends up with the same rows.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------- allergens
INSERT INTO public.allergens (allergen_type_id, internal_code, name, description, status_id, confidence_level)
SELECT t.id, v.code, v.name, v.description, s.id, 1.0
FROM (VALUES
    ('GLUTEN',    'Gluten',    'Cereals containing gluten: wheat, rye, barley, oats and their hybrids'),
    ('MOLLUSCS',  'Molluscs',  'Molluscs and mollusc-derived ingredients (squid, octopus, mussels, oysters)'),
    ('CELERY',    'Celery',    'Celery and celeriac and derived ingredients'),
    ('LUPIN',     'Lupin',     'Lupin and lupin-derived ingredients'),
    ('SULPHITES', 'Sulphites', 'Sulphur dioxide and sulphites at more than 10 mg/kg or 10 mg/l')
) AS v(code, name, description)
JOIN public.allergen_types t ON t.code = 'FOOD_ALLERGEN'
JOIN public.lifecycle_statuses s ON s.code = 'ACTIVE'
-- NOT EXISTS, not ON CONFLICT: the BEFORE INSERT history trigger would
-- still write a history row for a skipped conflicting insert.
WHERE NOT EXISTS (SELECT 1 FROM public.allergens a WHERE a.internal_code = v.code);

-- Salt is recorded by 0046 on Cloud; a database built from this repository
-- lacks it.
INSERT INTO public.nutrition_types (code, name, status_id)
SELECT 'SALT', 'Salt', id FROM public.lifecycle_statuses WHERE code = 'ACTIVE'
  AND NOT EXISTS (SELECT 1 FROM public.nutrition_types WHERE code = 'SALT');

-- ------------------------------------------------------------ conditions
INSERT INTO public.health_conditions (name, code, description)
SELECT 'High Cholesterol', 'HIGH_CHOLESTEROL', 'Saturated fat monitoring for high blood cholesterol'
WHERE NOT EXISTS (SELECT 1 FROM public.health_conditions WHERE code = 'HIGH_CHOLESTEROL');

-- ------------------------------------------------------------ thresholds
CREATE TABLE IF NOT EXISTS public.condition_nutrient_thresholds (
    id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    condition_id           uuid NOT NULL REFERENCES public.health_conditions(id),
    nutrition_type_code    text NOT NULL,
    measurement_basis_code text NOT NULL CHECK (measurement_basis_code IN ('PER_100G', 'PER_100ML')),
    operator               text NOT NULL DEFAULT '>' CHECK (operator IN ('>', '>=', '<', '<=')),
    threshold_value        double precision NOT NULL CHECK (threshold_value >= 0),
    unit_code              text NOT NULL,
    severity               text NOT NULL DEFAULT 'warning',
    description            text,
    source                 text NOT NULL,
    is_active              boolean NOT NULL DEFAULT TRUE,
    created_at             timestamptz NOT NULL DEFAULT now(),
    UNIQUE (condition_id, nutrition_type_code, measurement_basis_code)
);

COMMENT ON TABLE public.condition_nutrient_thresholds IS
    'Nutrition thresholds per health condition and measurement basis (migration 0055). Replaces condition_nutrition_rules.';

INSERT INTO public.condition_nutrient_thresholds
    (condition_id, nutrition_type_code, measurement_basis_code, threshold_value, unit_code, description, source)
SELECT c.id, r.nutrient, r.basis, r.threshold, r.unit, r.description,
       'UK FSA, Guide to creating a front of pack nutrition label, 2016: "high"'
FROM (VALUES
    ('DIABETES',         'SUGAR',         22.5,  'G',  'PER_100G',  'سكر مرتفع: أكثر من 22.5 غ لكل 100 غ | High sugar: over 22.5 g per 100 g'),
    ('DIABETES',         'SUGAR',         11.25, 'G',  'PER_100ML', 'سكر مرتفع: أكثر من 11.25 غ لكل 100 مل | High sugar: over 11.25 g per 100 ml'),
    ('HYPERTENSION',     'SODIUM',        600,   'MG', 'PER_100G',  'ملح مرتفع: صوديوم أكثر من 600 ملغ لكل 100 غ | High salt: sodium over 600 mg per 100 g'),
    ('HYPERTENSION',     'SODIUM',        300,   'MG', 'PER_100ML', 'ملح مرتفع: صوديوم أكثر من 300 ملغ لكل 100 مل | High salt: sodium over 300 mg per 100 ml'),
    ('HIGH_CHOLESTEROL', 'SATURATED_FAT', 5,     'G',  'PER_100G',  'دهون مشبعة مرتفعة: أكثر من 5 غ لكل 100 غ | High saturated fat: over 5 g per 100 g'),
    ('HIGH_CHOLESTEROL', 'SATURATED_FAT', 2.5,   'G',  'PER_100ML', 'دهون مشبعة مرتفعة: أكثر من 2.5 غ لكل 100 مل | High saturated fat: over 2.5 g per 100 ml'),
    ('HEART_DISEASE',    'SATURATED_FAT', 5,     'G',  'PER_100G',  'دهون مشبعة مرتفعة: أكثر من 5 غ لكل 100 غ | High saturated fat: over 5 g per 100 g'),
    ('HEART_DISEASE',    'SATURATED_FAT', 2.5,   'G',  'PER_100ML', 'دهون مشبعة مرتفعة: أكثر من 2.5 غ لكل 100 مل | High saturated fat: over 2.5 g per 100 ml'),
    ('HEART_DISEASE',    'SODIUM',        600,   'MG', 'PER_100G',  'ملح مرتفع: صوديوم أكثر من 600 ملغ لكل 100 غ | High salt: sodium over 600 mg per 100 g'),
    ('HEART_DISEASE',    'SODIUM',        300,   'MG', 'PER_100ML', 'ملح مرتفع: صوديوم أكثر من 300 ملغ لكل 100 مل | High salt: sodium over 300 mg per 100 ml')
) AS r(condition_code, nutrient, threshold, unit, basis, description)
JOIN public.health_conditions c ON c.code = r.condition_code
ON CONFLICT (condition_id, nutrition_type_code, measurement_basis_code) DO NOTHING;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fateen_app') THEN
        GRANT SELECT ON public.condition_nutrient_thresholds TO fateen_app;
    END IF;
END $$;

COMMIT;

-- ROLLBACK (run only to undo): DROP TABLE public.condition_nutrient_thresholds;
-- plus DELETE of the five allergens, SALT and HIGH_CHOLESTEROL if unused.
