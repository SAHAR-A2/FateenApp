"""Read access to public.product_completeness (migration 0054)."""
from app.db.connection import get_connection

MISSING_FIELDS = (
    "barcode",
    "name_ar",
    "name_en",
    "ingredients",
    "allergen_evidence",
    "nutrition",
    "image",
)


def completeness_summary() -> dict:
    with get_connection() as conn:
        totals = conn.execute(
            """
            SELECT COUNT(*) AS products,
                   COUNT(*) FILTER (WHERE cardinality(missing_fields) = 0) AS complete
            FROM public.product_completeness
            """
        ).fetchone()
        rows = conn.execute(
            """
            SELECT field, COUNT(*) AS products
            FROM public.product_completeness, unnest(missing_fields) AS field
            GROUP BY field
            """
        ).fetchall()
    by_field = {field: 0 for field in MISSING_FIELDS}
    by_field.update({r["field"]: r["products"] for r in rows})
    return {
        "products": totals["products"],
        "complete": totals["complete"],
        "missing_by_field": by_field,
    }


def list_incomplete(missing: str | None, limit: int, offset: int) -> tuple[int, list[dict]]:
    """Products with at least one missing field, optionally narrowed to one
    field. Ordered so the most complete products (quickest to finish) come
    first."""
    where = "cardinality(missing_fields) > 0"
    params: list = []
    if missing:
        where += " AND %s = ANY(missing_fields)"
        params.append(missing)
    with get_connection() as conn:
        total = conn.execute(
            f"SELECT COUNT(*) AS n FROM public.product_completeness WHERE {where}",
            params,
        ).fetchone()["n"]
        items = conn.execute(
            f"""
            SELECT internal_code, name, confidence_level, missing_fields
            FROM public.product_completeness
            WHERE {where}
            ORDER BY cardinality(missing_fields), internal_code
            LIMIT %s OFFSET %s
            """,
            [*params, limit, offset],
        ).fetchall()
    return total, items
