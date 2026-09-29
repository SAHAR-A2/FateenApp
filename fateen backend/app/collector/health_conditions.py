"""P22/P23/P24/P25: Disease-agnostic health condition evaluation.

Evaluates products against health conditions loaded from the database.
Conditions and rules are NOT hardcoded -- they are loaded dynamically.
No disease-specific logic is embedded in the code.
"""
# ---------------------------------------------------------------------------
# PRODUCTION-PATH STATUS (verified 2026-08-20, final release remediation):
# This module is NOT currently imported or called by any live API endpoint,
# CLI entry point, or orchestrator path in this codebase (app/api/*,
# app/main.py, app/collector/orchestrator.py, app/agent/*). It is fully
# implemented and tested in isolation but architecturally UNREACHABLE from
# production traffic as of commit 7b32932. Do not assume its protections
# are active for real requests until it is explicitly wired into a live
# call path AND that wiring is covered by an integration test proving the
# connection. See reports/FINAL_PRE_AGENT_RELEASE_AUDIT.md, section I, for
# the reachability audit and the decision not to wire it in during this
# remediation pass (wiring was judged out of scope: it requires an
# architecture decision about which entry point should invoke it and with
# what data, not just a mechanical import).
# ---------------------------------------------------------------------------

import logging
import time
import uuid
from datetime import datetime, timezone
from typing import Optional

from app.db.connection import get_connection
from app.collector.models import HealthEvaluation

logger = logging.getLogger("fateen.collector.health_conditions")

VALID_OPERATORS = {">", "<", "=", ">=", "<="}

_UNIT_FACTORS = {
    "G": 1.0,
    "MG": 0.001,
    "KG": 1000.0,
    "MCG": 0.000001,
    "UG": 0.000001,
    "KCAL": 1.0,
    "KJ": 0.239006,
    "MG_TE": 1.0,
}


def _convert_to_unit(value: float, from_unit: str, to_unit: str) -> float:
    """Convert a nutrition value between units using standard factors.

    If the pair is unknown, returns the original value unchanged
    (safe fallback — same as current behavior).
    """
    if from_unit == to_unit:
        return value
    from_f = _UNIT_FACTORS.get(from_unit)
    to_f = _UNIT_FACTORS.get(to_unit)
    if from_f is None or to_f is None:
        return value
    return value * from_f / to_f


def _apply_operator(value: float, operator: str, threshold: float) -> bool:
    """Apply a comparison operator to a value and threshold."""
    if operator == ">":
        return value > threshold
    elif operator == "<":
        return value < threshold
    elif operator == "=":
        return abs(value - threshold) < 1e-9
    elif operator == ">=":
        return value >= threshold
    elif operator == "<=":
        return value <= threshold
    return False


def _determine_evaluation(severity: str, triggered: bool) -> str:
    """Determine evaluation result based on severity and whether the rule triggered.

    Returns a HealthEvaluation value.
    """
    if not triggered:
        return HealthEvaluation.SAFE.value

    severity = (severity or "").lower()
    if severity == "unsafe":
        return HealthEvaluation.UNSAFE.value
    elif severity in ("warning", "warn"):
        return HealthEvaluation.WARNING.value
    elif severity in ("caution", "info"):
        return HealthEvaluation.CAUTION.value
    else:
        return HealthEvaluation.WARNING.value


# Conditions and their thresholds are reference data read for every
# product checked (an alternatives request checks up to 20). Keep them for
# a few minutes instead of re-reading them from a database that may be far
# away; a change to a threshold takes effect within _CACHE_SECONDS.
_CACHE_SECONDS = 300
_cache: dict[str, tuple[float, list[dict]]] = {}


def clear_cache() -> None:
    _cache.clear()


def _cached(key: str, load) -> list[dict]:
    hit = _cache.get(key)
    if hit and time.monotonic() - hit[0] < _CACHE_SECONDS:
        return hit[1]
    rows = load()
    if rows:  # never cache a failed or empty read
        _cache[key] = (time.monotonic(), rows)
    return rows


