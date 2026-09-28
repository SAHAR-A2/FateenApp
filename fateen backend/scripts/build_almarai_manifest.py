#!/usr/bin/env python3
"""Build a load_catalog.py manifest from almarai.com product pages.

Usage (from the backend root):
    python scripts/build_almarai_manifest.py PAGES_DIR --off-records OFF_DIR \\
        --out manifest_almarai.json [--unmatched unmatched_almarai.json] [--images-cache DIR]

PAGES_DIR holds the crawled pages: each file starts with the page URL on its
first line, then the HTML. The English and Arabic pages of one product share
the path after /en/ or /ar/.

almarai.com is the manufacturer's own site, so its Arabic and English names,
description, photo and nutrition are loaded as approved. It publishes no
barcode and no ingredient list, so:

  * The barcode comes from an Open Food Facts record of the same brand
    family, with a Saudi EAN (628...), whose name matches the page name and
    whose stated quantity is one of the sizes the page lists. A page is one
    product in several sizes, each with its own barcode, so it may receive
    several barcodes (the size is then added to the name); a record that
    fits two pages gets none. Products without a barcode are listed in the
    unmatched file and not loaded: a wrong barcode is worse than none.
  * Ingredients and allergens come from that record when it has them.
  * Nutrition is stated per serving. It is converted to per 100 g/ml only
    when the serving size is stated in g or ml, and kept only when it passes
    the same checks as the OFF builder.
"""

from __future__ import annotations

import argparse
import html
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
sys.path.insert(0, str(HERE))
from build_off_manifest import fetch_image, statements  # noqa: E402
from app.catalog.allergen_detection import detect, from_off_tags, is_plausible_statement, merge  # noqa: E402
from app.core.gtin import has_valid_check_digit  # noqa: E402

BRAND_FAMILY = {  # page brand slug -> words that identify it in an OFF brand/name
    "almarai": ("almarai", "al marai", "المراعي"),
    "lusine": ("l'usine", "lusine", "l’usine", "لوزين"),
    "alyoum": ("alyoum", "al youm", "اليوم"),
    "seven-days": ("7days", "7 days", "seven days", "سفن دايز"),
    "nura": ("nura", "نورا"),
    "bashayer": ("bashayer", "بشاير"),
    "evolac": ("evolac", "إيفولاك"),
    "surenutri": ("surenutri",),
    "almira": ("almira", "الميرا"),
    "seama": ("seama",),
    "farms-select": ("farms select", "فارمز سلكت"),
    "suregrow": ("suregrow",),
    "ice-leaf": ("ice leaf", "آيس ليف"),
}
# The site's own sections (second path segment) -> product_categories.code,
# with the few products that sit in a broader section named explicitly.
SITE_SECTIONS = {
    "bakery": "BAKERY", "beverages": "BEVERAGES", "cheeses-and-foods": "DAIRY", "dates": "FRUITS",
    "dips": "SAUCES", "frozen": "FROZEN_FOOD", "ice-cream": "CONFECTIONERY",
    "infant-medical-nutrition": "BABY_FOOD", "juices": "BEVERAGES", "liquid-dairy": "DAIRY",
    "poultry": "MEAT", "seafood": "SEAFOOD", "yoghurts": "DAIRY",
}
SUBSECTIONS = {"olive-oil": "SAUCES"}
_STOP = {"almarai", "al", "marai", "lusine", "l", "usine", "alyoum", "youm", "7days", "days", "seven",
         "nura", "the", "with", "and", "of", "fresh", "new", "pack", "ml", "g", "l", "kg", "x"}


def _text(raw: str) -> str:
    body = raw[raw.find("<body"):]
    body = re.sub(r"<script.*?</script>|<style.*?</style>", "", body, flags=re.S)
    # The site separates labels from values with non-breaking spaces.
    text = html.unescape(re.sub(r"<[^>]+>", "|", body)).replace("\xa0", " ")
    return re.sub(r"(\|\s*)+", "|", text)


def _num(s: str | None):
    try:
        return float(s.replace(",", "."))
    except (AttributeError, ValueError):
        return None


