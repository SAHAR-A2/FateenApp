from typing import Optional
from app.db.connection import get_connection


def find_product_details_by_barcode(barcode: str) -> Optional[dict]:
    product_query = """
        SELECT
            p.id,
            p.internal_code,
            p.name,
            b.barcode,
            rt.code AS relationship_type,
            ds.code AS source,
            et.code AS evidence_type,
            pb.confidence_level,
            ls.code AS lifecycle_status
        FROM public.product_barcodes pb
        JOIN public.products p ON p.id = pb.product_id
        JOIN public.barcodes b ON b.id = pb.barcode_id
        JOIN public.relationship_types rt ON rt.id = pb.relationship_type_id
        LEFT JOIN public.data_sources ds ON ds.id = pb.source_id
        LEFT JOIN public.evidence_types et ON et.id = pb.evidence_type_id
        JOIN public.lifecycle_statuses ls ON ls.id = pb.status_id
        WHERE b.barcode = %s
          AND pb.deleted_at IS NULL
          AND p.deleted_at IS NULL
          AND b.deleted_at IS NULL
          AND (pb.effective_from IS NULL OR pb.effective_from <= NOW())
          AND (pb.effective_to IS NULL OR pb.effective_to > NOW())
        LIMIT 1
    """

    with get_connection() as conn:
        product = conn.execute(product_query, (barcode,)).fetchone()

        if product is None:
            return None

        ingredients_query = """
            SELECT
                i.internal_code,
                i.name,
                rt.code AS relationship_type,
                pi.amount_value,
                u.code AS unit,
                pi.confidence_level,
                et.code AS evidence_type
            FROM public.product_ingredients pi
            JOIN public.ingredients i ON i.id = pi.ingredient_id
            JOIN public.relationship_types rt ON rt.id = pi.relationship_type_id
            LEFT JOIN public.units u ON u.id = pi.unit_id
            LEFT JOIN public.evidence_types et ON et.id = pi.evidence_type_id
            WHERE pi.product_id = %s
              AND pi.deleted_at IS NULL
              AND i.deleted_at IS NULL
              AND (pi.effective_from IS NULL OR pi.effective_from <= NOW())
              AND (pi.effective_to IS NULL OR pi.effective_to > NOW())
            ORDER BY i.name
        """

        allergens_query = """
            SELECT
                a.internal_code,
                a.name,
                rt.code AS relationship_type,
                pa.confidence_level,
                et.code AS evidence_type
            FROM public.product_allergens pa
            JOIN public.allergens a ON a.id = pa.allergen_id
            JOIN public.relationship_types rt ON rt.id = pa.relationship_type_id
            LEFT JOIN public.evidence_types et ON et.id = pa.evidence_type_id
            WHERE pa.product_id = %s
              AND pa.deleted_at IS NULL
              AND a.deleted_at IS NULL
              AND (pa.effective_from IS NULL OR pa.effective_from <= NOW())
              AND (pa.effective_to IS NULL OR pa.effective_to > NOW())
            ORDER BY a.name
        """

        ingredients = conn.execute(
            ingredients_query,
            (product["id"],)
        ).fetchall()

        allergens = conn.execute(
            allergens_query,
            (product["id"],)
        ).fetchall()

    result = dict(product)
    result.pop("id", None)
    result["ingredients"] = [dict(row) for row in ingredients]
    result["allergens"] = [dict(row) for row in allergens]

    return result