def get_health_conditions() -> list[dict]:
    """Get all active health conditions from the database."""
    return _cached("conditions", _load_health_conditions)


def _load_health_conditions() -> list[dict]:
    try:
        with get_connection() as conn:
            rows = conn.execute(
                """
                SELECT id, name, code, description, is_active, created_at
                FROM public.health_conditions
                WHERE is_active = TRUE
                ORDER BY name
                """
            ).fetchall()
            return [dict(r) for r in rows]
    except Exception:
        logger.exception("Failed to get health conditions")
        return []


def get_condition_rules(condition_id: str) -> list[dict]:
    """Get all active thresholds for a health condition (migration 0055;
    the older condition_nutrition_rules table is no longer read)."""
    return _cached(f"rules:{condition_id}", lambda: _load_condition_rules(condition_id))


def _load_condition_rules(condition_id: str) -> list[dict]:
    try:
        with get_connection() as conn:
            rows = conn.execute(
                """
                SELECT id, condition_id, nutrition_type_code, operator,
                       threshold_value, unit_code, measurement_basis_code,
                       severity, description, source, is_active, created_at
                FROM public.condition_nutrient_thresholds
                WHERE condition_id = %s AND is_active = TRUE
                ORDER BY nutrition_type_code, measurement_basis_code
                """,
                (condition_id,),
            ).fetchall()
            return [dict(r) for r in rows]
    except Exception:
        logger.exception("Failed to get rules for condition %s", condition_id)
        return []


def _get_product_nutrition(product_id: str) -> dict[str, list[dict]]:
    """Get all nutrition values for a product, keyed by nutrition_type code.

    Returns dict like {"SUGAR": [{"amount": 12.5, "unit": "G", ...}], ...}
    """
    try:
        with get_connection() as conn:
            rows = conn.execute(
                """
                SELECT nt.code AS nutrition_type_code,
                       pnv.amount_value,
                       u.code AS unit_code,
                       pnv.confidence_level,
                       mb.code AS measurement_basis
                FROM public.product_nutrition_values pnv
                JOIN public.nutrition_types nt ON nt.id = pnv.nutrition_type_id
                JOIN public.units u ON u.id = pnv.unit_id
                LEFT JOIN public.measurement_bases mb ON mb.id = pnv.measurement_basis_id
                WHERE pnv.product_id = %s
                  AND pnv.deleted_at IS NULL
                  AND (pnv.effective_from IS NULL OR pnv.effective_from <= NOW())
                  AND (pnv.effective_to IS NULL OR pnv.effective_to > NOW())
                """,
                (product_id,),
            ).fetchall()

            by_type: dict[str, list[dict]] = {}
            for row in rows:
                code = row["nutrition_type_code"]
                if code not in by_type:
                    by_type[code] = []
                by_type[code].append(dict(row))
            return by_type
    except Exception:
        logger.exception("Failed to get nutrition for product %s", product_id)
        return {}


# Rules are written per 100 g (food) or per 100 ml (drink). A per-serving or
# per-package value is not comparable with them.
_COMPARABLE_BASES = ("PER_100G", "PER_100ML")
# Regulation (EU) No 1169/2011 Annex I: salt = sodium x 2.5.
_SALT_PER_SODIUM = 2.5


def _with_sodium_from_salt(nutrition: dict[str, list[dict]]) -> dict[str, list[dict]]:
    """Add a SODIUM value derived from every SALT value, so a sodium rule is
    not reported as missing data and is judged by the worse of the two.

    Stored sodium is not always right: older imports saved Open Food Facts'
    sodium in grams under the unit MG (0.868 "mg" for crisps with 2.17 g of
    salt), which read as almost no salt. The derived value keeps such a
    product from passing a high-blood-pressure check."""
    derived = [
        {**v, "nutrition_type_code": "SODIUM",
         "amount_value": _convert_to_unit(v["amount_value"], v.get("unit_code", "G"), "G") / _SALT_PER_SODIUM,
         "unit_code": "G", "derived_from": "SALT"}
        for v in nutrition.get("SALT", [])
    ]
    if not derived:
        return nutrition
    return {**nutrition, "SODIUM": nutrition.get("SODIUM", []) + derived}


