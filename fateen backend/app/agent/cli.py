import argparse
import json
import sys
from app.db.connection import close_pool
from app.agent.ingestion import ingest
from app.agent.models import (
    IngestionInput,
    IngestionIngredient,
    IngestionAllergen,
    IngestionNutrition,
)
from app.core.config import resolve_effective_dry_run


def main():
    parser = argparse.ArgumentParser(
        description="Fateen Agent Ingestion CLI"
    )
    parser.add_argument("--barcode", required=True, help="Product barcode")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        default=True,
        help="Dry run mode (default)",
    )
    parser.add_argument(
        "--write",
        action="store_true",
        help="Actually write to database",
    )
    parser.add_argument(
        "--data-file", help="JSON file with ingestion data"
    )
    parser.add_argument(
        "--verbose", "-v", action="store_true", help="Verbose output"
    )

    try:
        args = parser.parse_args()

        dry_run = resolve_effective_dry_run(not args.write)

        if args.data_file:
            with open(args.data_file) as f:
                data = json.load(f)
        else:
            data = {}

        input_data = IngestionInput(
            barcode=args.barcode,
            product_name=data.get("product_name"),
            product_description=data.get("product_description"),
            ingredients=[
                IngestionIngredient(**ing)
                for ing in data.get("ingredients", [])
            ],
            allergens=[
                IngestionAllergen(**al)
                for al in data.get("allergens", [])
            ],
            nutrition=[
                IngestionNutrition(**nut)
                for nut in data.get("nutrition", [])
            ],
            source=data.get("source", "manual"),
            confidence_level=data.get("confidence_level", 0.5),
        )

        mode = "DRY RUN" if dry_run else "WRITE MODE"
        print(mode)
        print(f"Barcode: {args.barcode}")
        print()

        result = ingest(input_data, dry_run=dry_run)

        if result.errors:
            print("ERRORS:")
            for err in result.errors:
                print(f"  - {err}")
            return 1

        print(f"Product: {result.product_internal_code}")
        print(f"Changes: {len(result.changes)}")
        print()

        action_icons = {"create": "+", "update": "~", "no_change": "="}

        for change in result.changes:
            icon = action_icons.get(change.action, "?")
            name = change.details.get(
                "name", change.details.get("nutrition_type", "")
            )
            print(f"  [{icon}] {change.entity}: {name}")

            if change.action == "update":
                for k, v in change.details.items():
                    if k.startswith("old_") or k.startswith("new_"):
                        print(f"      {k}: {v}")

        if result.warnings:
            print()
            print("WARNINGS:")
            for w in result.warnings:
                print(f"  - {w}")

        print()

        if dry_run:
            print("No database changes performed.")
        else:
            print("Changes written to database.")

        return 0

    finally:
        close_pool()


if __name__ == "__main__":
    sys.exit(main())
