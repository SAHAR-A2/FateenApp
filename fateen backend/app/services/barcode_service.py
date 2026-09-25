from app.db.connection import get_connection


def get_product_by_barcode(barcode: str):
    query = """
    SELECT
        p.internal_code,
        p.name,
        b.barcode AS barcode,
        rt.code AS relationship_type,
        ds.code AS source,
        et.code AS evidence_type,
        ls.code AS lifecycle_status,
        pb.confidence_level
    FROM public.product_barcodes pb
    JOIN public.products p
        ON p.id = pb.product_id
    JOIN public.barcodes b
        ON b.id = pb.barcode_id
    JOIN public.relationship_types rt
        ON rt.id = pb.relationship_type_id
    LEFT JOIN public.data_sources ds
        ON ds.id = pb.source_id
    LEFT JOIN public.evidence_types et
        ON et.id = pb.evidence_type_id
    JOIN public.lifecycle_statuses ls
        ON ls.id = pb.status_id
    WHERE b.barcode = %s
      AND pb.deleted_at IS NULL
      AND p.deleted_at IS NULL
      AND b.deleted_at IS NULL
      AND (pb.effective_from IS NULL OR pb.effective_from <= NOW())
      AND (pb.effective_to IS NULL OR pb.effective_to > NOW())
    LIMIT 1
    """

    with get_connection() as conn:
        return conn.execute(query, (barcode,)).fetchone()
