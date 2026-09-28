#!/usr/bin/env python3
"""Check, read-only, that the API's database account can serve the app.

Usage (from the backend root), with the connection string the server will
use (the least-privilege fateen_app role, not postgres):
    python scripts/check_runtime_access.py --database-url URL

It checks that every table the public API reads is visible to that role (a
missing grant fails loudly; a row-level-security policy that hides rows
fails silently, as "0 rows"), then runs the real search, details,
compatibility and alternatives code on catalog products. Nothing is written.
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

# Tables the public API reads (app/repositories, app/services,
# app/collector/health_conditions.py). Each must show rows to the role.
TABLES = (
    "products", "product_translations", "product_barcodes", "barcodes", "product_images", "images",
    "product_allergens", "allergens", "product_nutrition_values", "nutrition_types", "units",
    "measurement_bases", "product_ingredient_statements", "product_categories", "languages",
    "lifecycle_statuses", "relationship_types", "evidence_types", "data_sources", "health_conditions",
    "condition_nutrient_thresholds",
)
# Tables that may legitimately be empty.
MAY_BE_EMPTY = {"product_ingredients", "ingredients", "health_flags", "product_health_flags"}

SAUDIA_MILK = "6281039100914"   # whole milk; its source statement omits the milk
OREO_BAR = "7622201765231"      # 44 g sugar per 100 g
SALT_VINEGAR = "6281036113306"  # salty crisps


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--database-url", required=True)
    args = parser.parse_args(argv)
    os.environ["DATABASE_URL"] = args.database_url
    os.environ.setdefault("APP_ENV", "development")

    import psycopg
    from psycopg.rows import dict_row

    failures = []

    def check(label: str, ok: bool, detail: str = "") -> None:
        print(f"  {'PASS' if ok else 'FAIL'}  {label}" + (f"  ({detail})" if detail else ""))
        if not ok:
            failures.append(label)

    with psycopg.connect(args.database_url, row_factory=dict_row, autocommit=True) as conn:
        conn.execute("SET default_transaction_read_only = on")
        user = conn.execute("SELECT current_user AS u").fetchone()["u"]
        print(f"Database account: {user}")
        check("not a superuser account", user.split(".")[0] not in ("postgres", "fateen"), user)
        print("Tables:")
        for table in TABLES + tuple(sorted(MAY_BE_EMPTY)):
            try:
                row = conn.execute(f"SELECT EXISTS (SELECT 1 FROM public.{table}) AS has_rows").fetchone()
                visible = row["has_rows"] or table in MAY_BE_EMPTY
                check(table, visible, "" if row["has_rows"] else "0 rows visible to this account")
            except psycopg.Error as exc:
                check(table, False, str(exc).splitlines()[0])

    print("App behaviour on catalog products:")
    from app.schemas.compatibility import CompatibilityRequest
    from app.services.search_service import search_products_by_name
    from app.services.product_details_service import get_product_details_by_barcode
    from app.services.compatibility_service import evaluate_compatibility
    from app.services.alternatives_service import get_safe_alternatives

    def run(label, fn):
        try:
            return fn()
        except Exception as exc:  # report and carry on with the other checks
            check(label, False, f"{type(exc).__name__}: {str(exc).splitlines()[0] if str(exc) else ''}")
            return None

    for query in ("حليب", "milk"):
        found = run(f"search {query}", lambda: search_products_by_name(query))
        if found is not None:
            with_images = sum(1 for r in found.results if r.image_url)
            check(f"search {query}", found.count > 0 and with_images == found.count,
                  f"{found.count} results, {with_images} with a photo")

    details = run("details", lambda: get_product_details_by_barcode(SAUDIA_MILK))
    if details is not None:
        check("details: Arabic and English names", bool(details.get("name_ar") and details.get("name_en")),
              f"{details.get('name_ar')} / {details.get('name_en')}")

    milk_allergy = CompatibilityRequest(allergies=[{"tag": "en:milk", "severity": "شديد"}])
    diabetes = CompatibilityRequest(diseases=[{"name": "سكري"}])
    hypertension = CompatibilityRequest(diseases=[{"name": "ارتفاع الضغط"}])

    result = run("milk allergy on whole milk", lambda: evaluate_compatibility(SAUDIA_MILK, milk_allergy))
    if result is not None:
        check("milk allergy on whole milk is DANGER", result.status == "DANGER", result.status)
    result = run("diabetes on a chocolate bar", lambda: evaluate_compatibility(OREO_BAR, diabetes))
    if result is not None:
        check("diabetes on a chocolate bar is WARNING", result.status == "WARNING", result.status)
    result = run("high blood pressure on salty crisps", lambda: evaluate_compatibility(SALT_VINEGAR, hypertension))
    if result is not None:
        check("high blood pressure on salty crisps is WARNING", result.status == "WARNING", result.status)
    alternatives = run("alternatives", lambda: get_safe_alternatives(SALT_VINEGAR, hypertension))
    if alternatives is not None:
        names = [a.product.name for a in alternatives.alternatives]
        check("alternatives found, each with a photo",
              bool(names) and all(a.product.image_url for a in alternatives.alternatives),
              ", ".join(names[:3]))

    print("All checks passed." if not failures else f"{len(failures)} check(s) failed: {', '.join(failures)}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
