"""STEP D + STEP E: Arabic ingredient vocabulary gap analysis and proposals.

STEP D - ranked gap report for unresolved Arabic ingredient terms, classified
into the nine documented categories:
    1 DIRECT_INGREDIENT  2 SYNONYM_ALIAS       3 COMPOUND_INGREDIENT
    4 ALLERGEN_ANNOTATION 5 ADDITIVE           6 PROCESSING_AID
    7 MEASUREMENT_PACKAGING 8 IRRELEVANT       9 UNKNOWN

STEP E - evidence-backed expansion PROPOSALS (report-only, NEVER auto-applied).
Every proposal records the Arabic term, normalized form, category, proposed
canonical code, the mechanism (NEW_INGREDIENT_ROW / ALIAS / ALLERGEN_EVIDENCE),
source evidence, confidence and the regression test that must gate it.

Important: `resolve_ingredient_token` reflects what FATEEN can do TODAY. The
DB grammar is an exact LOWER(name) lookup (same semantics as
app.agent.ingestion._resolve_by_name) plus the (currently unwired)
`ingredient_aliases` table. Arabic terms that only have a documented English/
canonical equivalent do NOT resolve today and therefore show up as gaps -
exactly the honest behavior the report needs.

Nothing in this module writes to the database.
"""
import json
import logging
import re
from collections import Counter, defaultdict
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Optional

from app.batch.models import utcnow
from app.integrations.sfda_ingredients import IngredientToken, split_ingredient_text

logger = logging.getLogger("fateen.batch.vocabulary")

# ---------------------------------------------------------------------------
# Deterministic classification lexicons (evidence-based, no LLM inference)
# ---------------------------------------------------------------------------

# Arabic terms with a documented exact translation whose canonical FATEEN row
# already exists BUT under a different `name` (English/French). They do not
# resolve via the exact LOWER(name) lookup today; the ALIAS proposal is the
# smallest bridging addition (or, per the FIX-4 convention, a dedicated row).
DIRECT_MATCHES = {
    "سكر": {"canonical": "SUGAR", "existing_name": "sugar"},
    "مستحلب ليسيثين الصويا": {"canonical": "SOY_LECITHIN", "existing_name": "Soy Lecithin"},
    "مسحوق مصل اللبن": {
        "canonical": "WHEY_POWDER",
        "existing_name": "lactoserum en poudre",
        "note": "existing row uses the French name; needs an alias/row to resolve",
    },
}

# Additive indicators (E numbers, emulsifiers, colours, stabilisers...).
_ADDITIVE_KEYWORDS = (
    "مستحلب", "ليسيثين", "زانتان", "كاراجينان", "ملون", "مكسب", "مثبيت",
    "محلي", "مقوم", "جلسريد", "أحادي", "ثنائي", "e",
)

# Processing-aid keywords.
_PROCESSING_AID_KEYWORDS = ("إنزيم", "انزيم", "منفحة", "عوامل معالجة", "مساعد معالجة")

# Measurement / packaging markers. A measurement is detected ONLY when a
# quantity digit is followed by a unit (e.g. "500غ", "1لتر") or the token is a
# known packaging word - short unit substrings ("غ", "مل") must never match
# normal Arabic ingredient words such as "كامل" or "مستحلب".
_MEASUREMENT_RE = re.compile(r"\d+(\.\d+)?\s*(غ|مل|لتر|كجم|كغم|كغ|ج|جم|٪|%)")
_PACKAGING_WORDS = ("علبة", "غلاف", "قطعة", "حبة", "كبسولة", "قرص")

# Irrelevant marketing/text markers.
_IRRELEVANT_KEYWORDS = ("طعم", "نكهة", "رائحة", "لون", "قوام", "شكل")

# Compound phrase markers.
_COMPOUND_KEYWORDS = ("مسحوق", "زبدة", "خليط", "مخلوط", "محتوي", "معجنات", "كامل")

_ALL_ANNOTATION_TRIGGER = ("حليب", "اشتقاق", "مشتق", "جلوتين", "فول", "صويا", "مكسرات", "مشتقات")


