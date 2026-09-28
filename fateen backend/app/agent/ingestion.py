import logging
from typing import Optional

from app.db.connection import get_connection

logger = logging.getLogger("fateen.ingestion")
from app.agent.models import (
    IngestionInput,
    IngestionResult,
    ProposedChange,
)
from app.agent.normalizers import normalize_barcode, normalize_name, normalize_code
from app.agent.validators import validate_barcode, validate_confidence
from app.agent.confidence import (
    calculate_ingredient_confidence,
    calculate_allergen_confidence,
    calculate_nutrition_confidence,
)


def ingest(input_data: IngestionInput, dry_run: bool = True) -> IngestionResult:
    result = IngestionResult(dry_run=dry_run, barcode=input_data.barcode)

    barcode_errors = validate_barcode(input_data.barcode)
    if barcode_errors:
        result.errors.extend(barcode_errors)
        return result

    conf_errors = validate_confidence(input_data.confidence_level)
    if conf_errors:
        result.errors.extend(conf_errors)
        return result

    barcode = normalize_barcode(input_data.barcode)

    try:
        with get_connection() as conn:
            product = _find_product(conn, barcode)
            if product is None:
                result.errors.append(
                    f"No product found for barcode {barcode}"
                )
                return result

            result.product_id = product["id"]
            result.product_internal_code = product["internal_code"]

            refs = _load_references(conn)

            source_id, evidence_type_id, source_errors = _resolve_source_and_evidence(
                conn, input_data
            )
            if source_errors:
                result.errors.extend(source_errors)
                result.errors.append(
                    "Ingestion rejected: source/evidence could not be "
                    "verified against known reference data (needs_review) "
                    "-- no data was attributed to a placeholder source."
                )
                return result
            refs["resolved_source_id"] = source_id
            refs["resolved_evidence_type_id"] = evidence_type_id

            existing = _load_existing_state(conn, product["id"])

            _compare_ingredients(
                existing["ingredients"], input_data, refs, result
            )
            _compare_allergens(
                existing["allergens"], input_data, refs, result
            )
            _compare_nutrition(
                existing["nutrition"], input_data, refs, result
            )

            if not dry_run:
                _apply_changes(
                    conn, result, refs, product["id"], input_data
                )
                applied = [c for c in result.changes if c.action in ("create", "update")]
                if applied:
                    # Structured trace of provenance for this write. We do
                    # NOT write this to public.evidence_records: that table
                    # (defined only in the never-applied
                    # legacy_archive/migrations/archive/001_collector_tables.sql) FKs
                    # source_config_id -> public.source_configs(id), a
                    # different, unrelated table from public.data_sources
                    # (the one resolved_source_id above actually comes
                    # from, per the main schema in
                    # migrations/0000_recovered_baseline.sql). Inserting a
                    # data_sources.id into that column would violate the FK
                    # constraint on essentially every real call. Wiring
                    # real per-fact evidence persistence needs a schema
                    # decision (reconcile data_sources/source_configs, or
                    # add source_url/retrieved_at columns directly on
                    # product_ingredients/product_allergens/
                    # product_nutrition_values) -- flagged for a human
                    # decision, not done here. Logging keeps the
                    # information from being silently dropped in the
                    # meantime.
                    logger.info(
                        "ingestion_provenance barcode=%s product_id=%s "
                        "source=%s evidence_type=%s source_url=%s "
                        "retrieved_at=%s changes_applied=%d",
                        barcode, product["id"], input_data.source,
                        input_data.evidence_type, input_data.source_url,
                        input_data.retrieved_at, len(applied),
                    )
    except Exception as e:
        logger.exception("Ingestion error for barcode=%s", input_data.barcode)
        if not result.errors:
            result.errors.append("Ingestion failed. Check server logs for details.")

    return result


