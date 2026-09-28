"""Verify app.services.allergen_mapping against the real FateenDB.

Checks that every internal_code a tag maps to exists in public.allergens
and prints its real name for a human to compare against the intended
allergen. At runtime a mapping with a missing code resolves as UNKNOWN.

Run this against your local/dev database (with DATABASE_URL configured as
usual) before flipping any 'verified' flag to True in allergen_mapping.py:

    python scripts/verify_allergen_mapping.py
"""
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.db.connection import get_connection  # noqa: E402
from app.services.allergen_mapping import all_mappings  # noqa: E402


def main() -> int:
    mappings = all_mappings()
    missing = 0

    with get_connection() as conn:
        for tag, mapping in sorted(mappings.items()):
            for code in mapping.internal_codes:
                row = conn.execute(
                    """
                    SELECT internal_code, name
                    FROM public.allergens
                    WHERE internal_code = %s
                      AND deleted_at IS NULL
                    """,
                    (code,),
                ).fetchone()

                if row is None:
                    missing += 1
                    found = "MISSING"
                    db_name = "-"
                else:
                    found = "FOUND"
                    db_name = row["name"]

                flag = "verified=True " if mapping.verified else "verified=False"
                print(
                    f"{tag:42s} -> {code:16s} "
                    f"[{found:7s}] ({flag}) db_name={db_name}"
                )

    print()
    if missing:
        print(
            f"{missing} mapped internal_code(s) do not exist in public.allergens. "
            "Do not mark those entries verified=True until fixed."
        )
        return 1

    print("All mapped internal_code values exist. Review db_name against the "
          "intended allergen for each row before setting verified=True.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
