"""P15: Safe deterministic deduplication.

Uses multiple identity keys to avoid false merges.
False merges are worse than duplicates.
"""
import logging
from typing import Optional

from app.db.connection import get_connection
from app.agent.normalizers import normalize_barcode, normalize_name

logger = logging.getLogger("fateen.collector.deduplication")


def find_matching_product(
    barcode: Optional[str] = None,
    product_name: Optional[str] = None,
    brand: Optional[str] = None,
) -> Optional[dict]:
    """Find a matching existing product using safe identity resolution.

    Priority: barcode > (normalized_brand + normalized_name)
    Returns None if no match found.
    Returns the product dict if matched.
    """
    if barcode:
        normalized = normalize_barcode(barcode)
        match = _match_by_barcode(normalized)
        if match:
            return match

    if product_name and brand:
        match = _match_by_name_and_brand(product_name, brand)
        if match:
            return match

    if product_name:
        match = _match_by_name(product_name)
        if match:
            return match

    return None


def _match_by_barcode(barcode: str) -> Optional[dict]:
    """Match by barcode - highest confidence match."""
    with get_connection() as conn:
        row = conn.execute("""
            SELECT p.id, p.internal_code, p.name, br.name as brand_name,
                   p.brand_id, 'barcode' as match_method, 1.0 as match_confidence
            FROM public.product_barcodes pb
            JOIN public.barcodes b ON b.id = pb.barcode_id
            JOIN public.products p ON p.id = pb.product_id
            LEFT JOIN public.brands br ON br.id = p.brand_id
            WHERE b.barcode = %s
              AND pb.deleted_at IS NULL
              AND p.deleted_at IS NULL
              AND b.deleted_at IS NULL
            LIMIT 1
        """, (barcode,)).fetchone()
        return dict(row) if row else None


def _match_by_name_and_brand(product_name: str, brand: str) -> Optional[dict]:
    """Match by normalized name + brand."""
    norm_name = normalize_name(product_name)
    norm_brand = normalize_name(brand)

    with get_connection() as conn:
        row = conn.execute("""
            SELECT p.id, p.internal_code, p.name, br.name as brand_name,
                   p.brand_id, 'name_brand' as match_method, 0.8 as match_confidence
            FROM public.products p
            JOIN public.brands br ON br.id = p.brand_id
            WHERE LOWER(p.name) = %s
              AND LOWER(br.name) = %s
              AND p.deleted_at IS NULL
              AND br.deleted_at IS NULL
            LIMIT 1
        """, (norm_name, norm_brand)).fetchone()
        return dict(row) if row else None


def _match_by_name(product_name: str) -> Optional[dict]:
    """Match by name only - lower confidence.

    Returns None if ambiguous (multiple products share the same name).
    """
    norm_name = normalize_name(product_name)

    with get_connection() as conn:
        rows = conn.execute("""
            SELECT p.id, p.internal_code, p.name, br.name as brand_name,
                   p.brand_id, 'name_only' as match_method, 0.5 as match_confidence
            FROM public.products p
            JOIN public.brands br ON br.id = p.brand_id
            WHERE LOWER(p.name) = %s
              AND p.deleted_at IS NULL
              AND br.deleted_at IS NULL
        """, (norm_name,)).fetchall()
        if not rows:
            return None
        if len(rows) == 1:
            return dict(rows[0])
        logger.warning(
            "Ambiguous name-only dedup for '%s': %d matches found, returning None to avoid false merge",
            product_name, len(rows),
        )
        return None


def check_ambiguous_match(
    barcode: Optional[str] = None,
    product_name: Optional[str] = None,
    brand: Optional[str] = None,
) -> dict:
    """Check for potential matches and assess ambiguity.

    Returns dict with 'matches' (list), 'is_ambiguous' (bool), and 'confidence'.
    """
    matches = []
    match_methods = []

    if barcode:
        normalized = normalize_barcode(barcode)
        m = _match_by_barcode(normalized)
        if m:
            matches.append(m)
            match_methods.append("barcode")

    if product_name and brand:
        m = _match_by_name_and_brand(product_name, brand)
        if m:
            matches.append(m)
            match_methods.append("name_brand")

    if product_name:
        m = _match_by_name(product_name)
        if m:
            matches.append(m)
            match_methods.append("name_only")

    unique_ids = set(m["id"] for m in matches)
    is_ambiguous = len(unique_ids) > 1

    return {
        "matches": matches,
        "match_methods": match_methods,
        "is_ambiguous": is_ambiguous,
        "count": len(unique_ids),
    }