def _find_product(conn, barcode: str) -> Optional[dict]:
    query = """
        SELECT p.id, p.internal_code, p.name
        FROM public.product_barcodes pb
        JOIN public.products p ON p.id = pb.product_id
        JOIN public.barcodes b ON b.id = pb.barcode_id
        WHERE b.barcode = %s
          AND pb.deleted_at IS NULL
          AND p.deleted_at IS NULL
          AND b.deleted_at IS NULL
          AND (pb.effective_from IS NULL OR pb.effective_from <= NOW())
          AND (pb.effective_to IS NULL OR pb.effective_to > NOW())
        LIMIT 1
    """
    return conn.execute(query, (barcode,)).fetchone()


# Whitelist of reference tables this module is allowed to interpolate into
# SQL via f-string. All current callers already pass only internal string
# literals (never user input), so this is defense-in-depth rather than a fix
# for an exploitable issue today: it turns any future call site that passes
# an unexpected/attacker-influenced table name into a loud internal error
# instead of a silent SQL-injection-shaped code path.
_ALLOWED_REFERENCE_TABLES = frozenset(
    {
        "ingredients",
        "allergens",
        "units",
        "nutrition_types",
        "measurement_bases",
        "relationship_types",
        "data_sources",
        "evidence_types",
        "lifecycle_statuses",
    }
)


def _assert_allowed_table(table: str) -> None:
    if table not in _ALLOWED_REFERENCE_TABLES:
        raise ValueError(
            f"Internal error: '{table}' is not an allow-listed reference "
            f"table for dynamic SQL construction in app.agent.ingestion. "
            f"Add it to _ALLOWED_REFERENCE_TABLES if this is intentional."
        )


def _load_references(conn) -> dict:
    refs = {}
    required = {
        "relationship_types": {
            "PRIMARY_BARCODE": "rt_PRIMARY_BARCODE",
            "CONTAINS_INGREDIENT": "rt_CONTAINS_INGREDIENT",
            "CONTAINS_ALLERGEN": "rt_CONTAINS_ALLERGEN",
            "MEASURED_VALUE": "rt_MEASURED_VALUE",
        },
        "lifecycle_statuses": {
            "ACTIVE": "ls_ACTIVE",
        },
    }
    for table, mappings in required.items():
        _assert_allowed_table(table)
        for code, key in mappings.items():
            row = conn.execute(
                f"SELECT id FROM public.{table} WHERE code = %s LIMIT 1",
                (code,),
            ).fetchone()
            if row is None:
                raise ValueError(
                    f"Required reference not found: {table}.{code}"
                )
            refs[key] = row["id"]
    return refs


def _resolve_source_and_evidence(conn, input_data: IngestionInput) -> tuple:
    """Resolve the real data_source and evidence_type for this ingestion.

    This is the fix for the CRITICAL finding in the FATEEN Architecture
    Audit: every fact used to be attributed to a hardcoded placeholder
    (data_sources.code='FATEEN_TEST', evidence_types.code='LABEL')
    regardless of what the caller actually passed in
    IngestionInput.source / IngestionInput.evidence_type. That silently
    destroyed provenance for real data.

    Behavior now:
      - Look up public.data_sources by code = input_data.source (upper-
        cased) and public.evidence_types by code = input_data.evidence_type
        (uppercased). These are the SAME two fields IngestionInput already
        had; they were simply never read before.
      - If either code does not exist as a real reference row, this
        returns errors instead of silently falling back to a placeholder.
        The caller (ingest()) turns that into a rejected/needs-review
        result -- never a guess.
      - Never invents or hardcodes a UUID: only IDs actually returned by
        these two SELECTs are used.

    Returns (source_id, evidence_type_id, errors). errors is a non-empty
    list of human-readable strings on failure; source_id/evidence_type_id
    are both None in that case.
    """
    errors = []

    source_code = (input_data.source or "").strip().upper()
    if not source_code:
        errors.append("IngestionInput.source is empty; cannot attribute evidence")
        source_id = None
    else:
        source_row = conn.execute(
            "SELECT id FROM public.data_sources WHERE code = %s AND deleted_at IS NULL LIMIT 1",
            (source_code,),
        ).fetchone()
        if source_row is None:
            errors.append(
                f"Unknown data source code '{source_code}' -- refusing to "
                f"fall back to a placeholder source. Add a public.data_sources "
                f"row with this code, or fix the caller."
            )
            source_id = None
        else:
            source_id = source_row["id"]

    evidence_code = (input_data.evidence_type or "").strip().upper()
    if not evidence_code:
        errors.append("IngestionInput.evidence_type is empty; cannot classify evidence")
        evidence_type_id = None
    else:
        evidence_row = conn.execute(
            "SELECT id FROM public.evidence_types WHERE code = %s AND deleted_at IS NULL LIMIT 1",
            (evidence_code,),
        ).fetchone()
        if evidence_row is None:
            errors.append(
                f"Unknown evidence type code '{evidence_code}' -- refusing to "
                f"fall back to a placeholder evidence type. Add a public."
                f"evidence_types row with this code, or fix the caller."
            )
            evidence_type_id = None
        else:
            evidence_type_id = evidence_row["id"]

    if errors:
        return None, None, errors
    return source_id, evidence_type_id, []