def evaluate_rules(rules: list[dict], nutrition: dict[str, list[dict]]) -> tuple[str, list[dict]]:
    """Worst result of `rules` over a product's nutrition, with evidence.

    Only per-100 g / per-100 ml values are compared. A rule with a
    measurement_basis_code applies only when the product has values on that
    basis, so a drink (per 100 ml) is judged by the drink thresholds and is
    not reported as missing the food ones. A rule without a basis (legacy)
    applies to either. A product with no comparable value at all gets
    INSUFFICIENT_DATA from every rule.
    """
    nutrition = _with_sodium_from_salt({
        code: [v for v in values if v.get("measurement_basis") in _COMPARABLE_BASES]
        for code, values in nutrition.items()
    })
    product_bases = {v["measurement_basis"] for values in nutrition.values() for v in values}

    evidence_items = []
    overall_worst = HealthEvaluation.SAFE.value
    for rule in rules:
        ntype = rule["nutrition_type_code"]
        operator = rule["operator"]
        threshold = rule["threshold_value"]
        severity = rule["severity"]
        rule_id = str(rule["id"])
        rule_basis = rule.get("measurement_basis_code")

        if operator not in VALID_OPERATORS:
            logger.warning("Invalid operator in rule %s: %s", rule_id, operator)
            continue
        if rule_basis and product_bases and rule_basis not in product_bases:
            continue  # a food rule for a drink, or the reverse

        nutrition_values = [
            v for v in nutrition.get(ntype, [])
            if not rule_basis or v["measurement_basis"] == rule_basis
        ]
        if not nutrition_values:
            evidence_items.append({
                "rule_id": rule_id,
                "nutrition_type": ntype,
                "operator": operator,
                "threshold": threshold,
                "severity": severity,
                "triggered": False,
                "result": HealthEvaluation.INSUFFICIENT_DATA.value,
                "description": rule.get("description"),
                "actual_value": None,
            })
            if overall_worst == HealthEvaluation.SAFE.value:
                overall_worst = HealthEvaluation.INSUFFICIENT_DATA.value
            continue

        for nv in nutrition_values:
            actual = nv["amount_value"]
            nv_unit = nv.get("unit_code", "G")
            actual_converted = _convert_to_unit(actual, nv_unit, rule.get("unit_code", "G"))
            triggered = _apply_operator(actual_converted, operator, threshold)
            result = _determine_evaluation(severity, triggered)
            evidence_items.append({
                "rule_id": rule_id,
                "nutrition_type": ntype,
                "operator": operator,
                "threshold": threshold,
                "severity": severity,
                "triggered": triggered,
                "result": result,
                "description": rule.get("description"),
                "actual_value": actual,
                "unit": nv_unit,
                "measurement_basis": nv["measurement_basis"],
            })
            if result == HealthEvaluation.UNSAFE.value:
                overall_worst = HealthEvaluation.UNSAFE.value
            elif result == HealthEvaluation.WARNING.value and overall_worst != HealthEvaluation.UNSAFE.value:
                overall_worst = HealthEvaluation.WARNING.value
            elif result == HealthEvaluation.CAUTION.value and overall_worst in (
                HealthEvaluation.SAFE.value, HealthEvaluation.INSUFFICIENT_DATA.value,
            ):
                overall_worst = HealthEvaluation.CAUTION.value
    return overall_worst, evidence_items


