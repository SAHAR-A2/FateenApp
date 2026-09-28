"""Find the 14 EU major allergens in an ingredient statement (ar / en / fr).

Used by the catalog loader next to the source's own allergen tags, because
automatic tagging often misses Arabic and French text: a wheat bread whose
statement says "دقيق القمح" must not reach a wheat-allergic user as SAFE.

The matching is deliberately conservative. A false alarm costs a warning; a
miss can cost a reaction. So "coconut", "nutmeg" and "gluten-free" are not
special-cased away: coconut and nutmeg are simply not in the word lists, and
a "gluten-free oats" statement still flags GLUTEN.

Text after "may contain" / "قد يحتوي" / "peut contenir" / "traces" is
reported as MAY_CONTAIN; everything else as CONTAINS.
"""
import re

# internal_code -> words. A Latin word matches whole, with an optional plural
# "s"/"es"; an Arabic word may carry the prefixes و ب ل ف and ال and the
# suffixes ة ه ات ي ية, so "والحليب" and "جبنة" match but "بيضاء" (white)
# does not match "بيض" (egg).
_TERMS: dict[str, tuple[str, ...]] = {
    "GLUTEN": ("gluten", "wheat", "barley", "rye", "oat", "spelt", "semolina", "durum", "malt extract",
               "barley malt", "malted", "couscous", "bulgur", "blé", "orge", "seigle", "avoine", "épeautre", "semoule",
               "جلوتين", "غلوتين", "قمح", "حنطة", "شعير", "شوفان", "جاودار", "سميد", "برغل", "مالت", "شعيرية"),
    "WHEAT": ("wheat", "spelt", "semolina", "durum", "couscous", "bulgur", "blé", "épeautre", "semoule",
              "قمح", "حنطة", "سميد", "برغل"),
    "MILK": ("milk", "lactose", "whey", "casein", "caseinate", "cream", "butter", "cheese", "yogurt",
             "yoghurt", "ghee", "curd", "lait", "lactosérum", "caséine", "crème", "beurre", "fromage",
             "حليب", "لبن", "لبنة", "مصل الحليب", "كازين", "قشدة", "قشطة", "زبدة", "زبده", "جبن", "جبنة",
             "زبادي", "سمن حيواني", "لاكتوز", "كريمة"),
    "EGG": ("egg", "albumen", "œuf", "oeuf", "ovalbumine", "بيض", "بيضة", "زلال"),
    "PEANUT": ("peanut", "groundnut", "arachide", "cacahuète", "فول سوداني", "فول السوداني", "زبدة الفول"),
    "TREE_NUTS": ("almond", "hazelnut", "walnut", "cashew", "pecan", "pistachio", "macadamia",
                  "brazil nut", "tree nut", "nut", "amande", "noisette", "noix", "pistache",
                  "لوز", "بندق", "جوز", "كاجو", "فستق", "بيكان", "مكاديميا", "مكسرات"),
    "SOY": ("soy", "soya", "soja", "صويا", "الصويا"),
    "SESAME": ("sesame", "tahini", "tahina", "sésame", "سمسم", "طحينة", "طحينية", "طحينه"),
    "FISH": ("fish", "anchovy", "anchovies", "tuna", "salmon", "sardine", "cod", "poisson", "thon", "saumon",
             "سمك", "أسماك", "اسماك", "تونة", "تونا", "سلمون", "سردين", "أنشوفة", "انشوفة"),
    "SHELLFISH": ("shrimp", "prawn", "crab", "lobster", "crustacean", "crevette", "crabe", "homard",
                  "روبيان", "جمبري", "ربيان", "سلطعون", "كابوريا", "قشريات", "استاكوزا"),
    "MOLLUSCS": ("mollusc", "mollusk", "squid", "octopus", "mussel", "oyster", "clam", "scallop",
                 "calamar", "moule", "huître", "حبار", "كاليماري", "أخطبوط", "اخطبوط", "بلح البحر",
                 "محار", "رخويات"),
    "CELERY": ("celery", "celeriac", "céleri", "كرفس"),
    "MUSTARD": ("mustard", "moutarde", "خردل", "مستردة", "مسطردة"),
    "LUPIN": ("lupin", "lupine", "ترمس"),
    "SULPHITES": ("sulphite", "sulfite", "sulphur dioxide", "sulfur dioxide", "metabisulphite",
                  "metabisulfite", "anhydride sulfureux", "كبريتيت", "ثاني أكسيد الكبريت",
                  "ميتابيسلفيت"),
}
# E220-E228 are sulphites.
_SULPHITE_E = re.compile(r"\bE\s?-?22[0-8]\b", re.I)

