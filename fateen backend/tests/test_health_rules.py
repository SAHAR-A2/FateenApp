"""evaluate_rules in app.collector.health_conditions (pure, no database)."""
import pytest

from app.collector.health_conditions import evaluate_rules


def _rule(nutrient, threshold, unit, basis, rid="r"):
    return {"id": rid, "nutrition_type_code": nutrient, "operator": ">",
            "threshold_value": threshold, "unit_code": unit,
            "measurement_basis_code": basis, "severity": "warning", "description": None}


# 0055: diabetes, FSA "high" sugar.
SUGAR_RULES = [_rule("SUGAR", 22.5, "G", "PER_100G", "food"), _rule("SUGAR", 11.25, "G", "PER_100ML", "drink")]
SODIUM_RULES = [_rule("SODIUM", 600, "MG", "PER_100G", "food"), _rule("SODIUM", 300, "MG", "PER_100ML", "drink")]


def _value(nutrient, amount, unit="G", basis="PER_100G"):
    return {nutrient: [{"amount_value": amount, "unit_code": unit, "measurement_basis": basis}]}


@pytest.mark.parametrize("nutrition,expected", [
    (_value("SUGAR", 30), "WARNING"),                         # food above 22.5
    (_value("SUGAR", 10), "SAFE"),
    (_value("SUGAR", 12, basis="PER_100ML"), "WARNING"),      # drink above 11.25
    (_value("SUGAR", 10, basis="PER_100ML"), "SAFE"),         # not judged by the food rule
    (_value("SUGAR", 90, basis="PER_SERVING"), "INSUFFICIENT_DATA"),  # not comparable
    ({}, "INSUFFICIENT_DATA"),
])
def test_sugar_rules_follow_the_measurement_basis(nutrition, expected):
    result, _ = evaluate_rules(SUGAR_RULES, nutrition)
    assert result == expected


def test_drink_is_not_reported_missing_the_food_value():
    _, evidence = evaluate_rules(SUGAR_RULES, _value("SUGAR", 5, basis="PER_100ML"))
    assert [e["rule_id"] for e in evidence] == ["drink"]


@pytest.mark.parametrize("salt_g,expected", [(1.6, "WARNING"), (1.4, "SAFE")])
def test_sodium_rule_uses_salt_when_sodium_is_missing(salt_g, expected):
    # 1.5 g salt = 600 mg sodium (salt = sodium x 2.5).
    result, evidence = evaluate_rules(SODIUM_RULES, _value("SALT", salt_g))
    assert result == expected
    assert evidence[0]["nutrition_type"] == "SODIUM"


def test_recorded_sodium_and_salt_are_both_judged():
    # Consistent values agree: 0.2 g salt is 80 mg sodium.
    result, _ = evaluate_rules(SODIUM_RULES, {**_value("SODIUM", 80, unit="MG"), **_value("SALT", 0.2)})
    assert result == "SAFE"
    # Contradicting values: the worse one wins (5 g salt is 2000 mg sodium).
    result, evidence = evaluate_rules(SODIUM_RULES, {**_value("SODIUM", 100, unit="MG"), **_value("SALT", 5)})
    assert result == "WARNING" and len(evidence) == 2


def test_sodium_stored_in_grams_under_mg_does_not_pass_salty_food():
    # Seen on Cloud: Lay's Salt & Vinegar, sodium 0.868 "MG" (really grams)
    # next to 2.17 g salt per 100 g.
    nutrition = {**_value("SODIUM", 0.868, unit="MG"), **_value("SALT", 2.17)}
    result, _ = evaluate_rules(SODIUM_RULES, nutrition)
    assert result == "WARNING"


def test_missing_nutrient_does_not_hide_a_triggered_rule():
    rules = [_rule("SATURATED_FAT", 5, "G", "PER_100G", "fat"), *SODIUM_RULES]
    result, _ = evaluate_rules(rules, _value("SATURATED_FAT", 9))  # no sodium or salt
    assert result == "WARNING"
