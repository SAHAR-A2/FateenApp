from app.db.connection import get_connection


def get_product_details_by_barcode(barcode: str):
    product_query = """
    SELECT
        p.id,
        p.internal_code,
        p.name,
        p.description,
        p.confidence_level,
        p.product_category_id,
        ls.code AS lifecycle_status,
        (
            SELECT pt.name FROM public.product_translations pt
            JOIN public.languages l ON l.id = pt.language_id
            WHERE pt.product_id = p.id AND l.code = 'ar'
              AND pt.deleted_at IS NULL AND pt.translation_status <> 'rejected'
            ORDER BY (pt.translation_status = 'approved') DESC
            LIMIT 1
        ) AS name_ar,
        (
            SELECT pt.name FROM public.product_translations pt
            JOIN public.languages l ON l.id = pt.language_id
            WHERE pt.product_id = p.id AND l.code = 'en'
              AND pt.deleted_at IS NULL AND pt.translation_status <> 'rejected'
            ORDER BY (pt.translation_status = 'approved') DESC
            LIMIT 1
        ) AS name_en,
        (
            SELECT i.storage_uri
            FROM public.product_images pi
            JOIN public.images i ON i.id = pi.image_id
            WHERE pi.product_id = p.id
              AND pi.deleted_at IS NULL AND i.deleted_at IS NULL
              AND (pi.effective_from IS NULL OR pi.effective_from <= NOW())
              AND (pi.effective_to IS NULL OR pi.effective_to > NOW())
            ORDER BY pi.confidence_level DESC, pi.created_at DESC
            LIMIT 1
        ) AS image_url
    FROM public.product_barcodes pb
    JOIN public.products p
        ON p.id = pb.product_id
    JOIN public.barcodes b
        ON b.id = pb.barcode_id
    JOIN public.lifecycle_statuses ls
        ON ls.id = p.status_id
    WHERE b.barcode = %s
      AND pb.deleted_at IS NULL
      AND b.deleted_at IS NULL
      AND p.deleted_at IS NULL
      AND (pb.effective_from IS NULL OR pb.effective_from <= NOW())
      AND (pb.effective_to IS NULL OR pb.effective_to > NOW())
    LIMIT 1
    """

    with get_connection() as conn:
        product = conn.execute(product_query, (barcode,)).fetchone()

        if product is None:
            return None

        product_id = product["id"]

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
        JOIN public.ingredients i
            ON i.id = pi.ingredient_id
        JOIN public.relationship_types rt
            ON rt.id = pi.relationship_type_id
        LEFT JOIN public.units u
            ON u.id = pi.unit_id
        LEFT JOIN public.evidence_types et
            ON et.id = pi.evidence_type_id
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
        JOIN public.allergens a
            ON a.id = pa.allergen_id
        JOIN public.relationship_types rt
            ON rt.id = pa.relationship_type_id
        LEFT JOIN public.evidence_types et
            ON et.id = pa.evidence_type_id
        WHERE pa.product_id = %s
          AND pa.deleted_at IS NULL
          AND a.deleted_at IS NULL
          AND (pa.effective_from IS NULL OR pa.effective_from <= NOW())
          AND (pa.effective_to IS NULL OR pa.effective_to > NOW())
        ORDER BY a.name
        """

        health_flags_query = """
        SELECT
            h.internal_code,
            h.name,
            rt.code AS relationship_type,
            ph.confidence_level,
            et.code AS evidence_type
        FROM public.product_health_flags ph
        JOIN public.health_flags h
            ON h.id = ph.health_flag_id
        JOIN public.relationship_types rt
            ON rt.id = ph.relationship_type_id
        LEFT JOIN public.evidence_types et
            ON et.id = ph.evidence_type_id
        WHERE ph.product_id = %s
          AND ph.deleted_at IS NULL
          AND h.deleted_at IS NULL
          AND (ph.effective_from IS NULL OR ph.effective_from <= NOW())
          AND (ph.effective_to IS NULL OR ph.effective_to > NOW())
        ORDER BY h.name
        """

        nutrition_query = """
        SELECT
          nt.code AS nutrition_type,
          pnv.amount_value,
          u.code AS unit,
          rt.code AS relationship_type,
          pnv.confidence_level,
          et.code AS evidence_type,
          mb.code AS measurement_basis
        FROM public.product_nutrition_values pnv
        JOIN public.nutrition_types nt
         ON nt.id = pnv.nutrition_type_id
        JOIN public.units u
          ON u.id = pnv.unit_id
        JOIN public.relationship_types rt
          ON rt.id = pnv.relationship_type_id
        LEFT JOIN public.evidence_types et
          ON et.id = pnv.evidence_type_id
       LEFT JOIN public.measurement_bases mb
          ON mb.id = pnv.measurement_basis_id
        WHERE pnv.product_id = %s
          AND pnv.deleted_at IS NULL
          AND (pnv.effective_from IS NULL OR pnv.effective_from <= NOW())
          AND (pnv.effective_to IS NULL OR pnv.effective_to > NOW())
        ORDER BY nt.code
          """

        ingredients = conn.execute(
            ingredients_query, (product_id,)
        ).fetchall()

        allergens = conn.execute(
            allergens_query, (product_id,)
        ).fetchall()

        health_flags = conn.execute(
            health_flags_query, (product_id,)
        ).fetchall()

        nutrition = conn.execute(
            nutrition_query, (product_id,)
        ).fetchall()

        # The ingredient list as printed on the pack (migration 0056). A
        # database without that migration simply has none.
        ingredient_statements = {}
        if conn.execute(
            "SELECT to_regclass('public.product_ingredient_statements') IS NOT NULL AS present"
        ).fetchone()["present"]:
            ingredient_statements = {
                r["language_code"]: r["statement"]
                for r in conn.execute(
                    """
                    SELECT language_code, statement
                    FROM public.product_ingredient_statements
                    WHERE product_id = %s AND deleted_at IS NULL
                    """,
                    (product_id,),
                ).fetchall()
            }

    return {
        "id": product["id"],
        "internal_code": product["internal_code"],
        "name": product["name"],
        "name_ar": product.get("name_ar"),
        "name_en": product.get("name_en"),
        "description": product["description"],
        "confidence_level": product["confidence_level"],
        "product_category_id": product["product_category_id"],
        "lifecycle_status": product["lifecycle_status"],
        "image_url": product["image_url"],
        "ingredients": ingredients,
        "allergens": allergens,
        "health_flags": health_flags,
        "nutrition": nutrition,
        "ingredient_statements": ingredient_statements,
    }