def parse_page(url: str, raw: str) -> dict | None:
    """The product fields of one page, or None for a listing page."""
    t = _text(raw)
    en = "/en/" in url
    desc_label, size_label = ("Description", "Size") if en else ("وصف", "الحجم")
    m = re.search(r"\|([^|]+?) ?\|" + desc_label + r"\|([^|]*)\|", t)
    if not m or f"|{size_label}|" not in t:
        return None
    page = {"url": url, "name": m.group(1).strip(), "description": m.group(2).strip()}
    sizes = re.findall(r"\|([\d.]+) +\|(g|G|ML|ml|Ml|L|l|KG|kg|غم|مل|لتر|كغم)(?=\|)", t)
    page["sizes"] = sorted({(float(v), u.lower()) for v, u in sizes})
    imgs = [i for i in re.findall(r'https://almmedia\.almarai\.com/Gallery/[^"\s)]+', raw)
            if re.search(r"\.(png|webp|jpg|jpeg)$", i, re.I) and "_sys" not in i]
    page["image"] = imgs[0] if imgs else None
    if en:
        serving = re.search(r"\|Serving Size\|= \|([\d.]+)\s*(g|ml)\|", t, re.I)
        page["serving"] = (float(serving.group(1)), serving.group(2).lower()) if serving else None
        kcal = re.search(r"\|Calories\|= \|([\d.]+)\|", t)
        page["per_serving"] = {
            "ENERGY": _num(kcal.group(1)) if kcal else None,
            **{key: _num((re.search(rf"\|{label} ([\d.]+)\s*{unit}\|", t) or [None, None])[1])
               for key, label, unit in (
                   ("TOTAL_FAT", "Total Fat", "g"), ("SATURATED_FAT", "Saturated Fat", "g"),
                   ("TRANS_FAT", "Trans Fat", "g"), ("SODIUM", "Sodium", "mg"),
                   ("CARBOHYDRATE", "Total Carbs", "g"), ("FIBER", "Dietary Fiber", "g"),
                   ("SUGAR", "Total Sugars", "g"), ("PROTEIN", "Protein", "g"))},
        }
    return page


def nutrition(page: dict) -> tuple[list[dict], str | None]:
    """Per-100 g/ml values, or ([], reason)."""
    if not page.get("serving"):
        return [], "serving size not stated in g or ml"
    amount, unit = page["serving"]
    if amount <= 0:
        return [], "serving size 0"
    factor = 100 / amount
    basis = "PER_100ML" if unit == "ml" else "PER_100G"
    v = {k: (x * factor if x is not None else None) for k, x in page["per_serving"].items()}
    needed = ("TOTAL_FAT", "SATURATED_FAT", "CARBOHYDRATE", "SUGAR", "PROTEIN", "SODIUM")
    if any(v[k] is None for k in needed):
        return [], "incomplete nutrition table"
    if any(v[k] > 100 for k in needed if k != "SODIUM") or v["SODIUM"] > 40000:
        return [], "impossible value per 100 g/ml"
    if v["SATURATED_FAT"] > v["TOTAL_FAT"] + 0.05 or v["SUGAR"] > v["CARBOHYDRATE"] + 0.05:
        return [], "saturated fat or sugar above its total"
    if v["ENERGY"] is not None:
        calc = 4 * v["PROTEIN"] + 4 * v["CARBOHYDRATE"] + 9 * v["TOTAL_FAT"]
        if abs(calc - v["ENERGY"]) > max(30, 0.3 * max(v["ENERGY"], calc)):
            return [], "energy inconsistent with macros"
    units = {"ENERGY": "KCAL", "SODIUM": "MG"}
    return [{"type": k, "amount": round(x, 3), "unit": units.get(k, "G"), "basis": basis}
            for k, x in v.items() if x is not None], None


_AR_STOP = {"المراعي", "مراعي", "لوزين", "اليوم", "طازج", "طازجة", "جديد", "من", "مع", "و", "في"}


def _tokens(s: str) -> set[str]:
    s = re.sub(r"[’'`]", "", (s or "").lower())
    latin = {w for w in re.findall(r"[a-z]+|\d+", s) if w not in _STOP}
    arabic = set()
    for w in re.findall(r"[\u0621-\u064A]+", s):
        w = w[2:] if w.startswith("ال") and len(w) > 3 else w
        w = w[:-1] + "ة" if w.endswith("ه") else w  # لبنه = لبنة
        if w not in _AR_STOP and len(w) > 1:
            arabic.add(w)
    return latin | arabic


