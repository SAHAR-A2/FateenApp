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


def get_health_conditions() -> list[dict]:
    """Get all active health conditions from the database."""
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
    """Get all active rules for a specific health condition."""
    try:
        with get_connection() as conn:
            rows = conn.execute(
                """
                SELECT id, condition_id, nutrition_type_code, operator,
                       threshold_value, unit_code, severity, description,
                       is_active, created_at
                FROM public.condition_nutrition_rules
                WHERE condition_id = %s AND is_active = TRUE
                ORDER BY nutrition_type_code, threshold_value
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

    nutrition = _get_product_nutrition(product_id)

    evidence_items = []
    overall_worst = HealthEvaluation.SAFE.value

    for rule in rules:
        ntype = rule["nutrition_type_code"]
        operator = rule["operator"]
        threshold = rule["threshold_value"]
        severity = rule["severity"]
        rule_id = str(rule["id"])

        if operator not in VALID_OPERATORS:
            logger.warning("Invalid operator in rule %s: %s", rule_id, operator)
            continue

        nutrition_values = nutrition.get(ntype, [])

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
            if overall_worst != HealthEvaluation.UNSAFE.value:
                overall_worst = HealthEvaluation.INSUFFICIENT_DATA.value
            continue

        for nv in nutrition_values:
            actual = nv["amount_value"]
            nv_unit = nv.get("unit_code", "G")
            rule_unit = rule.get("unit_code", "G")
            actual_converted = _convert_to_unit(actual, nv_unit, rule_unit)
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
            })

            if result == HealthEvaluation.UNSAFE.value:
                overall_worst = HealthEvaluation.UNSAFE.value
            elif result == HealthEvaluation.WARNING.value and overall_worst not in (
                HealthEvaluation.UNSAFE.value,
            ):
                overall_worst = HealthEvaluation.WARNING.value
            elif result == HealthEvaluation.CAUTION.value and overall_worst in (
                HealthEvaluation.SAFE.value, HealthEvaluation.INSUFFICIENT_DATA.value,
            ):
                overall_worst = HealthEvaluation.CAUTION.value

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
                evidence_items = []
                overall_worst = HealthEvaluation.SAFE.value

                for rule in rules:
                    ntype = rule["nutrition_type_code"]
                    operator = rule["operator"]
                    threshold = rule["threshold_value"]
                    severity = rule["severity"]
                    rule_id = str(rule["id"])

                    if operator not in VALID_OPERATORS:
                        logger.warning("Invalid operator in rule %s: %s", rule_id, operator)
                        continue

                    nutrition_values = nutrition.get(ntype, [])

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
                        if overall_worst != HealthEvaluation.UNSAFE.value:
                            overall_worst = HealthEvaluation.INSUFFICIENT_DATA.value
                        continue

                    for nv in nutrition_values:
                        actual = nv["amount_value"]
                        nv_unit = nv.get("unit_code", "G")
                        rule_unit = rule.get("unit_code", "G")
                        actual_converted = _convert_to_unit(actual, nv_unit, rule_unit)
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
                        })

                        if result == HealthEvaluation.UNSAFE.value:
                            overall_worst = HealthEvaluation.UNSAFE.value
                        elif result == HealthEvaluation.WARNING.value and overall_worst not in (
                            HealthEvaluation.UNSAFE.value,
                        ):
                            overall_worst = HealthEvaluation.WARNING.value
                        elif result == HealthEvaluation.CAUTION.value and overall_worst in (
                            HealthEvaluation.SAFE.value,
                            HealthEvaluation.INSUFFICIENT_DATA.value,
                        ):
                            overall_worst = HealthEvaluation.CAUTION.value

                evaluation_result = overall_worst

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
