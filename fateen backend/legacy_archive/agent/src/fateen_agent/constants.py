"""Shared constants: agent verification statuses, source taxonomy, weights."""

from __future__ import annotations

# ---------------------------------------------------------------------------
# Agent outcome statuses (see docs/verification_rules.md)
# ---------------------------------------------------------------------------
VERIFIED = "VERIFIED"
NEEDS_REVIEW = "NEEDS_REVIEW"
CONFLICT = "CONFLICT"
UNRESOLVED = "UNRESOLVED"
FAILED = "FAILED"

AGENT_STATUSES = (VERIFIED, NEEDS_REVIEW, CONFLICT, UNRESOLVED, FAILED)

# Statuses that always produce a review task.
REVIEW_PROBLEM_STATUSES = (NEEDS_REVIEW, CONFLICT, UNRESOLVED, FAILED)

# ---------------------------------------------------------------------------
# Source taxonomy used inside the agent.
# Maps to public.source_priorities codes.
# ---------------------------------------------------------------------------
PRIORITY_PRIMARY = "PRIMARY"
PRIORITY_SECONDARY = "SECONDARY"
PRIORITY_TERTIARY = "TERTIARY"
PRIORITY_COMMUNITY = "COMMUNITY"
PRIORITY_UNVERIFIED = "UNVERIFIED"

PRIORITY_RANK = {
    PRIORITY_PRIMARY: 90,
    PRIORITY_SECONDARY: 70,
    PRIORITY_TERTIARY: 50,
    PRIORITY_COMMUNITY: 30,
    PRIORITY_UNVERIFIED: 10,
}

# Source types (agent taxonomy; independent from public.source_types).
SOURCE_TYPE_MANUFACTURER = "manufacturer"
SOURCE_TYPE_REGULATORY = "regulatory"
SOURCE_TYPE_DATABASE = "database"
SOURCE_TYPE_WEB = "web"
SOURCE_TYPE_LABEL = "label"
SOURCE_TYPE_USER = "user"

# Base reliability per source type, used by the confidence engine.
SOURCE_TYPE_RELIABILITY = {
    SOURCE_TYPE_LABEL: 0.95,       # official label / product PDF
    SOURCE_TYPE_MANUFACTURER: 0.90,  # official manufacturer page
    SOURCE_TYPE_REGULATORY: 0.95,  # regulatory authority statement
    SOURCE_TYPE_DATABASE: 0.75,    # trusted open database (e.g. OFF)
    SOURCE_TYPE_WEB: 0.40,         # generic web research
    SOURCE_TYPE_USER: 0.20,        # user-submitted
}

# ---------------------------------------------------------------------------
# Key types
# ---------------------------------------------------------------------------
KEY_BARCODE = "barcode"
KEY_NAME = "name"

# ---------------------------------------------------------------------------
# Confidence engine weights (sum to 1.0). See docs/confidence.md.
# ---------------------------------------------------------------------------
DEFAULT_CONFIDENCE_WEIGHTS = {
    "source_reliability": 0.30,
    "barcode_match": 0.25,
    "brand_match": 0.10,
    "company_match": 0.10,
    "name_match": 0.10,
    "ingredient_evidence": 0.10,
    "recency": 0.05,
}

# ---------------------------------------------------------------------------
# Verification thresholds (see docs/verification_rules.md)
# ---------------------------------------------------------------------------
VERIFIED_MIN_CONFIDENCE = 0.70
NEEDS_REVIEW_MIN_CONFIDENCE = 0.40

# Facts a product must have evidence for to reach VERIFIED.
REQUIRED_FACTS_VERIFIED = ("name", "barcode", "ingredients", "brand_or_company")

# Percentage of top-priority source agreeing required to resolve a conflict.
CONFLICT_RESOLUTION_AGREEMENT = 0.5

# Max age in days before a source is considered stale for recency scoring.
RECENCY_HALF_LIFE_DAYS = 365.0

# ---------------------------------------------------------------------------
# Evidence fact keys
# ---------------------------------------------------------------------------
FACT_NAME = "name"
FACT_BRAND = "brand"
FACT_COMPANY = "company"
FACT_BARCODE = "barcode"
FACT_INGREDIENT = "ingredient"
FACT_ALLERGEN = "allergen"
FACT_NUTRITION = "nutrition"
FACT_PACKAGE = "package_size"
FACT_PRODUCT_URL = "product_url"

# ---------------------------------------------------------------------------
# Review task problem kinds
# ---------------------------------------------------------------------------
PROBLEM_MISSING_EVIDENCE = "missing_evidence"
PROBLEM_SOURCE_CONFLICT = "source_conflict"
PROBLEM_UNRESOLVED = "unresolved"
PROBLEM_TECHNICAL = "technical_failure"
