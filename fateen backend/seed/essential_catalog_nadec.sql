-- Idempotent catalog-only seed based on products listed on NADEC's official
-- website. No barcodes, ingredients, allergens, or nutrition facts are
-- invented; the descriptions explicitly mark those fields as unverified.
WITH catalog(internal_code, name, category_code, source_url) AS (
    VALUES
      ('FATEEN_SEED_NADEC_DAIRY_001', 'Nadec Full Fat Milk 1L | حليب نادك كامل الدسم 1 لتر', 'DAIRY', 'https://www.nadec.com/en'),
      ('FATEEN_SEED_NADEC_DAIRY_002', 'Nadec Laban Kefir 225ml | لبن نادك كفير 225 مل', 'DAIRY', 'https://www.nadec.com/en'),
      ('FATEEN_SEED_NADEC_DAIRY_003', 'Nadec Cooking Cream 1L | كريمة طبخ نادك 1 لتر', 'DAIRY', 'https://www.nadec.com/en'),
      ('FATEEN_SEED_NADEC_DAIRY_004', 'Nadec High Protein Vanilla Milk Drink 350ml | مشروب حليب نادك عالي البروتين بالفانيلا 350 مل', 'DAIRY', 'https://www.nadec.com/en'),
      ('FATEEN_SEED_NADEC_DRINK_001', 'Nadec Pineapple with Mixed Fruit Nectar 1.3L | عصير نادك أناناس مع فواكه مشكلة 1.3 لتر', 'BEVERAGES', 'https://www.nadec.com/en/juice'),
      ('FATEEN_SEED_NADEC_DRINK_002', 'Nadec Pomegranate with Mixed Fruit Nectar 180ml | عصير نادك رمان مع فواكه مشكلة 180 مل', 'BEVERAGES', 'https://www.nadec.com/en/juice'),
      ('FATEEN_SEED_NADEC_DRINK_003', 'Nadec Strawberry Mojito Juice 180ml | عصير نادك فراولة موهيتو 180 مل', 'BEVERAGES', 'https://www.nadec.com/en/juice')
)
INSERT INTO public.products (
    internal_code, name, description, product_category_id, status_id,
    confidence_level, version_number
)
SELECT
    c.internal_code,
    c.name,
    'Listed in the manufacturer catalog (' || c.source_url || '). Exact barcode and package-label ingredients/allergens/nutrition have not been verified; compatibility must remain unknown until those data are added.',
    pc.id,
    1,
    0.5,
    1
FROM catalog c
JOIN public.product_categories pc ON pc.code = c.category_code AND pc.deleted_at IS NULL
ON CONFLICT DO NOTHING
RETURNING internal_code;
