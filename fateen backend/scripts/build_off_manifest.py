#!/usr/bin/env python3
"""Build a load_catalog.py manifest from Open Food Facts product records.

Usage (from the backend root):
    python scripts/build_off_manifest.py RECORDS_DIR --translations AR_NAMES.json \\
        --out manifest_off.json [--rejected rejected_off.json] [--images-cache DIR]

RECORDS_DIR holds one /api/v2/product/{code} JSON response per file.
--categories CATEGORIES.json optionally maps barcode -> product_categories.code
for products reviewed by hand; it wins over the automatic classification.

AR_NAMES.json maps barcode -> Arabic name for products whose record has no
Arabic name; those names are loaded as pending_review translations. A null
value marks a name reviewed as meaningless: the product is rejected.

A record becomes an entry only when all of these hold, otherwise it is
listed in the rejected file with the reasons:
  * the barcode is a valid GTIN and the record is tagged as sold in Saudi Arabia,
    and it is not a UPC 0628/0629 code (North American products that OFF
    tagged as Saudi because the digits look like the Saudi prefix 628)
  * it has a name, a front photo that downloads, and no OFF data-quality error
  * per-100 g/ml values for energy, fat, saturated fat, carbohydrate, sugars,
    protein and salt, all physically possible and consistent (saturated fat
    <= fat, sugars <= carbohydrate, energy within 30 % of 4/4/9 kcal/g)
  * an Arabic name, from the record or from AR_NAMES.json
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import time
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
from app.catalog.allergen_detection import detect, from_off_tags, merge  # noqa: E402
from app.core.gtin import has_valid_check_digit  # noqa: E402

_AR = re.compile(r"[؀-ۿ]")
_LATIN = re.compile(r"[A-Za-z]")

# First match wins, in this order. Tags are OFF category tags anywhere in the
# product's category hierarchy.
CATEGORY_TAGS = [
    ("BABY_FOOD", {"en:baby-foods", "en:baby-milks", "en:infant-formulas"}),
    ("DAIRY", {"en:dairies", "en:milks", "en:yogurts", "en:cheeses", "en:dairy-drinks", "en:fermented-milk-products",
               "en:creams", "en:butters", "en:labneh"}),
    ("BEVERAGES", {"en:beverages", "en:waters", "en:juices", "en:fruit-juices", "en:sodas", "en:teas",
                   "en:coffees", "en:energy-drinks", "en:plant-based-beverages"}),
    ("CONFECTIONERY", {"en:chocolates", "en:candies", "en:confectioneries", "en:chewing-gum", "en:jams",
                       "en:honeys", "en:sweet-spreads", "en:desserts", "en:ice-creams"}),
    ("BAKERY", {"en:breads", "en:biscuits-and-cakes", "en:biscuits", "en:cakes", "en:pastries",
                "en:viennoiseries", "en:croissants", "en:wafers", "en:cookies"}),
    ("SNACKS", {"en:salty-snacks", "en:chips-and-fries", "en:crisps", "en:popcorn", "en:nuts",
                "en:appetizers", "en:snacks"}),
    ("CEREALS", {"en:breakfast-cereals", "en:cereals-and-their-products", "en:rices", "en:pastas",
                 "en:flours", "en:oat-flakes", "en:noodles"}),
    ("SAUCES", {"en:sauces", "en:condiments", "en:dips", "en:ketchup", "en:mayonnaises", "en:spreads",
                "en:hummus", "en:salad-dressings", "en:vinegars", "en:spices", "en:salts"}),
    ("MEAT", {"en:meats", "en:sausages", "en:poultries", "en:meat-based-products"}),
    ("SEAFOOD", {"en:seafood", "en:fishes", "en:tunas", "en:canned-fishes"}),
    ("FROZEN_FOOD", {"en:frozen-foods"}),
    ("CANNED_FOOD", {"en:canned-foods"}),
    ("FRUITS", {"en:fruits", "en:dried-fruits", "en:dates"}),
    ("VEGETABLES", {"en:vegetables", "en:legumes", "en:pulses", "en:olives"}),
]
NAME_KEYWORDS = [
    ("BABY_FOOD", r"\b(cerelac|infant|baby)\b|سيريلاك|أطفال"),
    ("DAIRY", r"\b(milk|laban|yog(h)?urt|yaourt|cheese|fromage|feta|mozzarella|halloumi|labneh|cream cheese|"
              r"ghee|butter|beurre|kiri|vache qui rit|lait|kashkaval|ricotta|parmesan)\b|حليب|لبن|زبادي|جبن|لبنة|قشطة|فيتا"),
    ("BEVERAGES", r"\b(juice|jus|water|eau|drink|nectar|soda|cola|pepsi|mirinda|tea|thé|coffee|café|nescafe|"
                  r"lemonade|mocktail|bitter lemon|ginger beer|smoothie|syrup)\b|عصير|ماء|مياه|مشروب|شاي|قهوة|نكتار"),
    ("CONFECTIONERY", r"\b(chocolate|chocolat|candy|candies|bonbon|sweets?|jam|confiture|jelly|honey|miel|"
                      r"gum|pop|lollipop|toffee|caramels?|fudge|marshmallow|wafer|milkybar|praline|halawa|"
                      r"cheesecake|pudding|ice cream|gummy|chewits|trolli)\b|شوكولات|حلوى|مربى|عسل|علكة|حلاوة|آيس كريم"),
    ("BAKERY", r"\b(bread|pain|cake|croissant|biscuits?|boscuits|cookies?|toast|bun|muffin|waffles?|donut|"
               r"digestive|maamoul|rusk|crackers?|pretzel|tortilla|pita|pick up|clubs)\b|خبز|كيك|كعك|بسكويت|توست|معمول|مقرمشات"),
    ("SNACKS", r"\b(chips|crisps|popcorn|nuts|peanuts|almonds?|cashew|pistachio|snacks?|puffs|bites|bars?|"
               r"seeds|kettle cooked|cheetos|doritos|lay'?s|pringles)\b|شيبس|فشار|مكسرات|فول سوداني|لوز|قطع"),
    ("CEREALS", r"\b(rice|riz|pasta|pâtes|spaghetti|penne|shells|macaroni|lasagne|flour|farine|oats|avoine|"
                r"cereals?|flakes|muesli|m[uü]sli|granola|noodles?|quinoa|lentils|beans|chia)\b|"
                r"أرز|رز|مكرونة|معكرونة|دقيق|شوفان|نودلز|عدس|اعواد حنطه"),
    ("SAUCES", r"\b(sauce|ketchup|mayonnaise|mayo|hummus|tahini|dressing|vinegar|paste|pesto|mustard|"
               r"spices?|pepper|curry|stock cubes?|broth|bouillon|salt|olive oil|oil|huile|olives?|pickles?|"
               r"harissa|barbecue|bbq|dumpling mix|sugar)\b|صلصة|كاتشب|مايونيز|حمص|طحينة|شطة|زيت|توابل|بهارات|خل"),
    ("SEAFOOD", r"\b(tuna|thon|sardines?|salmon|fish oil|fish)\b|تونة|سردين|سمك"),
    ("MEAT", r"\b(chicken|beef|lamb|meat|burger|nuggets|sausages?|mortadella)\b|دجاج|لحم|برغر"),
]

NUTRIENTS = [  # (OFF key, FateenDB type, unit, factor from OFF's grams)
    ("energy-kcal_100g", "ENERGY", "KCAL", 1),
    ("proteins_100g", "PROTEIN", "G", 1),
    ("carbohydrates_100g", "CARBOHYDRATE", "G", 1),
    ("sugars_100g", "SUGAR", "G", 1),
    ("fat_100g", "TOTAL_FAT", "G", 1),
    ("saturated-fat_100g", "SATURATED_FAT", "G", 1),
    ("trans-fat_100g", "TRANS_FAT", "G", 1),
    ("fiber_100g", "FIBER", "G", 1),
    ("salt_100g", "SALT", "G", 1),
    ("sodium_100g", "SODIUM", "MG", 1000),
]
REQUIRED = ["energy-kcal_100g", "proteins_100g", "carbohydrates_100g", "sugars_100g", "fat_100g",
            "saturated-fat_100g", "salt_100g"]


def _num(value):
    try:
        v = float(value)
    except (TypeError, ValueError):
        return None
    return v if v == v else None  # NaN


def energy_kcal(n: dict):
    kcal = _num(n.get("energy-kcal_100g"))
    if kcal is None and _num(n.get("energy-kj_100g")) is not None:
        kcal = round(_num(n["energy-kj_100g"]) / 4.184, 1)
    return kcal


def nutrition_problems(n: dict) -> list[str]:
    values = {k: _num(n.get(k)) for k in REQUIRED}
    values["energy-kcal_100g"] = energy_kcal(n)
    missing = [k for k, v in values.items() if v is None]
    if missing:
        return [f"missing {', '.join(missing)}"]
    problems = []
    if any(v < 0 for v in values.values()):
        problems.append("negative value")
    if any(values[k] > 100 for k in REQUIRED if k != "energy-kcal_100g"):
        problems.append("more than 100 g per 100 g")
    if values["energy-kcal_100g"] > 900:
        problems.append("more than 900 kcal per 100 g")
    if all(v == 0 for v in values.values()):
        problems.append("all values 0")
    if values["saturated-fat_100g"] > values["fat_100g"] + 0.05:
        problems.append("saturated fat above total fat")
    if values["sugars_100g"] > values["carbohydrates_100g"] + 0.05:
        problems.append("sugars above carbohydrate")
    calc = 4 * values["proteins_100g"] + 4 * values["carbohydrates_100g"] + 9 * values["fat_100g"]
    if abs(calc - values["energy-kcal_100g"]) > max(30, 0.3 * max(values["energy-kcal_100g"], calc)):
        problems.append(f"energy {values['energy-kcal_100g']} kcal inconsistent with macros ({calc:.0f})")
    return problems


def is_drink(p: dict) -> bool:
    q = (p.get("quantity") or "").lower()
    if re.search(r"\d\s*(ml|cl|l|litre|liter|لتر|مل)\b", q):
        return True
    tags = set(p.get("categories_tags") or [])
    return bool(tags & {"en:beverages", "en:waters", "en:juices", "en:milks", "en:dairy-drinks"}) \
        and not tags & {"en:beverage-preparations", "en:powdered-milks", "en:instant-beverages"}


def category(p: dict) -> str:
    tags = set(p.get("categories_hierarchy") or []) | set(p.get("categories_tags") or [])
    for code, wanted in CATEGORY_TAGS:
        if tags & wanted:
            return code
    name = " ".join(filter(None, [p.get("product_name_en"), p.get("product_name"), p.get("product_name_ar")]))
    for code, pattern in NAME_KEYWORDS:
        if re.search(pattern, name, re.I):
            return code
    return "OTHER"


def _with_brand(name: str | None, p: dict) -> str | None:
    """Prefix the first brand when the name does not mention it ("Shells" ->
    "Barilla Shells"), so a short name still identifies the product."""
    if not name:
        return name
    brands = p.get("brands") or ""
    brand = (brands[0] if isinstance(brands, list) and brands else str(brands)).split(",")[0].strip()
    if brand and brand.lower() not in name.lower() and len(brand) <= 30:
        return f"{brand} {name}"
    return name


def names(p: dict) -> tuple[str | None, str | None]:
    ar = next((v.strip() for v in (p.get("product_name_ar"), p.get("product_name"))
               if v and _AR.search(v)), None)
    en = next((v.strip() for v in (p.get("product_name_en"), p.get("product_name"))
               if v and not _AR.search(v) and _LATIN.search(v)), None)
    return ar, _with_brand(en, p)


def statements(p: dict) -> dict[str, str]:
    out = {}
    for key in ("ingredients_text_ar", "ingredients_text"):
        v = (p.get(key) or "").strip()
        if v and _AR.search(v):
            out["ar"] = v
            break
    lang_en = p.get("lang") == "en" or p.get("lc") == "en"
    for key, ok in (("ingredients_text_en", True), ("ingredients_text", lang_en)):
        v = (p.get(key) or "").strip()
        if ok and v and not _AR.search(v):
            out["en"] = v
            break
    return out


def fetch_image(url: str, cache: Path) -> dict | None:
    f = cache / hashlib.sha1(url.encode()).hexdigest()
    if not f.exists():
        for attempt in range(3):
            try:
                req = urllib.request.Request(url, headers={"User-Agent": "FateenApp/1.0 (catalog research)"})
                with urllib.request.urlopen(req, timeout=60) as r:
                    data, mime = r.read(), r.headers.get_content_type()
                if not mime.startswith("image/") or len(data) < 500:
                    return None
                f.write_bytes(data)
                f.with_suffix(".mime").write_text(mime)
                break
            except Exception:
                time.sleep(5 * (attempt + 1))
        else:
            return None
        time.sleep(0.2)
    data = f.read_bytes()
    mime_file = f.with_suffix(".mime")
    return {"url": url, "sha256": hashlib.sha256(data).hexdigest(),
            "mime": mime_file.read_text() if mime_file.exists() else "image/jpeg", "bytes": len(data)}


def build(records_dir: Path, translations: dict, cache: Path,
          categories: dict | None = None) -> tuple[list, list]:
    entries, rejected = [], []
    for f in sorted(records_dir.glob("*.json")):
        record = json.loads(f.read_bytes())
        p = record.get("product") or {}
        code = str(p.get("code") or record.get("code") or f.stem)
        problems = []
        if record.get("status") != 1:
            problems.append("not found")
        if not (code.isdigit() and len(code) in (8, 12, 13, 14) and has_valid_check_digit(code)):
            problems.append("barcode is not a valid GTIN")
        if "en:saudi-arabia" not in (p.get("countries_tags") or []):
            problems.append("not tagged as sold in Saudi Arabia")
        if len(code) == 13 and code[:4] in ("0628", "0629"):
            # UPC-A 628/629 (North America, mostly Canadian retail brands),
            # tagged as Saudi because it looks like the Saudi EAN prefix 628.
            problems.append("UPC 0628/0629 is North American, not a Saudi EAN")
        if p.get("data_quality_errors_tags"):
            problems.append("OFF data-quality errors: " + ", ".join(p["data_quality_errors_tags"][:3]))
        n = p.get("nutriments") or {}
        problems += nutrition_problems(n)
        name_ar, name_en = names(p)
        ar_status = "approved"
        if code in translations and translations[code] is None:
            problems.append("name reviewed as unclear")
        elif not name_ar and translations.get(code):
            name_ar, ar_status = translations[code].strip(), "pending_review"
        if not name_ar and not name_en:
            problems.append("no name")
        elif not name_ar:
            problems.append("no Arabic name")
        image = None
        if not problems:
            url = p.get("image_front_url")
            image = fetch_image(url, cache) if url else None
            if image is None:
                problems.append("no front photo")
        if problems:
            rejected.append({"barcode": code, "name": name_en or name_ar, "problems": problems})
            continue

        basis = "PER_100ML" if is_drink(p) else "PER_100G"
        nutrition = []
        for key, ntype, unit, factor in NUTRIENTS:
            v = energy_kcal(n) if key == "energy-kcal_100g" else _num(n.get(key))
            if v is not None:
                nutrition.append({"type": ntype, "amount": round(v * factor, 3), "unit": unit, "basis": basis})
        texts = statements(p)
        allergens = merge(
            from_off_tags(p.get("allergens_tags") or [], p.get("traces_tags") or []),
            *(detect(t) for t in texts.values()),
            # Text in other languages (often French) is not stored, but its
            # allergens are.
            detect(p.get("ingredients_text") or ""),
        )
        entries.append({
            "barcode": code,
            "name_ar": name_ar, "name_ar_status": ar_status,
            "name_en": name_en, "name_en_status": "approved",
            "category": (categories or {}).get(code) or category({**p, "product_name_en": name_en}),
            "image": image,
            "nutrition": nutrition,
            "ingredients": texts,
            "allergens": allergens,
            "source": "OPEN_FOOD_FACTS",
            "source_url": f"https://world.openfoodfacts.org/product/{code}",
            "confidence": 0.6,
        })
    return entries, rejected


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("records_dir")
    parser.add_argument("--translations", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--rejected", default="rejected_off.json")
    parser.add_argument("--images-cache", default=".image_cache")
    parser.add_argument("--categories", help="barcode -> category code, reviewed by hand")
    args = parser.parse_args(argv)
    cache = Path(args.images_cache)
    cache.mkdir(parents=True, exist_ok=True)
    translations = json.loads(Path(args.translations).read_text(encoding="utf-8"))
    categories = json.loads(Path(args.categories).read_text(encoding="utf-8")) if args.categories else None
    entries, rejected = build(Path(args.records_dir), translations, cache, categories)
    Path(args.out).write_text(json.dumps(entries, ensure_ascii=False, indent=1), encoding="utf-8")
    Path(args.rejected).write_text(json.dumps(rejected, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"entries: {len(entries)}  rejected: {len(rejected)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
