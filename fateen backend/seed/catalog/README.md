# Catalog manifest, 2026-09-28

`manifest_2026-09-28.json` is the input of `scripts/load_catalog.py`: 769
products (37 from almarai.com, 732 from Open Food Facts), each with a valid
barcode, an Arabic base name, an English name, a front photo and a category;
762 with nutrition per 100 g/ml, 174 with the printed ingredient list and
160 with allergens. How it was built and which gates it passed:
`docs/CATALOG_LOADING.md`.

Hand review, kept so the build can be repeated:

- `reviewed_ar_names.json`: Arabic names translated from the source name
  (loaded as `pending_review`); `null` marks a name rejected as unclear.
- `reviewed_names.json`: corrected source names and added English names.
- `reviewed_categories.json`: categories assigned by hand.

What was left out, with the reason for each product:

- `rejected_off.json`: Open Food Facts records that failed a gate.
- `unmatched_almarai.json`: almarai.com products without a barcode that
  matches them alone. Scanning them in a store would add them.

Licences: Open Food Facts data is under the Open Database Licence (ODbL) and
its photos under CC BY-SA; attribution is required. Names, descriptions and
photos from almarai.com belong to Almarai.