def _load_existing_state(conn, product_id: str) -> dict:
    ingredients = conn.execute(
        """
        SELECT pi.id, i.internal_code, i.name, pi.amount_value,
               u.code AS unit, pi.confidence_level
        FROM public.product_ingredients pi
        JOIN public.ingredients i ON i.id = pi.ingredient_id
        LEFT JOIN public.units u ON u.id = pi.unit_id
        WHERE pi.product_id = %s
          AND pi.deleted_at IS NULL
          AND i.deleted_at IS NULL
          AND (pi.effective_from IS NULL OR pi.effective_from <= NOW())
          AND (pi.effective_to IS NULL OR pi.effective_to > NOW())
        """,
        (product_id,),
    ).fetchall()

    allergens = conn.execute(
        """
        SELECT pa.id, a.internal_code, a.name, pa.confidence_level
        FROM public.product_allergens pa
        JOIN public.allergens a ON a.id = pa.allergen_id
        WHERE pa.product_id = %s
          AND pa.deleted_at IS NULL
          AND a.deleted_at IS NULL
          AND (pa.effective_from IS NULL OR pa.effective_from <= NOW())
          AND (pa.effective_to IS NULL OR pa.effective_to > NOW())
        """,
        (product_id,),
    ).fetchall()

    nutrition = conn.execute(
        """
        SELECT pnv.id, nt.code AS nutrition_type, pnv.amount_value,
               u.code AS unit, pnv.confidence_level,
               mb.code AS measurement_basis
        FROM public.product_nutrition_values pnv
        JOIN public.nutrition_types nt ON nt.id = pnv.nutrition_type_id
        JOIN public.units u ON u.id = pnv.unit_id
        LEFT JOIN public.measurement_bases mb
            ON mb.id = pnv.measurement_basis_id
        WHERE pnv.product_id = %s
          AND pnv.deleted_at IS NULL
          AND (pnv.effective_from IS NULL OR pnv.effective_from <= NOW())
          AND (pnv.effective_to IS NULL OR pnv.effective_to > NOW())
        """,
        (product_id,),
    ).fetchall()

    return {
        "ingredients": [dict(r) for r in ingredients],
        "allergens": [dict(r) for r in allergens],
        "nutrition": [dict(r) for r in nutrition],
    }


def _compare_ingredients(existing, input_data, refs, result):
    existing_by_name = {}
    for ex in existing:
        key = normalize_name(ex["name"])
        existing_by_name[key] = ex

    for ing in input_data.ingredients:
        norm_name = normalize_name(ing.name)

        if norm_name in existing_by_name:
            ex = existing_by_name[norm_name]
            needs_update = (
                ex.get("amount_value") != ing.amount_value
                or ex.get("unit") != ing.unit
            )
            if needs_update:
                result.changes.append(
                    ProposedChange(
                        action="update",
                        entity="ingredient",
                        entity_id=ex["id"],
                        details={
                            "name": ing.name,
                            "old_amount": ex.get("amount_value"),
                            "new_amount": ing.amount_value,
                            "old_unit": ex.get("unit"),
                            "new_unit": ing.unit,
                        },
                    )
                )
            else:
                result.changes.append(
                    ProposedChange(
                        action="no_change",
                        entity="ingredient",
                        entity_id=ex["id"],
                        details={"name": ing.name},
                    )
                )
        else:
            result.changes.append(
                ProposedChange(
                    action="create",
                    entity="ingredient",
                    details={
                        "name": ing.name,
                        "amount_value": ing.amount_value,
                        "unit": ing.unit,
                    },
                )
            )