def evaluate_single_condition(product_id: str, condition_code: str) -> Optional[dict]:
    """Evaluate a product against a single health condition by code.

    Returns an evaluation dict with condition info, result, and per-rule evidence,
    or None if the condition doesn't exist or is inactive.
    """
    try:
        with get_connection() as conn:
            condition = conn.execute(
                """
                SELECT id, name, code, description
                FROM public.health_conditions
                WHERE code = %s AND is_active = TRUE
                """,
                (condition_code,),
            ).fetchone()

            if not condition:
                logger.warning("Health condition not found or inactive: %s", condition_code)
                return None

            condition_id = str(condition["id"])

    except Exception:
        logger.exception("Failed to look up condition %s", condition_code)
        return None

    rules = get_condition_rules(condition_id)
    if not rules:
        return {
            "condition_id": condition_id,
            "condition_code": condition_code,
            "condition_name": condition["name"],
            "evaluation_result": HealthEvaluation.UNKNOWN.value,
            "evidence": [],
            "rule_count": 0,
        }

    overall_worst, evidence_items = evaluate_rules(rules, _get_product_nutrition(product_id))

    return {
        "condition_id": condition_id,
        "condition_code": condition_code,
        "condition_name": condition["name"],
        "evaluation_result": overall_worst,
        "evidence": evidence_items,
        "rule_count": len(rules),
    }


def evaluate_product_health(product_id: str) -> list[dict]:
    """Evaluate a product against all active health conditions.

    For each health condition with active rules:
      1. Query product_nutrition_values for the relevant nutrition_type
      2. Apply the operator against the threshold
      3. Return evaluation_result: SAFE, CAUTION, WARNING, UNSAFE, UNKNOWN, INSUFFICIENT_DATA

    Results are stored in product_health_evaluations and returned.
    """
    evaluations = []
    now = datetime.now(timezone.utc)

    try:
        conditions = get_health_conditions()
        if not conditions:
            return evaluations

        nutrition = _get_product_nutrition(product_id)

        for condition in conditions:
            condition_id = str(condition["id"])
            condition_code = condition["code"]
            rules = get_condition_rules(condition_id)

            if not rules:
                evaluation_result = HealthEvaluation.UNKNOWN.value
                evidence_items = []
            else:
                evaluation_result, evidence_items = evaluate_rules(rules, nutrition)

            eval_id = str(uuid.uuid4())
            try:
                with get_connection() as conn:
                    import json
                    existing = conn.execute(
                        """
                        SELECT id FROM public.product_health_evaluations
                        WHERE product_id = %s AND condition_id = %s
                        LIMIT 1
                        """,
                        (product_id, condition_id),
                    ).fetchone()
                    if existing:
                        eval_id = str(existing["id"])
                        conn.execute(
                            """
                            UPDATE public.product_health_evaluations
                            SET evaluation_result = %s, evidence = %s,
                                evaluated_at = %s
                            WHERE id = %s
                            """,
                            (evaluation_result, json.dumps(evidence_items), now, eval_id),
                        )
                    else:
                        conn.execute(
                            """
                            INSERT INTO public.product_health_evaluations
                                (id, product_id, condition_id, evaluation_result,
                                 evidence, evaluated_at, created_at)
                            VALUES (%s, %s, %s, %s, %s, %s, %s)
                            """,
                            (
                                eval_id,
                                product_id,
                                condition_id,
                                evaluation_result,
                                json.dumps(evidence_items),
                                now,
                                now,
                            ),
                        )
            except Exception:
                logger.exception(
                    "Failed to store health evaluation for product %s condition %s",
                    product_id, condition_code,
                )

            evaluations.append({
                "evaluation_id": eval_id,
                "condition_id": condition_id,
                "condition_code": condition_code,
                "condition_name": condition["name"],
                "evaluation_result": evaluation_result,
                "evidence": evidence_items,
                "rule_count": len(rules),
            })

    except Exception:
        logger.exception("Failed to evaluate product health for %s", product_id)

    return evaluations
