import logging

import psycopg

from app.db.connection import close_pool, get_connection

logger = logging.getLogger("fateen.products")


def get_products_count() -> int:
    with get_connection() as conn:
        row = conn.execute(
            "SELECT COUNT(*) AS count FROM public.products WHERE deleted_at IS NULL"
        ).fetchone()

    return row["count"]


def _escape_ilike(term: str) -> str:
    """Escape ILIKE wildcard characters so a search term is matched
    literally, not as a pattern (prevents a user-supplied '%' or '_' from
    changing the query's meaning)."""
    return term.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


_ARABIC_SEARCH_ALIASES = {
    "حليب": ("milk",),
    "لبن": ("laban", "yogurt", "yoghurt"),
    "زبادي": ("yogurt", "yoghurt"),
    "جبن": ("cheese",),
    "خبز": ("bread",),
    "مخبوزات": ("bakery", "cake", "pastry", "muffin"),
    "ألبان": ("dairy", "milk", "laban", "yogurt", "yoghurt"),
    "عصير": ("juice",),
    "مشروب": ("drink", "beverage", "juice"),
    "مشروبات": ("drink", "beverage", "juice", "water"),
    "ماء": ("water",),
    "مياه": ("water",),
    "تسالي": ("snack", "chips", "crisps"),
    "مقرمشات": ("snack", "chips", "crisps"),
    "المراعي": ("almarai", "al marai"),
    "نادك": ("nadec",),
    "الصافي": ("alsafi", "al safi"),
    "لوزين": ("lusine", "l'usine"),
    "عصائر": ("juice",),
    "أرز": ("rice",),
    "سكر": ("sugar",),
    "دقيق": ("flour",),
    "بيض": ("egg",),
    "زيت": ("oil",),
    "معكرونة": ("pasta",),
    "شاي": ("tea",),
    "قهوة": ("coffee",),
}


def _search_patterns(query: str) -> list[list[str]]:
    """Build one OR group per user word, including common Arabic aliases."""
    groups = []
    for raw_term in query.split()[:8]:
        term = raw_term.strip()
        if not term:
            continue
        base = term[2:] if term.startswith("ال") and len(term) > 3 else term
        aliases = _ARABIC_SEARCH_ALIASES.get(term, _ARABIC_SEARCH_ALIASES.get(base, ()))
        alternatives = dict.fromkeys((term, *aliases))
        groups.append([f"%{_escape_ilike(value)}%" for value in alternatives])
    return groups


def _rank_patterns(query: str) -> tuple[list[str], list[str]]:
    """ILIKE patterns for ordering search results by the first query word:
    a name that starts with it, then a name containing it as a word."""
    groups = _search_patterns(query)
    if not groups:
        return [], []
    values = [pattern[1:-1] for pattern in groups[0]]
    values += [f"ال{v}" for v in values if not v.isascii() and not v.startswith("ال")]
    starts = [p for v in values for p in (v, f"{v} %")]
    words = [p for v in values for p in (f"% {v}", f"% {v} %")]
    return starts, words


def _fetchall_with_retry(sql: str, params: tuple) -> list[dict]:
    """Reset stale cloud DB sockets, then retry one failed read."""
    for attempt in range(2):
        try:
            with get_connection() as conn:
                return conn.execute(sql, params).fetchall()
        except psycopg.OperationalError:
            if attempt:
                raise
            logger.warning("Database connection dropped during product read; retrying once")
            # All connections can become stale together when the managed
            # database resumes after idle. Rebuild the small pool so retry
            # doesn't immediately borrow its next already-closed socket.
            close_pool()
    return []


# Shared by search_products / get_alternative_candidates_by_* so the
# "representative barcode for a product" rule (prefer PRIMARY_BARCODE,
# only consider active/effective-dated, non-deleted rows) is defined once.
_REPRESENTATIVE_BARCODE_SUBQUERY = """
        (
            SELECT b.barcode
            FROM public.product_barcodes pb
            JOIN public.barcodes b
                ON b.id = pb.barcode_id
            JOIN public.relationship_types rt
                ON rt.id = pb.relationship_type_id
            WHERE pb.product_id = p.id
              AND pb.deleted_at IS NULL
              AND b.deleted_at IS NULL
              AND (pb.effective_from IS NULL OR pb.effective_from <= NOW())
              AND (pb.effective_to IS NULL OR pb.effective_to > NOW())
            ORDER BY (rt.code = 'PRIMARY_BARCODE') DESC
            LIMIT 1
        ) AS barcode
"""


