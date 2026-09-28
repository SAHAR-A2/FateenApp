#!/usr/bin/env python3
"""Soft-delete products whose data cannot be trusted.

Usage (from the backend root):
    python scripts/cleanup_unreliable_products.py [--database-url URL]            # preview only
    python scripts/cleanup_unreliable_products.py --apply --expect N --database-url URL

The preview's URL defaults to CLOUD_DATABASE_URL, then DATABASE_URL. --apply
takes the URL only from --database-url, so an environment variable left
over from another task can never pick the database that gets written.

A product is selected when any of these holds (definitions shared with
scripts/db_audit.py):
  test_row              internal_code marks a test fixture (TEST_..., ..._TEST,
                        PRIV_TEST_..., test-...)
  invalid_gtin          every active barcode fails the GS1 check digit, so no
                        real package carries it
  all_zero_nutrition    three or more nutrition values, all 0: "missing" stored as 0
  impossible_nutrition  a per-100 g/ml value that cannot be physical
  no_barcode            no active barcode (only with --include-no-barcode)

A product that also has a valid barcode keeps it: for invalid_gtin only the
invalid barcode links are ended.

"Delete" means deleted_at = now(): every API query already hides such rows,
the history triggers record the change and it can be undone. Nothing is
erased. The preview writes the selected rows to a JSON backup, and --apply
refuses to run unless --expect equals the number the preview showed, so a
database that changed in between is not touched.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

import psycopg
from psycopg.rows import dict_row

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
from app.core.gtin import has_valid_check_digit  # noqa: E402

_ACTIVE_PB = """
    pb.deleted_at IS NULL AND b.deleted_at IS NULL
    AND (pb.effective_from IS NULL OR pb.effective_from <= NOW())
    AND (pb.effective_to IS NULL OR pb.effective_to > NOW())