_MAY_CONTAIN = re.compile(
    r"(may contain|may also contain|traces? of|produced in a factory|peut contenir|traces? de|"
    r"قد يحتوي|قد تحتوي|يحتوي على آثار|آثار من|اثار من|يُصنع في مصنع|يصنع في مصنع)",
    re.I,
)
_ARABIC = re.compile(r"[\u0600-\u06FF]")
# Arabic letters and diacritics only: the Arabic comma "،" and semicolon "؛"
# are in the same Unicode block but separate words.
_AR_LETTER = r"\u0621-\u065F\u0671-\u06D3"


# Phrases that contain an allergen word but are not that allergen.
_NOT_ALLERGENS = re.compile(
    r"(cocoa butter|shea butter|beurre de cacao|زبدة الكاكاو|زبدة كاكاو|"
    r"coconut milk|coconut cream|lait de coco|حليب جوز الهند|كريمة جوز الهند|"
    r"coconut|noix de coco|جوز الهند|nutmeg|noix de muscade|جوزة الطيب|جوز الطيب|"
    r"butternut|cream of tartar|crème de tartre|كريم تارتار)",
    re.I,
)


def _pattern(term: str) -> re.Pattern:
    if _ARABIC.search(term):
        return re.compile(
            r"(?:^|[^" + _AR_LETTER + r"])(?:و|ب|ل|ف)?(?:ال)?" + re.escape(term.removeprefix("ال"))
            + r"(?:ة|ه|ات|ي|ية)?(?=[^" + _AR_LETTER + r"]|$)"
        )
    return re.compile(r"\b" + re.escape(term) + r"(?:s|es)?\b", re.I)


_PATTERNS = {code: [_pattern(t) for t in terms] for code, terms in _TERMS.items()}


def _found(text: str) -> set[str]:
    text = _NOT_ALLERGENS.sub(" ", text)
    codes = {code for code, patterns in _PATTERNS.items() if any(p.search(text) for p in patterns)}
    if _SULPHITE_E.search(text):
        codes.add("SULPHITES")
    return codes


def detect(statement: str) -> dict[str, str]:
    """internal_code -> "CONTAINS" or "MAY_CONTAIN" for one statement."""
    if not statement or not statement.strip():
        return {}
    text = statement.replace("‏", " ").replace("‎", " ")
    split = _MAY_CONTAIN.search(text)
    main, tail = (text[: split.start()], text[split.start():]) if split else (text, "")
    result = {code: "MAY_CONTAIN" for code in _found(tail)}
    result.update({code: "CONTAINS" for code in _found(main)})
    return result


# Open Food Facts allergen tags -> internal_code(s).
OFF_TAGS: dict[str, tuple[str, ...]] = {
    "en:gluten": ("GLUTEN",),
    "en:wheat": ("WHEAT", "GLUTEN"),
    "en:milk": ("MILK",),
    "en:eggs": ("EGG",),
    "en:peanuts": ("PEANUT",),
    "en:nuts": ("TREE_NUTS",),
    "en:soybeans": ("SOY",),
    "en:sesame-seeds": ("SESAME",),
    "en:fish": ("FISH",),
    "en:crustaceans": ("SHELLFISH",),
    "en:molluscs": ("MOLLUSCS",),
    "en:celery": ("CELERY",),
    "en:mustard": ("MUSTARD",),
    "en:lupin": ("LUPIN",),
    "en:sulphur-dioxide-and-sulphites": ("SULPHITES",),
}


def merge(*found: dict[str, str]) -> dict[str, str]:
    """Union of several detections; CONTAINS wins over MAY_CONTAIN."""
    result: dict[str, str] = {}
    for d in found:
        for code, relation in d.items():
            if result.get(code) != "CONTAINS":
                result[code] = relation
    return result


def from_off_tags(contains: list[str], traces: list[str]) -> dict[str, str]:
    result = {c: "MAY_CONTAIN" for t in traces or [] for c in OFF_TAGS.get(t, ())}
    result.update({c: "CONTAINS" for t in contains or [] for c in OFF_TAGS.get(t, ())})
    return result


_PRICE = re.compile(r"(price|prix|السعر|ريال|\bsr\b|\bsar\b|\d+\s*(sr|sar|ريال))", re.I)
_SEPARATOR = re.compile(r"[,،;؛:()\-]")


def is_plausible_statement(text: str) -> bool:
    """Whether text looks like an ingredient list and not a price, a note or
    a stray word ("price 3"). The allergy check trusts a stored statement as
    evidence, so a doubtful one must not be stored."""
    t = (text or "").strip()
    words = re.findall(r"[^\W\d_]{2,}", t)
    return (
        len(t) >= 15
        and len(words) >= 3
        and bool(_SEPARATOR.search(t))
        and not _PRICE.search(t)
    )
