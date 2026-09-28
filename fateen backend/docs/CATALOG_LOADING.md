# Catalog loading

How products get into FateenDB, from which sources, and which checks they
pass on the way. Nothing here writes to a database except
`scripts/load_catalog.py --apply`.

## Sources

| Source | What it gives | What it lacks | Confidence |
|--------|---------------|---------------|-----------:|
| almarai.com (manufacturer) | Arabic and English names, description, photo, nutrition per serving | barcode, ingredient list | 0.9 |
| Open Food Facts (crowd-sourced) | barcode, photo, nutrition per 100 g/ml, often ingredients and allergen tags | Arabic names (93 % of Saudi records have none), sometimes wrong country tags | 0.6 |
| SFDA registered food products API | official registration data | needs a developer-portal key (`app/integrations/sfda_food_adapter.py`) | not used yet |

Measured on 2026-09-28: Open Food Facts lists 8,923 products as sold in
Saudi Arabia (search.openfoodfacts.org). 4,734 have a valid barcode, a name
and a photo; 897 of those also have complete, consistent nutrition. The
anonymous API refuses listing pages past the tenth, so the full list is read
from search.openfoodfacts.org and each candidate from `/api/v2/product/{code}`.

## Pipeline

```
sources ──> build_off_manifest.py ─┐
        └─> build_almarai_manifest.py ─┴─> manifest.json ──> load_catalog.py [--apply]
```

1. **Collect.** Download OFF records and crawl almarai.com (robots.txt allows
   it; one request per second per worker).
2. **Build** a manifest with the two builders. Every product that fails a
   gate is written to a rejected/unmatched file with its reasons.
3. **Translate.** A product whose source has no Arabic name gets a reviewed
   translation (`--translations`). It is stored as `pending_review`; the
   source-language name stays `approved`. A name reviewed as meaningless
   (null in the file) rejects the product.
4. **Preview** `python scripts/load_catalog.py manifest.json`. It runs every
   write in a transaction that is rolled back and reports, per barcode,
   created / completed / unchanged / rejected.
5. **Load** `python scripts/load_catalog.py manifest.json --apply --database-url URL`.

## Gates

A product is loaded only when:

- its barcode is a valid GTIN (check digit), is not a UPC `0628…`/`0629…`
  code (North American products that OFF tags as Saudi because the digits
  resemble the Saudi prefix 628) and, for almarai.com, comes from a
  one-to-one match with an OFF record of the same brand, name and size;
- it has an Arabic name (the base name, `products.name`) and a photo that
  downloads (its SHA-256 is stored);
- its nutrition, if any, is per 100 g or per 100 ml, complete (energy, fat,
  saturated fat, carbohydrate, sugars, protein, salt/sodium), physically
  possible, with saturated fat ≤ fat, sugars ≤ carbohydrate and energy
  within 30 % of 4/4/9 kcal per gram of protein/carbohydrate/fat;
- OFF reports no data-quality error for it.

## Allergens

`app/catalog/allergen_detection.py` finds the 14 EU major allergens in
Arabic, English and French ingredient text, conservatively. The loader
always stores what it finds in a statement together with the source's own
allergen tags, so the allergy check can treat an ingredient statement as
evidence: a product with a statement and no peanut row has been read and
contains no peanut word. A product with neither statement nor allergen rows
stays INSUFFICIENT_DATA for an allergic user.

## Existing products

A barcode already in FateenDB is only completed: a missing translation,
photo, category, ingredient statement, allergen or nutrition set is added.
Stored values are never changed.

## Prerequisites

Migrations 0055 (allergens, thresholds) and 0056 (image type, sources,
ingredient statements). On Cloud, apply them as described in
`MIGRATIONS_GOVERNANCE.md`.