"""
_TEST_CODE = r"(^test[_-]|_test$|^priv_test_|_test_)"


def _load_db_audit():
    import importlib.util

    spec = importlib.util.spec_from_file_location("db_audit", HERE / "db_audit.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules["db_audit"] = module
    spec.loader.exec_module(module)
    return module


def collect(conn, include_no_barcode: bool = False) -> list[dict]:
    """One entry per product to soft-delete, with every reason that applies,
    plus the invalid barcode links of products that also have a valid one."""
    audit = _load_db_audit()
    products = {
        str(r["id"]): {**r, "id": str(r["id"]), "reasons": []}
        for r in conn.execute(
            f"""
            SELECT p.id, p.internal_code::text AS internal_code, p.name,
                   COALESCE(array_agg(b.barcode::text ORDER BY b.barcode)
                            FILTER (WHERE b.id IS NOT NULL), '{{}}') AS barcodes
            FROM public.products p
            LEFT JOIN public.product_barcodes pb ON pb.product_id = p.id
            LEFT JOIN public.barcodes b ON b.id = pb.barcode_id AND {_ACTIVE_PB}
            WHERE p.deleted_at IS NULL
            GROUP BY p.id
            """
        ).fetchall()
    }
    by_code = {p["internal_code"]: p for p in products.values()}

    for p in products.values():
        if re.search(_TEST_CODE, p["internal_code"] or "", re.I):
            p["reasons"].append("test_row")
        if p["barcodes"] and not any(has_valid_check_digit(b) for b in p["barcodes"]):
            p["reasons"].append("invalid_gtin")
        if include_no_barcode and not p["barcodes"]:
            p["reasons"].append("no_barcode")
    for row in audit.check_all_zero_nutrition(conn):
        by_code[row["internal_code"]]["reasons"].append("all_zero_nutrition")
    for row in audit.check_impossible_nutrition(conn):
        reasons = by_code[row["internal_code"]]["reasons"]
        if "impossible_nutrition" not in reasons:
            reasons.append("impossible_nutrition")

    selected = [p for p in products.values() if p["reasons"]]
    for p in selected:
        p["invalid_barcodes"] = [b for b in p["barcodes"] if not has_valid_check_digit(b)]
    # Products kept because they also carry a valid barcode: end only the
    # invalid links.
    partial = [
        {"id": p["id"], "internal_code": p["internal_code"], "name": p["name"],
         "reasons": ["invalid_barcode_link"],
         "invalid_barcodes": [b for b in p["barcodes"] if not has_valid_check_digit(b)]}
        for p in products.values()
        if not p["reasons"] and any(not has_valid_check_digit(b) for b in p["barcodes"])
    ]
    return sorted(selected, key=lambda p: p["internal_code"]) + sorted(partial, key=lambda p: p["internal_code"])


def apply(conn, selection: list[dict]) -> tuple[int, int]:
    """Soft-delete inside the caller's transaction. Returns (products, links)."""
    product_ids = [p["id"] for p in selection if p["reasons"] != ["invalid_barcode_link"]]
    link_targets = [p for p in selection if p["reasons"] == ["invalid_barcode_link"]]
    products = conn.execute(
        "UPDATE public.products SET deleted_at = now() WHERE id = ANY(%s::uuid[]) AND deleted_at IS NULL",
        (product_ids,),
    ).rowcount
    links = 0
    for p in link_targets:
        links += conn.execute(
            """
            UPDATE public.product_barcodes pb SET deleted_at = now()
            FROM public.barcodes b
            WHERE b.id = pb.barcode_id AND pb.product_id = %s
              AND b.barcode = ANY(%s::text[]) AND pb.deleted_at IS NULL
            """,
            (p["id"], p["invalid_barcodes"]),
        ).rowcount
    if products != len(product_ids):
        raise RuntimeError(f"expected {len(product_ids)} products, updated {products}; rolled back")
    return products, links


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--database-url")
    parser.add_argument("--apply", action="store_true", help="soft-delete (default: preview only)")
    parser.add_argument("--expect", type=int, help="number of entries the preview showed (required with --apply)")
    parser.add_argument("--include-no-barcode", action="store_true")
    parser.add_argument("--backup", help="backup JSON path (default: cleanup_backup_<UTC time>.json)")
    args = parser.parse_args(argv)

    url = args.database_url or os.environ.get("CLOUD_DATABASE_URL") or os.environ.get("DATABASE_URL")
    if not url:
        raise SystemExit("No database URL: pass --database-url or set CLOUD_DATABASE_URL")
    if args.apply and args.expect is None:
        raise SystemExit("--apply needs --expect N, the number of entries the preview showed")
    if args.apply and not args.database_url:
        raise SystemExit("--apply needs an explicit --database-url")

    with psycopg.connect(url, row_factory=dict_row) as conn:
        print(f"Database: {conn.info.user}@{conn.info.host}/{conn.info.dbname}\n")
        if not args.apply:
            conn.execute("SET TRANSACTION READ ONLY")
        selection = collect(conn, args.include_no_barcode)

        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        backup = Path(args.backup or f"cleanup_backup_{stamp}.json")
        backup.write_text(json.dumps(selection, ensure_ascii=False, indent=2, default=str), encoding="utf-8")

        counts: dict[str, int] = {}
        for p in selection:
            for reason in p["reasons"]:
                counts[reason] = counts.get(reason, 0) + 1
            print(f"  {p['internal_code']:<34} {','.join(p['reasons']):<40} {' '.join(p['barcodes'] if 'barcodes' in p else p['invalid_barcodes'])}")
        print(f"\nEntries: {len(selection)}  by reason: {counts}")
        print(f"Backup of every selected row: {backup}")

        if not args.apply:
            conn.rollback()
            print(f"\nPreview only, nothing changed. To apply: --apply --expect {len(selection)}")
            return 0
        if args.expect != len(selection):
            conn.rollback()
            print(f"Refusing: preview had {args.expect} entries, now {len(selection)}. Nothing changed.")
            return 1
        products, links = apply(conn, selection)
        conn.commit()
    print(f"\nSoft-deleted {products} products and ended {links} invalid barcode links.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
