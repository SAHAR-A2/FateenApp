#!/usr/bin/env python3
"""Read-only data-quality audit of FateenDB product data.

Usage (from the backend root):
    python scripts/db_audit.py [--database-url URL] [--json] [--samples N] [--strict]

Runs inside a READ ONLY transaction: it cannot change anything. Each check
reports a count and sample rows. Findings are review work, not deletions:
a product stays in the database and is fixed from a better source.

Checks:
  invalid_gtin_check_digit   active barcodes a retail scanner would reject
  barcode_on_many_products   one active barcode linked to several products
  impossible_nutrition       per-100 g/ml values that cannot be physical
                             (>100 g of a nutrient, >900 kcal, >3800 kJ)
  all_zero_nutrition         products whose every nutrition value is 0,
                             usually "missing" stored as 0
  product_without_barcode    live products no scan can ever reach
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

import psycopg
from psycopg.rows import dict_row

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from app.core.gtin import has_valid_check_digit  # noqa: E402

_ACTIVE_PB = """
    pb.deleted_at IS NULL AND b.deleted_at IS NULL
    AND (pb.effective_from IS NULL OR pb.effective_from <= NOW())
    AND (pb.effective_to IS NULL OR pb.effective_to > NOW())
"""

_ACTIVE_PNV = """
    pnv.deleted_at IS NULL
    AND (pnv.effective_from IS NULL OR pnv.effective_from <= NOW())
    AND (pnv.effective_to IS NULL OR pnv.effective_to > NOW())
"""


def check_invalid_gtin(conn) -> list[dict]:
    rows = conn.execute(
        f"""
        SELECT DISTINCT b.barcode, p.internal_code
        FROM public.product_barcodes pb
        JOIN public.barcodes b ON b.id = pb.barcode_id
        JOIN public.products p ON p.id = pb.product_id AND p.deleted_at IS NULL
        WHERE {_ACTIVE_PB}
        ORDER BY b.barcode
        """
    ).fetchall()
    return [dict(r) for r in rows if not has_valid_check_digit(r["barcode"])]


def check_barcode_on_many_products(conn) -> list[dict]:
    return conn.execute(
        f"""
        SELECT b.barcode, array_agg(DISTINCT p.internal_code::text ORDER BY p.internal_code::text) AS products
        FROM public.product_barcodes pb
        JOIN public.barcodes b ON b.id = pb.barcode_id
        JOIN public.products p ON p.id = pb.product_id AND p.deleted_at IS NULL
        WHERE {_ACTIVE_PB}
        GROUP BY b.barcode
        HAVING COUNT(DISTINCT p.id) > 1
        ORDER BY b.barcode
        """
    ).fetchall()


def check_impossible_nutrition(conn) -> list[dict]:
    # Only values stated per 100 g/ml can be bounded; per-serving and
    # unknown-basis values are skipped rather than guessed.
    return conn.execute(
        f"""
        SELECT p.internal_code, nt.code AS nutrition_type, pnv.amount_value,
               u.code AS unit, mb.code AS basis
        FROM public.product_nutrition_values pnv
        JOIN public.products p ON p.id = pnv.product_id AND p.deleted_at IS NULL
        JOIN public.nutrition_types nt ON nt.id = pnv.nutrition_type_id
        JOIN public.units u ON u.id = pnv.unit_id
        JOIN public.measurement_bases mb ON mb.id = pnv.measurement_basis_id
        WHERE {_ACTIVE_PNV}
          AND upper(mb.code) IN ('PER_100G', 'PER_100ML')
          AND (
               (upper(u.code) = 'G'    AND pnv.amount_value > 100)
            OR (upper(u.code) = 'MG'   AND pnv.amount_value > 100000)
            OR (upper(u.code) = 'KCAL' AND pnv.amount_value > 900)
            OR (upper(u.code) = 'KJ'   AND pnv.amount_value > 3800)
          )
        ORDER BY p.internal_code, nt.code
        """
    ).fetchall()


def check_all_zero_nutrition(conn) -> list[dict]:
    return conn.execute(
        f"""
        SELECT p.internal_code, COUNT(*) AS values
        FROM public.product_nutrition_values pnv
        JOIN public.products p ON p.id = pnv.product_id AND p.deleted_at IS NULL
        WHERE {_ACTIVE_PNV}
        GROUP BY p.internal_code
        HAVING COUNT(*) >= 3 AND bool_and(pnv.amount_value = 0)
        ORDER BY p.internal_code
        """
    ).fetchall()


def check_product_without_barcode(conn) -> list[dict]:
    return conn.execute(
        f"""
        SELECT p.internal_code, p.name
        FROM public.products p
        WHERE p.deleted_at IS NULL
          AND NOT EXISTS (
              SELECT 1 FROM public.product_barcodes pb
              JOIN public.barcodes b ON b.id = pb.barcode_id
              WHERE pb.product_id = p.id AND {_ACTIVE_PB}
          )
        ORDER BY p.internal_code
        """
    ).fetchall()


CHECKS = {
    "invalid_gtin_check_digit": check_invalid_gtin,
    "barcode_on_many_products": check_barcode_on_many_products,
    "impossible_nutrition": check_impossible_nutrition,
    "all_zero_nutrition": check_all_zero_nutrition,
    "product_without_barcode": check_product_without_barcode,
}


def run_audit(conn) -> dict[str, list[dict]]:
    return {name: [dict(r) for r in check(conn)] for name, check in CHECKS.items()}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--database-url")
    parser.add_argument("--json", action="store_true", help="print full JSON results")
    parser.add_argument("--samples", type=int, default=5)
    parser.add_argument("--strict", action="store_true", help="exit 1 when any check has findings")
    args = parser.parse_args(argv)

    url = args.database_url or os.environ.get("DATABASE_URL")
    if not url:
        raise SystemExit("No database URL: pass --database-url or set DATABASE_URL")

    with psycopg.connect(url, row_factory=dict_row) as conn:
        conn.execute("SET TRANSACTION READ ONLY")
        results = run_audit(conn)
        conn.rollback()

    if args.json:
        print(json.dumps(results, ensure_ascii=False, indent=2, default=str))
    else:
        for name, rows in results.items():
            print(f"{name}: {len(rows)}")
            for row in rows[: args.samples]:
                print("   ", json.dumps(row, ensure_ascii=False, default=str))
    return 1 if args.strict and any(results.values()) else 0


if __name__ == "__main__":
    sys.exit(main())