def search_products(query: str, limit: int = 25, language: str = "ar") -> list[dict]:
    """Search active, non-deleted products (case-insensitive substring
    matching across product, brand, company and category). Returns rows
    shaped for ProductSearchResult.

    A representative barcode is included where available, preferring a
    PRIMARY_BARCODE relationship if one exists.
    """
    # Match every query word, allowing an Arabic word to match its common
    # English catalogue equivalent. Search the product, brand, company and
    # category so "Almarai bread" can find L'usine items.
    groups = _search_patterns(query)
    word_filters = []
    params = []
    for patterns in groups:
        word_filters.append("""(
            p.name ILIKE ANY(%s::text[])
            OR COALESCE(p.description, '') ILIKE ANY(%s::text[])
            OR EXISTS (
                SELECT 1 FROM public.product_translations pt
                JOIN public.languages lang ON lang.id = pt.language_id
                WHERE pt.product_id = p.id AND pt.deleted_at IS NULL
                  AND lang.deleted_at IS NULL
                  AND (pt.name ILIKE ANY(%s::text[]) OR COALESCE(pt.search_name, '') ILIKE ANY(%s::text[]))
            )
            OR EXISTS (
                SELECT 1 FROM public.brands br
                JOIN public.companies co ON co.id = br.company_id
                WHERE br.id = p.brand_id
                  AND br.deleted_at IS NULL AND co.deleted_at IS NULL
                  AND (br.name ILIKE ANY(%s::text[]) OR co.name ILIKE ANY(%s::text[]))
            )
            OR EXISTS (
                SELECT 1 FROM public.product_categories pc
                WHERE pc.id = p.product_category_id AND pc.deleted_at IS NULL
                  AND pc.name ILIKE ANY(%s::text[])
            )
        )""")
        params.extend([patterns] * 7)
    filters_sql = " AND ".join(word_filters) or "TRUE"
    starts, words = _rank_patterns(query)

    sql = f"""
    SELECT
        p.internal_code,
        COALESCE((SELECT pt.name FROM public.product_translations pt JOIN public.languages lang ON lang.id=pt.language_id WHERE pt.product_id=p.id AND lang.code=%s AND pt.deleted_at IS NULL AND lang.deleted_at IS NULL LIMIT 1), p.name) AS name,
        (SELECT pt.name FROM public.product_translations pt JOIN public.languages lang ON lang.id=pt.language_id WHERE pt.product_id=p.id AND lang.code='ar' AND pt.deleted_at IS NULL AND lang.deleted_at IS NULL LIMIT 1) AS name_ar,
        (SELECT pt.name FROM public.product_translations pt JOIN public.languages lang ON lang.id=pt.language_id WHERE pt.product_id=p.id AND lang.code='en' AND pt.deleted_at IS NULL AND lang.deleted_at IS NULL LIMIT 1) AS name_en,
        p.description,
        p.confidence_level,
        ls.code AS lifecycle_status,
        {_REPRESENTATIVE_BARCODE_SUBQUERY},
        (
            SELECT i.storage_uri
            FROM public.product_images pi
            JOIN public.images i ON i.id = pi.image_id
            WHERE pi.product_id = p.id
              AND pi.deleted_at IS NULL
              AND i.deleted_at IS NULL
              AND (pi.effective_from IS NULL OR pi.effective_from <= NOW())
              AND (pi.effective_to IS NULL OR pi.effective_to > NOW())
            ORDER BY pi.confidence_level DESC, pi.created_at DESC
            LIMIT 1
        ) AS image_url
    FROM public.products p
    JOIN public.lifecycle_statuses ls
        ON ls.id = p.status_id
    WHERE p.deleted_at IS NULL
      AND p.internal_code NOT LIKE 'FATEEN_SEED_NADEC_%%'
      -- Do not present partial catalogue rows as verified products. Arabic
      -- and English labels, an active barcode, and an active product image
      -- are minimum display requirements for the consumer search result.
      -- One label may be a translation awaiting review (the catalog loader
      -- translates a name the source gives in one language only); the
      -- other must be approved.
      AND EXISTS (
          SELECT 1 FROM public.product_translations ar
          JOIN public.languages lar ON lar.id = ar.language_id
          WHERE ar.product_id = p.id AND lar.code = 'ar'
            AND ar.deleted_at IS NULL AND lar.deleted_at IS NULL
            AND ar.translation_status IN ('approved', 'pending_review')
      )
      AND EXISTS (
          SELECT 1 FROM public.product_translations en
          JOIN public.languages len ON len.id = en.language_id
          WHERE en.product_id = p.id AND len.code = 'en'
            AND en.deleted_at IS NULL AND len.deleted_at IS NULL
            AND en.translation_status IN ('approved', 'pending_review')
      )
      AND EXISTS (
          SELECT 1 FROM public.product_translations ok
          WHERE ok.product_id = p.id AND ok.deleted_at IS NULL
            AND ok.translation_status = 'approved'
      )
      AND EXISTS (
          SELECT 1 FROM public.product_barcodes pb
          JOIN public.barcodes b ON b.id = pb.barcode_id
          WHERE pb.product_id = p.id AND pb.deleted_at IS NULL
            AND b.deleted_at IS NULL
            AND (pb.effective_from IS NULL OR pb.effective_from <= NOW())
            AND (pb.effective_to IS NULL OR pb.effective_to > NOW())
      )
      AND EXISTS (
          SELECT 1 FROM public.product_images pi
          JOIN public.images i ON i.id = pi.image_id
          WHERE pi.product_id = p.id AND pi.deleted_at IS NULL
            AND i.deleted_at IS NULL
            AND (pi.effective_from IS NULL OR pi.effective_from <= NOW())
            AND (pi.effective_to IS NULL OR pi.effective_to > NOW())
      )
      AND {filters_sql}
    ORDER BY
        CASE
            WHEN p.name ILIKE ANY(%s::text[]) OR EXISTS (
                SELECT 1 FROM public.product_translations t
                WHERE t.product_id = p.id AND t.deleted_at IS NULL AND t.name ILIKE ANY(%s::text[])
            ) THEN 0
            WHEN p.name ILIKE ANY(%s::text[]) OR EXISTS (
                SELECT 1 FROM public.product_translations t
                WHERE t.product_id = p.id AND t.deleted_at IS NULL AND t.name ILIKE ANY(%s::text[])
            ) THEN 1
            ELSE 2
        END,
        length(p.name),
        p.name
    LIMIT %s
    """

    return _fetchall_with_retry(sql, (language, *params, starts, starts, words, words, limit))