class GapCategory:
    DIRECT_INGREDIENT = "direct_ingredient"          # 1
    SYNONYM_ALIAS = "synonym_alias"                  # 2
    COMPOUND_INGREDIENT = "compound_ingredient"      # 3
    ALLERGEN_ANNOTATION = "allergen_annotation"      # 4
    ADDITIVE = "additive"                            # 5
    PROCESSING_AID = "processing_aid"                # 6
    MEASUREMENT_PACKAGING = "measurement_packaging"  # 7
    IRRELEVANT = "irrelevant"                        # 8
    UNKNOWN = "unknown"                              # 9


CATEGORY_ORDER = [
    GapCategory.DIRECT_INGREDIENT,
    GapCategory.SYNONYM_ALIAS,
    GapCategory.COMPOUND_INGREDIENT,
    GapCategory.ALLERGEN_ANNOTATION,
    GapCategory.ADDITIVE,
    GapCategory.PROCESSING_AID,
    GapCategory.MEASUREMENT_PACKAGING,
    GapCategory.IRRELEVANT,
    GapCategory.UNKNOWN,
]


# ---------------------------------------------------------------------------
# Classification
# ---------------------------------------------------------------------------


def classify_token(token: IngredientToken) -> tuple[str, str]:
    """Deterministic category + explanation for one ingredient token.

    Order matters: annotation -> additive -> processing aid ->
    measurement/packaging -> compound -> deterministic translation
    (DIRECT_INGREDIENT) -> irrelevant -> unknown.
    """
    if token.annotation:
        return GapCategory.ALLERGEN_ANNOTATION, (
            f"annotation '{token.annotation}' on term '{token.source_term}'"
        )
    term = token.normalized
    if any(k in term for k in _ADDITIVE_KEYWORDS):
        return GapCategory.ADDITIVE, f"additive keyword in '{term}'"
    if any(k in term for k in _PROCESSING_AID_KEYWORDS):
        return GapCategory.PROCESSING_AID, f"processing-aid keyword in '{term}'"
    if _MEASUREMENT_RE.search(term) or term in _PACKAGING_WORDS:
        return GapCategory.MEASUREMENT_PACKAGING, f"measurement/packaging marker in '{term}'"
    if any(k in term for k in _COMPOUND_KEYWORDS) or " " in term:
        return GapCategory.COMPOUND_INGREDIENT, f"compound phrase in '{term}'"
    if term in DIRECT_MATCHES:
        return GapCategory.DIRECT_INGREDIENT, (
            f"documented translation -> canonical {DIRECT_MATCHES[term]['canonical']}"
        )
    if any(k in term for k in _IRRELEVANT_KEYWORDS):
        return GapCategory.IRRELEVANT, f"irrelevant marker in '{term}'"
    return GapCategory.UNKNOWN, f"no deterministic classification for '{term}'"


# ---------------------------------------------------------------------------
# Today's resolver (consumed by gap analysis / proposals)
# ---------------------------------------------------------------------------


def resolve_ingredient_token(conn, token: IngredientToken) -> Optional[dict]:
    """What FATEEN resolves TODAY.

    1) exact LOWER(name) match on public.ingredients (same semantics as the
       agent's `_resolve_by_name`);
    2) exact LOWER(alias) match on public.ingredient_aliases (table exists but
       is unwired per the FIX-4 precedent note; present for completeness).

    `conn=None` (offline) never resolves anything - the honest offline answer.
    """
    if conn is None:
        return None
    row = conn.execute(
        "SELECT internal_code, name FROM public.ingredients "
        "WHERE LOWER(name) = %s AND deleted_at IS NULL LIMIT 1",
        (token.normalized,),
    ).fetchone()
    if row:
        return {"name": row["name"], "internal_code": row["internal_code"]}
    alias = conn.execute(
        "SELECT i.internal_code, i.name FROM public.ingredient_aliases a "
        "JOIN public.ingredients i ON i.id = a.ingredient_id "
        "WHERE LOWER(a.alias) = %s AND a.deleted_at IS NULL LIMIT 1",
        (token.normalized,),
    ).fetchone()
    if alias:
        return {"name": alias["name"], "internal_code": alias["internal_code"]}
    return None


