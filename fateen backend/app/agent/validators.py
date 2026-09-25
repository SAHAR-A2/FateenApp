def validate_barcode(barcode: str) -> list:
    errors = []
    if not barcode:
        errors.append("Barcode is empty")
        return errors
    cleaned = barcode.replace(" ", "").replace("-", "")
    if not cleaned.isdigit():
        errors.append(f"Barcode contains non-digit characters: {barcode}")
    elif len(cleaned) < 8 or len(cleaned) > 14:
        errors.append(
            f"Barcode length {len(cleaned)} outside expected range 8-14"
        )
    return errors


def validate_confidence(confidence) -> list:
    errors = []
    if confidence is None:
        errors.append("Confidence is None")
    elif not isinstance(confidence, (int, float)):
        errors.append(f"Confidence is not numeric: {confidence}")
    elif confidence != confidence:
        errors.append("Confidence is NaN")
    elif confidence < 0 or confidence > 1:
        errors.append(f"Confidence {confidence} outside [0, 1]")
    return errors