def get_alternative_candidates_by_category(
    category_id, exclude_internal_code: str, limit: int = 500
) -> list[dict]:
    """Candidate retrieval for the alternatives feature: other active
    products in the same product_category_id. This only decides which
    products get evaluated by the compatibility service -- it never
    decides safety by itself.
    """
    sql = f"""
    SELECT
        p.internal_code,
        p.name,
        (SELECT pt.name FROM public.product_translations pt JOIN public.languages lang ON lang.id = pt.language_id
         WHERE pt.product_id = p.id AND lang.code = 'en' AND pt.deleted_at IS NULL LIMIT 1) AS name_en,
        {_REPRESENTATIVE_BARCODE_SUBQUERY},
        (
            SELECT i.storage_uri
            FROM public.product_images pi
            JOIN public.images i ON i.id = pi.image_id
            WHERE pi.product_id = p.id AND pi.deleted_at IS NULL AND i.deleted_at IS NULL
              AND (pi.effective_from IS NULL OR pi.effective_from <= NOW())
              AND (pi.effective_to IS NULL OR pi.effective_to > NOW())
            ORDER BY pi.confidence_level DESC, pi.created_at DESC
            LIMIT 1
        ) AS image_url
    FROM public.products p
    WHERE p.deleted_at IS NULL
      AND p.product_category_id = %s
      AND p.internal_code <> %s
    ORDER BY p.name
    LIMIT %s
    """
    return _fetchall_with_retry(sql, (category_id, exclude_internal_code, limit))


def get_alternative_candidates_by_name_token(
    token: str, exclude_internal_code: str, limit: int = 15
) -> list[dict]:
    """Fallback candidate retrieval when the original product has no
    product_category_id recorded: a plain name-token match. Used ONLY to
    decide which products are worth evaluating -- the actual safety
    decision for each candidate still goes through the same
    compatibility_service as everything else. Not a medical/ranking rule.
    """
    pattern = f"%{_escape_ilike(token)}%"
    sql = f"""
    SELECT
        p.internal_code,
        p.name,
        {_REPRESENTATIVE_BARCODE_SUBQUERY}
    FROM public.products p
    WHERE p.deleted_at IS NULL
      AND p.name ILIKE %s ESCAPE '\\'
      AND p.internal_code <> %s
    ORDER BY p.name
    LIMIT %s
    """
    return _fetchall_with_retry(sql, (pattern, exclude_internal_code, limit))