# ---------------------------------------------------------------------------
# STEP D: gap report
# ---------------------------------------------------------------------------


@dataclass
class TokenGapStat:
    term: str
    normalized: str
    category: str
    explanation: str
    resolves_now: bool
    matched_canonical: Optional[str] = None
    frequency: int = 1
    confidence: float = 0.5
    impact: float = 0.0

    def priority(self) -> float:
        return self.frequency * self.confidence * self.impact


def corpus_from_text(text: str) -> list[str]:
    """Statements to analyze (one per line, as in SFDA ingredientsAr fields)."""
    return [line.strip() for line in (text or "").splitlines() if line.strip()]


def analyze_arabic_gap(
    conn,
    corpus: list[str],
    out_path: Optional[Path] = None,
    label: str = "SFDA ingredient statements",
) -> dict:
    """Ranked gap report over a corpus of ingredient statements.

    Every token of every statement is classified; tokens that do not resolve
    against the current grammar are ranked by frequency x confidence x impact
    and grouped into the nine documented categories.
    """
    stats: dict[str, TokenGapStat] = {}
    for raw in corpus:
        for token in split_ingredient_text(raw).tokens:
            category, explanation = classify_token(token)
            resolved = resolve_ingredient_token(conn, token)
            key = token.normalized
            if key not in stats:
                stats[key] = TokenGapStat(
                    term=token.source_term,
                    normalized=key,
                    category=category,
                    explanation=explanation,
                    resolves_now=resolved is not None,
                    matched_canonical=resolved["internal_code"] if resolved else None,
                )
            else:
                stats[key].frequency += 1

    gap_rows = [s for s in stats.values() if not s.resolves_now]
    ranked = sorted(gap_rows, key=lambda s: s.priority(), reverse=True)
    by_category: dict[str, list[dict]] = defaultdict(list)
    for s in ranked:
        row = asdict(s)
        row["priority"] = s.priority()
        by_category[s.category].append(row)

    report = {
        "generated_at": utcnow(),
        "corpus_label": label,
        "corpus_statements": len(corpus),
        "unresolved_token_count": len(ranked),
        "category_order": CATEGORY_ORDER,
        "distribution": {c: len(by_category[c]) for c in CATEGORY_ORDER},
        "ranked_unresolved_terms": [
            {**asdict(s), "priority": s.priority()} for s in ranked
        ],
        "by_category": {c: by_category[c] for c in CATEGORY_ORDER},
    }
    if out_path:
        _write_json(out_path, report)
        logger.info("gap report written: %s", out_path)
    return report


# ---------------------------------------------------------------------------
# STEP E: expansion proposals (report-only, NEVER applied)
# ---------------------------------------------------------------------------


@dataclass
class ExpansionProposal:
    term: str
    normalized: str
    category: str
    canonical_internal_code: str
    mechanism: str
    existing_row: Optional[str]
    source_evidence: str
    confidence: float
    regression_test: str
    rationale: str
    frequency: int = 1
    impact: float = 0.0

    def priority(self) -> float:
        return self.frequency * self.confidence * self.impact


