#!/usr/bin/env python3
"""Merge catalog manifests into one, one entry per barcode.

Usage (from the backend root):
    python scripts/merge_manifests.py manifest_almarai.json manifest_off.json --out manifest.json

Manifests are listed in priority order (the manufacturer first). For a
barcode that appears in several, the first entry wins field by field; a
field it leaves empty (no nutrition, no ingredient statement, no allergens)
is taken from the next manifest that has it, and allergens are merged so
that nothing found by any source is dropped.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
from app.catalog.allergen_detection import merge as merge_allergens  # noqa: E402

_FILLABLE = ("nutrition", "ingredients", "description_ar", "description_en", "category", "image")


def merge(manifests: list[list[dict]]) -> list[dict]:
    by_barcode: dict[str, dict] = {}
    order: list[str] = []
    for manifest in manifests:
        for entry in manifest:
            code = str(entry["barcode"])
            if code not in by_barcode:
                by_barcode[code] = dict(entry)
                order.append(code)
                continue
            kept = by_barcode[code]
            for key in _FILLABLE:
                if not kept.get(key) and entry.get(key):
                    kept[key] = entry[key]
            if kept.get("category") == "OTHER" and entry.get("category") not in (None, "OTHER"):
                kept["category"] = entry["category"]
            kept["allergens"] = merge_allergens(kept.get("allergens") or {}, entry.get("allergens") or {})
    return [by_barcode[c] for c in order]


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("manifests", nargs="+")
    parser.add_argument("--out", required=True)
    args = parser.parse_args(argv)
    manifests = [json.loads(Path(p).read_text(encoding="utf-8")) for p in args.manifests]
    merged = merge(manifests)
    Path(args.out).write_text(json.dumps(merged, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"entries: {len(merged)} (from {sum(len(m) for m in manifests)})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
