-- =============================================================================
-- 0058: sodium values stored in grams under the unit MG
--
-- An older import saved Open Food Facts' sodium_100g (grams) with the unit
-- MG: Lay's Salt & Vinegar has "0.868 mg" sodium next to 2.17 g salt per
-- 100 g, so the product page showed almost no sodium. Salt is sodium x 2.5,
-- so a sodium value that equals the product's salt / 2.5 (within 5 %) on the
-- same basis is that salt in grams, not milligrams; multiply it by 1000.
-- Only such exact matches are changed, and a corrected row no longer
-- matches, so the migration is idempotent. The health check already judges
-- sodium by the worse of the stored value and salt / 2.5.
-- =============================================================================

BEGIN;

UPDATE public.product_nutrition_values sodium
SET amount_value = sodium.amount_value * 1000,
    version_number = sodium.version_number + 1
FROM public.nutrition_types st, public.units mg,
     public.product_nutrition_values salt, public.nutrition_types saltt, public.units g
WHERE st.id = sodium.nutrition_type_id AND st.code = 'SODIUM'
  AND mg.id = sodium.unit_id AND mg.code = 'MG'
  AND sodium.deleted_at IS NULL
  AND salt.product_id = sodium.product_id
  AND salt.measurement_basis_id IS NOT DISTINCT FROM sodium.measurement_basis_id
  AND salt.deleted_at IS NULL
  AND saltt.id = salt.nutrition_type_id AND saltt.code = 'SALT'
  AND g.id = salt.unit_id AND g.code = 'G'
  AND salt.amount_value > 0.05
  AND abs(sodium.amount_value * 2.5 - salt.amount_value) <= 0.05 * salt.amount_value;

COMMIT;