def _compare_allergens(existing, input_data, refs, result):
    existing_by_name = {}
    for ex in existing:
        key = normalize_name(ex["name"])
        existing_by_name[key] = ex

    for al in input_data.allergens:
        norm_name = normalize_name(al.name)

        if norm_name in existing_by_name:
            ex = existing_by_name[norm_name]
            result.changes.append(
                ProposedChange(
                    action="no_change",
                    entity="allergen",
                    entity_id=ex["id"],
                    details={"name": al.name},
                )
            )
        else:
            result.changes.append(
                ProposedChange(
                    action="create",
                    entity="allergen",
                    details={"name": al.name},
                )
            )


def _compare_nutrition(existing, input_data, refs, result):
    existing_by_key = {}
    for ex in existing:
        key = (
            f"{normalize_code(ex['nutrition_type'])}"
            f"_{normalize_code(ex['unit'])}"
        )
        existing_by_key[key] = ex

    for nut in input_data.nutrition:
        key = (
            f"{normalize_code(nut.nutrition_type)}"
            f"_{normalize_code(nut.unit)}"
        )

        if key in existing_by_key:
            ex = existing_by_key[key]
            needs_update = ex.get("amount_value") != nut.amount_value

            if needs_update:
                result.changes.append(
                    ProposedChange(
                        action="update",
                        entity="nutrition",
                        entity_id=ex["id"],
                        details={
                            "nutrition_type": nut.nutrition_type,
                            "old_amount": ex.get("amount_value"),
                            "new_amount": nut.amount_value,
                            "unit": nut.unit,
                            "measurement_basis": nut.measurement_basis,
                        },
                    )
                )
            else:
                result.changes.append(
                    ProposedChange(
                        action="no_change",
                        entity="nutrition",
                        entity_id=ex["id"],
                        details={
                            "nutrition_type": nut.nutrition_type,
                            "amount_value": nut.amount_value,
                            "unit": nut.unit,
                        },
                    )
                )
        else:
            result.changes.append(
                ProposedChange(
                    action="create",
                    entity="nutrition",
                    details={
                        "nutrition_type": nut.nutrition_type,
                        "amount_value": nut.amount_value,
                        "unit": nut.unit,
                        "measurement_basis": nut.measurement_basis,
                    },
                )
            )


def _apply_changes(conn, result, refs, product_id, input_data):
    for change in result.changes:
        if change.action == "create":
            if change.entity == "ingredient":
                _create_ingredient(conn, product_id, change, refs)
            elif change.entity == "allergen":
                _create_allergen(conn, product_id, change, refs)
            elif change.entity == "nutrition":
                _create_nutrition(conn, product_id, change, refs)
        elif change.action == "update":
            if change.entity == "ingredient":
                _update_ingredient(conn, change)
            elif change.entity == "nutrition":
                _update_nutrition(conn, change)


def _resolve_by_name(conn, table, name):
    _assert_allowed_table(table)
    row = conn.execute(
        f"SELECT id FROM public.{table} "
        f"WHERE LOWER(name) = LOWER(%s) "
        f"AND deleted_at IS NULL LIMIT 1",
        (name,),
    ).fetchone()
    return row["id"] if row else None


def _resolve_by_code(conn, table, code):
    _assert_allowed_table(table)
    row = conn.execute(
        f"SELECT id FROM public.{table} WHERE code = %s LIMIT 1",
        (code,),
    ).fetchone()
    return row["id"] if row else None


