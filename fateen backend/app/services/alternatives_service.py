"""Backend-owned safe-alternative retrieval.

Replaces the old Flutter result_screen flow (product name -> first three
words -> Open Food Facts search -> local HealthChecker filtering).

Candidate retrieval is deterministic: same product_category_id where the
original product has one recorded, otherwise a name-token fallback used
ONLY to decide which products are worth evaluating. Retrieval never decides
safety.

Within a category, candidates are ranked by how much their Arabic and
English names share with the original's (each shared word weighted by how
rare it is in the category, so "biscuit" counts more than the brand), and
only related candidates are evaluated: an alternative to a chocolate
biscuit is another biscuit, not an ice cream. When nothing in the category
shares a word, the category order is used.

Every candidate is evaluated through the exact same compatibility_service
used by the barcode/search flow -- there is no second, alternatives-
specific safety engine. Only candidates whose compatibility result is
SAFE are returned. WARNING/DANGER/UNKNOWN/INSUFFICIENT_DATA candidates are
excluded outright, not shown as a lower-confidence "maybe" option -- an
uncertain candidate is not presented as a safe alternative.
"""
import logging
import math
import re
from concurrent.futures import ThreadPoolExecutor
from typing import Optional

from app.services.product_details_service import get_product_details_by_barcode
from app.services.compatibility_service import evaluate_compatibility
from app.repositories.product_repository import (
    get_alternative_candidates_by_category,
    get_alternative_candidates_by_name_token,
)
from app.schemas.compatibility import CompatibilityRequest, ProductSummary, STATUS_SAFE
from app.schemas.alternatives import AlternativeCandidate, AlternativesResponse

logger = logging.getLogger("fateen.services.alternatives")

MAX_CANDIDATES = 15
MAX_EVALUATED = 20
PARALLEL_CHECKS = 4
MAX_RESULTS = 5

_DIACRITICS = re.compile("[\u064B-\u0652\u0640]")
_STOPWORDS = {
    "with", "and", "the", "of", "in", "for", "from", "flavour", "flavor", "flavoured", "flavored",
    "مع", "من", "في", "و", "نكهة", "بنكهة", "طعم", "بطعم",
}
_UNITS = re.compile(r"^\d|^(g|gm|kg|ml|l|oz|pcs|x|غ|جم|كغ|مل|لتر|ل)$")


def _word(token: str) -> str:
    token = _DIACRITICS.sub("", token.lower())
    token = token.translate(str.maketrans("أإآىة", "ااايه"))
    for prefix in ("بال", "وال", "لل", "ال", "ب", "و"):
        if token.startswith(prefix) and len(token) - len(prefix) >= 3:
            return token[len(prefix):]
    return token


def _tokens(*names: Optional[str]) -> set[str]:
    words = set()
    for name in names:
        for raw in re.split(r"[^\w]+", name or ""):
            word = _word(raw)
            if len(word) >= 3 and word not in _STOPWORDS and not _UNITS.match(word):
                words.add(word)
    return words


def rank_by_similarity(original_names: tuple, candidates: list[dict]) -> list[dict]:
    """Candidates sharing a name word with the original, most similar
    first. Returns all candidates unchanged if none share a word."""
    wanted = _tokens(*original_names)
    tokens = [_tokens(c.get("name"), c.get("name_en")) for c in candidates]
    frequency: dict[str, int] = {}
    for words in tokens:
        for word in words & wanted:
            frequency[word] = frequency.get(word, 0) + 1
    total = len(candidates) + 1
    scored = []
    for candidate, words in zip(candidates, tokens):
        score = sum(math.log(total / frequency[w]) + 0.1 for w in words & wanted)
        if score > 0:
            scored.append((score, candidate))
    if not scored:
        return candidates
    scored.sort(key=lambda pair: -pair[0])
    return [candidate for _, candidate in scored]


def get_safe_alternatives(
    barcode: str, request: CompatibilityRequest
) -> Optional[AlternativesResponse]:
    """Returns None if the original barcode is not found (mapped to 404 by
    the API layer), otherwise a list of at most MAX_RESULTS candidates
    that were positively confirmed SAFE for this specific user context.
    """
    details = get_product_details_by_barcode(barcode)
    if details is None:
        return None

    original = ProductSummary(
        internal_code=details["internal_code"],
        name=details["name"],
        barcode=barcode,
        lifecycle_status=details["lifecycle_status"],
        confidence_level=details["confidence_level"],
    )

    category_id = details.get("product_category_id")
    if category_id:
        candidates = rank_by_similarity(
            (details.get("name"), details.get("name_en")),
            get_alternative_candidates_by_category(category_id, details["internal_code"]),
        )
    else:
        first_token = (details["name"].split() or [""])[0]
        candidates = (
            get_alternative_candidates_by_name_token(
                first_token, details["internal_code"], limit=MAX_CANDIDATES
            )
            if first_token
            else []
        )

    # No active/purchasable barcode -- skip rather than recommend something
    # the user can't scan/verify themselves.
    to_check = [c for c in candidates[:MAX_EVALUATED] if c.get("barcode")]
    confirmed_safe: list[AlternativeCandidate] = []
    # Candidates are checked a few at a time, in ranking order: each check
    # is a handful of queries, and the database may be far from the API.
    with ThreadPoolExecutor(max_workers=PARALLEL_CHECKS) as pool:
        for start in range(0, len(to_check), PARALLEL_CHECKS):
            chunk = to_check[start:start + PARALLEL_CHECKS]
            results = pool.map(lambda c: evaluate_compatibility(c["barcode"], request), chunk)
            for candidate, result in zip(chunk, results):
                if result is None or result.status != STATUS_SAFE:
                    continue
                confirmed_safe.append(
                    AlternativeCandidate(
                        product=result.product.model_copy(update={"image_url": candidate.get("image_url")}),
                        reason="متوافق وفق البيانات والقواعد المتوفرة حاليًا لدى فطين",
                    )
                )
            if len(confirmed_safe) >= MAX_RESULTS:
                break
    confirmed_safe = confirmed_safe[:MAX_RESULTS]

    return AlternativesResponse(
        original_product=original,
        alternatives=confirmed_safe,
        candidates_considered=min(len(candidates), MAX_EVALUATED),
        candidates_confirmed_safe=len(confirmed_safe),
    )
