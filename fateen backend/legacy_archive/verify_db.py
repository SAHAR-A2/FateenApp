"""Database verification utility — an alternative to `psql`, since it's not
in your PATH but psycopg already is (confirmed by your pip output).

Usage (from the fateen-backend root, with your venv active or via the
venv's python.exe directly):

    .\\.venv\\Scripts\\python.exe verify_db.py codes        # dump the unconfirmed lookup tables
    .\\.venv\\Scripts\\python.exe verify_db.py milk-test     # query FATEEN_MILK_TEST nutrition rows
    .\\.venv\\Scripts\\python.exe verify_db.py milk-count    # count nutrition rows (duplicate check)
"""
from __future__ import annotations

import sys

from app.db.connection import get_connection


def dump_codes() -> None:
    queries = [
        ("source_types", "SELECT code, name FROM public.source_types ORDER BY display_order"),
        ("data_sources", "SELECT id, code, name FROM public.data_sources"),
        ("verification_statuses", "SELECT code, name FROM public.verification_statuses ORDER BY display_order"),
        ("image_types", "SELECT code, name FROM public.image_types ORDER BY display_order"),
    ]
    with get_connection() as conn:
        for label, sql in queries:
            print(f"\n=== {label} ===")
            rows = conn.execute(sql).fetchall()
            if not rows:
                print("  (no rows)")
            for row in rows:
                print(f"  {dict(row)}")


def milk_test() -> None:
    sql = """
        SELECT nt.code AS nutrition_type, pnv.amount_value, u.code AS unit, mb.code AS measurement_basis
        FROM public.product_nutrition_values pnv
        JOIN public.products p ON p.id = pnv.product_id
        JOIN public.nutrition_types nt ON nt.id = pnv.nutrition_type_id
        JOIN public.units u ON u.id = pnv.unit_id
        JOIN public.measurement_bases mb ON mb.id = pnv.measurement_basis_id
        WHERE p.internal_code = 'FATEEN_MILK_TEST' AND pnv.deleted_at IS NULL
        ORDER BY nt.code
    """
    with get_connection() as conn:
        rows = conn.execute(sql).fetchall()
        if not rows:
            print("No rows found for FATEEN_MILK_TEST — has the agent run against it yet?")
            return
        for row in rows:
            print(f"  {row['nutrition_type']:16} {row['amount_value']:>8} {row['unit']:6} basis={row['measurement_basis']}")


def milk_count() -> None:
    sql = """
        SELECT count(*) AS n
        FROM public.product_nutrition_values pnv
        JOIN public.products p ON p.id = pnv.product_id
        WHERE p.internal_code = 'FATEEN_MILK_TEST' AND pnv.deleted_at IS NULL
    """
    with get_connection() as conn:
        row = conn.execute(sql).fetchone()
        print(f"Nutrition row count for FATEEN_MILK_TEST: {row['n']} (expected: 9, never more even after re-running the agent)")


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else "codes"
    if command == "codes":
        dump_codes()
    elif command == "milk-test":
        milk_test()
    elif command == "milk-count":
        milk_count()
    else:
        print(f"Unknown command: {command!r}. Use: codes | milk-test | milk-count")
        sys.exit(1)
