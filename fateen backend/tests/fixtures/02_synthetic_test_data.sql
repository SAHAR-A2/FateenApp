-- FATEEN test fixture 2/2: synthetic additions (TEST DATA ONLY).
--
-- Load after every migration. Never load into Cloud.
--
-- Adds the reference rows the code and tests rely on that the archived
-- pilot dataset predates (MEASURED_VALUE, KCAL, measurement bases, SUGAR,
-- OPEN_FOOD_FACTS) and nine per-100 ml label values for the synthetic
-- FATEEN_MILK_TEST product. The nutrition numbers are typical whole-milk
-- label values chosen for tests; they describe no real product.
-- Idempotent: every insert is guarded by NOT EXISTS.
BEGIN;
INSERT INTO public.relationship_types (code, name, is_directional, display_order, status_id)
SELECT 'MEASURED_VALUE', 'Measured Value', false, 7, (SELECT id FROM public.lifecycle_statuses WHERE code='ACTIVE')
WHERE NOT EXISTS (SELECT 1 FROM public.relationship_types WHERE code='MEASURED_VALUE');

INSERT INTO public.units (code, name, symbol, dimension, is_base_unit, status_id)
SELECT 'KCAL', 'Kilocalorie', 'kcal', 'energy', true, (SELECT id FROM public.lifecycle_statuses WHERE code='ACTIVE')
WHERE NOT EXISTS (SELECT 1 FROM public.units WHERE code='KCAL');

INSERT INTO public.measurement_bases (code, name, display_order, status_id)
SELECT v.code, v.name, v.ord, (SELECT id FROM public.lifecycle_statuses WHERE code='ACTIVE')
FROM (VALUES ('PER_100G','Per 100 g',1),('PER_100ML','Per 100 ml',2),('PER_SERVING','Per serving',3),('PER_PACKAGE','Per package',4)) v(code,name,ord)
WHERE NOT EXISTS (SELECT 1 FROM public.measurement_bases m WHERE m.code=v.code);

INSERT INTO public.ingredients (internal_code, name, status_id, confidence_level)
SELECT 'SUGAR', 'Sugar', (SELECT id FROM public.lifecycle_statuses WHERE code='ACTIVE'), 0.9
WHERE NOT EXISTS (SELECT 1 FROM public.ingredients WHERE internal_code='SUGAR');

INSERT INTO public.data_sources (code, name, description, source_type_id, priority_id, is_verified, status_id)
SELECT 'OPEN_FOOD_FACTS', 'Open Food Facts', 'Open Food Facts public product database.',
       (SELECT id FROM public.source_types WHERE code='DATABASE'),
       (SELECT id FROM public.source_priorities WHERE code='DATABASE'), false,
       (SELECT id FROM public.lifecycle_statuses WHERE code='ACTIVE')
WHERE NOT EXISTS (SELECT 1 FROM public.data_sources WHERE code='OPEN_FOOD_FACTS');

-- Nine label values for the synthetic FATEEN_MILK_TEST product (per 100 ml).
INSERT INTO public.product_nutrition_values
    (product_id, nutrition_type_id, relationship_type_id, amount_value, unit_id,
     source_id, evidence_type_id, confidence_level, status_id, measurement_basis_id)
SELECT p.id, nt.id, rt.id, v.amount, u.id,
       (SELECT id FROM public.data_sources WHERE code='FATEEN_TEST'),
       (SELECT id FROM public.evidence_types WHERE code='LABEL'), 0.9,
       (SELECT id FROM public.lifecycle_statuses WHERE code='ACTIVE'),
       (SELECT id FROM public.measurement_bases WHERE code='PER_100ML')
FROM (VALUES ('ENERGY',61.0,'KCAL'),('PROTEIN',3.2,'G'),('CARBOHYDRATE',4.8,'G'),
             ('SUGAR',4.8,'G'),('TOTAL_FAT',3.3,'G'),('SATURATED_FAT',1.9,'G'),
             ('TRANS_FAT',0.0,'G'),('FIBER',0.0,'G'),('SODIUM',44.0,'MG')) v(nt,amount,unit)
JOIN public.nutrition_types nt ON nt.code = v.nt
JOIN public.units u ON u.code = v.unit
CROSS JOIN public.products p
CROSS JOIN public.relationship_types rt
WHERE p.internal_code = 'FATEEN_MILK_TEST' AND rt.code = 'MEASURED_VALUE'
  AND NOT EXISTS (SELECT 1 FROM public.product_nutrition_values x WHERE x.product_id = p.id AND x.nutrition_type_id = nt.id);
COMMIT;