def _create_ingredient(conn, product_id, change, refs):
    ingredient_id = _resolve_by_name(
        conn, "ingredients", change.details["name"]
    )
    if ingredient_id is None:
        raise ValueError(
            f"Ingredient not found in DB: {change.details['name']}"
        )

    conf = calculate_ingredient_confidence(
        has_name=True,
        has_amount=change.details.get("amount_value") is not None,
        has_unit=change.details.get("unit") is not None,
    )

    unit_id = None
    if change.details.get("unit"):
        unit_id = _resolve_by_code(conn, "units", change.details["unit"])

    status_id = refs.get("ls_ACTIVE")

    conn.execute(
        """
        INSERT INTO public.product_ingredients
            (product_id, ingredient_id,
             relationship_type_id, status_id, confidence_level,
             amount_value, unit_id,
             evidence_type_id, source_id)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        """,
        (
            product_id,
            ingredient_id,
            refs.get("rt_CONTAINS_INGREDIENT"),
            status_id,
            conf,
            change.details.get("amount_value"),
            unit_id,
            refs.get("resolved_evidence_type_id"),
            refs.get("resolved_source_id"),
        ),
    )


def _update_ingredient(conn, change):
    unit_id = None
    if change.details.get("new_unit"):
        unit_id = _resolve_by_code(conn, "units", change.details["new_unit"])

    conn.execute(
        """
        UPDATE public.product_ingredients
        SET amount_value = %s, unit_id = COALESCE(%s, unit_id)
        WHERE id = %s
        """,
        (change.details.get("new_amount"), unit_id, change.entity_id),
    )


def _create_allergen(conn, product_id, change, refs):
    allergen_id = _resolve_by_name(
        conn, "allergens", change.details["name"]
    )
    if allergen_id is None:
        raise ValueError(
            f"Allergen not found in DB: {change.details['name']}"
        )

    conf = calculate_allergen_confidence(has_name=True)

    status_id = refs.get("ls_ACTIVE")

    conn.execute(
        """
        INSERT INTO public.product_allergens
            (product_id, allergen_id, relationship_type_id,
             status_id, confidence_level, evidence_type_id, source_id)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        """,
        (
            product_id,
            allergen_id,
            refs.get("rt_CONTAINS_ALLERGEN"),
            status_id,
            conf,
            refs.get("resolved_evidence_type_id"),
            refs.get("resolved_source_id"),
        ),
    )


def _create_nutrition(conn, product_id, change, refs):
    nt_id = _resolve_by_code(
        conn, "nutrition_types", change.details["nutrition_type"]
    )
    unit_id = _resolve_by_code(
        conn, "units", change.details["unit"]
    )

    if nt_id is None:
        raise ValueError(
            f"Nutrition type not found: {change.details['nutrition_type']}"
        )
    if unit_id is None:
        raise ValueError(
            f"Unit not found: {change.details['unit']}"
        )

    mb_id = None
    if change.details.get("measurement_basis"):
        mb_id = _resolve_by_code(
            conn, "measurement_bases", change.details["measurement_basis"]
        )

    conf = calculate_nutrition_confidence(
        has_type=True, has_amount=True, has_unit=True
    )

    status_id = refs.get("ls_ACTIVE")

    conn.execute(
        """
        INSERT INTO public.product_nutrition_values
            (product_id, nutrition_type_id, amount_value, unit_id,
             measurement_basis_id,
             relationship_type_id, status_id, confidence_level,
             evidence_type_id, source_id)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """,
        (
            product_id,
            nt_id,
            change.details["amount_value"],
            unit_id,
            mb_id,
            refs.get("rt_MEASURED_VALUE"),
            status_id,
            conf,
            refs.get("resolved_evidence_type_id"),
            refs.get("resolved_source_id"),
        ),
    )


def _update_nutrition(conn, change):
    mb_id = None
    if change.details.get("measurement_basis"):
        mb_id = _resolve_by_code(
            conn, "measurement_bases", change.details["measurement_basis"]
        )

    conn.execute(
        """
        UPDATE public.product_nutrition_values
        SET amount_value = %s,
            measurement_basis_id = COALESCE(%s, measurement_basis_id)
        WHERE id = %s
        """,
        (change.details["new_amount"], mb_id, change.entity_id),
    )