def build_expansion_proposals(
    conn,
    corpus: list[str],
    out_path: Optional[Path] = None,
) -> dict:
    """Deterministic, evidence-backed vocabulary expansion proposals.

    Mechanisms:
      NEW_INGREDIENT_ROW   no canonical row exists; propose a row named with
                           the Arabic term and a suggested internal_code
                           (governed by the FIX-4 conventions; a regression
                           test must gate it).
      ALIAS                the canonical row exists but under a different
                           `name`; the minimal bridge is an
                           `ingredient_aliases` row (unapplied) or, per
                           FIX-4, a dedicated ingredient row.
      ALLERGEN_EVIDENCE    parenthetical annotations are allergen evidence, not
                           grammar rows; they are surfaced, never promoted.

    Impact is seeded from corpus frequency today and must be re-weighted from
    live SFDA data once credentials flow.
    """
    counter = Counter()
    for raw in corpus:
        for token in split_ingredient_text(raw).tokens:
            if token.annotation:
                counter[("annotation", token.annotation)] += 1
            counter[("term", token.normalized)] += 1

    proposals: list[ExpansionProposal] = []
    seen_terms: dict[str, IngredientToken] = {}
    for raw in corpus:
        for token in split_ingredient_text(raw).tokens:
            seen_terms.setdefault(token.normalized, token)

    for (kind, key), freq in counter.items():
        if kind == "annotation":
            proposals.append(ExpansionProposal(
                term=key,
                normalized=key,
                category=GapCategory.ALLERGEN_ANNOTATION,
                canonical_internal_code="",
                mechanism="ALLERGEN_EVIDENCE",
                existing_row=None,
                source_evidence=(
                    f"annotation ({key}) occurs {freq}x in the SFDA corpus; it names "
                    "an allergen, not a standalone ingredient"
                ),
                confidence=0.9,
                regression_test="test_allergen_annotation_not_promoted",
                rationale=(
                    "annotations such as (حليب) are allergen evidence and are "
                    "already detached by split_ingredient_text; they must never "
                    "become an ingredient grammar row"
                ),
                frequency=freq,
                impact=0.5,
            ))
            continue

        token = seen_terms.get(key)
        category, _ = classify_token(token) if token else (GapCategory.UNKNOWN, "")
        resolved = resolve_ingredient_token(conn, token) if token else None
        if resolved:
            continue  # resolves today; nothing to propose

        match = DIRECT_MATCHES.get(key)
        if match is not None:
            proposals.append(ExpansionProposal(
                term=token.source_term if token else key,
                normalized=key,
                category=category,
                canonical_internal_code=match["canonical"],
                mechanism="ALIAS",
                existing_row=match["existing_name"],
                source_evidence=_evidence_for(key),
                confidence=0.85,
                regression_test=f"test_proposal_alias_{_safe(key)}",
                rationale=(
                    f"documented translation -> canonical {match['canonical']} "
                    f"(existing row '{match['existing_name']}'); minimal bridge "
                    "is an ingredient_aliases row (unapplied) so the exact "
                    "LOWER(name) resolver can find it"
                ),
                frequency=freq,
                impact=1.0,
            ))
        else:
            proposals.append(ExpansionProposal(
                term=token.source_term if token else key,
                normalized=key,
                category=category,
                canonical_internal_code=_canonical_code_for(key),
                mechanism="NEW_INGREDIENT_ROW",
                existing_row=None,
                source_evidence=_evidence_for(key),
                confidence=0.6,
                regression_test=f"test_proposal_rule_{_safe(key)}",
                rationale=(
                    f"no canonical equivalence in the current grammar "
                    f"({category}); propose a new ingredient row governed by "
                    "the FIX-4 conventions, gated by the named regression test"
                ),
                frequency=freq,
                impact=1.0,
            ))

    proposals.sort(key=lambda p: p.priority(), reverse=True)
    payload = {
        "generated_at": utcnow(),
        "rule": (
            "proposals are evidence-backed and NEVER applied automatically; "
            "each requires a regression test + source evidence + review."
        ),
        "proposals": [asdict(p) for p in proposals],
    }
    if out_path:
        _write_json(out_path, payload)
        logger.info("expansion proposals written: %s", out_path)
    return payload


def _canonical_code_for(term: str) -> str:
    return "AR_" + "".join(c for c in term if c.isalnum())[:24]


def _safe(term: str) -> str:
    return "".join(c for c in term if c.isalnum())[:32] or "x"


def _evidence_for(term: str) -> str:
    return (
        f"evidence: the SFDA registered-food/FIRS ingredientsAr statement "
        f"contains the exact term '{term}'. Real live evidence must be "
        "recorded before any application."
    )


def _write_json(path: Path, payload: dict) -> None:
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)