_UNITS = {"ml": "ml", "l": "l", "ltr": "l", "g": "g", "gm": "g", "gr": "g", "grams": "g", "kg": "kg",
          "مل": "ml", "ملل": "ml", "لتر": "l", "جرام": "g", "غرام": "g", "غم": "g", "جم": "g", "غ": "g",
          "كجم": "kg", "كغ": "kg", "كيلو": "kg", "كيلوجرام": "kg"}
_QTY = re.compile(r"([\d.,٠-٩]+)\s*(" + "|".join(sorted(map(re.escape, _UNITS), key=len, reverse=True)) + r")(?![a-z])", re.I)


def _qty(s: str | None) -> tuple[float, str] | None:
    text = (s or "").lower().translate(str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789"))
    m = _QTY.search(text)
    if not m:
        return None
    value, unit = _num(m.group(1)), _UNITS[m.group(2)]
    if value is None:
        return None
    return (value * 1000, "ml") if unit == "l" else (value * 1000, "g") if unit == "kg" else (value, unit)


def _norm_sizes(sizes) -> set[tuple[float, str]]:
    out = set()
    for value, unit in sizes:
        unit = {"غم": "g", "مل": "ml", "لتر": "l", "كغم": "kg"}.get(unit, unit)
        out.add((value * 1000, "ml") if unit == "l" else (value * 1000, "g") if unit == "kg" else (value, unit))
    return out


# Words a record may leave out of the page name without changing what the
# product is. Flavours, fat levels, "salted" and the like are deliberately
# absent: "Mini croissant" must not become "Chocolate Mini Croissant".
_BENIGN_EXTRA = {"juice", "drink", "nectar", "fresh", "flavored", "flavoured", "natural", "pure",
                 "sliced", "bread", "ice", "cream", "bar", "cake", "enrobed", "mixed", "fruit", "dessert",
                 "extra", "virgin", "sandwich",
                 "عصير", "مشروب", "طازج", "طازجة", "نكتار", "شرائح"}


def _name_matches(record_tokens: set[str], page_tokens: set[str]) -> bool:
    """Same product name. The record may omit up to two descriptive words of
    the page name ("Gizzards chicken" for "Fresh Chicken Gizzards") or add
    one word."""
    if len(record_tokens) < 2 or not page_tokens:
        return False
    if record_tokens <= page_tokens:
        extra = page_tokens - record_tokens
        return len(extra) <= 2 and extra <= _BENIGN_EXTRA
    if page_tokens <= record_tokens:
        return len(record_tokens - page_tokens) <= 1
    return False


def match_barcodes(products: list[dict], off: list[dict]) -> dict[str, tuple[str, tuple[float, str] | None]]:
    """barcode -> (page path, size or None) for records that match exactly one page.

    A page is one product in several sizes, and each size has its own
    barcode, so a page may receive several barcodes. Brand and name (English
    or Arabic) must agree. A record that states its quantity must match a
    size the page lists; one without a quantity is accepted only when its
    name fits a single page (per-100 g facts do not depend on the size). A
    record that fits two pages ("Natural Butter 400 g" for both salted and
    unsalted) gets no page at all.
    """
    pages = [(prod, _tokens(prod["en"]["name"]), _tokens(prod.get("ar", {}).get("name", "")),
              _norm_sizes(prod["en"]["sizes"])) for prod in products]
    matched = {}
    for rec in off:
        text = f"{rec.get('brands') or ''} {rec.get('product_name') or ''} {rec.get('product_name_ar') or ''}".lower()
        size = _qty(rec.get("quantity"))
        names = [rec.get("product_name_en") or rec.get("product_name"), rec.get("product_name_ar")]
        have = [{t for t in _tokens(n) if not t.isdigit()} for n in names if n]
        fits = [prod["path"] for prod, want_en, want_ar, sizes in pages
                if any(w in text for w in BRAND_FAMILY.get(prod["brand_slug"], ()))
                and (size is None or size in sizes)
                and any(_name_matches(h, want_en) or _name_matches(h, want_ar) for h in have)
                # A record whose other name shares nothing with the page
                # (English "Nestle", Arabic "حليب مكثف") contradicts itself.
                and all(h & (want_en | want_ar) for h in have if h)]
        if len(fits) == 1:
            matched[rec["code"]] = (fits[0], size)
    return matched


def _size_label(size: tuple[float, str], lang: str) -> str:
    value, unit = size
    if value >= 1000:
        value, unit = value / 1000, {"g": "kg", "ml": "l"}[unit]
    number = f"{value:g}"
    return f"{number} {unit}" if lang == "en" else f"{number} " + {"g": "غ", "kg": "كغ", "ml": "مل", "l": "لتر"}[unit]


def category(path: str) -> str:
    parts = path.split("/")
    for part in parts[2:]:
        if part in SUBSECTIONS:
            return SUBSECTIONS[part]
    return SITE_SECTIONS.get(parts[1] if len(parts) > 1 else "", "OTHER")


def build(pages_dir: Path, off_dir: Path, cache: Path) -> tuple[list, list]:
    pages: dict[str, dict] = {}
    for f in pages_dir.glob("*.html"):
        raw = f.read_text(encoding="utf-8", errors="replace")
        url, _, body = raw.partition("\n")
        m = re.match(r"https://www\.almarai\.com/(en|ar)/brands/(.+?)/?$", url.strip())
        if not m:
            continue
        page = parse_page(url.strip(), body)
        if page:
            pages.setdefault(m.group(2), {})[m.group(1)] = page

    products = [{"path": path, "brand_slug": path.split("/")[0], **langs}
                for path, langs in sorted(pages.items()) if "en" in langs and "ar" in langs]
    off = []
    for f in off_dir.glob("*.json"):
        p = json.loads(f.read_bytes()).get("product") or {}
        code = str(p.get("code") or "")
        if len(code) == 13 and code.startswith("628") and has_valid_check_digit(code):
            off.append(p)
    matched = match_barcodes(products, off)
    off_by_code = {p["code"]: p for p in off}
    by_path: dict[str, list[tuple[str, tuple[float, str]]]] = {}
    for code, (path, size) in matched.items():
        by_path.setdefault(path, []).append((code, size))

    entries, unmatched = [], []
    for prod in products:
        en, ar = prod["en"], prod["ar"]
        barcodes = sorted(by_path.get(prod["path"], []), key=lambda b: b[0])
        if not barcodes:
            unmatched.append({"path": prod["path"], "name_en": en["name"], "name_ar": ar["name"],
                              "sizes": en["sizes"], "problems": ["no barcode matched this page alone"]})
            continue
        image = fetch_image(en["image"], cache) if en.get("image") else None
        if not image:
            unmatched.append({"path": prod["path"], "name_en": en["name"], "name_ar": ar["name"],
                              "sizes": en["sizes"], "problems": ["no photo"]})
            continue
        values, why_not = nutrition(en)
        several = len(barcodes) > 1
        for barcode, size in barcodes:
            labelled = several and size is not None
            record = off_by_code.get(barcode, {})
            texts = statements(record)
            entries.append({
                "barcode": barcode,
                "name_ar": f"{ar['name']} {_size_label(size, 'ar')}" if labelled else ar["name"],
                "name_ar_status": "approved",
                "name_en": f"{en['name']} {_size_label(size, 'en')}" if labelled else en["name"],
                "name_en_status": "approved",
                "description_ar": ar["description"] or None, "description_en": en["description"] or None,
                "brand": prod["brand_slug"].replace("-", " ").title(),
                "company": "Almarai",
                "category": category(prod["path"]),
                "image": image,
                "nutrition": values,
                "nutrition_note": why_not,
                "ingredients": texts,
                "allergens": merge(from_off_tags(record.get("allergens_tags") or [], record.get("traces_tags") or []),
                                   *(detect(t) for t in texts.values()),
                                   detect(record.get("ingredients_text") or "")
                                   if is_plausible_statement(record.get("ingredients_text") or "") else {}),
                "source": "ALMARAI_WEBSITE",
                "source_url": en["url"],
                "confidence": 0.9,
            })
    return entries, unmatched


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("pages_dir")
    parser.add_argument("--off-records", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--unmatched", default="unmatched_almarai.json")
    parser.add_argument("--images-cache", default=".image_cache")
    args = parser.parse_args(argv)
    cache = Path(args.images_cache)
    cache.mkdir(parents=True, exist_ok=True)
    entries, unmatched = build(Path(args.pages_dir), Path(args.off_records), cache)
    Path(args.out).write_text(json.dumps(entries, ensure_ascii=False, indent=1), encoding="utf-8")
    Path(args.unmatched).write_text(json.dumps(unmatched, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"entries: {len(entries)}  unmatched: {len(unmatched)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
