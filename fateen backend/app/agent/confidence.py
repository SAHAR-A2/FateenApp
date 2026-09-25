def calculate_ingredient_confidence(
    has_name: bool = True,
    has_amount: bool = False,
    has_unit: bool = False,
    source_verified: bool = False,
) -> float:
    score = 0.0
    if has_name:
        score += 0.4
    if has_amount:
        score += 0.2
    if has_unit:
        score += 0.1
    if source_verified:
        score += 0.3
    return round(min(score, 1.0), 2)


def calculate_allergen_confidence(
    has_name: bool = True,
    source_verified: bool = False,
) -> float:
    score = 0.0
    if has_name:
        score += 0.5
    if source_verified:
        score += 0.5
    return round(min(score, 1.0), 2)


def calculate_nutrition_confidence(
    has_type: bool = True,
    has_amount: bool = True,
    has_unit: bool = True,
    source_verified: bool = False,
) -> float:
    score = 0.0
    if has_type:
        score += 0.25
    if has_amount:
        score += 0.25
    if has_unit:
        score += 0.2
    if source_verified:
        score += 0.3
    return round(min(score, 1.0), 2)


def calculate_product_confidence(
    ingredient_confidences: list,
    allergen_confidences: list,
    nutrition_confidences: list,
) -> float:
    all_conf = ingredient_confidences + allergen_confidences + nutrition_confidences
    if not all_conf:
        return 0.0
    return round(sum(all_conf) / len(all_conf), 2)
